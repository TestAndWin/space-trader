class_name ShipUpgradeData
extends Resource

enum UpgradeSlot { ENGINE, HULL, SHIELDS, CARGO, WEAPONS, SPECIAL }

@export var upgrade_name: String = ""
@export var description: String = ""
@export var slot: UpgradeSlot = UpgradeSlot.HULL
@export var cost: int = 500
@export var cargo_bonus: int = 0
@export var hull_bonus: int = 0
@export var shield_bonus: int = 0
@export var cards_to_add: Array[Resource] = []
@export var hand_size_bonus: int = 0
@export var energy_bonus: int = 0
@export var required_crafted_items: Array[Dictionary] = []  # [{ "good": GoodData, "amount": int }]
@export var crafted_only: bool = false
