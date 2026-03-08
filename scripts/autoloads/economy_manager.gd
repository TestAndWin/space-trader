extends Node

var price_table: Dictionary = {}   # { planet_name: { good_name: int } }
var planets: Array = []
var goods: Array = []

# Sell prices are roughly 75% of buy prices.
const SELL_RATIO := 0.75

# Planet type integer constants (avoids magic numbers).
const PT_INDUSTRIAL := 0
const PT_AGRICULTURAL := 1
const PT_MINING := 2
const PT_TECH := 3
const PT_OUTLAW := 4

# Map PlanetType enum values to string keys.
const PLANET_TYPE_NAMES := {
	0: "Industrial",   # INDUSTRIAL
	1: "Agricultural", # AGRICULTURAL
	2: "Mining",       # MINING
	3: "Tech",         # TECH
	4: "Outlaw",       # OUTLAW
}

# Per-planet-type buy-price modifiers.
# Goods not listed for a type default to 1.0.
var _type_modifiers: Dictionary = {
	"Industrial": {
		"Food Rations": 1.2, "Raw Ore": 0.7, "Electronics": 0.9,
		"Luxury Goods": 1.0, "Weapons": 0.6, "Medicine": 1.0,
	},
	"Agricultural": {
		"Food Rations": 0.5, "Raw Ore": 1.3, "Electronics": 1.5,
		"Luxury Goods": 1.2, "Weapons": 1.0, "Medicine": 1.2,
	},
	"Mining": {
		"Food Rations": 1.4, "Raw Ore": 0.5, "Electronics": 1.3,
		"Luxury Goods": 1.1, "Weapons": 0.8, "Medicine": 1.4,
	},
	"Tech": {
		"Food Rations": 1.1, "Raw Ore": 1.2, "Electronics": 0.5,
		"Luxury Goods": 0.7, "Weapons": 1.2, "Medicine": 0.6,
	},
	"Outlaw": {
		"Food Rations": 1.0, "Raw Ore": 1.0, "Electronics": 1.0,
		"Luxury Goods": 0.8, "Weapons": 0.7, "Medicine": 1.0,
		"Spice": 0.6, "Stolen Tech": 0.5,
	},
}

# Per-planet-type available goods for purchase.
# Goods NOT listed here cannot be bought at that planet type.
var _type_available_goods: Dictionary = {
	"Industrial": ["Electronics", "Weapons", "Raw Ore", "Medicine", "Luxury Goods"],
	"Agricultural": ["Food Rations", "Medicine", "Luxury Goods", "Raw Ore"],
	"Mining": ["Raw Ore", "Weapons", "Food Rations", "Electronics"],
	"Tech": ["Electronics", "Medicine", "Luxury Goods", "Weapons"],
	"Outlaw": ["Weapons", "Spice", "Stolen Tech", "Electronics", "Luxury Goods"],
}

# Contraband goods: names that count as contraband.
var _contraband_goods: Array = ["Spice", "Stolen Tech"]

# Contraband price modifiers for non-Outlaw planets (high prices = good sell target).
var _contraband_non_outlaw_modifiers: Dictionary = {
	"Spice": 1.6,
	"Stolen Tech": 1.8,
}


func _ready() -> void:
	_load_data()
	_generate_initial_prices()


# ── Data loading ─────────────────────────────────────────────────────────────

func _load_data() -> void:
	planets = ResourceRegistry.load_all(ResourceRegistry.PLANETS)
	goods = ResourceRegistry.load_all(ResourceRegistry.GOODS)


# ── Price generation ─────────────────────────────────────────────────────────

func _generate_initial_prices() -> void:
	for planet in planets:
		var planet_name: String = planet.planet_name
		var planet_type: String = PLANET_TYPE_NAMES.get(planet.planet_type, "Industrial")
		var modifiers: Dictionary = _type_modifiers.get(planet_type, {})
		price_table[planet_name] = {}
		for good in goods:
			var good_name: String = good.good_name
			var base_price: int = good.base_price
			var modifier: float = modifiers.get(good_name, 1.0)
			# Contraband at non-Outlaw planets: high price (good sell target)
			if good_name in _contraband_goods and planet_type != "Outlaw":
				modifier = _contraband_non_outlaw_modifiers.get(good_name, 2.0)
			var variance: float = randf_range(0.9, 1.1)
			var final_price := int(round(base_price * modifier * variance))
			price_table[planet_name][good_name] = max(1, final_price)


# ── Public API ───────────────────────────────────────────────────────────────

func get_buy_price(planet_name: String, good_name: String) -> int:
	if not (planet_name in price_table and good_name in price_table[planet_name]):
		return -1
	# Check if this good is available for purchase at this planet type
	var planet_type := _get_planet_type(planet_name)
	var available: Array = _type_available_goods.get(planet_type, [])
	if available.size() > 0 and not (good_name in available):
		return -1
	# Contraband can only be BOUGHT at Outlaw planets
	if good_name in _contraband_goods:
		if planet_type != "Outlaw":
			return -1
	var base: int = price_table[planet_name][good_name]
	var event_mod: float = EventManager.get_price_modifier(planet_name, good_name)
	var rep_mod: float = GameManager.get_market_buy_modifier(planet_name)
	return max(1, int(round(base * event_mod * rep_mod)))


func get_sell_price(planet_name: String, good_name: String) -> int:
	if not (planet_name in price_table and good_name in price_table[planet_name]):
		return -1
	var local_price: int = price_table[planet_name][good_name]
	var event_mod: float = EventManager.get_price_modifier(planet_name, good_name)
	var ratio: float = SELL_RATIO
	var override: float = EventManager.get_sell_ratio_override()
	if override > 0.0:
		ratio = override
	# Crew trader bonus: use best sell ratio
	if GameManager.has_crew_bonus(3):  # SELL_BONUS
		ratio = maxf(ratio, GameManager.get_crew_bonus_value(3))
	var base_sell: float = local_price * event_mod * ratio
	# Ship contraband bonus
	if good_name in _contraband_goods:
		base_sell *= (1.0 + GameManager.get_contraband_bonus())
	base_sell *= GameManager.get_market_sell_modifier(planet_name)
	return max(1, int(round(base_sell)))


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


# ── Economy tick (called after departure) ────────────────────────────────────

func tick_economy() -> void:
	for planet_name in price_table:
		for good_name in price_table[planet_name]:
			var current: int = price_table[planet_name][good_name]
			var drift: float = randf_range(-0.05, 0.05)
			var new_price := int(round(current * (1.0 + drift)))
			price_table[planet_name][good_name] = max(1, new_price)
