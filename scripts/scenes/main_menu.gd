extends Control

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")


@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $VBoxContainer/SubtitleLabel
@onready var version_label: Label = $VBoxContainer/VersionLabel

func _ready() -> void:
	$VBoxContainer/ContinueButton.visible = SaveManager.has_save()
	$VBoxContainer/QuitButton.visible = OS.get_name() != "iOS"
	_style_buttons()
	_apply_title_glow()
	_apply_text_shadow(subtitle_label)
	_apply_text_shadow(version_label)


func _apply_title_glow() -> void:
	# Add golden glow via outline and shadow
	var settings := LabelSettings.new()
	settings.font = UIStyles.FONT_DISPLAY
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
		$VBoxContainer/AchievementsButton,
		$VBoxContainer/AboutButton,
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
	title.text = "Difficulty"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings := LabelSettings.new()
	title_settings.font_size = 28
	title_settings.font_color = Color(1.0, 0.88, 0.25)
	title.label_settings = title_settings
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var difficulties := [
		{ "name": "Easy", "desc": "Start 1500 cr, fewer enemies, more time for quests.\nWin: 8000 cr + all 7 planets + 1 crafted upgrade + no bounty", "value": GameManager.Difficulty.EASY },
		{ "name": "Normal", "desc": "Start 1000 cr, standard encounters, normal deadlines.\nWin: 10000 cr + all 7 planets + 1 crafted upgrade + no bounty", "value": GameManager.Difficulty.NORMAL },
		{ "name": "Hard", "desc": "Start 600 cr, more enemies, shorter deadlines, less hull.\nWin: 12000 cr + all 7 planets + 1 crafted upgrade + no bounty", "value": GameManager.Difficulty.HARD },
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
	cancel_btn.text = "Cancel"
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


func _on_achievements_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/achievements_screen.tscn")


func _on_about_pressed() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.95)
	panel_style.border_color = Color(0.0, 0.65, 0.95, 0.7)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(540, 460)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "About & Legal"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyles.apply_screen_title(title, UIStyles.GOLD)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var game_info := Label.new()
	game_info.text = "Space Trader: Dealer's Hand (v1.0)\nA 2D roguelike space trading & deck-building card game."
	game_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_info.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	game_info.add_theme_font_size_override("font_size", 14)
	vbox.add_child(game_info)

	vbox.add_child(HSeparator.new())

	var godot_info := Label.new()
	godot_info.text = "Engine & Legal Notice:\nPowered by Godot Engine (https://godotengine.org)\nCopyright (c) 2014-present Godot Engine contributors."
	godot_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	godot_info.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	godot_info.add_theme_font_size_override("font_size", 13)
	vbox.add_child(godot_info)

	var lic_header := Label.new()
	lic_header.text = "Godot Engine MIT License:"
	lic_header.add_theme_color_override("font_color", UIStyles.ACCENT)
	lic_header.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lic_header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var lic_label := Label.new()
	lic_label.text = Engine.get_license_text()
	lic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lic_label.custom_minimum_size = Vector2(500, 0)
	lic_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	lic_label.add_theme_font_size_override("font_size", 11)
	UIStyles.apply_mono_font(lic_label)
	scroll.add_child(lic_label)
	vbox.add_child(scroll)

	vbox.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = "Close"
	UIStyles.style_secondary_button(close_btn, 16)
	close_btn.pressed.connect(overlay.queue_free)
	vbox.add_child(close_btn)


func _on_quit_pressed() -> void:
	get_tree().quit()
