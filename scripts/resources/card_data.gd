class_name CardData
extends Resource

enum CardType { ATTACK, DEFENSE, UTILITY, TRADE }
enum CardRarity { COMMON, UNCOMMON, RARE }
enum CardKeyword { CHARGE, COMBO, SHIELD_ECHO, RECYCLING, BOUNCES }
enum SpecialEffect { NONE, SELF_DAMAGE_5, BONUS_ENERGY_2, SKIP_ENEMY_TURN, END_ENCOUNTER, SCAVENGE, PIERCE_NEXT }

## How an attack interacts with an enemy shield. KINETIC is the plain shot:
## full damage to bare hull, half-effective against a shield. ION is the
## shield breaker, weak once the shield is gone. PIERCING ignores the shield
## entirely and always lands on the hull.
enum DamageType { KINETIC, ION, PIERCING }

@export var card_name: String = ""
@export var description: String = ""
@export var card_type: CardType = CardType.ATTACK
@export var rarity: CardRarity = CardRarity.COMMON
@export var energy_cost: int = 1
@export var attack_value: int = 0
@export var defense_value: int = 0
@export var heal_value: int = 0
@export var draw_cards: int = 0
@export var credits_gain: int = 0
@export var special_effect: SpecialEffect = SpecialEffect.NONE
@export var damage_type: DamageType = DamageType.KINETIC
@export var keywords: Array[int] = []  # CardKeyword values

@export_group("Boarding")
@export_multiline var boarding_description: String = ""
@export var boarding_alarm_vs_guards: int = -1
@export var boarding_alarm_vs_doors: int = -1
@export var boarding_alarm_vs_terminals: int = -1
@export var boarding_alarm_vs_vaults: int = -1
@export var boarding_alarm_vs_hostage: int = -1
