extends Control

## Animated battle background — starfield, ship silhouettes, laser bolts, debris.
## Placed behind all UI panels in card_battle.tscn.

var _time: float = 0.0

var _stars: Array = []
var _bolts: Array = []
var _debris: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_stars()
	_init_bolts()
	_init_debris()


func _init_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 150:
		_stars.append({
			"pos": Vector2(rng.randf_range(0.0, 1280.0), rng.randf_range(0.0, 720.0)),
			"size": rng.randf_range(0.5, 2.0),
			"brightness": rng.randf_range(0.1, 0.65),
			"twinkle": rng.randf_range(0.0, TAU),
			"does_twinkle": i >= 120,
		})


func _init_bolts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 4:
		_bolts.append({
			"y": rng.randf_range(80.0, 490.0),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.7, 1.6),
			"width": rng.randf_range(1.0, 2.5),
			"is_player": i < 2,
		})


func _init_debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 10:
		_debris.append({
			"pos": Vector2(rng.randf_range(50.0, 1230.0), rng.randf_range(50.0, 670.0)),
			"vel": Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-10.0, 10.0)),
			"angle": rng.randf_range(0.0, TAU),
			"spin": rng.randf_range(-0.8, 0.8),
			"size": rng.randf_range(3.0, 9.0),
			"shape": i % 3,
		})


func _process(delta: float) -> void:
	_time += delta
	for d in _debris:
		d["pos"] += d["vel"] * delta
		d["angle"] += d["spin"] * delta
		if d["pos"].x < -20.0:
			d["pos"].x = 1300.0
		elif d["pos"].x > 1300.0:
			d["pos"].x = -20.0
		if d["pos"].y < -20.0:
			d["pos"].y = 740.0
		elif d["pos"].y > 740.0:
			d["pos"].y = -20.0
	queue_redraw()


func _draw() -> void:
	_draw_atmosphere()
	_draw_stars()
	_draw_ship_silhouettes()
	_draw_glows()
	_draw_bolts()
	_draw_debris()


func _draw_atmosphere() -> void:
	# Left half: faint cyan tint (player/hologram side)
	draw_rect(Rect2(0, 0, 640, 720), Color(0.0, 0.04, 0.12, 0.14))
	# Right half: faint red tint (enemy threat side)
	draw_rect(Rect2(640, 0, 640, 720), Color(0.14, 0.02, 0.02, 0.14))


func _draw_stars() -> void:
	for s in _stars:
		var brt: float = s["brightness"]
		if s["does_twinkle"]:
			brt = lerpf(brt * 0.3, brt * 1.6, (sin(_time * 1.8 + float(s["twinkle"])) + 1.0) * 0.5)
		draw_circle(s["pos"], s["size"], Color(brt, brt, minf(brt * 1.15, 1.0), brt))


func _draw_ship_silhouettes() -> void:
	# Player ship (left, pointing right) — faint cyan ghost
	var p_fill := Color(0.0, 0.45, 0.8, 0.09)
	var p_line := Color(0.0, 0.65, 1.0, 0.20)
	var player_pts := PackedVector2Array([
		Vector2(315, 390), Vector2(240, 356), Vector2(178, 330),
		Vector2(152, 355), Vector2(160, 390), Vector2(152, 425),
		Vector2(178, 450), Vector2(240, 424),
	])
	draw_polygon(player_pts, PackedColorArray([
		p_fill, p_fill, p_fill, p_fill, p_fill, p_fill, p_fill, p_fill,
	]))
	var player_closed := PackedVector2Array(player_pts)
	player_closed.append(player_pts[0])
	draw_polyline(player_closed, p_line, 1.5)
	# Engine thruster glow
	var engine_r: float = 8.0 + sin(_time * 3.0) * 2.5
	draw_circle(Vector2(157, 390), engine_r, Color(0.0, 0.7, 1.0, 0.28))
	draw_circle(Vector2(157, 390), engine_r * 0.45, Color(0.6, 0.95, 1.0, 0.55))

	# Enemy ship (right, pointing left) — faint red ghost
	var e_fill := Color(0.65, 0.1, 0.05, 0.09)
	var e_line := Color(0.9, 0.25, 0.1, 0.20)
	var enemy_pts := PackedVector2Array([
		Vector2(960, 270), Vector2(842, 218), Vector2(768, 198),
		Vector2(752, 270), Vector2(768, 342), Vector2(842, 322),
	])
	draw_polygon(enemy_pts, PackedColorArray([
		e_fill, e_fill, e_fill, e_fill, e_fill, e_fill,
	]))
	var enemy_closed := PackedVector2Array(enemy_pts)
	enemy_closed.append(enemy_pts[0])
	draw_polyline(enemy_closed, e_line, 1.5)
	# Enemy engine glow
	var e_engine_r: float = 10.0 + sin(_time * 2.5 + 1.0) * 3.0
	draw_circle(Vector2(755, 270), e_engine_r, Color(1.0, 0.4, 0.1, 0.24))
	draw_circle(Vector2(755, 270), e_engine_r * 0.40, Color(1.0, 0.8, 0.4, 0.50))


func _draw_glows() -> void:
	# Player ambient glow (left-center)
	var p_pulse: float = (sin(_time * 1.1) + 1.0) * 0.5
	draw_circle(Vector2(235, 390), 195.0 + p_pulse * 18.0, Color(0.0, 0.35, 0.8, 0.035))
	draw_circle(Vector2(235, 390), 115.0, Color(0.0, 0.6, 1.0, 0.045))
	draw_circle(Vector2(235, 390), 58.0, Color(0.0, 0.78, 1.0, 0.060))

	# Enemy threat glow (right-center, more aggressive pulse)
	var e_pulse: float = (sin(_time * 2.2 + 1.0) + 1.0) * 0.5
	draw_circle(Vector2(860, 270), 240.0 + e_pulse * 35.0, Color(0.9, 0.1, 0.05, 0.035 + e_pulse * 0.018))
	draw_circle(Vector2(860, 270), 150.0, Color(1.0, 0.2, 0.1, 0.055 + e_pulse * 0.025))
	draw_circle(Vector2(860, 270), 76.0, Color(1.0, 0.3, 0.15, 0.075 + e_pulse * 0.035))


func _draw_bolts() -> void:
	for bolt in _bolts:
		var phase: float = float(bolt["phase"]) + _time * float(bolt["speed"])
		if sin(phase) <= 0.3:
			continue
		var alpha: float = (sin(phase) - 0.3) / 0.7
		var y: float = float(bolt["y"])
		var col: Color
		var x_from: float
		var x_to: float

		if bolt["is_player"]:
			col = Color(0.0, 0.85, 1.0)
			x_from = lerpf(160.0, 310.0, (sin(_time * 0.4 + float(bolt["phase"])) + 1.0) * 0.5)
			x_to = lerpf(810.0, 1000.0, (sin(_time * 0.5 + float(bolt["phase"]) + 0.8) + 1.0) * 0.5)
		else:
			col = Color(1.0, 0.35, 0.1)
			x_from = lerpf(960.0, 1100.0, (sin(_time * 0.4 + float(bolt["phase"])) + 1.0) * 0.5)
			x_to = lerpf(190.0, 430.0, (sin(_time * 0.5 + float(bolt["phase"]) + 0.8) + 1.0) * 0.5)

		var w: float = float(bolt["width"])
		var from_pt := Vector2(x_from, y)
		var to_pt := Vector2(x_to, y)

		# Outer glow → mid glow → bright core
		draw_line(from_pt, to_pt, Color(col.r, col.g, col.b, alpha * 0.09), w * 8.0)
		draw_line(from_pt, to_pt, Color(col.r, col.g, col.b, alpha * 0.28), w * 3.0)
		draw_line(from_pt, to_pt, Color(minf(col.r * 1.5, 1.0), minf(col.g * 1.5, 1.0), minf(col.b * 1.5, 1.0), alpha * 0.85), w)

		# Impact flash at endpoint
		var flash_r: float = alpha * 14.0
		draw_circle(to_pt, flash_r, Color(col.r, col.g, col.b, alpha * 0.22))
		draw_circle(to_pt, flash_r * 0.35, Color(1.0, 1.0, 1.0, alpha * 0.55))


func _draw_debris() -> void:
	var col := Color(0.42, 0.47, 0.56, 0.42)
	for d in _debris:
		var s: float = float(d["size"])
		var a: float = float(d["angle"])
		var p: Vector2 = d["pos"]
		match int(d["shape"]):
			0:  # triangle shard
				var p1 := p + Vector2(cos(a), sin(a)) * s
				var p2 := p + Vector2(cos(a + TAU / 3.0), sin(a + TAU / 3.0)) * s
				var p3 := p + Vector2(cos(a + 2.0 * TAU / 3.0), sin(a + 2.0 * TAU / 3.0)) * s
				draw_line(p1, p2, col, 1.0)
				draw_line(p2, p3, col, 1.0)
				draw_line(p3, p1, col, 1.0)
			1:  # rectangle shard
				var hs := Vector2(s * 0.5, s * 0.3)
				var corners := PackedVector2Array([
					p + Vector2(-hs.x, -hs.y).rotated(a),
					p + Vector2(hs.x, -hs.y).rotated(a),
					p + Vector2(hs.x, hs.y).rotated(a),
					p + Vector2(-hs.x, hs.y).rotated(a),
					p + Vector2(-hs.x, -hs.y).rotated(a),
				])
				draw_polyline(corners, col, 1.0)
			2:  # line shard
				var p1 := p + Vector2(cos(a), sin(a)) * s * 2.0
				var p2 := p - Vector2(cos(a), sin(a)) * s * 2.0
				draw_line(p1, p2, col, 1.5)
