extends Control

const CockpitFrame := preload("res://scripts/components/cockpit_frame.gd")

var destination_planet: String = ""
var dot_count: int = 0
var dot_timer: float = 0.0
var star_rects: Array = []

# Planet type accent colors matching planet_background.gd atmosphere palette
const PLANET_WARP_COLORS: Dictionary = {
	0: Color(0.5, 0.55, 0.7),    # INDUSTRIAL  - steel blue
	1: Color(0.3, 0.7, 0.4),     # AGRICULTURAL - green
	2: Color(0.7, 0.5, 0.25),    # MINING       - orange/brown
	3: Color(0.25, 0.6, 0.85),   # TECH         - cyan
	4: Color(0.6, 0.15, 0.15),   # OUTLAW       - dark red
}

@onready var travel_label := $CenterContainer/VBoxContainer/TravelLabel
@onready var ship_icon := $CenterContainer/VBoxContainer/ShipContainer/ShipIcon
@onready var warning_label := $CenterContainer/VBoxContainer/WarningLabel


func _ready() -> void:
	destination_planet = GameManager.travel_destination if GameManager.travel_destination != "" else "Unknown"
	GameManager.total_flights += 1
	if EncounterManager.is_carrying_contraband():
		warning_label.text = "CONTRABAND ABOARD - Increased encounter risk!"
	travel_label.text = "Traveling to " + destination_planet + "..."

	# Determine destination planet type for color theming
	var dest_type: int = _get_destination_type()
	var warp_color: Color = PLANET_WARP_COLORS.get(dest_type, PLANET_WARP_COLORS[3])

	# Subtle background tint toward destination planet color
	var bg := $Background as ColorRect
	bg.color = Color(
		0.01 + warp_color.r * 0.05,
		0.02 + warp_color.g * 0.05,
		0.05 + warp_color.b * 0.05,
		1.0
	)

	_generate_starfield(warp_color)
	_add_warp_effect(warp_color)
	_start_travel_animation()

	# Hyperspace flash tinted by destination planet color
	var flash := ColorRect.new()
	flash.color = Color(
		warp_color.r * 0.5 + 0.5,
		warp_color.g * 0.5 + 0.5,
		warp_color.b * 0.5 + 0.5,
		0.75
	)
	flash.size = Vector2(1280, 720)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	flash_tween.tween_callback(flash.queue_free)
	CockpitFrame.add_to(self)


func _get_destination_type() -> int:
	for planet in EconomyManager.planets:
		if planet.planet_name == destination_planet:
			return planet.planet_type
	return 3  # Default: Tech (cyan)


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


func _generate_starfield(warp_color: Color) -> void:
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
		var brightness: float = rng.randf_range(0.2, 0.8)
		# Blend neutral white-blue with destination planet color
		var tint: float = rng.randf_range(0.2, 0.6)
		var cr: float = lerpf(brightness * 0.9, warp_color.r * brightness, tint)
		var cg: float = lerpf(brightness * 0.95, warp_color.g * brightness, tint)
		var cb: float = lerpf(brightness, warp_color.b * brightness, tint)
		star.color = Color(cr, cg, cb, brightness)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.set_meta("speed", rng.randf_range(80.0, 300.0))
		stars_node.add_child(star)
		star_rects.append(star)


func _add_warp_effect(warp_color: Color) -> void:
	var warp := Control.new()
	warp.name = "WarpEffect"
	warp.set_anchors_preset(Control.PRESET_FULL_RECT)
	warp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warp.set_script(load("res://scripts/components/warp_effect.gd"))
	add_child(warp)
	# Place between Background (0) and Stars (1) so tunnel is behind the star streaks
	move_child(warp, 1)
	warp.call("setup", warp_color)


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
