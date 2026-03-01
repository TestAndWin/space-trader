extends Control

const CockpitFrame := preload("res://scripts/components/cockpit_frame.gd")
const HULL_SHADER := preload("res://shaders/ship_hull.gdshader")
const ENGINE_SHADER := preload("res://shaders/engine_glow.gdshader")

var destination_planet: String = ""
var dot_count: int = 0
var dot_timer: float = 0.0
var _flight_elapsed: float = 0.0
var _arrival_triggered: bool = false

var _ship_base_position: Vector3 = Vector3(0.0, -1.0, -2.8)
var _planet_start_z: float = -290.0
var _planet_target_z: float = -30.0
var _travel_duration: float = 4.6
var _warp_color: Color = Color(0.25, 0.6, 0.85)

var _rng := RandomNumberGenerator.new()
var _star_nodes: Array = []
var _star_speeds: Array = []
var _planet_root: Node3D
var _planet_material: StandardMaterial3D
var _planet_atmo_material: StandardMaterial3D

# Planet type accent colors matching planet_background.gd atmosphere palette
const PLANET_WARP_COLORS: Dictionary = {
	0: Color(0.5, 0.55, 0.7),    # INDUSTRIAL  - steel blue
	1: Color(0.3, 0.7, 0.4),     # AGRICULTURAL - green
	2: Color(0.7, 0.5, 0.25),    # MINING       - orange/brown
	3: Color(0.25, 0.6, 0.85),   # TECH         - cyan
	4: Color(0.6, 0.15, 0.15),   # OUTLAW       - dark red
}

const PLANET_SURFACE_COLORS: Dictionary = {
	0: Color(0.42, 0.47, 0.58),  # INDUSTRIAL
	1: Color(0.28, 0.63, 0.38),  # AGRICULTURAL
	2: Color(0.62, 0.42, 0.22),  # MINING
	3: Color(0.24, 0.53, 0.72),  # TECH
	4: Color(0.45, 0.18, 0.16),  # OUTLAW
}

const STAR_COUNT: int = 360
const STARFIELD_BOUNDS: Vector2 = Vector2(72.0, 42.0)
const STARFIELD_Z_NEAR: float = 1.5
const STARFIELD_Z_FAR: float = -320.0

# Normalized 3D polygon coords (Y-up, ×2 scale, tip at +Y, engines at −Y).
const HULL_POLYGONS: Array = [
	# 0: Scout
	[Vector2(0.0, 0.84), Vector2(0.24, 0.50), Vector2(0.64, -0.20),
	 Vector2(0.36, -0.30), Vector2(0.20, -0.70), Vector2(-0.20, -0.70),
	 Vector2(-0.36, -0.30), Vector2(-0.64, -0.20), Vector2(-0.24, 0.50)],
	# 1: Freighter
	[Vector2(0.0, 0.64), Vector2(0.40, 0.50), Vector2(0.56, 0.10),
	 Vector2(0.56, -0.40), Vector2(0.30, -0.70), Vector2(-0.30, -0.70),
	 Vector2(-0.56, -0.40), Vector2(-0.56, 0.10), Vector2(-0.40, 0.50)],
	# 2: Warship
	[Vector2(0.0, 0.88), Vector2(0.16, 0.60), Vector2(0.70, 0.0),
	 Vector2(0.60, -0.30), Vector2(0.30, -0.40), Vector2(0.24, -0.76),
	 Vector2(-0.24, -0.76), Vector2(-0.30, -0.40), Vector2(-0.60, -0.30),
	 Vector2(-0.70, 0.0), Vector2(-0.16, 0.60)],
	# 3: Smuggler
	[Vector2(0.0, 0.90), Vector2(0.16, 0.60), Vector2(0.36, 0.0),
	 Vector2(0.44, -0.30), Vector2(0.24, -0.70), Vector2(-0.24, -0.70),
	 Vector2(-0.44, -0.30), Vector2(-0.36, 0.0), Vector2(-0.16, 0.60)],
	# 4: Explorer
	[Vector2(0.0, 0.76), Vector2(0.30, 0.56), Vector2(0.50, 0.20),
	 Vector2(0.50, -0.20), Vector2(0.36, -0.50), Vector2(0.20, -0.70),
	 Vector2(-0.20, -0.70), Vector2(-0.36, -0.50), Vector2(-0.50, -0.20),
	 Vector2(-0.50, 0.20), Vector2(-0.30, 0.56)],
]

const ENGINE_POSITIONS: Array = [
	[Vector2(-0.12, -0.68), Vector2(0.12, -0.68)],           # Scout
	[Vector2(-0.20, -0.68), Vector2(0.20, -0.68)],           # Freighter
	[Vector2(0.0, -0.74), Vector2(-0.24, -0.64), Vector2(0.24, -0.64)],  # Warship
	[Vector2(-0.12, -0.68), Vector2(0.12, -0.68)],           # Smuggler
	[Vector2(-0.16, -0.68), Vector2(0.16, -0.68)],           # Explorer
]

@onready var viewport: SubViewport = $TravelViewport/SubViewport
@onready var world_environment: WorldEnvironment = $TravelViewport/SubViewport/TravelWorld/WorldEnvironment
@onready var travel_world: Node3D = $TravelViewport/SubViewport/TravelWorld
@onready var travel_camera: Camera3D = $TravelViewport/SubViewport/TravelWorld/TravelCamera
@onready var starfield_root: Node3D = $TravelViewport/SubViewport/TravelWorld/Starfield
@onready var ship_root: Node3D = $TravelViewport/SubViewport/TravelWorld/Ship
@onready var planet_container: Node3D = $TravelViewport/SubViewport/TravelWorld/Planet
@onready var travel_label: Label = $HUD/TopPanel/VBoxContainer/TravelLabel
@onready var warning_label: Label = $HUD/TopPanel/VBoxContainer/WarningLabel


func _ready() -> void:
	_rng.seed = randi()
	destination_planet = GameManager.travel_destination if GameManager.travel_destination != "" else "Unknown"
	GameManager.total_flights += 1
	if EncounterManager.is_carrying_contraband():
		warning_label.text = "CONTRABAND ABOARD - Increased encounter risk!"
	else:
		warning_label.text = ""
	travel_label.text = "Traveling to " + destination_planet + "..."

	var dest_type: int = _get_destination_type()
	_warp_color = PLANET_WARP_COLORS.get(dest_type, PLANET_WARP_COLORS[3])

	_setup_environment(_warp_color)
	_generate_starfield(_warp_color)
	_build_ship_3d(_warp_color)
	_build_destination_planet(dest_type, _warp_color)
	_sync_viewport_size()
	travel_camera.look_at(Vector3(0.0, -0.4, -80.0), Vector3.UP)

	var flash := ColorRect.new()
	flash.color = Color(
		_warp_color.r * 0.5 + 0.5,
		_warp_color.g * 0.5 + 0.5,
		_warp_color.b * 0.5 + 0.5,
		0.75
	)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	flash_tween.tween_callback(flash.queue_free)
	CockpitFrame.add_to(self)


func _get_destination_type() -> int:
	var planet := EconomyManager.get_planet_data(destination_planet)
	if planet:
		return planet.planet_type
	return 3  # Default: Tech (cyan)


func _process(delta: float) -> void:
	_sync_viewport_size()
	dot_timer += delta
	if dot_timer >= 0.35:
		dot_timer = 0.0
		dot_count = (dot_count + 1) % 4
		var dots := ".".repeat(dot_count)
		travel_label.text = "Traveling to " + destination_planet + dots
	_flight_elapsed += delta
	var progress := clampf(_flight_elapsed / _travel_duration, 0.0, 1.0)
	_animate_starfield(delta, progress)
	_animate_ship(delta, progress)
	_animate_planet(delta, progress)
	_animate_camera(progress)
	if progress >= 1.0 and not _arrival_triggered:
		_arrival_triggered = true
		_on_travel_complete()


func _sync_viewport_size() -> void:
	var target_size := Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	if viewport.size != target_size:
		viewport.size = target_size


func _setup_environment(warp_color: Color) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(
		0.01 + warp_color.r * 0.03,
		0.01 + warp_color.g * 0.03,
		0.02 + warp_color.b * 0.05
	)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.16, 0.26).lerp(Color(warp_color.r * 0.25, warp_color.g * 0.25, warp_color.b * 0.25), 0.35)
	env.ambient_light_energy = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 0.82
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.003
	world_environment.environment = env

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.95, 0.88)
	key_light.light_energy = 1.2
	key_light.rotation = Vector3(-22.0, 20.0, 0.0) * (PI / 180.0)
	travel_world.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.light_color = Color(warp_color.r * 0.75 + 0.2, warp_color.g * 0.75 + 0.2, warp_color.b * 0.9 + 0.1)
	fill_light.light_energy = 0.4
	fill_light.rotation = Vector3(35.0, -130.0, 0.0) * (PI / 180.0)
	travel_world.add_child(fill_light)

	var cockpit_light := OmniLight3D.new()
	cockpit_light.light_color = Color(0.2, 0.35, 0.95)
	cockpit_light.light_energy = 1.0
	cockpit_light.omni_range = 16.0
	cockpit_light.position = Vector3(0.0, -0.8, 2.0)
	travel_world.add_child(cockpit_light)


func _generate_starfield(warp_color: Color) -> void:
	for child in starfield_root.get_children():
		child.queue_free()
	_star_nodes.clear()
	_star_speeds.clear()

	for i in STAR_COUNT:
		var star := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var star_size: float = _rng.randf_range(0.05, 0.18)
		quad.size = Vector2(star_size, star_size * _rng.randf_range(2.2, 4.8))
		star.mesh = quad

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var brightness: float = _rng.randf_range(0.35, 1.0)
		var tint: float = _rng.randf_range(0.2, 0.75)
		var color := Color(
			lerpf(brightness, warp_color.r * brightness, tint),
			lerpf(brightness, warp_color.g * brightness, tint),
			lerpf(brightness, warp_color.b * brightness, tint),
			_rng.randf_range(0.18, 0.95)
		)
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = _rng.randf_range(0.7, 2.0)
		star.material_override = mat

		_place_star(star, false)
		starfield_root.add_child(star)
		_star_nodes.append(star)
		_star_speeds.append(_rng.randf_range(40.0, 120.0))


func _place_star(star: MeshInstance3D, reset_far: bool) -> void:
	var z: float = _rng.randf_range(STARFIELD_Z_FAR, STARFIELD_Z_NEAR - 1.0)
	if reset_far:
		z = STARFIELD_Z_FAR - _rng.randf_range(0.0, 75.0)
	star.position = Vector3(
		_rng.randf_range(-STARFIELD_BOUNDS.x, STARFIELD_BOUNDS.x),
		_rng.randf_range(-STARFIELD_BOUNDS.y, STARFIELD_BOUNDS.y),
		z
	)


func _animate_starfield(delta: float, progress: float) -> void:
	var speed_multiplier := lerpf(1.2, 6.8, progress * progress)
	var stretch := lerpf(1.0, 3.8, progress)
	for i in _star_nodes.size():
		var star: MeshInstance3D = _star_nodes[i]
		star.position.z += delta * _star_speeds[i] * speed_multiplier
		if star.position.z > STARFIELD_Z_NEAR:
			_place_star(star, true)
		star.rotation.z = atan2(star.position.y, star.position.x) + PI * 0.5
		star.scale = Vector3(1.0, stretch, 1.0)


func _build_ship_3d(warp_color: Color) -> void:
	for child in ship_root.get_children():
		child.queue_free()

	var ship_data: Resource = GameManager.get_ship_data()
	var ship_shape: int = 0
	var hull_color: Color = Color(0.3, 0.85, 0.3)
	if ship_data:
		ship_shape = ship_data.hull_shape
		hull_color = ship_data.hull_color_primary

	ship_root.position = _ship_base_position
	ship_root.rotation = Vector3(-PI * 0.5, 0.0, 0.0)

	var hull_mat := ShaderMaterial.new()
	hull_mat.shader = HULL_SHADER
	hull_mat.set_shader_parameter("hull_color", hull_color)
	hull_mat.set_shader_parameter("emissive_strength", 0.08)
	hull_mat.set_shader_parameter("emissive_color", Color(1.0, 0.45, 0.2))

	var hull := MeshInstance3D.new()
	hull.mesh = _build_hull_mesh(PackedVector2Array(HULL_POLYGONS[clampi(ship_shape, 0, HULL_POLYGONS.size() - 1)]))
	hull.material_override = hull_mat
	hull.scale = Vector3.ONE * 2.0
	ship_root.add_child(hull)

	var canopy := MeshInstance3D.new()
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 0.18
	canopy_mesh.height = 0.36
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0.0, 0.78, 0.18)
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	canopy_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	canopy_mat.albedo_color = Color(0.5, 0.9, 1.0, 0.45)
	canopy_mat.emission_enabled = true
	canopy_mat.emission = Color(0.3, 0.8, 1.0, 1.0)
	canopy_mat.emission_energy_multiplier = 0.45
	canopy.material_override = canopy_mat
	ship_root.add_child(canopy)

	var engine_positions: Array = ENGINE_POSITIONS[clampi(ship_shape, 0, ENGINE_POSITIONS.size() - 1)]
	var base_engine_mat := ShaderMaterial.new()
	base_engine_mat.shader = ENGINE_SHADER
	base_engine_mat.set_shader_parameter("glow_color", Color(warp_color.r * 0.4 + 0.6, warp_color.g * 0.4 + 0.5, 1.0, 0.95))
	base_engine_mat.set_shader_parameter("pulse_speed", 4.0)

	for i in engine_positions.size():
		var p: Vector2 = engine_positions[i] * 2.0
		var glow := MeshInstance3D.new()
		var glow_mesh := QuadMesh.new()
		glow_mesh.size = Vector2(0.38, 0.38)
		glow.mesh = glow_mesh
		var glow_mat: ShaderMaterial = base_engine_mat.duplicate()
		glow_mat.set_shader_parameter("pulse_phase", float(i) * 1.3)
		glow.material_override = glow_mat
		glow.position = Vector3(p.x, p.y, 0.18)
		ship_root.add_child(glow)

		ship_root.add_child(_create_engine_particles(Vector3(p.x, p.y, 0.18), warp_color))


func _create_engine_particles(local_position: Vector3, warp_color: Color) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 72
	particles.lifetime = 0.28
	particles.one_shot = false
	particles.preprocess = 0.28
	particles.speed_scale = 1.0
	particles.local_coords = true
	particles.emitting = true
	particles.position = local_position
	particles.visibility_aabb = AABB(Vector3(-2.0, -3.5, -2.0), Vector3(4.0, 7.0, 7.0))

	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.30)
	particles.draw_pass_1 = quad

	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.albedo_color = Color(warp_color.r * 0.35 + 0.6, warp_color.g * 0.35 + 0.6, 1.0, 0.45)
	particles.material_override = draw_mat

	var process_mat := ParticleProcessMaterial.new()
	process_mat.direction = Vector3(0.0, -1.0, 0.0)
	process_mat.spread = 10.0
	process_mat.gravity = Vector3.ZERO
	process_mat.initial_velocity_min = 8.0
	process_mat.initial_velocity_max = 12.0
	process_mat.linear_accel_min = 2.0
	process_mat.linear_accel_max = 4.0
	process_mat.scale_min = 0.15
	process_mat.scale_max = 0.42
	process_mat.angle_min = -16.0
	process_mat.angle_max = 16.0
	process_mat.damping_min = 0.0
	process_mat.damping_max = 0.6
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.95, 0.8, 1.0))
	gradient.add_point(0.32, Color(0.55, 0.78, 1.0, 0.85))
	gradient.add_point(1.0, Color(0.2, 0.45, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process_mat.color_ramp = ramp
	particles.process_material = process_mat
	return particles


func _build_destination_planet(dest_type: int, warp_color: Color) -> void:
	for child in planet_container.get_children():
		child.queue_free()

	_planet_root = Node3D.new()
	_planet_root.position = Vector3(0.0, -1.9, _planet_start_z)
	planet_container.add_child(_planet_root)

	var planet_data := EconomyManager.get_planet_data(destination_planet)
	var danger_level: int = 1
	if planet_data:
		danger_level = planet_data.danger_level
	_planet_target_z = -32.0 - float(danger_level) * 2.8
	_travel_duration = 4.2 + float(maxi(0, danger_level - 1)) * 0.15

	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 11.0
	sphere.height = 22.0
	sphere.radial_segments = 72
	sphere.rings = 36
	body.mesh = sphere

	_planet_material = StandardMaterial3D.new()
	_planet_material.albedo_color = PLANET_SURFACE_COLORS.get(dest_type, PLANET_SURFACE_COLORS[3])
	_planet_material.roughness = 0.75
	_planet_material.metallic = 0.08
	_planet_material.emission_enabled = true
	_planet_material.emission = Color(warp_color.r * 0.15, warp_color.g * 0.15, warp_color.b * 0.18)
	_planet_material.emission_energy_multiplier = 0.4
	body.material_override = _planet_material
	_planet_root.add_child(body)

	var atmo := MeshInstance3D.new()
	var atmo_mesh := SphereMesh.new()
	atmo_mesh.radius = 11.5
	atmo_mesh.height = 23.0
	atmo_mesh.radial_segments = 64
	atmo_mesh.rings = 28
	atmo.mesh = atmo_mesh
	_planet_atmo_material = StandardMaterial3D.new()
	_planet_atmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_planet_atmo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_planet_atmo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_planet_atmo_material.albedo_color = Color(warp_color.r, warp_color.g, warp_color.b, 0.24)
	_planet_atmo_material.emission_enabled = true
	_planet_atmo_material.emission = Color(warp_color.r, warp_color.g, warp_color.b, 1.0)
	_planet_atmo_material.emission_energy_multiplier = 0.65
	atmo.material_override = _planet_atmo_material
	_planet_root.add_child(atmo)

	if dest_type == 1 or dest_type == 3:
		var ring := MeshInstance3D.new()
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 20.0
		ring_mesh.bottom_radius = 20.0
		ring_mesh.height = 0.24
		ring_mesh.radial_segments = 64
		ring.mesh = ring_mesh
		var ring_mat := StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color = Color(warp_color.r * 0.8 + 0.2, warp_color.g * 0.8 + 0.2, warp_color.b * 0.8 + 0.2, 0.18)
		ring.material_override = ring_mat
		ring.rotation_degrees = Vector3(70.0, 0.0, 0.0)
		_planet_root.add_child(ring)


func _animate_ship(delta: float, progress: float) -> void:
	var bob := sin(_flight_elapsed * 2.9) * 0.05
	var sway := sin(_flight_elapsed * 0.85) * 0.08
	ship_root.position = _ship_base_position + Vector3(sway, bob, -progress * 0.45)
	ship_root.rotation.z = sin(_flight_elapsed * 1.2) * 0.03
	ship_root.rotation.y = sin(_flight_elapsed * 0.7) * 0.025
	var particle_speed := lerpf(1.0, 2.6, progress)
	for child in ship_root.get_children():
		if child is GPUParticles3D:
			child.speed_scale = particle_speed


func _animate_planet(delta: float, progress: float) -> void:
	if not _planet_root:
		return
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	_planet_root.position.z = lerpf(_planet_start_z, _planet_target_z, eased)
	_planet_root.position.y = lerpf(-1.9, -0.55, eased)
	_planet_root.rotation.y += delta * 0.08
	_planet_root.rotation.x = sin(_flight_elapsed * 0.35) * 0.04
	var planet_scale := lerpf(0.42, 1.55, eased)
	_planet_root.scale = Vector3.ONE * planet_scale
	if _planet_material:
		_planet_material.emission_energy_multiplier = lerpf(0.4, 1.2, eased)
	if _planet_atmo_material:
		_planet_atmo_material.albedo_color = Color(_warp_color.r, _warp_color.g, _warp_color.b, lerpf(0.24, 0.42, eased))


func _animate_camera(progress: float) -> void:
	var shake := 1.0 - progress * 0.45
	travel_camera.position = Vector3(
		sin(_flight_elapsed * 1.9) * 0.05 * shake,
		-0.2 + sin(_flight_elapsed * 3.8) * 0.015 * shake,
		lerpf(1.2, 0.7, progress)
	)
	travel_camera.look_at(Vector3(0.0, -0.4, -80.0), Vector3.UP)


# Builds an extruded low-poly hull mesh from a 2D polygon (CW winding, Y-up).
func _build_hull_mesh(poly: PackedVector2Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = poly.size()
	const depth: float = 0.125

	var cx: float = 0.0
	var cy: float = 0.0
	for v: Vector2 in poly:
		cx += v.x
		cy += v.y
	cx /= float(n)
	cy /= float(n)

	for i in n:
		var v0: Vector2 = poly[i]
		var v1: Vector2 = poly[(i + 1) % n]
		st.set_normal(Vector3(0.0, 0.0, 1.0))
		st.set_uv(Vector2(cx * 0.5 + 0.5, -cy * 0.5 + 0.5))
		st.add_vertex(Vector3(cx, cy, depth))
		st.set_normal(Vector3(0.0, 0.0, 1.0))
		st.set_uv(Vector2(v1.x * 0.5 + 0.5, -v1.y * 0.5 + 0.5))
		st.add_vertex(Vector3(v1.x, v1.y, depth))
		st.set_normal(Vector3(0.0, 0.0, 1.0))
		st.set_uv(Vector2(v0.x * 0.5 + 0.5, -v0.y * 0.5 + 0.5))
		st.add_vertex(Vector3(v0.x, v0.y, depth))

	for i in n:
		var v0: Vector2 = poly[i]
		var v1: Vector2 = poly[(i + 1) % n]
		st.set_normal(Vector3(0.0, 0.0, -1.0))
		st.set_uv(Vector2(cx * 0.5 + 0.5, -cy * 0.5 + 0.5))
		st.add_vertex(Vector3(cx, cy, -depth))
		st.set_normal(Vector3(0.0, 0.0, -1.0))
		st.set_uv(Vector2(v0.x * 0.5 + 0.5, -v0.y * 0.5 + 0.5))
		st.add_vertex(Vector3(v0.x, v0.y, -depth))
		st.set_normal(Vector3(0.0, 0.0, -1.0))
		st.set_uv(Vector2(v1.x * 0.5 + 0.5, -v1.y * 0.5 + 0.5))
		st.add_vertex(Vector3(v1.x, v1.y, -depth))

	for i in n:
		var v0: Vector2 = poly[i]
		var v1: Vector2 = poly[(i + 1) % n]
		var d: Vector2 = v1 - v0
		var normal := Vector3(-d.y, d.x, 0.0).normalized()
		var v0f := Vector3(v0.x, v0.y, depth)
		var v1f := Vector3(v1.x, v1.y, depth)
		var v0b := Vector3(v0.x, v0.y, -depth)
		var v1b := Vector3(v1.x, v1.y, -depth)
		st.set_normal(normal)
		st.add_vertex(v0f)
		st.set_normal(normal)
		st.add_vertex(v1f)
		st.set_normal(normal)
		st.add_vertex(v1b)
		st.set_normal(normal)
		st.add_vertex(v0f)
		st.set_normal(normal)
		st.add_vertex(v1b)
		st.set_normal(normal)
		st.add_vertex(v0b)

	return st.commit()


func _on_travel_complete() -> void:
	set_process(false)
	var danger_level: int = 1
	var planet_data := EconomyManager.get_planet_data(destination_planet)
	if planet_data:
		danger_level = planet_data.danger_level
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
