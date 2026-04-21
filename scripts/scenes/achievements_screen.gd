extends Control

## Achievements screen — shows all achievements with unlock status.
## Accessible from the main menu.

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 16)
	margin.add_child(outer_vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	outer_vbox.add_child(header)

	var title := Label.new()
	title.text = "ACHIEVEMENTS"
	title.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIStyles.GOLD)
	header.add_child(title)

	var count_label := Label.new()
	count_label.text = "%d / %d" % [AchievementManager.get_unlocked_count(), AchievementManager.get_total_count()]
	count_label.add_theme_font_override("font", UIStyles.FONT_MONO)
	count_label.add_theme_font_size_override("font_size", 20)
	count_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(count_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 36)
	UIStyles.style_accent_button(back_btn, Color(0.5, 0.15, 0.1))
	back_btn.pressed.connect(_on_back)
	header.add_child(back_btn)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", UIStyles.ACCENT_DIM)
	outer_vbox.add_child(sep)

	# Grid of achievements
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for id in AchievementManager.ACHIEVEMENTS:
		var info: Dictionary = AchievementManager.ACHIEVEMENTS[id]
		var unlocked: bool = AchievementManager.is_unlocked(id)
		grid.add_child(_create_card(info, unlocked))


func _create_card(info: Dictionary, unlocked: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 90)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	if unlocked:
		style.bg_color = Color(0.08, 0.12, 0.06, 0.9)
		style.border_color = UIStyles.GOLD.darkened(0.3)
	else:
		style.bg_color = Color(0.06, 0.06, 0.08, 0.7)
		style.border_color = Color(0.2, 0.2, 0.25, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Icon area
	var icon_label := Label.new()
	if unlocked:
		icon_label.text = "★"
		icon_label.add_theme_color_override("font_color", UIStyles.GOLD)
	else:
		icon_label.text = "?"
		icon_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_label)

	# Text area
	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 4)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_vbox)

	var name_label := Label.new()
	if unlocked:
		name_label.text = info["name"]
		name_label.add_theme_color_override("font_color", UIStyles.GOLD)
	else:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	name_label.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	name_label.add_theme_font_size_override("font_size", 18)
	text_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = info["description"]
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if unlocked:
		desc_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.7))
	else:
		desc_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	desc_label.add_theme_font_size_override("font_size", 13)
	text_vbox.add_child(desc_label)

	return card


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
