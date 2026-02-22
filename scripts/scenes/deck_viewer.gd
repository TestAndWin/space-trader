extends Control

const CardDisplayScene = preload("res://scenes/components/card_display.tscn")

const SECONDARY_BG := Color(0.1, 0.12, 0.16)
const SECONDARY_BORDER := Color(0.35, 0.38, 0.42, 0.7)


func _ready() -> void:
	_populate_deck()
	_style_close_button()
	%CloseButton.pressed.connect(_on_close_pressed)


func _populate_deck() -> void:
	# Count duplicates
	var card_counts: Dictionary = {}
	for card in GameManager.deck:
		var cname: String = card.card_name
		if card_counts.has(cname):
			card_counts[cname]["count"] += 1
		else:
			card_counts[cname] = {"resource": card, "count": 1}

	%TitleLabel.text = "Your Deck (%d cards)" % GameManager.deck.size()

	for card_name in card_counts:
		var entry: Dictionary = card_counts[card_name]
		var card_display := CardDisplayScene.instantiate()
		card_display.custom_minimum_size = Vector2(130, 160)
		%CardGrid.add_child(card_display)
		card_display.setup(entry["resource"], false, "", false)
		card_display.modulate.a = 1.0
		# Show count badge
		if entry["count"] > 1:
			var count_label := Label.new()
			count_label.text = "x%d" % entry["count"]
			count_label.add_theme_font_size_override("font_size", 16)
			count_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card_display.get_node("VBoxContainer").add_child(count_label)


func _style_close_button() -> void:
	var btn := %CloseButton
	var normal := StyleBoxFlat.new()
	normal.bg_color = SECONDARY_BG
	normal.border_color = SECONDARY_BORDER
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4

	var hover := normal.duplicate()
	hover.bg_color = SECONDARY_BG.lightened(0.15)
	hover.border_color = SECONDARY_BORDER.lightened(0.2)

	var pressed := normal.duplicate()
	pressed.bg_color = SECONDARY_BG.darkened(0.15)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(0.85, 0.87, 0.9))


func _on_close_pressed() -> void:
	queue_free()
