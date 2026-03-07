extends Control

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")


@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $VBoxContainer/SubtitleLabel
@onready var version_label: Label = $VBoxContainer/VersionLabel

func _ready() -> void:
	$VBoxContainer/ContinueButton.visible = SaveManager.has_save()
	_style_buttons()
	_apply_title_glow()
	_apply_text_shadow(subtitle_label)
	_apply_text_shadow(version_label)


func _apply_title_glow() -> void:
	# Add golden glow via outline and shadow
	var settings := LabelSettings.new()
	settings.font_size = 52
	settings.font_color = Color(1.0, 0.88, 0.25, 1.0)
	settings.outline_size = 6
	settings.outline_color = Color(1.0, 0.6, 0.0, 0.6)
	settings.shadow_size = 12
	settings.shadow_color = Color(1.0, 0.5, 0.0, 0.45)
	settings.shadow_offset = Vector2(0, 2)
	title_label.label_settings = settings


func _apply_text_shadow(label: Label) -> void:
	var settings := LabelSettings.new()
	settings.font_size = label.get_theme_font_size("font_size")
	settings.font_color = label.get_theme_color("font_color")
	settings.shadow_size = 4
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	settings.shadow_offset = Vector2(1, 1)
	label.label_settings = settings


func _style_buttons() -> void:
	var buttons := [
		$VBoxContainer/NewGameButton,
		$VBoxContainer/ContinueButton,
		$VBoxContainer/HowToPlayButton,
		$VBoxContainer/QuitButton,
	]
	for btn: Button in buttons:
		UIStyles.style_secondary_button(btn, 18)


func _on_new_game_pressed() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/planet_screen.tscn")


func _on_continue_pressed() -> void:
	var success := SaveManager.load_game()
	if not success:
		print("ERROR: Failed to load save game")
		return
	get_tree().change_scene_to_file("res://scenes/planet_screen.tscn")


func _on_how_to_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
