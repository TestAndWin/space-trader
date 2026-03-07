extends ColorRect

## Ship upgrades popup — immersive showroom style with procedural background.
## Overlay on planet screen, consistent with Casino and Ship Dealer.

signal upgrades_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

# Planet type -> allowed upgrade slots
const PLANET_UPGRADE_SLOTS := {
	0: [0, 1, 4],          # Industrial: ENGINE, HULL, WEAPONS
	1: [3, 5],             # Agricultural: CARGO, SPECIAL
	2: [1, 3],             # Mining: HULL, CARGO
	3: [0, 1, 2, 3, 4, 5], # Tech: all slots
	4: [3, 4, 5],          # Outlaw: CARGO, WEAPONS, SPECIAL
}

const PANEL_COLOR := Color(0.02, 0.06, 0.14, 0.45)
const BORDER_COLOR := Color(0.0, 0.65, 0.95, 0.35)
const ACCENT := Color(0.0, 0.9, 1.0)
const ACCENT_DIM := Color(0.0, 0.45, 0.75, 0.6)
const GOLD := Color(1.0, 0.90, 0.25)
const POSITIVE := Color(0.2, 0.9, 0.35)

var all_upgrades: Array[Resource] = []
var _planet_type: int = 0
var _credits_label: Label
var _status_label: Label
var _upgrade_list: VBoxContainer
var _stats_list: VBoxContainer
var _ship_display: Control
var ShipDisplayScene := preload("res://scenes/components/ship_display_3d.tscn")


func setup(planet_type: int) -> void:
	_planet_type = planet_type
	_refresh_all()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.0)
	_load_all_upgrades()
	_build_ui()


func _load_all_upgrades() -> void:
	var loaded := ResourceRegistry.load_all(ResourceRegistry.UPGRADES)
	for res in loaded:
		all_upgrades.append(res)


func _build_ui() -> void:
	# Background image
	_add_building_background("shipyard")

	# Semi-transparent main panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	# ── Header ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header)

	# Title section with subtitle
	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 0)
	header.add_child(title_vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_vbox.add_child(title_row)

	var left_deco := Label.new()
	left_deco.text = "\u2726 \u2699 \u2726"
	left_deco.add_theme_font_size_override("font_size", 16)
	left_deco.add_theme_color_override("font_color", ACCENT_DIM)
	title_row.add_child(left_deco)

	var type_str := ""
	var planet_data: Resource = _find_planet_data()
	if planet_data:
		type_str = " \u2014 " + EconomyManager.PLANET_TYPE_NAMES.get(planet_data.planet_type, "Unknown")
	var title := Label.new()
	title.text = "SHIP UPGRADES" + type_str
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ACCENT)
	title_row.add_child(title)

	var right_deco := Label.new()
	right_deco.text = "\u2726 \u2699 \u2726"
	right_deco.add_theme_font_size_override("font_size", 16)
	right_deco.add_theme_color_override("font_color", ACCENT_DIM)
	title_row.add_child(right_deco)

	var subtitle := Label.new()
	subtitle.text = "Enhance Your Vessel \u2022 Certified Components \u2022 Installation Included"
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
	_credits_label.add_theme_color_override("font_color", GOLD)
	header.add_child(_credits_label)

	var close_btn := Button.new()
	close_btn.text = "Leave Workshop"
	close_btn.custom_minimum_size = Vector2(140, 36)
	_style_action_button(close_btn, Color(0.5, 0.15, 0.1))
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_color_override("separator", ACCENT_DIM)
	main_vbox.add_child(sep)

	# Status label
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.0, 0.85, 0.45))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_status_label)

	# ── Content: Ship stats (left) + Available upgrades (right) ──
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	main_vbox.add_child(content)

	# Left: Ship stats with large display
	var left_panel := _build_ship_stats_panel()
	content.add_child(left_panel)

	# Vertical separator
	var vsep := VSeparator.new()
	vsep.add_theme_color_override("separator", ACCENT_DIM)
	content.add_child(vsep)

	# Right: Available upgrades
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 2.0
	right_col.add_theme_constant_override("separation", 6)
	content.add_child(right_col)

	var avail_header := Label.new()
	avail_header.text = "\u25C6 AVAILABLE UPGRADES \u25C6"
	avail_header.add_theme_font_size_override("font_size", 16)
	avail_header.add_theme_color_override("font_color", ACCENT)
	avail_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_col.add_child(avail_header)

	var upgrade_scroll := ScrollContainer.new()
	upgrade_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(upgrade_scroll)

	_upgrade_list = VBoxContainer.new()
	_upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_list.add_theme_constant_override("separation", 6)
	upgrade_scroll.add_child(_upgrade_list)


func _find_planet_data() -> Resource:
	return EconomyManager.get_planet_data(GameManager.current_planet)


func _build_ship_stats_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(280, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.04, 0.10, 0.7)
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0.0, 0.4, 0.8, 0.15)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "YOUR SHIP"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", ACCENT_DIM)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Large ship display
	_ship_display = ShipDisplayScene.instantiate()
	_ship_display.custom_minimum_size = Vector2(140, 140)
	vbox.add_child(_ship_display)

	var ship: Resource = GameManager.get_ship_data()
	if ship:
		var ship_name_lbl := Label.new()
		ship_name_lbl.text = ship.ship_name
		ship_name_lbl.add_theme_font_size_override("font_size", 20)
		ship_name_lbl.add_theme_color_override("font_color", ACCENT)
		ship_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(ship_name_lbl)

	# Stats section
	var stats_sep := HSeparator.new()
	stats_sep.add_theme_color_override("separator", ACCENT_DIM)
	vbox.add_child(stats_sep)

	var stats_header := Label.new()
	stats_header.text = "STATS"
	stats_header.add_theme_font_size_override("font_size", 13)
	stats_header.add_theme_color_override("font_color", ACCENT_DIM)
	stats_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_header)

	var stats_scroll := ScrollContainer.new()
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(stats_scroll)

	_stats_list = VBoxContainer.new()
	_stats_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_list.add_theme_constant_override("separation", 3)
	stats_scroll.add_child(_stats_list)

	return panel


func _style_action_button(btn: Button, accent: Color) -> void:
	UIStyles.style_accent_button(btn, accent)


func _style_buy_button(btn: Button) -> void:
	UIStyles.style_buy_button(btn)


func _refresh_all() -> void:
	if not _credits_label:
		return
	_credits_label.text = "%d cr" % GameManager.credits
	_update_ship_display()
	_populate_available_upgrades()
	_update_stats()


func _update_ship_display() -> void:
	var ship: Resource = GameManager.get_ship_data()
	if ship and _ship_display:
		var hull_pct: float = float(GameManager.current_hull) / float(GameManager.max_hull)
		var shield_pct: float = float(GameManager.current_shield) / float(GameManager.max_shield) if GameManager.max_shield > 0 else 0.0
		_ship_display.update_ship(hull_pct, shield_pct, GameManager.get_cargo_used(), GameManager.cargo_capacity, ship.hull_shape)


func _populate_available_upgrades() -> void:
	for child in _upgrade_list.get_children():
		child.queue_free()

	var allowed_slots: Array = []
	var planet_data: Resource = _find_planet_data()
	if planet_data:
		var ptype: int = planet_data.planet_type
		allowed_slots = PLANET_UPGRADE_SLOTS.get(ptype, [])
	else:
		allowed_slots = [0, 1, 2, 3, 4, 5]

	var any_shown: bool = false
	for upgrade in all_upgrades:
		if upgrade.cost <= 0:
			continue
		if upgrade.upgrade_name in GameManager.installed_upgrades:
			continue
		if upgrade.slot not in allowed_slots:
			continue
		_add_upgrade_row(upgrade)
		any_shown = true

	if not any_shown:
		var lbl := Label.new()
		lbl.text = "No upgrades available at this planet."
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_upgrade_list.add_child(lbl)


func _add_upgrade_row(upgrade: Resource) -> void:
	var row := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.02, 0.06, 0.16, 0.75)
	row_style.border_color = Color(0.0, 0.40, 0.65, 0.5)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(8)
	row_style.set_content_margin_all(10)
	row_style.shadow_color = Color(0.0, 0.2, 0.5, 0.08)
	row_style.shadow_size = 4
	row.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)

	# Upgrade icon
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(44, 44)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.01, 0.04, 0.10, 0.8)
	icon_style.border_color = ACCENT_DIM
	icon_style.set_border_width_all(1)
	icon_style.set_corner_radius_all(6)
	icon_style.set_content_margin_all(4)
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	hbox.add_child(icon_panel)

	var icon_lbl := Label.new()
	var slot_icons: Dictionary = {0: "\u2699", 1: "\u26E8", 2: "\u26A1", 3: "\u25A3", 4: "\u2694", 5: "\u2605"}
	icon_lbl.text = slot_icons.get(upgrade.slot, "\u2726")
	icon_lbl.add_theme_font_size_override("font_size", 22)
	icon_lbl.add_theme_color_override("font_color", ACCENT)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_panel.add_child(icon_lbl)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = upgrade.upgrade_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = upgrade.description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.4, 0.55, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_label)

	# Price + buy button column
	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 3)
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(btn_col)

	var price_lbl := Label.new()
	price_lbl.text = "%d cr" % upgrade.cost
	price_lbl.add_theme_font_size_override("font_size", 15)
	price_lbl.add_theme_color_override("font_color", GOLD if GameManager.credits >= upgrade.cost else Color(0.5, 0.3, 0.3))
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_col.add_child(price_lbl)

	var buy_button := Button.new()
	buy_button.text = "INSTALL"
	buy_button.custom_minimum_size = Vector2(100, 36)
	buy_button.disabled = GameManager.credits < upgrade.cost
	_style_buy_button(buy_button)
	buy_button.pressed.connect(_on_buy_upgrade.bind(upgrade))
	btn_col.add_child(buy_button)

	_upgrade_list.add_child(row)


func _on_buy_upgrade(upgrade: Resource) -> void:
	if not GameManager.remove_credits(upgrade.cost):
		_status_label.text = "Not enough credits!"
		return
	GameManager.apply_upgrade(upgrade)
	EventLog.add_entry("Installed %s for %d cr" % [upgrade.upgrade_name, upgrade.cost])
	_status_label.text = "Installed %s!" % upgrade.upgrade_name
	_refresh_all()


func _update_stats() -> void:
	for child in _stats_list.get_children():
		child.queue_free()

	_add_stat_row("Hull", "%d / %d" % [GameManager.current_hull, GameManager.max_hull])
	_add_stat_row("Shield", "%d / %d" % [GameManager.current_shield, GameManager.max_shield])
	_add_stat_row("Cargo Capacity", str(GameManager.cargo_capacity))
	_add_stat_row("Energy / Turn", str(GameManager.energy_per_turn))
	_add_stat_row("Hand Size", str(GameManager.hand_size))
	_add_stat_row("Deck Size", str(GameManager.deck.size()))

	if GameManager.installed_upgrades.size() > 0:
		var spacer := HSeparator.new()
		spacer.add_theme_color_override("separator", ACCENT_DIM)
		_stats_list.add_child(spacer)

		var installed_header := Label.new()
		installed_header.text = "INSTALLED"
		installed_header.add_theme_font_size_override("font_size", 14)
		installed_header.add_theme_color_override("font_color", POSITIVE)
		installed_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_list.add_child(installed_header)

		for upgrade_name in GameManager.installed_upgrades:
			var lbl := Label.new()
			lbl.text = "\u2713 " + upgrade_name
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 0.5))
			_stats_list.add_child(lbl)


func _add_stat_row(stat_name: String, stat_value: String) -> void:
	var row := HBoxContainer.new()

	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.7))
	row.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = stat_value
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	row.add_child(val_lbl)

	_stats_list.add_child(row)


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
	upgrades_closed.emit()
	queue_free()
