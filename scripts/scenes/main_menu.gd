extends Control


func _ready() -> void:
	$VBoxContainer/ContinueButton.visible = SaveManager.has_save()
	_generate_starfield()


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
