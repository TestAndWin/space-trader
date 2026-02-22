class_name EncounterData
extends Resource

enum SpecialAbility { NONE, PLUNDER, SHIELD_BOOST, FLASH_GRENADE, ENERGY_DRAIN, ADAPTATION, FOCUS_FIRE, TRADE_OFFER, BOARDING }

@export var encounter_name: String = ""
@export var description: String = ""
@export var enemy_health: int = 20
@export var enemy_attack_range: Vector2i = Vector2i(3, 7)
@export var reward_credits: int = 100
@export var can_flee: bool = true
@export var difficulty: int = 1
@export var special_ability: SpecialAbility = SpecialAbility.NONE
@export var ability_description: String = ""
