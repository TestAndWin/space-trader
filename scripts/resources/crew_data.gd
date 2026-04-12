class_name CrewData
extends Resource

enum CrewBonus { ENCOUNTER_REDUCTION, ATTACK_BONUS, HULL_REGEN, SELL_BONUS,
	SMUGGLE_PROTECTION, MAX_HULL_BONUS, GAMBLING_EDGE, COMBAT_HEAL,
	EVENT_SKILL, QUEST_NEGOTIATION, COMBAT_TACTICAL }

@export var crew_name: String = ""
@export var title: String = ""
@export var description: String = ""
@export var bonus_type: CrewBonus = CrewBonus.ENCOUNTER_REDUCTION
@export var bonus_value: float = 0.0
@export var recruit_cost: int = 0
@export var available_planet_types: Array[int] = []

@export var secondary_bonus_type: CrewBonus = CrewBonus.ENCOUNTER_REDUCTION
@export var secondary_bonus_value: float = 0.0
@export var event_flavor_tag: String = ""  # "tech", "combat", "trade", "medical", "exploration", "underworld"
