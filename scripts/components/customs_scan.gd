extends ColorRect

## Customs scan popup — triggered on arrival at non-Outlaw planets when
## carrying contraband. Offers options to handle the situation.

signal scan_closed

const BASE_SCAN_CHANCE := 0.20
const FINE_MIN := 100
const FINE_MAX := 200
const HIDE_BASE_CHANCE := 0.30
const BRIBE_BASE_CHANCE := 0.70

var _contraband_items: Array = []  # [{ good_name, quantity }]
var _fine_amount: int = 0
var _hide_chance: float = 0.0
var _bribe_success_chance: float = 0.0
var _bribe_cost: int = 0
var _result_label: Label
var _options_container: VBoxContainer


func try_scan() -> bool:
	var planet_data: Resource = EconomyManager.get_planet_data(GameManager.current_planet)
	if planet_data == null or planet_data.planet_type == EconomyManager.PT_OUTLAW:
		return false

	_contraband_items.clear()
	for item in GameManager.cargo:
		var gname: String = item.get("good_name", "")
		if gname == "Spice" or gname == "Stolen Tech":
			_contraband_items.append({"good_name": gname, "quantity": item["quantity"]})
	if _contraband_items.is_empty():
		return false

	var scan_chance: float = BASE_SCAN_CHANCE + GameManager.get_customs_scan_modifier(GameManager.current_planet)
	if GameManager.has_crew_bonus(4):  # SMUGGLE_PROTECTION
		scan_chance *= GameManager.get_crew_bonus_value(4)
	if GameManager.has_cloaking_device():
		scan_chance *= 0.4
	scan_chance = clampf(scan_chance, 0.03, 0.90)
	if randf() > scan_chance:
		return false

	var base_fine: int = randi_range(FINE_MIN, FINE_MAX)
	_fine_amount = int(round(float(base_fine) * GameManager.get_customs_fine_modifier(GameManager.current_planet)))
	_hide_chance = _get_hide_chance()
	_bribe_success_chance = _get_bribe_success_chance()
	_bribe_cost = int(round(float(_fine_amount) * 1.6))
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
	panel.custom_minimum_size = Vector2(430, 0)
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

	var title := Label.new()
	title.text = "CUSTOMS INSPECTION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var cargo_text: String = ", ".join(_contraband_items.map(func(i: Dictionary) -> String: return "%d %s" % [i["quantity"], i["good_name"]]))
	var desc := Label.new()
	desc.text = "Authorities are scanning your cargo hold. They flagged: %s." % cargo_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc.custom_minimum_size = Vector2(380, 0)
	vbox.add_child(desc)

	var context := Label.new()
	context.text = _build_context_text()
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context.add_theme_font_size_override("font_size", 12)
	context.add_theme_color_override("font_color", Color(0.95, 0.78, 0.48))
	context.custom_minimum_size = Vector2(380, 0)
	vbox.add_child(context)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.5, 0.15, 0.1))
	vbox.add_child(sep)

	_result_label = Label.new()
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6))
	_result_label.custom_minimum_size = Vector2(380, 0)
	_result_label.visible = false
	vbox.add_child(_result_label)

	_options_container = VBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_options_container)

	var fine_btn := Button.new()
	fine_btn.text = "Pay Fine (%d cr)" % _fine_amount
	fine_btn.custom_minimum_size = Vector2(380, 36)
	_apply_button_style(fine_btn, Color(0.7, 0.25, 0.1), Color(0.85, 0.35, 0.15), Color(0.55, 0.18, 0.08))
	fine_btn.pressed.connect(_on_pay_fine)
	if GameManager.credits < _fine_amount:
		fine_btn.disabled = true
	_options_container.add_child(fine_btn)

	var hide_btn := Button.new()
	hide_btn.text = "Hide Contraband (%d%% chance)" % int(round(_hide_chance * 100.0))
	hide_btn.custom_minimum_size = Vector2(380, 36)
	_apply_button_style(hide_btn, Color(0.4, 0.2, 0.6), Color(0.5, 0.3, 0.7), Color(0.3, 0.15, 0.45))
	hide_btn.pressed.connect(_on_try_hide)
	_options_container.add_child(hide_btn)

	var bribe_btn := Button.new()
	bribe_btn.text = "Bribe Official (%d cr, %d%% success)" % [_bribe_cost, int(round(_bribe_success_chance * 100.0))]
	bribe_btn.custom_minimum_size = Vector2(380, 36)
	_apply_button_style(bribe_btn, Color(0.6, 0.5, 0.1), Color(0.75, 0.6, 0.15), Color(0.45, 0.35, 0.08))
	bribe_btn.pressed.connect(_on_bribe)
	if GameManager.credits < _bribe_cost:
		bribe_btn.disabled = true
	_options_container.add_child(bribe_btn)


func _build_context_text() -> String:
	var faction: String = GameManager.get_planet_faction(GameManager.current_planet)
	return "%s | Rep %s | Loyalty %s | Bounty %s" % [
		faction,
		GameManager.get_reputation_tier(faction),
		GameManager.get_loyalty_tier(GameManager.current_planet),
		GameManager.get_bounty_tier(),
	]


func _get_hide_chance() -> float:
	var chance: float = HIDE_BASE_CHANCE + GameManager.get_customs_hide_modifier(GameManager.current_planet)
	if GameManager.has_crew_bonus(4):  # SMUGGLE_PROTECTION
		chance += 0.20
	if GameManager.has_cloaking_device():
		chance += 0.25
	return clampf(chance, 0.05, 0.92)


func _get_bribe_success_chance() -> float:
	var chance: float = BRIBE_BASE_CHANCE + GameManager.get_customs_hide_modifier(GameManager.current_planet) * 0.6
	match GameManager.get_bounty_tier():
		"Wanted":
			chance -= 0.10
		"Most Wanted":
			chance -= 0.20
	if GameManager.has_crew_bonus(4):
		chance += 0.08
	return clampf(chance, 0.20, 0.95)


func _on_pay_fine() -> void:
	GameManager.remove_credits(_fine_amount)
	_confiscate_contraband()

	var faction: String = GameManager.get_planet_faction(GameManager.current_planet)
	var rep_tier: String = GameManager.get_reputation_tier(faction)
	var loyalty: int = GameManager.get_trade_loyalty(GameManager.current_planet)
	var lenient: bool = rep_tier in ["Trusted", "Allied"] and loyalty >= 30 and GameManager.get_bounty_tier() in ["None", "Watched"]

	GameManager.add_faction_reputation(faction, -1, "contraband warning")
	GameManager.add_trade_loyalty(GameManager.current_planet, -2)
	if lenient:
		EventLog.add_entry("Customs warning: paid %d cr, contraband confiscated." % _fine_amount)
		_show_result("The inspector notes your history and keeps it to a warning. You lose the cargo and pay the fine, but no new bounty is filed.")
		return

	GameManager.add_bounty(75, "contraband found")
	EventLog.add_entry("Customs fine: -%d cr. Contraband confiscated." % _fine_amount)
	_show_result("You pay the fine and hand over the cargo. The authorities log the incident and update your file.")


func _on_try_hide() -> void:
	if randf() < _hide_chance:
		EventLog.add_entry("Successfully hid contraband from customs!")
		_show_result("You keep calm, the scan misses the stash, and the inspectors move on.")
		return

	var penalty: int = int(round(float(_fine_amount) * 1.5))
	GameManager.remove_credits(mini(penalty, GameManager.credits))
	_confiscate_contraband()
	GameManager.add_bounty(125, "resisted customs inspection")
	var faction: String = GameManager.get_planet_faction(GameManager.current_planet)
	GameManager.add_faction_reputation(faction, -2, "failed customs deception")
	GameManager.add_trade_loyalty(GameManager.current_planet, -4)
	EventLog.add_entry("Failed to hide contraband! Fined %d cr." % penalty)
	_show_result("They find the hidden stash. The penalty escalates: heavier fine, confiscation, and a larger bounty.")


func _on_bribe() -> void:
	GameManager.remove_credits(_bribe_cost)
	if randf() < _bribe_success_chance:
		EventLog.add_entry("Bribed customs official for %d cr." % _bribe_cost)
		_show_result("The official pockets the credits and erases the inspection from the docket.")
		return

	_confiscate_contraband()
	GameManager.add_bounty(150, "attempted bribery")
	var faction: String = GameManager.get_planet_faction(GameManager.current_planet)
	GameManager.add_faction_reputation(faction, -3, "attempted bribery")
	GameManager.add_trade_loyalty(GameManager.current_planet, -5)
	EventLog.add_entry("Bribe failed! Contraband confiscated and bounty increased.")
	_show_result("The bribe backfires. Your cargo is confiscated, the incident is reported, and your reputation takes a hit.")


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
