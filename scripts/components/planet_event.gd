extends ColorRect

## Planet arrival event popup — random events triggered when landing on a planet.
## Call try_trigger(planet_type) from planet_screen. If it returns true the popup
## is visible; otherwise nothing happens.

signal event_resolved

const TRIGGER_CHANCE := 0.25
# All loaded event resources
var _all_events: Array = []
# Currently displayed event
var _current_event: Resource = null

var _title_label: Label
var _description_label: Label
var _outcome_label: Label
var _choice_a_button: Button
var _choice_b_button: Button


# ── Public API ───────────────────────────────────────────────────────────────

func try_trigger(planet_type: int) -> bool:
	_load_events()
	if randf() > TRIGGER_CHANCE:
		return false
	var matching: Array = []
	for ev in _all_events:
		if ev.planet_type == planet_type:
			matching.append(ev)
	if matching.is_empty():
		return false
	_current_event = matching[randi() % matching.size()]
	_show_event()
	visible = true
	return true


# ── Data loading ─────────────────────────────────────────────────────────────

func _load_events() -> void:
	if not _all_events.is_empty():
		return
	_all_events = ResourceRegistry.load_all(ResourceRegistry.PLANET_EVENTS)


# ── UI construction ──────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	# CenterContainer (full screen)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	# PanelContainer
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	panel_style.border_color = Color(0.3, 0.5, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	# VBoxContainer
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
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
	sep.add_theme_color_override("separator", Color(0.2, 0.35, 0.55))
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

	# Check if choice A is available
	_choice_a_button.disabled = not _can_choose_a()
	if _choice_a_button.disabled:
		_choice_a_button.tooltip_text = _get_requirement_text()


func _can_choose_a() -> bool:
	var ev := _current_event
	# Check credit cost (negative credits means player pays)
	if ev.choice_a_credits < 0 and GameManager.credits < abs(ev.choice_a_credits):
		return false
	# Check required cargo
	if ev.choice_a_requires_good != "" and ev.choice_a_requires_qty > 0:
		var owned := _get_cargo_qty(ev.choice_a_requires_good)
		if owned < ev.choice_a_requires_qty:
			return false
	# Check cargo space for adds
	if ev.choice_a_cargo_good != "" and ev.choice_a_cargo_qty > 0:
		if not GameManager.can_add_cargo(ev.choice_a_cargo_good, ev.choice_a_cargo_qty):
			return false
	# Check hull damage won't kill the player
	if ev.choice_a_hull < 0 and GameManager.current_hull <= abs(ev.choice_a_hull):
		return false
	return true


func _get_requirement_text() -> String:
	var ev := _current_event
	var parts: Array = []
	if ev.choice_a_credits < 0 and GameManager.credits < abs(ev.choice_a_credits):
		parts.append("Need %d credits" % abs(ev.choice_a_credits))
	if ev.choice_a_requires_good != "" and ev.choice_a_requires_qty > 0:
		var owned := _get_cargo_qty(ev.choice_a_requires_good)
		if owned < ev.choice_a_requires_qty:
			parts.append("Need %d %s" % [ev.choice_a_requires_qty, ev.choice_a_requires_good])
	if ev.choice_a_cargo_good != "" and ev.choice_a_cargo_qty > 0:
		if not GameManager.can_add_cargo(ev.choice_a_cargo_good, ev.choice_a_cargo_qty):
			parts.append("Not enough cargo space")
	if ev.choice_a_hull < 0 and GameManager.current_hull <= abs(ev.choice_a_hull):
		parts.append("Hull too low")
	return ". ".join(parts)


func _get_cargo_qty(good_name: String) -> int:
	for item in GameManager.cargo:
		if item["good_name"] == good_name:
			return item["quantity"]
	return 0


# ── Choice handlers ──────────────────────────────────────────────────────────

func _on_choice_a() -> void:
	var ev := _current_event
	# Special case: events with random outcomes (e.g. tech_experiment)
	if ev.has_random_outcome:
		_apply_tech_experiment()
		return
	_apply_outcome(ev.choice_a_credits, ev.choice_a_hull, ev.choice_a_cargo_good, ev.choice_a_cargo_qty)
	_show_outcome(ev.choice_a_description)


func _on_choice_b() -> void:
	var ev := _current_event
	_apply_outcome(ev.choice_b_credits, ev.choice_b_hull, ev.choice_b_cargo_good, ev.choice_b_cargo_qty)
	_show_outcome(ev.choice_b_description)


func _apply_tech_experiment() -> void:
	if randf() < 0.5:
		# Success
		GameManager.add_credits(300)
		EventLog.add_entry("Experiment succeeded! Earned 300 credits.")
		_show_outcome("The experiment is a success! The researcher pays you 300 credits.")
	else:
		# Failure
		GameManager.current_hull = maxi(GameManager.current_hull - 10, 1)
		EventLog.add_entry("Experiment failed! Hull took 10 damage.")
		_show_outcome("The experiment goes wrong! Your hull takes 10 damage.")


func _apply_outcome(credits_delta: int, hull_delta: int, cargo_good: String, cargo_qty: int) -> void:
	# Credits
	if credits_delta > 0:
		GameManager.add_credits(credits_delta)
	elif credits_delta < 0:
		GameManager.remove_credits(abs(credits_delta))

	# Hull
	if hull_delta > 0:
		GameManager.current_hull = mini(GameManager.current_hull + hull_delta, GameManager.max_hull)
	elif hull_delta < 0:
		GameManager.current_hull = maxi(GameManager.current_hull + hull_delta, 1)

	# Cargo
	if cargo_good != "" and cargo_qty != 0:
		if cargo_qty > 0:
			GameManager.add_cargo(cargo_good, cargo_qty)
		else:
			GameManager.remove_cargo(cargo_good, abs(cargo_qty))

	# Log entry
	var parts: Array = []
	if credits_delta != 0:
		parts.append("%+d credits" % credits_delta)
	if hull_delta != 0:
		parts.append("%+d hull" % hull_delta)
	if cargo_good != "" and cargo_qty != 0:
		if cargo_qty > 0:
			parts.append("+%d %s" % [cargo_qty, cargo_good])
		else:
			parts.append("-%d %s" % [abs(cargo_qty), cargo_good])
	if not parts.is_empty():
		EventLog.add_entry("Planet event: " + ", ".join(parts))


func _show_outcome(text: String) -> void:
	_outcome_label.text = text
	_outcome_label.visible = true
	_choice_a_button.visible = false
	_choice_b_button.visible = false

	# Replace buttons with a Close button
	var close_btn := Button.new()
	close_btn.text = "Continue"
	close_btn.custom_minimum_size = Vector2(140, 36)
	_apply_button_style(close_btn, Color(0.2, 0.4, 0.7), Color(0.25, 0.5, 0.85), Color(0.15, 0.3, 0.55))
	close_btn.pressed.connect(_close)
	_choice_a_button.get_parent().add_child(close_btn)


func _close() -> void:
	event_resolved.emit()
	queue_free()
