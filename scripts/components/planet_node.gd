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
	# All planets animate continuously for a living galaxy map
	pulse_time += delta
	queue_redraw()


func _draw() -> void:
	# Dim unreachable planets significantly
	var dim_factor: float = 1.0
	if not is_current and not is_reachable:
		dim_factor = 0.3

	# --- Current planet: strong pulsing aura ---
	if is_current:
		var aura_pulse: float = (sin(pulse_time * 1.8) + 1.0) * 0.5
		# Large outer aura
		draw_circle(Vector2.ZERO, GLOW_RADIUS + 18.0 + aura_pulse * 6.0,
			Color(1.0, 0.92, 0.3, 0.04 + aura_pulse * 0.03))
		# Mid aura
		draw_circle(Vector2.ZERO, GLOW_RADIUS + 10.0 + aura_pulse * 3.0,
			Color(1.0, 0.9, 0.35, 0.07 + aura_pulse * 0.04))

	# Outer glow — all planets pulse subtly
	var glow_color := base_color
	glow_color.a = 0.06 + sin(pulse_time * 1.5) * 0.025
	if hover:
		glow_color.a = 0.2
	if is_current:
		glow_color.a = 0.18 + sin(pulse_time * 2.0) * 0.06
	elif is_reachable:
		glow_color.a = 0.15 + sin(pulse_time * 2.5) * 0.05
	glow_color.a *= dim_factor
	draw_circle(Vector2.ZERO, GLOW_RADIUS + 6.0, glow_color)
	draw_circle(Vector2.ZERO, GLOW_RADIUS, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 1.5))

	# Main planet body — breathing radius
	var breath: float = sin(pulse_time * 1.2) * 0.8
	var body_r: float = PLANET_RADIUS + breath
	var body_dark := base_color * 0.7
	body_dark.a = dim_factor
	var body_main := base_color
	body_main.a = dim_factor
	draw_circle(Vector2.ZERO, body_r, body_dark)
	draw_circle(Vector2.ZERO, body_r - 1.0, body_main)

	# Surface bands — horizontal stripes that shift slowly
	var band_shift: float = pulse_time * 0.6
	for b in 5:
		var band_y: float = -body_r * 0.7 + float(b) * body_r * 0.35 + sin(band_shift + float(b)) * 1.5
		var band_half_w: float = sqrt(maxf(body_r * body_r - band_y * band_y, 0.0)) * 0.95
		if band_half_w > 2.0:
			var band_col: Color
			if b % 2 == 0:
				band_col = base_color.darkened(0.25)
			else:
				band_col = base_color.lightened(0.12)
			band_col.a = 0.18 * dim_factor
			draw_line(Vector2(-band_half_w, band_y), Vector2(band_half_w, band_y), band_col, 2.5)

	# Atmosphere rim — faint colored edge
	var atmo_col := base_color.lightened(0.3)
	atmo_col.a = 0.12 * dim_factor
	_draw_ring(Vector2.ZERO, body_r + 1.0, 1.5, atmo_col)

	# Rotating highlight — slowly orbiting specular spot for 3D illusion
	var hl_angle: float = pulse_time * 0.35
	var hl_orbit: float = PLANET_RADIUS * 0.28
	var hl_pos := Vector2(cos(hl_angle) * hl_orbit - 2.0, sin(hl_angle) * hl_orbit - 2.0)
	draw_circle(hl_pos, PLANET_RADIUS * 0.45, Color(1.0, 1.0, 1.0, 0.25 * dim_factor))
	# Smaller bright core of highlight
	draw_circle(hl_pos * 0.7, PLANET_RADIUS * 0.22, Color(1.0, 1.0, 1.0, 0.15 * dim_factor))

	# Dark edge (bottom-right shadow) — counter-rotates slightly
	var sh_angle: float = PI + pulse_time * 0.15
	var sh_pos := Vector2(cos(sh_angle) * 3.0 + 3.0, sin(sh_angle) * 2.0 + 3.0)
	draw_circle(sh_pos, PLANET_RADIUS * 0.6, Color(0.0, 0.0, 0.0, 0.2 * dim_factor))

	# Ring for current planet
	if is_current:
		var ring_alpha: float = 0.6 + sin(pulse_time * 3.0) * 0.3
		var ring_color := Color(1.0, 0.95, 0.4, ring_alpha)
		_draw_ring(Vector2.ZERO, body_r + 5.0, 2.5, ring_color)
		# Second subtle outer ring
		var ring2_alpha: float = 0.25 + sin(pulse_time * 2.0 + 1.0) * 0.15
		_draw_ring(Vector2.ZERO, body_r + 9.0, 1.5, Color(1.0, 0.9, 0.5, ring2_alpha))

	# Reachable indicator - bright pulsing ring + outer glow
	if is_reachable and not is_current:
		var pulse_val: float = 0.6 + sin(pulse_time * 2.5) * 0.25
		# Bright white-blue ring
		var reach_color := Color(0.5, 0.85, 1.0, pulse_val)
		_draw_ring(Vector2.ZERO, body_r + 5.0, 2.0, reach_color)
		# Outer glow ring
		var outer_glow := Color(0.4, 0.7, 1.0, pulse_val * 0.3)
		_draw_ring(Vector2.ZERO, body_r + 8.0, 3.0, outer_glow)

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
