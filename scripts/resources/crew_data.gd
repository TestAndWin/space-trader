class_name CrewData
extends Resource

enum CrewBonus { ENCOUNTER_REDUCTION, ATTACK_BONUS, HULL_REGEN, SELL_BONUS, SMUGGLE_PROTECTION, MAX_HULL_BONUS, GAMBLING_EDGE, COMBAT_HEAL }

@export var crew_name: String = ""
@export var title: String = ""
@export var description: String = ""
@export var bonus_type: CrewBonus = CrewBonus.ENCOUNTER_REDUCTION
@export var bonus_value: float = 0.0
@export var recruit_cost: int = 0
@export var available_planet_types: Array[int] = []
