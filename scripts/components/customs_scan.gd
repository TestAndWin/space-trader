extends ColorRect

## Customs scan popup — triggered on arrival at non-Outlaw planets when
## carrying contraband. Offers options to handle the situation.

signal scan_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BASE_SCAN_CHANCE := 0.20
const FINE_MIN := 100
const FINE_MAX := 200
const HIDE_BASE_CHANCE := 0.30
const BRIBE_BASE_CHANCE := 0.70

const OPTION_BUTTON_SIZE := Vector2(380, 36)
# [normal, hover, pressed] per option row.
const FINE_COLORS: Array[Color] = [Color(0.7, 0.25, 0.1), Color(0.85, 0.35, 0.15), Color(0.55, 0.18, 0.08)]
const HIDE_COLORS: Array[Color] = [Color(0.4, 0.2, 0.6), Color(0.5, 0.3, 0.7), Color(0.3, 0.15, 0.45)]
const BRIBE_COLORS: Array[Color] = [Color(0.6, 0.5, 0.1), Color(0.75, 0.6, 0.15), Color(0.45, 0.35, 0.08)]

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
		if EconomyManager.is_contraband_good(gname):
			_contraband_items.append({"good_name": gname, "quantity": item["quantity"]})
	if _contraband_items.is_empty():
		return false

	# Phase Cloak (crafted upgrade): 50% chance to bypass customs scans entirely.
	if "Phase Cloak" in GameManager.installed_upgrades and randf() < 0.5:
		EventLog.add_entry("Phase Cloak masked your cargo from customs.")
		return false

	var scan_chance: float = BASE_SCAN_CHANCE + StandingManager.get_customs_scan_modifier(GameManager.current_planet)
	if GameManager.has_crew_bonus(4):  # SMUGGLE_PROTECTION
		scan_chance *= GameManager.get_crew_bonus_value(4)
	if GameManager.has_cloaking_device():
		scan_chance *= 0.4
	scan_chance = clampf(scan_chance, 0.03, 0.90)
	if randf() > scan_chance:
		return false

	var base_fine: int = randi_range(FINE_MIN, FINE_MAX)
	_fine_amount = int(round(float(base_fine) * StandingManager.get_customs_fine_modifier(GameManager.current_planet)))
	_hide_chance = _get_hide_chance()
	_bribe_success_chance = _get_bribe_success_chance()
	_bribe_cost = int(round(float(_fine_amount) * 1.6))
	_build_ui()
	visible = true
	return true


func _build_ui() -> void:
	var scaffold := UIStyles.create_event_modal_scaffold(self, 430.0, Color(1.0, 0.3, 0.2))
	var vbox: VBoxContainer = scaffold["vbox"]
	var title: Label = scaffold["title_label"]
	title.text = "CUSTOMS INSPECTION"

	var cargo_text: String = ", ".join(_contraband_items.map(func(i: Dictionary) -> String: return "%d %s" % [i["quantity"], i["good_name"]]))
	var desc: Label = scaffold["description_label"]
	desc.text = "Authorities are scanning your cargo hold. They flagged: %s." % cargo_text
	desc.custom_minimum_size = Vector2(380, 0)

	var context := Label.new()
	context.text = _build_context_text()
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
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

	_add_option("Pay Fine (%d cr)" % _fine_amount, FINE_COLORS, _on_pay_fine,
		GameManager.credits >= _fine_amount)

	_add_option("Hide Contraband (%d%% chance)" % int(round(_hide_chance * 100.0)),
		HIDE_COLORS, _on_try_hide)

	var smuggler_note: String = " — Smuggler edge" if GameManager.get_customs_bribe_bonus() > 0.0 else ""
	_add_option("Bribe Official (%d cr, %d%% success%s)" % [
			_bribe_cost, int(round(_bribe_success_chance * 100.0)), smuggler_note
		], BRIBE_COLORS, _on_bribe, GameManager.credits >= _bribe_cost)


## One full-width option row. `colors` is [normal, hover, pressed].
func _add_option(text: String, colors: Array[Color], callback: Callable, affordable: bool = true) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = OPTION_BUTTON_SIZE
	UIStyles.style_event_button(btn, colors[0], colors[1], colors[2])
	btn.pressed.connect(callback)
	btn.disabled = not affordable
	_options_container.add_child(btn)


func _current_faction() -> String:
	return StandingManager.get_planet_faction(GameManager.current_planet)


func _build_context_text() -> String:
	var faction: String = _current_faction()
	return "%s | Rep %s | Loyalty %s | Bounty %s" % [
		faction,
		StandingManager.get_reputation_tier(faction),
		StandingManager.get_loyalty_tier(GameManager.current_planet),
		StandingManager.get_bounty_tier(),
	]


func _get_hide_chance() -> float:
	var chance: float = HIDE_BASE_CHANCE + StandingManager.get_customs_hide_modifier(GameManager.current_planet)
	if GameManager.has_crew_bonus(4):  # SMUGGLE_PROTECTION
		chance += 0.20
	if GameManager.has_cloaking_device():
		chance += 0.25
	return clampf(chance, 0.05, 0.92)


func _get_bribe_success_chance() -> float:
	var chance: float = BRIBE_BASE_CHANCE + StandingManager.get_customs_hide_modifier(GameManager.current_planet) * 0.6
	match StandingManager.get_bounty_tier():
		"Wanted":
			chance -= 0.10
		"Most Wanted":
			chance -= 0.20
	if GameManager.has_crew_bonus(4):
		chance += 0.08
	chance += GameManager.get_customs_bribe_bonus()
	return clampf(chance, 0.20, 0.95)


func _on_pay_fine() -> void:
	GameManager.remove_credits(_fine_amount)
	_confiscate_contraband()

	var faction: String = _current_faction()
	var rep_tier: String = StandingManager.get_reputation_tier(faction)
	var loyalty: int = StandingManager.get_trade_loyalty(GameManager.current_planet)
	var lenient: bool = rep_tier in ["Trusted", "Allied"] and loyalty >= 30 and StandingManager.get_bounty_tier() in ["None", "Watched"]

	StandingManager.add_faction_reputation(faction, -1, "contraband warning")
	StandingManager.add_trade_loyalty(GameManager.current_planet, -2)
	if lenient:
		EventLog.add_entry("Customs warning: paid %d cr, contraband confiscated." % _fine_amount)
		_show_result("The inspector notes your history and keeps it to a warning. You lose the cargo and pay the fine, but no new bounty is filed.")
		return

	StandingManager.add_bounty(75, "contraband found")
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
	StandingManager.add_bounty(125, "resisted customs inspection")
	var faction: String = _current_faction()
	StandingManager.add_faction_reputation(faction, -2, "failed customs deception")
	StandingManager.add_trade_loyalty(GameManager.current_planet, -4)
	EventLog.add_entry("Failed to hide contraband! Fined %d cr." % penalty)
	_show_result("They find the hidden stash. The penalty escalates: heavier fine, confiscation, and a larger bounty.")


func _on_bribe() -> void:
	GameManager.remove_credits(_bribe_cost)
	if randf() < _bribe_success_chance:
		EventLog.add_entry("Bribed customs official for %d cr." % _bribe_cost)
		_show_result("The official pockets the credits and erases the inspection from the docket.")
		return

	_confiscate_contraband()
	StandingManager.add_bounty(150, "attempted bribery")
	var faction: String = _current_faction()
	StandingManager.add_faction_reputation(faction, -3, "attempted bribery")
	StandingManager.add_trade_loyalty(GameManager.current_planet, -5)
	EventLog.add_entry("Bribe failed! Contraband confiscated and bounty increased.")
	_show_result("The bribe backfires. Your cargo is confiscated, the incident is reported, and your reputation takes a hit.")


func _confiscate_contraband() -> void:
	for item in _contraband_items:
		GameManager.remove_cargo(item["good_name"], item["quantity"])


func _show_result(text: String) -> void:
	_result_label.text = text
	_result_label.visible = true
	_options_container.visible = false

	var close_btn := Button.new()
	close_btn.text = "Continue"
	close_btn.custom_minimum_size = Vector2(140, 36)
	UIStyles.style_event_button(close_btn, Color(0.2, 0.4, 0.7), Color(0.25, 0.5, 0.85), Color(0.15, 0.3, 0.55))
	close_btn.pressed.connect(close)
	_options_container.get_parent().add_child(close_btn)


func close() -> void:
	scan_closed.emit()
	queue_free()
