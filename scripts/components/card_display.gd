extends PanelContainer

signal card_played(card_data)

var card_data: Resource = null
var playable: bool = true

const TYPE_COLORS = {
	0: Color(0.9, 0.3, 0.3),   # ATTACK - red
	1: Color(0.3, 0.5, 0.9),   # DEFENSE - blue
	2: Color(0.3, 0.8, 0.3),   # UTILITY - green
	3: Color(0.9, 0.8, 0.2),   # TRADE - yellow
}

const KEYWORD_NAMES = {
	0: "Charge",
	1: "Combo",
	2: "Shield Echo",
	3: "Recycling",
}

const KEYWORD_COLORS = {
	0: Color(1.0, 0.7, 0.2),     # CHARGE - orange
	1: Color(0.8, 0.4, 1.0),     # COMBO - purple
	2: Color(0.3, 0.9, 1.0),     # SHIELD_ECHO - cyan
	3: Color(0.3, 1.0, 0.5),     # RECYCLING - green
}


func setup(data: Resource, can_play: bool, button_text: String = "Play", show_button: bool = true) -> void:
	card_data = data
	playable = can_play

	%CardNameLabel.text = card_data.card_name
	%EnergyCostLabel.text = str(card_data.energy_cost)
	%DescriptionLabel.text = card_data.description

	var type_int := int(card_data.card_type)
	var type_color: Color = TYPE_COLORS.get(type_int, Color(0.5, 0.5, 0.5))
	%TypeIndicator.color = type_color

	# Style the card panel based on type
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06 + type_color.r * 0.04, 0.07 + type_color.g * 0.04, 0.14 + type_color.b * 0.04, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(type_color.r, type_color.g, type_color.b, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)

	# Card name color based on type
	%CardNameLabel.add_theme_color_override("font_color", type_color)

	# Display keyword tags
	if card_data.keywords.size() > 0:
		var bbcode := ""
		for kw in card_data.keywords:
			var color: Color = KEYWORD_COLORS.get(kw, Color(0.7, 0.7, 0.7))
			var hex := color.to_html(false)
			var kw_name: String = KEYWORD_NAMES.get(kw, "Unknown")
			bbcode += "[color=#%s][%s][/color] " % [hex, kw_name]
		%KeywordsLabel.text = bbcode.strip_edges()
		%KeywordsLabel.visible = true
	else:
		%KeywordsLabel.visible = false

	%PlayButton.visible = show_button
	%PlayButton.text = button_text
	if not playable:
		modulate.a = 0.4
		%PlayButton.disabled = true
	else:
		modulate.a = 1.0
		%PlayButton.disabled = false


func _on_play_button_pressed() -> void:
	if playable and card_data:
		card_played.emit(card_data)
