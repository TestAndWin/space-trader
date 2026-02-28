extends Control


func _ready() -> void:
	$VBoxContainer/ContinueButton.visible = SaveManager.has_save()
	_generate_starfield()
	_style_buttons()


func _style_buttons() -> void:
	var buttons := [
		$VBoxContainer/NewGameButton,
		$VBoxContainer/ContinueButton,
		$VBoxContainer/HowToPlayButton,
		$VBoxContainer/QuitButton,
	]
	for btn: Button in buttons:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.02, 0.06, 0.14, 0.85)
		normal.border_color = Color(0.0, 0.45, 0.75, 0.7)
		normal.set_border_width_all(2)
		normal.set_corner_radius_all(6)
		normal.content_margin_left = 16
		normal.content_margin_right = 16
		normal.content_margin_top = 8
		normal.content_margin_bottom = 8
		normal.shadow_color = Color(0.0, 0.45, 0.9, 0.2)
		normal.shadow_size = 4
		var hover := normal.duplicate()
		hover.bg_color = Color(0.03, 0.10, 0.22, 0.9)
		hover.border_color = Color(0.0, 0.65, 0.95, 0.85)
		var pressed := normal.duplicate()
		pressed.bg_color = Color(0.01, 0.04, 0.10, 0.9)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.8, 0.98, 1.0))
		btn.add_theme_font_size_override("font_size", 18)


func _on_new_game_pressed() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/planet_screen.tscn")


func _on_continue_pressed() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/planet_screen.tscn")


func _on_how_to_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _generate_starfield() -> void:
	var stars_node := $Stars
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 150:
		var star := ColorRect.new()
		star.position = Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720))
		var s: float = rng.randf_range(0.5, 2.0)
		star.size = Vector2(s, s)
		var b: float = rng.randf_range(0.1, 0.5)
		star.color = Color(b, b, b * 1.1, b)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars_node.add_child(star)
	for i in 10:
		var star := ColorRect.new()
		star.position = Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720))
		star.size = Vector2(2.5, 2.5)
		star.color = Color(0.7, 0.75, 1.0, 0.7)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars_node.add_child(star)
