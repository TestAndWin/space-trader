extends RefCounted

## BackgroundUtils — shared helpers for scene and building backgrounds.
## Usage: const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")
## All methods are static.

const SCENE_BACKGROUND_PATHS: PackedStringArray = [
	"res://assets/sprites/bg_start.png",
	"res://assets/sprites/bg_battle.png",
	"res://assets/sprites/bg_battle_result.png",
	"res://assets/sprites/bg_galaxy_map.png",
	"res://assets/sprites/bg_travel.png",
	"res://assets/sprites/bg_game_over.png",
	"res://assets/sprites/bg_victory.png",
]

const BUILDING_BACKGROUND_KEYS: PackedStringArray = [
	"market",
	"shipyard",
	"casino",
	"crew",
	"quest",
	"deck",
	"mission",
]


static func load_texture(path: String, strict: bool = true) -> Texture2D:
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if tex == null and strict:
		push_error("Missing background image: %s" % path)
	return tex


static func add_fullscreen_background(
	parent: Control,
	image_path: String,
	dim_alpha: float = 0.5,
	insert_index: int = -1,
	strict: bool = true,
	stretch_mode: int = TextureRect.STRETCH_KEEP_ASPECT_COVERED
) -> bool:
	var tex: Texture2D = load_texture(image_path, strict)
	if tex == null:
		return false

	var bg := TextureRect.new()
	bg.name = "FullscreenBackground"
	bg.texture = tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = stretch_mode
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)

	if insert_index >= 0:
		parent.move_child(bg, clampi(insert_index, 0, parent.get_child_count() - 1))

	if dim_alpha > 0.0:
		var dim := ColorRect.new()
		dim.name = "FullscreenBackgroundDim"
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.0, 0.0, 0.0, dim_alpha)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(dim)
		if insert_index >= 0:
			parent.move_child(dim, clampi(insert_index + 1, 0, parent.get_child_count() - 1))

	return true


static func add_building_background(parent: Control, building_key: String, dim_alpha: float = 0.4, strict: bool = true) -> bool:
	var path := "res://assets/sprites/bg_building_%s.png" % building_key
	return add_fullscreen_background(parent, path, dim_alpha, -1, strict)


static func add_3d_quad_background(parent: Node3D, image_path: String, quad_size: Vector2, z_depth: float, alpha: float = 0.35, strict: bool = true) -> bool:
	var tex: Texture2D = load_texture(image_path, strict)
	if tex == null:
		return false

	var bg_quad := MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = quad_size
	bg_quad.mesh = quad_mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	bg_quad.material_override = mat
	bg_quad.position = Vector3(0.0, 0.0, z_depth)
	parent.add_child(bg_quad)
	return true


static func collect_required_background_paths(planet_data_dir: String = "res://data/planets") -> Array[String]:
	var required: Array[String] = []
	for path in SCENE_BACKGROUND_PATHS:
		required.append(path)

	for key in BUILDING_BACKGROUND_KEYS:
		required.append("res://assets/sprites/bg_building_%s.png" % key)

	var planet_dir := DirAccess.open(planet_data_dir)
	if planet_dir:
		for file_name in planet_dir.get_files():
			if file_name.get_extension() == "tres":
				required.append("res://assets/sprites/bg_%s.png" % file_name.get_basename().to_lower())
	else:
		push_warning("BackgroundUtils: cannot open planet directory: %s" % planet_data_dir)

	required.sort()
	var unique_paths: Array[String] = []
	var last_path := ""
	for path in required:
		if path != last_path:
			unique_paths.append(path)
			last_path = path
	return unique_paths


static func validate_required_backgrounds(planet_data_dir: String = "res://data/planets") -> Array[String]:
	var missing: Array[String] = []
	for path in collect_required_background_paths(planet_data_dir):
		if not ResourceLoader.exists(path):
			missing.append(path)
	missing.sort()

	if not missing.is_empty():
		push_error("Missing required background images:\n- %s" % "\n- ".join(missing))

	return missing
