extends Node

## Developer tools for the hub, separate from its navigation and presentation.
signal state_changed
signal toast_requested(text: String, color: Color)

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

var _debug_label: Label
var _systems_debug_label: Label


func handle_key(key_event: InputEventKey) -> bool:
	if key_event.keycode == KEY_F5:
		GameManager.add_credits(5000)
		toast_requested.emit("CHEAT (F5): +5000 Credits", Color(0.2, 1.0, 0.2))
		state_changed.emit()
		return true

	if key_event.keycode == KEY_F6:
		GameManager.add_credits(10000)
		for p in ["Starport Alpha", "Forge World", "Green Reach", "Dust Haven", "Iron Belt", "Nova Station", "Nexus Prime"]:
			if p not in GameManager.visited_planets:
				GameManager.visited_planets.append(p)
		if "Adaptive Shields" not in GameManager.installed_upgrades:
			var shield_res: Resource = load("res://data/upgrades/crafted/adaptive_shields.tres")
			if shield_res:
				GameManager.apply_upgrade(shield_res)
		StandingManager.bounty_amount = 0
		StandingManager.bounty_changed.emit(0, "None")
		toast_requested.emit("CHEAT (F6): Boss Prerequisites Unlocked!", Color(1, 0.5, 0))
		GameManager.try_trigger_victory()
		state_changed.emit()
		return true
		
	if key_event.keycode == KEY_F7:
		PirateLordManager.heat = 100
		EncounterManager.force_enforcer_encounter = true
		if GameManager.current_planet not in PirateLordManager.active_presence_planets:
			PirateLordManager.active_presence_planets.append(GameManager.current_planet)
		toast_requested.emit("CHEAT (F7): Pirate Heat maxed & Enforcer guaranteed on next flight!", Color(1, 0.5, 0))
		state_changed.emit()
		return true

	if key_event.keycode == KEY_F9:
		if _debug_label:
			_debug_label.queue_free()
			_debug_label = null
		else:
			_debug_label = Label.new()
			_debug_label.z_index = 100
			_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_debug_label.add_theme_color_override("font_color", Color.YELLOW)
			_debug_label.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
			_debug_label.position = Vector2(10, 700)
			add_child(_debug_label)
		return true

	if key_event.keycode == KEY_F10:
		if _systems_debug_label:
			_systems_debug_label.queue_free()
			_systems_debug_label = null
		else:
			_systems_debug_label = Label.new()
			_systems_debug_label.z_index = 110
			_systems_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_systems_debug_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.85))
			_systems_debug_label.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
			_systems_debug_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
			_systems_debug_label.add_theme_constant_override("outline_size", 6)
			_systems_debug_label.position = Vector2(12, 10)
			add_child(_systems_debug_label)
			_systems_debug_label.text = _build_systems_debug_text()
		return true

	return false


func _process(_delta: float) -> void:
	if _debug_label:
		var pos: Vector2 = get_viewport().get_mouse_position()
		_debug_label.text = "X: %d  Y: %d" % [int(pos.x), int(pos.y)]
	if _systems_debug_label:
		_systems_debug_label.text = _build_systems_debug_text()


func _build_systems_debug_text() -> String:
	var current_planet_data: Resource = EconomyManager.get_planet_data(GameManager.current_planet)
	var faction: String = StandingManager.get_planet_faction(GameManager.current_planet)
	var rep: int = StandingManager.get_faction_reputation(faction)
	var rep_tier: String = StandingManager.get_reputation_tier(faction)
	var loyalty: int = StandingManager.get_trade_loyalty(GameManager.current_planet)
	var loyalty_tier: String = StandingManager.get_loyalty_tier(GameManager.current_planet)
	var bounty_tier: String = StandingManager.get_bounty_tier()
	var buy_mod: float = StandingManager.get_market_buy_modifier(GameManager.current_planet)
	var sell_mod: float = StandingManager.get_market_sell_modifier(GameManager.current_planet)
	var customs_scan_mod: float = StandingManager.get_customs_scan_modifier(GameManager.current_planet)
	var customs_fine_mod: float = StandingManager.get_customs_fine_modifier(GameManager.current_planet)
	var customs_hide_mod: float = StandingManager.get_customs_hide_modifier(GameManager.current_planet)
	var quest_reward_mod: float = StandingManager.get_quest_reward_modifier(faction)
	var quest_deadline_mod: int = StandingManager.get_quest_deadline_modifier(faction)
	var service_fee_mod: float = StandingManager.get_planet_service_fee_modifier(GameManager.current_planet)
	var chance: float = EncounterManager.estimate_encounter_chance(
		current_planet_data.danger_level if current_planet_data else 1,
		GameManager.current_planet
	)

	var rep_parts: Array[String] = []
	for f in StandingManager.faction_reputation.keys():
		rep_parts.append("%s:%d" % [str(f), int(StandingManager.faction_reputation[f])])
	rep_parts.sort()

	var quest_text := "none"
	if QuestManager.has_active_quest():
		var q: Dictionary = QuestManager.current_quest
		quest_text = "%s %d/%d | %d days" % [
			q.get("issuer_faction", "Independent"),
			q.get("stage", 1),
			q.get("chain_length", 1),
			q.get("days_left", 0)
		]

	return "DEBUG [F10]\nPlanet: %s\nLocal Faction: %s (%+d, %s)\nLoyalty: %d (%s)\nBounty: %d cr (%s)\nBuy/Sell Mod: %.2f / %.2f\nCustoms: Scan %+.0f%% | Fine x%.2f | Hide %+.0f%%\nQuest Terms: Reward %+.0f%% | Deadline %+d\nService Fee: x%.2f\nEncounter Chance: %.0f%%\nDebt: %s | Risk +%.0f%%\nQuest: %s\nTracked Goods: %d\nAll Reps: %s" % [
		GameManager.current_planet,
		faction,
		rep,
		rep_tier,
		loyalty,
		loyalty_tier,
		StandingManager.bounty_amount,
		bounty_tier,
		buy_mod,
		sell_mod,
		customs_scan_mod * 100.0,
		customs_fine_mod,
		customs_hide_mod * 100.0,
		quest_reward_mod * 100.0,
		quest_deadline_mod,
		service_fee_mod,
		chance * 100.0,
		GameManager.get_debt_status_text(),
		GameManager.get_debt_risk_modifier() * 100.0,
		quest_text,
		GameManager.trade_route_memory.size(),
		", ".join(rep_parts)
	]
