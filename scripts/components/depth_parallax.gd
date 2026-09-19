extends Node

## DepthParallax — turns the planet hub's flat background into a 2.5D scene.
## Displaces the illustration by a depth map (bg_<planet>_depth.png, made by
## tools/generate_depth_maps.py) as the view drifts, follows the mouse on
## desktop or the tilt of the device on touch screens, and moves the building
## hotspots along with the pixels they sit on. Also owns the camera zoom into a
## building. Usage: const DepthParallax = preload(...); DepthParallax.new()
## then attach(bg_rect, depth_texture).

const ParallaxShader: Shader = preload("res://shaders/depth_parallax.gdshader")

## Hotspot rects in PlanetData are authored against this size.
const DESIGN_SIZE := Vector2(1280.0, 720.0)
## Largest displacement in texture UV; x wider than y because looking sideways
## over a landscape reads better than bobbing up and down.
const MAX_OFFSET := Vector2(0.016, 0.009)
const EDGE_ZOOM: float = 1.03
const FOCUS_DEPTH: float = 0.5
## How quickly the view catches up with its target (per second).
const FOLLOW_SPEED: float = 3.0
## Idle drift keeps the scene alive when nothing steers it.
const DRIFT_PERIOD := Vector2(19.0, 13.0)
const DRIFT_AMOUNT: float = 0.35
const MOUSE_WEIGHT: float = 0.8
## Device tilt (m/s² of gravity change) that maps to the full offset; the
## rest pose re-centres slowly so any comfortable grip becomes neutral.
const TILT_FULL: float = 3.0
const TILT_RECENTER_SPEED: float = 0.25
const ZOOM_IN_TIME: float = 0.8
const ZOOM_OUT_TIME: float = 0.8
const ZOOM_FACTOR: float = 2.2

var _bg: TextureRect
var _material: ShaderMaterial
var _depth: Image
var _cover := Vector2.ONE
var _offset := Vector2.ZERO
var _time: float = 0.0
var _use_tilt: bool = false
var _tilt_rest := Vector3.ZERO
var _cam_tween: Tween
## Where the camera is headed: true from zoom_to() until zoom_out().
var _zoomed: bool = false
## Tracked controls and the design-space point each one is pinned to.
var _tracked: Array[Control] = []
var _anchors: Array[Vector2] = []


## Returns false (and leaves the background untouched) when there is no depth
## map, so a planet without one keeps its plain static image.
func attach(bg: TextureRect, depth_texture: Texture2D) -> bool:
	if bg.texture == null or depth_texture == null:
		return false
	_depth = depth_texture.get_image()
	if _depth == null:
		return false
	if _depth.is_compressed():
		_depth.decompress()
	_bg = bg
	var tex_size: Vector2 = bg.texture.get_size()
	var tex_aspect: float = tex_size.x / tex_size.y
	var design_aspect: float = DESIGN_SIZE.x / DESIGN_SIZE.y
	_cover = Vector2(design_aspect / tex_aspect, 1.0) if tex_aspect > design_aspect \
		else Vector2(1.0, tex_aspect / design_aspect)
	_material = ShaderMaterial.new()
	_material.shader = ParallaxShader
	_material.set_shader_parameter("depth_map", depth_texture)
	_material.set_shader_parameter("cover_scale", _cover)
	_material.set_shader_parameter("edge_zoom", EDGE_ZOOM)
	_material.set_shader_parameter("focus_depth", FOCUS_DEPTH)
	# Set explicitly: tweens need the parameters to exist on the material.
	_material.set_shader_parameter("parallax_offset", Vector2.ZERO)
	_material.set_shader_parameter("cam_center", Vector2(0.5, 0.5))
	_material.set_shader_parameter("cam_zoom", 1.0)
	# The shader does its own aspect-cover crop.
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.material = _material
	_use_tilt = DisplayServer.is_touchscreen_available()
	return true


func is_attached() -> bool:
	return _material != null


## Pins a full-rect control to a design-space point: it is translated every
## frame by however far the background under that point moves.
func track(control: Control, design_point: Vector2) -> void:
	_tracked.append(control)
	_anchors.append(design_point)
	_place(control, design_point)


## Magnifies the background onto a design-space point. Returns the tween so
## the caller can open the building when the camera arrives.
func zoom_to(design_point: Vector2) -> Tween:
	var half: float = 0.5 / ZOOM_FACTOR
	var target := Vector2(
		clampf(design_point.x / DESIGN_SIZE.x, half, 1.0 - half),
		clampf(design_point.y / DESIGN_SIZE.y, half, 1.0 - half))
	_zoomed = true
	return _tween_camera(target, ZOOM_FACTOR, ZOOM_IN_TIME, Tween.EASE_IN)


func zoom_out() -> Tween:
	_zoomed = false
	return _tween_camera(Vector2(0.5, 0.5), 1.0, ZOOM_OUT_TIME, Tween.EASE_OUT)


func is_zoomed() -> bool:
	return _zoomed


func _tween_camera(center: Vector2, zoom: float, duration: float, ease_type: Tween.EaseType) -> Tween:
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	if _material == null:
		# Without a shader there is no camera; finish at once so callers
		# waiting on `finished` still proceed.
		_cam_tween.tween_interval(0.0)
		return _cam_tween
	_cam_tween.tween_property(_material, "shader_parameter/cam_center", center, duration)
	_cam_tween.tween_property(_material, "shader_parameter/cam_zoom", zoom, duration)
	return _cam_tween


func _process(delta: float) -> void:
	if _material == null:
		return
	_time += delta
	var target: Vector2 = _drift() * DRIFT_AMOUNT
	if _use_tilt:
		target += _tilt(delta)
	else:
		target += _mouse() * MOUSE_WEIGHT
	target = target.limit_length(1.0)
	_offset = _offset.lerp(target, clampf(delta * FOLLOW_SPEED, 0.0, 1.0))
	_material.set_shader_parameter("parallax_offset", _offset * MAX_OFFSET)
	for i: int in range(_tracked.size() - 1, -1, -1):
		var control: Control = _tracked[i]
		if not is_instance_valid(control):
			_tracked.remove_at(i)
			_anchors.remove_at(i)
			continue
		_place(control, _anchors[i])


func _drift() -> Vector2:
	return Vector2(sin(_time * TAU / DRIFT_PERIOD.x), sin(_time * TAU / DRIFT_PERIOD.y))


## Mouse position relative to the screen centre, -1..1 per axis.
func _mouse() -> Vector2:
	var size: Vector2 = _bg.size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	var rel: Vector2 = _bg.get_local_mouse_position() / size * 2.0 - Vector2.ONE
	return rel.clamp(-Vector2.ONE, Vector2.ONE)


func _tilt(delta: float) -> Vector2:
	var gravity: Vector3 = Input.get_gravity()
	if gravity == Vector3.ZERO:
		return Vector2.ZERO
	if _tilt_rest == Vector3.ZERO:
		_tilt_rest = gravity
	_tilt_rest = _tilt_rest.lerp(gravity, clampf(delta * TILT_RECENTER_SPEED, 0.0, 1.0))
	var diff: Vector3 = gravity - _tilt_rest
	return Vector2(diff.x, -diff.y) / TILT_FULL


## Where a point of the texture (UV 0..1) currently shows on screen, in
## design pixels: the inverse of the shader's mapping, camera included.
## Pass `depth` to move a whole shape with the depth of one reference point.
func texture_to_screen(uv: Vector2, depth: float = -1.0) -> Vector2:
	if depth < 0.0:
		depth = sample_depth(uv)
	var t: Vector2 = uv - _offset * MAX_OFFSET * (depth - FOCUS_DEPTH)
	var s: Vector2 = Vector2(0.5, 0.5) + (t - Vector2(0.5, 0.5)) / _cover
	s = Vector2(0.5, 0.5) + (s - Vector2(0.5, 0.5)) * EDGE_ZOOM
	var cam_center: Vector2 = _material.get_shader_parameter("cam_center")
	var cam_zoom: float = _material.get_shader_parameter("cam_zoom")
	return (Vector2(0.5, 0.5) + (s - cam_center) * cam_zoom) * DESIGN_SIZE


## Design pixels per texture UV along each axis at the current zoom.
func texture_scale() -> Vector2:
	var cam_zoom: float = _material.get_shader_parameter("cam_zoom")
	return DESIGN_SIZE / _cover * EDGE_ZOOM * cam_zoom


## Current magnification relative to the plain background (1.0 at rest).
func view_zoom() -> float:
	return EDGE_ZOOM * float(_material.get_shader_parameter("cam_zoom"))


func design_to_texture(design_point: Vector2) -> Vector2:
	return Vector2(0.5, 0.5) + (design_point / DESIGN_SIZE - Vector2(0.5, 0.5)) * _cover


func _place(control: Control, design_point: Vector2) -> void:
	var shift: Vector2 = texture_to_screen(design_to_texture(design_point)) - design_point
	control.position = shift * control.get_parent_area_size() / DESIGN_SIZE


## Depth (0 far .. 1 near) of the texture at a UV point.
func sample_depth(uv: Vector2) -> float:
	var x: int = clampi(int(uv.x * _depth.get_width()), 0, _depth.get_width() - 1)
	var y: int = clampi(int(uv.y * _depth.get_height()), 0, _depth.get_height() - 1)
	return _depth.get_pixel(x, y).r
