extends Control

const CockpitFrame := preload("res://scripts/components/cockpit_frame.gd")

func _ready() -> void:
	$VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	_style_back_button()
	CockpitFrame.add_to(self)


func _style_back_button() -> void:
	var btn: Button = $VBoxContainer/BackButton
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.06, 0.14, 0.85)
	normal.border_color = Color(0.0, 0.45, 0.75, 0.7)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
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

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
