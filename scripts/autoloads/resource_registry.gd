extends Node

## Centralized resource path registry.
## DirAccess cannot list files inside packed PCK archives in exported builds.
## This registry provides hardcoded paths so load() works everywhere.

const PLANETS: Array[String] = [
	"res://data/planets/starport_alpha.tres",
	"res://data/planets/forge_world.tres",
	"res://data/planets/green_reach.tres",
	"res://data/planets/dust_haven.tres",
	"res://data/planets/iron_belt.tres",
	"res://data/planets/nova_station.tres",
	"res://data/planets/nexus_prime.tres",
]

const GOODS: Array[String] = [
	"res://data/goods/electronics.tres",
	"res://data/goods/food_rations.tres",
	"res://data/goods/luxury_goods.tres",
	"res://data/goods/medicine.tres",
	"res://data/goods/raw_ore.tres",
	"res://data/goods/spice.tres",
	"res://data/goods/stolen_tech.tres",
	"res://data/goods/weapons.tres",
]

const CARDS: Array[String] = [
	"res://data/cards/laser_shot.tres",
	"res://data/cards/heavy_blast.tres",
	"res://data/cards/shield_up.tres",
	"res://data/cards/evade.tres",
	"res://data/cards/patch_hull.tres",
	"res://data/cards/quick_draw.tres",
	"res://data/cards/torpedo.tres",
	"res://data/cards/overload.tres",
	"res://data/cards/deflector.tres",
	"res://data/cards/emergency_repair.tres",
	"res://data/cards/overclock.tres",
	"res://data/cards/negotiate.tres",
	"res://data/cards/bribe.tres",
	"res://data/cards/salvage.tres",
	"res://data/cards/ion_cannon.tres",
	"res://data/cards/power_shield.tres",
	"res://data/cards/emergency_dodge.tres",
	"res://data/cards/cargo_dump.tres",
	"res://data/cards/system_hack.tres",
	"res://data/cards/plasma_burst.tres",
	"res://data/cards/weak_shot.tres",
	"res://data/cards/flimsy_shield.tres",
	"res://data/cards/scavenge.tres",
	"res://data/cards/charged_strike.tres",
	"res://data/cards/chain_lightning.tres",
	"res://data/cards/shield_bash.tres",
	"res://data/cards/recycled_parts.tres",
	"res://data/cards/battle_fury.tres",
	"res://data/cards/tactical_link.tres",
	"res://data/cards/echo_barrier.tres",
	"res://data/cards/salvage_expert.tres",
]

const ENCOUNTERS: Array[String] = [
	"res://data/encounters/bounty_hunter.tres",
	"res://data/encounters/pirate_captain.tres",
	"res://data/encounters/pirate_raider.tres",
	"res://data/encounters/rogue_ai.tres",
	"res://data/encounters/smuggler_ambush.tres",
	"res://data/encounters/space_anomaly.tres",
	"res://data/encounters/system_patrol.tres",
	"res://data/encounters/wandering_trader.tres",
]

const UPGRADES: Array[String] = [
	"res://data/upgrades/reinforced_hull.tres",
	"res://data/upgrades/extended_cargo.tres",
	"res://data/upgrades/shield_generator.tres",
	"res://data/upgrades/auto_loader.tres",
	"res://data/upgrades/laser_array.tres",
	"res://data/upgrades/deflector_dish.tres",
	"res://data/upgrades/reactor_core.tres",
	"res://data/upgrades/med_bay.tres",
	"res://data/upgrades/smuggler_hold.tres",
	"res://data/upgrades/synergy_module.tres",
	"res://data/upgrades/combat_amplifier.tres",
	"res://data/upgrades/armor_plating.tres",
	"res://data/upgrades/combat_scanner.tres",
	"res://data/upgrades/shield_capacitor.tres",
	"res://data/upgrades/cloaking_device.tres",
]

const COMBAT_UPGRADES: Array[String] = [
	"res://data/upgrades/armor_plating.tres",
	"res://data/upgrades/combat_scanner.tres",
	"res://data/upgrades/shield_capacitor.tres",
]

const CREW: Array[String] = [
	"res://data/crew/navigator.tres",
	"res://data/crew/weapons_officer.tres",
	"res://data/crew/trader.tres",
	"res://data/crew/smuggler_crew.tres",
	"res://data/crew/medic.tres",
	"res://data/crew/engineer.tres",
]

const SHIPS: Array[String] = [
	"res://data/ships/scout.tres",
	"res://data/ships/freighter.tres",
	"res://data/ships/warship.tres",
	"res://data/ships/smuggler.tres",
	"res://data/ships/explorer.tres",
]

const PLANET_EVENTS: Array[String] = [
	"res://data/planet_events/factory_defect.tres",
	"res://data/planet_events/surplus_parts.tres",
	"res://data/planet_events/robot_rampage.tres",
	"res://data/planet_events/hungry_settlers.tres",
	"res://data/planet_events/bumper_crop.tres",
	"res://data/planet_events/pestilence.tres",
	"res://data/planet_events/asteroid_find.tres",
	"res://data/planet_events/cave_in.tres",
	"res://data/planet_events/rare_mineral.tres",
	"res://data/planet_events/data_cache.tres",
	"res://data/planet_events/ai_malfunction.tres",
	"res://data/planet_events/bounty_recognized.tres",
	"res://data/planet_events/black_market.tres",
	"res://data/planet_events/hired_muscle.tres",
	"res://data/planet_events/tech_experiment.tres",
	"res://data/planet_events/cargo_theft.tres",
]


const TRAVEL_EVENTS: Array[String] = [
	"res://data/travel_events/stranded_trader.tres",
	"res://data/travel_events/abandoned_wreck.tres",
	"res://data/travel_events/distress_signal.tres",
]


const RIVALS: Array[String] = [
	"res://data/rivals/captain_vex.tres",
]


func load_all(paths: Array[String]) -> Array:
	var results: Array = []
	for path in paths:
		var res: Resource = load(path)
		if res:
			results.append(res)
		else:
			push_warning("ResourceRegistry: failed to load '%s'" % path)
	return results
