extends Control

## Space Invaders mini-game — destroy all enemies to win credits.

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

const ENTRY_COST: int = 100
const WIN_REWARD: int = 300
const LOSE_HULL_MIN: int = 3
const LOSE_HULL_MAX: int = 8
const ABORT_PENALTY: int = 50

const GRID_COLS: int = 5
const GRID_ROWS: int = 3
const ENEMY_SIZE := Vector2(32, 24)
const PLAYER_SIZE := Vector2(28, 20)
const BULLET_SIZE := Vector2(4, 10)
const ENEMY_BULLET_SIZE := Vector2(4, 8)

const PLAYER_SPEED: float = 400.0
const BULLET_SPEED: float = 500.0
const ENEMY_BULLET_SPEED: float = 250.0
const ENEMY_MOVE_SPEED: float = 60.0
const ENEMY_DROP: float = 20.0
const ENEMY_FIRE_INTERVAL: float = 1.5

# Game area bounds
const AREA_LEFT: float = 100.0
const AREA_RIGHT: float = 1180.0
const AREA_TOP: float = 60.0
const AREA_BOTTOM: float = 560.0

var _player_x: float = 640.0
var _player_lives: int = 3
var _player_bullet: Dictionary = {}  # { x, y } or empty
var _player_shoot_cooldown: float = 0.0
var _shoot_cooldown_time: float = 0.4

var _enemies: Array = []  # Array of { x, y, alive, col, row }
var _enemy_direction: float = 1.0  # 1=right, -1=left
var _enemy_bullets: Array = []  # Array of { x, y }
var _enemy_fire_timer: float = 0.0

var _game_active: bool = false
var _game_won: bool = false
var _result_shown: bool = false
var _result_timer: float = 0.0
var _particles: Array = []  # Array of { x, y, vx, vy, life, color }
var _player_flash: float = 0.0  # Screen shake / flash timer on player hit

var _canvas: Control
var _lives_label: Label
var _info_label: Label


func _ready() -> void:
	# Setup background
	BackgroundUtils.add_building_background(self, "mission", 0.6)

	# Crew attack bonus: faster shooting
	if GameManager.has_crew_bonus(CrewData.CrewBonus.ATTACK_BONUS):
		_shoot_cooldown_time = 0.25

	_build_ui()
	_init_game()


func _build_ui() -> void:
	var scaffold: Dictionary = UIStyles.create_overlay_scaffold(
		self,
		"SPACE INVADERS",
		"Destroy all enemies to earn credits",
		"\u2726 \u2694 \u2726",
		"Abort (%dcr)" % ABORT_PENALTY,
		_on_abort_pressed,
	)
	var main_vbox: VBoxContainer = scaffold["main_vbox"]

	# Replace credits label with lives + info labels
	var header: HBoxContainer = scaffold["header"]
	var credits_lbl: Label = scaffold["credits_label"]
	credits_lbl.visible = false

	_lives_label = Label.new()
	_lives_label.add_theme_font_size_override("font_size", 18)
	_lives_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	header.add_child(_lives_label)
	header.move_child(_lives_label, header.get_child_count() - 2)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 16)
	_info_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	header.add_child(_info_label)
	header.move_child(_info_label, header.get_child_count() - 2)

	# Game canvas for _draw (fills remaining space)
	_canvas = Control.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_canvas_draw)
	main_vbox.add_child(_canvas)


func _init_game() -> void:
	_enemies.clear()
	_enemy_bullets.clear()
	_player_bullet = {}
	_player_x = 640.0
	_player_lives = 3
	_enemy_direction = 1.0
	_enemy_fire_timer = 0.0
	_game_active = true
	_game_won = false
	_result_shown = false

	var start_x: float = 340.0
	var start_y: float = AREA_TOP + 30.0
	var spacing_x: float = 60.0
	var spacing_y: float = 40.0

	for row in GRID_ROWS:
		for col in GRID_COLS:
			_enemies.append({
				"x": start_x + col * spacing_x,
				"y": start_y + row * spacing_y,
				"alive": true,
				"col": col,
				"row": row,
			})

	_update_hud()


func _process(delta: float) -> void:
	_update_particles(delta)
	if _player_flash > 0.0:
		_player_flash -= delta

	if _result_shown:
		_result_timer -= delta
		_canvas.queue_redraw()
		if _result_timer <= 0:
			_return_to_planet()
		return

	if not _game_active:
		_canvas.queue_redraw()
		return

	_handle_input(delta)
	_update_player_bullet(delta)
	_update_enemies(delta)
	_update_enemy_bullets(delta)
	_check_collisions()
	_update_hud()
	_canvas.queue_redraw()


func _handle_input(delta: float) -> void:
	_player_shoot_cooldown -= delta
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		_player_x -= PLAYER_SPEED * delta
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		_player_x += PLAYER_SPEED * delta
	_player_x = clampf(_player_x, AREA_LEFT + PLAYER_SIZE.x, AREA_RIGHT - PLAYER_SIZE.x)

	if (Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)) and _player_bullet.is_empty() and _player_shoot_cooldown <= 0:
		_player_bullet = { "x": _player_x, "y": AREA_BOTTOM - 30.0 }
		_player_shoot_cooldown = _shoot_cooldown_time


func _update_player_bullet(delta: float) -> void:
	if _player_bullet.is_empty():
		return
	_player_bullet["y"] -= BULLET_SPEED * delta
	if _player_bullet["y"] < AREA_TOP:
		_player_bullet = {}


func _update_enemies(delta: float) -> void:
	var should_drop: bool = false
	for enemy in _enemies:
		if not enemy["alive"]:
			continue
		enemy["x"] += ENEMY_MOVE_SPEED * _enemy_direction * delta
		if enemy["x"] > AREA_RIGHT - ENEMY_SIZE.x or enemy["x"] < AREA_LEFT + ENEMY_SIZE.x:
			should_drop = true

	if should_drop:
		_enemy_direction *= -1.0
		for enemy in _enemies:
			if enemy["alive"]:
				enemy["y"] += ENEMY_DROP
				# Check if enemies reached bottom
				if enemy["y"] > AREA_BOTTOM - 60:
					_on_game_lost()
					return

	# Enemy firing
	_enemy_fire_timer -= delta
	if _enemy_fire_timer <= 0:
		_enemy_fire_timer = ENEMY_FIRE_INTERVAL
		var alive_enemies: Array = []
		for enemy in _enemies:
			if enemy["alive"]:
				alive_enemies.append(enemy)
		if alive_enemies.size() > 0:
			var shooter: Dictionary = alive_enemies[randi() % alive_enemies.size()]
			_enemy_bullets.append({ "x": shooter["x"], "y": shooter["y"] + ENEMY_SIZE.y * 0.5 })


func _update_enemy_bullets(delta: float) -> void:
	var i: int = _enemy_bullets.size() - 1
	while i >= 0:
		_enemy_bullets[i]["y"] += ENEMY_BULLET_SPEED * delta
		if _enemy_bullets[i]["y"] > AREA_BOTTOM + 20:
			_enemy_bullets.remove_at(i)
		i -= 1


func _check_collisions() -> void:
	# Player bullet vs enemies
	if not _player_bullet.is_empty():
		var bx: float = _player_bullet["x"]
		var by: float = _player_bullet["y"]
		for enemy in _enemies:
			if not enemy["alive"]:
				continue
			if absf(bx - enemy["x"]) < ENEMY_SIZE.x * 0.6 and absf(by - enemy["y"]) < ENEMY_SIZE.y * 0.6:
				_spawn_explosion(enemy["x"], enemy["y"], Color(1.0, 0.6, 0.1))
				enemy["alive"] = false
				_player_bullet = {}
				break

	# Check if all enemies dead
	var all_dead: bool = true
	for enemy in _enemies:
		if enemy["alive"]:
			all_dead = false
			break
	if all_dead:
		_on_game_won()
		return

	# Enemy bullets vs player
	var player_y: float = AREA_BOTTOM - 20.0
	var i: int = _enemy_bullets.size() - 1
	while i >= 0:
		var bx: float = _enemy_bullets[i]["x"]
		var by: float = _enemy_bullets[i]["y"]
		if absf(bx - _player_x) < PLAYER_SIZE.x * 0.7 and absf(by - player_y) < PLAYER_SIZE.y * 0.7:
			_enemy_bullets.remove_at(i)
			_spawn_explosion(_player_x, player_y, Color(1.0, 0.2, 0.2))
			_player_flash = 0.3
			_player_lives -= 1
			if _player_lives <= 0:
				_on_game_lost()
				return
		i -= 1


func _on_game_won() -> void:
	_game_active = false
	_game_won = true
	GameManager.mission_done_this_landing = true
	GameManager.add_credits(WIN_REWARD)
	EventLog.add_entry("Mission complete! Earned %d cr." % WIN_REWARD)
	_info_label.text = "VICTORY! +%d cr" % WIN_REWARD
	_info_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_result_shown = true
	_result_timer = 2.0


func _on_game_lost() -> void:
	_game_active = false
	_game_won = false
	GameManager.mission_done_this_landing = true
	var hull_damage: int = randi_range(LOSE_HULL_MIN, LOSE_HULL_MAX)
	GameManager.current_hull = maxi(1, GameManager.current_hull - hull_damage)
	EventLog.add_entry("Mission failed! Ship took %d hull damage." % hull_damage)
	_info_label.text = "DEFEATED! -%d hull" % hull_damage
	_info_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_result_shown = true
	_result_timer = 2.0


func _on_abort_pressed() -> void:
	if not _game_active:
		return
	_game_active = false
	GameManager.mission_done_this_landing = true
	GameManager.remove_credits(mini(ABORT_PENALTY, GameManager.credits))
	EventLog.add_entry("Mission aborted! Penalty: %d cr." % ABORT_PENALTY)
	_info_label.text = "ABORTED! -%d cr" % ABORT_PENALTY
	_info_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	_result_shown = true
	_result_timer = 1.5


func _return_to_planet() -> void:
	GameManager.change_scene("res://scenes/planet_screen.tscn")


func _update_hud() -> void:
	var hearts: String = ""
	for i in _player_lives:
		hearts += "♥ "
	_lives_label.text = hearts
	if not _result_shown:
		var alive_count: int = 0
		for enemy in _enemies:
			if enemy["alive"]:
				alive_count += 1
		_info_label.text = "Enemies: %d" % alive_count


func _on_canvas_draw() -> void:
	# Draw player (triangle)
	var player_y: float = AREA_BOTTOM - 20.0
	var player_poly := PackedVector2Array([
		Vector2(_player_x, player_y - PLAYER_SIZE.y * 0.5),
		Vector2(_player_x + PLAYER_SIZE.x * 0.5, player_y + PLAYER_SIZE.y * 0.5),
		Vector2(_player_x - PLAYER_SIZE.x * 0.5, player_y + PLAYER_SIZE.y * 0.5),
	])
	_canvas.draw_colored_polygon(player_poly, Color(0.3, 0.85, 0.3))

	# Draw player bullet
	if not _player_bullet.is_empty():
		var br := Rect2(_player_bullet["x"] - BULLET_SIZE.x * 0.5, _player_bullet["y"] - BULLET_SIZE.y * 0.5, BULLET_SIZE.x, BULLET_SIZE.y)
		_canvas.draw_rect(br, Color(0.3, 1.0, 0.3))

	# Draw enemies
	var enemy_colors: Array = [Color(0.9, 0.3, 0.3), Color(0.9, 0.6, 0.2), Color(0.3, 0.6, 0.9)]
	for enemy in _enemies:
		if not enemy["alive"]:
			continue
		var ec: Color = enemy_colors[enemy["row"] % enemy_colors.size()]
		var ex: float = enemy["x"]
		var ey: float = enemy["y"]
		# Body rectangle
		var body_rect := Rect2(ex - ENEMY_SIZE.x * 0.5, ey - ENEMY_SIZE.y * 0.5, ENEMY_SIZE.x, ENEMY_SIZE.y)
		_canvas.draw_rect(body_rect, ec)
		# Eyes (two small white squares)
		var eye_size: float = 4.0
		_canvas.draw_rect(Rect2(ex - 7, ey - 3, eye_size, eye_size), Color(1, 1, 1))
		_canvas.draw_rect(Rect2(ex + 3, ey - 3, eye_size, eye_size), Color(1, 1, 1))

	# Draw enemy bullets
	for bullet in _enemy_bullets:
		var br := Rect2(bullet["x"] - ENEMY_BULLET_SIZE.x * 0.5, bullet["y"] - ENEMY_BULLET_SIZE.y * 0.5, ENEMY_BULLET_SIZE.x, ENEMY_BULLET_SIZE.y)
		_canvas.draw_rect(br, Color(1.0, 0.3, 0.3))

	# Draw explosion particles
	for p in _particles:
		var alpha: float = clampf(p["life"] / 0.4, 0.0, 1.0)
		var col: Color = p["color"]
		col.a = alpha
		var radius: float = lerpf(1.0, 4.0, alpha)
		_canvas.draw_circle(Vector2(p["x"], p["y"]), radius, col)

	# Player hit flash (red screen overlay)
	if _player_flash > 0.0:
		var flash_alpha: float = clampf(_player_flash / 0.3, 0.0, 1.0) * 0.25
		_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(1.0, 0.0, 0.0, flash_alpha))


func _spawn_explosion(x: float, y: float, base_color: Color) -> void:
	for i in 8:
		var angle: float = randf() * TAU
		var speed: float = randf_range(60.0, 180.0)
		_particles.append({
			"x": x, "y": y,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed,
			"life": randf_range(0.3, 0.6),
			"color": base_color.lightened(randf_range(0.0, 0.3)),
		})


func _update_particles(delta: float) -> void:
	var i: int = _particles.size() - 1
	while i >= 0:
		_particles[i]["x"] += _particles[i]["vx"] * delta
		_particles[i]["y"] += _particles[i]["vy"] * delta
		_particles[i]["life"] -= delta
		if _particles[i]["life"] < 0:
			_particles.remove_at(i)
		i -= 1
