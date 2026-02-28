extends Node2D

var planet_scene: PackedScene = preload("res://scenes/components/planet_node.tscn")
const CockpitFrame := preload("res://scripts/components/cockpit_frame.gd")
var planets: Array = []
var planet_nodes: Dictionary = {}   # { planet_name: PlanetNode }
var selected_planet: Resource = null
var _time: float = 0.0
var _twinkle_stars: Array = []  # { node: ColorRect, base_brightness: float, phase: float, speed: float }
var _nebula_clouds: Array = []  # { node: ColorRect, base_alpha: float, phase: float }
var _particles: Array = []      # { pos: Vector2, vel: Vector2, size: float, alpha: float, color: Color }
var _route_data: Array = []     # { from: Vector2, to: Vector2, is_active: bool }

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
	_init_particles()
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
	CockpitFrame.add_to(self, true)


func _process(delta: float) -> void:
	_time += delta
	# Animate twinkle stars
	for ts in _twinkle_stars:
		var node: ColorRect = ts["node"]
		var base: float = ts["base_brightness"]
		var phase: float = ts["phase"]
		var spd: float = ts["speed"]
		var brt: float = lerpf(base * 0.2, minf(base * 2.2, 1.0), (sin(_time * spd + phase) + 1.0) * 0.5)
		node.color = Color(brt, brt, minf(brt * 1.15, 1.0), brt)
		# Also animate size for bright stars to create glow pulsing
		if base > 0.5:
			var sz: float = 2.0 + sin(_time * spd * 0.7 + phase) * 0.8
			node.size = Vector2(sz, sz)
	# Animate nebula breathing
	for nc in _nebula_clouds:
		var node: ColorRect = nc["node"]
		var base_a: float = nc["base_alpha"]
		var phase: float = nc["phase"]
		var breath: float = sin(_time * 0.3 + phase) * 0.02
		var col: Color = node.color
		col.a = base_a + breath
		node.color = col
	# Move floating particles
	for p in _particles:
		p["pos"] += p["vel"] * delta
		# Wrap around screen
		if p["pos"].x < -20.0:
			p["pos"].x = 1300.0
		elif p["pos"].x > 1300.0:
			p["pos"].x = -20.0
		if p["pos"].y < -20.0:
			p["pos"].y = 740.0
		elif p["pos"].y > 740.0:
			p["pos"].y = -20.0
	# Request redraw for animated routes + particles
	queue_redraw()


func _draw() -> void:
	_draw_animated_routes()
	_draw_particles()


func _draw_animated_routes() -> void:
	for rd in _route_data:
		var from: Vector2 = rd["from"]
		var to: Vector2 = rd["to"]
		var is_active: bool = rd["is_active"]

		if is_active:
			# Outer glow line
			draw_line(from, to, Color(0.3, 0.55, 0.9, 0.12), 8.0, true)
			# Main route line
			draw_line(from, to, Color(0.4, 0.7, 1.0, 0.55), 2.5, true)
			# Bright core
			draw_line(from, to, Color(0.6, 0.85, 1.0, 0.45), 1.0, true)

			# Animated energy pulses traveling along the route
			var num_pulses: int = 3
			for i in num_pulses:
				var phase: float = float(i) / float(num_pulses)
				# t goes 0..1 along the route, wrapping
				var t: float = fmod(_time * 0.25 + phase, 1.0)
				var pulse_pos: Vector2 = from.lerp(to, t)
				# Pulse brightness fades at edges
				var edge_fade: float = 1.0 - abs(t - 0.5) * 2.0
				edge_fade = clampf(edge_fade, 0.0, 1.0)
				var pulse_alpha: float = 0.7 * edge_fade
				# Bright dot
				draw_circle(pulse_pos, 4.0, Color(0.5, 0.8, 1.0, pulse_alpha * 0.3))
				draw_circle(pulse_pos, 2.0, Color(0.7, 0.9, 1.0, pulse_alpha * 0.7))
				draw_circle(pulse_pos, 0.8, Color(1.0, 1.0, 1.0, pulse_alpha))
		else:
			# Inactive route: dim dashed appearance via alternating alpha
			var route_len: float = from.distance_to(to)
			var dir: Vector2 = (to - from).normalized()
			var seg_len: float = 12.0
			var segments: int = int(route_len / seg_len)
			for i in segments:
				if i % 2 == 0:
					var seg_start: Vector2 = from + dir * (float(i) * seg_len)
					var seg_end: Vector2 = from + dir * minf(float(i + 1) * seg_len, route_len)
					draw_line(seg_start, seg_end, Color(0.2, 0.3, 0.5, 0.18), 1.0, true)


func _draw_particles() -> void:
	for p in _particles:
		var pos: Vector2 = p["pos"]
		var sz: float = p["size"]
		var alpha: float = p["alpha"]
		var col: Color = p["color"]
		# Subtle pulsing alpha
		alpha *= 0.7 + sin(_time * 0.8 + pos.x * 0.01) * 0.3
		draw_circle(pos, sz, Color(col.r, col.g, col.b, alpha))
		# Tiny glow halo for larger particles
		if sz > 1.2:
			draw_circle(pos, sz * 2.5, Color(col.r, col.g, col.b, alpha * 0.15))


func _init_particles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var particle_colors: Array = [
		Color(0.4, 0.6, 1.0),   # blue
		Color(0.3, 0.8, 0.9),   # cyan
		Color(0.6, 0.4, 0.9),   # purple
		Color(0.9, 0.8, 0.5),   # gold
		Color(0.5, 0.7, 0.6),   # teal
	]
	for i in 30:
		_particles.append({
			"pos": Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)),
			"vel": Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-4.0, 4.0)),
			"size": rng.randf_range(0.5, 1.8),
			"alpha": rng.randf_range(0.08, 0.25),
			"color": particle_colors[i % particle_colors.size()],
		})


func _load_planets() -> void:
	planets = ResourceRegistry.load_all(ResourceRegistry.PLANETS)


func _generate_starfield() -> void:
	# Nebula clouds — larger, more vibrant
	var nebula_rng := RandomNumberGenerator.new()
	nebula_rng.seed = 7
	var nebula_colors: Array = [
		Color(0.35, 0.12, 0.55, 0.09),  # purple — more visible
		Color(0.12, 0.18, 0.45, 0.08),  # blue
		Color(0.45, 0.12, 0.18, 0.08),  # red
		Color(0.18, 0.12, 0.45, 0.09),  # indigo
		Color(0.12, 0.35, 0.45, 0.07),  # teal
		Color(0.4, 0.18, 0.35, 0.08),   # magenta
		Color(0.15, 0.25, 0.5, 0.06),   # deep blue — extra cloud
		Color(0.5, 0.2, 0.4, 0.05),     # rose — extra cloud
	]
	for i in nebula_colors.size():
		var cloud := ColorRect.new()
		cloud.position = Vector2(nebula_rng.randf_range(-150, 1000), nebula_rng.randf_range(-80, 550))
		cloud.size = Vector2(nebula_rng.randf_range(280, 550), nebula_rng.randf_range(220, 450))
		cloud.color = nebula_colors[i]
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		starfield.add_child(cloud)
		_nebula_clouds.append({ "node": cloud, "base_alpha": nebula_colors[i].a, "phase": nebula_rng.randf_range(0.0, TAU) })

	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # Fixed seed for consistent starfield
	# More stars for a richer background
	for i in 250:
		var star_x: float = rng.randf_range(0, 1280)
		var star_y: float = rng.randf_range(0, 720)
		var star_size: float = rng.randf_range(0.5, 2.2)
		var brightness: float = rng.randf_range(0.15, 0.75)
		var star := ColorRect.new()
		star.position = Vector2(star_x, star_y)
		star.size = Vector2(star_size, star_size)
		# Slight color variation — some stars bluish, some warm
		var tint: float = rng.randf_range(-0.08, 0.08)
		star.color = Color(brightness - tint, brightness, brightness + tint, brightness)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		starfield.add_child(star)
		# Every 5th star twinkles (50 total)
		if i % 5 == 0:
			_twinkle_stars.append({ "node": star, "base_brightness": brightness, "phase": rng.randf_range(0.0, TAU), "speed": rng.randf_range(1.2, 3.0) })
	# Bright accent stars with glow
	for i in 20:
		var star_x: float = rng.randf_range(0, 1280)
		var star_y: float = rng.randf_range(0, 720)
		var star := ColorRect.new()
		star.position = Vector2(star_x, star_y)
		star.size = Vector2(2.5, 2.5)
		# Blue-white bright stars
		var warmth: float = rng.randf_range(0.0, 0.15)
		star.color = Color(0.75 + warmth, 0.82, 0.95, 0.85)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		starfield.add_child(star)
		_twinkle_stars.append({ "node": star, "base_brightness": 0.85, "phase": rng.randf_range(0.0, TAU), "speed": rng.randf_range(1.5, 2.8) })


func _draw_routes() -> void:
	# Build route data for animated drawing (no static Line2D nodes for routes)
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

			_route_data.append({
				"from": planet.map_position,
				"to": target.map_position,
				"is_active": is_active,
			})


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


