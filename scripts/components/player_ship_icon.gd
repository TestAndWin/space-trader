extends Node2D

var pulse_time: float = 0.0


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var ship: Resource = GameManager.get_ship_data()
	var ship_shape: int = 0
	var hull_color := Color(0.3, 0.85, 0.3)
	if ship:
		ship_shape = ship.hull_shape
		hull_color = ship.hull_color_primary

	# Scale: unit size that polygons are built around
	var s := 20.0

	var body := _get_ship_polygon(ship_shape, s)

	# Engine trail glow (at the back = positive y, which rotates to the left during travel)
	var trail_alpha: float = 0.06 + sin(pulse_time * 5.0) * 0.03
	draw_circle(Vector2(0, s * 0.36), s * 0.5, Color(hull_color.r * 0.2, hull_color.g * 0.2, 1.0, trail_alpha))

	# Outer hull glow
	var glow_alpha: float = 0.10 + sin(pulse_time * 3.0) * 0.04
	draw_circle(Vector2.ZERO, s * 0.65, Color(hull_color.r, hull_color.g, hull_color.b, glow_alpha))

	# Ship body
	draw_colored_polygon(body, hull_color)

	# Cockpit highlight
	var cockpit := PackedVector2Array([
		Vector2(0, -s * 0.35),
		Vector2(s * 0.06, -s * 0.18),
		Vector2(0, -s * 0.1),
		Vector2(-s * 0.06, -s * 0.18),
	])
	var cockpit_color := Color(
		minf(hull_color.r + 0.3, 1.0),
		minf(hull_color.g + 0.3, 1.0),
		minf(hull_color.b + 0.4, 1.0),
		0.8
	)
	draw_colored_polygon(cockpit, cockpit_color)

	# Engine glow (two thruster points)
	var engine_brightness: float = 0.6 + sin(pulse_time * 8.0) * 0.3
	draw_circle(Vector2(-s * 0.06, s * 0.34), s * 0.04, Color(0.3, 0.6, 1.0, engine_brightness))
	draw_circle(Vector2(s * 0.06, s * 0.34), s * 0.04, Color(0.3, 0.6, 1.0, engine_brightness))


func _get_ship_polygon(shape: int, s: float) -> PackedVector2Array:
	match shape:
		1:  # Freighter — wide, boxy
			return PackedVector2Array([
				Vector2(0, -s * 0.32),
				Vector2(s * 0.2, -s * 0.25),
				Vector2(s * 0.28, -s * 0.05),
				Vector2(s * 0.28, s * 0.2),
				Vector2(s * 0.15, s * 0.35),
				Vector2(-s * 0.15, s * 0.35),
				Vector2(-s * 0.28, s * 0.2),
				Vector2(-s * 0.28, -s * 0.05),
				Vector2(-s * 0.2, -s * 0.25),
			])
		2:  # Warship — angular, aggressive
			return PackedVector2Array([
				Vector2(0, -s * 0.44),
				Vector2(s * 0.08, -s * 0.3),
				Vector2(s * 0.35, 0.0),
				Vector2(s * 0.3, s * 0.15),
				Vector2(s * 0.15, s * 0.2),
				Vector2(s * 0.12, s * 0.38),
				Vector2(-s * 0.12, s * 0.38),
				Vector2(-s * 0.15, s * 0.2),
				Vector2(-s * 0.3, s * 0.15),
				Vector2(-s * 0.35, 0.0),
				Vector2(-s * 0.08, -s * 0.3),
			])
		3:  # Smuggler — slim, fast
			return PackedVector2Array([
				Vector2(0, -s * 0.45),
				Vector2(s * 0.08, -s * 0.3),
				Vector2(s * 0.18, 0.0),
				Vector2(s * 0.22, s * 0.15),
				Vector2(s * 0.12, s * 0.35),
				Vector2(-s * 0.12, s * 0.35),
				Vector2(-s * 0.22, s * 0.15),
				Vector2(-s * 0.18, 0.0),
				Vector2(-s * 0.08, -s * 0.3),
			])
		4:  # Explorer — rounded
			return PackedVector2Array([
				Vector2(0, -s * 0.38),
				Vector2(s * 0.15, -s * 0.28),
				Vector2(s * 0.25, -s * 0.1),
				Vector2(s * 0.25, s * 0.1),
				Vector2(s * 0.18, s * 0.25),
				Vector2(s * 0.1, s * 0.35),
				Vector2(-s * 0.1, s * 0.35),
				Vector2(-s * 0.18, s * 0.25),
				Vector2(-s * 0.25, s * 0.1),
				Vector2(-s * 0.25, -s * 0.1),
				Vector2(-s * 0.15, -s * 0.28),
			])
		_:  # Scout (default)
			return PackedVector2Array([
				Vector2(0, -s * 0.42),
				Vector2(s * 0.12, -s * 0.25),
				Vector2(s * 0.32, s * 0.1),
				Vector2(s * 0.18, s * 0.15),
				Vector2(s * 0.1, s * 0.35),
				Vector2(-s * 0.1, s * 0.35),
				Vector2(-s * 0.18, s * 0.15),
				Vector2(-s * 0.32, s * 0.1),
				Vector2(-s * 0.12, -s * 0.25),
			])
