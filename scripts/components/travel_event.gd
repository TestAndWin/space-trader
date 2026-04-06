extends ColorRect

## Travel event popup — random non-combat encounters during space travel.
## Call try_trigger() from travel_scene. If it returns true the popup is visible
## and ready for player interaction; otherwise nothing happens.

signal event_resolved

const TRIGGER_CHANCE := 0.20

var _all_events: Array = []
var _current_event: Resource = null

var _title_label: Label
var _description_label: Label
var _outcome_label: Label
var _choice_a_button: Button
var _choice_b_button: Button


# ── Public API ───────────────────────────────────────────────────────────────

func try_trigger() -> bool:
	_load_events()
	if randf() > TRIGGER_CHANCE:
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
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0.0, 0.0, 0.0, 0.75)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.95)
	panel_style.border_color = Color(0.5, 0.7, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_title_label)

	# Description
	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_description_label.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(_description_label)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.25, 0.4, 0.6))
	vbox.add_child(sep)

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
	_apply_button_style(_choice_a_button, Color(0.2, 0.4, 0.7), Color(0.25, 0.5, 0.85), Color(0.15, 0.3, 0.55))
	_choice_a_button.pressed.connect(_on_choice_a)
	hbox.add_child(_choice_a_button)

	_choice_b_button = Button.new()
	_choice_b_button.custom_minimum_size = Vector2(160, 36)
	_apply_button_style(_choice_b_button, Color(0.25, 0.25, 0.28), Color(0.35, 0.35, 0.38), Color(0.18, 0.18, 0.2))
	_choice_b_button.pressed.connect(_on_choice_b)
	hbox.add_child(_choice_b_button)


func _apply_button_style(btn: Button, normal_color: Color, hover_color: Color, pressed_color: Color) -> void:
	for pair in [["normal", normal_color], ["hover", hover_color], ["pressed", pressed_color]]:
		var style := StyleBoxFlat.new()
		style.bg_color = pair[1]
		style.set_corner_radius_all(4)
		style.set_content_margin_all(6)
		btn.add_theme_stylebox_override(pair[0], style)


# ── Display ──────────────────────────────────────────────────────────────────

func _show_event() -> void:
	if _current_event == null:
		return
	_title_label.text = _current_event.event_name.to_upper()
	_description_label.text = _current_event.description
	_choice_a_button.text = _current_event.choice_a_text
	_choice_b_button.text = _current_event.choice_b_text
	_outcome_label.visible = false

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
	if ev.choice_a_success_chance < 1.0 and randf() >= ev.choice_a_success_chance:
		_apply_outcome(ev.choice_a_alt_credits, ev.choice_a_alt_hull)
		_show_outcome(ev.choice_a_alt_description)
	else:
		_apply_outcome(ev.choice_a_credits, ev.choice_a_hull)
		# Distress signal: helping improves reputation with destination faction
		if ev.event_name == "Distress Signal":
			var dest_faction: String = GameManager.get_planet_faction(GameManager.travel_destination)
			GameManager.add_faction_reputation(dest_faction, 5, "helped distress signal")
		_show_outcome(ev.choice_a_description)


func _on_choice_b() -> void:
	var ev := _current_event
	if ev.choice_b_success_chance < 1.0 and randf() >= ev.choice_b_success_chance:
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
	_apply_button_style(close_btn, Color(0.2, 0.4, 0.7), Color(0.25, 0.5, 0.85), Color(0.15, 0.3, 0.55))
	close_btn.pressed.connect(_close)
	_choice_a_button.get_parent().add_child(close_btn)


func _close() -> void:
	event_resolved.emit()
	queue_free()
