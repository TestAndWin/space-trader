class_name PlanetEventData
extends Resource

@export var event_name: String = ""
@export var description: String = ""
@export var planet_type: int = 0  # PlanetData.PlanetType value
@export var any_planet_type: bool = false  # If true, triggers on all planet types
@export var choice_a_text: String = ""
@export var choice_b_text: String = ""
@export var choice_a_description: String = ""
@export var choice_b_description: String = ""
# Outcomes
@export var choice_a_credits: int = 0  # + gain, - lose
@export var choice_a_hull: int = 0
@export var choice_a_cargo_good: String = ""
@export var choice_a_cargo_qty: int = 0  # + add, - remove
@export var choice_a_requires_good: String = ""
@export var choice_a_requires_qty: int = 0
@export var choice_b_credits: int = 0
@export var choice_b_hull: int = 0
@export var choice_b_cargo_good: String = ""
@export var choice_b_cargo_qty: int = 0
@export var has_random_outcome: bool = false
# Random outcome support: success_chance controls probability of primary outcome.
# If roll fails, alt values + alt description are used instead.
@export_range(0.0, 1.0) var choice_a_success_chance: float = 1.0
@export var choice_a_alt_description: String = ""
@export var choice_a_alt_credits: int = 0
@export var choice_a_alt_hull: int = 0
@export var choice_a_alt_cargo_good: String = ""
@export var choice_a_alt_cargo_qty: int = 0
@export_range(0.0, 1.0) var choice_b_success_chance: float = 1.0
@export var choice_b_alt_description: String = ""
@export var choice_b_alt_credits: int = 0
@export var choice_b_alt_hull: int = 0
@export var choice_b_alt_cargo_good: String = ""
@export var choice_b_alt_cargo_qty: int = 0
