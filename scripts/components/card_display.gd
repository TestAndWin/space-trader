extends Control

signal card_played(card_data)

var card_data: Resource = null
var playable: bool = true
var _count_label: Label
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

## Badge text, colour and tooltip per CardData.DamageType. Enemy shields only
## become a decision if the player can read a card's role off the card itself.
const DAMAGE_TYPE_BADGES = {
	CardData.DamageType.KINETIC: {
		"text": "KINETIC",
		"color": Color(1.0, 0.65, 0.35),
		"tip": "Kinetic — full damage to a bare hull, only half-effective against a shield.",
	},
	CardData.DamageType.ION: {
		"text": "ION",
		"color": Color(0.35, 0.8, 1.0),
		"tip": "Ion — double damage to shields, but only half damage to the hull.",
	},
	CardData.DamageType.PIERCING: {
		"text": "PIERCING",
		"color": Color(0.8, 0.6, 1.0),
		"tip": "Piercing — ignores the enemy shield and always hits the hull.",
	},
}

const BOUNCE_BADGE = {
	"text": "BOUNCES",
	"color": Color(1.0, 0.45, 0.4),
	"tip": "Bounces — deals nothing at all while the enemy shield still stands.",
}


func _ready() -> void:
	# Set pivot so scaling expands from the center
	pivot_offset = custom_minimum_size / 2.0


## A deck stack's quantity belongs to the card's own layout.
func set_count(count: int) -> void:
	if _count_label == null:
		_count_label = Label.new()
		_count_label.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
		_count_label.add_theme_color_override("font_color", UIStyles.GOLD)
		_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var button: Button = %PlayButton
		var container: Node = button.get_parent()
		container.add_child(_count_label)
		container.move_child(_count_label, button.get_index())
	_count_label.text = "x%d" % count
	_count_label.visible = count > 1


func setup(data: Resource, can_play: bool, button_text: String = "Play", show_button: bool = true, hide_energy: bool = false) -> void:
	card_data = data
	playable = can_play
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_apply_content_layout()

	%CardNameLabel.text = card_data.card_name
	UIStyles.apply_display_font(%CardNameLabel)
	# The name wraps to two lines and may still be trimmed on very long names.
	%CardNameLabel.tooltip_text = "%s — %s" % [card_data.card_name, _rarity_name()]
	%CardNameLabel.mouse_filter = Control.MOUSE_FILTER_STOP
	# A drawn bolt carries the unit, so the number stays a bare number.
	%EnergyCostLabel.text = str(card_data.energy_cost)
	UIStyles.apply_mono_font(%EnergyCostLabel)
	%CostBadge.tooltip_text = "Energy cost to play this card"
	%CostBadge.mouse_filter = Control.MOUSE_FILTER_STOP
	%CostBadge.visible = not hide_energy
	%DescriptionLabel.text = card_data.description
	# Reserve a fixed line count so every card's play button and cost badge land
	# at the same height — a two-line name would otherwise shift the whole card
	# relative to its neighbours in the hand.
	_lock_label_height(%CardNameLabel, 2)
	_lock_label_height(%DescriptionLabel, 3)

	var type_int := int(card_data.card_type)
	var type_color: Color = CARD_TYPE_COLORS.get(type_int, Color(0.5, 0.5, 0.5))
	_apply_damage_type_badge()

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
	var rarity := int(card_data.rarity)
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

	# The cost badge sits on the already-dark text panel, so it needs no plate
	# or border of its own — the bolt glyph carries the meaning.
	%CostBadge.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

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
		
	# Set boarding action tooltip on the entire card
	tooltip_text = _boarding_tooltip()


## Only attack cards carry a damage type, so the badge stays off everything
## else rather than printing a meaningless "KINETIC" on a repair card.
func _apply_damage_type_badge() -> void:
	# The row stays in the layout even when it has nothing to say. Hiding it
	# would shorten the text panel and uncover more artwork on defense cards
	# than on attack cards, so the hand would no longer read as one set.
	%TypeIndicator.visible = true
	%TypeIndicator.add_theme_font_size_override("font_size", UIStyles.FONT_MICRO)
	UIStyles.apply_mono_font(%TypeIndicator)
	_lock_label_height(%TypeIndicator, 1)

	if int(card_data.card_type) != int(CardData.CardType.ATTACK):
		%TypeIndicator.text = ""
		%TypeIndicator.tooltip_text = ""
		%TypeIndicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	var badge: Dictionary = DAMAGE_TYPE_BADGES.get(
		int(card_data.damage_type), DAMAGE_TYPE_BADGES[CardData.DamageType.KINETIC]
	)
	if card_data.keywords.has(CardData.CardKeyword.BOUNCES):
		badge = BOUNCE_BADGE

	%TypeIndicator.text = "[ %s ]" % badge["text"]
	%TypeIndicator.add_theme_color_override("font_color", badge["color"])
	%TypeIndicator.tooltip_text = badge["tip"]
	%TypeIndicator.mouse_filter = Control.MOUSE_FILTER_STOP


func _boarding_tooltip() -> String:
	if card_data.boarding_description != "":
		return "Boarding Action:\n" + card_data.boarding_description
	return "Boarding Action:\nTrade: Not very effective in boarding."


## Pin a label to an exact number of text lines, so cards keep a uniform
## internal layout regardless of how long their name or description is.
func _lock_label_height(label: Label, lines: int) -> void:
	var font: Font = label.get_theme_font("font")
	if font == null:
		return
	var font_size: int = label.get_theme_font_size("font_size")
	# The gaps between lines count too. Reserving only lines * font_height left
	# a label that actually filled all its lines taller than its own minimum,
	# so the panel still grew with the text it was supposed to be immune to.
	var line_spacing: int = label.get_theme_constant("line_spacing")
	label.custom_minimum_size.y = font.get_height(font_size) * float(lines) + float(line_spacing * (lines - 1))
	label.max_lines_visible = lines
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP


func _apply_content_layout() -> void:
	# Keep text content at the top of art cards while action buttons stay anchored at the bottom.
	var content_vbox: VBoxContainer = get_node("CardSurface/VBoxContainer")
	var spacer: Control = get_node("CardSurface/VBoxContainer/Spacer")
	var text_panel: PanelContainer = get_node("CardSurface/VBoxContainer/TextPanel")
	var play_button: Button = %PlayButton
	content_vbox.move_child(text_panel, 0)
	content_vbox.move_child(spacer, 1)
	content_vbox.move_child(play_button, content_vbox.get_child_count() - 1)

	# Every label inside the panel is locked to a fixed line count, so the panel
	# has one height for all cards — take exactly that and let the spacer swallow
	# whatever is left. Expanding here instead would hand short-text cards a
	# smaller plate and reveal a different slice of artwork on every card.
	text_panel.size_flags_vertical = Control.SIZE_FILL
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL


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
	button.add_theme_font_size_override("font_size", UIStyles.FONT_SUBHEADING)
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.65))


const RARITY_NAMES: PackedStringArray = ["Common", "Uncommon", "Rare"]


func _rarity_name() -> String:
	var rarity := int(card_data.rarity)
	return RARITY_NAMES[rarity] if rarity < RARITY_NAMES.size() else "Common"


func _load_card_artwork() -> void:
	"""Load card artwork PNG by convention: card_id derived from .tres filename.
	Cards created at runtime have no resource_path, so fall back to the card
	name before giving up — a missing texture must not leave a blank card."""
	var art: Texture2D = _load_artwork_for_id(card_data.resource_path.get_file().get_basename())
	if art == null:
		art = _load_artwork_for_id(card_data.card_name.to_lower().replace(" ", "_"))
	%ArtworkRect.texture = art
	%ArtworkRect.visible = art != null
	_apply_artwork_fallback(art == null)


func _load_artwork_for_id(card_id: String) -> Texture2D:
	if card_id == "":
		return null
	var path: String = CARD_ART_BASE_PATH + card_id + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Without artwork the card surface would be flat black. Paint a type-tinted
## placeholder so the slot still reads as a card.
func _apply_artwork_fallback(needed: bool) -> void:
	var existing: ColorRect = %CardSurface.get_node_or_null("ArtworkFallback")
	if not needed:
		if existing:
			existing.queue_free()
		return
	if existing:
		return
	var type_color: Color = CARD_TYPE_COLORS.get(int(card_data.card_type), Color(0.5, 0.5, 0.5))
	var fallback := ColorRect.new()
	fallback.name = "ArtworkFallback"
	fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	fallback.color = Color(type_color.r * 0.22, type_color.g * 0.22, type_color.b * 0.28, 1.0)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%CardSurface.add_child(fallback)
	%CardSurface.move_child(fallback, 0)


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
