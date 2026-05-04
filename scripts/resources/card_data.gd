class_name CardData
extends Resource

enum CardType { ATTACK, DEFENSE, UTILITY, TRADE }
enum CardRarity { COMMON, UNCOMMON, RARE }
enum CardKeyword { CHARGE, COMBO, SHIELD_ECHO, RECYCLING }
enum SpecialEffect { NONE, SELF_DAMAGE_5, BONUS_ENERGY_2, SKIP_ENEMY_TURN, END_ENCOUNTER, SCAVENGE }

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
@export var keywords: Array[int] = []  # CardKeyword values
