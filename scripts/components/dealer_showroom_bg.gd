extends Control

## Procedural showroom background for the Ship Dealer.
## Creates a premium auto-dealer atmosphere with starfield,
## floor grid, spotlights, and floating ambient particles.

var _time: float = 0.0
var _stars: Array = []         # [position, radius, color]
var _particles: Array = []     # [position, speed, radius, color, phase]
var _spotlight_positions: Array = []  # x positions for spotlights

const FLOOR_Y_RATIO := 0.72   # Where the floor starts (% of height)
const GRID_COLOR := Color(0.0, 0.55, 0.85, 0.12)
const GRID_COLOR_BRIGHT := Color(0.0, 0.65, 0.95, 0.22)
const SPOTLIGHT_COLOR := Color(0.15, 0.35, 0.65, 0.06)
const AMBIENT_BASE := Color(0.01, 0.025, 0.06)
const SIDE_GLOW := Color(0.0, 0.45, 0.80, 0.04)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_generate()


func _generate() -> void:
	_stars.clear()
	_particles.clear()
	_spotlight_positions.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = 42424242

	var area := size
	if area.x < 1.0 or area.y < 1.0:
		area = Vector2(1280, 720)

	# Stars — concentrated in the upper portion (above the floor)
	var star_count: int = 120
	for i in star_count:
		var pos := Vector2(rng.randf() * area.x, rng.randf() * area.y * FLOOR_Y_RATIO)
		var roll: float = rng.randf()
		var radius: float
		if roll < 0.5:
			radius = 0.8
		elif roll < 0.8:
			radius = 1.3
		else:
			radius = 2.0
		var brightness: float = rng.randf_range(0.3, 0.9)
		var warmth: float = rng.randf_range(-0.06, 0.06)
		var star_color := Color(
			clampf(brightness + warmth, 0.0, 1.0),
			brightness,
			clampf(brightness - warmth + 0.05, 0.0, 1.0),
			1.0
		)
		_stars.append([pos, radius, star_color])

	# Floating ambient particles
	var particle_count: int = 35
	for i in particle_count:
		var pos := Vector2(rng.randf() * area.x, rng.randf() * area.y)
		var speed := Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-15.0, -3.0))
		var radius: float = rng.randf_range(0.8, 2.5)
		var brightness: float = rng.randf_range(0.3, 0.8)
		var col := Color(
			brightness * 0.6,
			brightness * 0.8,
			brightness * 1.0,
			rng.randf_range(0.15, 0.45)
		)
		var phase: float = rng.randf() * TAU
		_particles.append([pos, speed, radius, col, phase])

	# 3 main spotlights
	_spotlight_positions = [area.x * 0.25, area.x * 0.5, area.x * 0.75]


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 1.0 or h < 1.0:
		return
	var floor_y: float = h * FLOOR_Y_RATIO

	# 1. Dark background with subtle gradient
	draw_rect(Rect2(Vector2.ZERO, size), AMBIENT_BASE)
	# Subtle vignette — darker at edges
	var vignette_left := Color(0.0, 0.0, 0.0, 0.3)
	var vignette_mid := Color(0.0, 0.0, 0.0, 0.0)
	draw_rect(Rect2(0, 0, w * 0.15, h), vignette_left)
	draw_rect(Rect2(w * 0.85, 0, w * 0.15, h), vignette_left)

	# 2. Nebula clouds (large, very soft)
	var neb_positions: Array = [
		[Vector2(w * 0.2, h * 0.25), 180.0, Color(0.05, 0.1, 0.25, 0.08)],
		[Vector2(w * 0.7, h * 0.15), 220.0, Color(0.02, 0.08, 0.2, 0.06)],
		[Vector2(w * 0.5, h * 0.4), 150.0, Color(0.08, 0.05, 0.18, 0.05)],
	]
	for neb in neb_positions:
		draw_circle(neb[0], neb[1], neb[2])

	# 3. Stars
	for star in _stars:
		var pos: Vector2 = star[0]
		var radius: float = star[1]
		var col: Color = star[2]
		if radius <= 1.0:
			draw_rect(Rect2(pos - Vector2(1, 1), Vector2(2, 2)), col)
		else:
			draw_circle(pos, radius, col)

	# 4. Spotlights from ceiling
	for sx in _spotlight_positions:
		# Cone shape: narrow at top, wide at floor
		var top_width: float = 20.0
		var bottom_width: float = 160.0
		var cone_top_y: float = 0.0
		var cone_bottom_y: float = floor_y + 40.0
		# Draw as layered transparent triangles for soft falloff
		for layer in 5:
			var alpha_mult: float = 1.0 - float(layer) / 5.0
			var expand: float = float(layer) * 15.0
			var points := PackedVector2Array([
				Vector2(sx - top_width * 0.5 - expand * 0.2, cone_top_y),
				Vector2(sx + top_width * 0.5 + expand * 0.2, cone_top_y),
				Vector2(sx + bottom_width * 0.5 + expand, cone_bottom_y),
				Vector2(sx - bottom_width * 0.5 - expand, cone_bottom_y),
			])
			var col := Color(SPOTLIGHT_COLOR.r, SPOTLIGHT_COLOR.g, SPOTLIGHT_COLOR.b, SPOTLIGHT_COLOR.a * alpha_mult)
			draw_colored_polygon(points, col)
		# Bright core line at center
		draw_line(Vector2(sx, 0), Vector2(sx, floor_y), Color(0.2, 0.5, 0.9, 0.03), 2.0)

	# 5. Floor — reflective grid
	# Floor base (dark reflective surface)
	var floor_color := Color(0.015, 0.03, 0.06, 0.95)
	draw_rect(Rect2(0, floor_y, w, h - floor_y), floor_color)
	# Gradient fade at floor edge
	for i in 8:
		var fade_y: float = floor_y - 8.0 + float(i)
		var fade_alpha: float = float(i) / 8.0 * 0.5
		draw_line(Vector2(0, fade_y), Vector2(w, fade_y), Color(0.01, 0.025, 0.06, fade_alpha), 1.0)

	# Floor grid lines — horizontal (perspective spacing)
	var grid_lines: int = 12
	for i in grid_lines:
		var t: float = float(i) / float(grid_lines)
		# Perspective: lines get closer together further away
		var y: float = floor_y + (h - floor_y) * (t * t)
		var alpha: float = lerpf(0.06, 0.18, t)
		var col := Color(GRID_COLOR.r, GRID_COLOR.g, GRID_COLOR.b, alpha)
		draw_line(Vector2(0, y), Vector2(w, y), col, 1.0)

	# Floor grid lines — vertical (converging to vanishing point)
	var vanish_x: float = w * 0.5
	var vanish_y: float = floor_y - 10.0
	var vert_count: int = 16
	for i in vert_count:
		var bottom_x: float = float(i) / float(vert_count - 1) * w
		var alpha: float = 0.08 + 0.06 * (1.0 - absf(bottom_x - vanish_x) / (w * 0.5))
		var col := Color(GRID_COLOR.r, GRID_COLOR.g, GRID_COLOR.b, alpha)
		draw_line(Vector2(vanish_x, vanish_y), Vector2(bottom_x, h), col, 1.0)

	# Spotlight reflections on floor
	for sx in _spotlight_positions:
		var ref_radius: float = 80.0
		var ref_col := Color(0.05, 0.15, 0.35, 0.08)
		draw_circle(Vector2(sx, floor_y + 20.0), ref_radius, ref_col)
		# Brighter center spot
		draw_circle(Vector2(sx, floor_y + 10.0), 30.0, Color(0.1, 0.25, 0.5, 0.06))

	# Pulsing accent line at floor edge
	var pulse: float = (sin(_time * 1.5) + 1.0) * 0.5
	var line_alpha: float = lerpf(0.1, 0.25, pulse)
	draw_line(Vector2(0, floor_y), Vector2(w, floor_y), Color(0.0, 0.6, 0.95, line_alpha), 2.0)

	# 6. Side glow strips
	var strip_width: float = 3.0
	var glow_pulse: float = (sin(_time * 0.8 + 1.0) + 1.0) * 0.5
	var strip_alpha: float = lerpf(0.04, 0.12, glow_pulse)
	var strip_col := Color(SIDE_GLOW.r, SIDE_GLOW.g, SIDE_GLOW.b, strip_alpha)
	# Left strip
	draw_rect(Rect2(8, 40, strip_width, floor_y - 80), strip_col)
	# Right strip
	draw_rect(Rect2(w - 11, 40, strip_width, floor_y - 80), strip_col)
	# Outer glow around strips
	var glow_col := Color(0.0, 0.4, 0.8, strip_alpha * 0.3)
	draw_rect(Rect2(4, 40, strip_width + 8, floor_y - 80), glow_col)
	draw_rect(Rect2(w - 15, 40, strip_width + 8, floor_y - 80), glow_col)

	# 7. Floating particles
	for particle in _particles:
		var base_pos: Vector2 = particle[0]
		var spd: Vector2 = particle[1]
		var radius: float = particle[2]
		var col: Color = particle[3]
		var phase: float = particle[4]
		# Animate position
		var offset := Vector2(
			sin(_time * 0.3 + phase) * 20.0 + spd.x * sin(_time * 0.1 + phase),
			sin(_time * 0.5 + phase * 1.3) * 15.0
		)
		var pos := base_pos + offset
		# Wrap around
		pos.x = fmod(pos.x + w, w)
		pos.y = fmod(pos.y + h, h)
		# Pulse alpha
		var pulse_val: float = (sin(_time * 0.7 + phase) + 1.0) * 0.5
		var final_alpha: float = col.a * lerpf(0.4, 1.0, pulse_val)
		var final_col := Color(col.r, col.g, col.b, final_alpha)
		# Glow + core
		draw_circle(pos, radius * 2.5, Color(final_col.r, final_col.g, final_col.b, final_alpha * 0.2))
		draw_circle(pos, radius, final_col)

	# 8. Top decorative bar — thin neon line
	draw_line(Vector2(w * 0.1, 4), Vector2(w * 0.9, 4), Color(0.0, 0.5, 0.85, 0.15), 1.5)
	draw_line(Vector2(w * 0.2, 6), Vector2(w * 0.8, 6), Color(0.0, 0.4, 0.75, 0.08), 1.0)
