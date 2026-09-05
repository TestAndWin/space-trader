class_name EventChoiceModal
extends ColorRect

## Shared frame for the two-choice event popups (PlanetEvent, TravelEvent).
##
## Both are the same modal: title, description, two choice buttons, then a
## single outcome text with a Continue button. Only the event data and the
## per-choice consequences differ, so a subclass supplies try_trigger(), the
## two choice handlers, and the small configuration hooks below.

signal event_resolved

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

const MODAL_WIDTH := 400.0
const CHOICE_BUTTON_SIZE := Vector2(160, 36)

# All loaded event resources
var _all_events: Array = []
# Currently displayed event
var _current_event: Resource = null

var _title_label: Label
var _description_label: Label
var _outcome_label: Label
var _choice_a_button: Button
var _choice_b_button: Button


# ── Configuration hooks ──────────────────────────────────────────────────────
# Overridden by the concrete popups.

## Tint of the modal frame title.
func _modal_title_color() -> Color:
	return Color(0.4, 0.7, 1.0)


## Prefix for the EventLog entry written by _apply_outcome().
func _log_prefix() -> String:
	return "Event"


## Last chance to rewrite the event text before it is shown.
func _format_description(text: String) -> String:
	return text


## Tooltip explaining why choice A is unavailable. Subclasses append their own
## reasons via super(). Empty means no tooltip.
func _requirement_text() -> String:
	var ev := _current_event
	var parts: Array = []
	if ev.choice_a_credits < 0 and GameManager.credits < abs(ev.choice_a_credits):
		parts.append("Need %d credits" % abs(ev.choice_a_credits))
	if ev.choice_a_hull < 0 and GameManager.current_hull <= abs(ev.choice_a_hull):
		parts.append("Hull too low")
	if _is_wasted_repair():
		parts.append("Hull already full")
	return ". ".join(parts)


## True when choice A is a paid repair and there is nothing left to repair.
## Hull gains clamp at max_hull, so buying one at full hull spends the credits
## for no effect at all -- block it rather than let the player pay for nothing.
func _is_wasted_repair() -> bool:
	var ev := _current_event
	return (
		ev.choice_a_hull > 0
		and ev.choice_a_credits <= 0
		and ev.choice_a_cargo_qty <= 0
		and GameManager.current_hull >= GameManager.max_hull
	)


## Subclasses resolve their own choices — the outcome fields differ per event type.
func _on_choice_a() -> void:
	pass


func _on_choice_b() -> void:
	pass


# ── Data loading ─────────────────────────────────────────────────────────────

func _load_events(paths: Array) -> void:
	if _all_events.is_empty():
		_all_events = ResourceRegistry.load_all(paths)


# ── UI construction ──────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var scaffold := UIStyles.create_event_modal_scaffold(self, MODAL_WIDTH, _modal_title_color())
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
	_choice_a_button.custom_minimum_size = CHOICE_BUTTON_SIZE
	_style_primary_button(_choice_a_button)
	_choice_a_button.pressed.connect(_on_choice_a)
	hbox.add_child(_choice_a_button)

	_choice_b_button = Button.new()
	_choice_b_button.custom_minimum_size = CHOICE_BUTTON_SIZE
	UIStyles.style_event_button(
		_choice_b_button, Color(0.25, 0.25, 0.28), Color(0.35, 0.35, 0.38), Color(0.18, 0.18, 0.2)
	)
	_choice_b_button.pressed.connect(_on_choice_b)
	hbox.add_child(_choice_b_button)


static func _style_primary_button(btn: Button) -> void:
	UIStyles.style_event_button(
		btn, Color(0.2, 0.4, 0.7), Color(0.25, 0.5, 0.85), Color(0.15, 0.3, 0.55)
	)


# ── Display ──────────────────────────────────────────────────────────────────

func _show_event() -> void:
	if _current_event == null:
		return
	_title_label.text = _current_event.event_name.to_upper()
	_description_label.text = _format_description(_current_event.description)
	_choice_a_button.text = _current_event.choice_a_text
	_choice_b_button.text = _current_event.choice_b_text
	_outcome_label.visible = false

	# Show crew flavor text if applicable
	var flavor_text: String = GameManager.get_crew_event_flavor_text(_current_event.event_name)
	if flavor_text != "":
		_description_label.text += "\n\n[Crew] " + flavor_text

	_choice_a_button.disabled = not _can_choose_a()
	if _choice_a_button.disabled:
		_choice_a_button.tooltip_text = _requirement_text()


## Credits and hull are checked for every event type; subclasses add their own
## requirements on top via super().
func _can_choose_a() -> bool:
	var ev := _current_event
	# Negative credits mean the player pays
	if ev.choice_a_credits < 0 and GameManager.credits < abs(ev.choice_a_credits):
		return false
	# Hull damage must not kill the player
	if ev.choice_a_hull < 0 and GameManager.current_hull <= abs(ev.choice_a_hull):
		return false
	if _is_wasted_repair():
		return false
	return true


# ── Outcome resolution ───────────────────────────────────────────────────────

## Crew event skill raises the odds; a chance of 1.0 or more never rolls.
func _roll_succeeds(chance: float) -> bool:
	var effective_chance: float = chance + GameManager.get_event_success_bonus()
	return effective_chance >= 1.0 or randf() < effective_chance


func _resolve_and_show(
	credits_delta: int, hull_delta: int, cargo_good: String, cargo_qty: int, description: String
) -> void:
	var actual_qty: int = _apply_outcome(credits_delta, hull_delta, cargo_good, cargo_qty)
	_show_outcome(_append_partial_note(description, cargo_good, cargo_qty, actual_qty))


func _append_partial_note(base: String, good: String, requested: int, actual: int) -> String:
	if good == "" or requested <= 0 or actual >= requested:
		return base
	if actual == 0:
		return base + "\n\nCargo hold is full — no %s could be taken." % good
	return base + "\n\nCargo hold nearly full — only %d of %d %s fit." % [actual, requested, good]


## Returns the cargo quantity that actually changed hands.
func _apply_outcome(
	credits_delta: int, hull_delta: int, cargo_good: String = "", cargo_qty: int = 0
) -> int:
	# Credits
	if credits_delta > 0:
		GameManager.add_credits(credits_delta)
	elif credits_delta < 0:
		GameManager.remove_credits(abs(credits_delta))

	# Hull. Repairs clamp at max_hull, so track what actually landed -- reporting
	# the printed value would tell a player at full hull they gained 5 HP they
	# never got, which is exactly how a paid choice reads as "nothing happened".
	var actual_hull_delta: int = hull_delta
	if hull_delta > 0:
		var before: int = GameManager.current_hull
		GameManager.current_hull = mini(before + hull_delta, GameManager.max_hull)
		actual_hull_delta = GameManager.current_hull - before
	elif hull_delta < 0:
		var before_dmg: int = GameManager.current_hull
		GameManager.current_hull = maxi(before_dmg + hull_delta, 1)
		actual_hull_delta = GameManager.current_hull - before_dmg

	# Positive cargo adds are clamped to free space so the choice is never wasted.
	var actual_cargo_qty: int = cargo_qty
	if cargo_good != "" and cargo_qty != 0:
		if cargo_qty > 0:
			actual_cargo_qty = mini(cargo_qty, GameManager.get_free_cargo_space())
			if actual_cargo_qty > 0:
				GameManager.add_cargo(cargo_good, actual_cargo_qty)
		else:
			GameManager.remove_cargo(cargo_good, abs(cargo_qty))

	var parts: Array = []
	if credits_delta != 0:
		parts.append("%+d cr" % credits_delta)
	if actual_hull_delta != 0:
		parts.append("%+d hull" % actual_hull_delta)
	if cargo_good != "" and actual_cargo_qty != 0:
		if actual_cargo_qty > 0:
			parts.append("+%d %s" % [actual_cargo_qty, cargo_good])
		else:
			parts.append("-%d %s" % [abs(actual_cargo_qty), cargo_good])
	if not parts.is_empty():
		EventLog.add_entry("%s: %s" % [_log_prefix(), ", ".join(parts)])

	return actual_cargo_qty


## Replaces the two choices with the outcome text and a single Continue button.
func _show_outcome(text: String) -> void:
	_outcome_label.text = text
	_outcome_label.visible = true
	_choice_a_button.visible = false
	_choice_b_button.visible = false

	var close_btn := Button.new()
	close_btn.text = "Continue"
	UIStyles.style_continue_button(close_btn)
	close_btn.pressed.connect(close)
	_choice_a_button.get_parent().add_child(close_btn)


func close() -> void:
	event_resolved.emit()
	queue_free()
