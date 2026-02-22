extends Control

## Procedural planet background drawn entirely via _draw().
## Call setup(planet_type) to configure the planet type (0-4) and trigger a redraw.

var planet_type: int = 0

const BASE_COLORS = {
	0: Color(0.4, 0.45, 0.55),   # INDUSTRIAL - steel grey/blue
	1: Color(0.25, 0.6, 0.35),   # AGRICULTURAL - green/blue
	2: Color(0.6, 0.4, 0.2),     # MINING - brown/orange
	3: Color(0.2, 0.5, 0.7),     # TECH - cyan/metallic
	4: Color(0.5, 0.15, 0.15),   # OUTLAW - dark red/crimson
}

const ATMOSPHERE_COLORS = {
	0: Color(0.5, 0.55, 0.7, 0.12),
	1: Color(0.3, 0.7, 0.4, 0.14),
	2: Color(0.7, 0.5, 0.25, 0.1),
	3: Color(0.25, 0.6, 0.85, 0.15),
	4: Color(0.6, 0.1, 0.1, 0.1),
}

# Band color offsets per type: positive = lighter, negative = darker
const BAND_OFFSETS = {
	0: 0.08,
	1: 0.1,
	2: -0.08,
	3: 0.12,
	4: -0.06,
}

const HAS_MOON = {
	0: false,
	1: true,
	2: false,
	3: true,
	4: false,
}


func setup(p_planet_type: int) -> void:
	planet_type = clampi(p_planet_type, 0, 4)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.4
	var base_color: Color = BASE_COLORS.get(planet_type, BASE_COLORS[0])
	var atmo_color: Color = ATMOSPHERE_COLORS.get(planet_type, ATMOSPHERE_COLORS[0])
	var band_offset: float = BAND_OFFSETS.get(planet_type, 0.08)

	# --- 1. Atmosphere glow ---
	var atmo_radius := radius * 1.35
	# Two layers for soft glow
	draw_circle(center, atmo_radius, Color(atmo_color.r, atmo_color.g, atmo_color.b, atmo_color.a * 0.5))
	draw_circle(center, atmo_radius * 0.85, atmo_color)

	# --- 2. Planet body ---
	# Dark rim first, then main body slightly smaller for an edge effect
	var rim_color := base_color * 0.6
	rim_color.a = 1.0
	draw_circle(center, radius, rim_color)
	draw_circle(center, radius - 1.5, base_color)

	# --- 3. Surface bands ---
	_draw_bands(center, radius, base_color, band_offset)

	# --- 4. Highlight arc (upper-left light reflection) ---
	_draw_highlight(center, radius)

	# --- 5. Shadow on lower-right for depth ---
	_draw_shadow(center, radius)

	# --- 6. Optional moon ---
	if HAS_MOON.get(planet_type, false):
		_draw_moon(center, radius)


func _draw_bands(center: Vector2, radius: float, base_color: Color, offset: float) -> void:
	# Use deterministic seed based on planet_type for band positions
	var rng := RandomNumberGenerator.new()
	rng.seed = 42 + planet_type * 137

	var band_count: int = 3 + (planet_type % 3)  # 3-5 bands depending on type

	for i in band_count:
		# Band vertical position: spread across the planet face
		var t: float = rng.randf_range(0.15, 0.85)
		var band_y: float = center.y - radius + (radius * 2.0 * t)

		# Band thickness
		var thickness: float = rng.randf_range(radius * 0.04, radius * 0.1)

		# Band color: shift from base
		var band_color := Color(
			clampf(base_color.r + offset * rng.randf_range(0.5, 1.5), 0.0, 1.0),
			clampf(base_color.g + offset * rng.randf_range(0.5, 1.5), 0.0, 1.0),
			clampf(base_color.b + offset * rng.randf_range(0.3, 1.0), 0.0, 1.0),
			0.55
		)

		# Compute horizontal extent at this y position (circle clipping)
		var dy := absf(band_y - center.y)
		if dy >= radius:
			continue
		var half_width := sqrt(radius * radius - dy * dy)

		# Draw band as a series of short horizontal lines for a curved look
		var segments: int = 16
		for s in segments:
			var frac: float = float(s) / float(segments)
			var frac_next: float = float(s + 1) / float(segments)
			var x1: float = center.x - half_width + frac * half_width * 2.0
			var x2: float = center.x - half_width + frac_next * half_width * 2.0
			# Slight vertical wave for organic feel
			var wave: float = sin(frac * PI * 2.0 + float(i)) * thickness * 0.3
			draw_line(
				Vector2(x1, band_y + wave),
				Vector2(x2, band_y + wave),
				band_color,
				thickness,
				true
			)


func _draw_highlight(center: Vector2, radius: float) -> void:
	# Bright arc on upper-left for light reflection
	var highlight_center := center + Vector2(-radius * 0.3, -radius * 0.3)
	var highlight_radius := radius * 0.55
	var highlight_color := Color(1.0, 1.0, 1.0, 0.18)
	draw_circle(highlight_center, highlight_radius, highlight_color)

	# Sharper small specular highlight
	var spec_center := center + Vector2(-radius * 0.35, -radius * 0.4)
	draw_circle(spec_center, radius * 0.15, Color(1.0, 1.0, 1.0, 0.25))


func _draw_shadow(center: Vector2, radius: float) -> void:
	# Darken lower-right quadrant for depth
	var shadow_center := center + Vector2(radius * 0.25, radius * 0.25)
	draw_circle(shadow_center, radius * 0.7, Color(0.0, 0.0, 0.0, 0.2))


func _draw_moon(center: Vector2, radius: float) -> void:
	var moon_offset := Vector2(radius * 0.9, -radius * 0.75)
	var moon_center := center + moon_offset
	var moon_radius := radius * 0.12
	var moon_color: Color

	if planet_type == 1:
		moon_color = Color(0.75, 0.75, 0.7)  # Grey-ish moon for agricultural
	else:
		moon_color = Color(0.6, 0.7, 0.8)  # Blue-grey for tech

	# Moon glow
	draw_circle(moon_center, moon_radius * 1.6, Color(moon_color.r, moon_color.g, moon_color.b, 0.1))
	# Moon body
	draw_circle(moon_center, moon_radius, moon_color)
	# Moon highlight
	draw_circle(moon_center + Vector2(-moon_radius * 0.25, -moon_radius * 0.25), moon_radius * 0.4, Color(1.0, 1.0, 1.0, 0.3))
