extends Control

## Procedural enemy ship display for the battle UI.
## Shows enemy ship silhouette colored by HP%, damage cracks, shield bubble.
## API: update_enemy(hull_pct, shield_pct, encounter_name)
##       play_hit() — shake + flash on taking damage

var hull_pct: float = 1.0
var shield_pct: float = 0.0
var _ship_type: int = 0  # 0=fighter, 1=freighter, 2=patrol, 3=battleship, 4=drone, 5=anomaly, 6=hunter
var _crack_positions: Array = []
var _crack_seed_generated: bool = false

# Hit animation state
var _hit_offset: Vector2 = Vector2.ZERO
var _hit_flash: float = 0.0  # 0..1, fades out


func update_enemy(p_hull_pct: float, p_shield_pct: float, encounter_name: String) -> void:
	hull_pct = clampf(p_hull_pct, 0.0, 1.0)
	shield_pct = clampf(p_shield_pct, 0.0, 1.0)
	_ship_type = _type_from_name(encounter_name)
	if hull_pct < 0.6 and not _crack_seed_generated:
		_generate_cracks()
	elif hull_pct >= 0.6:
		_crack_positions.clear()
		_crack_seed_generated = false
	queue_redraw()


func play_hit() -> void:
	# Shake + flash tween
	var tween := create_tween()
	tween.set_parallel(true)
	# Shake: offset left-right rapidly then settle
	tween.tween_method(_set_hit_offset_x, 0.0, 5.0, 0.04)
	tween.tween_method(_set_hit_offset_x, 5.0, -4.0, 0.06).set_delay(0.04)
	tween.tween_method(_set_hit_offset_x, -4.0, 3.0, 0.05).set_delay(0.10)
	tween.tween_method(_set_hit_offset_x, 3.0, -2.0, 0.04).set_delay(0.15)
	tween.tween_method(_set_hit_offset_x, -2.0, 0.0, 0.06).set_delay(0.19)
	# Flash white-red
	tween.tween_method(_set_hit_flash, 0.0, 1.0, 0.06)
	tween.tween_method(_set_hit_flash, 1.0, 0.0, 0.25).set_delay(0.06)


func _set_hit_offset_x(val: float) -> void:
	_hit_offset.x = val
	queue_redraw()


func _set_hit_flash(val: float) -> void:
	_hit_flash = val
	queue_redraw()


func _type_from_name(encounter_name: String) -> int:
	match encounter_name:
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


func _generate_cracks() -> void:
	_crack_positions.clear()
	var count: int = int((1.0 - hull_pct) * 8) + 1
	for i in count:
		var start := Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		var end_pt := start + Vector2(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
		_crack_positions.append([start, end_pt])
	_crack_seed_generated = true


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var w: float = s
	var h: float = s
	var cx: float = size.x * 0.5 + _hit_offset.x
	var cy: float = size.y * 0.5

	# Ship color by hull percentage — clear visual progression
	var hull_color: Color
	if hull_pct > 0.6:
		hull_color = Color(0.9, 0.55, 0.15)  # bright orange = healthy
	elif hull_pct > 0.3:
		var t: float = (hull_pct - 0.3) / 0.3
		hull_color = Color(0.9, 0.3, 0.15).lerp(Color(0.9, 0.55, 0.15), t)  # orange → yellow-orange
	else:
		var t: float = hull_pct / 0.3
		hull_color = Color(0.35, 0.08, 0.08).lerp(Color(0.9, 0.3, 0.15), t)  # near-black red → red-orange

	# Hit flash overlay: blend toward white
	if _hit_flash > 0.01:
		hull_color = hull_color.lerp(Color(1.0, 0.85, 0.7), _hit_flash * 0.7)

	# Shield bubble
	if shield_pct > 0.0:
		var shield_alpha: float = 0.1 + shield_pct * 0.25
		var shield_color := Color(0.8, 0.3, 0.3, shield_alpha)
		_draw_ellipse(Vector2(cx, cy), w * 0.48, h * 0.46, shield_color)

	# Ship hull polygon
	var body := _get_ship_polygon(cx, cy, w, h)
	draw_colored_polygon(body, hull_color)

	# Outline
	var outline := PackedVector2Array(body)
	outline.append(body[0])
	var outline_col := Color(hull_color.r + 0.2, hull_color.g + 0.1, hull_color.b + 0.1, 0.5)
	draw_polyline(outline, outline_col, 1.5)

	# Damage cracks
	if hull_pct < 0.6:
		var crack_color := Color(0.15, 0.1, 0.05, 0.6 + (1.0 - hull_pct) * 0.4)
		for crack in _crack_positions:
			var start: Vector2 = crack[0]
			var end_pt: Vector2 = crack[1]
			var p1 := Vector2(cx + start.x * w, cy + start.y * h)
			var p2 := Vector2(cx + end_pt.x * w, cy + end_pt.y * h)
			draw_line(p1, p2, crack_color, 1.5)

	# Hit flash glow
	if _hit_flash > 0.05:
		draw_circle(Vector2(cx, cy), w * 0.35, Color(1.0, 0.5, 0.2, _hit_flash * 0.3))


func _get_ship_polygon(cx: float, cy: float, w: float, h: float) -> PackedVector2Array:
	match _ship_type:
		1:  # Freighter — wide boxy
			return PackedVector2Array([
				Vector2(cx, cy - h * 0.3),
				Vector2(cx + w * 0.25, cy - h * 0.2),
				Vector2(cx + w * 0.3, cy),
				Vector2(cx + w * 0.3, cy + h * 0.15),
				Vector2(cx + w * 0.15, cy + h * 0.3),
				Vector2(cx - w * 0.15, cy + h * 0.3),
				Vector2(cx - w * 0.3, cy + h * 0.15),
				Vector2(cx - w * 0.3, cy),
				Vector2(cx - w * 0.25, cy - h * 0.2),
			])
		2:  # Patrol — winged
			return PackedVector2Array([
				Vector2(cx, cy - h * 0.4),
				Vector2(cx + w * 0.1, cy - h * 0.25),
				Vector2(cx + w * 0.35, cy - h * 0.05),
				Vector2(cx + w * 0.25, cy + h * 0.1),
				Vector2(cx + w * 0.12, cy + h * 0.35),
				Vector2(cx - w * 0.12, cy + h * 0.35),
				Vector2(cx - w * 0.25, cy + h * 0.1),
				Vector2(cx - w * 0.35, cy - h * 0.05),
				Vector2(cx - w * 0.1, cy - h * 0.25),
			])
		3:  # Battleship — massive
			return PackedVector2Array([
				Vector2(cx, cy - h * 0.35),
				Vector2(cx + w * 0.2, cy - h * 0.28),
				Vector2(cx + w * 0.35, cy - h * 0.05),
				Vector2(cx + w * 0.32, cy + h * 0.15),
				Vector2(cx + w * 0.18, cy + h * 0.35),
				Vector2(cx - w * 0.18, cy + h * 0.35),
				Vector2(cx - w * 0.32, cy + h * 0.15),
				Vector2(cx - w * 0.35, cy - h * 0.05),
				Vector2(cx - w * 0.2, cy - h * 0.28),
			])
		4:  # Drone — hexagonal
			return PackedVector2Array([
				Vector2(cx, cy - h * 0.38),
				Vector2(cx + w * 0.33, cy - h * 0.19),
				Vector2(cx + w * 0.33, cy + h * 0.19),
				Vector2(cx, cy + h * 0.38),
				Vector2(cx - w * 0.33, cy + h * 0.19),
				Vector2(cx - w * 0.33, cy - h * 0.19),
			])
		5:  # Anomaly — irregular crystal
			return PackedVector2Array([
				Vector2(cx + w * 0.05, cy - h * 0.35),
				Vector2(cx + w * 0.25, cy - h * 0.15),
				Vector2(cx + w * 0.3, cy + h * 0.05),
				Vector2(cx + w * 0.15, cy + h * 0.32),
				Vector2(cx - w * 0.1, cy + h * 0.35),
				Vector2(cx - w * 0.3, cy + h * 0.1),
				Vector2(cx - w * 0.25, cy - h * 0.15),
				Vector2(cx - w * 0.08, cy - h * 0.3),
			])
		6:  # Hunter — sleek needle
			return PackedVector2Array([
				Vector2(cx, cy - h * 0.44),
				Vector2(cx + w * 0.08, cy - h * 0.3),
				Vector2(cx + w * 0.2, cy + h * 0.05),
				Vector2(cx + w * 0.15, cy + h * 0.15),
				Vector2(cx + w * 0.08, cy + h * 0.38),
				Vector2(cx - w * 0.08, cy + h * 0.38),
				Vector2(cx - w * 0.15, cy + h * 0.15),
				Vector2(cx - w * 0.2, cy + h * 0.05),
				Vector2(cx - w * 0.08, cy - h * 0.3),
			])
		_:  # Fighter — default angular
			return PackedVector2Array([
				Vector2(cx, cy - h * 0.42),
				Vector2(cx + w * 0.12, cy - h * 0.25),
				Vector2(cx + w * 0.3, cy + h * 0.1),
				Vector2(cx + w * 0.18, cy + h * 0.15),
				Vector2(cx + w * 0.1, cy + h * 0.35),
				Vector2(cx - w * 0.1, cy + h * 0.35),
				Vector2(cx - w * 0.18, cy + h * 0.15),
				Vector2(cx - w * 0.3, cy + h * 0.1),
				Vector2(cx - w * 0.12, cy - h * 0.25),
			])


func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	var segments: int = 32
	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(center.x + cos(angle) * rx, center.y + sin(angle) * ry))
	draw_colored_polygon(points, color)
