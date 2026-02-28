extends Control

const CockpitFrame := preload("res://scripts/components/cockpit_frame.gd")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

func _ready() -> void:
	$VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	UIStyles.style_secondary_button($VBoxContainer/BackButton)
	CockpitFrame.add_to(self)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
