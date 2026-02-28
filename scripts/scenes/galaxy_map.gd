extends Node2D

var planet_scene: PackedScene = preload("res://scenes/components/planet_node.tscn")
var planets: Array = []
var planet_nodes: Dictionary = {}   # { planet_name: PlanetNode }
var selected_planet: Resource = null

@onready var planets_container := $PlanetsContainer
@onready var routes_container := $RoutesContainer
@onready var starfield := $Starfield
@onready var player_icon := $PlayerIcon
@onready var credits_label := $CanvasLayer/TopBar/CreditsLabel
@onready var cargo_label := $CanvasLayer/TopBar/CargoLabel
@onready var info_panel := $CanvasLayer/InfoPanel
@onready var planet_name_label := $CanvasLayer/InfoPanel/VBoxContainer/PlanetNameLabel
@onready var planet_type_label := $CanvasLayer/InfoPanel/VBoxContainer/PlanetTypeLabel
@onready var danger_label := $CanvasLayer/InfoPanel/VBoxContainer/DangerLabel
@onready var travel_button := $CanvasLayer/TravelButton
@onready var current_planet_label := $CanvasLayer/TopBar/CurrentPlanetLabel
@onready var hull_label := $CanvasLayer/TopBar/HullLabel
@onready var shield_label := $CanvasLayer/TopBar/ShieldLabel
@onready var trades_label := $CanvasLayer/InfoPanel/VBoxContainer/TradesLabel
@onready var land_button := $CanvasLayer/LandButton


func _ready() -> void:
	_load_planets()
	_generate_starfield()
	_draw_routes()
	_spawn_planet_nodes()
	_update_planet_states()
	_update_player_position()
	_update_ui()
	# Add padding to info panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.06, 0.14, 0.92)
	panel_style.border_color = Color(0.0, 0.65, 0.95, 0.85)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.shadow_color = Color(0.0, 0.45, 0.9, 0.25)
	panel_style.shadow_size = 6
	info_panel.add_theme_stylebox_override("panel", panel_style)
	info_panel.visible = false
	travel_button.visible = false
	travel_button.pressed.connect(_on_travel_pressed)
	land_button.pressed.connect(_on_land_pressed)
	_style_nav_button(travel_button, Color(0.0, 0.85, 0.45))
	_style_nav_button(land_button, Color(0.0, 0.65, 0.95))
	_add_cockpit_frame()


func _load_planets() -> void:
	planets = ResourceRegistry.load_all(ResourceRegistry.PLANETS)


func _generate_starfield() -> void:
	# Nebula clouds
	var nebula_rng := RandomNumberGenerator.new()
	nebula_rng.seed = 7
	var nebula_colors: Array = [
		Color(0.3, 0.1, 0.5, 0.06),  # purple
		Color(0.1, 0.15, 0.4, 0.05), # blue
		Color(0.4, 0.1, 0.15, 0.05), # red
		Color(0.15, 0.1, 0.4, 0.06), # indigo
		Color(0.1, 0.3, 0.4, 0.04),  # teal
		Color(0.35, 0.15, 0.3, 0.05), # magenta
	]
	for i in 6:
		var cloud := ColorRect.new()
		cloud.position = Vector2(nebula_rng.randf_range(-100, 900), nebula_rng.randf_range(-50, 500))
		cloud.size = Vector2(nebula_rng.randf_range(250, 500), nebula_rng.randf_range(200, 400))
		cloud.color = nebula_colors[i]
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		starfield.add_child(cloud)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # Fixed seed for consistent starfield
	for i in 200:
		var star_x: float = rng.randf_range(0, 1280)
		var star_y: float = rng.randf_range(0, 720)
		var star_size: float = rng.randf_range(0.5, 2.0)
		var brightness: float = rng.randf_range(0.15, 0.7)
		var star := ColorRect.new()
		star.position = Vector2(star_x, star_y)
		star.size = Vector2(star_size, star_size)
		star.color = Color(brightness, brightness, brightness * 1.1, brightness)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		starfield.add_child(star)
	# A few brighter stars
	for i in 15:
		var star_x: float = rng.randf_range(0, 1280)
		var star_y: float = rng.randf_range(0, 720)
		var star := ColorRect.new()
		star.position = Vector2(star_x, star_y)
		star.size = Vector2(2.0, 2.0)
		star.color = Color(0.8, 0.85, 1.0, 0.8)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		starfield.add_child(star)


func _draw_routes() -> void:
	var drawn_pairs: Dictionary = {}
	var current_name: String = GameManager.current_planet
	var current_planet := _find_planet_by_name(current_name)
	var active_connections: Array = []
	if current_planet:
		active_connections = current_planet.connected_planets

	for planet in planets:
		for connected_name: String in planet.connected_planets:
			var pair_key := _route_key(planet.planet_name, connected_name)
			if pair_key in drawn_pairs:
				continue
			drawn_pairs[pair_key] = true
			var target := _find_planet_by_name(connected_name)
			if target == null:
				continue

			# Check if this route connects to current planet
			var is_active: bool = (planet.planet_name == current_name and connected_name in active_connections) or (connected_name == current_name and planet.planet_name in active_connections)

			if is_active:
				# Active route: bright, visible
				var line := Line2D.new()
				line.add_point(planet.map_position)
				line.add_point(target.map_position)
				line.width = 2.5
				line.default_color = Color(0.4, 0.7, 1.0, 0.6)
				line.antialiased = true
				routes_container.add_child(line)
				# Bright center glow
				var center_line := Line2D.new()
				center_line.add_point(planet.map_position)
				center_line.add_point(target.map_position)
				center_line.width = 1.0
				center_line.default_color = Color(0.6, 0.85, 1.0, 0.5)
				center_line.antialiased = true
				routes_container.add_child(center_line)
			else:
				# Inactive route: very dim
				var line := Line2D.new()
				line.add_point(planet.map_position)
				line.add_point(target.map_position)
				line.width = 1.0
				line.default_color = Color(0.15, 0.2, 0.35, 0.2)
				line.antialiased = true
				routes_container.add_child(line)


func _route_key(a: String, b: String) -> String:
	if a < b:
		return a + "|" + b
	return b + "|" + a


func _find_planet_by_name(pname: String) -> Resource:
	for p in planets:
		if p.planet_name == pname:
			return p
	return null


func _spawn_planet_nodes() -> void:
	for planet in planets:
		var node := planet_scene.instantiate()
		node.setup(planet)
		node.planet_clicked.connect(_on_planet_clicked)
		node.planet_hovered.connect(_on_planet_hovered)
		node.planet_unhovered.connect(_on_planet_unhovered)
		planets_container.add_child(node)
		planet_nodes[planet.planet_name] = node


func _update_planet_states() -> void:
	var current := _find_planet_by_name(GameManager.current_planet)
	var reachable_names: Array = []
	if current:
		reachable_names = current.connected_planets
	for pname in planet_nodes:
		var node: Node = planet_nodes[pname]
		node.set_current(pname == GameManager.current_planet)
		node.set_reachable(pname in reachable_names)


func _update_player_position() -> void:
	var current := _find_planet_by_name(GameManager.current_planet)
	if current:
		player_icon.position = current.map_position


func _update_ui() -> void:
	credits_label.text = "Credits: %d" % GameManager.credits
	cargo_label.text = "Cargo: %d/%d" % [GameManager.get_cargo_used(), GameManager.cargo_capacity]
	current_planet_label.text = "@ %s" % GameManager.current_planet
	hull_label.text = "Hull: %d/%d" % [GameManager.current_hull, GameManager.max_hull]
	shield_label.text = "Shield: %d/%d" % [GameManager.current_shield, GameManager.max_shield]


func _on_planet_clicked(planet_data: Resource) -> void:
	if planet_data.planet_name == GameManager.current_planet:
		selected_planet = null
		travel_button.visible = false
		land_button.visible = true
		return
	land_button.visible = false
	var current := _find_planet_by_name(GameManager.current_planet)
	if current and planet_data.planet_name in current.connected_planets:
		selected_planet = planet_data
		travel_button.visible = true
		travel_button.text = "Travel to %s" % planet_data.planet_name
	else:
		selected_planet = null
		travel_button.visible = false


func _on_planet_hovered(planet_data: Resource) -> void:
	info_panel.visible = true
	planet_name_label.text = planet_data.planet_name
	var type_text: String = EconomyManager.PLANET_TYPE_NAMES.get(planet_data.planet_type, "Unknown")
	planet_type_label.text = type_text
	danger_label.text = "Danger: %d" % planet_data.danger_level
	# Color danger
	if planet_data.danger_level >= 3:
		danger_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif planet_data.danger_level >= 2:
		danger_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		danger_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	# Color planet type
	var type_color: Color = Color(0.6, 0.6, 0.7)
	match planet_data.planet_type:
		0: type_color = Color(0.4, 0.6, 1.0)
		1: type_color = Color(0.4, 0.9, 0.4)
		2: type_color = Color(0.9, 0.6, 0.3)
		3: type_color = Color(0.3, 0.9, 1.0)
		4: type_color = Color(1.0, 0.3, 0.3)
	planet_type_label.add_theme_color_override("font_color", type_color)
	# Available goods
	var available: Array = EconomyManager.get_available_goods(type_text)
	if available.size() > 0:
		trades_label.text = "Trades: " + ", ".join(available)
	else:
		trades_label.text = ""


func _on_planet_unhovered() -> void:
	info_panel.visible = false


func _on_travel_pressed() -> void:
	if selected_planet == null:
		return
	GameManager.travel_origin = GameManager.current_planet
	GameManager.travel_destination = selected_planet.planet_name
	GameManager.change_scene("res://scenes/travel_scene.tscn")


func _style_nav_button(btn: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.5)
	normal.bg_color.a = 0.85
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.3)
	normal.shadow_size = 6
	var hover := normal.duplicate()
	hover.bg_color = accent.darkened(0.35)
	hover.bg_color.a = 0.9
	hover.border_color = accent.lightened(0.1)
	var pressed := normal.duplicate()
	pressed.bg_color = accent.darkened(0.6)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	btn.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.0))


func _on_land_pressed() -> void:
	GameManager.change_scene("res://scenes/planet_screen.tscn")


func _add_cockpit_frame() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var frame := Control.new()
	frame.name = "CockpitFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_script(load("res://scripts/components/cockpit_frame.gd"))
	layer.add_child(frame)
