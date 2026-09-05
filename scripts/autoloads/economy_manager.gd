extends Node

var price_table: Dictionary = {}   # { planet_name: { good_name: int } }
var planets: Array = []
var goods: Array = []

# Sell prices are roughly 75% of buy prices.
const SELL_RATIO := 0.75

# ── Market saturation ────────────────────────────────────────────────────────
# Dumping the same cargo into the same market floods it. Once a planet has taken
# its fill of a good, every further unit sells for less; the market absorbs one
# unit per day. Contraband floods far faster than ordinary cargo, which is what
# stops the "buy contraband, hop to the neighbour, sell, hop back" money loop.

# How many units still fetch the full price. The modifier for a unit is read
# before that unit is booked, so the Nth sale still sees only N-1 booked units
# -- the penalty therefore starts once the counter has reached this number.
const SATURATION_FULL_PRICE_UNITS_NORMAL := 6.0
const SATURATION_FULL_PRICE_UNITS_CONTRABAND := 2.0
const SATURATION_STEP_NORMAL := 0.05
const SATURATION_STEP_CONTRABAND := 0.12
const SATURATION_FLOOR_NORMAL := 0.65
const SATURATION_FLOOR_CONTRABAND := 0.35
const SATURATION_RECOVERY_PER_DAY := 1.0

# { planet_name: { good_name: { "units": float, "day": int } } }
var market_saturation: Dictionary = {}

# Planet type integer constants (avoids magic numbers).
const PT_INDUSTRIAL := 0
const PT_AGRICULTURAL := 1
const PT_MINING := 2
const PT_TECH := 3
const PT_OUTLAW := 4

const PLANET_TYPE_NAMES := {
	0: "Industrial",   # INDUSTRIAL
	1: "Agricultural", # AGRICULTURAL
	2: "Mining",       # MINING
	3: "Tech",         # TECH
	4: "Outlaw",       # OUTLAW
}

# Per-planet-type buy-price modifiers.
# Goods not listed for a type default to 1.0.
const _type_modifiers: Dictionary = {
	"Industrial": {
		"Food Rations": 1.2, "Raw Ore": 0.7, "Electronics": 0.9,
		"Luxury Goods": 1.0, "Weapons": 0.6, "Medicine": 1.0,
		"Rare Crystals": 1.2, "Plasma Coils": 0.6,
	},
	"Agricultural": {
		"Food Rations": 0.5, "Raw Ore": 1.3, "Electronics": 1.5,
		"Luxury Goods": 1.2, "Weapons": 1.0, "Medicine": 1.2,
		"Rare Crystals": 1.3, "Plasma Coils": 1.3,
	},
	"Mining": {
		"Food Rations": 1.4, "Raw Ore": 0.5, "Electronics": 1.3,
		"Luxury Goods": 1.1, "Weapons": 0.8, "Medicine": 1.4,
		"Rare Crystals": 0.6, "Plasma Coils": 1.2,
	},
	"Tech": {
		"Food Rations": 1.1, "Raw Ore": 1.2, "Electronics": 0.5,
		"Luxury Goods": 0.7, "Weapons": 1.2, "Medicine": 0.6,
		"Rare Crystals": 1.4, "Plasma Coils": 1.4,
	},
	"Outlaw": {
		"Food Rations": 1.0, "Raw Ore": 1.0, "Electronics": 1.0,
		"Luxury Goods": 0.8, "Weapons": 0.7, "Medicine": 1.0,
		"Spice": 0.6, "Stolen Tech": 0.5,
		"Rare Crystals": 1.1, "Plasma Coils": 1.1,
	},
}

# Per-planet-type available goods for purchase.
# Goods NOT listed here cannot be bought at that planet type.
const _type_available_goods: Dictionary = {
	"Industrial": ["Electronics", "Weapons", "Raw Ore", "Medicine", "Luxury Goods", "Plasma Coils"],
	"Agricultural": ["Food Rations", "Medicine", "Luxury Goods", "Raw Ore"],
	"Mining": ["Raw Ore", "Weapons", "Food Rations", "Electronics", "Rare Crystals"],
	"Tech": ["Electronics", "Medicine", "Luxury Goods", "Weapons"],
	"Outlaw": ["Weapons", "Spice", "Stolen Tech", "Electronics", "Luxury Goods"],
}

const CONTRABAND_GOODS: Array = ["Spice", "Stolen Tech"]

# Contraband price modifiers for non-Outlaw planets (high prices = good sell target).
const _contraband_non_outlaw_modifiers: Dictionary = {
	"Spice": 1.6,
	"Stolen Tech": 1.8,
}


func _ready() -> void:
	reset()


func reset() -> void:
	_load_data()
	price_table.clear()
	_generate_initial_prices()
	market_saturation.clear()


func save_state() -> Dictionary:
	return {"prices": price_table.duplicate(true), "saturation": market_saturation.duplicate(true)}


func load_state(data: Dictionary) -> void:
	reset()
	var saved_prices: Dictionary = data.get("prices", {})
	for planet_name: String in price_table:
		var local_prices: Dictionary = saved_prices.get(planet_name, {})
		for good_name: String in price_table[planet_name]:
			if local_prices.has(good_name):
				price_table[planet_name][good_name] = maxi(1, int(local_prices[good_name]))
	market_saturation = data.get("saturation", {}).duplicate(true)


# ── Data loading ─────────────────────────────────────────────────────────────

func _load_data() -> void:
	planets = ResourceRegistry.load_all(ResourceRegistry.PLANETS)
	if GameManager.crimson_base_unlocked:
		var crimson_base: Resource = load(ResourceRegistry.CRIMSON_BASE)
		if crimson_base:
			planets.append(crimson_base)
	goods = ResourceRegistry.load_all(ResourceRegistry.GOODS)
	# Crafted goods need prices for sell_finished_item() but are not buyable
	# (they are not listed in _type_available_goods).
	goods.append_array(ResourceRegistry.load_all(ResourceRegistry.CRAFTED_GOODS))


func reload_planets() -> void:
	_load_data()
	# Need to generate prices for the new planet if it wasn't there
	for planet in planets:
		if not price_table.has(planet.planet_name):
			_generate_prices_for_planet(planet)

func _generate_prices_for_planet(planet: Resource) -> void:
	var planet_name: String = planet.planet_name
	var planet_type: String = PLANET_TYPE_NAMES.get(planet.planet_type, "Industrial")
	var modifiers: Dictionary = _type_modifiers.get(planet_type, {})
	price_table[planet_name] = {}
	for good in goods:
		var good_name: String = good.good_name
		var base_price: int = good.base_price
		var modifier: float = modifiers.get(good_name, 1.0)
		# Contraband at non-Outlaw planets: high price (good sell target)
		if good_name in CONTRABAND_GOODS and planet_type != "Outlaw":
			modifier = _contraband_non_outlaw_modifiers.get(good_name, 2.0)
		var variance: float = randf_range(0.9, 1.1)
		var final_price := int(round(base_price * modifier * variance))
		price_table[planet_name][good_name] = max(1, final_price)

# ── Price generation ─────────────────────────────────────────────────────────

func _generate_initial_prices() -> void:
	for planet in planets:
		_generate_prices_for_planet(planet)


# ── Public API ───────────────────────────────────────────────────────────────

func get_buy_price(planet_name: String, good_name: String) -> int:
	var breakdown: Dictionary = get_buy_price_breakdown(planet_name, good_name)
	if breakdown.is_empty():
		return -1
	return int(breakdown.get("final_price", -1))


func get_sell_price(planet_name: String, good_name: String) -> int:
	var breakdown: Dictionary = get_sell_price_breakdown(planet_name, good_name)
	if breakdown.is_empty():
		return -1
	return int(breakdown.get("final_price", -1))


func get_buy_price_breakdown(planet_name: String, good_name: String) -> Dictionary:
	if not _can_buy_good(planet_name, good_name):
		return {}
	var base_price: int = _get_local_price(planet_name, good_name)
	if base_price < 0:
		return {}
	var event_entries: Array = EventManager.get_price_modifiers_for(planet_name, good_name)
	var event_modifier: float = _multiply_event_entries(event_entries)
	var rep_modifier: float = StandingManager.get_market_buy_modifier(planet_name)
	var loyalty_modifier: float = StandingManager.get_loyalty_buy_modifier(planet_name)
	var service_fee_modifier: float = StandingManager.get_planet_service_fee_modifier(planet_name)
	var ship: Resource = GameManager.get_ship_data()
	var ship_modifier: float = 0.92 if ship and ship.ship_ability == ShipData.ShipAbility.BULK_DISCOUNT else 1.0
	
	var pirate_modifier: float = 1.0
	if PirateLordManager.active_presence_planets.has(planet_name):
		if is_contraband_good(good_name):
			pirate_modifier = 0.5 # Cheap contraband
		else:
			pirate_modifier = 1.5 # Expensive regular goods

	var final_price: int = max(
		1,
		int(round(float(base_price) * event_modifier * rep_modifier * loyalty_modifier * service_fee_modifier * pirate_modifier))
	)
	final_price = maxi(1, int(round(float(final_price) * ship_modifier)))
	return {
		"base_price": base_price,
		"event_modifier": event_modifier,
		"event_entries": event_entries,
		"rep_modifier": rep_modifier,
		"loyalty_modifier": loyalty_modifier,
		"service_fee_modifier": service_fee_modifier,
		"ship_modifier": ship_modifier,
		"pirate_modifier": pirate_modifier,
		"final_price": final_price,
	}


func get_sell_price_breakdown(planet_name: String, good_name: String, extra_units: float = 0.0) -> Dictionary:
	var local_price: int = _get_local_price(planet_name, good_name)
	if local_price < 0:
		return {}
	var event_entries: Array = EventManager.get_price_modifiers_for(planet_name, good_name)
	var event_modifier: float = _multiply_event_entries(event_entries)
	var sell_ratio: float = SELL_RATIO
	var override_ratio: float = EventManager.get_sell_ratio_override(planet_name)
	if override_ratio > 0.0:
		sell_ratio = override_ratio
	if GameManager.has_crew_bonus(CrewData.CrewBonus.SELL_BONUS):
		sell_ratio = maxf(sell_ratio, GameManager.get_crew_bonus_value(CrewData.CrewBonus.SELL_BONUS))
	var contraband_modifier: float = 1.0
	if is_contraband_good(good_name):
		contraband_modifier += GameManager.get_contraband_bonus()
	var rep_modifier: float = StandingManager.get_market_sell_modifier(planet_name)
	var loyalty_modifier: float = StandingManager.get_loyalty_sell_modifier(planet_name)
	var service_fee_modifier: float = 1.0 / StandingManager.get_planet_service_fee_modifier(planet_name)
	
	var pirate_modifier: float = 1.0
	if PirateLordManager.active_presence_planets.has(planet_name):
		if is_contraband_good(good_name):
			pirate_modifier = 1.5 # High sell price for contraband
		else:
			pirate_modifier = 0.5 # Low sell price for regular goods

	var saturation_modifier: float = get_saturation_modifier(planet_name, good_name, extra_units)

	var final_price: int = max(
		1,
		int(round(
			float(local_price) * event_modifier * sell_ratio * contraband_modifier * rep_modifier * loyalty_modifier * service_fee_modifier * pirate_modifier * saturation_modifier
		))
	)
	
	var uncapped_price: int = final_price
	# Cap the sell price at the buy price if the good is sold here,
	# so that players cannot infinitely generate money by buying and selling at the same market.
	var buy_breakdown: Dictionary = get_buy_price_breakdown(planet_name, good_name)
	if not buy_breakdown.is_empty():
		var buy_price: int = int(buy_breakdown.get("final_price", -1))
		if buy_price > 0 and final_price > buy_price:
			final_price = buy_price
			

	return {
		"base_price": local_price,
		"event_modifier": event_modifier,
		"event_entries": event_entries,
		"sell_ratio": sell_ratio,
		"contraband_modifier": contraband_modifier,
		"rep_modifier": rep_modifier,
		"loyalty_modifier": loyalty_modifier,
		"service_fee_modifier": service_fee_modifier,
		"pirate_modifier": pirate_modifier,
		"saturation_modifier": saturation_modifier,
		"uncapped_price": uncapped_price,
		"was_capped": final_price < uncapped_price,
		"final_price": final_price,
	}


func get_average_price(good_name: String) -> int:
	var total: int = 0
	var count: int = 0
	for planet_name in price_table:
		if good_name in price_table[planet_name]:
			total += price_table[planet_name][good_name]
			count += 1
	if count == 0:
		return -1
	return int(round(float(total) / float(count)))


func get_available_goods(planet_type_name: String) -> Array:
	return _type_available_goods.get(planet_type_name, [])


func is_good_sold_at_planet(planet_name: String, good_name: String) -> bool:
	if get_planet_data(planet_name) == null:
		return false
	return good_name in _type_available_goods.get(_get_planet_type(planet_name), [])


func get_planet_data(planet_name: String) -> Resource:
	for planet in planets:
		if planet.planet_name == planet_name:
			return planet
	return null


func _get_planet_type(planet_name: String) -> String:
	var planet := get_planet_data(planet_name)
	if planet:
		return PLANET_TYPE_NAMES.get(planet.planet_type, "Industrial")
	return "Industrial"


func _get_local_price(planet_name: String, good_name: String) -> int:
	if not (planet_name in price_table and good_name in price_table[planet_name]):
		return -1
	return int(price_table[planet_name][good_name])


func _can_buy_good(planet_name: String, good_name: String) -> bool:
	if _get_local_price(planet_name, good_name) < 0:
		return false
	var planet_type: String = _get_planet_type(planet_name)
	var available: Array = _type_available_goods.get(planet_type, [])
	if available.size() > 0 and not (good_name in available):
		return false
	if is_contraband_good(good_name) and planet_type != "Outlaw":
		return false
	return true


## Planets where a good can actually be bought.
## Quests may ask for cargo the issuing planet does not stock, so the quest UI
## and the galaxy map need to be able to point the player somewhere.
func get_planets_selling(good_name: String) -> Array[String]:
	var result: Array[String] = []
	for planet in planets:
		if _can_buy_good(planet.planet_name, good_name):
			result.append(planet.planet_name)
	return result


## Planet-type names (not planet names) that stock a good — used for the short
## "available on Mining planets" hint when the exact planets are less useful.
func get_planet_types_selling(good_name: String) -> Array[String]:
	var result: Array[String] = []
	for type_name: String in _type_available_goods:
		if good_name in _type_available_goods[type_name]:
			if is_contraband_good(good_name) and type_name != "Outlaw":
				continue
			result.append(type_name)
	return result


## One-line sourcing hint for a good, e.g. "Raw Ore: buy on Mining or
## Industrial planets (Iron Belt, Dust Haven, Forge World)".
## Returns "" for goods that cannot be bought anywhere (crafted items).
func get_sourcing_hint(good_name: String) -> String:
	var planets_with: Array[String] = get_planets_selling(good_name)
	if planets_with.is_empty():
		return ""
	var types: Array[String] = get_planet_types_selling(good_name)
	var type_text: String = " or ".join(types) if types.size() <= 2 else ", ".join(types)
	return "Available on %s planets: %s" % [type_text, ", ".join(planets_with)]


func is_contraband_good(good_name: String) -> bool:
	return good_name in CONTRABAND_GOODS


func _multiply_event_entries(entries: Array) -> float:
	var modifier: float = 1.0
	for entry in entries:
		modifier *= float((entry as Dictionary).get("modifier", 1.0))
	return modifier


# ── Market saturation ────────────────────────────────────────────────────────

## Units of a good a fresh market buys at the full price, per planet.
func get_full_price_units(good_name: String) -> float:
	return SATURATION_FULL_PRICE_UNITS_CONTRABAND if is_contraband_good(good_name) else SATURATION_FULL_PRICE_UNITS_NORMAL


## Units a market has taken beyond the ones it pays full price for. The +1
## closes the off-by-one: with N full-price units the Nth sale sees N-1 booked.
func _units_over(units: float, full_price_units: float) -> float:
	return units - full_price_units + 1.0


func _get_saturation_step(good_name: String) -> float:
	return SATURATION_STEP_CONTRABAND if is_contraband_good(good_name) else SATURATION_STEP_NORMAL


func _get_saturation_floor(good_name: String) -> float:
	return SATURATION_FLOOR_CONTRABAND if is_contraband_good(good_name) else SATURATION_FLOOR_NORMAL


## Units past which the price no longer drops. Capping here keeps recovery
## bounded -- selling 100 units must not lock a market out for 100 days.
func _get_saturation_cap(good_name: String) -> float:
	var floor_value: float = _get_saturation_floor(good_name)
	var over_at_floor: float = ceil((1.0 - floor_value) / _get_saturation_step(good_name))
	# _units_over() inverted: the unit count at which the price bottoms out.
	return get_full_price_units(good_name) - 1.0 + over_at_floor


## Units still flooding a market, after the daily recovery has been applied.
func get_saturation_units(planet_name: String, good_name: String) -> float:
	var planet_entry: Dictionary = market_saturation.get(planet_name, {})
	var entry: Dictionary = planet_entry.get(good_name, {})
	if entry.is_empty():
		return 0.0
	var days_passed: int = maxi(GameManager.current_day - int(entry.get("day", 0)), 0)
	var recovered: float = float(days_passed) * SATURATION_RECOVERY_PER_DAY
	return maxf(float(entry.get("units", 0.0)) - recovered, 0.0)


## Sell-price multiplier from market saturation, 1.0 when the market is fresh.
## `extra_units` prices a unit that has not been sold yet, so a stack sold in
## one click is priced the same as the same stack sold one unit at a time.
func get_saturation_modifier(planet_name: String, good_name: String, extra_units: float = 0.0) -> float:
	var units: float = get_saturation_units(planet_name, good_name) + extra_units
	var over: float = _units_over(units, get_full_price_units(good_name))
	if over <= 0.0:
		return 1.0
	var modifier: float = 1.0 - over * _get_saturation_step(good_name)
	return maxf(modifier, _get_saturation_floor(good_name))


## Days until a flooded market pays full price again, 0 when it already does.
func get_days_until_recovered(planet_name: String, good_name: String) -> int:
	var over: float = _units_over(get_saturation_units(planet_name, good_name), get_full_price_units(good_name))
	if over <= 0.0:
		return 0
	return int(ceil(over / SATURATION_RECOVERY_PER_DAY))


## Every market currently paying below full price, worst first, so the trade hub
## can tell the player where they have already dumped too much and how long the
## market needs. Entries: { planet, good, modifier, days }.
func get_flooded_markets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for planet_name: String in market_saturation:
		for good_name: String in market_saturation[planet_name]:
			var modifier: float = get_saturation_modifier(planet_name, good_name)
			if modifier >= 1.0:
				continue
			result.append({
				"planet": planet_name,
				"good": good_name,
				"modifier": modifier,
				"days": get_days_until_recovered(planet_name, good_name),
			})
	# The planet the player is standing on decides the next trade, so it leads;
	# the rest follow worst-flooded first.
	var here: String = GameManager.current_planet
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_here: bool = a["planet"] == here
		var b_here: bool = b["planet"] == here
		if a_here != b_here:
			return a_here
		if a["days"] != b["days"]:
			return a["days"] > b["days"]
		return str(a["good"]) < str(b["good"])
	)
	return result


func register_sale(planet_name: String, good_name: String, quantity: int) -> void:
	if quantity <= 0 or planet_name == "" or good_name == "":
		return
	var units: float = get_saturation_units(planet_name, good_name) + float(quantity)
	units = minf(units, _get_saturation_cap(good_name))
	if not market_saturation.has(planet_name):
		market_saturation[planet_name] = {}
	market_saturation[planet_name][good_name] = {
		"units": units,
		"day": GameManager.current_day,
	}


## Income for selling `quantity` units in one go. Each unit floods the market a
## little further, so the stack is priced unit by unit -- selling ten at once
## must not dodge the penalty that selling them one by one would incur.
## Returns -1 when the good cannot be sold here at all.
func get_sell_total(planet_name: String, good_name: String, quantity: int) -> int:
	if quantity <= 0:
		return 0
	var total: int = 0
	for i in range(quantity):
		var breakdown: Dictionary = get_sell_price_breakdown(planet_name, good_name, float(i))
		if breakdown.is_empty():
			return -1
		total += int(breakdown.get("final_price", 0))
	return total


# ── Economy tick (called after departure) ────────────────────────────────────

func tick_economy() -> void:
	for planet_name in price_table:
		for good_name in price_table[planet_name]:
			var current: int = price_table[planet_name][good_name]
			var drift: float = randf_range(-0.05, 0.05)
			var new_price := int(round(current * (1.0 + drift)))
			price_table[planet_name][good_name] = max(1, new_price)
