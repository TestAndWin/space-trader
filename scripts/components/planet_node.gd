extends Area2D

signal planet_clicked(planet_data)
signal planet_hovered(planet_data)
signal planet_unhovered()

var planet_data: Resource = null
var is_current: bool = false
var is_reachable: bool = false
var hover: bool = false
var base_color: Color = Color.WHITE
var pulse_time: float = 0.0

const PLANET_RADIUS: float = 18.0
const GLOW_RADIUS: float = 28.0

const TYPE_COLORS = {
	0: Color(0.35, 0.55, 0.95),  # INDUSTRIAL - blue
	1: Color(0.3, 0.8, 0.35),    # AGRICULTURAL - green
	2: Color(0.8, 0.55, 0.2),    # MINING - orange
	3: Color(0.2, 0.85, 0.95),   # TECH - cyan
	4: Color(0.95, 0.2, 0.2),    # OUTLAW - red
}


func setup(data: Resource) -> void:
	planet_data = data
	$NameLabel.text = data.planet_name
	base_color = TYPE_COLORS.get(data.planet_type, Color.WHITE)
	position = data.map_position
	queue_redraw()


func set_current(value: bool) -> void:
	is_current = value
	queue_redraw()


func set_reachable(value: bool) -> void:
	is_reachable = value
	queue_redraw()


func _process(delta: float) -> void:
	if is_current or is_reachable or hover:
		pulse_time += delta
		queue_redraw()


func _draw() -> void:
	# Dim unreachable planets significantly
	var dim_factor: float = 1.0
	if not is_current and not is_reachable:
		dim_factor = 0.3

	# Outer glow
	var glow_color := base_color
	glow_color.a = 0.08 + sin(pulse_time * 2.0) * 0.03
	if hover:
		glow_color.a = 0.2
	if is_reachable and not is_current:
		glow_color.a = 0.15 + sin(pulse_time * 2.5) * 0.05
	glow_color.a *= dim_factor
	draw_circle(Vector2.ZERO, GLOW_RADIUS + 6.0, glow_color)
	draw_circle(Vector2.ZERO, GLOW_RADIUS, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 1.5))

	# Main planet body
	var body_dark := base_color * 0.7
	body_dark.a = dim_factor
	var body_main := base_color
	body_main.a = dim_factor
	draw_circle(Vector2.ZERO, PLANET_RADIUS, body_dark)
	draw_circle(Vector2.ZERO, PLANET_RADIUS - 1.0, body_main)

	# Highlight (top-left light source for 3D effect)
	draw_circle(Vector2(-4, -4), PLANET_RADIUS * 0.5, Color(1.0, 1.0, 1.0, 0.3 * dim_factor))

	# Dark edge (bottom-right shadow)
	draw_circle(Vector2(3, 3), PLANET_RADIUS * 0.6, Color(0.0, 0.0, 0.0, 0.2 * dim_factor))

	# Ring for current planet
	if is_current:
		var ring_alpha: float = 0.6 + sin(pulse_time * 3.0) * 0.3
		var ring_color := Color(1.0, 0.95, 0.4, ring_alpha)
		_draw_ring(Vector2.ZERO, PLANET_RADIUS + 5.0, 2.5, ring_color)

	# Reachable indicator - bright pulsing ring + outer glow
	if is_reachable and not is_current:
		var pulse_val: float = 0.6 + sin(pulse_time * 2.5) * 0.25
		# Bright white-blue ring
		var reach_color := Color(0.5, 0.85, 1.0, pulse_val)
		_draw_ring(Vector2.ZERO, PLANET_RADIUS + 5.0, 2.0, reach_color)
		# Outer glow ring
		var outer_glow := Color(0.4, 0.7, 1.0, pulse_val * 0.3)
		_draw_ring(Vector2.ZERO, PLANET_RADIUS + 8.0, 3.0, outer_glow)

	# Danger indicator (small red dots for high danger)
	if planet_data and planet_data.danger_level >= 3:
		var danger_color := Color(1.0, 0.2, 0.2, 0.6 + sin(pulse_time * 4.0) * 0.3)
		draw_circle(Vector2(PLANET_RADIUS + 6, -PLANET_RADIUS + 2), 3.0, danger_color)

	# Update name label visibility
	if is_current or is_reachable or hover:
		$NameLabel.modulate.a = 1.0
	else:
		$NameLabel.modulate.a = 0.35


func _draw_ring(center: Vector2, radius: float, width: float, color: Color) -> void:
	var point_count: int = 32
	for i in point_count:
		var angle_from: float = TAU * i / point_count
		var angle_to: float = TAU * (i + 1) / point_count
		var p1 := center + Vector2(cos(angle_from), sin(angle_from)) * radius
		var p2 := center + Vector2(cos(angle_to), sin(angle_to)) * radius
		draw_line(p1, p2, color, width, true)


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		planet_clicked.emit(planet_data)


func _on_mouse_entered() -> void:
	hover = true
	scale = Vector2(1.12, 1.12)
	planet_hovered.emit(planet_data)


func _on_mouse_exited() -> void:
	hover = false
	scale = Vector2(1.0, 1.0)
	planet_unhovered.emit()
