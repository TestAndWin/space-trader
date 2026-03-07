extends Node3D

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")


const GALAXY_CENTER_2D := Vector2(640.0, 360.0)
const GALAXY_WORLD_SCALE: float = 72.0
const GALAXY_SPREAD: float = 4.20
const STARFIELD_DEPTH_NEAR: float = -8.0
const STARFIELD_DEPTH_FAR: float = -42.0

var planets: Array = []
var selected_planet: Resource = null

var _time: float = 0.0
var _planet_visuals: Dictionary = {} # { planet_name: { planet, node, body, body_mat, glow, glow_mat, ring, ring_mat, label, base_color, base_position, phase } }
var _route_data: Array = []          # [{ from_name, to_name, from_pos, to_pos, is_active, line, core, pulses, phases }]
var _hovered_planet_name: String = ""
var _player_marker: Node3D
var _player_marker_base_position: Vector3 = Vector3.ZERO

@onready var map_camera: Camera3D = $GalaxyWorld/MapCamera
@onready var world_environment: WorldEnvironment = $GalaxyWorld/WorldEnvironment
@onready var starfield_container: Node3D = $GalaxyWorld/Starfield3D
@onready var nebula_container: Node3D = $GalaxyWorld/Nebulae3D
@onready var routes_container: Node3D = $GalaxyWorld/Routes3D
@onready var planets_container: Node3D = $GalaxyWorld/Planets3D
@onready var markers_container: Node3D = $GalaxyWorld/Markers3D

@onready var credits_label := $CanvasLayer/BottomBar/HBoxContainer/CreditsLabel
@onready var cargo_label := $CanvasLayer/BottomBar/HBoxContainer/CargoLabel
@onready var info_panel := $CanvasLayer/InfoPanel
@onready var planet_name_label := $CanvasLayer/InfoPanel/VBoxContainer/PlanetNameLabel
@onready var planet_type_label := $CanvasLayer/InfoPanel/VBoxContainer/PlanetTypeLabel
@onready var danger_label := $CanvasLayer/InfoPanel/VBoxContainer/DangerLabel
@onready var travel_button := $CanvasLayer/InfoPanel/VBoxContainer/TravelButton
@onready var current_planet_label := $CanvasLayer/BottomBar/HBoxContainer/CurrentPlanetLabel
@onready var hull_label := $CanvasLayer/BottomBar/HBoxContainer/HullLabel
@onready var shield_label := $CanvasLayer/BottomBar/HBoxContainer/ShieldLabel
@onready var trades_label := $CanvasLayer/InfoPanel/VBoxContainer/TradesLabel
@onready var land_button := $CanvasLayer/InfoPanel/VBoxContainer/LandButton


func _ready() -> void:
	_load_planets()
	_setup_environment()
	_generate_starfield()
	_generate_nebulae()
	_spawn_planets()
	_build_routes()
	_create_player_marker()
	_update_planet_states()
	_update_player_position()
	_update_ui()
	_configure_info_panel()

	travel_button.visible = false
	land_button.visible = true
	travel_button.pressed.connect(_on_travel_pressed)
	land_button.pressed.connect(_on_land_pressed)
	_style_nav_button(travel_button, Color(0.0, 0.85, 0.45))
	_style_nav_button(land_button, Color(0.0, 0.65, 0.95))

	# Show info panel with current planet on start
	var current := _find_planet_by_name(GameManager.current_planet)
	if current:
		_on_planet_hovered(current)

	map_camera.position = Vector3(0.0, 0.35, 24.0)
	map_camera.look_at(Vector3(0.0, -0.1, 0.0), Vector3.UP)
	_add_galaxy_background()
	_style_bottom_bar()


func _style_bottom_bar() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.14, 0.75)
	style.border_color = Color(0.0, 0.65, 0.95, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.45, 0.9, 0.25)
	style.shadow_size = 6
	style.set_content_margin_all(8)
	$CanvasLayer/BottomBar.add_theme_stylebox_override("panel", style)


func _process(delta: float) -> void:
	_time += delta
	_animate_camera()
	_animate_planets(delta)
	_animate_routes()
	_animate_player_marker()


func _configure_info_panel() -> void:
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


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.005, 0.01, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.17, 0.28)
	env.ambient_light_energy = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 0.75
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	world_environment.environment = env


func _generate_starfield() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8842

	# Wide background coverage so stars are visible across the whole screen area.
	for i in 980:
		var star := MeshInstance3D.new()
		var star_mesh := SphereMesh.new()
		var size: float = rng.randf_range(0.010, 0.050)
		star_mesh.radius = size
		star_mesh.height = size * 2.0
		star_mesh.radial_segments = 8
		star_mesh.rings = 4
		star.mesh = star_mesh

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var brightness: float = rng.randf_range(0.12, 0.72)
		var cool_shift: float = rng.randf_range(-0.07, 0.09)
		mat.albedo_color = Color(
			clampf(brightness - cool_shift, 0.0, 1.0),
			clampf(brightness, 0.0, 1.0),
			clampf(brightness + cool_shift * 1.25, 0.0, 1.0),
			rng.randf_range(0.16, 0.65)
		)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = rng.randf_range(0.45, 1.15)
		star.material_override = mat

		star.position = Vector3(
			rng.randf_range(-95.0, 95.0),
			rng.randf_range(-56.0, 56.0),
			rng.randf_range(-72.0, STARFIELD_DEPTH_NEAR)
		)
		starfield_container.add_child(star)

	# Brighter accent stars on top of the faint field.
	for i in 140:
		var star := MeshInstance3D.new()
		var star_mesh := SphereMesh.new()
		var size: float = rng.randf_range(0.050, 0.120)
		star_mesh.radius = size
		star_mesh.height = size * 2.0
		star_mesh.radial_segments = 10
		star_mesh.rings = 5
		star.mesh = star_mesh

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var brightness: float = rng.randf_range(0.65, 1.0)
		var tint: float = rng.randf_range(-0.08, 0.08)
		mat.albedo_color = Color(
			clampf(brightness + tint, 0.0, 1.0),
			clampf(brightness, 0.0, 1.0),
			clampf(brightness - tint * 0.8, 0.0, 1.0),
			rng.randf_range(0.60, 0.95)
		)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = rng.randf_range(1.2, 2.0)
		star.material_override = mat

		star.position = Vector3(
			rng.randf_range(-95.0, 95.0),
			rng.randf_range(-56.0, 56.0),
			rng.randf_range(-72.0, STARFIELD_DEPTH_NEAR)
		)
		starfield_container.add_child(star)


func _generate_nebulae() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9901
	var nebula_colors: Array = [
		Color(0.50, 0.22, 0.66),
		Color(0.18, 0.35, 0.75),
		Color(0.62, 0.25, 0.32),
		Color(0.24, 0.52, 0.62),
		Color(0.42, 0.28, 0.54),
	]

	# Broad, subtle volumetric nebula pass across the full background area.
	for i in 16:
		var cloud_color: Color = nebula_colors[i % nebula_colors.size()]
		var cluster := Node3D.new()
		cluster.position = Vector3(
			rng.randf_range(-86.0, 86.0),
			rng.randf_range(-50.0, 50.0),
			rng.randf_range(-66.0, -12.0)
		)
		nebula_container.add_child(cluster)

		for j in 2:
			var fog := FogVolume.new()
			fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
			fog.size = Vector3(
				rng.randf_range(8.0, 18.0),
				rng.randf_range(4.2, 10.0),
				rng.randf_range(8.0, 17.0)
			)
			fog.position = Vector3(
				rng.randf_range(-3.6, 3.6),
				rng.randf_range(-2.0, 2.0),
				rng.randf_range(-3.2, 3.2)
			)

			var fog_material := FogMaterial.new()
			fog_material.albedo = Color(cloud_color.r, cloud_color.g, cloud_color.b, 1.0)
			fog_material.emission = Color(cloud_color.r * 0.18, cloud_color.g * 0.18, cloud_color.b * 0.22, 1.0)
			fog_material.density = rng.randf_range(0.018, 0.050)
			fog.material = fog_material
			cluster.add_child(fog)


func _load_planets() -> void:
	planets = ResourceRegistry.load_all(ResourceRegistry.PLANETS)


func _spawn_planets() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 321

	for planet: Resource in planets:
		var node := Node3D.new()
		node.name = "Planet_%s" % planet.planet_name.replace(" ", "_")
		var world_pos: Vector3 = _planet_to_world(planet)
		node.position = world_pos
		planets_container.add_child(node)

		var base_color: Color = UIStyles.TYPE_COLORS.get(planet.planet_type, Color(0.8, 0.8, 0.9))
		var radius: float = 0.92 + float(planet.danger_level) * 0.14

		var sphere := MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = radius
		sphere_mesh.height = radius * 2.0
		sphere_mesh.radial_segments = 36
		sphere_mesh.rings = 18
		sphere.mesh = sphere_mesh
		var sphere_mat := StandardMaterial3D.new()
		sphere_mat.albedo_color = base_color
		sphere_mat.metallic = 0.08
		sphere_mat.roughness = 0.32
		sphere_mat.emission_enabled = true
		sphere_mat.emission = base_color
		sphere_mat.emission_energy_multiplier = 0.75
		sphere.material_override = sphere_mat
		node.add_child(sphere)

		var glow := MeshInstance3D.new()
		var glow_mesh := SphereMesh.new()
		glow_mesh.radius = radius * 1.55
		glow_mesh.height = radius * 3.1
		glow_mesh.radial_segments = 24
		glow_mesh.rings = 12
		glow.mesh = glow_mesh
		var glow_mat := StandardMaterial3D.new()
		glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow_mat.albedo_color = Color(base_color.r, base_color.g, base_color.b, 0.13)
		glow_mat.emission_enabled = true
		glow_mat.emission = base_color
		glow_mat.emission_energy_multiplier = 1.1
		glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		glow.material_override = glow_mat
		node.add_child(glow)

		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = radius * 1.55
		ring_mesh.outer_radius = radius * 1.78
		ring_mesh.rings = 32
		ring_mesh.ring_segments = 12
		ring.mesh = ring_mesh
		ring.rotation.x = PI * 0.5
		var ring_mat := StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color = Color(0.65, 0.85, 1.0, 0.0)
		ring_mat.emission_enabled = true
		ring_mat.emission = Color(0.65, 0.85, 1.0)
		ring_mat.emission_energy_multiplier = 1.8
		ring.material_override = ring_mat
		node.add_child(ring)

		var area := Area3D.new()
		area.input_ray_pickable = true
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = radius * 2.35
		collision.shape = shape
		area.add_child(collision)
		area.mouse_entered.connect(_on_planet_mouse_entered.bind(planet))
		area.mouse_exited.connect(_on_planet_mouse_exited.bind(planet))
		area.input_event.connect(_on_planet_input_event.bind(planet))
		node.add_child(area)

		var label := Label3D.new()
		label.text = planet.planet_name
		label.position = Vector3(0.0, radius * 2.35, 0.0)
		label.font_size = 54
		label.pixel_size = 0.0105
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.92, 0.97, 1.0, 1.0)
		label.outline_modulate = Color(0.0, 0.03, 0.09, 1.0)
		label.outline_size = 18
		node.add_child(label)

		_planet_visuals[planet.planet_name] = {
			"planet": planet,
			"node": node,
			"body": sphere,
			"body_mat": sphere_mat,
			"glow": glow,
			"glow_mat": glow_mat,
			"ring": ring,
			"ring_mat": ring_mat,
			"label": label,
			"base_color": base_color,
			"base_position": world_pos,
			"phase": rng.randf_range(0.0, TAU),
		}


func _planet_to_world(planet: Resource) -> Vector3:
	var map_pos: Vector2 = planet.map_position
	var x: float = ((map_pos.x - GALAXY_CENTER_2D.x) / GALAXY_WORLD_SCALE) * GALAXY_SPREAD
	var y: float = ((GALAXY_CENTER_2D.y - map_pos.y) / GALAXY_WORLD_SCALE) * GALAXY_SPREAD
	var z: float = _depth_offset(planet.planet_name, map_pos)
	return Vector3(x, y, z)


func _depth_offset(planet_name: String, map_pos: Vector2) -> float:
	var hash_val: int = abs(planet_name.hash())
	var base: float = (float(hash_val % 1000) / 999.0) * 4.8 - 2.4
	var wave: float = sin(map_pos.x * 0.0105 + map_pos.y * 0.016) * 0.7
	return base + wave


func _build_routes() -> void:
	_route_data.clear()
	for child in routes_container.get_children():
		child.queue_free()

	var drawn_pairs: Dictionary = {}
	var current_name: String = GameManager.current_planet
	var current_planet := _find_planet_by_name(current_name)
	var active_connections: Array = []
	if current_planet:
		active_connections = current_planet.connected_planets

	for planet: Resource in planets:
		for connected_name: String in planet.connected_planets:
			var pair_key := _route_key(planet.planet_name, connected_name)
			if pair_key in drawn_pairs:
				continue
			drawn_pairs[pair_key] = true
			var target := _find_planet_by_name(connected_name)
			if target == null:
				continue

			var is_active: bool = (planet.planet_name == current_name and connected_name in active_connections) or (connected_name == current_name and planet.planet_name in active_connections)
			var from_pos: Vector3 = _planet_to_world(planet)
			var to_pos: Vector3 = _planet_to_world(target)

			var route_root := Node3D.new()
			route_root.name = "Route_%s" % pair_key.replace("|", "_")
			routes_container.add_child(route_root)

			var glow_color := Color(0.34, 0.60, 1.0)
			var core_color := Color(0.66, 0.88, 1.0)
			var dim_color := Color(0.20, 0.35, 0.55)
			var line: MeshInstance3D
			var core: MeshInstance3D = null
			var pulses: Array = []
			var phases: Array = []

			if is_active:
				line = _create_route_segment(from_pos, to_pos, glow_color, 0.095, 0.18, 1.8)
				core = _create_route_segment(from_pos, to_pos, core_color, 0.030, 0.95, 2.8)
				route_root.add_child(line)
				route_root.add_child(core)

				for i in 4:
					var pulse := MeshInstance3D.new()
					var pulse_mesh := SphereMesh.new()
					pulse_mesh.radius = 0.10
					pulse_mesh.height = 0.20
					pulse_mesh.radial_segments = 18
					pulse_mesh.rings = 10
					pulse.mesh = pulse_mesh
					var pulse_mat := StandardMaterial3D.new()
					pulse_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					pulse_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					pulse_mat.albedo_color = Color(0.78, 0.94, 1.0, 0.95)
					pulse_mat.emission_enabled = true
					pulse_mat.emission = Color(0.72, 0.90, 1.0)
					pulse_mat.emission_energy_multiplier = 3.2
					pulse.material_override = pulse_mat
					route_root.add_child(pulse)
					pulses.append(pulse)
					phases.append(float(i) / 4.0)
			else:
				line = _create_route_segment(from_pos, to_pos, dim_color, 0.018, 0.26, 0.4)
				route_root.add_child(line)

			_route_data.append({
				"from_name": planet.planet_name,
				"to_name": connected_name,
				"from_pos": from_pos,
				"to_pos": to_pos,
				"is_active": is_active,
				"line": line,
				"core": core,
				"pulses": pulses,
				"phases": phases,
			})


func _create_route_segment(from_pos: Vector3, to_pos: Vector3, color: Color, radius: float, alpha: float, emissive_energy: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	var length: float = from_pos.distance_to(to_pos)
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = maxf(length, 0.01)
	mesh.radial_segments = 16
	mesh_instance.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emissive_energy
	mesh_instance.material_override = mat

	_align_between(mesh_instance, from_pos, to_pos)
	return mesh_instance


func _align_between(node: Node3D, from_pos: Vector3, to_pos: Vector3) -> void:
	var delta: Vector3 = to_pos - from_pos
	var up: Vector3 = delta.normalized()
	var right: Vector3 = up.cross(Vector3.FORWARD)
	if right.length_squared() < 0.0001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	var forward: Vector3 = right.cross(up).normalized()
	node.transform = Transform3D(Basis(right, up, forward), (from_pos + to_pos) * 0.5)


func _create_player_marker() -> void:
	_player_marker = Node3D.new()
	_player_marker.name = "PlayerMarker"
	markers_container.add_child(_player_marker)

	var ship := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.13
	cone.height = 0.32
	cone.radial_segments = 12
	ship.mesh = cone
	ship.rotation_degrees.x = 180.0
	var ship_mat := StandardMaterial3D.new()
	ship_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ship_mat.albedo_color = Color(0.95, 0.98, 1.0, 0.95)
	ship_mat.emission_enabled = true
	ship_mat.emission = Color(0.40, 0.85, 1.0)
	ship_mat.emission_energy_multiplier = 2.1
	ship.material_override = ship_mat
	_player_marker.add_child(ship)

	var halo := MeshInstance3D.new()
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 0.23
	halo_mesh.height = 0.46
	halo_mesh.radial_segments = 16
	halo_mesh.rings = 8
	halo.mesh = halo_mesh
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(0.30, 0.75, 1.0, 0.22)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(0.32, 0.74, 1.0)
	halo_mat.emission_energy_multiplier = 2.8
	halo.material_override = halo_mat
	_player_marker.add_child(halo)


func _animate_camera() -> void:
	var base_pos := Vector3(0.0, 0.35, 24.0)
	map_camera.position = base_pos + Vector3(
		sin(_time * 0.13) * 0.55,
		cos(_time * 0.19) * 0.24,
		0.0
	)
	map_camera.look_at(Vector3(0.0, -0.1, 0.0), Vector3.UP)


func _animate_planets(delta: float) -> void:
	for planet_name_key in _planet_visuals.keys():
		var planet_name: String = str(planet_name_key)
		var visual: Dictionary = _planet_visuals[planet_name]
		var node: Node3D = visual["node"]
		var glow: MeshInstance3D = visual["glow"]
		var ring: MeshInstance3D = visual["ring"]
		var base_pos: Vector3 = visual["base_position"]
		var phase: float = visual["phase"]
		var is_current: bool = planet_name == GameManager.current_planet

		node.rotation.y += delta * (0.55 + phase * 0.03)
		var bob: float = sin(_time * 1.4 + phase) * 0.045
		node.position = base_pos + Vector3(0.0, bob + (0.08 if is_current else 0.0), 0.0)

		var glow_pulse: float = 0.95 + sin(_time * 2.1 + phase) * 0.07
		glow.scale = Vector3.ONE * glow_pulse
		ring.rotation.z = _time * 0.45 + phase


func _animate_routes() -> void:
	for route: Dictionary in _route_data:
		if not route["is_active"]:
			continue
		var from_pos: Vector3 = route["from_pos"]
		var to_pos: Vector3 = route["to_pos"]
		var pulses: Array = route["pulses"]
		var phases: Array = route["phases"]
		for i in pulses.size():
			var pulse: MeshInstance3D = pulses[i]
			var phase: float = phases[i]
			var t: float = fmod(_time * 0.24 + phase, 1.0)
			pulse.position = from_pos.lerp(to_pos, t)
			var pulse_scale: float = 0.75 + sin(_time * 6.0 + phase * TAU) * 0.2
			pulse.scale = Vector3.ONE * pulse_scale


func _animate_player_marker() -> void:
	if _player_marker == null:
		return
	_player_marker.rotation.y = _time * 1.1
	_player_marker.position = _player_marker_base_position + Vector3(0.0, sin(_time * 2.6) * 0.08, 0.0)


func _find_planet_by_name(pname: String) -> Resource:
	for p: Resource in planets:
		if p.planet_name == pname:
			return p
	return null


func _route_key(a: String, b: String) -> String:
	if a < b:
		return a + "|" + b
	return b + "|" + a


func _update_planet_states() -> void:
	var current := _find_planet_by_name(GameManager.current_planet)
	var reachable_names: Array = []
	if current:
		reachable_names = current.connected_planets

	for planet_name_key in _planet_visuals.keys():
		var planet_name: String = str(planet_name_key)
		var visual: Dictionary = _planet_visuals[planet_name]
		var body_mat: StandardMaterial3D = visual["body_mat"]
		var glow_mat: StandardMaterial3D = visual["glow_mat"]
		var ring_mat: StandardMaterial3D = visual["ring_mat"]
		var label: Label3D = visual["label"]
		var base_color: Color = visual["base_color"]
		var is_current: bool = planet_name == GameManager.current_planet
		var is_reachable: bool = planet_name in reachable_names
		var is_hovered: bool = planet_name == _hovered_planet_name

		var dim_factor: float = 1.0
		if not is_current and not is_reachable and not is_hovered:
			dim_factor = 0.35

		var lit_color := base_color
		if is_hovered:
			lit_color = lit_color.lightened(0.18)
		if is_current:
			lit_color = lit_color.lightened(0.24)

		body_mat.albedo_color = Color(lit_color.r * dim_factor, lit_color.g * dim_factor, lit_color.b * dim_factor, 1.0)
		body_mat.emission = lit_color
		body_mat.emission_energy_multiplier = 0.45 + (1.2 if is_current else 0.55 if is_reachable else 0.0) + (0.35 if is_hovered else 0.0)

		glow_mat.albedo_color = Color(lit_color.r, lit_color.g, lit_color.b, 0.08 + (0.17 if is_current else 0.10 if is_reachable else 0.0) + (0.10 if is_hovered else 0.0))
		glow_mat.emission = lit_color
		glow_mat.emission_energy_multiplier = 1.0 + (1.8 if is_current else 1.1 if is_reachable else 0.0)

		if is_current:
			ring_mat.albedo_color = Color(1.0, 0.92, 0.45, 0.9)
			ring_mat.emission = Color(1.0, 0.86, 0.35)
			ring_mat.emission_energy_multiplier = 2.4
		elif is_reachable:
			ring_mat.albedo_color = Color(0.52, 0.83, 1.0, 0.75)
			ring_mat.emission = Color(0.45, 0.75, 1.0)
			ring_mat.emission_energy_multiplier = 1.8
		elif is_hovered:
			ring_mat.albedo_color = Color(0.75, 0.92, 1.0, 0.55)
			ring_mat.emission = Color(0.62, 0.85, 1.0)
			ring_mat.emission_energy_multiplier = 1.4
		else:
			ring_mat.albedo_color = Color(0.7, 0.9, 1.0, 0.0)
			ring_mat.emission_energy_multiplier = 0.0

		if is_current or is_reachable or is_hovered:
			label.modulate = Color(0.85, 0.93, 1.0, 1.0)
		else:
			label.modulate = Color(0.75, 0.82, 0.92, 0.38)


func _update_player_position() -> void:
	var current := _find_planet_by_name(GameManager.current_planet)
	if current and _player_marker:
		_player_marker_base_position = _planet_to_world(current) + Vector3(0.0, 2.25, 0.0)
		_player_marker.position = _player_marker_base_position


func _update_ui() -> void:
	credits_label.text = "Credits: %d" % GameManager.credits
	cargo_label.text = "Cargo: %d/%d" % [GameManager.get_cargo_used(), GameManager.cargo_capacity]
	current_planet_label.text = "@ %s" % GameManager.current_planet
	hull_label.text = "Hull: %d/%d" % [GameManager.current_hull, GameManager.max_hull]
	shield_label.text = "Shield: %d/%d" % [GameManager.current_shield, GameManager.max_shield]


func _on_planet_input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int, planet_data: Resource) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_planet_clicked(planet_data)


func _on_planet_mouse_entered(planet_data: Resource) -> void:
	_hovered_planet_name = planet_data.planet_name
	_on_planet_hovered(planet_data)
	_update_planet_states()


func _on_planet_mouse_exited(planet_data: Resource) -> void:
	if _hovered_planet_name == planet_data.planet_name:
		_hovered_planet_name = ""
		_on_planet_unhovered()
	_update_planet_states()


func _on_planet_clicked(planet_data: Resource) -> void:
	if planet_data.planet_name == GameManager.current_planet:
		selected_planet = planet_data
		travel_button.visible = false
		land_button.visible = true
		_on_planet_hovered(planet_data)
		_update_planet_states()
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
	_update_planet_states()


func _on_planet_hovered(planet_data: Resource) -> void:
	info_panel.visible = true
	planet_name_label.text = planet_data.planet_name
	var type_text: String = EconomyManager.PLANET_TYPE_NAMES.get(planet_data.planet_type, "Unknown")
	planet_type_label.text = type_text
	danger_label.text = "Danger: %d" % planet_data.danger_level

	if planet_data.danger_level >= 3:
		danger_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif planet_data.danger_level >= 2:
		danger_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		danger_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))

	var type_color: Color = UIStyles.TYPE_COLORS.get(planet_data.planet_type, Color(0.6, 0.6, 0.7))
	planet_type_label.add_theme_color_override("font_color", type_color)

	var available: Array = EconomyManager.get_available_goods(type_text)
	if available.size() > 0:
		trades_label.text = "Trades: " + ", ".join(available)
	else:
		trades_label.text = ""


func _on_planet_unhovered() -> void:
	if selected_planet:
		# Keep panel visible with selected planet info
		_on_planet_hovered(selected_planet)
	else:
		info_panel.visible = false


func _on_travel_pressed() -> void:
	if selected_planet == null:
		return
	GameManager.travel_origin = GameManager.current_planet
	GameManager.travel_destination = selected_planet.planet_name
	GameManager.change_scene("res://scenes/travel_scene.tscn")


func _style_nav_button(btn: Button, accent: Color) -> void:
	UIStyles.style_accent_button(btn, accent.darkened(0.5))
	var normal: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
	normal.bg_color.a = 0.85
	normal.border_color = accent
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.3)
	normal.shadow_size = 6
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = accent.darkened(0.35)
	hover.bg_color.a = 0.9
	hover.border_color = accent.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = accent.darkened(0.6)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	btn.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.0))


func _add_galaxy_background() -> void:
	BackgroundUtils.add_3d_quad_background(
		starfield_container,
		"res://assets/sprites/bg_galaxy_map.png",
		Vector2(320.0, 180.0),
		-80.0,
		0.35
	)


func _on_land_pressed() -> void:
	GameManager.change_scene("res://scenes/planet_screen.tscn")
