extends Control

## HubAmbience — small animated lights layered over a planet background:
## blinking beacons, flickering neon signs, scan lines on screens, traffic on
## sky lanes and roads, and shuttles lifting off. Effects are data (see
## hub_ambience_presets.gd) placed in texture UV, and are positioned through
## DepthParallax every frame so they sway and zoom with the painted pixels.
## Usage: const HubAmbience = preload(...); var a := HubAmbience.new();
## a.setup(parallax, effects); add it right above the background.

const DepthParallax = preload("res://scripts/components/depth_parallax.gd")

## Premultiplied blending lets one layer both add light (alpha 0) and dim
## (black with alpha), which neon dropouts need. Glow texture resolution:
const GLOW_SIZE: int = 64
## Traffic fades in/out over this share of its path.
const PATH_FADE: float = 0.12
## Near objects (depth 1) draw this much larger than far ones (depth 0).
const DEPTH_SCALE_FAR: float = 0.55
const DEPTH_SCALE_NEAR: float = 1.25
const LAUNCH_TRAIL_STEPS: int = 18
const LAUNCH_TRAIL_SPACING: float = 0.009

var _parallax: Node
var _effects: Array[Dictionary] = []
var _time: float = 0.0
var _glow: Texture2D
var _rng := RandomNumberGenerator.new()


func setup(parallax: Node, effects: Array) -> void:
	_parallax = parallax
	for effect: Dictionary in effects:
		var entry: Dictionary = effect.duplicate()
		if entry.has("path"):
			entry["lengths"] = _cumulative_lengths(entry["path"])
		if entry["type"] == "neon":
			entry["next_dropout"] = _rng.randf_range(1.0, _dropout_gap(entry))
			entry["dropout_until"] = 0.0
		_effects.append(entry)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	material = mat
	_glow = _make_glow_texture()


func _process(delta: float) -> void:
	# Shares the parallax's pause: it stops while an overlay hides the hub.
	if _parallax == null or not _parallax.is_processing():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _parallax == null:
		return
	# Everything is laid out in design pixels; scale to the actual control.
	draw_set_transform(Vector2.ZERO, 0.0, size / DepthParallax.DESIGN_SIZE)
	for effect: Dictionary in _effects:
		match effect["type"]:
			"beacon": _draw_beacon(effect)
			"glow": _draw_breathing_glow(effect)
			"neon": _draw_neon(effect)
			"scan": _draw_scan(effect)
			"traffic": _draw_traffic(effect)
			"launch": _draw_launch(effect)


# ── Effects ──────────────────────────────────────────────────────────────────

## Short flash once per period, like an aircraft warning light.
func _draw_beacon(e: Dictionary) -> void:
	var cycle: float = fposmod(_time / float(e["period"]) + float(e.get("phase", 0.0)), 1.0)
	var on: float = 1.0 - smoothstep(0.0, 0.22, cycle)
	if on <= 0.0:
		return
	var pos: Vector2 = _parallax.texture_to_screen(e["pos"])
	var radius: float = float(e["radius"]) * _parallax.view_zoom()
	_add_glow(pos, radius * 2.2, e["color"], 0.8 * on)
	_add_dot(pos, radius * 0.3, e["color"], on)


func _draw_breathing_glow(e: Dictionary) -> void:
	var breath: float = 0.5 + 0.5 * sin(_time * TAU / float(e["period"]))
	var pos: Vector2 = _parallax.texture_to_screen(e["pos"])
	var radius: float = float(e["radius"]) * _parallax.view_zoom() * (0.9 + 0.2 * breath)
	_add_glow(pos, radius, e["color"], float(e.get("strength", 0.35)) * (0.6 + 0.4 * breath))


## Soft halo over a painted sign, with occasional brief dropouts.
func _draw_neon(e: Dictionary) -> void:
	if _time >= float(e["next_dropout"]):
		e["dropout_until"] = _time + _rng.randf_range(0.06, 0.2)
		# Failing tubes stutter: often a second blink follows right away.
		var stutter: bool = _rng.randf() < 0.45
		e["next_dropout"] = _time + (_rng.randf_range(0.12, 0.3) if stutter else _rng.randf_range(0.5, 1.5) * _dropout_gap(e))
	var rect: Rect2 = _map_rect(e["rect"])
	var center: Vector2 = rect.get_center()
	if _time < float(e["dropout_until"]):
		draw_texture_rect(_glow, _grow_rect(rect, 1.15), false, Color(0.0, 0.0, 0.0, 0.5))
		return
	var hum: float = 0.85 + 0.15 * sin(_time * 7.3 + center.x)
	var color: Color = e["color"]
	var strength: float = float(e.get("strength", 0.3)) * hum
	draw_texture_rect(_glow, _grow_rect(rect, 1.6), false, Color(color.r, color.g, color.b, 0.0) * strength)


## A bright band sweeping down a screen, plus a faint shimmer.
func _draw_scan(e: Dictionary) -> void:
	var rect: Rect2 = _map_rect(e["rect"])
	var color: Color = e["color"]
	var progress: float = fposmod(_time / float(e["period"]) + float(e.get("phase", 0.0)), 1.0)
	var band_h: float = maxf(rect.size.y * 0.07, 2.0)
	var y: float = rect.position.y + progress * (rect.size.y - band_h)
	var shimmer: float = 0.04 + 0.03 * sin(_time * 11.0 + rect.position.x)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.0) * shimmer)
	draw_rect(Rect2(rect.position.x, y, rect.size.x, band_h), Color(color.r, color.g, color.b, 0.0) * 0.28)


## Lights travelling along a path, evenly spaced, fading at both ends.
func _draw_traffic(e: Dictionary) -> void:
	var count: int = int(e["count"])
	var travel: float = _time / float(e["duration"]) + float(e.get("phase", 0.0))
	for i: int in count:
		var t: float = fposmod(travel + float(i) / count, 1.0)
		var fade: float = smoothstep(0.0, PATH_FADE, t) * smoothstep(1.0, 1.0 - PATH_FADE, t)
		var uv: Vector2 = _point_on_path(e, t)
		var pos: Vector2 = _parallax.texture_to_screen(uv)
		var radius: float = float(e["radius"]) * _parallax.view_zoom() * _depth_scale(uv)
		_add_glow(pos, radius * 2.0, e["color"], 0.55 * fade)
		_add_dot(pos, radius * 0.35, e["color"], fade)


## A craft climbing away along a path with an engine trail, once per interval.
func _draw_launch(e: Dictionary) -> void:
	var elapsed: float = fposmod(_time + float(e.get("phase", 0.0)), float(e["interval"]))
	var p: float = elapsed / float(e["duration"])
	if p >= 1.0:
		return
	var color: Color = e["color"]
	# Ignition flare on the pad before the craft visibly moves.
	if p < 0.15:
		var pad: Vector2 = _parallax.texture_to_screen(_point_on_path(e, 0.0))
		_add_glow(pad, float(e["radius"]) * 4.0 * _parallax.view_zoom(), color, 0.5 * sin(p / 0.15 * PI))
	for step: int in range(LAUNCH_TRAIL_STEPS, -1, -1):
		var q: float = p - step * LAUNCH_TRAIL_SPACING
		if q < 0.0:
			continue
		var t: float = pow(q, 1.7)
		var uv: Vector2 = _point_on_path(e, t)
		var pos: Vector2 = _parallax.texture_to_screen(uv)
		var fade: float = (1.0 - smoothstep(0.7, 1.0, q)) * (1.0 - float(step) / (LAUNCH_TRAIL_STEPS + 1))
		var radius: float = float(e["radius"]) * _parallax.view_zoom() * _depth_scale(uv) * lerpf(1.0, 0.35, t)
		_add_glow(pos, radius * (2.2 if step == 0 else 1.2), color, (0.8 if step == 0 else 0.35) * fade)
		if step == 0:
			_add_dot(pos, radius * 0.4, Color.WHITE, fade)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _add_glow(pos: Vector2, radius: float, color: Color, strength: float) -> void:
	if strength <= 0.0:
		return
	var r := Vector2(radius, radius)
	draw_texture_rect(_glow, Rect2(pos - r, r * 2.0), false, Color(color.r, color.g, color.b, 0.0) * strength)


func _add_dot(pos: Vector2, radius: float, color: Color, strength: float) -> void:
	if strength <= 0.0:
		return
	draw_circle(pos, maxf(radius, 1.0), Color(color.r, color.g, color.b, 0.0) * strength)


## Maps a UV rect to design pixels, moved by the depth at its centre.
func _map_rect(uv_rect: Rect2) -> Rect2:
	var center_uv: Vector2 = uv_rect.get_center()
	var center: Vector2 = _parallax.texture_to_screen(center_uv)
	var rect_size: Vector2 = uv_rect.size * _parallax.texture_scale()
	return Rect2(center - rect_size * 0.5, rect_size)


func _grow_rect(rect: Rect2, factor: float) -> Rect2:
	var grown: Vector2 = rect.size * factor
	return Rect2(rect.get_center() - grown * 0.5, grown)


func _depth_scale(uv: Vector2) -> float:
	return lerpf(DEPTH_SCALE_FAR, DEPTH_SCALE_NEAR, _parallax.sample_depth(uv))


func _dropout_gap(e: Dictionary) -> float:
	return 60.0 / maxf(float(e.get("dropouts_per_minute", 4.0)), 0.1)


func _cumulative_lengths(path: PackedVector2Array) -> PackedFloat32Array:
	var lengths := PackedFloat32Array([0.0])
	for i: int in range(1, path.size()):
		lengths.append(lengths[i - 1] + path[i - 1].distance_to(path[i]))
	return lengths


func _point_on_path(e: Dictionary, t: float) -> Vector2:
	var path: PackedVector2Array = e["path"]
	var lengths: PackedFloat32Array = e["lengths"]
	var target: float = clampf(t, 0.0, 1.0) * lengths[lengths.size() - 1]
	for i: int in range(1, path.size()):
		if target <= lengths[i]:
			var seg: float = lengths[i] - lengths[i - 1]
			var local: float = 0.0 if seg <= 0.0 else (target - lengths[i - 1]) / seg
			return path[i - 1].lerp(path[i], local)
	return path[path.size() - 1]


func _make_glow_texture() -> Texture2D:
	var gradient := Gradient.new()
	# Premultiplied: colour falls off together with alpha.
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	gradient.add_point(0.35, Color(0.45, 0.45, 0.45, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = GLOW_SIZE
	tex.height = GLOW_SIZE
	return tex
