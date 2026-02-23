class_name ShipData
extends Resource

@export var ship_name: String = ""
@export var description: String = ""
@export var cost: int = 0
@export var base_max_hull: int = 30
@export var base_max_shield: int = 10
@export var base_cargo_capacity: int = 10
@export var base_energy_per_turn: int = 3
@export var base_hand_size: int = 5
@export var encounter_reduction: float = 0.0
@export var contraband_bonus: float = 0.0
@export var quest_reward_bonus: float = 0.0
@export var hull_color_primary: Color = Color(0.3, 0.85, 0.3)
@export var hull_shape: int = 0
@export var available_planet_types: Array[int] = []
