extends Node

## Player standing across the galaxy: faction reputation, planet trade loyalty, bounty.
## Plus all read-only modifier aggregations consumers (market, customs, quests, encounters)
## use to translate standing into effects.

# ── Signals ───────────────────────────────────────────────────────────────────

signal reputation_changed(faction_name: String, new_value: int, new_tier: String)
signal loyalty_changed(planet_name: String, new_value: int)
signal bounty_changed(new_amount: int, new_tier: String)


# ── Constants ─────────────────────────────────────────────────────────────────

const FACTION_NEUTRAL: int = 0

const REPUTATION_MIN: int = -100
const REPUTATION_MAX: int = 100
const REPUTATION_HOSTILE_MAX: int = -10
const REPUTATION_COLD_MAX: int = -3
const REPUTATION_TRUSTED_MIN: int = 5
const REPUTATION_ALLIED_MIN: int = 10

const FACTION_BY_PLANET_TYPE: Dictionary = {
	0: "Consortium",         # PT_INDUSTRIAL
	1: "Agri Union",         # PT_AGRICULTURAL
	2: "Mining Guild",       # PT_MINING
	3: "Helix Directorate",  # PT_TECH
	4: "Free Cartel",        # PT_OUTLAW
}

const LOYALTY_KNOWN_MIN: int = 2
const LOYALTY_REGULAR_MIN: int = 5
const LOYALTY_PREFERRED_MIN: int = 10
const LOYALTY_LOCAL_HERO_MIN: int = 20

const BOUNTY_THRESHOLD_LOW: int = 100
const BOUNTY_THRESHOLD_HIGH: int = 300


# ── State ─────────────────────────────────────────────────────────────────────

var faction_reputation: Dictionary = {}  # { faction_name: int }
var trade_loyalty: Dictionary = {}       # { planet_name: int (0..100) }
var bounty_amount: int = 0


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	init_faction_reputation()


func init_faction_reputation() -> void:
	faction_reputation.clear()
	for faction in FACTION_BY_PLANET_TYPE.values():
		faction_reputation[faction] = FACTION_NEUTRAL


func reset() -> void:
	init_faction_reputation()
	trade_loyalty.clear()
	bounty_amount = 0


func save_state() -> Dictionary:
	return {
		"faction_reputation": faction_reputation.duplicate(true),
		"trade_loyalty": trade_loyalty.duplicate(true),
		"bounty_amount": bounty_amount,
	}


func load_state(data: Dictionary) -> void:
	faction_reputation = data.get("faction_reputation", {}).duplicate(true)
	trade_loyalty = data.get("trade_loyalty", {}).duplicate(true)
	bounty_amount = int(data.get("bounty_amount", 0))
	if faction_reputation.is_empty():
		init_faction_reputation()


# ── Reputation ────────────────────────────────────────────────────────────────

func get_planet_faction(planet_name: String) -> String:
	var planet: Resource = EconomyManager.get_planet_data(planet_name)
	if planet:
		return FACTION_BY_PLANET_TYPE.get(planet.planet_type, "Independent")
	return "Independent"


func get_faction_reputation(faction_name: String) -> int:
	return int(faction_reputation.get(faction_name, FACTION_NEUTRAL))


func get_current_planet_reputation() -> int:
	var faction: String = get_planet_faction(GameManager.current_planet)
	return get_faction_reputation(faction)


func add_faction_reputation(faction_name: String, amount: int, reason: String = "") -> void:
	if amount == 0:
		return
	var current_rep: int = get_faction_reputation(faction_name)
	var previous_tier: String = get_reputation_tier(faction_name)
	var new_rep: int = clampi(current_rep + amount, REPUTATION_MIN, REPUTATION_MAX)
	faction_reputation[faction_name] = new_rep
	if current_rep == new_rep:
		return
	if reason != "":
		EventLog.add_entry("%s reputation %+d (%s)" % [faction_name, (new_rep - current_rep), reason])
	else:
		EventLog.add_entry("%s reputation %+d" % [faction_name, (new_rep - current_rep)])
	var new_tier: String = get_reputation_tier(faction_name)
	if new_tier != previous_tier:
		EventLog.add_entry("%s standing is now %s." % [faction_name, new_tier])
	reputation_changed.emit(faction_name, new_rep, new_tier)


func get_reputation_tier(faction_name: String) -> String:
	var rep: int = get_faction_reputation(faction_name)
	if rep <= REPUTATION_HOSTILE_MAX:
		return "Hostile"
	if rep <= REPUTATION_COLD_MAX:
		return "Cold"
	if rep < REPUTATION_TRUSTED_MIN:
		return "Neutral"
	if rep < REPUTATION_ALLIED_MIN:
		return "Trusted"
	return "Allied"


# ── Trade Loyalty ─────────────────────────────────────────────────────────────

func get_trade_loyalty(planet_name: String) -> int:
	return int(trade_loyalty.get(planet_name, 0))


func add_trade_loyalty(planet_name: String, amount: int) -> void:
	if amount == 0:
		return
	var current: int = trade_loyalty.get(planet_name, 0)
	var previous_tier: String = get_loyalty_tier(planet_name)
	trade_loyalty[planet_name] = clampi(current + amount, 0, 100)
	var updated: int = get_trade_loyalty(planet_name)
	var new_tier: String = get_loyalty_tier(planet_name)
	if new_tier != previous_tier:
		EventLog.add_entry("%s loyalty is now %s (%d)." % [planet_name, new_tier, updated])
	loyalty_changed.emit(planet_name, updated)


func get_trade_loyalty_gain(quantity: int, total_value: int) -> int:
	var gain: int = 1
	var bulk_bonus: int = mini(int(floor(float(maxi(quantity, 0)) / 4.0)), 2)
	var value_bonus: int = mini(int(floor(float(maxi(total_value, 0)) / 400.0)), 2)
	gain += bulk_bonus + value_bonus
	return clampi(gain, 1, 5)


func get_loyalty_tier(planet_name: String) -> String:
	var loyalty: int = get_trade_loyalty(planet_name)
	if loyalty >= LOYALTY_LOCAL_HERO_MIN:
		return "Local Hero"
	if loyalty >= LOYALTY_PREFERRED_MIN:
		return "Preferred"
	if loyalty >= LOYALTY_REGULAR_MIN:
		return "Regular"
	if loyalty >= LOYALTY_KNOWN_MIN:
		return "Known"
	return "Unknown"


# ── Bounty ────────────────────────────────────────────────────────────────────

func add_bounty(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	var previous_tier: String = get_bounty_tier()
	bounty_amount += amount
	if reason != "":
		EventLog.add_entry("Bounty +%d cr (%s). Total: %d cr" % [amount, reason, bounty_amount])
	else:
		EventLog.add_entry("Bounty +%d cr. Total: %d cr" % [amount, bounty_amount])
	var new_tier: String = get_bounty_tier()
	if new_tier != previous_tier:
		EventLog.add_entry("Bounty status is now %s." % new_tier)
	bounty_changed.emit(bounty_amount, new_tier)


func reduce_bounty(amount: int) -> void:
	var previous_tier: String = get_bounty_tier()
	bounty_amount = maxi(bounty_amount - amount, 0)
	if bounty_amount == 0:
		EventLog.add_entry("Bounty cleared!")
	else:
		EventLog.add_entry("Bounty reduced by %d cr. Remaining: %d cr" % [amount, bounty_amount])
	var new_tier: String = get_bounty_tier()
	if new_tier != previous_tier and bounty_amount > 0:
		EventLog.add_entry("Bounty status is now %s." % new_tier)
	bounty_changed.emit(bounty_amount, new_tier)


func pay_off_bounty() -> bool:
	if bounty_amount <= 0:
		return false
	if GameManager.credits < bounty_amount:
		return false
	var cost: int = bounty_amount
	GameManager.remove_credits(cost)
	bounty_amount = 0
	EventLog.add_entry("Paid off bounty of %d cr." % cost)
	bounty_changed.emit(0, "None")
	return true


func get_bounty_tier() -> String:
	if bounty_amount <= 0:
		return "None"
	if bounty_amount < BOUNTY_THRESHOLD_LOW:
		return "Watched"
	if bounty_amount < BOUNTY_THRESHOLD_HIGH:
		return "Wanted"
	return "Most Wanted"


# ── Modifier Aggregations (read-only) ─────────────────────────────────────────

func get_market_buy_modifier(planet_name: String) -> float:
	# Positive reputation gives better buy prices.
	var rep: int = get_faction_reputation(get_planet_faction(planet_name))
	return clampf(1.0 - float(rep) * 0.0012, 0.90, 1.15)


func get_market_sell_modifier(planet_name: String) -> float:
	# Positive reputation gives better sell prices.
	var rep: int = get_faction_reputation(get_planet_faction(planet_name))
	return clampf(1.0 + float(rep) * 0.0009, 0.88, 1.12)


func get_loyalty_buy_modifier(planet_name: String) -> float:
	# Max -8% discount at loyalty 100
	var loyalty: int = get_trade_loyalty(planet_name)
	return clampf(1.0 - float(loyalty) * 0.0008, 0.92, 1.0)


func get_loyalty_sell_modifier(planet_name: String) -> float:
	# Max +6% premium at loyalty 100
	var loyalty: int = get_trade_loyalty(planet_name)
	return clampf(1.0 + float(loyalty) * 0.0006, 1.0, 1.06)


func get_local_encounter_modifier(planet_name: String) -> float:
	# Bad local standing leads to more inspections; good standing lowers friction.
	var rep: int = get_faction_reputation(get_planet_faction(planet_name))
	return clampf(-float(rep) * 0.0007, -0.06, 0.07)


func get_bounty_encounter_modifier() -> float:
	if bounty_amount >= BOUNTY_THRESHOLD_HIGH:
		return 0.20
	elif bounty_amount >= BOUNTY_THRESHOLD_LOW:
		return 0.10
	return 0.0


func get_customs_scan_modifier(planet_name: String) -> float:
	var faction: String = get_planet_faction(planet_name)
	var rep: int = get_faction_reputation(faction)
	var loyalty: int = get_trade_loyalty(planet_name)
	var modifier: float = 0.0
	modifier += clampf(-float(rep) * 0.0011, -0.08, 0.12)
	modifier += clampf(float(bounty_amount) * 0.0004, 0.0, 0.15)
	modifier -= clampf(float(loyalty) * 0.0008, 0.0, 0.08)
	return clampf(modifier, -0.12, 0.25)


func get_customs_fine_modifier(planet_name: String) -> float:
	var faction: String = get_planet_faction(planet_name)
	var rep: int = get_faction_reputation(faction)
	var loyalty: int = get_trade_loyalty(planet_name)
	var modifier: float = 1.0
	modifier += clampf(-float(rep) * 0.0014, -0.08, 0.18)
	modifier += clampf(float(bounty_amount) * 0.0005, 0.0, 0.20)
	modifier -= clampf(float(loyalty) * 0.0006, 0.0, 0.06)
	return clampf(modifier, 0.85, 1.35)


func get_customs_hide_modifier(planet_name: String) -> float:
	var faction: String = get_planet_faction(planet_name)
	var rep: int = get_faction_reputation(faction)
	var loyalty: int = get_trade_loyalty(planet_name)
	var modifier: float = 0.0
	modifier += clampf(float(rep) * 0.0008, -0.08, 0.08)
	modifier += clampf(float(loyalty) * 0.0006, 0.0, 0.06)
	modifier -= clampf(float(bounty_amount) * 0.0004, 0.0, 0.12)
	return clampf(modifier, -0.15, 0.12)


func get_quest_reward_modifier(faction_name: String) -> float:
	var rep: int = get_faction_reputation(faction_name)
	return clampf(float(rep) * 0.0015, -0.10, 0.12)


func get_quest_deadline_modifier(faction_name: String) -> int:
	var rep: int = get_faction_reputation(faction_name)
	if rep <= REPUTATION_HOSTILE_MAX:
		return -1
	if rep >= 40:
		return 1
	return 0


func get_planet_service_fee_modifier(planet_name: String) -> float:
	var faction: String = get_planet_faction(planet_name)
	var rep: int = get_faction_reputation(faction)
	var loyalty: int = get_trade_loyalty(planet_name)
	var modifier: float = 1.0
	if rep <= REPUTATION_HOSTILE_MAX:
		modifier += 0.10
	elif rep <= REPUTATION_COLD_MAX:
		modifier += 0.05
	match get_bounty_tier():
		"Wanted":
			modifier += 0.04
		"Most Wanted":
			modifier += 0.08
	modifier -= clampf(float(loyalty) * 0.0005, 0.0, 0.05)
	return clampf(modifier, 0.95, 1.18)
