extends Node

const MAX_DIFFICULTY := 3

var encounter_pool: Array = []


func _ready() -> void:
	_load_encounters()


func _load_encounters() -> void:
	encounter_pool = ResourceRegistry.load_all(ResourceRegistry.ENCOUNTERS)


func should_encounter_happen(danger_level: int) -> bool:
	var target_planet: String = GameManager.travel_destination if GameManager.travel_destination != "" else GameManager.current_planet
	var chance: float = estimate_encounter_chance(danger_level, target_planet)
	return randf() < chance


func estimate_encounter_chance(danger_level: int, planet_name: String = "") -> float:
	if planet_name == "":
		planet_name = GameManager.travel_destination if GameManager.travel_destination != "" else GameManager.current_planet
	var chance: float = 0.3 + (danger_level - 1) * 0.1
	# Carrying contraband increases encounter chance
	if is_carrying_contraband():
		chance += 0.05 if GameManager.has_cloaking_device() else 0.15
	# Ship encounter reduction
	chance -= GameManager.get_encounter_reduction()
	# Crew navigator bonus
	if GameManager.has_crew_bonus(0):  # ENCOUNTER_REDUCTION
		chance -= GameManager.get_crew_bonus_value(0)
	# Galaxy event modifier
	chance += EventManager.get_encounter_modifier(planet_name)
	# Local standing and debt pressure affect inspection intensity.
	chance += GameManager.get_local_encounter_modifier(planet_name)
	chance += GameManager.get_debt_risk_modifier()
	# Difficulty modifier
	chance += GameManager.get_difficulty_encounter_modifier()
	# Bounty modifier
	chance += GameManager.get_bounty_encounter_modifier()
	return clampf(chance, 0.05, 0.90)


func is_carrying_contraband() -> bool:
	for item in GameManager.cargo:
		var gname: String = item.get("good_name", "")
		if gname == "Spice" or gname == "Stolen Tech":
			return true
	return false


func _get_difficulty_bonus() -> int:
	if GameManager.visited_planets.size() >= 6:
		return 2
	elif GameManager.visited_planets.size() >= 4:
		return 1
	return 0


func get_encounter(max_difficulty: int) -> Resource:
	var focus_planet: String = GameManager.travel_destination if GameManager.travel_destination != "" else GameManager.current_planet
	return get_encounter_for_planet(max_difficulty, focus_planet)


func get_encounter_for_planet(max_difficulty: int, planet_name: String) -> Resource:
	var effective_max: int = mini(max_difficulty + _get_difficulty_bonus(), MAX_DIFFICULTY)
	var weighted: Array[Dictionary] = []
	var total_weight: float = 0.0
	for enc in encounter_pool:
		if enc.difficulty > effective_max:
			continue
		var weight: float = _get_encounter_weight(enc, planet_name)
		if weight <= 0.0:
			continue
		total_weight += weight
		weighted.append({
			"encounter": enc,
			"weight": weight,
			"threshold": total_weight,
		})
	if weighted.is_empty():
		return null
	var roll: float = randf() * total_weight
	for entry in weighted:
		if roll <= float((entry as Dictionary).get("threshold", 0.0)):
			return (entry as Dictionary).get("encounter", null)
	return (weighted.back() as Dictionary).get("encounter", null)


func _get_encounter_weight(enc: Resource, planet_name: String) -> float:
	var name: String = enc.encounter_name
	var tags: Array[String] = EventManager.get_active_event_tags(planet_name)
	var planet: Resource = EconomyManager.get_planet_data(planet_name)
	var lawful_space: bool = planet == null or planet.planet_type != EconomyManager.PT_OUTLAW
	var faction: String = GameManager.get_planet_faction(planet_name)
	var rep_tier: String = GameManager.get_reputation_tier(faction)
	var bounty_tier: String = GameManager.get_bounty_tier()

	var weight: float = 1.0
	match name:
		"Bounty Hunter":
			weight = 0.0
			match bounty_tier:
				"Watched":
					weight = 0.8
				"Wanted":
					weight = 2.2
				"Most Wanted":
					weight = 4.5
			if weight > 0.0 and "bounty_contracts" in tags:
				weight += 0.6
		"System Patrol":
			weight = 0.35 if lawful_space else 0.08
			if lawful_space and rep_tier == "Cold":
				weight += 0.9
			elif lawful_space and rep_tier == "Hostile":
				weight += 1.8
			if lawful_space and is_carrying_contraband():
				weight += 1.0
			if "security_crackdown" in tags or "blockade" in tags:
				weight += 1.6
			if "bounty_contracts" in tags:
				weight += 0.8
		"Pirate Raider":
			weight = 1.0
			if "pirate_activity" in tags or "bounty_contracts" in tags:
				weight += 1.2
			if "smuggling_window" in tags:
				weight += 0.6
		"Pirate Captain":
			weight = 0.45
			if "pirate_activity" in tags or "bounty_contracts" in tags:
				weight += 0.9
			if bounty_tier == "Wanted" or bounty_tier == "Most Wanted":
				weight += 0.4
		"Smuggler Ambush":
			weight = 0.4
			if is_carrying_contraband():
				weight += 1.0
			if "smuggling_window" in tags:
				weight += 1.2
		"Wandering Trader":
			weight = 0.7
			if "trade_agreement" in tags or "harvest_surplus" in tags:
				weight += 0.7
			if "blockade" in tags:
				weight -= 0.3
		"Rogue AI":
			weight = 0.5
			if "tech_boom" in tags or "prototype_theft" in tags:
				weight += 0.6
		"Space Anomaly":
			weight = 0.5
			if "tech_boom" in tags:
				weight += 0.3

	return maxf(weight, 0.0)
