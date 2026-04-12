class_name RivalData
extends Resource

@export var rival_name: String = ""
@export var title: String = ""
@export var taunt_lines: Array[String] = []  # Eine Zeile pro Phase
@export var base_health: int = 25
@export var health_per_phase: int = 10
@export var base_attack_range: Vector2i = Vector2i(4, 8)
@export var attack_bonus_per_phase: int = 1
@export var special_abilities_by_phase: Array[int] = []  # SpecialAbility-Werte
@export var phase_descriptions: Array[String] = []
@export var reward_credits_base: int = 150
@export var reward_credits_per_phase: int = 75
