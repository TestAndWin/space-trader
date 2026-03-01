extends Control

## 3D combat backdrop for card_battle.tscn.
## Keeps all gameplay/UI in 2D while rendering animated 3D ships, starfield,
## laser fire, shield flashes and explosion bursts behind the card UI.

const HULL_SHADER := preload("res://shaders/ship_hull.gdshader")
const ENGINE_SHADER := preload("res://shaders/engine_glow.gdshader")

const STAR_COUNT: int = 260
const STAR_NEAR_Z: float = -11.0
const STAR_FAR_Z: float = -92.0
const STAR_BOUNDS_X: float = 26.0
const STAR_BOUNDS_Y: float = 15.0

const PLAYER_HULL_POLYGONS: Array = [
	[Vector2(0.0, 0.84), Vector2(0.24, 0.50), Vector2(0.64, -0.20),
	 Vector2(0.36, -0.30), Vector2(0.20, -0.70), Vector2(-0.20, -0.70),
	 Vector2(-0.36, -0.30), Vector2(-0.64, -0.20), Vector2(-0.24, 0.50)],
	[Vector2(0.0, 0.64), Vector2(0.40, 0.50), Vector2(0.56, 0.10),
	 Vector2(0.56, -0.40), Vector2(0.30, -0.70), Vector2(-0.30, -0.70),
	 Vector2(-0.56, -0.40), Vector2(-0.56, 0.10), Vector2(-0.40, 0.50)],
	[Vector2(0.0, 0.88), Vector2(0.16, 0.60), Vector2(0.70, 0.0),
	 Vector2(0.60, -0.30), Vector2(0.30, -0.40), Vector2(0.24, -0.76),
	 Vector2(-0.24, -0.76), Vector2(-0.30, -0.40), Vector2(-0.60, -0.30),
	 Vector2(-0.70, 0.0), Vector2(-0.16, 0.60)],
	[Vector2(0.0, 0.90), Vector2(0.16, 0.60), Vector2(0.36, 0.0),
	 Vector2(0.44, -0.30), Vector2(0.24, -0.70), Vector2(-0.24, -0.70),
	 Vector2(-0.44, -0.30), Vector2(-0.36, 0.0), Vector2(-0.16, 0.60)],
	[Vector2(0.0, 0.76), Vector2(0.30, 0.56), Vector2(0.50, 0.20),
	 Vector2(0.50, -0.20), Vector2(0.36, -0.50), Vector2(0.20, -0.70),
	 Vector2(-0.20, -0.70), Vector2(-0.36, -0.50), Vector2(-0.50, -0.20),
	 Vector2(-0.50, 0.20), Vector2(-0.30, 0.56)],
]

const PLAYER_ENGINE_POSITIONS: Array = [
	[Vector2(-0.12, -0.68), Vector2(0.12, -0.68)],
	[Vector2(-0.20, -0.68), Vector2(0.20, -0.68)],
	[Vector2(0.0, -0.74), Vector2(-0.24, -0.64), Vector2(0.24, -0.64)],
	[Vector2(-0.12, -0.68), Vector2(0.12, -0.68)],
	[Vector2(-0.16, -0.68), Vector2(0.16, -0.68)],
]

const ENEMY_HULL_POLYGONS: Array = [
	[Vector2(0.0, 0.84), Vector2(0.24, 0.50), Vector2(0.60, -0.20),
	 Vector2(0.36, -0.30), Vector2(0.20, -0.70), Vector2(-0.20, -0.70),
	 Vector2(-0.36, -0.30), Vector2(-0.60, -0.20), Vector2(-0.24, 0.50)],
	[Vector2(0.0, 0.60), Vector2(0.50, 0.40), Vector2(0.60, 0.0),
	 Vector2(0.60, -0.30), Vector2(0.30, -0.60), Vector2(-0.30, -0.60),
	 Vector2(-0.60, -0.30), Vector2(-0.60, 0.0), Vector2(-0.50, 0.40)],
	[Vector2(0.0, 0.80), Vector2(0.20, 0.50), Vector2(0.70, 0.10),
	 Vector2(0.50, -0.20), Vector2(0.24, -0.70), Vector2(-0.24, -0.70),
	 Vector2(-0.50, -0.20), Vector2(-0.70, 0.10), Vector2(-0.20, 0.50)],
	[Vector2(0.0, 0.70), Vector2(0.40, 0.56), Vector2(0.70, 0.10),
	 Vector2(0.64, -0.30), Vector2(0.36, -0.70), Vector2(-0.36, -0.70),
	 Vector2(-0.64, -0.30), Vector2(-0.70, 0.10), Vector2(-0.40, 0.56)],
	[Vector2(0.0, 0.76), Vector2(0.66, 0.38), Vector2(0.66, -0.38),
	 Vector2(0.0, -0.76), Vector2(-0.66, -0.38), Vector2(-0.66, 0.38)],
	[Vector2(0.10, 0.70), Vector2(0.50, 0.30), Vector2(0.60, -0.10),
	 Vector2(0.30, -0.64), Vector2(-0.20, -0.70), Vector2(-0.60, -0.20),
	 Vector2(-0.50, 0.30), Vector2(-0.16, 0.60)],
	[Vector2(0.0, 0.88), Vector2(0.16, 0.60), Vector2(0.40, -0.10),
	 Vector2(0.30, -0.30), Vector2(0.16, -0.76), Vector2(-0.16, -0.76),
	 Vector2(-0.30, -0.30), Vector2(-0.40, -0.10), Vector2(-0.16, 0.60)],
]

const ENEMY_ENGINE_POSITIONS: Array = [
	[Vector2(-0.12, -0.68), Vector2(0.12, -0.68)],
	[Vector2(-0.20, -0.58), Vector2(0.20, -0.58)],
	[Vector2(-0.14, -0.68), Vector2(0.14, -0.68)],
	[Vector2(0.0, -0.68), Vector2(-0.24, -0.60), Vector2(0.24, -0.60)],
	[Vector2(-0.20, -0.60), Vector2(0.20, -0.60)],
	[Vector2(-0.12, -0.60), Vector2(0.12, -0.60)],
	[Vector2(-0.10, -0.74), Vector2(0.10, -0.74)],
]

var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _world_root: Node3D
var _world_environment: WorldEnvironment
var _camera: Camera3D
var _star_root: Node3D
var _effects_root: Node3D

var _player_ship_root: Node3D
var _enemy_ship_root: Node3D
var _player_hull_mat: ShaderMaterial
var _enemy_hull_mat: ShaderMaterial
var _player_shield: MeshInstance3D
var _enemy_shield: MeshInstance3D
var _player_shield_mat: StandardMaterial3D
var _enemy_shield_mat: StandardMaterial3D

var _player_base_position: Vector3 = Vector3(-5.5, -2.1, -11.0)
var _enemy_base_position: Vector3 = Vector3(5.7, 2.0, -14.0)
var _player_base_rotation: Vector3 = Vector3(0.18, -0.15, 0.60)
var _enemy_base_rotation: Vector3 = Vector3(-0.12, 0.14, PI + 0.62)

var _player_hit_offset: Vector3 = Vector3.ZERO
var _enemy_hit_offset: Vector3 = Vector3.ZERO

var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _stars: Array = []
var _star_speeds: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 18473
	_build_viewport()
	_setup_world()
	_generate_starfield()
	_spawn_nebulae()
	_build_ships()
	_update_viewport_size()


func _process(delta: float) -> void:
	_time += delta
	_update_viewport_size()
	_animate_starfield(delta)
	_animate_ships(delta)


func play_player_attack_effect(raw_damage: int, shield_absorb: int, hull_damage: int) -> void:
	if raw_damage <= 0 and shield_absorb <= 0 and hull_damage <= 0:
		return
	_fire_laser(_player_muzzle_position(), _enemy_impact_position(), Color(0.35, 0.85, 1.0), true)
	if shield_absorb > 0:
		_flash_shield(_enemy_shield, _enemy_shield_mat, Color(1.0, 0.45, 0.35))
	if hull_damage > 0:
		_pulse_ship_hit(false)
		_spawn_explosion(
			_enemy_impact_position(),
			Color(1.0, 0.42, 0.22),
			0.95 + minf(float(hull_damage) * 0.05, 0.6)
		)


func play_enemy_attack_effect(shield_absorb: int, hull_damage: int) -> void:
	if shield_absorb <= 0 and hull_damage <= 0:
		return
	_fire_laser(_enemy_muzzle_position(), _player_impact_position(), Color(1.0, 0.35, 0.28), false)
	if shield_absorb > 0:
		_flash_shield(_player_shield, _player_shield_mat, Color(0.35, 0.7, 1.0))
	if hull_damage > 0:
		_pulse_ship_hit(true)
		_spawn_explosion(
			_player_impact_position(),
			Color(1.0, 0.42, 0.2),
			0.9 + minf(float(hull_damage) * 0.05, 0.6)
		)


func play_player_shield_charge_effect(_amount: int) -> void:
	_flash_shield(_player_shield, _player_shield_mat, Color(0.35, 0.7, 1.0))


func play_enemy_shield_charge_effect(_amount: int) -> void:
	_flash_shield(_enemy_shield, _enemy_shield_mat, Color(1.0, 0.45, 0.35))


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = SubViewport.MSAA_2X
	_viewport.size = Vector2i(1280, 720)
	_viewport_container.add_child(_viewport)


func _setup_world() -> void:
	_world_root = Node3D.new()
	_viewport.add_child(_world_root)

	_world_environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.18, 0.28)
	env.ambient_light_energy = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.82
	env.glow_strength = 0.78
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0032
	_world_environment.environment = env
	_world_root.add_child(_world_environment)

	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 0.0, 12.0)
	_camera.fov = 56.0
	_camera.near = 0.05
	_camera.far = 220.0
	_camera.current = true
	_world_root.add_child(_camera)
	_camera.look_at(Vector3(0.0, 0.0, -20.0), Vector3.UP)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.95, 0.85)
	key_light.light_energy = 1.05
	key_light.rotation = Vector3(-24.0, 18.0, 0.0) * (PI / 180.0)
	_world_root.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.light_color = Color(0.35, 0.62, 1.0)
	rim_light.light_energy = 0.45
	rim_light.rotation = Vector3(18.0, -146.0, 0.0) * (PI / 180.0)
	_world_root.add_child(rim_light)

	var enemy_light := OmniLight3D.new()
	enemy_light.position = Vector3(6.5, 2.3, -12.0)
	enemy_light.light_color = Color(1.0, 0.3, 0.2)
	enemy_light.light_energy = 1.0
	enemy_light.omni_range = 18.0
	_world_root.add_child(enemy_light)

	var player_light := OmniLight3D.new()
	player_light.position = Vector3(-6.0, -2.0, -10.0)
	player_light.light_color = Color(0.2, 0.58, 1.0)
	player_light.light_energy = 0.95
	player_light.omni_range = 18.0
	_world_root.add_child(player_light)

	_star_root = Node3D.new()
	_world_root.add_child(_star_root)

	_effects_root = Node3D.new()
	_world_root.add_child(_effects_root)


func _generate_starfield() -> void:
	_stars.clear()
	_star_speeds.clear()
	for i in STAR_COUNT:
		var star := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var s: float = _rng.randf_range(0.015, 0.065)
		mesh.radius = s
		mesh.height = s * 2.0
		mesh.radial_segments = 8
		mesh.rings = 4
		star.mesh = mesh

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var brightness: float = _rng.randf_range(0.25, 1.0)
		var cool_shift: float = _rng.randf_range(-0.06, 0.10)
		mat.albedo_color = Color(
			clampf(brightness - cool_shift, 0.0, 1.0),
			clampf(brightness, 0.0, 1.0),
			clampf(brightness + cool_shift * 1.2, 0.0, 1.0),
			_rng.randf_range(0.22, 0.82)
		)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = _rng.randf_range(0.55, 1.65)
		star.material_override = mat

		_reset_star(star, false)
		_star_root.add_child(star)
		_stars.append(star)
		_star_speeds.append(_rng.randf_range(10.0, 38.0))


func _spawn_nebulae() -> void:
	var colors: Array = [
		Color(0.16, 0.24, 0.68, 0.09),
		Color(0.58, 0.16, 0.20, 0.08),
		Color(0.34, 0.18, 0.50, 0.08),
	]
	for i in 9:
		var cloud := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(_rng.randf_range(10.0, 24.0), _rng.randf_range(5.0, 14.0))
		cloud.mesh = quad
		cloud.position = Vector3(
			_rng.randf_range(-16.0, 16.0),
			_rng.randf_range(-9.0, 9.0),
			_rng.randf_range(-65.0, -20.0)
		)
		cloud.rotation.z = _rng.randf_range(-PI, PI)

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var col: Color = colors[i % colors.size()]
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = Color(col.r, col.g, col.b, 1.0)
		mat.emission_energy_multiplier = 0.45
		cloud.material_override = mat

		_world_root.add_child(cloud)


func _build_ships() -> void:
	var ship_data: Resource = GameManager.get_ship_data()
	var player_shape: int = ship_data.hull_shape if ship_data else 0
	var player_color: Color = ship_data.hull_color_primary if ship_data else Color(0.3, 0.85, 0.3)

	var player_info := _create_ship(
		PLAYER_HULL_POLYGONS[clampi(player_shape, 0, PLAYER_HULL_POLYGONS.size() - 1)],
		PLAYER_ENGINE_POSITIONS[clampi(player_shape, 0, PLAYER_ENGINE_POSITIONS.size() - 1)],
		player_color,
		Color(0.25, 0.7, 1.0),
		Color(1.0, 0.45, 0.2)
	)
	_player_ship_root = player_info["root"]
	_player_hull_mat = player_info["hull_mat"]
	_player_ship_root.position = _player_base_position
	_player_ship_root.rotation = _player_base_rotation
	_world_root.add_child(_player_ship_root)

	var player_shield_info := _create_shield(1.22, Color(0.3, 0.7, 1.0))
	_player_shield = player_shield_info["node"]
	_player_shield_mat = player_shield_info["mat"]
	_player_ship_root.add_child(_player_shield)

	var enemy_type: int = _enemy_type_from_encounter()
	var enemy_info := _create_ship(
		ENEMY_HULL_POLYGONS[clampi(enemy_type, 0, ENEMY_HULL_POLYGONS.size() - 1)],
		ENEMY_ENGINE_POSITIONS[clampi(enemy_type, 0, ENEMY_ENGINE_POSITIONS.size() - 1)],
		Color(0.92, 0.54, 0.16),
		Color(1.0, 0.32, 0.25),
		Color(1.0, 0.5, 0.1)
	)
	_enemy_ship_root = enemy_info["root"]
	_enemy_hull_mat = enemy_info["hull_mat"]
	_enemy_ship_root.position = _enemy_base_position
	_enemy_ship_root.rotation = _enemy_base_rotation
	_world_root.add_child(_enemy_ship_root)

	var enemy_shield_info := _create_shield(1.2, Color(1.0, 0.42, 0.35))
	_enemy_shield = enemy_shield_info["node"]
	_enemy_shield_mat = enemy_shield_info["mat"]
	_enemy_ship_root.add_child(_enemy_shield)


func _create_ship(polygons: Array, engines: Array, hull_color: Color, canopy_color: Color, engine_color: Color) -> Dictionary:
	var root := Node3D.new()
	root.scale = Vector3.ONE * 2.15

	var hull_mat := ShaderMaterial.new()
	hull_mat.shader = HULL_SHADER
	hull_mat.set_shader_parameter("hull_color", hull_color)
	hull_mat.set_shader_parameter("emissive_strength", 0.08)
	hull_mat.set_shader_parameter("emissive_color", Color(1.0, 0.40, 0.24))

	var hull := MeshInstance3D.new()
	hull.mesh = _build_hull_mesh(PackedVector2Array(polygons))
	hull.material_override = hull_mat
	root.add_child(hull)

	var canopy := MeshInstance3D.new()
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 0.16
	canopy_mesh.height = 0.32
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0.0, 0.74, 0.18)
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	canopy_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	canopy_mat.albedo_color = Color(canopy_color.r, canopy_color.g, canopy_color.b, 0.45)
	canopy_mat.emission_enabled = true
	canopy_mat.emission = canopy_color
	canopy_mat.emission_energy_multiplier = 0.5
	canopy.material_override = canopy_mat
	root.add_child(canopy)

	var base_engine_mat := ShaderMaterial.new()
	base_engine_mat.shader = ENGINE_SHADER
	base_engine_mat.set_shader_parameter("glow_color", Color(engine_color.r, engine_color.g, engine_color.b, 0.95))
	base_engine_mat.set_shader_parameter("pulse_speed", 2.8)

	for i in engines.size():
		var p: Vector2 = engines[i]
		var glow := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.26, 0.26)
		glow.mesh = quad
		var glow_mat: ShaderMaterial = base_engine_mat.duplicate()
		glow_mat.set_shader_parameter("pulse_phase", float(i) * 1.3)
		glow.material_override = glow_mat
		glow.position = Vector3(p.x, p.y, 0.15)
		root.add_child(glow)

	return {
		"root": root,
		"hull_mat": hull_mat,
	}


func _create_shield(radius: float, color: Color) -> Dictionary:
	var shield := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 32
	mesh.rings = 14
	shield.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.1
	shield.material_override = mat
	shield.visible = false

	return {
		"node": shield,
		"mat": mat,
	}


func _animate_starfield(delta: float) -> void:
	for i in _stars.size():
		var star: Node3D = _stars[i]
		star.position.z += delta * _star_speeds[i]
		if star.position.z > STAR_NEAR_Z:
			_reset_star(star, true)


func _animate_ships(delta: float) -> void:
	_player_hit_offset = _player_hit_offset.lerp(Vector3.ZERO, delta * 8.0)
	_enemy_hit_offset = _enemy_hit_offset.lerp(Vector3.ZERO, delta * 8.0)

	if _player_ship_root:
		var p_bob := Vector3(
			sin(_time * 1.2) * 0.12,
			sin(_time * 2.1) * 0.07,
			sin(_time * 0.9) * 0.16
		)
		_player_ship_root.position = _player_base_position + p_bob + _player_hit_offset
		_player_ship_root.rotation = _player_base_rotation + Vector3(
			sin(_time * 0.9) * 0.02,
			sin(_time * 0.8) * 0.03,
			sin(_time * 1.4) * 0.025
		)

	if _enemy_ship_root:
		var e_bob := Vector3(
			sin(_time * 1.0 + 1.4) * 0.11,
			sin(_time * 1.9 + 0.7) * 0.06,
			sin(_time * 0.8 + 0.4) * 0.15
		)
		_enemy_ship_root.position = _enemy_base_position + e_bob + _enemy_hit_offset
		_enemy_ship_root.rotation = _enemy_base_rotation + Vector3(
			sin(_time * 0.8 + 0.3) * 0.02,
			sin(_time * 0.7 + 1.0) * 0.03,
			sin(_time * 1.1 + 0.2) * 0.024
		)


func _fire_laser(from: Vector3, to: Vector3, color: Color, from_player: bool) -> void:
	_spawn_beam(from, to, color)
	_spawn_bolt(from, to, color)
	if from_player:
		_spawn_muzzle_flash(from, Color(0.45, 0.8, 1.0), 0.6)
	else:
		_spawn_muzzle_flash(from, Color(1.0, 0.4, 0.3), 0.6)


func _spawn_beam(from: Vector3, to: Vector3, color: Color) -> void:
	var beam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.11, 0.11, from.distance_to(to))
	beam.mesh = mesh
	beam.transform = Transform3D(_basis_from_direction(to - from), (from + to) * 0.5)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.1
	beam.material_override = mat
	_effects_root.add_child(beam)

	var tween := create_tween()
	tween.tween_method(func(alpha: float) -> void:
		_set_material_alpha(mat, color, alpha)
	, 0.9, 0.0, 0.12)
	tween.finished.connect(beam.queue_free)


func _spawn_bolt(from: Vector3, to: Vector3, color: Color) -> void:
	var bolt := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 12
	mesh.rings = 6
	bolt.mesh = mesh
	bolt.position = from

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.95)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	bolt.material_override = mat
	_effects_root.add_child(bolt)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(bolt, "position", to, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(alpha: float) -> void:
		_set_material_alpha(mat, color, alpha)
	, 0.95, 0.0, 0.14)
	tween.finished.connect(bolt.queue_free)


func _spawn_muzzle_flash(position_3d: Vector3, color: Color, radius: float) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius * 0.22
	mesh.height = radius * 0.44
	mesh.radial_segments = 12
	mesh.rings = 6
	flash.mesh = mesh
	flash.position = position_3d

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.9
	flash.material_override = mat
	_effects_root.add_child(flash)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 2.2, 0.10)
	tween.tween_method(func(alpha: float) -> void:
		_set_material_alpha(mat, color, alpha)
	, 0.85, 0.0, 0.10)
	tween.finished.connect(flash.queue_free)


func _flash_shield(shield: MeshInstance3D, mat: StandardMaterial3D, color: Color) -> void:
	if not shield or not mat:
		return
	shield.visible = true
	shield.scale = Vector3.ONE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(alpha: float) -> void:
		_set_shield_alpha(mat, color, alpha)
	, 0.0, 0.58, 0.08)
	tween.tween_method(func(s: float) -> void:
		shield.scale = Vector3.ONE * s
	, 1.0, 1.08, 0.08)
	tween.chain().set_parallel(true)
	tween.tween_method(func(alpha: float) -> void:
		_set_shield_alpha(mat, color, alpha)
	, 0.58, 0.0, 0.24)
	tween.tween_method(func(s: float) -> void:
		shield.scale = Vector3.ONE * s
	, 1.08, 1.0, 0.24)
	tween.chain().tween_callback(func() -> void:
		shield.visible = false
	)


func _pulse_ship_hit(on_player: bool) -> void:
	if on_player:
		_player_hit_offset += Vector3(_rng.randf_range(-0.22, 0.22), _rng.randf_range(-0.14, 0.14), 0.0)
		if _player_hull_mat:
			var tween_p := create_tween()
			tween_p.tween_method(func(v: float) -> void:
				_player_hull_mat.set_shader_parameter("emissive_strength", v)
			, 0.08, 1.2, 0.05)
			tween_p.chain().tween_method(func(v: float) -> void:
				_player_hull_mat.set_shader_parameter("emissive_strength", v)
			, 1.2, 0.08, 0.22)
	else:
		_enemy_hit_offset += Vector3(_rng.randf_range(-0.22, 0.22), _rng.randf_range(-0.14, 0.14), 0.0)
		if _enemy_hull_mat:
			var tween_e := create_tween()
			tween_e.tween_method(func(v: float) -> void:
				_enemy_hull_mat.set_shader_parameter("emissive_strength", v)
			, 0.08, 1.2, 0.05)
			tween_e.chain().tween_method(func(v: float) -> void:
				_enemy_hull_mat.set_shader_parameter("emissive_strength", v)
			, 1.2, 0.08, 0.22)


func _spawn_explosion(position_3d: Vector3, color: Color, intensity: float) -> void:
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.amount = int(58 + intensity * 24.0)
	particles.lifetime = 0.42
	particles.preprocess = 0.0
	particles.local_coords = false
	particles.position = position_3d
	particles.visibility_aabb = AABB(Vector3(-4.0, -4.0, -4.0), Vector3(8.0, 8.0, 8.0))

	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	particles.draw_pass_1 = quad

	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.albedo_color = Color(color.r, color.g, color.b, 0.92)
	particles.material_override = draw_mat

	var process_mat := ParticleProcessMaterial.new()
	process_mat.direction = Vector3(0.0, 0.0, 1.0)
	process_mat.spread = 180.0
	process_mat.gravity = Vector3.ZERO
	process_mat.initial_velocity_min = 2.8
	process_mat.initial_velocity_max = 6.8 + intensity * 1.4
	process_mat.linear_accel_min = -1.8
	process_mat.linear_accel_max = 1.1
	process_mat.scale_min = 0.35
	process_mat.scale_max = 0.85 + intensity * 0.2
	process_mat.angle_min = -180.0
	process_mat.angle_max = 180.0
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.95, 0.82, 1.0))
	gradient.add_point(0.4, Color(1.0, 0.48, 0.22, 0.9))
	gradient.add_point(1.0, Color(0.34, 0.1, 0.06, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process_mat.color_ramp = ramp
	particles.process_material = process_mat

	_effects_root.add_child(particles)
	particles.emitting = true
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(particles):
		particles.queue_free()


func _player_muzzle_position() -> Vector3:
	if _player_ship_root:
		return _player_ship_root.global_position + Vector3(0.0, 1.6, 0.20)
	return Vector3(-5.0, -1.0, -12.0)


func _enemy_muzzle_position() -> Vector3:
	if _enemy_ship_root:
		return _enemy_ship_root.global_position + Vector3(0.0, -1.6, 0.20)
	return Vector3(5.0, 1.0, -13.0)


func _player_impact_position() -> Vector3:
	if _player_ship_root:
		return _player_ship_root.global_position + Vector3(0.0, 0.45, 0.10)
	return Vector3(-5.1, -1.6, -11.0)


func _enemy_impact_position() -> Vector3:
	if _enemy_ship_root:
		return _enemy_ship_root.global_position + Vector3(0.0, -0.45, 0.10)
	return Vector3(5.4, 1.6, -13.6)


func _enemy_type_from_encounter() -> int:
	var enc: Resource = GameManager.current_encounter
	if not enc:
		return 0
	match enc.encounter_name:
		"Wandering Trader":
			return 1
		"System Patrol", "Smuggler Ambush":
			return 2
		"Pirate Captain":
			return 3
		"Rogue AI":
			return 4
		"Space Anomaly":
			return 5
		"Bounty Hunter":
			return 6
		_:
			return 0


func _update_viewport_size() -> void:
	if not _viewport:
		return
	var target_size := Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	if _viewport.size != target_size:
		_viewport.size = target_size


func _reset_star(star: Node3D, move_farther_back: bool) -> void:
	var z: float = _rng.randf_range(STAR_FAR_Z, STAR_NEAR_Z - 1.0)
	if move_farther_back:
		z = STAR_FAR_Z - _rng.randf_range(0.0, 20.0)
	star.position = Vector3(
		_rng.randf_range(-STAR_BOUNDS_X, STAR_BOUNDS_X),
		_rng.randf_range(-STAR_BOUNDS_Y, STAR_BOUNDS_Y),
		z
	)


func _basis_from_direction(direction: Vector3) -> Basis:
	var z_axis := -direction.normalized()
	var up := Vector3.UP
	if absf(z_axis.dot(up)) > 0.97:
		up = Vector3.RIGHT
	var x_axis := up.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _set_material_alpha(mat: StandardMaterial3D, color: Color, alpha: float) -> void:
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission = color


func _set_shield_alpha(mat: StandardMaterial3D, color: Color, alpha: float) -> void:
	mat.albedo_color = Color(color.r, color.g, color.b, alpha * 0.8)
	mat.emission = Color(color.r, color.g, color.b, 1.0)


# Builds an extruded low-poly hull mesh from a 2D polygon (CW winding, Y-up).
func _build_hull_mesh(poly: PackedVector2Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = poly.size()
	const DEPTH: float = 0.125

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
		st.add_vertex(Vector3(cx, cy, DEPTH))
		st.set_normal(Vector3(0.0, 0.0, 1.0))
		st.set_uv(Vector2(v1.x * 0.5 + 0.5, -v1.y * 0.5 + 0.5))
		st.add_vertex(Vector3(v1.x, v1.y, DEPTH))
		st.set_normal(Vector3(0.0, 0.0, 1.0))
		st.set_uv(Vector2(v0.x * 0.5 + 0.5, -v0.y * 0.5 + 0.5))
		st.add_vertex(Vector3(v0.x, v0.y, DEPTH))

	for i in n:
		var v0: Vector2 = poly[i]
		var v1: Vector2 = poly[(i + 1) % n]
		st.set_normal(Vector3(0.0, 0.0, -1.0))
		st.set_uv(Vector2(cx * 0.5 + 0.5, -cy * 0.5 + 0.5))
		st.add_vertex(Vector3(cx, cy, -DEPTH))
		st.set_normal(Vector3(0.0, 0.0, -1.0))
		st.set_uv(Vector2(v0.x * 0.5 + 0.5, -v0.y * 0.5 + 0.5))
		st.add_vertex(Vector3(v0.x, v0.y, -DEPTH))
		st.set_normal(Vector3(0.0, 0.0, -1.0))
		st.set_uv(Vector2(v1.x * 0.5 + 0.5, -v1.y * 0.5 + 0.5))
		st.add_vertex(Vector3(v1.x, v1.y, -DEPTH))

	for i in n:
		var v0: Vector2 = poly[i]
		var v1: Vector2 = poly[(i + 1) % n]
		var d: Vector2 = v1 - v0
		var normal := Vector3(-d.y, d.x, 0.0).normalized()
		var v0f := Vector3(v0.x, v0.y, DEPTH)
		var v1f := Vector3(v1.x, v1.y, DEPTH)
		var v0b := Vector3(v0.x, v0.y, -DEPTH)
		var v1b := Vector3(v1.x, v1.y, -DEPTH)
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
