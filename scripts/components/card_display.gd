extends Control

signal card_played(card_data)

var card_data: Resource = null
var playable: bool = true
var _base_scale := Vector2(1.0, 1.0)
var _hover_scale := Vector2(1.05, 1.05)
var _rare_tween: Tween

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

const CARD_TYPE_COLORS = {
	0: Color(0.9, 0.3, 0.3),   # ATTACK - red
	1: Color(0.3, 0.5, 0.9),   # DEFENSE - blue
	2: Color(0.3, 0.8, 0.3),   # UTILITY - green
	3: Color(0.9, 0.8, 0.2),   # TRADE - yellow
}

const CARD_TYPE_ICONS = {
	0: "⚔️ ATTACK",
	1: "🛡️ DEFENSE",
	2: "⚙️ UTILITY",
	3: "💰 TRADE",
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


func _ready() -> void:
	# Set pivot so scaling expands from the center
	pivot_offset = custom_minimum_size / 2.0


func setup(data: Resource, can_play: bool, button_text: String = "Play", show_button: bool = true) -> void:
	card_data = data
	playable = can_play

	%CardNameLabel.text = card_data.card_name
	%EnergyCostLabel.text = str(card_data.energy_cost)
	%DescriptionLabel.text = card_data.description

	var type_int := int(card_data.card_type)
	var type_color: Color = CARD_TYPE_COLORS.get(type_int, Color(0.5, 0.5, 0.5))
	
	%TypeIndicator.text = "[ %s ]" % CARD_TYPE_ICONS.get(type_int, "UNKNOWN")

	# Style the main card panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06 + type_color.r * 0.04, 0.07 + type_color.g * 0.04, 0.14 + type_color.b * 0.04, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(type_color.r, type_color.g, type_color.b, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0

	# Apply rarity glow
	var rarity := int(card_data.get("rarity") if card_data.get("rarity") != null else 0)
	if rarity == 1: # UNCOMMON
		style.shadow_color = Color(0.6, 0.9, 1.0, 0.4)
		style.shadow_size = 6
	elif rarity == 2: # RARE
		style.shadow_color = Color(1.0, 0.8, 0.2, 0.6)
		style.shadow_size = 10
		_start_rare_pulse(style)

	add_theme_stylebox_override("panel", style)

	# Style the type indicator badge inside the card
	var type_style := StyleBoxFlat.new()
	type_style.bg_color = Color(type_color.r, type_color.g, type_color.b, 0.15)
	type_style.corner_radius_top_left = 4
	type_style.corner_radius_top_right = 4
	type_style.corner_radius_bottom_right = 4
	type_style.corner_radius_bottom_left = 4
	%TypeIndicator.add_theme_stylebox_override("normal", type_style)
	%TypeIndicator.add_theme_color_override("font_color", type_color.lightened(0.2))

	# Style the floating Cost Badge
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	badge_style.border_color = Color(0.9, 0.75, 0.2, 0.9)
	badge_style.border_width_left = 2
	badge_style.border_width_top = 2
	badge_style.border_width_right = 2
	badge_style.border_width_bottom = 2
	badge_style.corner_radius_top_left = 12
	badge_style.corner_radius_top_right = 12
	badge_style.corner_radius_bottom_right = 12
	badge_style.corner_radius_bottom_left = 12
	%CostBadge.add_theme_stylebox_override("panel", badge_style)

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


func _start_rare_pulse(style: StyleBoxFlat) -> void:
	if _rare_tween:
		_rare_tween.kill()
	_rare_tween = create_tween().set_loops()
	_rare_tween.tween_property(style, "shadow_size", 16, 1.5).set_trans(Tween.TRANS_SINE)
	_rare_tween.tween_property(style, "shadow_size", 8, 1.5).set_trans(Tween.TRANS_SINE)


func _on_mouse_entered() -> void:
	z_index = 1
	var tw := create_tween()
	tw.tween_property(self, "scale", _hover_scale, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if playable:
		modulate = Color(1.2, 1.2, 1.2, modulate.a)


func _on_mouse_exited() -> void:
	z_index = 0
	var tw := create_tween()
	tw.tween_property(self, "scale", _base_scale, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if playable:
		modulate = Color(1.0, 1.0, 1.0, modulate.a)


func _on_play_button_pressed() -> void:
	if playable and card_data:
		card_played.emit(card_data)
