extends Control

signal card_played(card_data)

var card_data: Resource = null
var playable: bool = true
var _base_scale := Vector2(1.0, 1.0)
var _hover_scale := Vector2(1.05, 1.05)

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

const CARD_TYPE_COLORS = {
	0: Color(0.9, 0.3, 0.3),   # ATTACK - red
	1: Color(0.3, 0.5, 0.9),   # DEFENSE - blue
	2: Color(0.3, 0.8, 0.3),   # UTILITY - green
	3: Color(0.9, 0.8, 0.2),   # TRADE - yellow
}

const CARD_ART_BASE_PATH = "res://assets/sprites/cards/"


func _ready() -> void:
	# Set pivot so scaling expands from the center
	pivot_offset = custom_minimum_size / 2.0


func setup(data: Resource, can_play: bool, button_text: String = "Play", show_button: bool = true) -> void:
	card_data = data
	playable = can_play
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_apply_content_layout()

	%CardNameLabel.text = card_data.card_name
	UIStyles.apply_display_font(%CardNameLabel)
	%EnergyCostLabel.text = str(card_data.energy_cost)
	UIStyles.apply_mono_font(%EnergyCostLabel)
	%DescriptionLabel.text = card_data.description

	var type_int := int(card_data.card_type)
	var type_color: Color = CARD_TYPE_COLORS.get(type_int, Color(0.5, 0.5, 0.5))
	%TypeIndicator.visible = false

	_load_card_artwork()

	# Style the main card panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.06, 0.98)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(type_color.r, type_color.g, type_color.b, 0.8)
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0

	# Apply rarity glow
	var rarity := int(card_data.get("rarity") if card_data.get("rarity") != null else 0)
	if rarity == 1: # UNCOMMON
		style.border_color = Color(0.62, 0.84, 1.0, 0.95)
	elif rarity == 2: # RARE
		style.border_color = Color(0.96, 0.83, 0.34, 0.95)

	%CardSurface.add_theme_stylebox_override("panel", style)

	# Style the text panel with semi-transparent background
	var text_panel_style := StyleBoxFlat.new()
	text_panel_style.bg_color = Color(0.04, 0.05, 0.12, 0.85)
	text_panel_style.border_color = Color(1.0, 1.0, 1.0, 0.05)
	text_panel_style.border_width_bottom = 1
	text_panel_style.content_margin_left = 6.0
	text_panel_style.content_margin_top = 4.0
	text_panel_style.content_margin_right = 6.0
	text_panel_style.content_margin_bottom = 4.0
	var text_panel: PanelContainer = get_node("CardSurface/VBoxContainer/TextPanel")
	text_panel.add_theme_stylebox_override("panel", text_panel_style)

	# Style the floating Cost Badge
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	badge_style.border_color = Color(0.9, 0.75, 0.2, 0.9)
	badge_style.border_width_left = 2
	badge_style.border_width_top = 2
	badge_style.border_width_right = 2
	badge_style.border_width_bottom = 2
	%CostBadge.add_theme_stylebox_override("panel", badge_style)

	# Card name color based on type
	%CardNameLabel.add_theme_color_override("font_color", type_color)

	%PlayButton.visible = show_button
	%PlayButton.text = button_text
	_style_play_button()

	if not playable:
		modulate.a = 0.4
		%PlayButton.disabled = true
	else:
		modulate.a = 1.0
		%PlayButton.disabled = false


func _apply_content_layout() -> void:
	# Keep text content at the top of art cards while action buttons stay anchored at the bottom.
	var content_vbox: VBoxContainer = get_node("CardSurface/VBoxContainer")
	var spacer: Control = get_node("CardSurface/VBoxContainer/Spacer")
	var text_panel: PanelContainer = get_node("CardSurface/VBoxContainer/TextPanel")
	var play_button: Button = %PlayButton
	content_vbox.move_child(text_panel, 0)
	content_vbox.move_child(spacer, 1)
	content_vbox.move_child(play_button, content_vbox.get_child_count() - 1)


func _style_play_button() -> void:
	var button := %PlayButton
	button.flat = false
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.05, 0.12, 0.88)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.05)
	normal.border_width_top = 1
	normal.border_width_left = 0
	normal.border_width_right = 0
	normal.border_width_bottom = 0
	normal.content_margin_left = 8.0
	normal.content_margin_top = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_bottom = 10.0

	var hover := normal.duplicate()
	hover.bg_color = Color(0.08, 0.10, 0.20, 0.92)
	hover.border_color = Color(1.0, 0.92, 0.55, 0.18)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.03, 0.04, 0.09, 0.95)
	pressed.border_color = Color(1.0, 0.92, 0.55, 0.12)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.04, 0.05, 0.12, 0.65)
	disabled.border_color = Color(1.0, 1.0, 1.0, 0.04)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.65))


func _load_card_artwork() -> void:
	"""Load card artwork PNG by convention: card_id derived from .tres filename."""
	var card_id: String = card_data.resource_path.get_file().get_basename()
	%ArtworkRect.texture = load(CARD_ART_BASE_PATH + card_id + ".png") as Texture2D


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
