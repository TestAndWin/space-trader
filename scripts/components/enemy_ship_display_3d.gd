extends Control

var hull_pct: float = 1.0
var shield_pct: float = 0.0
var _ship_type: int = 0 
var crack_positions: Array = []
var crack_seed_generated: bool = false

const TEX_ENEMY_FIGHTER = preload("res://assets/sprites/enemies/fighter_ship.png")
const TEX_ENEMY_PATROL = preload("res://assets/sprites/enemies/patrol_ship.png")
const TEX_ENEMY_PIRATE = preload("res://assets/sprites/enemies/pirate_ship.png")
const TEX_ENEMY_AI_DRONE = preload("res://assets/sprites/enemies/rogue_ai_ship.png")
const TEX_ENEMY_ANOMALY = preload("res://assets/sprites/enemies/anomaly_ship.png")
const TEX_ENEMY_HUNTER = preload("res://assets/sprites/enemies/hunter_ship.png")
const TEX_FREIGHTER = preload("res://assets/sprites/ships/freighter.png")

var _hit_offset: Vector2 = Vector2.ZERO
var _hit_flash: float = 0.0

func update_enemy(p_hull_pct: float, p_shield_pct: float, encounter_name: String) -> void:
	hull_pct = clampf(p_hull_pct, 0.0, 1.0)
	shield_pct = clampf(p_shield_pct, 0.0, 1.0)
	_ship_type = _type_from_name(encounter_name)
	if hull_pct < 0.6 and not crack_seed_generated:
		_generate_cracks()
	elif hull_pct >= 0.6:
		crack_positions.clear()
		crack_seed_generated = false
	queue_redraw()

func play_hit() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_hit_offset_x, 0.0, 5.0, 0.04)
	tween.tween_method(_set_hit_offset_x, 5.0, -4.0, 0.06).set_delay(0.04)
	tween.tween_method(_set_hit_offset_x, -4.0, 3.0, 0.05).set_delay(0.10)
	tween.tween_method(_set_hit_offset_x, 3.0, -2.0, 0.04).set_delay(0.15)
	tween.tween_method(_set_hit_offset_x, -2.0, 0.0, 0.06).set_delay(0.19)
	tween.tween_method(_set_hit_flash, 0.0, 1.0, 0.06)
	tween.tween_method(_set_hit_flash, 1.0, 0.0, 0.25).set_delay(0.06)

func _set_hit_offset_x(val: float) -> void:
	_hit_offset.x = val
	queue_redraw()

func _set_hit_flash(val: float) -> void:
	_hit_flash = val
	queue_redraw()

func _type_from_name(encounter_name: String) -> int:
	match encounter_name:
		"Wandering Trader": return 1     # Freighter
		"System Patrol", "Smuggler Ambush": return 2  # Scout
		"Pirate Captain": return 3       # Warship
		"Rogue AI": return 4             # Explorer
		"Space Anomaly": return 5        # Smuggler
		"Bounty Hunter": return 6        # Warship/Smuggler
		_: return 0                      # Scout

func _generate_cracks() -> void:
	crack_positions.clear()
	var count: int = int((1.0 - hull_pct) * 8) + 1
	for i in count:
		var start := Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		var end_pt := start + Vector2(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
		crack_positions.append([start, end_pt])
	crack_seed_generated = true

func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var w: float = s
	var h: float = s
	var cx: float = size.x * 0.5 + _hit_offset.x
	var cy: float = size.y * 0.5

	var hull_color: Color
	if hull_pct > 0.6:
		hull_color = Color(0.9, 0.55, 0.15)
	elif hull_pct > 0.3:
		var t: float = (hull_pct - 0.3) / 0.3
		hull_color = Color(0.9, 0.3, 0.15).lerp(Color(0.9, 0.55, 0.15), t)
	else:
		var t: float = hull_pct / 0.3
		hull_color = Color(0.35, 0.08, 0.08).lerp(Color(0.9, 0.3, 0.15), t)

	if _hit_flash > 0.01:
		hull_color = hull_color.lerp(Color(1.0, 0.85, 0.7), _hit_flash * 0.7)

	if shield_pct > 0.0:
		var shield_alpha: float = 0.1 + shield_pct * 0.25
		var shield_color := Color(0.8, 0.3, 0.3, shield_alpha)
		_draw_ellipse(Vector2(cx, cy), w * 0.48, h * 0.46, shield_color)

	var tex: Texture2D
	match _ship_type:
		1: tex = TEX_FREIGHTER
		2: tex = TEX_ENEMY_PATROL
		3: tex = TEX_ENEMY_PIRATE
		4: tex = TEX_ENEMY_AI_DRONE
		5: tex = TEX_ENEMY_ANOMALY
		6: tex = TEX_ENEMY_HUNTER
		_: tex = TEX_ENEMY_FIGHTER

	if tex:
		var rect_width = w
		var rect_height = h
		var rect = Rect2(cx - rect_width / 2.0, cy - rect_height / 2.0, rect_width, rect_height)
		draw_texture_rect(tex, rect, false, hull_color)

	# Draw outline
	# Skipping outline for sprites as they already have internal cel shading

	if hull_pct < 0.6:
		var crack_color := Color(0.15, 0.1, 0.05, 0.6 + (1.0 - hull_pct) * 0.4)
		for crack in crack_positions:
			var p1 := Vector2(cx + crack[0].x * w, cy + crack[0].y * h)
			var p2 := Vector2(cx + crack[1].x * w, cy + crack[1].y * h)
			draw_line(p1, p2, crack_color, 1.5)

	if _hit_flash > 0.05:
		draw_circle(Vector2(cx, cy), w * 0.35, Color(1.0, 0.5, 0.2, _hit_flash * 0.3))

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	var segments: int = 32
	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(center.x + cos(angle) * rx, center.y + sin(angle) * ry))
	draw_colored_polygon(points, color)
