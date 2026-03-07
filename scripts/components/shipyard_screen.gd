extends ColorRect

## Shipyard screen — fullscreen overlay for ship repairs and stat upgrades.
## Wraps existing ShipyardPanel in showroom-style overlay, with access to
## Ship Dealer and Ship Upgrades sub-screens.

signal shipyard_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

const PANEL_COLOR := Color(0.02, 0.06, 0.14, 0.45)
const BORDER_COLOR := Color(0.0, 0.55, 0.85, 0.35)
const ACCENT := Color(0.0, 0.9, 1.0)
const ACCENT_DIM := Color(0.0, 0.45, 0.75, 0.6)

const SHIPYARD_NAMES = {
	0: "TECH BAY",
	1: "REPAIR SHED",
	2: "REPAIR DEPOT",
	3: "WORKSHOP",
	4: "CHOP SHOP",
}

const SHIPYARD_ICONS = {
	0: "\u2699",  # ⚙
	1: "\u2692",  # ⚒
	2: "\u2692",  # ⚒
	3: "\u2726",  # ✦
	4: "\u2620",  # ☠
}

var _planet_type: int = 0
var _credits_label: Label
var _shipyard_panel: Control  # ShipyardPanel instance

var ShipyardPanelScene := preload("res://scenes/components/shipyard_panel.tscn")
var ShipDealerScene: PackedScene = preload("res://scenes/components/ship_dealer.tscn")
var ShipUpgradeScene: PackedScene = preload("res://scenes/ship_upgrade.tscn")


func setup(planet_type: int) -> void:
	_planet_type = planet_type
	if _shipyard_panel:
		_shipyard_panel.setup(_planet_type)
	_refresh_ui()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.0)
	_build_ui()


func _build_ui() -> void:
	# Background image
	_add_building_background("shipyard")

	# Main panel
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	add_child(margin)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(main_vbox)

	# ── Header ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header)

	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 0)
	header.add_child(title_vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_vbox.add_child(title_row)

	var left_deco := Label.new()
	left_deco.text = SHIPYARD_ICONS.get(_planet_type, "\u2699")
	left_deco.add_theme_font_size_override("font_size", 16)
	left_deco.add_theme_color_override("font_color", ACCENT_DIM)
	title_row.add_child(left_deco)

	var title := Label.new()
	title.text = SHIPYARD_NAMES.get(_planet_type, "SHIPYARD")
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ACCENT)
	title_row.add_child(title)

	var right_deco := Label.new()
	right_deco.text = SHIPYARD_ICONS.get(_planet_type, "\u2699")
	right_deco.add_theme_font_size_override("font_size", 16)
	right_deco.add_theme_color_override("font_color", ACCENT_DIM)
	title_row.add_child(right_deco)

	var subtitle := Label.new()
	subtitle.text = "Repairs only" if _planet_type == 1 else "Repair, upgrade, and customize your vessel"
	var sub_settings := LabelSettings.new()
	sub_settings.font_size = 11
	sub_settings.font_color = Color(0.8, 0.85, 0.9, 1.0)
	sub_settings.shadow_size = 3
	sub_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	sub_settings.shadow_offset = Vector2(1, 1)
	subtitle.label_settings = sub_settings
	title_vbox.add_child(subtitle)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 20)
	_credits_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.25))
	header.add_child(_credits_label)

	var close_btn := Button.new()
	close_btn.text = "Leave Shipyard"
	close_btn.custom_minimum_size = Vector2(140, 36)
	UIStyles.style_accent_button(close_btn, Color(0.5, 0.15, 0.1))
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_color_override("separator", ACCENT_DIM)
	main_vbox.add_child(sep)

	# Spacer to push content to lower third
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.size_flags_stretch_ratio = 2.0
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(top_spacer)

	# ── Content: Shipyard panel (half width, centered) ──
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.size_flags_stretch_ratio = 1.0
	content_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(content_hbox)

	_shipyard_panel = ShipyardPanelScene.instantiate()
	_shipyard_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shipyard_panel.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	_shipyard_panel.custom_minimum_size = Vector2(480, 0)
	content_hbox.add_child(_shipyard_panel)
	_shipyard_panel.setup(_planet_type)
	_shipyard_panel.shipyard_action.connect(_on_shipyard_action)
	_shipyard_panel.ships_requested.connect(_on_ship_dealer_pressed)
	_shipyard_panel.upgrades_requested.connect(_on_ship_upgrades_pressed)


func _on_shipyard_action() -> void:
	_refresh_ui()


func _on_ship_dealer_pressed() -> void:
	if has_node("ShipDealer"):
		return
	var dealer := ShipDealerScene.instantiate()
	dealer.name = "ShipDealer"
	add_child(dealer)
	dealer.setup(_planet_type)
	dealer.dealer_closed.connect(func():
		_refresh_ui()
		if _shipyard_panel:
			_shipyard_panel.setup(_planet_type)
	)


func _on_ship_upgrades_pressed() -> void:
	if has_node("ShipUpgrades"):
		return
	var upgrades := ShipUpgradeScene.instantiate()
	upgrades.name = "ShipUpgrades"
	add_child(upgrades)
	upgrades.setup(_planet_type)
	upgrades.upgrades_closed.connect(func():
		_refresh_ui()
		if _shipyard_panel:
			_shipyard_panel.setup(_planet_type)
	)


func _refresh_ui() -> void:
	if not _credits_label:
		return
	_credits_label.text = "%d cr" % GameManager.credits


func _add_building_background(building_key: String) -> void:
	var path: String = "res://assets/sprites/bg_building_%s.png" % building_key
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex:
		var bg := TextureRect.new()
		bg.texture = tex
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var dim := ColorRect.new()
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.0, 0.0, 0.0, 0.4)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)


func _close() -> void:
	shipyard_closed.emit()
	queue_free()
