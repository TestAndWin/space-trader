extends Node

var active_event: Dictionary = {}
var event_turns_remaining: int = 0
var affected_planet: String = ""

const EVENT_CHANCE: float = 0.3
const MIN_DURATION: int = 3
const MAX_DURATION: int = 5

var _planets: Array = []

var _event_pool: Array[Dictionary] = [
	{"id": "blockade", "title": "Blockade on %s!", "description": "Prices +40%, encounter chance +20%", "price_modifier": 1.4, "encounter_modifier": 0.2, "target": "specific_planet"},
	{"id": "harvest_surplus", "title": "Harvest surplus on %s!", "description": "Food Rations -50% there", "price_modifier": 0.5, "good": "Food Rations", "target": "agricultural_planet"},
	{"id": "tech_boom", "title": "Tech Boom!", "description": "Electronics +30% everywhere", "price_modifier": 1.3, "good": "Electronics", "target": "all"},
	{"id": "pirate_activity", "title": "Pirate Activity!", "description": "Encounters +15%, rewards +50%", "encounter_modifier": 0.15, "reward_modifier": 1.5, "target": "all"},
	{"id": "trade_agreement", "title": "Trade Agreement!", "description": "Sell ratio 85% instead of 75%", "sell_ratio_override": 0.85, "target": "all"},
]


func _ready() -> void:
	_load_planets()


func _load_planets() -> void:
	_planets = ResourceRegistry.load_all(ResourceRegistry.PLANETS)


func tick() -> void:
	if active_event.size() > 0:
		event_turns_remaining -= 1
		if event_turns_remaining <= 0:
			var ended := active_event.duplicate()
			active_event = {}
			affected_planet = ""
			event_turns_remaining = 0
			EventLog.add_entry("Event ended: %s" % ended.get("title", "Unknown"))
		return

	# 30% chance of a new event
	if randf() >= EVENT_CHANCE:
		return

	var candidates: Array[Dictionary] = []
	for evt in _event_pool:
		candidates.append(evt.duplicate())

	candidates.shuffle()

	for evt in candidates:
		var target: String = evt.get("target", "all")
		if target == "specific_planet":
			var planet := _pick_random_planet_except_current()
			if planet == "":
				continue
			affected_planet = planet
			evt["title"] = evt["title"] % planet
		elif target == "agricultural_planet":
			var planet := _pick_agricultural_planet()
			if planet == "":
				continue
			affected_planet = planet
			evt["title"] = evt["title"] % planet
		else:
			affected_planet = ""

		active_event = evt
		event_turns_remaining = randi_range(MIN_DURATION, MAX_DURATION)
		EventLog.add_entry("New event: %s (%d trips)" % [active_event["title"], event_turns_remaining])
		return


func _pick_random_planet_except_current() -> String:
	var options: Array = []
	for planet in _planets:
		if planet.planet_name != GameManager.current_planet:
			options.append(planet.planet_name)
	if options.is_empty():
		return ""
	return options[randi() % options.size()]


func _pick_agricultural_planet() -> String:
	var options: Array = []
	for planet in _planets:
		if planet.planet_type == 1:  # PlanetType.AGRICULTURAL
			options.append(planet.planet_name)
	if options.is_empty():
		return ""
	return options[randi() % options.size()]


# ── Public API ───────────────────────────────────────────────────────────────

func get_price_modifier(planet_name: String, good_name: String) -> float:
	if active_event.size() == 0:
		return 1.0

	var has_good_filter: bool = active_event.has("good")
	var has_planet_filter: bool = affected_planet != ""

	# If event targets a specific good, only apply to that good
	if has_good_filter and active_event["good"] != good_name:
		return 1.0

	# If event targets a specific planet, only apply there
	if has_planet_filter and affected_planet != planet_name:
		return 1.0

	return active_event.get("price_modifier", 1.0)


func get_encounter_modifier() -> float:
	if active_event.size() == 0:
		return 0.0
	return active_event.get("encounter_modifier", 0.0)


func get_sell_ratio_override() -> float:
	if active_event.size() == 0:
		return 0.0
	return active_event.get("sell_ratio_override", 0.0)


func get_reward_modifier() -> float:
	if active_event.size() == 0:
		return 1.0
	return active_event.get("reward_modifier", 1.0)


func get_event_display_text() -> String:
	if active_event.size() == 0:
		return ""
	var title: String = active_event.get("title", "Unknown Event")
	var desc: String = active_event.get("description", "")
	return "%s - %s (%d trips left)" % [title, desc, event_turns_remaining]


# ── Save / Load ──────────────────────────────────────────────────────────────

func save_data() -> Dictionary:
	return {
		"active_event": active_event.duplicate(),
		"event_turns_remaining": event_turns_remaining,
		"affected_planet": affected_planet,
	}


func load_data(data: Dictionary) -> void:
	active_event = data.get("active_event", {})
	event_turns_remaining = int(data.get("event_turns_remaining", 0))
	affected_planet = data.get("affected_planet", "")
