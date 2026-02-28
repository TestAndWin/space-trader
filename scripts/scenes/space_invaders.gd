extends Control

## Space Invaders mini-game — destroy all enemies to win credits.

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
const AREA_BOTTOM: float = 650.0

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

var _canvas: Control
var _lives_label: Label
var _info_label: Label


func _ready() -> void:
	# Setup background
	var bg := $Background
	bg.setup(3, 2)  # Tech type, medium danger

	# Crew attack bonus: faster shooting
	if GameManager.has_crew_bonus(CrewData.CrewBonus.ATTACK_BONUS):
		_shoot_cooldown_time = 0.25

	_build_ui()
	_init_game()
	_add_cockpit_frame()


func _build_ui() -> void:
	# HUD at top
	var hud := HBoxContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_top = 8
	hud.offset_left = 16
	hud.offset_right = -16
	hud.add_theme_constant_override("separation", 20)
	add_child(hud)

	var title := Label.new()
	title.text = "SPACE INVADERS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	hud.add_child(title)

	_lives_label = Label.new()
	_lives_label.add_theme_font_size_override("font_size", 18)
	_lives_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	hud.add_child(_lives_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(spacer)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 16)
	_info_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	hud.add_child(_info_label)

	var abort_btn := Button.new()
	abort_btn.text = "Abort (%dcr)" % ABORT_PENALTY
	abort_btn.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.15, 0.1)
	style.border_color = Color(0.7, 0.3, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	abort_btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.6, 0.2, 0.15)
	abort_btn.add_theme_stylebox_override("hover", hover_style)
	abort_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.8))
	abort_btn.pressed.connect(_on_abort_pressed)
	hud.add_child(abort_btn)

	# Game canvas for _draw
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_canvas_draw)
	add_child(_canvas)


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
	if _result_shown:
		_result_timer -= delta
		if _result_timer <= 0:
			_return_to_planet()
		return

	if not _game_active:
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


func _add_cockpit_frame() -> void:
	var frame := Control.new()
	frame.name = "CockpitFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_script(load("res://scripts/components/cockpit_frame.gd"))
	add_child(frame)
