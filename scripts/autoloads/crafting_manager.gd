extends Node

## Manages crafting facilities on Tech planets.
## State per planet: unlocked, slots, active jobs, finished items.
## Tick is called from planet_screen._do_depart() like Quest/Event managers.

const FACILITY_COST: int = 2500
const SLOT_COSTS: Dictionary = {2: 800, 3: 2000}  # cost to unlock slot N
const MAX_SLOTS: int = 3

# production_facilities[planet_name] = {
#   "unlocked": bool,
#   "slots": int,                    # 1..3
#   "active_jobs": Array[Dictionary] # [{ recipe_id, trips_remaining, slot_index }]
#   "finished_items": Array[Dictionary] # [{ good_path, amount }]
# }
var production_facilities: Dictionary = {}

# Cached recipes by id, loaded once.
var _recipes_by_id: Dictionary = {}


func _ready() -> void:
	_load_recipes()


func _load_recipes() -> void:
	_recipes_by_id.clear()
	for recipe in ResourceRegistry.load_all(ResourceRegistry.RECIPES):
		_recipes_by_id[recipe.recipe_id] = recipe


func reset() -> void:
	production_facilities.clear()


func get_recipe(recipe_id: String) -> Resource:
	return _recipes_by_id.get(recipe_id, null)


func _ensure_facility(planet_name: String) -> Dictionary:
	if not production_facilities.has(planet_name):
		production_facilities[planet_name] = {
			"unlocked": false,
			"slots": 0,
			"active_jobs": [],
			"finished_items": [],
		}
	return production_facilities[planet_name]


# ── Save / Load ─────────────────────────────────────────────────────────────

func save_state() -> Dictionary:
	return { "facilities": production_facilities.duplicate(true) }


func load_state(data: Dictionary) -> void:
	production_facilities = data.get("facilities", {}).duplicate(true)

# ── Facility / Slots ────────────────────────────────────────────────────────

func is_facility_unlocked(planet_name: String) -> bool:
	var f: Dictionary = _ensure_facility(planet_name)
	return bool(f.unlocked)


func unlock_facility(planet_name: String) -> bool:
	if GameManager.credits < FACILITY_COST:
		return false
	var f: Dictionary = _ensure_facility(planet_name)
	if f.unlocked:
		return false
	GameManager.remove_credits(FACILITY_COST)
	f.unlocked = true
	f.slots = 1
	EventLog.add_entry("Production Facility unlocked at %s." % planet_name)
	return true


func expand_slots(planet_name: String) -> bool:
	var f: Dictionary = _ensure_facility(planet_name)
	if not f.unlocked:
		return false
	if f.slots >= MAX_SLOTS:
		return false
	var next_slot: int = f.slots + 1
	var cost: int = SLOT_COSTS.get(next_slot, 0)
	if GameManager.credits < cost:
		return false
	GameManager.remove_credits(cost)
	f.slots = next_slot
	EventLog.add_entry("Factory slot %d unlocked at %s." % [next_slot, planet_name])
	return true


func get_slot_count(planet_name: String) -> int:
	return int(_ensure_facility(planet_name).slots)


func get_next_slot_cost(planet_name: String) -> int:
	var f: Dictionary = _ensure_facility(planet_name)
	if f.slots >= MAX_SLOTS:
		return 0
	return int(SLOT_COSTS.get(f.slots + 1, 0))


# ── Recipes for planet ──────────────────────────────────────────────────────

func get_recipes_for_planet(planet_name: String) -> Array:
	var result: Array = []
	for recipe in _recipes_by_id.values():
		if recipe.available_at_planets.is_empty():
			result.append(recipe)
		elif planet_name in recipe.available_at_planets:
			result.append(recipe)
	return result


# ── Job lifecycle ───────────────────────────────────────────────────────────

func get_active_jobs(planet_name: String) -> Array:
	return _ensure_facility(planet_name).active_jobs


func get_finished_items(planet_name: String) -> Array:
	return _ensure_facility(planet_name).finished_items


func get_free_slot_index(planet_name: String) -> int:
	var f: Dictionary = _ensure_facility(planet_name)
	var used: Array = []
	for job in f.active_jobs:
		used.append(int(job.slot_index))
	for i in f.slots:
		if i not in used:
			return i
	return -1


func can_start_job(planet_name: String, recipe: Resource) -> bool:
	var f: Dictionary = _ensure_facility(planet_name)
	if not f.unlocked:
		return false
	if get_free_slot_index(planet_name) == -1:
		return false
	for entry in recipe.inputs:
		var good: GoodData = entry.good
		var needed: int = int(entry.amount)
		var have: int = GameManager.get_cargo_quantity(good.good_name)
		if have < needed:
			return false
	return true


func start_job(planet_name: String, recipe: Resource) -> bool:
	if not can_start_job(planet_name, recipe):
		return false
	var slot: int = get_free_slot_index(planet_name)
	for entry in recipe.inputs:
		var good: GoodData = entry.good
		GameManager.remove_cargo(good.good_name, int(entry.amount))
	var f: Dictionary = _ensure_facility(planet_name)
	f.active_jobs.append({
		"recipe_id": recipe.recipe_id,
		"trips_remaining": recipe.build_trips,
		"slot_index": slot,
	})
	EventLog.add_entry("Started crafting %s at %s (%d trips)." % [
		recipe.output_good.good_name, planet_name, recipe.build_trips,
	])
	return true


# Called once per departure from any planet.
func tick() -> void:
	for planet_name in production_facilities.keys():
		var f: Dictionary = production_facilities[planet_name]
		var still_active: Array = []
		for job in f.active_jobs:
			job.trips_remaining -= 1
			if job.trips_remaining <= 0:
				var recipe: Resource = get_recipe(job.recipe_id)
				if recipe and recipe.output_good:
					f.finished_items.append({
						"good_path": recipe.output_good.resource_path,
						"amount": recipe.output_amount,
					})
					EventLog.add_entry("%s ready at %s." % [
						recipe.output_good.good_name, planet_name,
					])
			else:
				still_active.append(job)
		f.active_jobs = still_active


# ── Collect / Sell ──────────────────────────────────────────────────────────

# Crafted goods aren't in the planet price table, so fall back to base_price * SELL_RATIO.
func get_finished_item_sell_price(planet_name: String, good: GoodData) -> int:
	var price: int = EconomyManager.get_sell_price(planet_name, good.good_name)
	if price < 0:
		price = int(round(good.base_price * EconomyManager.SELL_RATIO))
	return price


func collect_finished_item(planet_name: String, finished_index: int) -> bool:
	var f: Dictionary = _ensure_facility(planet_name)
	if finished_index < 0 or finished_index >= f.finished_items.size():
		return false
	var entry: Dictionary = f.finished_items[finished_index]
	var good: GoodData = load(entry.good_path)
	if good == null:
		return false
	var amount: int = int(entry.amount)
	var free_space: int = GameManager.get_free_cargo_space()
	if free_space < amount:
		return false
	GameManager.add_cargo(good.good_name, amount)
	f.finished_items.remove_at(finished_index)
	EventLog.add_entry("Collected %d x %s." % [amount, good.good_name])
	return true


func sell_finished_item(planet_name: String, finished_index: int) -> int:
	var f: Dictionary = _ensure_facility(planet_name)
	if finished_index < 0 or finished_index >= f.finished_items.size():
		return 0
	var entry: Dictionary = f.finished_items[finished_index]
	var good: GoodData = load(entry.good_path)
	if good == null:
		return 0
	var amount: int = int(entry.amount)
	var price: int = get_finished_item_sell_price(planet_name, good)
	var total: int = price * amount
	GameManager.add_credits(total)
	f.finished_items.remove_at(finished_index)
	EventLog.add_entry("Sold %d x %s for %d cr." % [amount, good.good_name, total])
	return total
