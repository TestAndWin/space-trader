class_name PlanetData
extends Resource

enum PlanetType { INDUSTRIAL, AGRICULTURAL, MINING, TECH, OUTLAW }

@export var planet_name: String = ""
@export var planet_type: PlanetType = PlanetType.INDUSTRIAL
@export var description: String = ""
@export var map_position: Vector2 = Vector2.ZERO
@export var danger_level: int = 1
@export var connected_planets: Array[String] = []
@export var image_hotspots: Dictionary = {}
