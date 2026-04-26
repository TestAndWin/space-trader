class_name CraftingRecipeData
extends Resource

@export var recipe_id: String = ""
@export var output_good: GoodData
@export var output_amount: int = 1
@export var inputs: Array[Dictionary] = []  # [{ "good": GoodData, "amount": int }]
@export var tier: int = 1
@export var build_trips: int = 2
@export var available_at_planets: Array[String] = []  # leer = alle Tech-Planeten
