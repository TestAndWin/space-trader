extends ColorRect

signal boarding_finished(success: bool)

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

var _rounds_won: int = 0
var _rounds_lost: int = 0
var _status_label: Label
var _result_label: Label
var _btn_row: HBoxContainer

enum Move { ROCK, PAPER, SCISSORS }

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	
	var BackgroundUtils = preload("res://scripts/tools/background_utils.gd")
	BackgroundUtils.add_fullscreen_background(self, "res://assets/sprites/scenes/bg_battle.png", 0.5, 1, true, TextureRect.STRETCH_SCALE)
	
	_build_ui()


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIStyles.PANEL_COLOR
	style.border_color = UIStyles.BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "BOARDING ACTION!"
	title.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIStyles.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "First to 2 wins takes the ship!"
	desc.add_theme_font_size_override("font_size", 16)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	_status_label = Label.new()
	_status_label.text = "You: 0 | Enemy: 0"
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", UIStyles.GOLD)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

	_result_label = Label.new()
	_result_label.text = "Choose your tactic:"
	_result_label.add_theme_font_size_override("font_size", 16)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_result_label)

	_btn_row = HBoxContainer.new()
	_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(_btn_row)

	var rock_btn := Button.new()
	rock_btn.text = "Aggressive (Rock)"
	rock_btn.custom_minimum_size = Vector2(150, 48)
	UIStyles.style_accent_button(rock_btn, Color(0.6, 0.2, 0.2))
	rock_btn.pressed.connect(_on_move.bind(Move.ROCK))
	_btn_row.add_child(rock_btn)

	var paper_btn := Button.new()
	paper_btn.text = "Defensive (Paper)"
	paper_btn.custom_minimum_size = Vector2(150, 48)
	UIStyles.style_accent_button(paper_btn, Color(0.2, 0.4, 0.8))
	paper_btn.pressed.connect(_on_move.bind(Move.PAPER))
	_btn_row.add_child(paper_btn)

	var scissors_btn := Button.new()
	scissors_btn.text = "Flanking (Scissors)"
	scissors_btn.custom_minimum_size = Vector2(160, 48)
	UIStyles.style_accent_button(scissors_btn, Color(0.2, 0.6, 0.2))
	scissors_btn.pressed.connect(_on_move.bind(Move.SCISSORS))
	_btn_row.add_child(scissors_btn)


func _on_move(player_move: Move) -> void:
	var enemy_move: Move = randi() % 3 as Move
	
	var move_names := {Move.ROCK: "Aggressive", Move.PAPER: "Defensive", Move.SCISSORS: "Flanking"}
	var result_text := "You: %s vs Enemy: %s\n" % [move_names[player_move], move_names[enemy_move]]
	
	if player_move == enemy_move:
		result_text += "Draw!"
	elif (player_move == Move.ROCK and enemy_move == Move.SCISSORS) or \
		 (player_move == Move.PAPER and enemy_move == Move.ROCK) or \
		 (player_move == Move.SCISSORS and enemy_move == Move.PAPER):
		result_text += "You won this round!"
		_rounds_won += 1
	else:
		result_text += "Enemy won this round!"
		_rounds_lost += 1

	_status_label.text = "You: %d | Enemy: %d" % [_rounds_won, _rounds_lost]
	_result_label.text = result_text

	if _rounds_won >= 2 or _rounds_lost >= 2:
		for btn in _btn_row.get_children():
			btn.disabled = true
		
		var success := _rounds_won >= 2
		if success:
			_result_label.add_theme_color_override("font_color", UIStyles.POSITIVE)
			_result_label.text += "\n\nBOARDING SUCCESSFUL!"
		else:
			_result_label.add_theme_color_override("font_color", UIStyles.NEGATIVE)
			_result_label.text += "\n\nBOARDING FAILED!"
			
		await get_tree().create_timer(2.0).timeout
		boarding_finished.emit(success)
		queue_free()
