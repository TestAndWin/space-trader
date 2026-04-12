extends Node2D

const TEX_SCOUT = preload("res://assets/sprites/ships/scout.png")
const TEX_FREIGHTER = preload("res://assets/sprites/ships/freighter.png")
const TEX_WARSHIP = preload("res://assets/sprites/ships/warship.png")
const TEX_SMUGGLER = preload("res://assets/sprites/ships/smuggler.png")
const TEX_EXPLORER = preload("res://assets/sprites/ships/explorer.png")

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

	# Scale: unit size that polygons were built around
	var s := 20.0

	# Engine trail glow (at the back = positive y, which rotates to the left during travel)
	var trail_alpha: float = 0.06 + sin(pulse_time * 5.0) * 0.03
	draw_circle(Vector2(0, s * 0.40), s * 0.5, Color(hull_color.r * 0.2, hull_color.g * 0.2, 1.0, trail_alpha))

	# Outer hull glow
	var glow_alpha: float = 0.10 + sin(pulse_time * 3.0) * 0.04
	draw_circle(Vector2.ZERO, s * 0.65, Color(hull_color.r, hull_color.g, hull_color.b, glow_alpha))

	# Engine glow (two thruster points)
	var engine_brightness: float = 0.6 + sin(pulse_time * 8.0) * 0.3
	draw_circle(Vector2(-s * 0.15, s * 0.34), s * 0.05, Color(0.3, 0.6, 1.0, engine_brightness))
	draw_circle(Vector2(s * 0.15, s * 0.34), s * 0.05, Color(0.3, 0.6, 1.0, engine_brightness))

	var tex: Texture2D
	match ship_shape:
		1: tex = TEX_FREIGHTER
		2: tex = TEX_WARSHIP
		3: tex = TEX_SMUGGLER
		4: tex = TEX_EXPLORER
		_: tex = TEX_SCOUT
		
	if tex:
		# The visual size of the previous polygon ships was about 15-18 pixels in diameter (s=20)
		# We'll use a rect of 30x30 pixels.
		var rect_width = s * 1.5
		var rect_height = s * 1.5
		var rect = Rect2(-rect_width / 2.0, -rect_height / 2.0, rect_width, rect_height)
		draw_texture_rect(tex, rect, false, hull_color)
