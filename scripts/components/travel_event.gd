extends ColorRect

## Travel event popup — random non-combat encounters during space travel.
## Call try_trigger(days) from travel_scene. If it returns true the popup is visible
## and ready for player interaction; otherwise nothing happens.

signal event_resolved

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const TRIGGER_CHANCE := 0.20

var _all_events: Array = []
var _current_event: Resource = null

var _title_label: Label
var _description_label: Label
var _outcome_label: Label
var _choice_a_button: Button
var _choice_b_button: Button


# ── Public API ───────────────────────────────────────────────────────────────

func try_trigger(days: int = 1) -> bool:
	_load_events()
	var base_chance: float = 1.0 - pow(1.0 - TRIGGER_CHANCE, maxi(days, 1))
	var weather_modifier: float = EventManager.get_active_weather().get("travel_event_chance_modifier", 0.0)
	var chance: float = clampf(base_chance + weather_modifier, 0.0, 0.85)
	if randf() > chance:
		return false
	if _all_events.is_empty():
		return false
	_current_event = _all_events[randi() % _all_events.size()]
	_show_event()
	visible = true
	return true


# ── Data loading ─────────────────────────────────────────────────────────────

func _load_events() -> void:
	if not _all_events.is_empty():
		return
	_all_events = ResourceRegistry.load_all(ResourceRegistry.TRAVEL_EVENTS)


# ── UI construction ──────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var scaffold := UIStyles.create_event_modal_scaffold(self, 400.0, Color(0.5, 0.8, 1.0))
	var vbox: VBoxContainer = scaffold["vbox"]
	_title_label = scaffold["title_label"]
	_description_label = scaffold["description_label"]

	# Outcome label (shown after choice)
	_outcome_label = Label.new()
	_outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outcome_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6))
	_outcome_label.custom_minimum_size = Vector2(360, 0)
	_outcome_label.visible = false
	vbox.add_child(_outcome_label)

	# Buttons
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	_choice_a_button = Button.new()
	_choice_a_button.custom_minimum_size = Vector2(160, 36)
	UIStyles.style_event_button(_choice_a_button, Color(0.2, 0.4, 0.7), Color(0.25, 0.5, 0.85), Color(0.15, 0.3, 0.55))
	_choice_a_button.pressed.connect(_on_choice_a)
	hbox.add_child(_choice_a_button)

	_choice_b_button = Button.new()
	_choice_b_button.custom_minimum_size = Vector2(160, 36)
	UIStyles.style_event_button(_choice_b_button, Color(0.25, 0.25, 0.28), Color(0.35, 0.35, 0.38), Color(0.18, 0.18, 0.2))
	_choice_b_button.pressed.connect(_on_choice_b)
	hbox.add_child(_choice_b_button)


# ── Display ──────────────────────────────────────────────────────────────────

func _show_event() -> void:
	if _current_event == null:
		return
	_title_label.text = _current_event.event_name.to_upper()
	_description_label.text = _current_event.description
	_choice_a_button.text = _current_event.choice_a_text
	_choice_b_button.text = _current_event.choice_b_text
	_outcome_label.visible = false
	# Show crew flavor text if applicable
	var flavor_text: String = GameManager.get_crew_event_flavor_text(_current_event.event_name)
	if flavor_text != "":
		_description_label.text = _description_label.text + "\n\n[Crew] " + flavor_text

	# Check if choice A is affordable
	_choice_a_button.disabled = not _can_choose_a()


func _can_choose_a() -> bool:
	var ev := _current_event
	if ev.choice_a_credits < 0 and GameManager.credits < abs(ev.choice_a_credits):
		return false
	if ev.choice_a_hull < 0 and GameManager.current_hull <= abs(ev.choice_a_hull):
		return false
	return true


# ── Choice handlers ──────────────────────────────────────────────────────────

func _on_choice_a() -> void:
	var ev := _current_event
	var effective_chance: float = ev.choice_a_success_chance + GameManager.get_event_success_bonus()
	if effective_chance < 1.0 and randf() >= effective_chance:
		_apply_outcome(ev.choice_a_alt_credits, ev.choice_a_alt_hull)
		_show_outcome(ev.choice_a_alt_description)
	else:
		_apply_outcome(ev.choice_a_credits, ev.choice_a_hull)
		# Distress signal: helping improves reputation with destination faction
		if ev.event_name == "Distress Signal":
			var dest_faction: String = StandingManager.get_planet_faction(GameManager.travel_destination)
			StandingManager.add_faction_reputation(dest_faction, 5, "helped distress signal")
		_show_outcome(ev.choice_a_description)


func _on_choice_b() -> void:
	var ev := _current_event
	var effective_chance: float = ev.choice_b_success_chance + GameManager.get_event_success_bonus()
	if effective_chance < 1.0 and randf() >= effective_chance:
		_apply_outcome(ev.choice_b_alt_credits, ev.choice_b_alt_hull)
		_show_outcome(ev.choice_b_alt_description)
	else:
		_apply_outcome(ev.choice_b_credits, ev.choice_b_hull)
		_show_outcome(ev.choice_b_description)


func _apply_outcome(credits_delta: int, hull_delta: int) -> void:
	if credits_delta > 0:
		GameManager.add_credits(credits_delta)
	elif credits_delta < 0:
		GameManager.remove_credits(abs(credits_delta))

	if hull_delta > 0:
		GameManager.current_hull = mini(GameManager.current_hull + hull_delta, GameManager.max_hull)
	elif hull_delta < 0:
		GameManager.current_hull = maxi(GameManager.current_hull + hull_delta, 1)

	var parts: Array = []
	if credits_delta != 0:
		parts.append("%+d credits" % credits_delta)
	if hull_delta != 0:
		parts.append("%+d hull" % hull_delta)
	if not parts.is_empty():
		EventLog.add_entry("Travel event: " + ", ".join(parts))


func _show_outcome(text: String) -> void:
	_outcome_label.text = text
	_outcome_label.visible = true
	_choice_a_button.visible = false
	_choice_b_button.visible = false

	var close_btn := Button.new()
	close_btn.text = "Continue"
	close_btn.custom_minimum_size = Vector2(140, 36)
	UIStyles.style_event_button(close_btn, Color(0.2, 0.4, 0.7), Color(0.25, 0.5, 0.85), Color(0.15, 0.3, 0.55))
	close_btn.pressed.connect(close)
	_choice_a_button.get_parent().add_child(close_btn)


func close() -> void:
	event_resolved.emit()
	queue_free()
