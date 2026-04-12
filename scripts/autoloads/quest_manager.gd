extends Node

var available_quests: Dictionary = {}  # { planet_name: quest_data } — not yet accepted
var current_quest: Dictionary = {}     # the single active quest, or empty
var next_chain_id: int = 1

const DEADLINE_MIN := 3
const DEADLINE_MAX := 5
const PENALTY_RATIO := 0.4
const CHAIN_CHANCE := 0.35
const MAX_CHAIN_LENGTH := 3
const STAGE_REWARD_MULT := 1.25
const REPUTATION_REWARD_BASE := 2
const REPUTATION_FAIL_PENALTY := -4
const QUEST_FLAVORS: Array[String] = [
	"Priority route",
	"Sensitive shipment",
	"Time-critical manifest",
	"Escrow courier run",
]


func _ready() -> void:
	generate_quests()


func generate_quests() -> void:
	available_quests.clear()
	for planet in EconomyManager.planets:
		var quality: Dictionary = get_offer_quality_for_planet(planet.planet_name)
		if bool(quality.get("blocked", false)):
			continue
		var chain_length: int = _roll_chain_length(quality)
		var quest := _make_quest(planet, 1, _next_chain_id(), chain_length)
		if quest.size() > 0:
			available_quests[planet.planet_name] = quest


func can_offer_quest(planet_name: String) -> bool:
	return not bool(get_offer_quality_for_planet(planet_name).get("blocked", false))


func get_offer_quality_for_planet(planet_name: String) -> Dictionary:
	var faction: String = GameManager.get_planet_faction(planet_name)
	var rep_tier: String = GameManager.get_reputation_tier(faction)
	var loyalty_tier: String = GameManager.get_loyalty_tier(planet_name)
	var bounty_tier: String = GameManager.get_bounty_tier()
	var planet: Resource = EconomyManager.get_planet_data(planet_name)
	var is_outlaw: bool = planet != null and planet.planet_type == EconomyManager.PT_OUTLAW

	var reward_modifier: float = GameManager.get_quest_reward_modifier(faction)
	var deadline_bonus: int = GameManager.get_quest_deadline_modifier(faction)
	var chain_bonus: float = 0.0
	var notes: Array[String] = []
	var blocked: bool = false
	var blocked_reason: String = ""

	match loyalty_tier:
		"Regular":
			reward_modifier += 0.03
			chain_bonus += 0.04
			notes.append("Regular local trade gives slightly better contracts.")
		"Preferred":
			reward_modifier += 0.06
			chain_bonus += 0.08
			notes.append("Preferred trader status improves local offers.")
		"Local Hero":
			reward_modifier += 0.10
			chain_bonus += 0.14
			notes.append("Local hero status unlocks premium trust.")

	match rep_tier:
		"Trusted":
			chain_bonus += 0.08
			notes.append("%s trusts you with better routes." % faction)
		"Allied":
			chain_bonus += 0.16
			notes.append("%s treats you like an insider." % faction)
		"Cold":
			notes.append("%s keeps contract terms cautious." % faction)
		"Hostile":
			if not is_outlaw:
				blocked = true
				blocked_reason = "Local standing too low for public contracts."

	if not blocked and bounty_tier == "Most Wanted" and not is_outlaw:
		blocked = true
		blocked_reason = "Authorities refuse contracts while you are Most Wanted."
	elif bounty_tier == "Wanted" and not is_outlaw:
		reward_modifier -= 0.05
		deadline_bonus -= 1
		notes.append("Wanted status makes officials rush or underpay your jobs.")

	var event_context: Dictionary = EventManager.get_quest_context(planet_name)
	reward_modifier += float(event_context.get("reward_modifier", 0.0))
	deadline_bonus += int(event_context.get("deadline_bonus", 0))
	chain_bonus += 0.05 if "smuggling_window" in event_context.get("tags", []) else 0.0
	for note in event_context.get("notes", []):
		var note_text: String = str(note)
		if note_text not in notes:
			notes.append(note_text)

	return {
		"blocked": blocked,
		"blocked_reason": blocked_reason,
		"issuer_faction": faction,
		"issuer_rep_tier": rep_tier,
		"loyalty_tier": loyalty_tier,
		"reward_modifier": reward_modifier,
		"deadline_bonus": deadline_bonus,
		"chain_bonus": chain_bonus,
		"preferred_goods": event_context.get("preferred_goods", []),
		"event_tags": event_context.get("tags", []),
		"notes": notes,
	}


func _make_quest(
	planet: Resource,
	stage: int = 1,
	chain_id: int = -1,
	chain_length: int = 1
) -> Dictionary:
	var quality: Dictionary = get_offer_quality_for_planet(planet.planet_name)
	if bool(quality.get("blocked", false)):
		return {}
	var good: Resource = _pick_quest_good(planet.planet_name, quality)
	if good == null:
		return {}

	var all_planet_names: Array = []
	for p in EconomyManager.planets:
		if p.planet_name != planet.planet_name:
			all_planet_names.append(p.planet_name)
	if all_planet_names.is_empty():
		return {}

	var dest: String = _pick_destination_planet(planet.planet_name, all_planet_names, good.good_name)
	var route_hops: int = _get_route_hops(planet.planet_name, dest)
	if route_hops < 0:
		return {}
	var qty: int = randi_range(1, 3) + (1 if stage >= 3 else 0)
	var stage_mult: float = pow(STAGE_REWARD_MULT, float(maxi(stage - 1, 0)))
	var reward_mult: float = maxf(0.75, 1.0 + float(quality.get("reward_modifier", 0.0)))
	var deadline: int = (
		randi_range(DEADLINE_MIN, DEADLINE_MAX)
		+ maxi(stage - 1, 0)
		+ GameManager.get_difficulty_quest_bonus()
		+ int(quality.get("deadline_bonus", 0))
	)
	deadline = maxi(deadline, maxi(route_hops, 1))
	# QUEST_NEGOTIATION crew bonus: +1 deadline, +10% reward
	var negotiation_bonus: float = 0.0
	for res in GameManager.get_crew_resources():
		if res.secondary_bonus_type == CrewData.CrewBonus.QUEST_NEGOTIATION:
			negotiation_bonus += res.secondary_bonus_value
	if negotiation_bonus > 0.0:
		deadline += 1
		reward_mult *= (1.0 + 0.10 * negotiation_bonus)
	var reward: int = int((good.base_price * qty * 1.8 + randi_range(50, 150)) * stage_mult * reward_mult)
	var penalty: int = int(reward * PENALTY_RATIO)
	var issuer_faction: String = str(quality.get("issuer_faction", GameManager.get_planet_faction(planet.planet_name)))
	if chain_id < 0:
		chain_id = _next_chain_id()

	return {
		"deliver_good": good.good_name,
		"deliver_qty": qty,
		"destination": dest,
		"route_hops": route_hops,
		"reward_credits": reward,
		"origin": planet.planet_name,
		"turns_left": deadline,
		"penalty": penalty,
		"stage": stage,
		"chain_length": chain_length,
		"chain_id": chain_id,
		"issuer_faction": issuer_faction,
		"issuer_rep_tier": quality.get("issuer_rep_tier", "Neutral"),
		"flavor": _pick_flavor(dest, good.good_name),
		"offer_reward_modifier": quality.get("reward_modifier", 0.0),
		"offer_deadline_modifier": quality.get("deadline_bonus", 0),
		"event_tags": quality.get("event_tags", []),
		"quality_notes": quality.get("notes", []).duplicate(),
	}


func get_offer_for_planet(planet_name: String) -> Dictionary:
	var quality: Dictionary = get_offer_quality_for_planet(planet_name)
	if bool(quality.get("blocked", false)):
		available_quests.erase(planet_name)
		return {
			"blocked": true,
			"blocked_reason": quality.get("blocked_reason", "No quests available"),
			"issuer_faction": quality.get("issuer_faction", "Independent"),
			"issuer_rep_tier": quality.get("issuer_rep_tier", "Neutral"),
			"quality_notes": quality.get("notes", []).duplicate(),
		}

	var refresh_offer: bool = planet_name not in available_quests
	if not refresh_offer:
		refresh_offer = not _offer_matches_quality(available_quests[planet_name], quality)

	if refresh_offer:
		var planet: Resource = EconomyManager.get_planet_data(planet_name)
		if planet:
			var chain_length: int = _roll_chain_length(quality)
			var quest := _make_quest(planet, 1, _next_chain_id(), chain_length)
			if quest.size() > 0:
				available_quests[planet_name] = quest

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
	if not has_active_quest():
		return false
	if current_quest["turns_left"] >= 0:
		return false
	var penalty: int = current_quest["penalty"]
	EventLog.add_entry("Quest FAILED! Deliver %d %s to %s — penalty: %d cr" % [
		current_quest["deliver_qty"], current_quest["deliver_good"],
		current_quest["destination"], penalty])
	var issuer_faction: String = current_quest.get("issuer_faction", "")
	if issuer_faction != "":
		var stage: int = int(current_quest.get("stage", 1))
		GameManager.add_faction_reputation(
			issuer_faction,
			REPUTATION_FAIL_PENALTY - maxi(stage - 1, 0),
			"quest failure"
		)
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
	var quest_bonus: float = GameManager.get_quest_reward_bonus()
	if quest_bonus > 0.0:
		reward = int(round(reward * (1.0 + quest_bonus)))
	var completed_quest: Dictionary = current_quest.duplicate(true)
	GameManager.add_credits(reward)
	GameManager.total_quests_completed += 1
	AchievementManager.check_quests(GameManager.total_quests_completed)
	_apply_reputation_on_completion(completed_quest)
	if _promote_followup_quest(planet_name, completed_quest):
		EventLog.add_entry("Quest stage %d/%d complete! +%d cr. Follow-up assigned." % [
			completed_quest.get("stage", 1),
			completed_quest.get("chain_length", 1),
			reward
		])
	else:
		EventLog.add_entry("Quest complete! Delivered %d %s. +%d cr" % [
			completed_quest["deliver_qty"], completed_quest["deliver_good"], reward
		])
		current_quest.clear()
	return reward


func _apply_reputation_on_completion(completed_quest: Dictionary) -> void:
	var issuer_faction: String = completed_quest.get("issuer_faction", "")
	if issuer_faction == "":
		return
	var stage: int = int(completed_quest.get("stage", 1))
	var rep_gain: int = REPUTATION_REWARD_BASE + stage
	GameManager.add_faction_reputation(issuer_faction, rep_gain, "quest completion")


func _promote_followup_quest(current_planet_name: String, completed_quest: Dictionary) -> bool:
	var stage: int = int(completed_quest.get("stage", 1))
	var chain_length: int = int(completed_quest.get("chain_length", 1))
	if stage >= chain_length:
		return false
	var origin_planet: Resource = EconomyManager.get_planet_data(current_planet_name)
	if origin_planet == null:
		return false
	var next_stage: int = stage + 1
	var chain_id: int = int(completed_quest.get("chain_id", _next_chain_id()))
	var next_quest: Dictionary = _make_quest(origin_planet, next_stage, chain_id, chain_length)
	if next_quest.is_empty():
		return false
	current_quest = next_quest
	return true


func _pick_quest_good(planet_name: String, quality: Dictionary) -> Resource:
	var candidates: Array = []
	var preferred: Array = quality.get("preferred_goods", [])
	if not preferred.is_empty():
		for good_name in preferred:
			var preferred_res: Resource = _find_good_by_name(str(good_name))
			if preferred_res != null:
				candidates.append(preferred_res)
	if candidates.is_empty():
		var outlaw_faction: bool = GameManager.get_planet_faction(planet_name) == GameManager.FACTION_BY_PLANET_TYPE.get(EconomyManager.PT_OUTLAW, "Free Cartel")
		for good in EconomyManager.goods:
			if good == null:
				continue
			if outlaw_faction or not bool(good.is_contraband):
				candidates.append(good)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


func _find_good_by_name(good_name: String) -> Resource:
	for good in EconomyManager.goods:
		if good and good.good_name == good_name:
			return good
	return null


func _pick_destination_planet(origin_name: String, candidates: Array, good_name: String) -> String:
	var preferred_tags: Array[String] = []
	match good_name:
		"Food Rations":
			preferred_tags = ["shortage"]
		"Medicine":
			preferred_tags = ["shortage"]
		"Spice":
			preferred_tags = ["smuggling_window"]
		"Stolen Tech":
			preferred_tags = ["smuggling_window", "prototype_theft", "security_crackdown"]
		"Electronics":
			preferred_tags = ["prototype_theft", "tech_boom", "security_crackdown"]

	if not preferred_tags.is_empty():
		var tagged_destinations: Array[String] = []
		for candidate in candidates:
			var candidate_name: String = str(candidate)
			if candidate_name == origin_name:
				continue
			var tags: Array[String] = EventManager.get_active_event_tags(candidate_name)
			for tag in preferred_tags:
				if tag in tags:
					tagged_destinations.append(candidate_name)
					break
		if not tagged_destinations.is_empty():
			return tagged_destinations[randi() % tagged_destinations.size()]

	return str(candidates[randi() % candidates.size()])


func _get_route_hops(origin_name: String, destination_name: String) -> int:
	if origin_name == "" or destination_name == "":
		return -1
	if origin_name == destination_name:
		return 0

	var visited: Dictionary = {origin_name: true}
	var frontier: Array[String] = [origin_name]
	var hops: int = 0

	while not frontier.is_empty():
		hops += 1
		var next_frontier: Array[String] = []
		for current_name in frontier:
			var planet: Resource = EconomyManager.get_planet_data(current_name)
			if planet == null:
				continue
			for neighbor in planet.connected_planets:
				var neighbor_name: String = str(neighbor)
				if neighbor_name == destination_name:
					return hops
				if visited.has(neighbor_name):
					continue
				visited[neighbor_name] = true
				next_frontier.append(neighbor_name)
		frontier = next_frontier

	return -1


func _pick_flavor(destination: String, good_name: String) -> String:
	var tags: Array[String] = EventManager.get_active_event_tags(destination)
	if "smuggling_window" in tags and good_name in ["Spice", "Stolen Tech"]:
		return "Hot window courier run"
	if "shortage" in tags and good_name in ["Food Rations", "Medicine"]:
		return "Emergency relief route"
	if ("prototype_theft" in tags or "security_crackdown" in tags) and good_name in ["Electronics", "Stolen Tech"]:
		return "Silent retrieval order"
	if "bounty_contracts" in tags:
		return "Pressure-run dispatch"
	return QUEST_FLAVORS[randi() % QUEST_FLAVORS.size()]


func _offer_matches_quality(offer: Dictionary, quality: Dictionary) -> bool:
	if offer.is_empty():
		return false
	if int(offer.get("offer_deadline_modifier", 0)) != int(quality.get("deadline_bonus", 0)):
		return false
	if absf(float(offer.get("offer_reward_modifier", 0.0)) - float(quality.get("reward_modifier", 0.0))) > 0.001:
		return false
	var offer_tags: Array = offer.get("event_tags", [])
	var quality_tags: Array = quality.get("event_tags", [])
	return offer_tags == quality_tags


func _roll_chain_length(quality: Dictionary) -> int:
	var chance: float = clampf(CHAIN_CHANCE + float(quality.get("chain_bonus", 0.0)), 0.05, 0.90)
	if randf() >= chance:
		return 1
	return randi_range(2, MAX_CHAIN_LENGTH)


func _next_chain_id() -> int:
	var id: int = next_chain_id
	next_chain_id += 1
	return id
