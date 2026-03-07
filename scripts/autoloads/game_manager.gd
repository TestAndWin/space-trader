extends Node

signal credits_changed(new_amount: int)
signal cargo_changed
signal crew_changed

const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

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

# Shipyard upgrade counters (max 3 each)
const MAX_STAT_UPGRADES: int = 3
var hull_upgrades_bought: int = 0
var shield_upgrades_bought: int = 0
var cargo_upgrades_bought: int = 0

# Mission
var mission_return_planet: String = ""
var mission_done_this_landing: bool = false

# Planet arrival flag — prevents duplicate events when returning from sub-screens
var arrival_events_done: bool = false

# Statistics
var total_trades: int = 0
var total_encounters_won: int = 0
var total_flights: int = 0


func _ready() -> void:
	BackgroundUtils.validate_required_backgrounds()
	build_starter_deck()


func reset() -> void:
	credits = 1000
	max_hull = 30
	current_hull = 30
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
	mission_return_planet = ""
	mission_done_this_landing = false
	arrival_events_done = false
	total_trades = 0
	total_encounters_won = 0
	total_flights = 0
	current_encounter = null
	battle_result = ""
	last_cargo_lost_text = ""
	removed_cards.clear()
	hull_upgrades_bought = 0
	shield_upgrades_bought = 0
	cargo_upgrades_bought = 0
	build_starter_deck()
	EventLog.clear()
	EventLog.add_entry("Welcome to Starport Alpha. Your journey begins.")
	QuestManager.current_quest.clear()
	QuestManager.generate_quests()


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


func remove_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	credits_changed.emit(credits)
	return true


# ── Cargo ────────────────────────────────────────────────────────────────────

func get_cargo_used() -> int:
	var total := 0
	for item in cargo:
		total += item.get("quantity", 0)
	return total


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
	for path in crew:
		var res: Resource = load(path)
		if res and res.bonus_type == bonus_type:
			total += res.bonus_value
	return total


func get_crew_resources() -> Array:
	var result: Array = []
	for path in crew:
		var res: Resource = load(path)
		if res:
			result.append(res)
	return result


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


func switch_ship(new_ship_path: String) -> void:
	var old_ship: Resource = get_ship_data()
	var new_ship: Resource = load(new_ship_path)
	if not old_ship or not new_ship:
		return
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
	# Trade-in: 50% of old ship price
	var trade_in: int = int(old_ship.cost * 0.5)
	add_credits(trade_in)
	current_ship = new_ship_path
	credits_changed.emit(credits)
