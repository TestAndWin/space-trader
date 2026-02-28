extends Control

var destination_planet: String = ""
var dot_count: int = 0
var dot_timer: float = 0.0
var star_rects: Array = []

@onready var travel_label := $CenterContainer/VBoxContainer/TravelLabel
@onready var ship_icon := $CenterContainer/VBoxContainer/ShipContainer/ShipIcon
@onready var warning_label := $CenterContainer/VBoxContainer/WarningLabel


func _ready() -> void:
	destination_planet = GameManager.travel_destination if GameManager.travel_destination != "" else "Unknown"
	GameManager.total_flights += 1
	if EncounterManager.is_carrying_contraband():
		warning_label.text = "CONTRABAND ABOARD - Increased encounter risk!"
	travel_label.text = "Traveling to " + destination_planet + "..."
	_generate_starfield()
	_start_travel_animation()
	# Hyperspace flash
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.7)
	flash.size = Vector2(1280, 720)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	flash_tween.tween_callback(flash.queue_free)
	_add_cockpit_frame()


func _process(delta: float) -> void:
	dot_timer += delta
	if dot_timer >= 0.4:
		dot_timer = 0.0
		dot_count = (dot_count + 1) % 4
		var dots := ".".repeat(dot_count)
		travel_label.text = "Traveling to " + destination_planet + dots
	# Animate stars moving left for hyperspace feel
	for star in star_rects:
		if star is ColorRect:
			star.position.x -= delta * star.get_meta("speed", 100.0)
			if star.position.x < -10:
				star.position.x = 1290


func _generate_starfield() -> void:
	var stars_node := $Stars
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	for i in 80:
		var star := ColorRect.new()
		var sx: float = rng.randf_range(0, 1280)
		var sy: float = rng.randf_range(0, 720)
		star.position = Vector2(sx, sy)
		var s: float = rng.randf_range(1.0, 3.0)
		star.size = Vector2(s, 1.0)  # Stretch horizontally for warp effect
		var b: float = rng.randf_range(0.2, 0.8)
		star.color = Color(b * 0.9, b * 0.95, b, b)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.set_meta("speed", rng.randf_range(80.0, 300.0))
		stars_node.add_child(star)
		star_rects.append(star)


func _start_travel_animation() -> void:
	ship_icon.position.x = -50.0
	ship_icon.rotation = PI / 2  # Point right
	var tween := create_tween()
	tween.tween_property(ship_icon, "position:x", 450.0, 2.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_on_travel_complete)


func _on_travel_complete() -> void:
	set_process(false)
	var danger_level: int = 1
	for planet in EconomyManager.planets:
		if planet.planet_name == destination_planet:
			danger_level = planet.danger_level
			break
	if EncounterManager.should_encounter_happen(danger_level):
		var enc: Resource = EncounterManager.get_encounter(danger_level)
		if enc:
			GameManager.current_encounter = enc
			get_tree().change_scene_to_file("res://scenes/card_battle.tscn")
			return
	EventLog.add_entry("Arrived at %s" % destination_planet)
	GameManager.current_planet = destination_planet
	if destination_planet not in GameManager.visited_planets:
		GameManager.visited_planets.append(destination_planet)
	GameManager.change_scene("res://scenes/planet_screen.tscn")


func _add_cockpit_frame() -> void:
	var frame := Control.new()
	frame.name = "CockpitFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_script(load("res://scripts/components/cockpit_frame.gd"))
	add_child(frame)
