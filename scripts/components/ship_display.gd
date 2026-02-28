extends Control

var hull_pct: float = 1.0
var shield_pct: float = 0.0
var cargo_used: int = 0
var cargo_max: int = 10
var ship_shape: int = 0
var crack_positions: Array = []
var crack_seed_generated: bool = false

# Hit animation state
var _hit_offset: Vector2 = Vector2.ZERO
var _hit_flash_color: Color = Color.TRANSPARENT
var _hit_flash: float = 0.0


func play_shield_hit() -> void:
	_hit_flash_color = Color(0.3, 0.6, 1.0)  # blue
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_hit_offset_x, 0.0, 3.0, 0.04)
	tween.tween_method(_set_hit_offset_x, 3.0, -2.0, 0.05).set_delay(0.04)
	tween.tween_method(_set_hit_offset_x, -2.0, 1.0, 0.04).set_delay(0.09)
	tween.tween_method(_set_hit_offset_x, 1.0, 0.0, 0.05).set_delay(0.13)
	tween.tween_method(_set_hit_flash, 0.0, 0.8, 0.05)
	tween.tween_method(_set_hit_flash, 0.8, 0.0, 0.30).set_delay(0.05)


func play_hull_hit() -> void:
	_hit_flash_color = Color(1.0, 0.3, 0.2)  # red
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_hit_offset_x, 0.0, 5.0, 0.03)
	tween.tween_method(_set_hit_offset_x, 5.0, -5.0, 0.05).set_delay(0.03)
	tween.tween_method(_set_hit_offset_x, -5.0, 4.0, 0.04).set_delay(0.08)
	tween.tween_method(_set_hit_offset_x, 4.0, -3.0, 0.04).set_delay(0.12)
	tween.tween_method(_set_hit_offset_x, -3.0, 0.0, 0.06).set_delay(0.16)
	tween.tween_method(_set_hit_flash, 0.0, 1.0, 0.04)
	tween.tween_method(_set_hit_flash, 1.0, 0.0, 0.35).set_delay(0.04)


func _set_hit_offset_x(val: float) -> void:
	_hit_offset.x = val
	queue_redraw()


func _set_hit_flash(val: float) -> void:
	_hit_flash = val
	queue_redraw()


func update_ship(p_hull_pct: float, p_shield_pct: float, p_cargo_used: int, p_cargo_max: int, p_ship_shape: int = -1) -> void:
	hull_pct = clampf(p_hull_pct, 0.0, 1.0)
	shield_pct = clampf(p_shield_pct, 0.0, 1.0)
	cargo_used = p_cargo_used
	cargo_max = p_cargo_max
	if p_ship_shape >= 0:
		ship_shape = p_ship_shape
	if hull_pct < 0.6 and not crack_seed_generated:
		_generate_cracks()
	elif hull_pct >= 0.6:
		crack_positions.clear()
		crack_seed_generated = false
	queue_redraw()


func _generate_cracks() -> void:
	crack_positions.clear()
	var count: int = int((1.0 - hull_pct) * 8) + 1
	for i in count:
		var start := Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		var end := start + Vector2(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
		crack_positions.append([start, end])
	crack_seed_generated = true


func _get_hull_polygon(cx: float, cy: float, w: float, h: float) -> PackedVector2Array:
	match ship_shape:
		1:  # Freighter — wide, boxy
			return PackedVector2Array([
				Vector2(cx, cy - h * 0.32),
				Vector2(cx + w * 0.2, cy - h * 0.25),
				Vector2(cx + w * 0.28, cy - h * 0.05),
				Vector2(cx + w * 0.28, cy + h * 0.2),
				Vector2(cx + w * 0.15, cy + h * 0.35),
				Vector2(cx - w * 0.15, cy + h * 0.35),
				Vector2(cx - w * 0.28, cy + h * 0.2),
				Vector2(cx - w * 0.28, cy - h * 0.05),
				Vector2(cx - w * 0.2, cy - h * 0.25),
			])
		2:  # Warship — angular, aggressive
			return PackedVector2Array([
				Vector2(cx, cy - h * 0.44),
				Vector2(cx + w * 0.08, cy - h * 0.3),
				Vector2(cx + w * 0.35, cy + h * 0.0),
				Vector2(cx + w * 0.3, cy + h * 0.15),
				Vector2(cx + w * 0.15, cy + h * 0.2),
				Vector2(cx + w * 0.12, cy + h * 0.38),
				Vector2(cx - w * 0.12, cy + h * 0.38),
				Vector2(cx - w * 0.15, cy + h * 0.2),
				Vector2(cx - w * 0.3, cy + h * 0.15),
				Vector2(cx - w * 0.35, cy + h * 0.0),
				Vector2(cx - w * 0.08, cy - h * 0.3),
			])
		3:  # Smuggler — slim, fast
			return PackedVector2Array([
				Vector2(cx, cy - h * 0.45),
				Vector2(cx + w * 0.08, cy - h * 0.3),
				Vector2(cx + w * 0.18, cy + h * 0.0),
				Vector2(cx + w * 0.22, cy + h * 0.15),
				Vector2(cx + w * 0.12, cy + h * 0.35),
				Vector2(cx - w * 0.12, cy + h * 0.35),
				Vector2(cx - w * 0.22, cy + h * 0.15),
				Vector2(cx - w * 0.18, cy + h * 0.0),
				Vector2(cx - w * 0.08, cy - h * 0.3),
			])
		4:  # Explorer — rounded
			return PackedVector2Array([
				Vector2(cx, cy - h * 0.38),
				Vector2(cx + w * 0.15, cy - h * 0.28),
				Vector2(cx + w * 0.25, cy - h * 0.1),
				Vector2(cx + w * 0.25, cy + h * 0.1),
				Vector2(cx + w * 0.18, cy + h * 0.25),
				Vector2(cx + w * 0.1, cy + h * 0.35),
				Vector2(cx - w * 0.1, cy + h * 0.35),
				Vector2(cx - w * 0.18, cy + h * 0.25),
				Vector2(cx - w * 0.25, cy + h * 0.1),
				Vector2(cx - w * 0.25, cy - h * 0.1),
				Vector2(cx - w * 0.15, cy - h * 0.28),
			])
		_:  # Scout (default) — original shape
			return PackedVector2Array([
				Vector2(cx, cy - h * 0.42),
				Vector2(cx + w * 0.12, cy - h * 0.25),
				Vector2(cx + w * 0.32, cy + h * 0.1),
				Vector2(cx + w * 0.18, cy + h * 0.15),
				Vector2(cx + w * 0.1, cy + h * 0.35),
				Vector2(cx - w * 0.1, cy + h * 0.35),
				Vector2(cx - w * 0.18, cy + h * 0.15),
				Vector2(cx - w * 0.32, cy + h * 0.1),
				Vector2(cx - w * 0.12, cy - h * 0.25),
			])


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var w: float = s
	var h: float = s
	var cx: float = size.x * 0.5 + _hit_offset.x
	var cy: float = size.y * 0.5

	# 1. Shield bubble
	if shield_pct > 0.0:
		var shield_alpha: float = 0.1 + shield_pct * 0.25
		var shield_col := Color(0.3, 0.5, 1.0, shield_alpha)
		# Shield flash on hit
		if _hit_flash > 0.01 and _hit_flash_color.b > 0.5:
			shield_col = shield_col.lerp(Color(0.5, 0.8, 1.0, 0.7), _hit_flash * 0.6)
		var shield_rx: float = w * 0.48
		var shield_ry: float = h * 0.46
		_draw_ellipse(Vector2(cx, cy), shield_rx, shield_ry, shield_col)

	# 2. Ship hull polygon
	var hull_color: Color
	if hull_pct > 0.6:
		hull_color = Color(0.3, 0.85, 0.3)
	elif hull_pct > 0.3:
		var t: float = (hull_pct - 0.3) / 0.3
		hull_color = Color(0.9, 0.85, 0.2).lerp(Color(0.3, 0.85, 0.3), t)
	else:
		var t: float = hull_pct / 0.3
		hull_color = Color(0.9, 0.2, 0.2).lerp(Color(0.9, 0.85, 0.2), t)

	# Hit flash overlay
	if _hit_flash > 0.01:
		hull_color = hull_color.lerp(_hit_flash_color, _hit_flash * 0.5)

	var body := _get_hull_polygon(cx, cy, w, h)
	draw_colored_polygon(body, hull_color)

	# 3. Cockpit
	var cockpit := PackedVector2Array([
		Vector2(cx, cy - h * 0.35),
		Vector2(cx + w * 0.06, cy - h * 0.18),
		Vector2(cx, cy - h * 0.1),
		Vector2(cx - w * 0.06, cy - h * 0.18),
	])
	var cockpit_color := Color(hull_color.r + 0.3, hull_color.g + 0.3, hull_color.b + 0.4, 0.8)
	draw_colored_polygon(cockpit, cockpit_color)

	# 4. Engine glow
	var engine_color := Color(1.0, 0.7, 0.2, 0.9)
	draw_circle(Vector2(cx - w * 0.06, cy + h * 0.34), w * 0.04, engine_color)
	draw_circle(Vector2(cx + w * 0.06, cy + h * 0.34), w * 0.04, engine_color)

	# 5. Damage cracks
	if hull_pct < 0.6:
		var crack_color := Color(0.15, 0.1, 0.05, 0.6 + (1.0 - hull_pct) * 0.4)
		for crack in crack_positions:
			var start: Vector2 = crack[0]
			var end: Vector2 = crack[1]
			var p1 := Vector2(cx + start.x * w, cy + start.y * h)
			var p2 := Vector2(cx + end.x * w, cy + end.y * h)
			draw_line(p1, p2, crack_color, 1.5)

	# 6. Cargo indicators
	if cargo_max > 0:
		var max_dots: int = mini(cargo_max, 8)
		var filled: int = ceili(float(cargo_used) / float(cargo_max) * max_dots)
		var dot_size := Vector2(w * 0.06, h * 0.04)
		var start_x: float = cx - (max_dots * dot_size.x + (max_dots - 1) * 2.0) * 0.5
		var dot_y: float = cy + h * 0.1
		for i in max_dots:
			var rect := Rect2(start_x + i * (dot_size.x + 2.0), dot_y, dot_size.x, dot_size.y)
			if i < filled:
				draw_rect(rect, Color(1.0, 0.85, 0.3, 0.8))
			else:
				draw_rect(rect, Color(0.3, 0.3, 0.4, 0.3))


func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	var segments: int = 32
	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(center.x + cos(angle) * rx, center.y + sin(angle) * ry))
	draw_colored_polygon(points, color)
