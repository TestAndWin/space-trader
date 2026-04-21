extends Control

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

func _ready() -> void:
	$VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	UIStyles.style_secondary_button($VBoxContainer/BackButton)
	var title_label: Label = $VBoxContainer/TitleLabel
	if title_label:
		UIStyles.apply_display_font(title_label)
	# Apply display font to all section titles
	var content_vbox: Node = $VBoxContainer/ScrollContainer/ContentVBox
	if content_vbox:
		for section in content_vbox.get_children():
			var section_title: Node = section.get_node_or_null("Title")
			if section_title is Label:
				UIStyles.apply_display_font(section_title)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
