extends Node

const MAX_DIFFICULTY := 3

var encounter_pool: Array = []


func _ready() -> void:
	_load_encounters()


func _load_encounters() -> void:
	encounter_pool = ResourceRegistry.load_all(ResourceRegistry.ENCOUNTERS)


func should_encounter_happen(danger_level: int) -> bool:
	var chance: float = estimate_encounter_chance(danger_level, GameManager.current_planet)
	return randf() < chance


func estimate_encounter_chance(danger_level: int, planet_name: String = "") -> float:
	if planet_name == "":
		planet_name = GameManager.current_planet
	var chance: float = 0.3 + (danger_level - 1) * 0.1
	# Carrying contraband increases encounter chance
	if is_carrying_contraband():
		chance += 0.15
	# Ship encounter reduction
	chance -= GameManager.get_encounter_reduction()
	# Crew navigator bonus
	if GameManager.has_crew_bonus(0):  # ENCOUNTER_REDUCTION
		chance -= GameManager.get_crew_bonus_value(0)
	# Galaxy event modifier
	chance += EventManager.get_encounter_modifier()
	# Local standing and debt pressure affect inspection intensity.
	chance += GameManager.get_local_encounter_modifier(planet_name)
	chance += GameManager.get_debt_risk_modifier()
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
	var effective_max: int = mini(max_difficulty + _get_difficulty_bonus(), MAX_DIFFICULTY)
	var filtered: Array = []
	for enc in encounter_pool:
		if enc.difficulty <= effective_max:
			filtered.append(enc)
	if filtered.is_empty():
		return null
	return filtered[randi() % filtered.size()]
