class_name EncounterData
extends Resource

enum SpecialAbility { NONE, PLUNDER, SHIELD_BOOST, FLASH_GRENADE, ENERGY_DRAIN, ADAPTATION, FOCUS_FIRE, TRADE_OFFER, BOARDING, CRIMSON_FURY }

@export var encounter_name: String = ""
@export var description: String = ""
@export var enemy_health: int = 20
@export var enemy_attack_range: Vector2i = Vector2i(3, 7)
@export var reward_credits: int = 100
@export var can_flee: bool = true
@export var difficulty: int = 1
@export var special_ability: SpecialAbility = SpecialAbility.NONE
@export var ability_description: String = ""

@export_group("Shield")
## Deflector capacity. 0 leaves the enemy unshielded — the plain fight that
## teaches the basics. A shield is a second, separate health pool: damage that
## breaks it never spills over onto the hull in the same hit.
@export var enemy_max_shield: int = 0
## Shield points restored at the start of every player turn. This is what turns
## "grind the shield down" into "burst it down inside a window".
@export var shield_regen: int = 0
## Player turns the emitter stays offline after the shield is broken. A long
## delay buys the player a wide hull window, a short one punishes hesitation.
@export var shield_regen_delay: int = 0

# Rival encounter fields (Finding #9 — typisierte Properties statt set_meta)
var is_rival: bool = false
var taunt_line: String = ""
var rival_phase: int = -1
