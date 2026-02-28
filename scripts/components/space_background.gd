extends Control

## Procedural space background with stars, nebulae, and twinkling effects.
## Colors adapt to the current planet type and danger level.
## Call setup(planet_type, danger_level) to configure.

var planet_type: int = 0
var danger_level: int = 1
var _time: float = 0.0

var _static_stars: Array = []
var _twinkle_stars: Array = []  # [position, radius, base_color, speed, phase]
var _nebulae: Array = []  # [position, radius, color]

const ATMOSPHERE_COLORS = {
	0: Color(0.5, 0.55, 0.7),    # INDUSTRIAL - steel blue
	1: Color(0.3, 0.7, 0.4),     # AGRICULTURAL - green
	2: Color(0.7, 0.5, 0.25),    # MINING - orange/brown
	3: Color(0.25, 0.6, 0.85),   # TECH - cyan
	4: Color(0.6, 0.1, 0.1),     # OUTLAW - dark red
}


func setup(p_planet_type: int, p_danger_level: int = 1) -> void:
	planet_type = clampi(p_planet_type, 0, 4)
	danger_level = clampi(p_danger_level, 1, 5)
	_generate_stars()
	queue_redraw()


func _generate_stars() -> void:
	_static_stars.clear()
	_twinkle_stars.clear()
	_nebulae.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + planet_type * 7919

	var area_size := size
	if area_size.x < 1.0 or area_size.y < 1.0:
		area_size = Vector2(1280, 720)

	var atmo_color: Color = ATMOSPHERE_COLORS.get(planet_type, ATMOSPHERE_COLORS[0])
	var danger_factor: float = clampf((danger_level - 1) / 4.0, 0.0, 1.0)
	var danger_red_shift: float = danger_factor * 0.15

	# --- Nebulae: 4-6 large clouds, layered for depth ---
	var nebula_count: int = rng.randi_range(6, 8)
	for i in nebula_count:
		var pos := Vector2(rng.randf() * area_size.x, rng.randf() * area_size.y)
		var radius: float = rng.randf_range(120.0, 320.0)
		var opacity: float = rng.randf_range(0.06, 0.14)
		opacity *= lerpf(1.0, 0.7, danger_factor)
		var neb_color := Color(
			clampf(atmo_color.r + danger_red_shift, 0.0, 1.0),
			atmo_color.g * lerpf(1.0, 0.7, danger_red_shift),
			atmo_color.b * lerpf(1.0, 0.7, danger_red_shift),
			opacity
		)
		_nebulae.append([pos, radius, neb_color])
	# Add a second layer of smaller, brighter nebula patches
	for i in 3:
		var pos := Vector2(rng.randf() * area_size.x, rng.randf() * area_size.y)
		var radius: float = rng.randf_range(60.0, 140.0)
		var opacity: float = rng.randf_range(0.08, 0.18)
		opacity *= lerpf(1.0, 0.7, danger_factor)
		var neb_color := Color(
			clampf(atmo_color.r * 1.2 + danger_red_shift, 0.0, 1.0),
			clampf(atmo_color.g * 1.1, 0.0, 1.0),
			clampf(atmo_color.b * 1.1, 0.0, 1.0),
			opacity
		)
		_nebulae.append([pos, radius, neb_color])

	# --- Static stars (~150) ---
	var star_count: int = 150

	for i in star_count:
		var pos := Vector2(rng.randf() * area_size.x, rng.randf() * area_size.y)
		var roll: float = rng.randf()
		var radius: float
		if roll < 0.5:
			radius = 1.0   # small dot
		elif roll < 0.8:
			radius = 1.5   # medium
		else:
			radius = 2.5   # large, clearly visible

		var brightness: float = rng.randf_range(0.4, 1.0)
		var star_color: Color
		# 25% of stars tinted by planet color
		if rng.randf() < 0.25:
			star_color = Color(
				lerpf(brightness, atmo_color.r * 1.3, 0.35),
				lerpf(brightness, atmo_color.g * 1.3, 0.35),
				lerpf(brightness, atmo_color.b * 1.3, 0.35),
				1.0
			)
		else:
			# Slight warm/cool color variation for natural look
			var warmth: float = rng.randf_range(-0.08, 0.08)
			star_color = Color(
				clampf(brightness + warmth, 0.0, 1.0),
				brightness,
				clampf(brightness - warmth, 0.0, 1.0),
				1.0
			)
		_static_stars.append([pos, radius, star_color])

	# --- Twinkle stars (20-28 animated, clearly visible) ---
	var twinkle_count: int = rng.randi_range(20, 28)
	for i in twinkle_count:
		var pos := Vector2(rng.randf() * area_size.x, rng.randf() * area_size.y)
		var radius: float = rng.randf_range(1.5, 3.5)
		var brightness: float = rng.randf_range(0.6, 1.0)
		var star_color: Color
		if rng.randf() < 0.4:
			star_color = Color(
				lerpf(brightness, atmo_color.r * 1.4, 0.4),
				lerpf(brightness, atmo_color.g * 1.4, 0.4),
				lerpf(brightness, atmo_color.b * 1.4, 0.4),
				1.0
			)
		else:
			star_color = Color(brightness, brightness, brightness * 1.05, 1.0)
		var speed: float = rng.randf_range(0.5, 1.5)
		var phase: float = rng.randf() * TAU
		_twinkle_stars.append([pos, radius, star_color, speed, phase])


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Dark space background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.05, 1.0))

	# Nebulae (drawn first, behind stars)
	for neb in _nebulae:
		draw_circle(neb[0], neb[1], neb[2])

	# Static stars
	for star in _static_stars:
		var pos: Vector2 = star[0]
		var radius: float = star[1]
		var col: Color = star[2]
		if radius <= 1.0:
			# Small stars: 2x2 pixel rect for visibility
			draw_rect(Rect2(pos - Vector2(1, 1), Vector2(2, 2)), col)
		else:
			draw_circle(pos, radius, col)

	# Twinkle stars with glow
	for star in _twinkle_stars:
		var pos: Vector2 = star[0]
		var radius: float = star[1]
		var base_color: Color = star[2]
		var speed: float = star[3]
		var phase: float = star[4]
		var pulse: float = (sin(_time * speed + phase) + 1.0) * 0.5  # 0..1
		var alpha: float = lerpf(0.3, 1.0, pulse)
		var cur_radius: float = radius * lerpf(0.6, 1.0, pulse)
		# Outer glow
		var glow_col := Color(base_color.r, base_color.g, base_color.b, alpha * 0.15)
		draw_circle(pos, cur_radius * 3.0, glow_col)
		# Core
		var core_col := Color(base_color.r, base_color.g, base_color.b, alpha)
		draw_circle(pos, cur_radius, core_col)

