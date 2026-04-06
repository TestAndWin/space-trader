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
	_show_difficulty_popup()


func _show_difficulty_popup() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	panel_style.border_color = Color(1.0, 0.88, 0.25, 0.6)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(400, 0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Schwierigkeitsgrad"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings := LabelSettings.new()
	title_settings.font_size = 28
	title_settings.font_color = Color(1.0, 0.88, 0.25)
	title.label_settings = title_settings
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var difficulties := [
		{ "name": "Leicht", "desc": "1500 Credits, weniger Gegner, mehr Zeit für Quests", "value": GameManager.Difficulty.EASY },
		{ "name": "Normal", "desc": "1000 Credits, Standard-Encounter, normale Deadlines", "value": GameManager.Difficulty.NORMAL },
		{ "name": "Schwer", "desc": "600 Credits, mehr Gegner, kürzere Deadlines, weniger Hülle", "value": GameManager.Difficulty.HARD },
	]

	for diff: Dictionary in difficulties:
		var btn_vbox := VBoxContainer.new()
		btn_vbox.add_theme_constant_override("separation", 2)

		var btn := Button.new()
		btn.text = diff["name"]
		UIStyles.style_accent_button(btn, 20)
		btn.pressed.connect(_on_difficulty_chosen.bind(diff["value"], overlay))
		btn_vbox.add_child(btn)

		var desc := Label.new()
		desc.text = diff["desc"]
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var desc_settings := LabelSettings.new()
		desc_settings.font_size = 13
		desc_settings.font_color = Color(0.7, 0.7, 0.7)
		desc.label_settings = desc_settings
		btn_vbox.add_child(desc)

		vbox.add_child(btn_vbox)

	vbox.add_child(HSeparator.new())

	var cancel_btn := Button.new()
	cancel_btn.text = "Abbrechen"
	UIStyles.style_secondary_button(cancel_btn, 16)
	cancel_btn.pressed.connect(overlay.queue_free)
	vbox.add_child(cancel_btn)


func _on_difficulty_chosen(diff: int, overlay: Control) -> void:
	overlay.queue_free()
	GameManager.difficulty = diff
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
