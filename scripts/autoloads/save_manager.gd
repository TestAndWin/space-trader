extends Node

const SAVE_PATH := "user://savegame.json"


func save_game() -> void:
	var save_data: Dictionary = {
		"player_name": GameManager.player_name,
		"credits": GameManager.credits,
		"max_hull": GameManager.max_hull,
		"current_hull": GameManager.current_hull,
		"max_shield": GameManager.max_shield,
		"current_shield": GameManager.current_shield,
		"cargo_capacity": GameManager.cargo_capacity,
		"cargo": GameManager.cargo.duplicate(true),
		"hand_size": GameManager.hand_size,
		"energy_per_turn": GameManager.energy_per_turn,
		"current_planet": GameManager.current_planet,
		"visited_planets": GameManager.visited_planets.duplicate(),
		"total_trades": GameManager.total_trades,
		"total_encounters_won": GameManager.total_encounters_won,
		"total_flights": GameManager.total_flights,
		"current_ship": GameManager.current_ship,
		"installed_upgrades": GameManager.installed_upgrades.duplicate(),
		"crew": GameManager.crew.duplicate(),
		"deck_cards": _serialize_deck(),
		"event_log": EventLog.get_entries() if has_node("/root/EventLog") else [],
		"event_manager": EventManager.save_data(),
		"quest_current": QuestManager.current_quest.duplicate() if QuestManager.current_quest.size() > 0 else {},
		"quest_available": QuestManager.available_quests.duplicate(true),
	}
	var json_string := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json_string := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		return false
	var data: Dictionary = json.data
	GameManager.player_name = data.get("player_name", "Pilot")
	GameManager.credits = int(data.get("credits", 1000))
	GameManager.max_hull = int(data.get("max_hull", 30))
	GameManager.current_hull = int(data.get("current_hull", 30))
	GameManager.max_shield = int(data.get("max_shield", 10))
	GameManager.current_shield = int(data.get("current_shield", 10))
	GameManager.cargo_capacity = int(data.get("cargo_capacity", 10))
	GameManager.cargo = data.get("cargo", [])
	GameManager.hand_size = int(data.get("hand_size", 5))
	GameManager.energy_per_turn = int(data.get("energy_per_turn", 3))
	GameManager.current_planet = data.get("current_planet", "Starport Alpha")
	GameManager.visited_planets = data.get("visited_planets", [])
	GameManager.total_trades = int(data.get("total_trades", 0))
	GameManager.total_encounters_won = int(data.get("total_encounters_won", 0))
	GameManager.total_flights = int(data.get("total_flights", 0))
	GameManager.current_ship = data.get("current_ship", "res://data/ships/scout.tres")
	GameManager.installed_upgrades = data.get("installed_upgrades", [])
	GameManager.crew = data.get("crew", [])
	_deserialize_deck(data.get("deck_cards", []))
	# Restore event log
	if has_node("/root/EventLog"):
		var entries: Array = data.get("event_log", [])
		EventLog.set_entries(entries)
	# Restore event manager
	EventManager.load_data(data.get("event_manager", {}))
	# Restore quest state
	QuestManager.current_quest = data.get("quest_current", {})
	QuestManager.available_quests = data.get("quest_available", {})
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _serialize_deck() -> Array:
	var card_paths: Array = []
	for card in GameManager.deck:
		if card and card.resource_path != "":
			card_paths.append(card.resource_path)
	return card_paths


func _deserialize_deck(card_paths: Array) -> void:
	GameManager.deck.clear()
	for path in card_paths:
		var card: Resource = load(path)
		if card:
			GameManager.deck.append(card)
