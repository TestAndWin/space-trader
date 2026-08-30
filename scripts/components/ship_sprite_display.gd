class_name ShipSpriteDisplay
extends Control

## Shared drawing for the player and enemy ship panels.
##
## Both paint the same way: a shield ellipse, the ship sprite tinted by a hull
## colour ramp, and hairline cracks once the hull is damaged — plus a shake and
## flash on hit. Subclasses own the sprite choice, the palette and the tween
## timings, and call these helpers from their own _draw().

## Below this hull fraction the ship shows cracks.
const CRACK_THRESHOLD := 0.6

var hull_pct: float = 1.0
var shield_pct: float = 0.0
var crack_positions: Array = []
var crack_seed_generated: bool = false

var _hit_offset: Vector2 = Vector2.ZERO
var _hit_flash: float = 0.0


# ── State ────────────────────────────────────────────────────────────────────

## Stores the clamped hull/shield and re-seeds the crack pattern. Cracks are
## seeded once per damage episode so they stay put between redraws, and are
## dropped again as soon as the hull is repaired past the threshold.
func _set_hull_and_shield(p_hull_pct: float, p_shield_pct: float) -> void:
	hull_pct = clampf(p_hull_pct, 0.0, 1.0)
	shield_pct = clampf(p_shield_pct, 0.0, 1.0)
	if hull_pct < CRACK_THRESHOLD and not crack_seed_generated:
		_generate_cracks()
	elif hull_pct >= CRACK_THRESHOLD:
		crack_positions.clear()
		crack_seed_generated = false


func _generate_cracks() -> void:
	crack_positions.clear()
	var count: int = int((1.0 - hull_pct) * 8) + 1
	for i in count:
		var start := Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		var end_pt := start + Vector2(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
		crack_positions.append([start, end_pt])
	crack_seed_generated = true


# ── Hit animation (tween targets) ────────────────────────────────────────────

func _set_hit_offset_x(val: float) -> void:
	_hit_offset.x = val
	queue_redraw()


func _set_hit_offset_y(val: float) -> void:
	_hit_offset.y = val
	queue_redraw()


func _set_hit_flash(val: float) -> void:
	_hit_flash = val
	queue_redraw()


# ── Drawing helpers ──────────────────────────────────────────────────────────

## Hull tint: `high` above 60%, fading through `mid` at 30% down to `low`.
func _hull_ramp(high: Color, mid: Color, low: Color) -> Color:
	if hull_pct > 0.6:
		return high
	if hull_pct > 0.3:
		return mid.lerp(high, (hull_pct - 0.3) / 0.3)
	return low.lerp(mid, hull_pct / 0.3)


func _draw_sprite(tex: Texture2D, center: Vector2, span: float, tint: Color) -> void:
	if tex == null:
		return
	draw_texture_rect(tex, Rect2(center - Vector2(span, span) * 0.5, Vector2(span, span)), false, tint)


func _draw_cracks(center: Vector2, span: float) -> void:
	if hull_pct >= CRACK_THRESHOLD:
		return
	var crack_color := Color(0.15, 0.1, 0.05, 0.6 + (1.0 - hull_pct) * 0.4)
	for crack in crack_positions:
		var p1 := center + Vector2(crack[0].x, crack[0].y) * span
		var p2 := center + Vector2(crack[1].x, crack[1].y) * span
		draw_line(p1, p2, crack_color, 1.5)


func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	var segments: int = 32
	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(center.x + cos(angle) * rx, center.y + sin(angle) * ry))
	draw_colored_polygon(points, color)
