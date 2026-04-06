extends Node

var active_event: Dictionary = {}
var event_turns_remaining: int = 0
var affected_planet: String = ""

var active_chain: Dictionary = {}
var chain_stage: int = -1
var chain_turns_remaining: int = 0
var chain_context: Dictionary = {}

const EVENT_CHANCE: float = 0.3
const MIN_DURATION: int = 3
const MAX_DURATION: int = 5
const CHAIN_MIN_DURATION: int = 2
const CHAIN_MAX_DURATION: int = 4

var _planets: Array = []

var _event_pool: Array[Dictionary] = [
	{
		"id": "blockade",
		"title": "Blockade on %s!",
		"description": "Prices +40%, encounters +20%",
		"price_modifier": 1.4,
		"encounter_modifier": 0.2,
		"target": "specific_planet",
		"tags": ["blockade"],
		"chain_id": "blockade",
	},
	{
		"id": "harvest_surplus",
		"title": "Harvest surplus on %s!",
		"description": "Food Rations -50% there",
		"price_modifier": 0.5,
		"good": "Food Rations",
		"target": "agricultural_planet",
		"tags": ["harvest_surplus"],
	},
	{
		"id": "tech_boom",
		"title": "Tech Boom!",
		"description": "Electronics +30% everywhere",
		"price_modifier": 1.3,
		"good": "Electronics",
		"target": "all",
		"tags": ["tech_boom"],
		"chain_id": "tech_boom",
	},
	{
		"id": "pirate_activity",
		"title": "Pirate Activity!",
		"description": "Encounters +15%, rewards +50%",
		"encounter_modifier": 0.15,
		"reward_modifier": 1.5,
		"target": "all",
		"tags": ["pirate_activity"],
		"chain_id": "pirate_activity",
	},
	{
		"id": "trade_agreement",
		"title": "Trade Agreement!",
		"description": "Sell ratio 85% instead of 75%",
		"sell_ratio_override": 0.85,
		"target": "all",
		"tags": ["trade_agreement"],
	},
]

var _event_chains: Dictionary = {
	"blockade": [
		{
			"id": "shortage",
			"title": "Shortage on %s!",
			"description": "Food and Medicine demand spikes.",
			"target": "source_planet",
			"goods": ["Food Rations", "Medicine"],
			"price_modifier": 1.25,
			"encounter_modifier": 0.08,
			"quest_reward_modifier": 0.10,
			"quest_deadline_bonus": -1,
			"preferred_goods": ["Food Rations", "Medicine"],
			"tags": ["shortage"],
		},
		{
			"id": "smuggling_window",
			"title": "Smuggling Window near %s!",
			"description": "Contraband prices soar as patrol routes leak.",
			"target": "source_planet",
			"goods": ["Spice", "Stolen Tech"],
			"price_modifier": 1.35,
			"encounter_modifier": 0.10,
			"reward_modifier": 1.10,
			"quest_reward_modifier": 0.18,
			"preferred_goods": ["Spice", "Stolen Tech"],
			"tags": ["smuggling_window"],
		},
	],
	"tech_boom": [
		{
			"id": "prototype_theft",
			"title": "Prototype Theft Ring!",
			"description": "Electronics and stolen prototypes move fast.",
			"target": "all",
			"goods": ["Electronics", "Stolen Tech"],
			"price_modifier": 1.25,
			"reward_modifier": 1.10,
			"quest_reward_modifier": 0.15,
			"quest_deadline_bonus": -1,
			"preferred_goods": ["Electronics", "Stolen Tech"],
			"tags": ["prototype_theft"],
		},
		{
			"id": "security_crackdown",
			"title": "Security Crackdown on %s!",
			"description": "Patrols tighten while investigators hunt the thieves.",
			"target": "tech_planet",
			"encounter_modifier": 0.18,
			"quest_deadline_bonus": -1,
			"tags": ["security_crackdown"],
		},
	],
	"pirate_activity": [
		{
			"id": "bounty_contracts",
			"title": "Bounty Contracts Issued!",
			"description": "Hunters flood the lanes, chasing pirate and smuggler prizes.",
			"target": "all",
			"encounter_modifier": 0.08,
			"reward_modifier": 1.20,
			"quest_reward_modifier": 0.08,
			"tags": ["bounty_contracts"],
		},
	],
}


func _ready() -> void:
	_load_planets()


func reset_state() -> void:
	_clear_active_event()
	_clear_chain()


func _load_planets() -> void:
	_planets = ResourceRegistry.load_all(ResourceRegistry.PLANETS)


func tick() -> void:
	if not active_event.is_empty():
		event_turns_remaining -= 1
		if event_turns_remaining <= 0:
			var ended_event: Dictionary = active_event.duplicate(true)
			_clear_active_event()
			if not _start_chain_from(ended_event):
				EventLog.add_entry("Event ended: %s" % ended_event.get("title", "Unknown"))
		return

	if not active_chain.is_empty():
		chain_turns_remaining -= 1
		if chain_turns_remaining <= 0:
			_advance_chain()
		return

	if randf() >= EVENT_CHANCE:
		return
	_start_random_event()


func _start_random_event() -> void:
	var candidates: Array[Dictionary] = []
	for evt in _event_pool:
		candidates.append(evt.duplicate(true))
	candidates.shuffle()

	for evt in candidates:
		var resolved: Dictionary = _resolve_effect(evt, {})
		if resolved.is_empty():
			continue
		active_event = resolved
		affected_planet = active_event.get("affected_planet", "")
		event_turns_remaining = randi_range(
			int(active_event.get("duration_min", MIN_DURATION)),
			int(active_event.get("duration_max", MAX_DURATION))
		)
		chain_context = {
			"source_event_id": active_event.get("id", ""),
			"source_planet": affected_planet,
			"good": active_event.get("good", ""),
		}
		EventLog.add_entry("New event: %s (%d trips)" % [active_event["title"], event_turns_remaining])
		return


func _start_chain_from(ended_event: Dictionary) -> bool:
	var chain_id: String = ended_event.get("chain_id", "")
	if chain_id == "" or not _event_chains.has(chain_id):
		_clear_chain()
		return false

	chain_context = {
		"source_event_id": ended_event.get("id", ""),
		"source_planet": ended_event.get("affected_planet", ""),
		"good": ended_event.get("good", ""),
	}
	active_chain = {
		"chain_id": chain_id,
	}
	chain_stage = -1
	return _advance_chain()


func _advance_chain() -> bool:
	if active_chain.is_empty():
		return false
	var chain_id: String = active_chain.get("chain_id", "")
	var stages: Array = _event_chains.get(chain_id, [])
	chain_stage += 1
	if chain_stage >= stages.size():
		EventLog.add_entry("Event chain ended: %s" % chain_id.capitalize())
		_clear_chain()
		return false

	var stage_def: Dictionary = (stages[chain_stage] as Dictionary).duplicate(true)
	stage_def["chain_id"] = chain_id
	stage_def["chain_stage"] = chain_stage + 1
	var resolved: Dictionary = _resolve_effect(stage_def, chain_context)
	if resolved.is_empty():
		_clear_chain()
		return false
	active_chain = resolved
	active_chain["chain_id"] = chain_id
	active_chain["chain_stage"] = chain_stage + 1
	chain_turns_remaining = randi_range(
		int(active_chain.get("duration_min", CHAIN_MIN_DURATION)),
		int(active_chain.get("duration_max", CHAIN_MAX_DURATION))
	)
	EventLog.add_entry("Event chain: %s (%d trips)" % [active_chain.get("title", "Unknown"), chain_turns_remaining])
	return true


func _resolve_effect(effect: Dictionary, context: Dictionary) -> Dictionary:
	var resolved: Dictionary = effect.duplicate(true)
	var target: String = resolved.get("target", "all")
	var planet_name: String = ""

	match target:
		"specific_planet":
			planet_name = _pick_random_planet_except_current()
		"agricultural_planet":
			planet_name = _pick_planet_by_type(EconomyManager.PT_AGRICULTURAL)
		"tech_planet":
			planet_name = _pick_planet_by_type(EconomyManager.PT_TECH)
		"source_planet":
			planet_name = str(context.get("source_planet", ""))
		"all":
			planet_name = ""
		_:
			planet_name = ""

	if target != "all" and planet_name == "":
		return {}

	resolved["affected_planet"] = planet_name
	var title: String = resolved.get("title", "Unknown Event")
	if title.find("%s") != -1 and planet_name != "":
		resolved["title"] = title % planet_name
	return resolved


func _clear_active_event() -> void:
	active_event.clear()
	event_turns_remaining = 0
	affected_planet = ""


func _clear_chain() -> void:
	active_chain.clear()
	chain_stage = -1
	chain_turns_remaining = 0
	chain_context.clear()


func _pick_random_planet_except_current() -> String:
	var options: Array = []
	for planet in _planets:
		if planet.planet_name != GameManager.current_planet:
			options.append(planet.planet_name)
	if options.is_empty():
		return ""
	return options[randi() % options.size()]


func _pick_planet_by_type(planet_type: int) -> String:
	var options: Array = []
	for planet in _planets:
		if planet.planet_type == planet_type:
			options.append(planet.planet_name)
	if options.is_empty():
		return ""
	return options[randi() % options.size()]


func _get_active_effects() -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	if not active_event.is_empty():
		effects.append(active_event)
	if not active_chain.is_empty():
		effects.append(active_chain)
	return effects


func _effect_applies_to(effect: Dictionary, planet_name: String, good_name: String = "") -> bool:
	var effect_planet: String = effect.get("affected_planet", "")
	if effect_planet != "" and effect_planet != planet_name:
		return false
	if good_name == "":
		return true
	var effect_good: String = effect.get("good", "")
	if effect_good != "":
		return effect_good == good_name
	var goods: Array = effect.get("goods", [])
	return goods.is_empty() or good_name in goods


func _multiply_modifiers(entries: Array) -> float:
	var value: float = 1.0
	for entry in entries:
		value *= float((entry as Dictionary).get("modifier", 1.0))
	return value


# ── Public API ───────────────────────────────────────────────────────────────

func get_price_modifiers_for(planet_name: String, good_name: String) -> Array:
	var modifiers: Array = []
	for effect in _get_active_effects():
		if not _effect_applies_to(effect, planet_name, good_name):
			continue
		if effect.has("price_modifier"):
			modifiers.append({
				"source": effect.get("title", "Event"),
				"modifier": effect.get("price_modifier", 1.0),
				"tags": effect.get("tags", []),
			})
	return modifiers


func get_price_modifier(planet_name: String, good_name: String) -> float:
	return _multiply_modifiers(get_price_modifiers_for(planet_name, good_name))


func get_encounter_modifiers(planet_name: String = "") -> Array:
	if planet_name == "":
		planet_name = GameManager.travel_destination if GameManager.travel_destination != "" else GameManager.current_planet
	var modifiers: Array = []
	for effect in _get_active_effects():
		if not _effect_applies_to(effect, planet_name):
			continue
		if effect.has("encounter_modifier"):
			modifiers.append({
				"source": effect.get("title", "Event"),
				"modifier": effect.get("encounter_modifier", 0.0),
				"tags": effect.get("tags", []),
			})
	return modifiers


func get_encounter_modifier(planet_name: String = "") -> float:
	var value: float = 0.0
	for entry in get_encounter_modifiers(planet_name):
		value += float((entry as Dictionary).get("modifier", 0.0))
	return value


func get_sell_ratio_override(planet_name: String = "") -> float:
	if planet_name == "":
		planet_name = GameManager.current_planet
	var override_ratio: float = 0.0
	for effect in _get_active_effects():
		if not _effect_applies_to(effect, planet_name):
			continue
		override_ratio = maxf(override_ratio, float(effect.get("sell_ratio_override", 0.0)))
	return override_ratio


func get_reward_modifier() -> float:
	var modifier: float = 1.0
	for effect in _get_active_effects():
		modifier *= float(effect.get("reward_modifier", 1.0))
	return modifier


func get_active_event_tags(planet_name: String = "") -> Array[String]:
	if planet_name == "":
		planet_name = GameManager.travel_destination if GameManager.travel_destination != "" else GameManager.current_planet
	var tags: Array[String] = []
	for effect in _get_active_effects():
		if not _effect_applies_to(effect, planet_name):
			continue
		for tag in effect.get("tags", []):
			var tag_text: String = str(tag)
			if tag_text not in tags:
				tags.append(tag_text)
	return tags


func get_quest_context(planet_name: String) -> Dictionary:
	var reward_modifier: float = 0.0
	var deadline_bonus: int = 0
	var preferred_goods: Array[String] = []
	var notes: Array[String] = []
	var tags: Array[String] = get_active_event_tags(planet_name)

	for effect in _get_active_effects():
		if not _effect_applies_to(effect, planet_name):
			continue
		reward_modifier += float(effect.get("quest_reward_modifier", 0.0))
		deadline_bonus += int(effect.get("quest_deadline_bonus", 0))
		for good in effect.get("preferred_goods", []):
			var good_name: String = str(good)
			if good_name not in preferred_goods:
				preferred_goods.append(good_name)
		if effect.has("title"):
			notes.append(str(effect.get("title", "")))

	return {
		"reward_modifier": reward_modifier,
		"deadline_bonus": deadline_bonus,
		"preferred_goods": preferred_goods,
		"tags": tags,
		"notes": notes,
	}


func get_planet_status_lines(planet_name: String) -> Array[String]:
	var lines: Array[String] = []
	for effect in _get_active_effects():
		if not _effect_applies_to(effect, planet_name):
			continue
		var title: String = str(effect.get("title", ""))
		var desc: String = str(effect.get("description", ""))
		if desc != "":
			lines.append("%s: %s" % [title, desc])
		elif title != "":
			lines.append(title)
	return lines


func get_travel_warning_text(planet_name: String) -> String:
	var tags: Array[String] = get_active_event_tags(planet_name)
	if "security_crackdown" in tags:
		return "Patrol routes intensified near %s." % planet_name
	if "smuggling_window" in tags:
		return "Smuggling window active near %s." % planet_name
	if "blockade" in tags:
		return "Traffic control is strict around %s." % planet_name
	if "shortage" in tags:
		return "Supply stress reported on %s." % planet_name
	if "bounty_contracts" in tags:
		return "Hunters are active across nearby routes."
	return ""


func get_event_display_text() -> String:
	if not active_event.is_empty():
		return "%s - %s (%d trips left)" % [
			active_event.get("title", "Unknown Event"),
			active_event.get("description", ""),
			event_turns_remaining,
		]
	if not active_chain.is_empty():
		return "%s - %s (%d trips left)" % [
			active_chain.get("title", "Unknown Event"),
			active_chain.get("description", ""),
			chain_turns_remaining,
		]
	return ""


# ── Save / Load ──────────────────────────────────────────────────────────────

func save_data() -> Dictionary:
	return {
		"active_event": active_event.duplicate(true),
		"event_turns_remaining": event_turns_remaining,
		"affected_planet": affected_planet,
		"active_chain": active_chain.duplicate(true),
		"chain_stage": chain_stage,
		"chain_turns_remaining": chain_turns_remaining,
		"chain_context": chain_context.duplicate(true),
	}


func load_data(data: Dictionary) -> void:
	active_event = data.get("active_event", {}).duplicate(true)
	event_turns_remaining = int(data.get("event_turns_remaining", 0))
	affected_planet = data.get("affected_planet", "")
	active_chain = data.get("active_chain", {}).duplicate(true)
	chain_stage = int(data.get("chain_stage", -1))
	chain_turns_remaining = int(data.get("chain_turns_remaining", 0))
	chain_context = data.get("chain_context", {}).duplicate(true)
