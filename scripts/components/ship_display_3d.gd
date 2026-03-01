extends Control

## 3D low-poly ship display using SubViewport.
## Public API is identical to ship_display.gd.

var hull_pct: float = 1.0
var shield_pct: float = 0.0
var cargo_used: int = 0
var cargo_max: int = 10
var ship_shape: int = 0

var _base_emissive: float = 0.0

var _viewport: SubViewport
var _ship_root: Node3D
var _hull_mi: MeshInstance3D
var _shield_mi: MeshInstance3D
var _engine_mis: Array = []
var _hull_mat: ShaderMaterial
var _shield_mat: ShaderMaterial

const HULL_SHADER = preload("res://shaders/ship_hull.gdshader")
const SHIELD_SHADER = preload("res://shaders/ship_shield.gdshader")
const ENGINE_SHADER = preload("res://shaders/engine_glow.gdshader")

# Normalized 3D polygon coords (Y-up, ×2 scale, tip at +Y, engines at −Y).
# Derived from ship_display.gd polygon offsets with Y-axis inversion.
const HULL_POLYGONS: Array = [
	# 0: Scout — original shape
	[Vector2(0.0, 0.84), Vector2(0.24, 0.50), Vector2(0.64, -0.20),
	 Vector2(0.36, -0.30), Vector2(0.20, -0.70), Vector2(-0.20, -0.70),
	 Vector2(-0.36, -0.30), Vector2(-0.64, -0.20), Vector2(-0.24, 0.50)],
	# 1: Freighter — wide, boxy
	[Vector2(0.0, 0.64), Vector2(0.40, 0.50), Vector2(0.56, 0.10),
	 Vector2(0.56, -0.40), Vector2(0.30, -0.70), Vector2(-0.30, -0.70),
	 Vector2(-0.56, -0.40), Vector2(-0.56, 0.10), Vector2(-0.40, 0.50)],
	# 2: Warship — angular, aggressive
	[Vector2(0.0, 0.88), Vector2(0.16, 0.60), Vector2(0.70, 0.0),
	 Vector2(0.60, -0.30), Vector2(0.30, -0.40), Vector2(0.24, -0.76),
	 Vector2(-0.24, -0.76), Vector2(-0.30, -0.40), Vector2(-0.60, -0.30),
	 Vector2(-0.70, 0.0), Vector2(-0.16, 0.60)],
	# 3: Smuggler — slim, fast
	[Vector2(0.0, 0.90), Vector2(0.16, 0.60), Vector2(0.36, 0.0),
	 Vector2(0.44, -0.30), Vector2(0.24, -0.70), Vector2(-0.24, -0.70),
	 Vector2(-0.44, -0.30), Vector2(-0.36, 0.0), Vector2(-0.16, 0.60)],
	# 4: Explorer — rounded
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


func update_ship(p_hull_pct: float, p_shield_pct: float, p_cargo_used: int, p_cargo_max: int, p_ship_shape: int = -1) -> void:
	hull_pct = clampf(p_hull_pct, 0.0, 1.0)
	shield_pct = clampf(p_shield_pct, 0.0, 1.0)
	cargo_used = p_cargo_used
	cargo_max = p_cargo_max
	if p_ship_shape >= 0 and p_ship_shape != ship_shape:
		ship_shape = p_ship_shape
		if _hull_mi:
			_build_ship(ship_shape)
	if _hull_mat:
		_update_hull_visual()
	if _shield_mat:
		_shield_mat.set_shader_parameter("shield_strength", shield_pct)
		_shield_mi.visible = shield_pct > 0.001


func play_shield_hit() -> void:
	if not _shield_mat:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_shield_flash, 0.0, 1.0, 0.05)
	tween.tween_method(_set_shield_flash, 1.0, 0.0, 0.35).set_delay(0.05)
	tween.tween_method(_set_ship_x, 0.0, 0.08, 0.04)
	tween.tween_method(_set_ship_x, 0.08, -0.06, 0.06).set_delay(0.04)
	tween.tween_method(_set_ship_x, -0.06, 0.0, 0.08).set_delay(0.10)


func play_hull_hit() -> void:
	if not _hull_mat:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_emissive, 0.0, 1.2, 0.04)
	tween.tween_method(_set_emissive, 1.2, _base_emissive, 0.36).set_delay(0.04)
	tween.tween_method(_set_ship_x, 0.0, 0.14, 0.03)
	tween.tween_method(_set_ship_x, 0.14, -0.12, 0.05).set_delay(0.03)
	tween.tween_method(_set_ship_x, -0.12, 0.10, 0.04).set_delay(0.08)
	tween.tween_method(_set_ship_x, 0.10, 0.0, 0.10).set_delay(0.12)


func _set_shield_flash(val: float) -> void:
	if _shield_mat:
		_shield_mat.set_shader_parameter("hit_flash", val)


func _set_emissive(val: float) -> void:
	if _hull_mat:
		_hull_mat.set_shader_parameter("emissive_strength", val)


func _set_ship_x(val: float) -> void:
	if _ship_root:
		_ship_root.position.x = val


func _ready() -> void:
	_setup_viewport()
	_setup_scene()
	resized.connect(_on_resized)
	call_deferred("_on_resized")


func _setup_viewport() -> void:
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = SubViewport.MSAA_2X
	container.add_child(_viewport)


func _setup_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.TRANSPARENT
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.18, 0.25)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.95, 0.85)
	key_light.light_energy = 1.4
	key_light.rotation = Vector3(-35.0, 30.0, 0.0) * (PI / 180.0)
	_viewport.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.light_color = Color(0.4, 0.5, 0.8)
	fill_light.light_energy = 0.4
	fill_light.rotation = Vector3(30.0, -150.0, 0.0) * (PI / 180.0)
	_viewport.add_child(fill_light)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.2
	camera.position = Vector3(0.0, 0.0, 5.0)
	_viewport.add_child(camera)

	_ship_root = Node3D.new()
	_viewport.add_child(_ship_root)

	_hull_mat = ShaderMaterial.new()
	_hull_mat.shader = HULL_SHADER
	_hull_mat.set_shader_parameter("hull_color", Color(0.3, 0.85, 0.3))
	_hull_mat.set_shader_parameter("emissive_strength", 0.0)
	_hull_mat.set_shader_parameter("emissive_color", Color(1.0, 0.3, 0.2))

	_shield_mat = ShaderMaterial.new()
	_shield_mat.shader = SHIELD_SHADER
	_shield_mat.set_shader_parameter("shield_color", Color(0.2, 0.5, 1.0, 0.8))
	_shield_mat.set_shader_parameter("shield_strength", 0.0)
	_shield_mat.set_shader_parameter("hit_flash", 0.0)
	_shield_mat.set_shader_parameter("hit_color", Color(0.8, 0.9, 1.0, 1.0))

	_hull_mi = MeshInstance3D.new()
	_hull_mi.material_override = _hull_mat
	_ship_root.add_child(_hull_mi)

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.05
	sphere_mesh.height = 2.1
	sphere_mesh.rings = 16
	sphere_mesh.radial_segments = 32
	_shield_mi = MeshInstance3D.new()
	_shield_mi.mesh = sphere_mesh
	_shield_mi.material_override = _shield_mat
	_shield_mi.visible = false
	_ship_root.add_child(_shield_mi)

	_build_ship(ship_shape)


func _build_ship(shape: int) -> void:
	for mi: MeshInstance3D in _engine_mis:
		mi.queue_free()
	_engine_mis.clear()

	var idx: int = clampi(shape, 0, HULL_POLYGONS.size() - 1)
	var poly := PackedVector2Array(HULL_POLYGONS[idx])
	_hull_mi.mesh = _build_hull_mesh(poly)

	var positions: Array = ENGINE_POSITIONS[idx]
	var base_mat := ShaderMaterial.new()
	base_mat.shader = ENGINE_SHADER
	base_mat.set_shader_parameter("glow_color", Color(1.0, 0.6, 0.15, 1.0))
	base_mat.set_shader_parameter("pulse_speed", 2.5)

	for i in positions.size():
		var pos: Vector2 = positions[i]
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.30, 0.30)
		mi.mesh = quad
		var mat: ShaderMaterial = base_mat.duplicate()
		mat.set_shader_parameter("pulse_phase", float(i) * 1.2)
		mi.material_override = mat
		mi.position = Vector3(pos.x, pos.y, 0.14)
		_ship_root.add_child(mi)
		_engine_mis.append(mi)


# Builds an extruded low-poly hull mesh from a 2D polygon (CW winding, Y-up).
# Front face at Z=+depth, back face at Z=-depth, side walls connect them.
func _build_hull_mesh(poly: PackedVector2Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = poly.size()
	const depth: float = 0.125

	# Centroid for fan triangulation
	var cx: float = 0.0
	var cy: float = 0.0
	for v: Vector2 in poly:
		cx += v.x
		cy += v.y
	cx /= float(n)
	cy /= float(n)

	# Front face (Z = +depth, normal +Z).
	# Polygon is CW from +Z, so fan order (centroid, v_{i+1}, v_i) gives CCW = correct front face.
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

	# Back face (Z = -depth, normal -Z).
	# Fan order (centroid, v_i, v_{i+1}) is CW from +Z = CCW from -Z = correct back face.
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

	# Side walls: one quad per polygon edge.
	# For CW polygon, outward normal of edge (v0→v1) is left-perpendicular = (-D.y, D.x, 0).
	# Winding (v0f, v1f, v1b) + (v0f, v1b, v0b) is CCW when viewed from outside.
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


func _update_hull_visual() -> void:
	var color: Color
	if hull_pct > 0.6:
		color = Color(0.3, 0.85, 0.3)
	elif hull_pct > 0.3:
		var t: float = (hull_pct - 0.3) / 0.3
		color = Color(0.9, 0.85, 0.2).lerp(Color(0.3, 0.85, 0.3), t)
	else:
		var t: float = hull_pct / 0.3
		color = Color(0.9, 0.2, 0.2).lerp(Color(0.9, 0.85, 0.2), t)
	_hull_mat.set_shader_parameter("hull_color", color)
	if hull_pct < 0.3:
		_base_emissive = (0.3 - hull_pct) / 0.3 * 0.4
	else:
		_base_emissive = 0.0
	_hull_mat.set_shader_parameter("emissive_strength", _base_emissive)


func _on_resized() -> void:
	if _viewport:
		var px := Vector2i(maxi(int(size.x), 1), maxi(int(size.y), 1))
		_viewport.size = px
