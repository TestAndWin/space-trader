extends Control

## Ship upgrades screen — full-screen immersive style like the casino.

# Planet type -> allowed upgrade slots
const PLANET_UPGRADE_SLOTS := {
	0: [0, 1, 4],          # Industrial: ENGINE, HULL, WEAPONS
	1: [3, 5],             # Agricultural: CARGO, SPECIAL
	2: [1, 3],             # Mining: HULL, CARGO
	3: [0, 1, 2, 3, 4, 5], # Tech: all slots
	4: [3, 4, 5],          # Outlaw: CARGO, WEAPONS, SPECIAL
}

const BG_COLOR := Color(0.04, 0.06, 0.14)
const PANEL_COLOR := Color(0.06, 0.08, 0.16)
const BORDER_COLOR := Color(0.15, 0.25, 0.5, 0.8)
const ACCENT := Color(0.3, 0.5, 1.0)
const ACCENT_DIM := Color(0.2, 0.35, 0.7, 0.6)
const GOLD := Color(1.0, 0.95, 0.4)

var all_upgrades: Array[Resource] = []
var current_planet_data: Resource = null
var _credits_label: Label
var _status_label: Label
var _upgrade_list: VBoxContainer
var _stats_list: VBoxContainer


func _ready() -> void:
	_find_planet_data()
	_load_all_upgrades()
	_build_ui()
	_refresh_all()


func _find_planet_data() -> void:
	for planet in EconomyManager.planets:
		if planet.planet_name == GameManager.current_planet:
			current_planet_data = planet
			return


func _load_all_upgrades() -> void:
	var loaded := ResourceRegistry.load_all(ResourceRegistry.UPGRADES)
	for res in loaded:
		all_upgrades.append(res)


func _build_ui() -> void:
	# Full-screen background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Full-screen panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(main_vbox)

	# Header bar
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	main_vbox.add_child(header)

	# Decorative symbols
	var left_deco := Label.new()
	left_deco.text = "\u2726 \u2605 \u2726"
	left_deco.add_theme_font_size_override("font_size", 18)
	left_deco.add_theme_color_override("font_color", ACCENT_DIM)
	header.add_child(left_deco)

	var title := Label.new()
	var type_str := ""
	if current_planet_data:
		type_str = " - " + EconomyManager.PLANET_TYPE_NAMES.get(current_planet_data.planet_type, "Unknown")
	title.text = "SHIP UPGRADES" + type_str
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ACCENT)
	header.add_child(title)

	var right_deco := Label.new()
	right_deco.text = "\u2726 \u2605 \u2726"
	right_deco.add_theme_font_size_override("font_size", 18)
	right_deco.add_theme_color_override("font_color", ACCENT_DIM)
	header.add_child(right_deco)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 20)
	_credits_label.add_theme_color_override("font_color", GOLD)
	header.add_child(_credits_label)

	var close_btn := Button.new()
	close_btn.text = "Leave"
	close_btn.custom_minimum_size = Vector2(80, 36)
	_style_action_button(close_btn, Color(0.5, 0.15, 0.1))
	close_btn.pressed.connect(_on_back_pressed)
	header.add_child(close_btn)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.add_theme_color_override("separator", ACCENT_DIM)
	main_vbox.add_child(sep)

	# Status label
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_status_label)

	# Content: two columns
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	main_vbox.add_child(content)

	# Left: Available upgrades
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 2.0
	left_col.add_theme_constant_override("separation", 8)
	content.add_child(left_col)

	var avail_label := Label.new()
	avail_label.text = "AVAILABLE UPGRADES"
	avail_label.add_theme_font_size_override("font_size", 18)
	avail_label.add_theme_color_override("font_color", ACCENT)
	left_col.add_child(avail_label)

	var upgrade_scroll := ScrollContainer.new()
	upgrade_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(upgrade_scroll)

	_upgrade_list = VBoxContainer.new()
	_upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_list.add_theme_constant_override("separation", 6)
	upgrade_scroll.add_child(_upgrade_list)

	# Vertical separator
	var vsep := VSeparator.new()
	vsep.add_theme_color_override("separator", ACCENT_DIM)
	content.add_child(vsep)

	# Right: Ship stats
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	content.add_child(right_col)

	var stats_label := Label.new()
	stats_label.text = "SHIP STATS"
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", ACCENT)
	right_col.add_child(stats_label)

	var stats_scroll := ScrollContainer.new()
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(stats_scroll)

	_stats_list = VBoxContainer.new()
	_stats_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_list.add_theme_constant_override("separation", 4)
	stats_scroll.add_child(_stats_list)


func _style_action_button(btn: Button, accent: Color) -> void:
	btn.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent
	normal.border_color = accent.lightened(0.3)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate()
	hover.bg_color = accent.lightened(0.15)

	var pressed := normal.duplicate()
	pressed.bg_color = accent.darkened(0.2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.95))


func _style_buy_button(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 14)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.15, 0.3)
	normal.border_color = ACCENT_DIM
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4

	var hover := normal.duplicate()
	hover.bg_color = Color(0.15, 0.2, 0.4)
	hover.border_color = ACCENT

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.08, 0.1, 0.2)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.06, 0.07, 0.1, 0.6)
	disabled.border_color = Color(0.15, 0.15, 0.2, 0.4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(0.85, 0.9, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.35))


func _refresh_all() -> void:
	_credits_label.text = "%d cr" % GameManager.credits
	_populate_available_upgrades()
	_update_stats()


func _populate_available_upgrades() -> void:
	for child in _upgrade_list.get_children():
		child.queue_free()

	var allowed_slots: Array = []
	if current_planet_data:
		var ptype: int = current_planet_data.planet_type
		allowed_slots = PLANET_UPGRADE_SLOTS.get(ptype, [])
	else:
		allowed_slots = [0, 1, 2, 3, 4, 5]

	var any_shown: bool = false
	for upgrade in all_upgrades:
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
		_upgrade_list.add_child(lbl)


func _add_upgrade_row(upgrade: Resource) -> void:
	var row := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.1, 0.18, 0.8)
	row_style.border_color = Color(0.2, 0.25, 0.4, 0.6)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(4)
	row_style.set_content_margin_all(8)
	row.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

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
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_label)

	var buy_button := Button.new()
	buy_button.text = "Buy (%dcr)" % upgrade.cost
	buy_button.custom_minimum_size = Vector2(120, 0)
	buy_button.disabled = GameManager.credits < upgrade.cost
	_style_buy_button(buy_button)
	buy_button.pressed.connect(_on_buy_upgrade.bind(upgrade))
	hbox.add_child(buy_button)

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
		installed_header.add_theme_font_size_override("font_size", 16)
		installed_header.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		_stats_list.add_child(installed_header)

		for upgrade_name in GameManager.installed_upgrades:
			var lbl := Label.new()
			lbl.text = "\u2713 " + upgrade_name
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 0.8))
			_stats_list.add_child(lbl)


func _add_stat_row(stat_name: String, stat_value: String) -> void:
	var row := HBoxContainer.new()

	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	row.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = stat_value
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 15)
	val_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	row.add_child(val_lbl)

	_stats_list.add_child(row)


func _on_back_pressed() -> void:
	GameManager.change_scene("res://scenes/planet_screen.tscn")
