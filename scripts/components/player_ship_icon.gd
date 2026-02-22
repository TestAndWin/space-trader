extends Node2D

var pulse_time: float = 0.0
const SHIP_COLOR := Color(1.0, 0.95, 0.4)
const GLOW_COLOR := Color(1.0, 0.95, 0.4, 0.15)
const TRAIL_COLOR := Color(1.0, 0.8, 0.2, 0.08)


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()


func _draw() -> void:
	# Engine trail glow
	var trail_alpha: float = 0.06 + sin(pulse_time * 5.0) * 0.03
	draw_circle(Vector2(0, 12), 10.0, Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, trail_alpha))

	# Outer glow
	var glow_alpha: float = 0.12 + sin(pulse_time * 3.0) * 0.05
	draw_circle(Vector2.ZERO, 14.0, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, glow_alpha))

	# Ship body (triangle pointing up)
	var body_points := PackedVector2Array([
		Vector2(0, -10),   # nose
		Vector2(-7, 8),    # left wing
		Vector2(0, 4),     # center notch
		Vector2(7, 8),     # right wing
	])
	var body_color := SHIP_COLOR * 0.9
	body_color.a = 1.0
	draw_colored_polygon(body_points, body_color)

	# Highlight stripe
	var highlight_points := PackedVector2Array([
		Vector2(0, -8),
		Vector2(-3, 4),
		Vector2(0, 2),
		Vector2(3, 4),
	])
	draw_colored_polygon(highlight_points, Color(1.0, 1.0, 0.8, 0.5))

	# Engine glow (small circle at back)
	var engine_brightness: float = 0.6 + sin(pulse_time * 8.0) * 0.3
	draw_circle(Vector2(-3, 7), 2.0, Color(0.3, 0.6, 1.0, engine_brightness))
	draw_circle(Vector2(3, 7), 2.0, Color(0.3, 0.6, 1.0, engine_brightness))
