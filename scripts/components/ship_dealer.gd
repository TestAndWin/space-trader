extends ColorRect

## Ship dealer popup — immersive showroom experience.
## Full-screen with procedural background, large ship previews,
## and premium showroom aesthetic.

signal dealer_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")



var _planet_type: int = 0
var _ship_list_container: VBoxContainer
var _credits_label: Label
var _status_label: Label
var _current_ship_display: Control
var ShipDisplayScene := preload("res://scenes/components/ship_display_3d.tscn")


func setup(planet_type: int) -> void:
	_planet_type = planet_type
	_refresh_ui()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.0)
	_build_ui()


func _build_ui() -> void:
	# Background image
	BackgroundUtils.add_building_background(self, "shipyard", 0.4)

	# Semi-transparent main panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = UIStyles.PANEL_COLOR
	style.border_color = UIStyles.BORDER_COLOR
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
	left_deco.text = "\u2726 \u2605 \u2726"
	left_deco.add_theme_font_size_override("font_size", 16)
	left_deco.add_theme_color_override("font_color", UIStyles.ACCENT_DIM)
	title_row.add_child(left_deco)

	var title := Label.new()
	title.text = "STARSHIP SHOWROOM"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UIStyles.ACCENT)
	title_row.add_child(title)

	var right_deco := Label.new()
	right_deco.text = "\u2726 \u2605 \u2726"
	right_deco.add_theme_font_size_override("font_size", 16)
	right_deco.add_theme_color_override("font_color", UIStyles.ACCENT_DIM)
	title_row.add_child(right_deco)

	var subtitle := Label.new()
	subtitle.text = "Premium Vessels \u2022 Trade-In Available \u2022 Galactic Licensed Dealer"
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
	_credits_label.add_theme_color_override("font_color", UIStyles.GOLD)
	header.add_child(_credits_label)

	var close_btn := Button.new()
	close_btn.text = "Leave Showroom"
	close_btn.custom_minimum_size = Vector2(130, 36)
	UIStyles.style_accent_button(close_btn, Color(0.5, 0.15, 0.1))
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# Separator with glow
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_color_override("separator", UIStyles.ACCENT_DIM)
	main_vbox.add_child(sep)

	# Status label
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.0, 0.85, 0.45))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_status_label)

	# ── Content: Current ship + available ships ──
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	main_vbox.add_child(content)

	# Left: Current ship showcase
	var current_panel := _build_current_ship_panel()
	content.add_child(current_panel)

	# Vertical divider
	var vsep := VSeparator.new()
	vsep.add_theme_color_override("separator", UIStyles.ACCENT_DIM)
	content.add_child(vsep)

	# Right: Ship list
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 2.0
	right_col.add_theme_constant_override("separation", 6)
	content.add_child(right_col)

	var avail_header := Label.new()
	avail_header.text = "\u25C6 AVAILABLE SHIPS \u25C6"
	avail_header.add_theme_font_size_override("font_size", 16)
	avail_header.add_theme_color_override("font_color", UIStyles.ACCENT)
	avail_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_col.add_child(avail_header)

	_ship_list_container = VBoxContainer.new()
	_ship_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ship_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_list_container.add_theme_constant_override("separation", 4)
	right_col.add_child(_ship_list_container)


func _build_current_ship_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(280, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.04, 0.10, 0.7)
	style.border_color = UIStyles.ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	# Bottom glow (spotlight reflection)
	style.shadow_color = Color(0.0, 0.4, 0.8, 0.15)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "YOUR SHIP"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", UIStyles.ACCENT_DIM)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Large ship display
	_current_ship_display = ShipDisplayScene.instantiate()
	_current_ship_display.custom_minimum_size = Vector2(140, 140)
	vbox.add_child(_current_ship_display)

	var ship: Resource = GameManager.get_ship_data()
	if ship:
		var hull_pct: float = float(GameManager.current_hull) / float(GameManager.max_hull)
		var shield_pct: float = float(GameManager.current_shield) / float(GameManager.max_shield) if GameManager.max_shield > 0 else 0.0
		_current_ship_display.update_ship(hull_pct, shield_pct, GameManager.get_cargo_used(), GameManager.cargo_capacity, ship.hull_shape)

		var name_lbl := Label.new()
		name_lbl.text = ship.ship_name
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", UIStyles.ACCENT)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		# Stats grid
		var stats_grid := GridContainer.new()
		stats_grid.columns = 2
		stats_grid.add_theme_constant_override("h_separation", 12)
		stats_grid.add_theme_constant_override("v_separation", 2)
		vbox.add_child(stats_grid)

		_add_stat_pair(stats_grid, "Hull", "%d/%d" % [GameManager.current_hull, GameManager.max_hull])
		_add_stat_pair(stats_grid, "Shield", "%d/%d" % [GameManager.current_shield, GameManager.max_shield])
		_add_stat_pair(stats_grid, "Cargo", "%d slots" % GameManager.cargo_capacity)
		_add_stat_pair(stats_grid, "Energy", "%d/turn" % GameManager.energy_per_turn)
		_add_stat_pair(stats_grid, "Hand", "%d cards" % GameManager.hand_size)

		# Trade-in value
		if ship.cost > 0:
			var trade_in: int = int(ship.cost * 0.5)
			var trade_lbl := Label.new()
			trade_lbl.text = "Trade-in value: %d cr" % trade_in
			trade_lbl.add_theme_font_size_override("font_size", 12)
			trade_lbl.add_theme_color_override("font_color", UIStyles.GOLD)
			trade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(trade_lbl)

	return panel


func _add_stat_pair(grid: GridContainer, stat_name: String, stat_value: String) -> void:
	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.7))
	grid.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = stat_value
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(val_lbl)


func _get_current_ship_name() -> String:
	var ship: Resource = GameManager.get_ship_data()
	return ship.ship_name if ship else "Unknown"


func _refresh_ui() -> void:
	if not _credits_label:
		return
	_credits_label.text = "%d cr" % GameManager.credits

	for child in _ship_list_container.get_children():
		child.queue_free()

	var current_ship: Resource = GameManager.get_ship_data()
	var all_ships: Array = ResourceRegistry.load_all(ResourceRegistry.SHIPS)

	for ship in all_ships:
		# Only show ships available at this planet type
		if ship.available_planet_types.size() > 0 and not (_planet_type in ship.available_planet_types):
			continue
		# Don't show the starter ship for purchase
		if ship.cost == 0 and ship.resource_path != GameManager.current_ship:
			continue

		var card := _create_ship_card(ship, current_ship)
		_ship_list_container.add_child(card)


func _create_ship_card(ship: Resource, current_ship: Resource) -> PanelContainer:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	var is_current: bool = ship.resource_path == GameManager.current_ship

	if is_current:
		card_style.bg_color = Color(0.03, 0.10, 0.22, 0.85)
		card_style.border_color = UIStyles.ACCENT
		card_style.set_border_width_all(2)
		# Spotlight glow effect for current ship
		card_style.shadow_color = Color(0.0, 0.5, 0.9, 0.2)
		card_style.shadow_size = 10
	else:
		card_style.bg_color = Color(0.02, 0.06, 0.16, 0.75)
		card_style.border_color = Color(0.0, 0.40, 0.65, 0.5)
		card_style.set_border_width_all(1)
		card_style.shadow_color = Color(0.0, 0.2, 0.5, 0.08)
		card_style.shadow_size = 4

	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", card_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Ship preview — larger in showroom
	var preview_container := PanelContainer.new()
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.01, 0.03, 0.08, 0.6)
	preview_style.border_color = Color(0.0, 0.35, 0.55, 0.3)
	preview_style.set_border_width_all(1)
	preview_style.set_corner_radius_all(6)
	preview_style.set_content_margin_all(4)
	# Bottom spotlight reflection
	preview_style.shadow_color = Color(0.0, 0.3, 0.6, 0.1)
	preview_style.shadow_size = 6
	preview_container.add_theme_stylebox_override("panel", preview_style)
	hbox.add_child(preview_container)

	var ship_preview := ShipDisplayScene.instantiate()
	ship_preview.custom_minimum_size = Vector2(70, 70)
	preview_container.add_child(ship_preview)
	ship_preview.update_ship(1.0, 0.5, 0, ship.base_cargo_capacity, ship.hull_shape)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = ship.ship_name + ("  \u2605 EQUIPPED" if is_current else "")
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", UIStyles.ACCENT if is_current else Color(0.75, 0.88, 1.0))
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = ship.description
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.35, 0.55, 0.75))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	# Color-coded stat comparison
	var stats := _build_stat_comparison(ship, current_ship)
	info.add_child(stats)

	# Ship ability description
	var ability_row := _build_ability_row(ship)
	if ability_row.get_child_count() > 0:
		info.add_child(ability_row)

	# Buy button column
	if not is_current and ship.cost > 0:
		var btn_col := VBoxContainer.new()
		btn_col.add_theme_constant_override("separation", 4)
		btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(btn_col)

		var trade_in: int = int(current_ship.cost * 0.5)
		var net_cost: int = ship.cost - trade_in

		var price_lbl := Label.new()
		price_lbl.text = "%d cr" % net_cost
		price_lbl.add_theme_font_size_override("font_size", 16)
		price_lbl.add_theme_color_override("font_color", UIStyles.GOLD if GameManager.credits >= net_cost else Color(0.5, 0.3, 0.3))
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_col.add_child(price_lbl)

		if trade_in > 0:
			var trade_lbl := Label.new()
			trade_lbl.text = "(-%d trade-in)" % trade_in
			trade_lbl.add_theme_font_size_override("font_size", 10)
			trade_lbl.add_theme_color_override("font_color", Color(0.5, 0.65, 0.45))
			trade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn_col.add_child(trade_lbl)

		var btn := Button.new()
		btn.text = "BUY"
		btn.custom_minimum_size = Vector2(100, 38)
		btn.disabled = GameManager.credits < net_cost
		_style_buy_button(btn)
		btn.pressed.connect(_on_buy_ship.bind(ship, net_cost))
		btn_col.add_child(btn)

	return card


func _build_stat_comparison(ship: Resource, current: Resource) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var dh: int = ship.base_max_hull - current.base_max_hull
	var ds: int = ship.base_max_shield - current.base_max_shield
	var dc: int = ship.base_cargo_capacity - current.base_cargo_capacity
	var de: int = ship.base_energy_per_turn - current.base_energy_per_turn
	var dhnd: int = ship.base_hand_size - current.base_hand_size

	_add_stat_chip(row, "Hull", ship.base_max_hull, dh)
	_add_stat_chip(row, "Shield", ship.base_max_shield, ds)
	_add_stat_chip(row, "Cargo", ship.base_cargo_capacity, dc)
	if de != 0:
		_add_stat_chip(row, "Energy", ship.base_energy_per_turn, de)
	if dhnd != 0:
		_add_stat_chip(row, "Hand", ship.base_hand_size, dhnd)

	# Special abilities
	var specials: Array = []
	if ship.encounter_reduction > 0:
		specials.append("-%d%% Encounters" % int(ship.encounter_reduction * 100))
	if ship.contraband_bonus > 0:
		specials.append("+%d%% Contraband" % int(ship.contraband_bonus * 100))
	if ship.quest_reward_bonus > 0:
		specials.append("+%d%% Quest" % int(ship.quest_reward_bonus * 100))

	if specials.size() > 0:
		var spec_lbl := Label.new()
		spec_lbl.text = " | ".join(specials)
		spec_lbl.add_theme_font_size_override("font_size", 10)
		spec_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
		row.add_child(spec_lbl)

	return row


func _build_ability_row(ship: Resource) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	# Ability description
	var ability_desc: String = ship.ability_description
	if ability_desc != "":
		var ability_lbl := Label.new()
		ability_lbl.text = "⚡ " + ability_desc
		ability_lbl.add_theme_font_size_override("font_size", 10)
		ability_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
		ability_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(ability_lbl)
	return row


func _add_stat_chip(container: HBoxContainer, stat_name: String, value: int, diff: int) -> void:
	var chip := Label.new()
	var diff_str: String = ""
	var col: Color = Color(0.6, 0.65, 0.75)

	if diff > 0:
		diff_str = " +%d" % diff
		col = UIStyles.POSITIVE
	elif diff < 0:
		diff_str = " %d" % diff
		col = UIStyles.NEGATIVE

	chip.text = "%s:%d%s" % [stat_name, value, diff_str]
	chip.add_theme_font_size_override("font_size", 11)
	chip.add_theme_color_override("font_color", col)
	container.add_child(chip)


func _on_buy_ship(ship: Resource, net_cost: int) -> void:
	if not GameManager.remove_credits(net_cost):
		_status_label.text = "Not enough credits!"
		return
	var old_ship: Resource = GameManager.get_ship_data()
	var trade_in: int = int(old_ship.cost * 0.5)
	GameManager.switch_ship(ship.resource_path)
	GameManager.remove_credits(trade_in)

	EventLog.add_entry("Bought %s for %d cr (trade-in: %d cr)" % [ship.ship_name, net_cost, trade_in])
	_status_label.text = "Switched to %s!" % ship.ship_name
	_refresh_ui()


func _style_buy_button(btn: Button) -> void:
	UIStyles.style_buy_button(btn)


func _close() -> void:
	dealer_closed.emit()
	queue_free()
