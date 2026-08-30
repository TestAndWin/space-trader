extends Node

signal credits_changed(new_amount: int)
signal cargo_changed
signal crew_changed

const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

# ── Constants ─────────────────────────────────────────────────────────────────

# Navigation
const FUEL_PRICE: int = 50
const EMERGENCY_FUEL_DEBT: int = 100
const CAPTURED_SHIP_BASE_PRICE: int = 500

# The pirate lord's base. Its planet_name is compared in several screens, and it
# is renamed once the player has taken it over — see get_display_planet_name().
const CRIMSON_BASE_NAME: String = "Crimson Jack's Hideout"
const CRIMSON_BASE_OWNED_NAME: String = "Your Hideout"

# Ship & Upgrades
const STARTER_SHIP: String = "res://data/ships/scout.tres"
const SHIP_TRANSFER_FEE: int = 250
const REPAIR_COST_PER_HP: int = 30

# Finance
const LOAN_DEFAULT_AMOUNT := 1000
const LOAN_DEFAULT_TERM := 7
const LOAN_DEFAULT_INTEREST := 0.08
const LOAN_REPAY_CHUNK := 300

# Game Logic
const WIN_PLANETS: int = 7

# Difficulty
enum Difficulty { EASY, NORMAL, HARD }
const DIFFICULTY_SETTINGS := {
	Difficulty.EASY:   { "credits": 1500, "hull": 35, "encounter_mod": -0.10, "quest_deadline_bonus": 2, "win_credits":  8000 },
	Difficulty.NORMAL: { "credits": 1000, "hull": 30, "encounter_mod":  0.00, "quest_deadline_bonus": 0, "win_credits": 10000 },
	Difficulty.HARD:   { "credits":  600, "hull": 25, "encounter_mod":  0.10, "quest_deadline_bonus": -1, "win_credits": 12000 },
}
var difficulty: int = Difficulty.NORMAL

# Player identity
var player_name: String = "Pilot"

# Economy
## Every write emits credits_changed, including reset() and save loading, so UI
## bound to the signal cannot go stale. Callers must never emit it themselves.
## Assigning the same value is a no-op — no redundant UI churn.
var credits: int = 1000:
	set(value):
		if credits == value:
			return
		credits = value
		credits_changed.emit(credits)

# Ship stats
var max_hull: int = 30
var current_hull: int = 30
var max_shield: int = 10
var current_shield: int = 10
var cargo_capacity: int = 10

# Inventory  (each entry: { "good_name": String, "quantity": int })
## The setter only fires when the array itself is replaced (save loading,
## reset()) — element changes cannot be observed this way. Everything that
## modifies the hold must therefore go through add_cargo()/remove_cargo(),
## which emit; never mutate GameManager.cargo from outside.
var cargo: Array = []:
	set(value):
		if cargo == value:
			return
		cargo = value
		cargo_changed.emit()

# Card / combat
var deck: Array = []
var installed_upgrades: Array = []
var ship_upgrades_store: Dictionary = {}
var removed_cards: Array = []  # Permanently removed card paths
var hand_size: int = 5
var energy_per_turn: int = 3

# Crew
var crew: Array = []  # Array of resource paths (String)
var wounded_crew: Dictionary = {} # Dictionary mapping path to days_left

# Ship Upgrades
var damaged_upgrades: Array = [] # Array of upgrade names (String) that are damaged

# Navigation
var max_fuel: int = 6
var current_fuel: int = 6
var current_planet: String = "Starport Alpha"
var travel_destination: String = ""
var travel_origin: String = ""
var travel_days: int = 1
var travel_distance: float = 0.0
var travel_route: Array[String] = []
var visited_planets: Array = []
var blockaded_planet: String = ""

# Battle
var current_encounter: Resource = null
var battle_result: String = ""
var last_cargo_lost_text: String = ""
var extra_battle_message: String = ""
var boarding_special_loot: String = ""

# Ship
var current_ship: String = STARTER_SHIP
var owned_ships: Array[String] = [STARTER_SHIP]

# Shipyard upgrade counters (max 3 each)
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
var total_travel_days: int = 0
var current_day: int = 1
var intro_shown: bool = false
var total_smuggler_deals: int = 0
var total_quests_completed: int = 0

# Trade route memory (player notebook — best prices observed per good)
var trade_route_memory: Dictionary = {}  # { good_name: { best_buy, best_sell, last_seen } }

# Finance pressure
var outstanding_debt: int = 0
var debt_due_in_days: int = 0
var debt_interest_rate: float = 0.0
var missed_debt_payments: int = 0

# Boss logic
var crimson_base_unlocked: bool = false

func _ready() -> void:
	BackgroundUtils.validate_required_backgrounds()
	build_starter_deck()


func reset() -> void:
	var settings: Dictionary = _get_difficulty_settings()
	credits = settings["credits"]
	max_hull = settings["hull"]
	current_hull = settings["hull"]
	max_shield = 10
	current_shield = 10
	cargo_capacity = 10
	cargo = []  # Reassign rather than clear(), so the setter reports it.
	deck.clear()
	installed_upgrades.clear()
	ship_upgrades_store.clear()
	crew.clear()
	wounded_crew.clear()
	damaged_upgrades.clear()
	hand_size = 5
	energy_per_turn = 3
	max_fuel = get_base_max_fuel_for_ship(STARTER_SHIP)
	current_fuel = max_fuel
	current_planet = "Starport Alpha"
	travel_destination = ""
	travel_origin = ""
	travel_days = 1
	travel_distance = 0.0
	travel_route.clear()
	visited_planets.clear()
	visited_planets.append("Starport Alpha")
	blockaded_planet = ""
	current_ship = STARTER_SHIP
	owned_ships = [current_ship]
	mission_return_planet = ""
	mission_done_this_landing = false
	arrival_events_done = false
	total_trades = 0
	total_encounters_won = 0
	total_travel_days = 0
	current_day = 1
	intro_shown = false
	total_smuggler_deals = 0
	total_quests_completed = 0
	StandingManager.reset()
	outstanding_debt = 0
	debt_due_in_days = 0
	debt_interest_rate = 0.0
	missed_debt_payments = 0
	trade_route_memory.clear()
	current_encounter = null
	battle_result = ""
	last_cargo_lost_text = ""
	boarding_special_loot = ""
	removed_cards.clear()
	hull_upgrades_bought = 0
	shield_upgrades_bought = 0
	cargo_upgrades_bought = 0
	ghost_run_available = true
	victory_triggered = false
	crimson_base_unlocked = false
	build_starter_deck()
	EventLog.clear()
	EventLog.add_entry("Welcome to Starport Alpha. Your journey begins.")
	EventLog.add_entry("Goal: Locate and defeat the pirate lord Crimson Jack.")
	EventLog.add_entry("Prerequisites: %d cr + visit all 7 planets + install 1 T2 upgrade + no open bounty." % get_win_credits())
	EventLog.add_entry("T2 chain: buy goods -> Factory (Tech planet) -> craft T1 -> craft T2 -> install at any Shipyard.")
	EventManager.reset_state()
	EconomyManager.reset_saturation()
	QuestManager.current_quest.clear()
	QuestManager.next_chain_id = 1
	QuestManager.generate_quests()
	RivalManager.reset()
	CraftingManager.reset()
	PirateLordManager.reset()


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
	AchievementManager.check_credits(credits)


func remove_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	return true


# ── Finance pressure ─────────────────────────────────────────────────────────

func has_active_loan() -> bool:
	return outstanding_debt > 0


func take_loan(
	amount: int = LOAN_DEFAULT_AMOUNT,
	term_days: int = LOAN_DEFAULT_TERM,
	interest_rate: float = LOAN_DEFAULT_INTEREST
) -> bool:
	if has_active_loan():
		return false
	if amount <= 0 or term_days <= 0:
		return false
	debt_interest_rate = maxf(interest_rate, 0.0)
	outstanding_debt = int(ceil(float(amount) * (1.0 + debt_interest_rate)))
	debt_due_in_days = term_days
	missed_debt_payments = 0
	add_credits(amount)
	EventLog.add_entry("Loan approved: +%d cr, %d days, %.0f%% interest/day" % [
		amount, term_days, debt_interest_rate * 100.0
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
		debt_due_in_days = 0
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
	debt_due_in_days = maxi(debt_due_in_days - 1, 0)
	if debt_due_in_days > 0:
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
	debt_due_in_days = 2
	var hull_damage: int = 2 + missed_debt_payments * 2
	current_hull = maxi(1, current_hull - hull_damage)
	EventLog.add_entry("Debt collectors hit you: Hull -%d, debt remaining %d cr" % [hull_damage, outstanding_debt])

	# Missing payments hurts lawful factions (Outlaw faction has no reputation system).
	for planet_type in [EconomyManager.PT_INDUSTRIAL, EconomyManager.PT_AGRICULTURAL, EconomyManager.PT_MINING, EconomyManager.PT_TECH]:
		var faction: String = StandingManager.FACTION_BY_PLANET_TYPE.get(planet_type, "")
		if faction != "":
			StandingManager.add_faction_reputation(faction, -1, "debt default")


func get_debt_status_text() -> String:
	if not has_active_loan():
		return "Debt: none"
	return "Debt: %d cr (%d days)" % [outstanding_debt, debt_due_in_days]


func get_loan_repay_chunk() -> int:
	return LOAN_REPAY_CHUNK


func get_debt_risk_modifier() -> float:
	if not has_active_loan():
		return 0.0
	var pressure: float = float(missed_debt_payments) * 0.02
	if debt_due_in_days <= 1:
		pressure += 0.02
	return clampf(pressure, 0.0, 0.10)


# ── Fuel and travel time ─────────────────────────────────────────────────────

func can_start_travel(destination: String, route: Array[String]) -> bool:
	if destination == "" or route.size() < 2:
		return false
	if str(route.front()) != current_planet or str(route.back()) != destination:
		return false
	var fuel_cost: int = NavigationManager.get_fuel_cost(current_planet, destination)
	return fuel_cost >= 0 and current_fuel >= fuel_cost


func begin_travel(destination: String, route: Array[String]) -> bool:
	if not can_start_travel(destination, route):
		return false
	arrival_events_done = false
	mission_done_this_landing = false
	reset_ghost_run()
	blockaded_planet = ""
	travel_origin = current_planet
	travel_destination = destination
	travel_route.clear()
	for entry in route:
		travel_route.append(str(entry))
	travel_days = maxi(NavigationManager.get_travel_days(current_planet, destination), 1)
	travel_distance = maxf(NavigationManager.get_distance(current_planet, destination), 0.0)
	var fuel_cost: int = NavigationManager.get_fuel_cost(current_planet, destination)
	if not consume_fuel(fuel_cost):
		return false
	process_travel_days(travel_days)
	return true


func process_travel_days(days: int) -> void:
	for _i in range(maxi(days, 0)):
		current_day += 1
		total_travel_days += 1
		
		# Crew wages (dynamic per member, 15-30cr per day)
		var wages: int = 0
		for path in crew:
			var crew_res = load(path)
			if crew_res:
				wages += crew_res.daily_wage
		
		if wages > 0:
			if credits >= wages:
				remove_credits(wages)
				EventLog.add_entry("Day %d: Paid %d cr in crew wages" % [current_day, wages])
			else:
				var shortfall: int = wages - credits
				credits = 0
				outstanding_debt += shortfall
				EventLog.add_entry("Day %d: Paid wages but went into debt by %d cr" % [current_day, shortfall])
				if debt_due_in_days <= 0:
					debt_due_in_days = 3
				if debt_interest_rate <= 0.0:
					debt_interest_rate = LOAN_DEFAULT_INTEREST
		
		QuestManager.tick()
		EventManager.tick()
		CraftingManager.tick()
		EconomyManager.tick_economy()
		PirateLordManager.tick()
		process_loan_tick()
		RivalManager.on_travel_day_completed()
		
		# Heal wounded crew over time
		var recovered: Array = []
		for path in wounded_crew.keys():
			wounded_crew[path] -= 1
			if wounded_crew[path] <= 0:
				recovered.append(path)
		for path in recovered:
			wounded_crew.erase(path)
			var res = load(path)
			if res:
				EventLog.add_entry("Crew member recovered: %s is fit for duty again!" % res.crew_name)
		if recovered.size() > 0:
			crew_changed.emit()


func consume_fuel(amount: int) -> bool:
	if amount <= 0:
		return true
	if current_fuel < amount:
		return false
	current_fuel -= amount
	return true


func get_fuel_price() -> int:
	var base_price := FUEL_PRICE
	var planet = EconomyManager.get_planet_data(current_planet)
	if not planet:
		return base_price
	match planet.planet_type:
		0, 3: # Industrial, Tech
			return int(round(base_price * 0.85))
		1: # Agricultural
			return int(round(base_price * 1.15))
		_:
			return base_price

func buy_fuel(amount: int) -> bool:
	if amount <= 0 or current_fuel >= max_fuel:
		return false
	var fuel_to_buy: int = mini(amount, max_fuel - current_fuel)
	var cost: int = fuel_to_buy * get_fuel_price()
	if not remove_credits(cost):
		return false
	current_fuel += fuel_to_buy
	EventLog.add_entry("Bought %d fuel for %dcr." % [fuel_to_buy, cost])
	return true

func take_emergency_fuel() -> bool:
	if current_fuel > 0 or credits >= get_fuel_price() or current_fuel >= max_fuel:
		return false
	current_fuel += 1
	outstanding_debt += EMERGENCY_FUEL_DEBT
	if debt_due_in_days <= 0:
		debt_due_in_days = 3
	if debt_interest_rate <= 0.0:
		debt_interest_rate = LOAN_DEFAULT_INTEREST
	EventLog.add_entry("Emergency fuel loaded: +1 fuel, +%d cr debt." % EMERGENCY_FUEL_DEBT)
	return true


func get_aggregate_encounter_chance(route_danger: int, destination: String, days: int) -> float:
	var per_day: float = EncounterManager.estimate_encounter_chance(route_danger, destination)
	if NavigationManager.is_safe_lane(current_planet, destination):
		per_day *= 0.8
	return clampf(1.0 - pow(1.0 - per_day, maxi(days, 1)), 0.0, 0.95)


func apply_arrival_fuel_generation() -> void:
	var generated: int = 0
	for upgrade_name in installed_upgrades:
		generated += _get_fuel_generation_for_upgrade(str(upgrade_name))
	if generated <= 0 or current_fuel >= max_fuel:
		return
	var before: int = current_fuel
	current_fuel = mini(max_fuel, current_fuel + generated)
	if current_fuel != before:
		EventLog.add_entry("Fuel Synthesizer generated +%d fuel." % (current_fuel - before))


func _get_fuel_generation_for_upgrade(upgrade_name: String) -> int:
	var upgrade: Resource = _get_upgrade_resource(upgrade_name)
	if upgrade == null:
		return 0
	return int(upgrade.fuel_generation_per_arrival)


## The planet the player is heading for, or the one they are standing on when
## no journey is in progress. Encounters and events resolve against it.

## Display name for a planet. The pirate lord's hideout becomes the player's own
## base after the win, so every screen must show it under the new name; the
## stored planet_name never changes.

## Ends the current run: deletes the save, clears all state and returns to the
## main menu. Used by the victory and game-over screens.
func end_run_to_main_menu() -> void:
	SaveManager.delete_save()
	reset()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func get_display_planet_name(planet_name: String) -> String:
	if planet_name == CRIMSON_BASE_NAME and victory_triggered:
		return CRIMSON_BASE_OWNED_NAME
	return planet_name


func get_focus_planet() -> String:
	return travel_destination if travel_destination != "" else current_planet


func complete_travel_arrival(destination: String, generate_fuel: bool = true) -> void:
	current_planet = destination
	if destination not in visited_planets:
		visited_planets.append(destination)
	AchievementManager.check_planets(visited_planets)
	if generate_fuel:
		apply_arrival_fuel_generation()


# ── Cargo ────────────────────────────────────────────────────────────────────

func get_cargo_used() -> int:
	var total := 0
	for item in cargo:
		total += item.get("quantity", 0)
	return total


func get_cargo_quantity(good_name: String) -> int:
	for item in cargo:
		if item.get("good_name") == good_name:
			return item.get("quantity", 0)
	return 0


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
	max_fuel += upgrade.fuel_capacity_bonus
	current_fuel = mini(current_fuel + upgrade.fuel_capacity_bonus, max_fuel)
	energy_per_turn += upgrade.energy_bonus
	hand_size += upgrade.hand_size_bonus
	for card in upgrade.cards_to_add:
		deck.append(card)
	installed_upgrades.append(upgrade.upgrade_name)
	AchievementManager.check_deck(deck.size())
	try_trigger_victory()


# ── Win condition ─────────────────────────────────────────────────────────────

func get_win_credits() -> int:
	return _get_difficulty_settings()["win_credits"]


var _crafted_upgrade_names: PackedStringArray = []

func _get_crafted_upgrade_names() -> PackedStringArray:
	if _crafted_upgrade_names.is_empty():
		for path in ResourceRegistry.CRAFTED_UPGRADES:
			var upgrade: Resource = load(path)
			if upgrade != null:
				_crafted_upgrade_names.append(upgrade.upgrade_name)
	return _crafted_upgrade_names


func has_crafted_upgrade_installed() -> bool:
	for upgrade_name in _get_crafted_upgrade_names():
		if upgrade_name in installed_upgrades:
			return true
	return false


func check_win_condition() -> bool:
	return (
		credits >= get_win_credits()
		and visited_planets.size() >= WIN_PLANETS
		and has_crafted_upgrade_installed()
		and StandingManager.bounty_amount <= 0
	)


# Latched so overlapping call sites (arrival + market sell etc.) cannot
# start the victory transition twice. Cleared on reset() and save load.
var victory_triggered: bool = false

## Central victory trigger — call after any action that can complete the last
## win condition: planet arrival, market sale, quest delivery, upgrade
## install, bounty payoff.
func try_trigger_victory() -> bool:
	if crimson_base_unlocked or not check_win_condition():
		return false
	crimson_base_unlocked = true
	EconomyManager.reload_planets()
	EventLog.add_entry("CRITICAL: Crimson Jack's hideout coordinates acquired! The final battle awaits.")
	# We could emit a signal here to show a popup in the UI if needed
	return true

func try_trigger_actual_victory() -> bool:
	if victory_triggered or not PirateLordManager.jack_defeated:
		return false
	victory_triggered = true
	change_scene("res://scenes/victory.tscn")
	return true


# ── Scene management ─────────────────────────────────────────────────────────

func change_scene(scene_path: String) -> void:
	await ScreenFade.fade_to_black(0.3)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	ScreenFade.fade_from_black(0.3)


# ── Crew ────────────────────────────────────────────────────────────────────

func get_max_crew() -> int:
	var ship: Resource = get_ship_data()
	if ship:
		return ship.max_crew
	return 3


func hire_crew(crew_res: Resource) -> bool:
	if crew.size() >= get_max_crew():
		return false
	if credits < crew_res.recruit_cost:
		return false
	credits -= crew_res.recruit_cost
	crew.append(crew_res.resource_path)
	crew_changed.emit()
	AchievementManager.check_crew(crew.size())
	return true


func dismiss_crew(index: int) -> void:
	if index >= 0 and index < crew.size():
		var path = crew[index]
		crew.remove_at(index)
		if path in wounded_crew:
			wounded_crew.erase(path)
		crew_changed.emit()


func has_crew_bonus(bonus_type: int) -> bool:
	for path in crew:
		if path in wounded_crew: continue
		var res: Resource = load(path)
		if res and (res.bonus_type == bonus_type or res.secondary_bonus_type == bonus_type):
			return true
	return false


func get_crew_bonus_value(bonus_type: int) -> float:
	var total: float = 0.0
	var ship: Resource = get_ship_data()
	for path in crew:
		if path in wounded_crew: continue
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
		if path in wounded_crew: continue
		var res: Resource = load(path)
		if res:
			result.append(res)
	return result


## Sum of secondary_bonus_value for all crew matching bonus_type.
func get_crew_secondary_bonus_value(bonus_type: int) -> float:
	var total: float = 0.0
	for res in get_crew_resources():
		if res.secondary_bonus_type == bonus_type:
			total += res.secondary_bonus_value
	return total


## True if any hired crew has the given event_flavor_tag.
func has_crew_flavor_tag(tag: String) -> bool:
	for res in get_crew_resources():
		if res.event_flavor_tag == tag:
			return true
	return false


## Name of the first crew member matching the event_flavor_tag, or "".
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


## Fuel tank size of a ship class, before upgrades. Tank capacity is part of a
## hull's identity: the Explorer ranges far, the Warship barely at all.
func get_base_max_fuel_for_ship(ship_path: String) -> int:
	var ship: Resource = load(ship_path)
	if ship:
		return int(ship.base_max_fuel)
	return 6


## Tank size is always the current hull's base capacity plus every installed
## tank upgrade -- never stored, so it stays right across ship swaps and loads.
func recompute_max_fuel() -> void:
	var total: int = get_base_max_fuel_for_ship(current_ship)
	for upg_name in installed_upgrades:
		var upg: Resource = _get_upgrade_resource(upg_name)
		if upg:
			total += int(upg.fuel_capacity_bonus)
	max_fuel = maxi(total, 1)
	current_fuel = clampi(current_fuel, 0, max_fuel)


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


func _get_upgrade_resource(upg_name: String) -> Resource:
	var paths: Array[String] = ResourceRegistry.COMBAT_UPGRADES + ResourceRegistry.CRAFTED_UPGRADES + ResourceRegistry.UPGRADES
	for path in paths:
		var res: Resource = load(path)
		if res and res.upgrade_name == upg_name:
			return res
	return null

func save_current_ship_upgrades() -> void:
	if current_ship == "": return
	ship_upgrades_store[current_ship] = {
		"installed_upgrades": installed_upgrades.duplicate(),
		"hull_upgrades_bought": hull_upgrades_bought,
		"shield_upgrades_bought": shield_upgrades_bought,
		"cargo_upgrades_bought": cargo_upgrades_bought
	}

func load_ship_upgrades(ship_path: String) -> void:
	var data = ship_upgrades_store.get(ship_path, {
		"installed_upgrades": [],
		"hull_upgrades_bought": 0,
		"shield_upgrades_bought": 0,
		"cargo_upgrades_bought": 0
	})
	installed_upgrades = data["installed_upgrades"].duplicate()
	hull_upgrades_bought = data["hull_upgrades_bought"]
	shield_upgrades_bought = data["shield_upgrades_bought"]
	cargo_upgrades_bought = data["cargo_upgrades_bought"]


func switch_ship(new_ship_path: String, keep_old: bool = false) -> void:
	var old_ship: Resource = get_ship_data()
	var new_ship: Resource = load(new_ship_path)
	if not old_ship or not new_ship:
		return
	var old_path: String = current_ship
	
	save_current_ship_upgrades()
	for upg_name in installed_upgrades:
		var upg = _get_upgrade_resource(upg_name)
		if upg and "cards_to_add" in upg:
			for card in upg.cards_to_add:
				for i in range(deck.size()):
					if deck[i].card_name == card.card_name:
						deck.remove_at(i)
						break
	
	if not keep_old:
		owned_ships.erase(old_path)
		ship_upgrades_store.erase(old_path)
	if not (new_ship_path in owned_ships):
		owned_ships.append(new_ship_path)
	current_ship = new_ship_path
	
	load_ship_upgrades(new_ship_path)
	for upg_name in installed_upgrades:
		var upg = _get_upgrade_resource(upg_name)
		if upg and "cards_to_add" in upg:
			for card in upg.cards_to_add:
				deck.append(card)
	
	max_hull = new_ship.base_max_hull + (hull_upgrades_bought * 5)
	max_shield = new_ship.base_max_shield + (shield_upgrades_bought * 3)
	cargo_capacity = new_ship.base_cargo_capacity + (cargo_upgrades_bought * 2)
	energy_per_turn = new_ship.base_energy_per_turn
	hand_size = new_ship.base_hand_size

	for upg_name in installed_upgrades:
		var upg = _get_upgrade_resource(upg_name)
		if upg:
			max_hull += upg.hull_bonus
			max_shield += upg.shield_bonus
			cargo_capacity += upg.cargo_bonus
			energy_per_turn += upg.energy_bonus
			hand_size += upg.hand_size_bonus

	recompute_max_fuel()
	current_hull = mini(current_hull, max_hull)
	current_shield = mini(current_shield, max_shield)
	
	var dropped_any: bool = false
	while get_cargo_used() > cargo_capacity and cargo.size() > 0:
		var last_item: Dictionary = cargo[cargo.size() - 1]
		var excess: int = get_cargo_used() - cargo_capacity
		var drop: int = mini(last_item["quantity"], excess)
		last_item["quantity"] -= drop
		if last_item["quantity"] <= 0:
			cargo.remove_at(cargo.size() - 1)
		dropped_any = true
	if dropped_any:
		cargo_changed.emit()
	# Ghost Run: available only on Smuggler-class ships, resets on every switch
	ghost_run_available = new_ship.ship_ability == ShipData.ShipAbility.GHOST_RUN


# ── Difficulty ──────────────────────────────────────────────────────────────

func _get_difficulty_settings() -> Dictionary:
	return DIFFICULTY_SETTINGS.get(difficulty, DIFFICULTY_SETTINGS[Difficulty.NORMAL])


func get_difficulty_encounter_modifier() -> float:
	return _get_difficulty_settings()["encounter_mod"]


func get_difficulty_quest_bonus() -> int:
	return _get_difficulty_settings()["quest_deadline_bonus"]


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
