extends Node

var available_quests: Dictionary = {}  # { planet_name: quest_data } — not yet accepted
var current_quest: Dictionary = {}     # the single active quest, or empty

const DEADLINE_MIN := 3
const DEADLINE_MAX := 5
const PENALTY_RATIO := 0.4


func _ready() -> void:
	generate_quests()


func generate_quests() -> void:
	available_quests.clear()
	for planet in EconomyManager.planets:
		var quest := _make_quest(planet)
		if quest.size() > 0:
			available_quests[planet.planet_name] = quest


func _make_quest(planet: Resource) -> Dictionary:
	if EconomyManager.goods.is_empty():
		return {}
	var good: Resource = EconomyManager.goods[randi() % EconomyManager.goods.size()]
	# Pick destination from all planets except the origin for more variety
	var all_planet_names: Array = []
	for p in EconomyManager.planets:
		if p.planet_name != planet.planet_name:
			all_planet_names.append(p.planet_name)
	if all_planet_names.is_empty():
		return {}
	var dest: String = all_planet_names[randi() % all_planet_names.size()]
	var qty: int = randi_range(1, 3)
	var reward: int = int(good.base_price * qty * 1.8) + randi_range(50, 150)
	var deadline: int = randi_range(DEADLINE_MIN, DEADLINE_MAX)
	var penalty: int = int(reward * PENALTY_RATIO)
	return {
		"deliver_good": good.good_name,
		"deliver_qty": qty,
		"destination": dest,
		"reward_credits": reward,
		"origin": planet.planet_name,
		"turns_left": deadline,
		"penalty": penalty,
	}


func get_offer_for_planet(planet_name: String) -> Dictionary:
	if planet_name in available_quests:
		return available_quests[planet_name]
	return {}


func has_active_quest() -> bool:
	return current_quest.size() > 0


func accept_quest(planet_name: String) -> bool:
	if has_active_quest():
		return false
	if planet_name not in available_quests:
		return false
	current_quest = available_quests[planet_name]
	available_quests.erase(planet_name)
	return true


func tick() -> void:
	if not has_active_quest():
		return
	current_quest["turns_left"] -= 1


func check_expired_quest() -> bool:
	## Check if the active quest has expired and apply penalty.
	## Returns true if the player cannot pay and the game is lost.
	if not has_active_quest():
		return false
	if current_quest["turns_left"] > 0:
		return false
	var penalty: int = current_quest["penalty"]
	EventLog.add_entry("Quest FAILED! Deliver %d %s to %s — penalty: %d cr" % [
		current_quest["deliver_qty"], current_quest["deliver_good"],
		current_quest["destination"], penalty])
	if GameManager.credits < penalty:
		GameManager.credits = 0
		GameManager.credits_changed.emit(GameManager.credits)
		current_quest.clear()
		return true
	GameManager.remove_credits(penalty)
	current_quest.clear()
	return false


func try_complete_quest(planet_name: String) -> int:
	if not has_active_quest():
		return 0
	if current_quest["destination"] != planet_name:
		return 0
	var has_goods := false
	for item in GameManager.cargo:
		if item["good_name"] == current_quest["deliver_good"] and item["quantity"] >= current_quest["deliver_qty"]:
			has_goods = true
			break
	if not has_goods:
		return 0
	GameManager.remove_cargo(current_quest["deliver_good"], current_quest["deliver_qty"])
	var reward: int = current_quest["reward_credits"]
	# Ship quest reward bonus
	var quest_bonus: float = GameManager.get_quest_reward_bonus()
	if quest_bonus > 0.0:
		reward = int(round(reward * (1.0 + quest_bonus)))
	GameManager.add_credits(reward)
	EventLog.add_entry("Quest complete! Delivered %d %s. +%d cr" % [
		current_quest["deliver_qty"], current_quest["deliver_good"], reward])
	current_quest.clear()
	return reward
