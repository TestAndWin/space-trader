class_name TravelEventData
extends Resource

@export var event_name: String = ""
@export var description: String = ""
@export var choice_a_text: String = ""
@export var choice_b_text: String = ""
@export var choice_a_description: String = ""
@export var choice_b_description: String = ""
# Outcomes
@export var choice_a_credits: int = 0  # + gain, - lose
@export var choice_a_hull: int = 0
@export var choice_b_credits: int = 0
@export var choice_b_hull: int = 0
@export var min_difficulty: int = 1
# Random outcome support: success_chance controls probability of primary outcome.
# If roll fails, alt values + alt description are used instead.
@export_range(0.0, 1.0) var choice_a_success_chance: float = 1.0
@export var choice_a_alt_description: String = ""
@export var choice_a_alt_credits: int = 0
@export var choice_a_alt_hull: int = 0
@export_range(0.0, 1.0) var choice_b_success_chance: float = 1.0
@export var choice_b_alt_description: String = ""
@export var choice_b_alt_credits: int = 0
@export var choice_b_alt_hull: int = 0
