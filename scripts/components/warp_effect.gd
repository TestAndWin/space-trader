extends Control

## Procedural warp tunnel drawn behind the hyperspace starfield.
## Radial streaks fly outward from center; concentric rings expand.
## Call setup(color) after adding to the scene to set the accent color.

var accent_color: Color = Color(0.25, 0.6, 0.85)
var _time: float = 0.0

const STREAK_COUNT := 56

# Precomputed per-streak data: [angle, speed, phase_offset]
var _streak_data: Array = []


func setup(p_color: Color) -> void:
	accent_color = p_color


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_precompute_streaks()


func _precompute_streaks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	for i in STREAK_COUNT:
		_streak_data.append([
			float(i) / float(STREAK_COUNT) * TAU + rng.randf_range(-0.06, 0.06),
			rng.randf_range(0.25, 0.8),
			rng.randf_range(0.0, 1.0),
		])


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var center := Vector2(w * 0.5, h * 0.5)
	var max_r := Vector2(w * 0.5, h * 0.5).length()

	# Radial streak lines flying outward from center
	for data in _streak_data:
		var angle: float = data[0]
		var speed: float = data[1]
		var offset: float = data[2]
		var progress := fmod(_time * speed + offset, 1.0)

		var inner_r := progress * max_r * 0.5
		var outer_r := minf(inner_r + max_r * 0.22, max_r * 1.05)

		var p_start := center + Vector2(cos(angle), sin(angle)) * inner_r
		var p_end := center + Vector2(cos(angle), sin(angle)) * outer_r

		# Brightest at mid-progress, fades at start and end
		var fade := sin(progress * PI)
		var alpha := fade * 0.22
		draw_line(p_start, p_end, Color(accent_color.r, accent_color.g, accent_color.b, alpha), 1.2)

	# Concentric rings expanding outward
	for r in 4:
		var ring_progress := fmod(_time * 0.45 + float(r) * 0.25, 1.0)
		var ring_r := ring_progress * max_r * 0.9
		var ring_alpha := (1.0 - ring_progress) * 0.18
		if ring_alpha > 0.005:
			draw_arc(center, ring_r, 0.0, TAU, 64,
				Color(accent_color.r, accent_color.g, accent_color.b, ring_alpha), 1.2)

	# Soft pulsing center glow
	var glow_pulse := (sin(_time * 2.5) + 1.0) * 0.5
	var glow_r := lerpf(22.0, 38.0, glow_pulse)
	draw_circle(center, glow_r, Color(accent_color.r, accent_color.g, accent_color.b, 0.07))
	draw_circle(center, 9.0, Color(1.0, 1.0, 1.0, 0.05))
