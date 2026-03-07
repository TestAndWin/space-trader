extends Control

const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

var destination_planet: String = ""
var dot_count: int = 0
var dot_timer: float = 0.0
var _flight_elapsed: float = 0.0
var _arrival_triggered: bool = false
var _warp_exit_triggered: bool = false
var _warp_exit_elapsed: float = 0.0

var _planet_start_z: float = -290.0
var _planet_target_z: float = -30.0
var _travel_duration: float = 4.6
var _warp_color: Color = Color(0.25, 0.6, 0.85)

var _rng := RandomNumberGenerator.new()
var _star_nodes: Array = []
var _star_speeds: Array = []
var _star_base_scales: Array = []
var _star_parallax: Array = []

var _dust_nodes: Array = []
var _dust_speeds: Array = []
var _dust_rotations: Array = []
var _dust_parallax: Array = []

var _planet_root: Node3D
var _planet_material: StandardMaterial3D
var _planet_atmo_material: StandardMaterial3D
var _warp_exit_wave: MeshInstance3D
var _warp_exit_wave_material: StandardMaterial3D
var _arrival_flash_overlay: ColorRect


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

const STAR_COUNT: int = 1200
const DUST_COUNT: int = 250
const STARFIELD_BOUNDS: Vector2 = Vector2(85.0, 50.0)
const STARFIELD_Z_NEAR: float = 2.0
const STARFIELD_Z_FAR: float = -350.0
const WARP_EXIT_START_PROGRESS: float = 0.84
const WARP_EXIT_DURATION: float = 0.55

@onready var viewport: SubViewport = $TravelViewport/SubViewport
@onready var world_environment: WorldEnvironment = $TravelViewport/SubViewport/TravelWorld/WorldEnvironment
@onready var travel_world: Node3D = $TravelViewport/SubViewport/TravelWorld
@onready var travel_camera: Camera3D = $TravelViewport/SubViewport/TravelWorld/TravelCamera
@onready var starfield_root: Node3D = $TravelViewport/SubViewport/TravelWorld/Starfield
@onready var planet_container: Node3D = $TravelViewport/SubViewport/TravelWorld/Planet
@onready var travel_label: Label = $HUD/BottomPanel/HBoxContainer/TravelLabel
@onready var warning_label: Label = $HUD/BottomPanel/HBoxContainer/WarningLabel


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

	viewport.transparent_bg = true
	_setup_environment(_warp_color)
	_generate_starfield(_warp_color)
	_generate_dust(_warp_color)
	_build_destination_planet(dest_type, _warp_color)
	_setup_warp_exit_effects()
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
	BackgroundUtils.add_fullscreen_background(self, "res://assets/sprites/bg_travel.png", 0.4, 0)
	_style_bottom_panel()


func _style_bottom_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.14, 0.75)
	style.border_color = Color(0.0, 0.65, 0.95, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.45, 0.9, 0.25)
	style.shadow_size = 6
	style.set_content_margin_all(8)
	$HUD/BottomPanel.add_theme_stylebox_override("panel", style)


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
	var approach_progress := _travel_curve(progress)
	_animate_starfield(delta, progress)
	_animate_dust(delta, progress)
	_animate_planet(delta, approach_progress)
	_animate_camera(progress, approach_progress)
	_animate_warp_exit(delta, progress)
	if progress >= 1.0 and not _arrival_triggered:
		_arrival_triggered = true
		_on_travel_complete()


func _sync_viewport_size() -> void:
	var target_size := Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	if viewport.size != target_size:
		viewport.size = target_size


func _setup_environment(warp_color: Color) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
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
	fill_light.light_energy = 0.5
	fill_light.rotation = Vector3(35.0, -130.0, 0.0) * (PI / 180.0)
	travel_world.add_child(fill_light)
	
	var rim_light := DirectionalLight3D.new()
	rim_light.light_color = Color(warp_color.r, warp_color.g, 1.0)
	rim_light.light_energy = 0.8
	rim_light.rotation = Vector3(15.0, 160.0, 0.0) * (PI / 180.0)
	travel_world.add_child(rim_light)

	var cockpit_light := OmniLight3D.new()
	cockpit_light.light_color = Color(0.2, 0.45, 1.0)
	cockpit_light.light_energy = 1.5
	cockpit_light.omni_range = 16.0
	cockpit_light.position = Vector3(0.0, -0.6, 2.5)
	travel_world.add_child(cockpit_light)


func _generate_starfield(warp_color: Color) -> void:
	for child in starfield_root.get_children():
		child.queue_free()
	_star_nodes.clear()
	_star_speeds.clear()
	_star_base_scales.clear()
	_star_parallax.clear()

	for i in STAR_COUNT:
		var star := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var star_size: float = _rng.randf_range(0.02, 0.12)
		var length_mult: float = _rng.randf_range(3.0, 8.0)
		quad.size = Vector2(star_size, star_size * length_mult)
		star.mesh = quad

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		
		# More diverse and vibrant star colors
		var brightness: float = _rng.randf_range(0.4, 1.0)
		var tint: float = _rng.randf_range(0.1, 0.9)
		# Mix white, warp_color, and a complementary warm color occasionally
		var base_color = warp_color if _rng.randf() > 0.3 else Color(1.0, 0.9, 0.7)
		if _rng.randf() > 0.9:
			base_color = Color(0.9, 0.4, 0.8) # rare pink/purple hues
			
		var color := Color(
			lerpf(brightness, base_color.r * brightness, tint),
			lerpf(brightness, base_color.g * brightness, tint),
			lerpf(brightness, base_color.b * brightness, tint),
			_rng.randf_range(0.3, 1.0)
		)
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = _rng.randf_range(1.0, 3.5)
		star.material_override = mat

		var depth_factor := _place_star(star, false)
		starfield_root.add_child(star)
		_star_nodes.append(star)
		_star_speeds.append(_rng.randf_range(60.0, 220.0))
		_star_base_scales.append(length_mult)
		_star_parallax.append(depth_factor * _rng.randf_range(0.85, 1.25))



func _generate_dust(warp_color: Color) -> void:
	_dust_nodes.clear()
	_dust_speeds.clear()
	_dust_rotations.clear()
	_dust_parallax.clear()

	for i in DUST_COUNT:
		var dust := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var dust_size: float = _rng.randf_range(0.5, 4.5)
		quad.size = Vector2(dust_size, dust_size)
		dust.mesh = quad

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		
		# Dust should be very faint and nebulous
		var alpha = _rng.randf_range(0.02, 0.15)
		var color := Color(warp_color.r, warp_color.g, warp_color.b, alpha)
		# Occasionally different color
		if _rng.randf() > 0.8:
			color = Color(0.8, 0.3, 0.5, alpha * 0.8)
			
		mat.albedo_color = color
		
		# Use a soft circular mask if possible, else just quad.
		# Since we don't have a texture easily loaded here, we rely on low alpha and additive blending to make it soft.
		dust.material_override = mat

		var depth_factor := _place_star(dust, false, 1.5)
		
		starfield_root.add_child(dust)
		_dust_nodes.append(dust)
		_dust_speeds.append(_rng.randf_range(15.0, 45.0))
		_dust_rotations.append(_rng.randf_range(-1.0, 1.0))
		_dust_parallax.append(depth_factor * _rng.randf_range(0.8, 1.4))

func _place_star(star: MeshInstance3D, reset_far: bool, spread: float = 1.0) -> float:
	var z: float = _rng.randf_range(STARFIELD_Z_FAR, STARFIELD_Z_NEAR - 1.0)
	if reset_far:
		z = STARFIELD_Z_FAR - _rng.randf_range(0.0, 120.0)
	star.position = Vector3(
		_rng.randf_range(-STARFIELD_BOUNDS.x, STARFIELD_BOUNDS.x) * spread,
		_rng.randf_range(-STARFIELD_BOUNDS.y, STARFIELD_BOUNDS.y) * spread,
		z
	)
	return _depth_factor_from_z(z)


func _depth_factor_from_z(z: float) -> float:
	var depth := inverse_lerp(STARFIELD_Z_FAR, STARFIELD_Z_NEAR, z)
	return lerpf(0.55, 1.85, depth)

func _animate_starfield(delta: float, progress: float) -> void:
	var progress_curve := pow(progress, 0.52)
	var speed_multiplier := lerpf(13.5, 0.9, progress_curve)
	var stretch := lerpf(7.2, 1.0, progress_curve)
	for i in _star_nodes.size():
		var star: MeshInstance3D = _star_nodes[i]
		var parallax: float = _star_parallax[i]
		star.position.z += delta * _star_speeds[i] * speed_multiplier * parallax
		
		# Twinkle effect based on z position
		if star.material_override:
			var mat: StandardMaterial3D = star.material_override
			mat.emission_energy_multiplier = 2.0 + sin(star.position.z * 0.1 + float(i)) * (1.1 + parallax * 0.4)
			
		if star.position.z > STARFIELD_Z_NEAR:
			_star_parallax[i] = _place_star(star, true) * _rng.randf_range(0.85, 1.25)
		star.rotation.z = atan2(star.position.y, star.position.x) + PI * 0.5
		star.scale = Vector3(1.0, stretch * _star_base_scales[i] * (0.42 + parallax * 0.2), 1.0)

func _animate_dust(delta: float, progress: float) -> void:
	var speed_multiplier := lerpf(9.5, 0.65, pow(progress, 0.55))
	for i in _dust_nodes.size():
		var dust: MeshInstance3D = _dust_nodes[i]
		var parallax: float = _dust_parallax[i]
		dust.position.z += delta * _dust_speeds[i] * speed_multiplier * parallax
		dust.rotation.z += delta * _dust_rotations[i] * (0.65 + parallax * 0.35)
		
		# Fade out dust as we get close to planet to not obscure it
		if dust.material_override:
			var mat: StandardMaterial3D = dust.material_override
			var a = mat.albedo_color.a
			mat.albedo_color.a = lerpf(a, a * (1.0 - progress), delta * 2.0)
			
		if dust.position.z > STARFIELD_Z_NEAR:
			_dust_parallax[i] = _place_star(dust, true, 1.5) * _rng.randf_range(0.8, 1.4)


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


func _animate_planet(delta: float, progress: float) -> void:
	if not _planet_root:
		return
	_planet_root.position.z = lerpf(_planet_start_z, _planet_target_z, progress)
	_planet_root.position.y = lerpf(-1.9, -0.55, progress)
	_planet_root.rotation.y += delta * 0.08
	_planet_root.rotation.x = sin(_flight_elapsed * 0.35) * 0.04
	var planet_scale := lerpf(0.42, 1.55, progress)
	_planet_root.scale = Vector3.ONE * planet_scale
	if _planet_material:
		_planet_material.emission_energy_multiplier = lerpf(0.4, 1.2, progress)
	if _planet_atmo_material:
		_planet_atmo_material.albedo_color = Color(_warp_color.r, _warp_color.g, _warp_color.b, lerpf(0.24, 0.42, progress))


func _animate_camera(progress: float, approach_progress: float) -> void:
	var camera_curve := _camera_curve(progress)
	var arrival_settle := _smoothstep(clampf((progress - 0.74) / 0.26, 0.0, 1.0))
	var shake_intensity := lerpf(1.0, 0.0, camera_curve) * (1.0 - arrival_settle * 0.85)
	travel_camera.fov = lerpf(104.0, 72.0, camera_curve)

	var shake_offset = Vector3(
		_rng.randf_range(-1.0, 1.0) * 0.04 * shake_intensity,
		_rng.randf_range(-1.0, 1.0) * 0.04 * shake_intensity,
		0.0
	)
	
	var orbital_x := sin(_flight_elapsed * 0.8) * 0.35 * shake_intensity
	var orbital_y := cos(_flight_elapsed * 1.1) * 0.28 * shake_intensity
	var cam_z := lerpf(0.35, 2.35, pow(approach_progress, 1.75))
	
	travel_camera.position = Vector3(
		orbital_x,
		-0.2 + orbital_y,
		cam_z
	) + shake_offset
	
	var look_target := Vector3(0.0, 0.0, -60.0)
	if _planet_root:
		look_target = _planet_root.global_position + Vector3(0.0, 0.8, -6.0)
	travel_camera.look_at(look_target, Vector3.UP)


func _animate_warp_exit(delta: float, progress: float) -> void:
	if not _warp_exit_triggered and progress >= WARP_EXIT_START_PROGRESS:
		_warp_exit_triggered = true
		_warp_exit_elapsed = 0.0

	if not _warp_exit_triggered:
		return

	_warp_exit_elapsed += delta
	var t := clampf(_warp_exit_elapsed / WARP_EXIT_DURATION, 0.0, 1.0)
	var expanded := _ease_out_cubic(t)

	if _warp_exit_wave and _warp_exit_wave_material:
		_warp_exit_wave.visible = t < 1.0
		var forward := -travel_camera.global_basis.z
		_warp_exit_wave.global_position = travel_camera.global_position + forward * 8.0
		_warp_exit_wave.scale = Vector3.ONE * lerpf(0.7, 18.0, expanded)
		_warp_exit_wave_material.albedo_color = Color(_warp_color.r, _warp_color.g, _warp_color.b, (1.0 - t) * 0.28)
		_warp_exit_wave_material.emission_energy_multiplier = lerpf(3.6, 0.45, t)

	if _arrival_flash_overlay:
		var rise := _smoothstep(clampf(t / 0.17, 0.0, 1.0))
		var fall := _smoothstep(clampf((t - 0.17) / 0.5, 0.0, 1.0))
		var alpha := 0.28 * rise * (1.0 - fall)
		_arrival_flash_overlay.color = Color(
			_warp_color.r * 0.5 + 0.5,
			_warp_color.g * 0.5 + 0.5,
			_warp_color.b * 0.5 + 0.5,
			alpha
		)


func _setup_warp_exit_effects() -> void:
	_warp_exit_wave = MeshInstance3D.new()
	var wave_mesh := SphereMesh.new()
	wave_mesh.radius = 1.0
	wave_mesh.height = 2.0
	wave_mesh.radial_segments = 48
	wave_mesh.rings = 24
	_warp_exit_wave.mesh = wave_mesh

	_warp_exit_wave_material = StandardMaterial3D.new()
	_warp_exit_wave_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warp_exit_wave_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_warp_exit_wave_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_warp_exit_wave_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_warp_exit_wave_material.albedo_color = Color(_warp_color.r, _warp_color.g, _warp_color.b, 0.0)
	_warp_exit_wave_material.emission_enabled = true
	_warp_exit_wave_material.emission = Color(_warp_color.r, _warp_color.g, _warp_color.b)
	_warp_exit_wave_material.emission_energy_multiplier = 0.0
	_warp_exit_wave.material_override = _warp_exit_wave_material
	_warp_exit_wave.visible = false
	travel_world.add_child(_warp_exit_wave)

	_arrival_flash_overlay = ColorRect.new()
	_arrival_flash_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	_arrival_flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrival_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrival_flash_overlay)


func _smoothstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _travel_curve(progress: float) -> float:
	var smooth := _smoothstep(progress)
	return clampf(lerpf(progress, smooth, 0.65), 0.0, 1.0)


func _camera_curve(progress: float) -> float:
	var base := _travel_curve(progress)
	var settle := _smoothstep(clampf((progress - 0.42) / 0.58, 0.0, 1.0))
	return clampf(lerpf(base, settle, 0.42), 0.0, 1.0)


func _ease_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	var inv := 1.0 - t
	return 1.0 - inv * inv * inv


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
