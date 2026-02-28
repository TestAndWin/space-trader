extends Control

## Animated battle background — starfield with glow, nebula clouds, ship silhouettes,
## laser bolts, debris, floating dust, and subtle scanline overlay.
## Placed behind all UI panels in card_battle.tscn.

var _time: float = 0.0

var _stars: Array = []
var _bolts: Array = []
var _debris: Array = []
var _nebulae: Array = []
var _dust: Array = []

# Enemy silhouette type — determined from encounter name in _ready().
# 0=fighter, 1=freighter, 2=patrol, 3=battleship, 4=drone, 5=anomaly, 6=hunter
var _enemy_silhouette: int = 0
var _enemy_glow_center: Vector2 = Vector2(860, 270)
var _enemy_is_anomaly: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_enemy_silhouette()
	_init_stars()
	_init_nebulae()
	_init_bolts()
	_init_debris()
	_init_dust()


func _init_enemy_silhouette() -> void:
	var enc: Resource = GameManager.current_encounter
	if enc == null:
		return
	match enc.encounter_name:
		"Wandering Trader":
			_enemy_silhouette = 1
			_enemy_glow_center = Vector2(862, 270)
		"System Patrol", "Smuggler Ambush":
			_enemy_silhouette = 2
			_enemy_glow_center = Vector2(848, 270)
		"Pirate Captain":
			_enemy_silhouette = 3
			_enemy_glow_center = Vector2(872, 270)
		"Rogue AI":
			_enemy_silhouette = 4
			_enemy_glow_center = Vector2(860, 270)
		"Space Anomaly":
			_enemy_silhouette = 5
			_enemy_glow_center = Vector2(878, 268)
			_enemy_is_anomaly = true
		"Bounty Hunter":
			_enemy_silhouette = 6
			_enemy_glow_center = Vector2(873, 270)
		_:  # Pirate Raider and any unknown encounter
			_enemy_silhouette = 0
			_enemy_glow_center = Vector2(856, 270)


func _init_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 200:
		var roll: float = rng.randf()
		var star_size: float
		if roll < 0.5:
			star_size = 1.0        # small dot
		elif roll < 0.8:
			star_size = 1.5        # medium
		else:
			star_size = 2.5        # large, clearly visible

		var brightness: float = rng.randf_range(0.3, 1.0)

		# 25% of stars get warm/cool color variation
		var star_r: float = brightness
		var star_g: float = brightness
		var star_b: float = brightness
		if rng.randf() < 0.25:
			var warmth: float = rng.randf_range(-0.12, 0.12)
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
			"twinkle_speed": rng.randf_range(0.5, 1.8),
			"does_twinkle": i >= 160,  # last 40 stars twinkle
		})


func _init_nebulae() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Choose nebula tint based on enemy type
	var base_r: float = 0.6
	var base_g: float = 0.1
	var base_b: float = 0.15
	if _enemy_is_anomaly:
		base_r = 0.4
		base_g = 0.05
		base_b = 0.7
	elif _enemy_silhouette == 2:  # patrol
		base_r = 0.15
		base_g = 0.2
		base_b = 0.5
	elif _enemy_silhouette == 4:  # drone
		base_r = 0.35
		base_g = 0.15
		base_b = 0.45

	# Main nebula clouds
	for i in 6:
		var pos := Vector2(rng.randf_range(50.0, 1230.0), rng.randf_range(50.0, 670.0))
		var radius: float = rng.randf_range(130.0, 320.0)
		var opacity: float = rng.randf_range(0.04, 0.10)
		var color_shift: float = rng.randf_range(-0.08, 0.08)
		_nebulae.append({
			"pos": pos,
			"radius": radius,
			"color": Color(
				clampf(base_r + color_shift, 0.0, 1.0),
				clampf(base_g + color_shift * 0.5, 0.0, 1.0),
				clampf(base_b - color_shift, 0.0, 1.0),
				opacity
			),
			"pulse_phase": rng.randf_range(0.0, TAU),
			"pulse_speed": rng.randf_range(0.3, 0.7),
		})
	# Smaller bright patches
	for i in 3:
		var pos := Vector2(rng.randf_range(100.0, 1180.0), rng.randf_range(100.0, 620.0))
		var radius: float = rng.randf_range(60.0, 140.0)
		var opacity: float = rng.randf_range(0.06, 0.14)
		_nebulae.append({
			"pos": pos,
			"radius": radius,
			"color": Color(
				clampf(base_r * 1.2, 0.0, 1.0),
				clampf(base_g * 1.1, 0.0, 1.0),
				clampf(base_b * 1.1, 0.0, 1.0),
				opacity
			),
			"pulse_phase": rng.randf_range(0.0, TAU),
			"pulse_speed": rng.randf_range(0.4, 0.9),
		})


func _init_bolts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 6:
		# Slight color variation per bolt
		var hue_shift: float = rng.randf_range(-0.06, 0.06)
		_bolts.append({
			"y": rng.randf_range(80.0, 490.0),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.7, 1.6),
			"width": rng.randf_range(1.0, 2.5),
			"is_player": i < 3,
			"hue_shift": hue_shift,
		})


func _init_debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 15:
		# Color variation: some reddish (damaged), some bluish (shield fragments)
		var color_type: int = i % 4  # 0=neutral, 1=reddish, 2=bluish, 3=neutral
		var col: Color
		match color_type:
			1:
				col = Color(0.55, 0.35, 0.32, 0.45)  # reddish damaged metal
			2:
				col = Color(0.35, 0.42, 0.62, 0.45)  # bluish shield fragment
			_:
				col = Color(0.42, 0.47, 0.56, 0.42)  # neutral
		_debris.append({
			"pos": Vector2(rng.randf_range(50.0, 1230.0), rng.randf_range(50.0, 670.0)),
			"vel": Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-10.0, 10.0)),
			"angle": rng.randf_range(0.0, TAU),
			"spin": rng.randf_range(-0.8, 0.8),
			"size": rng.randf_range(3.0, 9.0),
			"shape": i % 3,
			"color": col,
			"glint_phase": rng.randf_range(0.0, TAU),
			"glint_speed": rng.randf_range(2.0, 5.0),
		})


func _init_dust() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in 28:
		_dust.append({
			"pos": Vector2(rng.randf_range(0.0, 1280.0), rng.randf_range(0.0, 720.0)),
			"speed": rng.randf_range(8.0, 25.0),
			"wave_amp": rng.randf_range(0.3, 1.2),
			"wave_freq": rng.randf_range(0.5, 1.5),
			"wave_phase": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(0.5, 1.5),
			"brightness": rng.randf_range(0.15, 0.35),
		})


func _process(delta: float) -> void:
	_time += delta
	# Update debris positions
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
	# Update dust positions (drift right to left)
	for dust in _dust:
		dust["pos"].x -= dust["speed"] * delta
		dust["pos"].y += sin(_time * dust["wave_freq"] + dust["wave_phase"]) * dust["wave_amp"] * delta * 10.0
		if dust["pos"].x < -10.0:
			dust["pos"].x = 1290.0
	queue_redraw()


func _draw() -> void:
	_draw_atmosphere()
	_draw_nebulae()
	_draw_stars()
	_draw_dust()
	_draw_ship_silhouettes()
	_draw_glows()
	_draw_bolts()
	_draw_debris()
	_draw_scanlines()


func _draw_atmosphere() -> void:
	# Multi-layer gradient for depth instead of flat rects
	# Left half: cyan player side — 3 layers fading toward center
	draw_rect(Rect2(0, 0, 640, 720), Color(0.0, 0.04, 0.12, 0.16))
	draw_rect(Rect2(0, 0, 480, 720), Color(0.0, 0.05, 0.14, 0.08))
	draw_rect(Rect2(0, 0, 320, 720), Color(0.0, 0.06, 0.16, 0.06))
	# Right half: red enemy side — 3 layers fading toward center
	draw_rect(Rect2(640, 0, 640, 720), Color(0.14, 0.02, 0.02, 0.16))
	draw_rect(Rect2(800, 0, 480, 720), Color(0.16, 0.02, 0.02, 0.08))
	draw_rect(Rect2(960, 0, 320, 720), Color(0.18, 0.02, 0.02, 0.06))
	# Center battle zone divider — subtle bright strip
	var divider_pulse: float = (sin(_time * 0.8) + 1.0) * 0.5
	draw_rect(Rect2(632, 0, 16, 720), Color(0.3, 0.15, 0.3, 0.03 + divider_pulse * 0.02))


func _draw_nebulae() -> void:
	for neb in _nebulae:
		var pulse: float = (sin(_time * neb["pulse_speed"] + neb["pulse_phase"]) + 1.0) * 0.5
		var r: float = neb["radius"] * (1.0 + pulse * 0.05)  # ±5% breathing
		var col: Color = neb["color"]
		# Outer diffuse layer
		draw_circle(neb["pos"], r * 1.3, Color(col.r, col.g, col.b, col.a * 0.4))
		# Main cloud
		draw_circle(neb["pos"], r, col)
		# Inner brighter core
		draw_circle(neb["pos"], r * 0.5, Color(col.r, col.g, col.b, col.a * 1.4))


func _draw_stars() -> void:
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
			# Outer glow halo
			draw_circle(s["pos"], cur_sz * 3.0, Color(r, g, b, alpha * 0.15))
			# Core
			draw_circle(s["pos"], cur_sz, Color(r, g, b, alpha))
		else:
			if sz <= 1.0:
				# Small stars: 2x2 pixel rect for visibility
				draw_rect(Rect2(s["pos"] - Vector2(1, 1), Vector2(2, 2)), Color(r, g, b, brt))
			else:
				draw_circle(s["pos"], sz, Color(r, g, b, brt))


func _draw_dust() -> void:
	for dust in _dust:
		var col := Color(0.6, 0.65, 0.75, dust["brightness"])
		draw_circle(dust["pos"], dust["size"], col)


func _draw_ship_silhouettes() -> void:
	_draw_player_ship()
	_draw_enemy_ship()


func _draw_player_ship() -> void:
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


func _draw_enemy_ship() -> void:
	match _enemy_silhouette:
		0: _draw_enemy_fighter()
		1: _draw_enemy_freighter()
		2: _draw_enemy_patrol()
		3: _draw_enemy_battleship()
		4: _draw_enemy_drone()
		5: _draw_enemy_anomaly()
		6: _draw_enemy_hunter()


# Small, nimble pirate vessel — original hexagonal shape.
func _draw_enemy_fighter() -> void:
	var e_fill := Color(0.65, 0.1, 0.05, 0.09)
	var e_line := Color(0.9, 0.25, 0.1, 0.20)
	var pts := PackedVector2Array([
		Vector2(960, 270), Vector2(842, 218), Vector2(768, 198),
		Vector2(752, 270), Vector2(768, 342), Vector2(842, 322),
	])
	_draw_enemy_polygon(pts, e_fill, e_line)
	var r: float = 10.0 + sin(_time * 2.5 + 1.0) * 3.0
	draw_circle(Vector2(755, 270), r, Color(1.0, 0.4, 0.1, 0.24))
	draw_circle(Vector2(755, 270), r * 0.40, Color(1.0, 0.8, 0.4, 0.50))


# Wide, heavy cargo freighter — fat octagonal hull with cargo bay markings.
func _draw_enemy_freighter() -> void:
	var e_fill := Color(0.65, 0.1, 0.05, 0.09)
	var e_line := Color(0.9, 0.25, 0.1, 0.20)
	var pts := PackedVector2Array([
		Vector2(1000, 270), Vector2(962, 228), Vector2(858, 207),
		Vector2(742, 228), Vector2(725, 270), Vector2(742, 312),
		Vector2(858, 333), Vector2(962, 312),
	])
	_draw_enemy_polygon(pts, e_fill, e_line)
	# Cargo bay detail lines on upper and lower hull
	var bay_top := PackedVector2Array([
		Vector2(920, 226), Vector2(848, 215), Vector2(845, 230), Vector2(918, 240), Vector2(920, 226),
	])
	draw_polyline(bay_top, Color(0.9, 0.25, 0.1, 0.12), 1.0)
	var bay_bot := PackedVector2Array([
		Vector2(920, 314), Vector2(918, 300), Vector2(845, 310), Vector2(848, 325), Vector2(920, 314),
	])
	draw_polyline(bay_bot, Color(0.9, 0.25, 0.1, 0.12), 1.0)
	var r: float = 10.0 + sin(_time * 2.5 + 1.0) * 3.0
	draw_circle(Vector2(730, 270), r, Color(1.0, 0.4, 0.1, 0.24))
	draw_circle(Vector2(730, 270), r * 0.40, Color(1.0, 0.8, 0.4, 0.50))


# Mid-size patrol cruiser with prominent wing fins.
func _draw_enemy_patrol() -> void:
	var e_fill := Color(0.65, 0.1, 0.05, 0.09)
	var e_line := Color(0.9, 0.25, 0.1, 0.20)
	var pts := PackedVector2Array([
		Vector2(955, 270), Vector2(898, 248), Vector2(840, 235),
		Vector2(802, 222), Vector2(782, 195), Vector2(762, 225),
		Vector2(748, 255), Vector2(742, 270), Vector2(748, 285),
		Vector2(762, 315), Vector2(782, 345), Vector2(802, 318),
		Vector2(840, 305), Vector2(898, 292),
	])
	_draw_enemy_polygon(pts, e_fill, e_line)
	var r: float = 10.0 + sin(_time * 2.5 + 1.0) * 3.0
	draw_circle(Vector2(747, 270), r, Color(1.0, 0.4, 0.1, 0.24))
	draw_circle(Vector2(747, 270), r * 0.40, Color(1.0, 0.8, 0.4, 0.50))


# Massive capital ship — wide, imposing hull with a center keel line.
func _draw_enemy_battleship() -> void:
	var e_fill := Color(0.65, 0.1, 0.05, 0.09)
	var e_line := Color(0.9, 0.25, 0.1, 0.20)
	var pts := PackedVector2Array([
		Vector2(1015, 270), Vector2(968, 215), Vector2(878, 185),
		Vector2(785, 178), Vector2(748, 208), Vector2(728, 270),
		Vector2(748, 332), Vector2(785, 362), Vector2(878, 355),
		Vector2(968, 325),
	])
	_draw_enemy_polygon(pts, e_fill, e_line)
	# Center keel line for detail
	draw_line(Vector2(968, 270), Vector2(748, 270), Color(0.9, 0.25, 0.1, 0.08), 1.0)
	var r: float = 13.0 + sin(_time * 2.5 + 1.0) * 4.0
	draw_circle(Vector2(733, 270), r, Color(1.0, 0.4, 0.1, 0.28))
	draw_circle(Vector2(733, 270), r * 0.40, Color(1.0, 0.8, 0.4, 0.55))


# Geometric hexagonal drone — symmetric, mechanical, no cockpit.
func _draw_enemy_drone() -> void:
	var e_fill := Color(0.5, 0.15, 0.05, 0.10)
	var e_line := Color(1.0, 0.45, 0.15, 0.22)
	var pts := PackedVector2Array([
		Vector2(935, 270), Vector2(897, 207), Vector2(823, 207),
		Vector2(785, 270), Vector2(823, 333), Vector2(897, 333),
	])
	_draw_enemy_polygon(pts, e_fill, e_line)
	# Inner hexagon outline (scaled toward center)
	var cx: float = 860.0
	var cy: float = 270.0
	var inner_pts := PackedVector2Array()
	for pt in pts:
		inner_pts.append(Vector2(cx + (pt.x - cx) * 0.48, cy + (pt.y - cy) * 0.48))
	inner_pts.append(inner_pts[0])
	draw_polyline(inner_pts, Color(1.0, 0.55, 0.2, 0.25), 1.0)
	# Central pulsing eye
	var eye_pulse: float = (sin(_time * 3.5) + 1.0) * 0.5
	draw_circle(Vector2(860, 270), 10.0 + eye_pulse * 3.0, Color(1.0, 0.4, 0.1, 0.35 + eye_pulse * 0.2))
	draw_circle(Vector2(860, 270), 4.0, Color(1.0, 0.75, 0.3, 0.85))
	# Sensor lines projecting from the left-facing vertex
	draw_line(Vector2(785, 270), Vector2(762, 250), Color(1.0, 0.5, 0.2, 0.20), 1.0)
	draw_line(Vector2(785, 270), Vector2(758, 270), Color(1.0, 0.5, 0.2, 0.28), 1.2)
	draw_line(Vector2(785, 270), Vector2(762, 290), Color(1.0, 0.5, 0.2, 0.20), 1.0)
	# Weapon glow at forward vertex
	var r: float = 8.0 + sin(_time * 4.0 + 1.0) * 2.5
	draw_circle(Vector2(788, 270), r, Color(1.0, 0.5, 0.15, 0.22))
	draw_circle(Vector2(788, 270), r * 0.38, Color(1.0, 0.85, 0.5, 0.55))


# Space anomaly — not a ship, a cluster of pulsing energy crystal fragments.
func _draw_enemy_anomaly() -> void:
	var pulse1: float = (sin(_time * 1.8) + 1.0) * 0.5
	var pulse2: float = (sin(_time * 2.6 + 1.1) + 1.0) * 0.5
	var pulse3: float = (sin(_time * 3.1 + 2.3) + 1.0) * 0.5
	# Core crystal
	var core := PackedVector2Array([
		Vector2(895, 255), Vector2(922, 248), Vector2(940, 262),
		Vector2(938, 285), Vector2(912, 298), Vector2(882, 284), Vector2(868, 268),
	])
	_draw_enemy_polygon(core,
		Color(0.55, 0.05, 0.85, 0.08 + pulse1 * 0.06),
		Color(0.75, 0.2, 1.0, 0.20 + pulse1 * 0.12))
	# Upper crystal shard
	var shard_up := PackedVector2Array([
		Vector2(855, 218), Vector2(875, 205), Vector2(892, 220),
		Vector2(888, 242), Vector2(862, 248), Vector2(845, 233),
	])
	_draw_enemy_polygon(shard_up,
		Color(0.45, 0.05, 0.75, 0.07 + pulse2 * 0.05),
		Color(0.65, 0.15, 0.9, 0.18 + pulse2 * 0.10))
	# Lower crystal shard
	var shard_dn := PackedVector2Array([
		Vector2(840, 295), Vector2(862, 300), Vector2(866, 325),
		Vector2(845, 335), Vector2(822, 322), Vector2(820, 300),
	])
	_draw_enemy_polygon(shard_dn,
		Color(0.50, 0.05, 0.80, 0.07 + pulse3 * 0.05),
		Color(0.70, 0.15, 0.95, 0.18 + pulse3 * 0.10))
	# Energy tendrils radiating outward
	var t_col := Color(0.6, 0.1, 0.9, 0.15 + pulse1 * 0.08)
	draw_line(Vector2(868, 268), Vector2(835, 242), t_col, 1.2)
	draw_line(Vector2(868, 268), Vector2(830, 275), t_col, 1.2)
	draw_line(Vector2(940, 262), Vector2(968, 248), t_col, 1.0)
	draw_line(Vector2(938, 285), Vector2(965, 302), t_col, 1.0)
	# Core pulse
	draw_circle(Vector2(905, 272), 18.0 + pulse1 * 8.0, Color(0.6, 0.1, 0.9, 0.08 + pulse1 * 0.06))
	draw_circle(Vector2(905, 272), 8.0, Color(0.85, 0.4, 1.0, 0.60))


# Long, thin predator — sleek needle profile, engine pods at tail.
func _draw_enemy_hunter() -> void:
	var e_fill := Color(0.65, 0.1, 0.05, 0.09)
	var e_line := Color(0.9, 0.25, 0.1, 0.20)
	var pts := PackedVector2Array([
		Vector2(1012, 270), Vector2(980, 261), Vector2(890, 252),
		Vector2(800, 254), Vector2(750, 262), Vector2(735, 270),
		Vector2(750, 278), Vector2(800, 286), Vector2(890, 288),
		Vector2(980, 279),
	])
	_draw_enemy_polygon(pts, e_fill, e_line)
	# Cockpit detail near nose
	draw_circle(Vector2(765, 270), 5.0, Color(0.9, 0.25, 0.1, 0.18))
	# Twin engine pods at tail
	draw_circle(Vector2(1002, 262), 5.0, Color(1.0, 0.4, 0.1, 0.22))
	draw_circle(Vector2(1002, 278), 5.0, Color(1.0, 0.4, 0.1, 0.22))
	# Weapon glow at nose tip
	var r: float = 9.0 + sin(_time * 3.0 + 1.0) * 2.5
	draw_circle(Vector2(740, 270), r, Color(1.0, 0.4, 0.1, 0.24))
	draw_circle(Vector2(740, 270), r * 0.40, Color(1.0, 0.8, 0.4, 0.50))


func _draw_enemy_polygon(pts: PackedVector2Array, fill: Color, line: Color) -> void:
	var colors := PackedColorArray()
	for _i in pts.size():
		colors.append(fill)
	draw_polygon(pts, colors)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, line, 1.5)


func _draw_glows() -> void:
	# Player ambient glow (left-center)
	var p_pulse: float = (sin(_time * 1.1) + 1.0) * 0.5
	draw_circle(Vector2(235, 390), 195.0 + p_pulse * 18.0, Color(0.0, 0.35, 0.8, 0.035))
	draw_circle(Vector2(235, 390), 115.0, Color(0.0, 0.6, 1.0, 0.045))
	draw_circle(Vector2(235, 390), 58.0, Color(0.0, 0.78, 1.0, 0.060))

	# Enemy ambient glow — purple for anomaly, red for all ship types
	var e_pulse: float = (sin(_time * 2.2 + 1.0) + 1.0) * 0.5
	var glow_a: Color
	var glow_b: Color
	var glow_c: Color
	if _enemy_is_anomaly:
		glow_a = Color(0.50, 0.05, 0.85, 0.035 + e_pulse * 0.018)
		glow_b = Color(0.65, 0.10, 1.00, 0.055 + e_pulse * 0.025)
		glow_c = Color(0.75, 0.20, 1.00, 0.075 + e_pulse * 0.035)
	else:
		glow_a = Color(0.90, 0.10, 0.05, 0.035 + e_pulse * 0.018)
		glow_b = Color(1.00, 0.20, 0.10, 0.055 + e_pulse * 0.025)
		glow_c = Color(1.00, 0.30, 0.15, 0.075 + e_pulse * 0.035)
	draw_circle(_enemy_glow_center, 240.0 + e_pulse * 35.0, glow_a)
	draw_circle(_enemy_glow_center, 150.0, glow_b)
	draw_circle(_enemy_glow_center, 76.0, glow_c)


func _draw_bolts() -> void:
	for bolt in _bolts:
		var phase: float = float(bolt["phase"]) + _time * float(bolt["speed"])
		if sin(phase) <= 0.3:
			continue
		var alpha: float = (sin(phase) - 0.3) / 0.7
		var y: float = float(bolt["y"])
		var hue: float = float(bolt["hue_shift"])
		var col: Color
		var x_from: float
		var x_to: float

		if bolt["is_player"]:
			col = Color(clampf(0.0 + hue, 0.0, 1.0), clampf(0.85 + hue, 0.0, 1.0), clampf(1.0 - hue * 0.5, 0.0, 1.0))
			x_from = lerpf(160.0, 310.0, (sin(_time * 0.4 + float(bolt["phase"])) + 1.0) * 0.5)
			x_to = lerpf(810.0, 1000.0, (sin(_time * 0.5 + float(bolt["phase"]) + 0.8) + 1.0) * 0.5)
		else:
			col = Color(clampf(1.0 + hue, 0.0, 1.0), clampf(0.35 + hue, 0.0, 1.0), clampf(0.1 - hue * 0.5, 0.0, 1.0))
			x_from = lerpf(960.0, 1100.0, (sin(_time * 0.4 + float(bolt["phase"])) + 1.0) * 0.5)
			x_to = lerpf(190.0, 430.0, (sin(_time * 0.5 + float(bolt["phase"]) + 0.8) + 1.0) * 0.5)

		var w: float = float(bolt["width"])
		var from_pt := Vector2(x_from, y)
		var to_pt := Vector2(x_to, y)

		# Outer glow → mid glow → bright core
		draw_line(from_pt, to_pt, Color(col.r, col.g, col.b, alpha * 0.09), w * 8.0)
		draw_line(from_pt, to_pt, Color(col.r, col.g, col.b, alpha * 0.28), w * 3.0)
		draw_line(from_pt, to_pt, Color(minf(col.r * 1.5, 1.0), minf(col.g * 1.5, 1.0), minf(col.b * 1.5, 1.0), alpha * 0.85), w)

		# Spark particles along the bolt trajectory
		var bolt_dir := to_pt - from_pt
		var bolt_len: float = bolt_dir.length()
		if bolt_len > 10.0:
			var spark_count: int = 3
			for si in spark_count:
				var t: float = fmod(_time * 2.0 + float(si) / float(spark_count), 1.0)
				var spark_pos := from_pt + bolt_dir * t
				var spark_offset := Vector2(0, sin(_time * 8.0 + float(si) * 2.5) * 4.0)
				draw_circle(spark_pos + spark_offset, 1.5, Color(col.r, col.g, col.b, alpha * 0.4))

		# Impact flash at endpoint
		var flash_r: float = alpha * 14.0
		draw_circle(to_pt, flash_r, Color(col.r, col.g, col.b, alpha * 0.22))
		draw_circle(to_pt, flash_r * 0.35, Color(1.0, 1.0, 1.0, alpha * 0.55))


func _draw_debris() -> void:
	for d in _debris:
		var s: float = float(d["size"])
		var a: float = float(d["angle"])
		var p: Vector2 = d["pos"]
		var col: Color = d["color"]

		# Glint effect: brief brightness spike
		var glint: float = (sin(_time * d["glint_speed"] + d["glint_phase"]))
		if glint > 0.92:
			var glint_intensity: float = (glint - 0.92) / 0.08
			col = Color(
				lerpf(col.r, 1.0, glint_intensity * 0.6),
				lerpf(col.g, 1.0, glint_intensity * 0.6),
				lerpf(col.b, 1.0, glint_intensity * 0.6),
				lerpf(col.a, 0.9, glint_intensity * 0.5)
			)

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


func _draw_scanlines() -> void:
	# Subtle CRT scanline overlay scrolling slowly downward
	var line_spacing: int = 4
	var scroll_offset: float = fmod(_time * 12.0, float(line_spacing))
	var scanline_col := Color(0.0, 0.0, 0.0, 0.03)
	var y: float = scroll_offset
	while y < 720.0:
		draw_line(Vector2(0, y), Vector2(1280, y), scanline_col, 1.0)
		y += float(line_spacing)
