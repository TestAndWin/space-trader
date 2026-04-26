extends Node

signal credits_changed(new_amount: int)
signal cargo_changed
signal crew_changed

const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

# Difficulty
enum Difficulty { EASY, NORMAL, HARD }
const DIFFICULTY_SETTINGS := {
	Difficulty.EASY:   { "credits": 1500, "hull": 35, "encounter_mod": -0.10, "quest_deadline_bonus": 2 },
	Difficulty.NORMAL: { "credits": 1000, "hull": 30, "encounter_mod":  0.00, "quest_deadline_bonus": 0 },
	Difficulty.HARD:   { "credits":  600, "hull": 25, "encounter_mod":  0.10, "quest_deadline_bonus": -1 },
}
var difficulty: int = Difficulty.NORMAL

# Player identity
var player_name: String = "Pilot"

# Economy
var credits: int = 1000

# Ship stats
var max_hull: int = 30
var current_hull: int = 30
var max_shield: int = 10
var current_shield: int = 10
var cargo_capacity: int = 10

# Inventory  (each entry: { "good_name": String, "quantity": int })
var cargo: Array = []

# Card / combat
var deck: Array = []
var installed_upgrades: Array = []
var removed_cards: Array = []  # Permanently removed card paths
var hand_size: int = 5
var energy_per_turn: int = 3

# Crew
const MAX_CREW: int = 3
var crew: Array = []  # Array of resource paths (String)

# Navigation
var current_planet: String = "Starport Alpha"
var travel_destination: String = ""
var travel_origin: String = ""
var visited_planets: Array = []

# Battle
var current_encounter: Resource = null
var battle_result: String = ""
var last_cargo_lost_text: String = ""

# Ship
var current_ship: String = "res://data/ships/scout.tres"
var owned_ships: Array[String] = ["res://data/ships/scout.tres"]
const SHIP_TRANSFER_FEE: int = 250

# Shipyard upgrade counters (max 3 each)
const MAX_STAT_UPGRADES: int = 3
var hull_upgrades_bought: int = 0
var shield_upgrades_bought: int = 0
var cargo_upgrades_bought: int = 0

# Ghost Run (Smuggler ability)
var ghost_run_available: bool = true

# Mission
var mission_return_planet: String = ""
var mission_done_this_landing: bool = false

# Planet arrival flag — prevents duplicate events when returning from sub-screens
var arrival_events_done: bool = false

# Statistics
var total_trades: int = 0
var total_encounters_won: int = 0
var total_flights: int = 0
var total_smuggler_deals: int = 0
var total_quests_completed: int = 0

# Factions / reputation
const FACTION_NEUTRAL := 0
const REPUTATION_MIN := -100
const REPUTATION_MAX := 100
const REPUTATION_HOSTILE_MAX := -10
const REPUTATION_COLD_MAX := -3
const REPUTATION_TRUSTED_MIN := 5
const REPUTATION_ALLIED_MIN := 10
const FACTION_BY_PLANET_TYPE := {
	0: "Consortium", # INDUSTRIAL
	1: "Agri Union", # AGRICULTURAL
	2: "Mining Guild", # MINING
	3: "Helix Directorate", # TECH
	4: "Free Cartel", # OUTLAW
}
var faction_reputation: Dictionary = {} # { faction_name: int }

# Trade loyalty per planet
var trade_loyalty: Dictionary = {}  # { planet_name: int } (0–100)
const LOYALTY_KNOWN_MIN := 2
const LOYALTY_REGULAR_MIN := 5
const LOYALTY_PREFERRED_MIN := 10
const LOYALTY_LOCAL_HERO_MIN := 20

# Trade route memory
var trade_route_memory: Dictionary = {}  # { good_name: { best_buy, best_sell, last_seen } }

# Bounty
var bounty_amount: int = 0
const BOUNTY_THRESHOLD_LOW := 100
const BOUNTY_THRESHOLD_HIGH := 300

# Finance pressure
const LOAN_DEFAULT_AMOUNT := 1000
const LOAN_DEFAULT_TERM := 7
const LOAN_DEFAULT_INTEREST := 0.08
const LOAN_REPAY_CHUNK := 300
var outstanding_debt: int = 0
var debt_due_in_trips: int = 0
var debt_interest_rate: float = 0.0
var missed_debt_payments: int = 0


func _ready() -> void:
	BackgroundUtils.validate_required_backgrounds()
	init_faction_reputation()
	build_starter_deck()


func reset() -> void:
	var settings: Dictionary = DIFFICULTY_SETTINGS.get(difficulty, DIFFICULTY_SETTINGS[Difficulty.NORMAL])
	credits = settings["credits"]
	max_hull = settings["hull"]
	current_hull = settings["hull"]
	max_shield = 10
	current_shield = 10
	cargo_capacity = 10
	cargo.clear()
	deck.clear()
	installed_upgrades.clear()
	crew.clear()
	hand_size = 5
	energy_per_turn = 3
	current_planet = "Starport Alpha"
	travel_destination = ""
	travel_origin = ""
	visited_planets.clear()
	visited_planets.append("Starport Alpha")
	current_ship = "res://data/ships/scout.tres"
	owned_ships = [current_ship]
	mission_return_planet = ""
	mission_done_this_landing = false
	arrival_events_done = false
	total_trades = 0
	total_encounters_won = 0
	total_flights = 0
	total_smuggler_deals = 0
	total_quests_completed = 0
	init_faction_reputation()
	outstanding_debt = 0
	debt_due_in_trips = 0
	debt_interest_rate = 0.0
	missed_debt_payments = 0
	bounty_amount = 0
	trade_loyalty.clear()
	trade_route_memory.clear()
	current_encounter = null
	battle_result = ""
	last_cargo_lost_text = ""
	removed_cards.clear()
	hull_upgrades_bought = 0
	shield_upgrades_bought = 0
	cargo_upgrades_bought = 0
	ghost_run_available = true
	build_starter_deck()
	EventLog.clear()
	EventLog.add_entry("Welcome to Starport Alpha. Your journey begins.")
	EventManager.reset_state()
	QuestManager.current_quest.clear()
	QuestManager.next_chain_id = 1
	QuestManager.generate_quests()
	RivalManager.reset()
	CraftingManager.reset()


func init_faction_reputation() -> void:
	faction_reputation.clear()
	for faction in FACTION_BY_PLANET_TYPE.values():
		faction_reputation[faction] = FACTION_NEUTRAL


func build_starter_deck() -> void:
	var starter_cards: Dictionary = {
		"laser_shot": 2,
		"heavy_blast": 1,
		"weak_shot": 2,
		"shield_up": 1,
		"flimsy_shield": 1,
		"evade": 1,
		"patch_hull": 1,
		"quick_draw": 1,
		"scavenge": 1,
	}
	for card_name in starter_cards:
		var path := "res://data/cards/%s.tres" % card_name
		var card_res: Resource = load(path)
		if card_res:
			for i in starter_cards[card_name]:
				deck.append(card_res)
		else:
			push_warning("GameManager: could not load card '%s'" % path)


# ── Credits ──────────────────────────────────────────────────────────────────

func add_credits(amount: int) -> void:
	credits += amount
	credits_changed.emit(credits)
	AchievementManager.check_credits(credits)


func remove_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	credits_changed.emit(credits)
	return true


# ── Reputation ───────────────────────────────────────────────────────────────

func get_planet_faction(planet_name: String) -> String:
	var planet: Resource = EconomyManager.get_planet_data(planet_name)
	if planet:
		return FACTION_BY_PLANET_TYPE.get(planet.planet_type, "Independent")
	return "Independent"


func get_faction_reputation(faction_name: String) -> int:
	return int(faction_reputation.get(faction_name, FACTION_NEUTRAL))


func get_current_planet_reputation() -> int:
	var faction: String = get_planet_faction(current_planet)
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


func get_market_buy_modifier(planet_name: String) -> float:
	# Positive reputation gives better buy prices.
	var rep: int = get_faction_reputation(get_planet_faction(planet_name))
	return clampf(1.0 - float(rep) * 0.0012, 0.90, 1.15)


func get_market_sell_modifier(planet_name: String) -> float:
	# Positive reputation gives better sell prices.
	var rep: int = get_faction_reputation(get_planet_faction(planet_name))
	return clampf(1.0 + float(rep) * 0.0009, 0.88, 1.12)


func get_local_encounter_modifier(planet_name: String) -> float:
	# Bad local standing leads to more inspections; good standing lowers friction.
	var rep: int = get_faction_reputation(get_planet_faction(planet_name))
	return clampf(-float(rep) * 0.0007, -0.06, 0.07)


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


# ── Finance pressure ─────────────────────────────────────────────────────────

func has_active_loan() -> bool:
	return outstanding_debt > 0


func can_take_loan() -> bool:
	return not has_active_loan()


func take_loan(
	amount: int = LOAN_DEFAULT_AMOUNT,
	term_trips: int = LOAN_DEFAULT_TERM,
	interest_rate: float = LOAN_DEFAULT_INTEREST
) -> bool:
	if has_active_loan():
		return false
	if amount <= 0 or term_trips <= 0:
		return false
	debt_interest_rate = maxf(interest_rate, 0.0)
	outstanding_debt = int(ceil(float(amount) * (1.0 + debt_interest_rate)))
	debt_due_in_trips = term_trips
	missed_debt_payments = 0
	add_credits(amount)
	EventLog.add_entry("Loan approved: +%d cr, %d trips, %.0f%% interest/trip" % [
		amount, term_trips, debt_interest_rate * 100.0
	])
	return true


func repay_loan(amount: int) -> int:
	if not has_active_loan():
		return 0
	var capped_amount: int = amount
	if capped_amount < 0:
		capped_amount = outstanding_debt
	capped_amount = mini(capped_amount, outstanding_debt)
	capped_amount = mini(capped_amount, credits)
	if capped_amount <= 0:
		return 0
	remove_credits(capped_amount)
	outstanding_debt -= capped_amount
	if outstanding_debt <= 0:
		outstanding_debt = 0
		debt_due_in_trips = 0
		debt_interest_rate = 0.0
		missed_debt_payments = 0
		EventLog.add_entry("Loan fully repaid.")
		AchievementManager.unlock("debt_free")
	else:
		EventLog.add_entry("Loan repayment: -%d cr (%d cr left)" % [capped_amount, outstanding_debt])
	return capped_amount


func process_loan_tick() -> void:
	if not has_active_loan():
		return
	outstanding_debt = int(ceil(float(outstanding_debt) * (1.0 + debt_interest_rate)))
	debt_due_in_trips = maxi(debt_due_in_trips - 1, 0)
	if debt_due_in_trips > 0:
		return

	# Debt reached maturity: attempt automatic collection.
	var collected: int = mini(credits, outstanding_debt)
	if collected > 0:
		remove_credits(collected)
		outstanding_debt -= collected
	if outstanding_debt <= 0:
		outstanding_debt = 0
		debt_interest_rate = 0.0
		missed_debt_payments = 0
		EventLog.add_entry("Loan auto-collected at maturity.")
		return

	missed_debt_payments += 1
	debt_due_in_trips = 2
	var hull_damage: int = 2 + missed_debt_payments * 2
	current_hull = maxi(1, current_hull - hull_damage)
	credits_changed.emit(credits)
	EventLog.add_entry("Debt collectors hit you: Hull -%d, debt remaining %d cr" % [hull_damage, outstanding_debt])

	# Missing payments hurts lawful factions.
	for planet_type in [0, 1, 2, 3]:
		var faction: String = FACTION_BY_PLANET_TYPE.get(planet_type, "")
		if faction != "":
			add_faction_reputation(faction, -1, "debt default")


func get_debt_status_text() -> String:
	if not has_active_loan():
		return "Debt: none"
	return "Debt: %d cr (%d trips)" % [outstanding_debt, debt_due_in_trips]


func get_loan_repay_chunk() -> int:
	return LOAN_REPAY_CHUNK


func get_debt_risk_modifier() -> float:
	if not has_active_loan():
		return 0.0
	var pressure: float = float(missed_debt_payments) * 0.02
	if debt_due_in_trips <= 1:
		pressure += 0.02
	return clampf(pressure, 0.0, 0.10)


# ── Cargo ────────────────────────────────────────────────────────────────────

func get_cargo_used() -> int:
	var total := 0
	for item in cargo:
		total += item.get("quantity", 0)
	return total


func get_free_cargo_space() -> int:
	return maxi(0, cargo_capacity - get_cargo_used())


func can_add_cargo(_good_name: String, quantity: int) -> bool:
	return get_cargo_used() + quantity <= cargo_capacity


func add_cargo(good_name: String, quantity: int) -> void:
	for item in cargo:
		if item["good_name"] == good_name:
			item["quantity"] += quantity
			cargo_changed.emit()
			return
	cargo.append({"good_name": good_name, "quantity": quantity})
	cargo_changed.emit()


func remove_cargo(good_name: String, quantity: int) -> void:
	for i in cargo.size():
		if cargo[i]["good_name"] == good_name:
			cargo[i]["quantity"] -= quantity
			if cargo[i]["quantity"] <= 0:
				cargo.remove_at(i)
			cargo_changed.emit()
			return


# ── Card removal ─────────────────────────────────────────────────────────────

func remove_card_permanently(card_path: String) -> void:
	# Remove all copies from the deck
	var i := deck.size() - 1
	while i >= 0:
		if deck[i] and deck[i].resource_path == card_path:
			deck.remove_at(i)
		i -= 1
	if card_path not in removed_cards:
		removed_cards.append(card_path)


# ── Upgrades ─────────────────────────────────────────────────────────────────

func apply_upgrade(upgrade: Resource) -> void:
	max_hull += upgrade.hull_bonus
	current_hull += upgrade.hull_bonus
	max_shield += upgrade.shield_bonus
	current_shield += upgrade.shield_bonus
	cargo_capacity += upgrade.cargo_bonus
	energy_per_turn += upgrade.energy_bonus
	hand_size += upgrade.hand_size_bonus
	for card in upgrade.cards_to_add:
		deck.append(card)
	installed_upgrades.append(upgrade.upgrade_name)
	AchievementManager.check_deck(deck.size())


# ── Win condition ─────────────────────────────────────────────────────────────

const WIN_CREDITS: int = 8000
const WIN_PLANETS: int = 7
const REPAIR_COST_PER_HP: int = 8

func check_win_condition() -> bool:
	return credits >= WIN_CREDITS and visited_planets.size() >= WIN_PLANETS


# ── Scene management ─────────────────────────────────────────────────────────

func change_scene(scene_path: String) -> void:
	await ScreenFade.fade_to_black(0.3)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	ScreenFade.fade_from_black(0.3)


# ── Crew ────────────────────────────────────────────────────────────────────

func hire_crew(crew_res: Resource) -> bool:
	if crew.size() >= MAX_CREW:
		return false
	if credits < crew_res.recruit_cost:
		return false
	credits -= crew_res.recruit_cost
	crew.append(crew_res.resource_path)
	crew_changed.emit()
	credits_changed.emit(credits)
	AchievementManager.check_crew(crew.size())
	return true


func dismiss_crew(index: int) -> void:
	if index >= 0 and index < crew.size():
		crew.remove_at(index)
		crew_changed.emit()


func has_crew_bonus(bonus_type: int) -> bool:
	for path in crew:
		var res: Resource = load(path)
		if res and res.bonus_type == bonus_type:
			return true
	return false


func get_crew_bonus_value(bonus_type: int) -> float:
	var total: float = 0.0
	var ship: Resource = get_ship_data()
	for path in crew:
		var res: Resource = load(path)
		if res and res.bonus_type == bonus_type:
			var value: float = res.bonus_value
			# Ship synergy: +50% if ship synergy matches this crew bonus
			if ship and ship.ship_ability == ShipData.ShipAbility.ADAPTABLE:
				value *= 1.2
			elif ship and ship.synergy_crew_bonus == bonus_type:
				value *= 1.5
			total += value
	return total


# ── Ghost Run (Smuggler Ship Ability) ────────────────────────────────────────

func use_ghost_run() -> bool:
	if not ghost_run_available:
		return false
	var ship: Resource = get_ship_data()
	if ship and ship.ship_ability == ShipData.ShipAbility.GHOST_RUN:
		ghost_run_available = false
		EventLog.add_entry("Ghost Run activated! Encounter avoided.")
		return true
	return false


func reset_ghost_run() -> void:
	ghost_run_available = true


func get_crew_resources() -> Array:
	var result: Array = []
	for path in crew:
		var res: Resource = load(path)
		if res:
			result.append(res)
	return result


## Sum of secondary_bonus_value for all crew matching bonus_type (Finding #3/#4).
func get_crew_secondary_bonus_value(bonus_type: int) -> float:
	var total: float = 0.0
	for res in get_crew_resources():
		if res.secondary_bonus_type == bonus_type:
			total += res.secondary_bonus_value
	return total


## True if any hired crew has the given event_flavor_tag (Finding #8).
func has_crew_flavor_tag(tag: String) -> bool:
	for res in get_crew_resources():
		if res.event_flavor_tag == tag:
			return true
	return false


## Name of the first crew member matching the event_flavor_tag, or "" (Finding #8).
func get_crew_name_by_flavor_tag(tag: String) -> String:
	for res in get_crew_resources():
		if res.event_flavor_tag == tag:
			return res.crew_name
	return ""


## Combined event success bonus from crew EVENT_SKILL + ship DEEP_SCAN.
## Used by planet events and travel events to modify choice success chances.
func get_event_success_bonus() -> float:
	var bonus: float = get_crew_secondary_bonus_value(CrewData.CrewBonus.EVENT_SKILL)
	var ship: Resource = get_ship_data()
	if ship and ship.ship_ability == ShipData.ShipAbility.DEEP_SCAN:
		bonus += 0.20
	return bonus


## Per-turn HP regen from Medic primary bonus (COMBAT_HEAL acts as turn heal of 1).
func get_combat_heal_per_turn() -> int:
	return 1 if has_crew_bonus(CrewData.CrewBonus.COMBAT_HEAL) else 0


## Per-turn shield regen from Engineer primary bonus (HULL_REGEN doubles as in-combat shield reroute).
func get_combat_shield_regen_per_turn() -> int:
	return 1 if has_crew_bonus(CrewData.CrewBonus.HULL_REGEN) else 0


## Sum of secondary COMBAT_TACTICAL values across crew, capped to keep dodge sane.
func get_combat_tactical_dodge_chance() -> float:
	return clampf(get_crew_secondary_bonus_value(CrewData.CrewBonus.COMBAT_TACTICAL), 0.0, 0.6)


## Mission bullet speed multiplier — Navigator slows enemy fire (0.85 with Navigator, else 1.0).
func get_mission_enemy_bullet_speed_mult() -> float:
	return 0.85 if has_crew_bonus(CrewData.CrewBonus.ENCOUNTER_REDUCTION) else 1.0


## Casino loss multiplier — Trader cushions punitive losses (0.8 with Trader, else 1.0).
func get_casino_loss_mult() -> float:
	return 0.8 if has_crew_bonus(CrewData.CrewBonus.SELL_BONUS) else 1.0


## Customs bribe bonus — Smuggler gives small extra success on top of SMUGGLE_PROTECTION wiring.
func get_customs_bribe_bonus() -> float:
	return 0.05 if has_crew_bonus(CrewData.CrewBonus.SMUGGLE_PROTECTION) else 0.0


## Returns a one-line crew flavor remark for the given event name, or "" if no
## crew member's event_flavor_tag matches the event. Shared by planet and travel events.
func get_crew_event_flavor_text(event_name: String) -> String:
	var event_lower: String = event_name.to_lower()
	for res in get_crew_resources():
		var tag: String = res.event_flavor_tag
		if tag == "":
			continue
		var match_tag: bool = false
		match tag:
			"tech":
				match_tag = ("tech" in event_lower or "ai" in event_lower or "data" in event_lower or "robot" in event_lower)
			"combat":
				match_tag = ("fight" in event_lower or "attack" in event_lower or "rampage" in event_lower or "muscle" in event_lower or "pirate" in event_lower or "distress" in event_lower)
			"trade":
				match_tag = ("trade" in event_lower or "market" in event_lower or "deal" in event_lower or "cargo" in event_lower or "merchant" in event_lower)
			"medical":
				match_tag = ("medic" in event_lower or "health" in event_lower or "pestilence" in event_lower or "hunger" in event_lower or "distress" in event_lower)
			"exploration":
				match_tag = ("mineral" in event_lower or "cache" in event_lower or "find" in event_lower or "cave" in event_lower or "anomaly" in event_lower or "debris" in event_lower)
			"underworld":
				match_tag = ("black" in event_lower or "bounty" in event_lower or "smug" in event_lower or "theft" in event_lower)
		if match_tag:
			return "%s assists with this situation." % res.crew_name
	return ""


# ── Ship ────────────────────────────────────────────────────────────────────

func get_ship_data() -> Resource:
	return load(current_ship)


func get_encounter_reduction() -> float:
	var ship: Resource = get_ship_data()
	if ship:
		return ship.encounter_reduction
	return 0.0


func get_contraband_bonus() -> float:
	var ship: Resource = get_ship_data()
	if ship:
		return ship.contraband_bonus
	return 0.0


func get_quest_reward_bonus() -> float:
	var ship: Resource = get_ship_data()
	if ship:
		return ship.quest_reward_bonus
	return 0.0


func owns_ship(path: String) -> bool:
	return path in owned_ships


func switch_ship(new_ship_path: String, keep_old: bool = false) -> void:
	var old_ship: Resource = get_ship_data()
	var new_ship: Resource = load(new_ship_path)
	if not old_ship or not new_ship:
		return
	var old_path: String = current_ship
	# Calculate stat deltas (new base - old base) and apply to current upgraded stats
	max_hull += new_ship.base_max_hull - old_ship.base_max_hull
	current_hull = mini(current_hull, max_hull)
	max_shield += new_ship.base_max_shield - old_ship.base_max_shield
	current_shield = mini(current_shield, max_shield)
	cargo_capacity += new_ship.base_cargo_capacity - old_ship.base_cargo_capacity
	energy_per_turn += new_ship.base_energy_per_turn - old_ship.base_energy_per_turn
	hand_size += new_ship.base_hand_size - old_ship.base_hand_size
	# Drop excess cargo
	while get_cargo_used() > cargo_capacity and cargo.size() > 0:
		var last_item: Dictionary = cargo[cargo.size() - 1]
		var excess: int = get_cargo_used() - cargo_capacity
		var drop: int = mini(last_item["quantity"], excess)
		last_item["quantity"] -= drop
		if last_item["quantity"] <= 0:
			cargo.remove_at(cargo.size() - 1)
		cargo_changed.emit()
	# Hangar bookkeeping
	if not keep_old:
		owned_ships.erase(old_path)
	if not (new_ship_path in owned_ships):
		owned_ships.append(new_ship_path)
	current_ship = new_ship_path
	# Ghost Run: available only on Smuggler-class ships, resets on every switch
	ghost_run_available = new_ship.ship_ability == ShipData.ShipAbility.GHOST_RUN
	credits_changed.emit(credits)


# ── Difficulty ──────────────────────────────────────────────────────────────

func get_difficulty_encounter_modifier() -> float:
	var settings: Dictionary = DIFFICULTY_SETTINGS.get(difficulty, DIFFICULTY_SETTINGS[Difficulty.NORMAL])
	return settings["encounter_mod"]


func get_difficulty_quest_bonus() -> int:
	var settings: Dictionary = DIFFICULTY_SETTINGS.get(difficulty, DIFFICULTY_SETTINGS[Difficulty.NORMAL])
	return settings["quest_deadline_bonus"]


# ── Bounty ──────────────────────────────────────────────────────────────────

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


func pay_off_bounty() -> bool:
	if bounty_amount <= 0:
		return false
	if credits < bounty_amount:
		return false
	var cost: int = bounty_amount
	remove_credits(cost)
	bounty_amount = 0
	EventLog.add_entry("Paid off bounty of %d cr." % cost)
	return true


func get_bounty_tier() -> String:
	if bounty_amount <= 0:
		return "None"
	if bounty_amount < BOUNTY_THRESHOLD_LOW:
		return "Watched"
	if bounty_amount < BOUNTY_THRESHOLD_HIGH:
		return "Wanted"
	return "Most Wanted"


func get_bounty_encounter_modifier() -> float:
	if bounty_amount >= BOUNTY_THRESHOLD_HIGH:
		return 0.20
	elif bounty_amount >= BOUNTY_THRESHOLD_LOW:
		return 0.10
	return 0.0


# ── Trade Loyalty ───────────────────────────────────────────────────────────

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


func get_trade_loyalty_gain(quantity: int, total_value: int) -> int:
	var gain: int = 1
	var bulk_bonus: int = mini(int(floor(float(maxi(quantity, 0)) / 4.0)), 2)
	var value_bonus: int = mini(int(floor(float(maxi(total_value, 0)) / 400.0)), 2)
	gain += bulk_bonus + value_bonus
	return clampi(gain, 1, 5)


func get_trade_loyalty(planet_name: String) -> int:
	return int(trade_loyalty.get(planet_name, 0))


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


func get_loyalty_buy_modifier(planet_name: String) -> float:
	# Max -8% discount at loyalty 100
	var loyalty: int = get_trade_loyalty(planet_name)
	return clampf(1.0 - float(loyalty) * 0.0008, 0.92, 1.0)


func get_loyalty_sell_modifier(planet_name: String) -> float:
	# Max +6% premium at loyalty 100
	var loyalty: int = get_trade_loyalty(planet_name)
	return clampf(1.0 + float(loyalty) * 0.0006, 1.0, 1.06)


func record_market_observation(
	planet_name: String,
	good_name: String,
	buy_price: int = -1,
	sell_price: int = -1
) -> void:
	if planet_name == "" or good_name == "":
		return

	var good_memory: Dictionary = trade_route_memory.get(good_name, {
		"best_buy": {},
		"best_sell": {},
		"last_seen": {},
	})
	var last_seen: Dictionary = good_memory.get("last_seen", {})
	var planet_entry: Dictionary = last_seen.get(planet_name, {})

	if buy_price >= 0:
		planet_entry["buy"] = buy_price
		var best_buy: Dictionary = good_memory.get("best_buy", {})
		if best_buy.is_empty() or buy_price < int(best_buy.get("price", buy_price + 1)):
			good_memory["best_buy"] = {"planet": planet_name, "price": buy_price}

	if sell_price >= 0:
		planet_entry["sell"] = sell_price
		var best_sell: Dictionary = good_memory.get("best_sell", {})
		if best_sell.is_empty() or sell_price > int(best_sell.get("price", sell_price - 1)):
			good_memory["best_sell"] = {"planet": planet_name, "price": sell_price}

	last_seen[planet_name] = planet_entry
	good_memory["last_seen"] = last_seen
	trade_route_memory[good_name] = good_memory


func get_best_buy_hint(good_name: String) -> Dictionary:
	var good_memory: Dictionary = trade_route_memory.get(good_name, {})
	return good_memory.get("best_buy", {})


func get_best_sell_hint(good_name: String) -> Dictionary:
	var good_memory: Dictionary = trade_route_memory.get(good_name, {})
	return good_memory.get("best_sell", {})


func get_last_seen_prices(planet_name: String, good_name: String) -> Dictionary:
	var good_memory: Dictionary = trade_route_memory.get(good_name, {})
	var last_seen: Dictionary = good_memory.get("last_seen", {})
	return last_seen.get(planet_name, {})


func has_cloaking_device() -> bool:
	return "Cloaking Device" in installed_upgrades
