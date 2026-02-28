extends Control

## Calm animated background for the battle result screen.
## Toned-down version: starfield, soft nebulae, floating dust. No ships or lasers.

var _time: float = 0.0
var _stars: Array = []
var _nebulae: Array = []
var _dust: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_stars()
	_init_nebulae()
	_init_dust()


func _init_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 160:
		var roll: float = rng.randf()
		var star_size: float
		if roll < 0.5:
			star_size = 1.0
		elif roll < 0.8:
			star_size = 1.5
		else:
			star_size = 2.5

		var brightness: float = rng.randf_range(0.3, 1.0)
		var star_r: float = brightness
		var star_g: float = brightness
		var star_b: float = brightness
		if rng.randf() < 0.2:
			var warmth: float = rng.randf_range(-0.1, 0.1)
			star_r = clampf(brightness + warmth, 0.0, 1.0)
			star_b = clampf(brightness - warmth, 0.0, 1.0)

		_stars.append({
			"pos": Vector2(rng.randf_range(0.0, 1280.0), rng.randf_range(0.0, 720.0)),
			"size": star_size,
			"r": star_r,
			"g": star_g,
			"b": star_b,
			"brightness": brightness,
			"twinkle": rng.randf_range(0.0, TAU),
			"twinkle_speed": rng.randf_range(0.3, 1.2),
			"does_twinkle": i >= 135,
		})


func _init_nebulae() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 64
	# Determine tint from battle result
	var base_r: float = 0.2
	var base_g: float = 0.15
	var base_b: float = 0.4
	var result := GameManager.battle_result
	if result == "won":
		base_r = 0.1
		base_g = 0.3
		base_b = 0.35
	elif result == "lost":
		base_r = 0.4
		base_g = 0.08
		base_b = 0.15
	elif result == "fled":
		base_r = 0.35
		base_g = 0.3
		base_b = 0.1

	for i in 5:
		var pos := Vector2(rng.randf_range(80.0, 1200.0), rng.randf_range(80.0, 640.0))
		var radius: float = rng.randf_range(150.0, 350.0)
		var opacity: float = rng.randf_range(0.03, 0.08)
		var shift: float = rng.randf_range(-0.06, 0.06)
		_nebulae.append({
			"pos": pos,
			"radius": radius,
			"color": Color(
				clampf(base_r + shift, 0.0, 1.0),
				clampf(base_g + shift * 0.5, 0.0, 1.0),
				clampf(base_b - shift, 0.0, 1.0),
				opacity
			),
			"pulse_phase": rng.randf_range(0.0, TAU),
			"pulse_speed": rng.randf_range(0.2, 0.5),
		})


func _init_dust() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	for i in 18:
		_dust.append({
			"pos": Vector2(rng.randf_range(0.0, 1280.0), rng.randf_range(0.0, 720.0)),
			"speed": rng.randf_range(5.0, 15.0),
			"wave_amp": rng.randf_range(0.2, 0.8),
			"wave_freq": rng.randf_range(0.3, 1.0),
			"wave_phase": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(0.5, 1.2),
			"brightness": rng.randf_range(0.12, 0.28),
		})


func _process(delta: float) -> void:
	_time += delta
	for dust in _dust:
		dust["pos"].x -= dust["speed"] * delta
		dust["pos"].y += sin(_time * dust["wave_freq"] + dust["wave_phase"]) * dust["wave_amp"] * delta * 8.0
		if dust["pos"].x < -10.0:
			dust["pos"].x = 1290.0
	queue_redraw()


func _draw() -> void:
	# Nebulae behind stars
	for neb in _nebulae:
		var pulse: float = (sin(_time * neb["pulse_speed"] + neb["pulse_phase"]) + 1.0) * 0.5
		var r: float = neb["radius"] * (1.0 + pulse * 0.04)
		var col: Color = neb["color"]
		draw_circle(neb["pos"], r * 1.3, Color(col.r, col.g, col.b, col.a * 0.4))
		draw_circle(neb["pos"], r, col)

	# Stars
	for s in _stars:
		var brt: float = s["brightness"]
		var r: float = s["r"]
		var g: float = s["g"]
		var b: float = s["b"]
		var sz: float = s["size"]

		if s["does_twinkle"]:
			var pulse: float = (sin(_time * s["twinkle_speed"] + float(s["twinkle"])) + 1.0) * 0.5
			var alpha: float = lerpf(0.3, 1.0, pulse)
			var cur_sz: float = sz * lerpf(0.6, 1.0, pulse)
			draw_circle(s["pos"], cur_sz * 2.5, Color(r, g, b, alpha * 0.12))
			draw_circle(s["pos"], cur_sz, Color(r, g, b, alpha))
		else:
			if sz <= 1.0:
				draw_rect(Rect2(s["pos"] - Vector2(1, 1), Vector2(2, 2)), Color(r, g, b, brt))
			else:
				draw_circle(s["pos"], sz, Color(r, g, b, brt))

	# Dust
	for dust in _dust:
		draw_circle(dust["pos"], dust["size"], Color(0.55, 0.6, 0.7, dust["brightness"]))
