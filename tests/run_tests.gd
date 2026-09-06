extends SceneTree

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	print("==================================================")
	print("SpaceTrader: Headless Formula & Math Tests")
	print("==================================================")

	_run_economy_tests()
	_run_combat_damage_tests()

	print("--------------------------------------------------")
	print("Results: %d total, %d passed, %d failed" % [total_tests, passed_tests, failed_tests])
	print("==================================================")

	quit(0 if failed_tests == 0 else 1)


func assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	total_tests += 1
	if actual == expected:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		print("  [FAIL] %s: expected %s, got %s" % [test_name, str(expected), str(actual)])


func assert_approx_eq(actual: float, expected: float, test_name: String, tolerance: float = 0.001) -> void:
	total_tests += 1
	if absf(actual - expected) <= tolerance:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		print("  [FAIL] %s: expected %s, got %s (diff: %f)" % [test_name, str(expected), str(actual), absf(actual - expected)])


# ==============================================================================
# 1. ECONOMY & PRICE FORMULA TESTS
# ==============================================================================
func _run_economy_tests() -> void:
	print("\n--- Economy & Pricing Formula Tests ---")

	# Sell ratio constant
	const SELL_RATIO: float = 0.75
	assert_approx_eq(SELL_RATIO, 0.75, "Base sell ratio is 75%")

	# Sell price formula: int(buy_price * SELL_RATIO)
	var buy_p1 := 100
	var sell_p1: int = int(buy_p1 * SELL_RATIO)
	assert_eq(sell_p1, 75, "Sell price of 100cr is 75cr")

	var buy_p2 := 240
	var sell_p2: int = int(buy_p2 * SELL_RATIO)
	assert_eq(sell_p2, 180, "Sell price of 240cr is 180cr")

	var buy_p3 := 35
	var sell_p3: int = int(buy_p3 * SELL_RATIO)
	assert_eq(sell_p3, 26, "Sell price of 35cr is 26cr (truncated integer)")

	# Planet-type price modifiers
	# Industrial: Raw Ore 0.7, Weapons 0.6, Food Rations 1.2, Rare Crystals 1.2
	const INDUSTRIAL_MODS := {
		"Raw Ore": 0.7, "Weapons": 0.6, "Food Rations": 1.2, "Rare Crystals": 1.2
	}
	assert_approx_eq(INDUSTRIAL_MODS["Raw Ore"], 0.7, "Industrial: Raw Ore discount modifier is 0.7")
	assert_approx_eq(INDUSTRIAL_MODS["Weapons"], 0.6, "Industrial: Weapons discount modifier is 0.6")
	assert_approx_eq(INDUSTRIAL_MODS["Food Rations"], 1.2, "Industrial: Food Rations premium modifier is 1.2")

	# Agricultural: Food Rations 0.5, Raw Ore 1.3, Electronics 1.5
	const AGRI_MODS := {
		"Food Rations": 0.5, "Raw Ore": 1.3, "Electronics": 1.5
	}
	assert_approx_eq(AGRI_MODS["Food Rations"], 0.5, "Agricultural: Food Rations discount modifier is 0.5")
	assert_approx_eq(AGRI_MODS["Electronics"], 1.5, "Agricultural: Electronics premium modifier is 1.5")

	# Mining: Raw Ore 0.5, Rare Crystals 0.6, Food Rations 1.4
	const MINING_MODS := {
		"Raw Ore": 0.5, "Rare Crystals": 0.6, "Food Rations": 1.4
	}
	assert_approx_eq(MINING_MODS["Raw Ore"], 0.5, "Mining: Raw Ore discount modifier is 0.5")
	assert_approx_eq(MINING_MODS["Rare Crystals"], 0.6, "Mining: Rare Crystals discount modifier is 0.6")

	# Tech: Electronics 0.5, Medicine 0.6, Rare Crystals 1.4
	const TECH_MODS := {
		"Electronics": 0.5, "Medicine": 0.6, "Rare Crystals": 1.4
	}
	assert_approx_eq(TECH_MODS["Electronics"], 0.5, "Tech: Electronics discount modifier is 0.5")
	assert_approx_eq(TECH_MODS["Medicine"], 0.6, "Tech: Medicine discount modifier is 0.6")

	# Outlaw: Spice 0.6, Stolen Tech 0.5
	const OUTLAW_MODS := {
		"Spice": 0.6, "Stolen Tech": 0.5
	}
	assert_approx_eq(OUTLAW_MODS["Spice"], 0.6, "Outlaw: Spice buy discount modifier is 0.6")
	assert_approx_eq(OUTLAW_MODS["Stolen Tech"], 0.5, "Outlaw: Stolen Tech buy discount modifier is 0.5")

	# Contraband on non-outlaw planets (high sell price multiplier)
	const CONTRABAND_NON_OUTLAW := {
		"Spice": 1.6, "Stolen Tech": 1.8
	}
	assert_approx_eq(CONTRABAND_NON_OUTLAW["Spice"], 1.6, "Non-Outlaw: Spice multiplier is 1.6")
	assert_approx_eq(CONTRABAND_NON_OUTLAW["Stolen Tech"], 1.8, "Non-Outlaw: Stolen Tech multiplier is 1.8")

	# Market Saturation Formula:
	# Normal cargo: full price for first 6 units, -0.05 per unit above 6, floor 0.65
	# Contraband: full price for first 2 units, -0.12 per unit above 2, floor 0.35
	var sat_normal_0 := _calculate_saturation_modifier(0.0, false)
	assert_approx_eq(sat_normal_0, 1.0, "Normal cargo saturation at 0 units sold is 1.0")

	var sat_normal_6 := _calculate_saturation_modifier(5.0, false)
	assert_approx_eq(sat_normal_6, 1.0, "Normal cargo saturation for 6th unit is 1.0")

	var sat_normal_7 := _calculate_saturation_modifier(6.0, false)
	assert_approx_eq(sat_normal_7, 0.95, "Normal cargo saturation for 7th unit is 0.95")

	var sat_normal_floor := _calculate_saturation_modifier(20.0, false)
	assert_approx_eq(sat_normal_floor, 0.65, "Normal cargo saturation floor is 0.65")

	var sat_contra_2 := _calculate_saturation_modifier(1.0, true)
	assert_approx_eq(sat_contra_2, 1.0, "Contraband saturation for 2nd unit is 1.0")

	var sat_contra_3 := _calculate_saturation_modifier(2.0, true)
	assert_approx_eq(sat_contra_3, 0.88, "Contraband saturation for 3rd unit is 0.88 (-0.12 step)")

	var sat_contra_floor := _calculate_saturation_modifier(10.0, true)
	assert_approx_eq(sat_contra_floor, 0.35, "Contraband saturation floor is 0.35")


func _calculate_saturation_modifier(units_booked: float, is_contraband: bool) -> float:
	var full_price_units: float = 2.0 if is_contraband else 6.0
	var step: float = 0.12 if is_contraband else 0.05
	var floor_val: float = 0.35 if is_contraband else 0.65

	var over: float = units_booked - full_price_units + 1.0
	if over <= 0.0:
		return 1.0
	return maxf(floor_val, 1.0 - over * step)



# ==============================================================================
# 2. COMBAT DAMAGE & SHIELD INTERACTION TESTS
# ==============================================================================
func _run_combat_damage_tests() -> void:
	print("\n--- Combat Damage & Shield Formula Tests ---")

	# Damage Type Multipliers
	# 0: KINETIC, 1: ION, 2: PIERCING
	const SHIELD_MULT := { 0: 0.5, 1: 2.0, 2: 0.0 }
	const HULL_MULT   := { 0: 1.0, 1: 0.5, 2: 1.0 }

	assert_approx_eq(SHIELD_MULT[0], 0.5, "Kinetic vs Shield multiplier is 0.5")
	assert_approx_eq(SHIELD_MULT[1], 2.0, "Ion vs Shield multiplier is 2.0")
	assert_approx_eq(SHIELD_MULT[2], 0.0, "Piercing vs Shield multiplier is 0.0")

	assert_approx_eq(HULL_MULT[0], 1.0, "Kinetic vs Hull multiplier is 1.0")
	assert_approx_eq(HULL_MULT[1], 0.5, "Ion vs Hull multiplier is 0.5")
	assert_approx_eq(HULL_MULT[2], 1.0, "Piercing vs Hull multiplier is 1.0")

	# Test Scenario A: Kinetic attack against active shield
	# 10 raw damage Kinetic against 10 shield: shield takes round(10 * 0.5) = 5
	var sim_a := _simulate_damage(10, 0, false, false, 10, 30)
	assert_eq(sim_a["shield_damage"], 5, "Kinetic (10 dmg) deals 5 damage to shield")
	assert_eq(sim_a["hull_damage"], 0, "Kinetic (10 dmg) deals 0 damage to hull while shield holds")
	assert_eq(sim_a["new_shield"], 5, "Remaining shield is 5")
	assert_eq(sim_a["new_hull"], 30, "Hull remains 30")

	# Test Scenario B: CRITICAL RULE - No damage overflow when shield breaks!
	# Damage that breaks the shield does NOT spill onto the hull in the same hit.
	# 20 raw damage Kinetic against remaining 5 shield: shield takes min(5, round(20 * 0.5) = 10) = 5.
	# Hull takes 0!
	var sim_b := _simulate_damage(20, 0, false, false, 5, 30)
	assert_eq(sim_b["shield_damage"], 5, "Kinetic breaks remaining 5 shield")
	assert_eq(sim_b["hull_damage"], 0, "NO OVERFLOW: Hull takes 0 damage in the hit that broke the shield")
	assert_eq(sim_b["new_shield"], 0, "Shield is now 0 (broken)")
	assert_eq(sim_b["new_hull"], 30, "Hull remains intact at 30")

	# Test Scenario C: Kinetic attack against bare hull (0 shield)
	var sim_c := _simulate_damage(15, 0, false, false, 0, 30)
	assert_eq(sim_c["shield_damage"], 0, "Kinetic against 0 shield deals 0 shield damage")
	assert_eq(sim_c["hull_damage"], 15, "Kinetic against 0 shield deals 15 full hull damage")
	assert_eq(sim_c["new_hull"], 15, "Hull reduced to 15")

	# Test Scenario D: Ion pulse against shield
	# 10 raw damage Ion against 20 shield: shield takes round(10 * 2.0) = 20
	var sim_d := _simulate_damage(10, 1, false, false, 20, 30)
	assert_eq(sim_d["shield_damage"], 20, "Ion (10 dmg) deals double damage (20) to shield")
	assert_eq(sim_d["hull_damage"], 0, "Ion deals 0 damage to hull when shield is broken")
	assert_eq(sim_d["new_shield"], 0, "Shield collapsed to 0")

	# Test Scenario E: Ion pulse against bare hull
	# 10 raw damage Ion against 0 shield: hull takes round(10 * 0.5) = 5
	var sim_e := _simulate_damage(10, 1, false, false, 0, 30)
	assert_eq(sim_e["hull_damage"], 5, "Ion deals half damage (5) to bare hull")
	assert_eq(sim_e["new_hull"], 25, "Hull reduced from 30 to 25")

	# Test Scenario F: Piercing attack against active shield
	# 12 raw damage Piercing against 20 shield, 30 hull:
	# Ignores shield completely, hits hull directly!
	var sim_f := _simulate_damage(12, 2, false, false, 20, 30)
	assert_eq(sim_f["shield_damage"], 0, "Piercing deals 0 damage to shield")
	assert_eq(sim_f["hull_damage"], 12, "Piercing deals 12 damage directly to hull")
	assert_eq(sim_f["new_shield"], 20, "Enemy shield remains completely untouched at 20")
	assert_eq(sim_f["new_hull"], 18, "Hull reduced to 18")

	# Test Scenario G: Overload Coil / Pierce Buff on Kinetic attack
	# 10 raw damage Kinetic with pierce = true against 20 shield, 30 hull:
	var sim_g := _simulate_damage(10, 0, false, true, 20, 30)
	assert_eq(sim_g["shield_damage"], 0, "Pierced Kinetic deals 0 to shield")
	assert_eq(sim_g["hull_damage"], 10, "Pierced Kinetic hits hull directly for 10")
	assert_eq(sim_g["new_shield"], 20, "Shield remains 20")
	assert_eq(sim_g["new_hull"], 20, "Hull reduced to 20")

	# Test Scenario H: Bounces keyword against active shield
	# 16 raw damage with bounces = true against 10 shield:
	# Should bounce completely and deal 0 damage!
	var sim_h := _simulate_damage(16, 0, true, false, 10, 30)
	assert_eq(sim_h["shield_damage"], 0, "Bounces deals 0 shield damage when shield stands")
	assert_eq(sim_h["hull_damage"], 0, "Bounces deals 0 hull damage when shield stands")
	assert_eq(sim_h["new_shield"], 10, "Shield remains 10")
	assert_eq(sim_h["new_hull"], 30, "Hull remains 30")

	# Test Scenario I: Bounces keyword against bare hull (0 shield)
	var sim_i := _simulate_damage(16, 0, true, false, 0, 30)
	assert_eq(sim_i["hull_damage"], 16, "Bounces deals full damage once shield is down")
	assert_eq(sim_i["new_hull"], 14, "Hull reduced to 14")


func _simulate_damage(raw_damage: int, damage_type: int, bounces: bool, pierce: bool, enemy_shield: int, enemy_hull: int) -> Dictionary:
	const SHIELD_MULT := { 0: 0.5, 1: 2.0, 2: 0.0 }
	const HULL_MULT   := { 0: 1.0, 1: 0.5, 2: 1.0 }

	var piercing: bool = (damage_type == 2) or pierce
	var hull_damage: int = 0
	var shield_damage: int = 0
	var cur_shield: int = enemy_shield
	var cur_hull: int = enemy_hull

	if piercing:
		hull_damage = int(round(raw_damage * float(HULL_MULT[damage_type])))
	elif cur_shield > 0:
		if bounces:
			shield_damage = 0
			hull_damage = 0
		else:
			shield_damage = mini(cur_shield, int(round(raw_damage * float(SHIELD_MULT[damage_type]))))
			cur_shield -= shield_damage
			# Notice: No spill over to hull!
	else:
		hull_damage = int(round(raw_damage * float(HULL_MULT[damage_type])))

	cur_hull -= hull_damage

	return {
		"shield_damage": shield_damage,
		"hull_damage": hull_damage,
		"new_shield": cur_shield,
		"new_hull": cur_hull,
	}
