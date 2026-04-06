extends ColorRect

## Customs scan popup — triggered on arrival at non-Outlaw planets when
## carrying contraband. Offers options to handle the situation.

signal scan_closed

const BASE_SCAN_CHANCE := 0.20
const FINE_MIN := 100
const FINE_MAX := 200
const HIDE_BASE_CHANCE := 0.30  # Base chance to hide contraband

var _contraband_items: Array = []  # [{ good_name, quantity }]
var _fine_amount: int = 0
var _result_label: Label
var _options_container: VBoxContainer


func try_scan() -> bool:
	# Only on non-Outlaw planets
	var planet_data: Resource = EconomyManager.get_planet_data(GameManager.current_planet)
	if not planet_data or planet_data.planet_type == EconomyManager.PT_OUTLAW:
		return false
	# Must carry contraband
	_contraband_items.clear()
	for item in GameManager.cargo:
		var gname: String = item.get("good_name", "")
		if gname == "Spice" or gname == "Stolen Tech":
			_contraband_items.append({"good_name": gname, "quantity": item["quantity"]})
	if _contraband_items.is_empty():
		return false
	# Scan chance
	var scan_chance: float = BASE_SCAN_CHANCE
	if GameManager.has_crew_bonus(4):  # SMUGGLE_PROTECTION
		scan_chance *= GameManager.get_crew_bonus_value(4)
	if GameManager.has_cloaking_device():
		scan_chance *= 0.4
	if randf() > scan_chance:
		return false
	_fine_amount = randi_range(FINE_MIN, FINE_MAX)
	_build_ui()
	visible = true
	return true


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
	panel_style.bg_color = Color(0.1, 0.06, 0.06, 0.95)
	panel_style.border_color = Color(0.9, 0.2, 0.15)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "CUSTOMS INSPECTION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	# Description
	var cargo_text: String = ", ".join(_contraband_items.map(func(i: Dictionary) -> String: return "%d %s" % [i["quantity"], i["good_name"]]))
	var desc := Label.new()
	desc.text = "Authorities are scanning your cargo hold! They found contraband: %s." % cargo_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(desc)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.5, 0.15, 0.1))
	vbox.add_child(sep)

	# Result label (shown after choice)
	_result_label = Label.new()
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6))
	_result_label.custom_minimum_size = Vector2(360, 0)
	_result_label.visible = false
	vbox.add_child(_result_label)

	# Options
	_options_container = VBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_options_container)

	# Option 1: Pay fine
	var fine_btn := Button.new()
	fine_btn.text = "Pay Fine (%d cr)" % _fine_amount
	fine_btn.custom_minimum_size = Vector2(360, 36)
	_apply_button_style(fine_btn, Color(0.7, 0.25, 0.1), Color(0.85, 0.35, 0.15), Color(0.55, 0.18, 0.08))
	fine_btn.pressed.connect(_on_pay_fine)
	if GameManager.credits < _fine_amount:
		fine_btn.disabled = true
	_options_container.add_child(fine_btn)

	# Option 2: Try to hide
	var hide_chance: int = int(_get_hide_chance() * 100)
	var hide_btn := Button.new()
	hide_btn.text = "Try to Hide Contraband (%d%% chance)" % hide_chance
	hide_btn.custom_minimum_size = Vector2(360, 36)
	_apply_button_style(hide_btn, Color(0.4, 0.2, 0.6), Color(0.5, 0.3, 0.7), Color(0.3, 0.15, 0.45))
	hide_btn.pressed.connect(_on_try_hide)
	_options_container.add_child(hide_btn)

	# Option 3: Bribe
	var bribe_cost: int = _fine_amount * 2
	var bribe_btn := Button.new()
	bribe_btn.text = "Bribe Official (%d cr, no bounty)" % bribe_cost
	bribe_btn.custom_minimum_size = Vector2(360, 36)
	_apply_button_style(bribe_btn, Color(0.6, 0.5, 0.1), Color(0.75, 0.6, 0.15), Color(0.45, 0.35, 0.08))
	bribe_btn.pressed.connect(_on_bribe)
	if GameManager.credits < bribe_cost:
		bribe_btn.disabled = true
	_options_container.add_child(bribe_btn)


func _get_hide_chance() -> float:
	var chance: float = HIDE_BASE_CHANCE
	if GameManager.has_crew_bonus(4):  # SMUGGLE_PROTECTION
		chance += 0.20
	if GameManager.has_cloaking_device():
		chance += 0.25
	return clampf(chance, 0.0, 0.85)


func _on_pay_fine() -> void:
	GameManager.remove_credits(_fine_amount)
	_confiscate_contraband()
	GameManager.add_bounty(75, "contraband found")
	EventLog.add_entry("Customs fine: -%d cr. Contraband confiscated." % _fine_amount)
	_show_result("You pay the fine and hand over the contraband. The authorities note your infraction.")


func _on_try_hide() -> void:
	if randf() < _get_hide_chance():
		EventLog.add_entry("Successfully hid contraband from customs!")
		_show_result("You manage to conceal the goods! The inspectors leave satisfied.")
	else:
		var penalty: int = int(_fine_amount * 1.5)
		GameManager.remove_credits(mini(penalty, GameManager.credits))
		_confiscate_contraband()
		GameManager.add_bounty(125, "resisted customs inspection")
		EventLog.add_entry("Failed to hide contraband! Fined %d cr." % penalty)
		_show_result("They find your hidden stash! The penalty is harsher: %d cr fine, contraband confiscated, and a bigger bounty." % penalty)


func _on_bribe() -> void:
	var bribe_cost: int = _fine_amount * 2
	if randf() < 0.80:
		GameManager.remove_credits(bribe_cost)
		EventLog.add_entry("Bribed customs official for %d cr." % bribe_cost)
		_show_result("The official pockets the credits and waves you through. No record of the inspection.")
	else:
		GameManager.remove_credits(bribe_cost)
		_confiscate_contraband()
		GameManager.add_bounty(150, "attempted bribery")
		EventLog.add_entry("Bribe failed! Fined + contraband confiscated + bounty.")
		_show_result("The official reports your bribe attempt! Contraband confiscated and a hefty bounty placed on your head.")


func _confiscate_contraband() -> void:
	for item in _contraband_items:
		GameManager.remove_cargo(item["good_name"], item["quantity"])
	GameManager.cargo_changed.emit()


func _show_result(text: String) -> void:
	_result_label.text = text
	_result_label.visible = true
	_options_container.visible = false

	var close_btn := Button.new()
	close_btn.text = "Continue"
	close_btn.custom_minimum_size = Vector2(140, 36)
	_apply_button_style(close_btn, Color(0.2, 0.4, 0.7), Color(0.25, 0.5, 0.85), Color(0.15, 0.3, 0.55))
	close_btn.pressed.connect(_close)
	_options_container.get_parent().add_child(close_btn)


func _apply_button_style(btn: Button, normal_color: Color, hover_color: Color, pressed_color: Color) -> void:
	for pair in [["normal", normal_color], ["hover", hover_color], ["pressed", pressed_color]]:
		var style := StyleBoxFlat.new()
		style.bg_color = pair[1]
		style.set_corner_radius_all(4)
		style.set_content_margin_all(6)
		btn.add_theme_stylebox_override(pair[0], style)


func _close() -> void:
	scan_closed.emit()
	queue_free()
