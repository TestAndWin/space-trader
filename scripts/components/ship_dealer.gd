extends ColorRect

## Ship dealer popup — immersive showroom experience.
## Full-screen with procedural background, large ship previews,
## and premium showroom aesthetic.

signal dealer_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

var _planet_type: int = 0
var _ship_list_container: VBoxContainer
var _status_label: Label
var _current_ship_display: Control
const ShipDisplayScene: PackedScene = preload("res://scenes/components/ship_display.tscn")

## When shown as a tab inside the shipyard screen the host already provides the
## background, frame and header — drawing our own would stack a second full
## screen inside the first, which is the nesting the tabs replaced.
var _embedded: bool = false


## Must be called before add_child(), because the UI is built in _ready().
func set_embedded(value: bool) -> void:
	_embedded = value


func setup(planet_type: int) -> void:
	_planet_type = planet_type
	_refresh_ui()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.0)
	_build_ui()


func _build_ui() -> void:
	if _embedded:
		# Sits inside the shipyard screen, which already draws chrome and header,
		# so this variant builds only the content column.
		var embedded_panel := PanelContainer.new()
		embedded_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		UIStyles.style_overlay_panel(embedded_panel, true)
		add_child(embedded_panel)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 10)
		embedded_panel.add_child(inner)
		_build_content(inner)
		return

	BackgroundUtils.add_building_background(self, "shipyard", 0.4)

	var scaffold: Dictionary = UIStyles.create_overlay_scaffold(
		self,
		"STARSHIP SHOWROOM",
		"Premium Vessels \u2022 Trade-In Available \u2022 Galactic Licensed Dealer",
		"\u2726 \u2605 \u2726",
		"Back to Shipyard",
		close,
	)
	var main_vbox: VBoxContainer = scaffold["main_vbox"]

	_build_content(main_vbox)


## Everything below the header — shared by the standalone screen and the
## embedded shipyard tab.
func _build_content(main_vbox: VBoxContainer) -> void:
	# Status label
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
	_status_label.add_theme_color_override("font_color", UIStyles.POSITIVE)
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
	UIStyles.apply_section_title(avail_header)
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
	header.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
	header.add_theme_color_override("font_color", UIStyles.ACCENT_DIM)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Large ship display
	_current_ship_display = ShipDisplayScene.instantiate()
	_current_ship_display.custom_minimum_size = Vector2(140, 140)
	_current_ship_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_current_ship_display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_current_ship_display)

	var ship: Resource = GameManager.get_ship_data()
	if ship:
		var hull_pct: float = float(GameManager.current_hull) / float(GameManager.max_hull)
		var shield_pct: float = float(GameManager.current_shield) / float(GameManager.max_shield) if GameManager.max_shield > 0 else 0.0
		_current_ship_display.update_ship(hull_pct, shield_pct, GameManager.get_cargo_used(), GameManager.cargo_capacity, ship.hull_shape)

		var name_lbl := Label.new()
		name_lbl.text = ship.ship_name
		name_lbl.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
		name_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_HEADING)
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
		_add_stat_pair(stats_grid, "Crew", "Max %d" % ship.max_crew)

		# Trade-in value
		if ship.cost > 0:
			var trade_in: int = int(ship.cost * 0.5)
			var trade_lbl := Label.new()
			trade_lbl.text = "Trade-in value: %d cr" % trade_in
			trade_lbl.add_theme_font_override("font", UIStyles.FONT_MONO)
			trade_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
			trade_lbl.add_theme_color_override("font_color", UIStyles.GOLD)
			trade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(trade_lbl)

	return panel


func _add_stat_pair(grid: GridContainer, stat_name: String, stat_value: String) -> void:
	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
	name_lbl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.7))
	grid.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = stat_value
	val_lbl.add_theme_font_override("font", UIStyles.FONT_MONO)
	val_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
	val_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(val_lbl)


func _refresh_ui() -> void:
	if _ship_list_container == null:
		return
	for child in _ship_list_container.get_children():
		child.queue_free()

	var current_ship: Resource = GameManager.get_ship_data()
	var all_ships: Array = ResourceRegistry.load_all(ResourceRegistry.SHIPS)

	for ship in all_ships:
		var is_owned: bool = GameManager.owns_ship(ship.resource_path)
		# Only restrict planet availability for ships the player doesn't already own —
		# owned ships can always be swapped in from the hangar.
		if not is_owned and ship.available_planet_types.size() > 0 and not (_planet_type in ship.available_planet_types):
			continue
		# Don't show the starter ship for purchase — unless it's still in the hangar
		if ship.cost == 0 and ship.resource_path != GameManager.current_ship and not is_owned:
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
	ship_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ship_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview_container.add_child(ship_preview)
	ship_preview.update_ship(1.0, 0.5, 0, ship.base_cargo_capacity, ship.hull_shape)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = ship.ship_name + ("  \u2605 EQUIPPED" if is_current else "")
	name_lbl.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	name_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_SUBHEADING)
	name_lbl.add_theme_color_override("font_color", UIStyles.ACCENT if is_current else Color(0.75, 0.88, 1.0))
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = ship.description
	desc_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
	desc_lbl.add_theme_color_override("font_color", Color(0.35, 0.55, 0.75))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	# Color-coded stat comparison
	var stats := _build_stat_comparison(ship, current_ship)
	info.add_child(stats)

	# Ship ability description
	var ability_lbl := _build_ability_label(ship)
	if ability_lbl:
		info.add_child(ability_lbl)

	# Action button column
	if not is_current and (ship.cost > 0 or GameManager.owns_ship(ship.resource_path)):
		var btn_col := VBoxContainer.new()
		btn_col.add_theme_constant_override("separation", 4)
		btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(btn_col)

		if GameManager.owns_ship(ship.resource_path):
			# Owned but not active → switch for transfer fee
			var fee: int = GameManager.SHIP_TRANSFER_FEE
			var price_lbl := Label.new()
			price_lbl.text = "%d cr" % fee
			price_lbl.add_theme_font_override("font", UIStyles.FONT_MONO)
			price_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
			price_lbl.add_theme_color_override("font_color", UIStyles.GOLD if GameManager.credits >= fee else Color(0.5, 0.3, 0.3))
			price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn_col.add_child(price_lbl)

			var fee_note := Label.new()
			fee_note.text = "(transfer fee)"
			fee_note.add_theme_font_size_override("font_size", UIStyles.FONT_MICRO)
			fee_note.add_theme_color_override("font_color", Color(0.5, 0.65, 0.45))
			fee_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn_col.add_child(fee_note)

			var switch_btn := Button.new()
			switch_btn.text = "SWITCH"
			switch_btn.custom_minimum_size = Vector2(100, 38)
			switch_btn.disabled = GameManager.credits < fee
			switch_btn.theme_type_variation = UIStyles.BTN_BUY
			switch_btn.pressed.connect(_on_switch_owned.bind(ship))
			btn_col.add_child(switch_btn)
		else:
			# Not owned → buy. Two flavors: keep old (full price) vs trade-in (-50% of old)
			var trade_in: int = int(current_ship.cost * 0.5)
			var net_cost: int = ship.cost - trade_in

			var price_lbl := Label.new()
			price_lbl.text = "%d cr" % ship.cost
			price_lbl.add_theme_font_override("font", UIStyles.FONT_MONO)
			price_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
			price_lbl.add_theme_color_override("font_color", UIStyles.GOLD if GameManager.credits >= ship.cost else Color(0.5, 0.3, 0.3))
			price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn_col.add_child(price_lbl)

			var buy_keep_btn := Button.new()
			buy_keep_btn.text = "BUY & KEEP OLD"
			buy_keep_btn.custom_minimum_size = Vector2(140, 32)
			buy_keep_btn.disabled = GameManager.credits < ship.cost
			buy_keep_btn.theme_type_variation = UIStyles.BTN_BUY
			buy_keep_btn.pressed.connect(_on_buy_ship.bind(ship, ship.cost, true))
			btn_col.add_child(buy_keep_btn)

			if trade_in > 0:
				var buy_trade_btn := Button.new()
				buy_trade_btn.text = "BUY & TRADE-IN (%d cr)" % net_cost
				buy_trade_btn.custom_minimum_size = Vector2(140, 32)
				buy_trade_btn.disabled = GameManager.credits < net_cost
				buy_trade_btn.theme_type_variation = UIStyles.BTN_BUY
				buy_trade_btn.pressed.connect(_on_buy_ship.bind(ship, net_cost, false))
				btn_col.add_child(buy_trade_btn)

	return card


func _build_stat_comparison(ship: Resource, current: Resource) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	_add_stat_chip(row, "Hull", ship.base_max_hull, ship.base_max_hull - current.base_max_hull)
	_add_stat_chip(row, "Shield", ship.base_max_shield, ship.base_max_shield - current.base_max_shield)
	_add_stat_chip(row, "Cargo", ship.base_cargo_capacity, ship.base_cargo_capacity - current.base_cargo_capacity)
	_add_stat_chip(row, "Crew", ship.max_crew, ship.max_crew - current.max_crew)
	var de: int = ship.base_energy_per_turn - current.base_energy_per_turn
	if de != 0:
		_add_stat_chip(row, "Energy", ship.base_energy_per_turn, de)
	var dhnd: int = ship.base_hand_size - current.base_hand_size
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

	if not specials.is_empty():
		var spec_lbl := Label.new()
		spec_lbl.text = " | ".join(specials)
		spec_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_MICRO)
		spec_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
		row.add_child(spec_lbl)

	return row


## Returns the ship's ability line, or null when the ship has no ability.
func _build_ability_label(ship: Resource) -> Label:
	if ship.ability_description == "":
		return null
	var ability_lbl := Label.new()
	ability_lbl.text = "⚡ " + ship.ability_description
	ability_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_MICRO)
	ability_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
	ability_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return ability_lbl


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
	chip.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
	chip.add_theme_color_override("font_color", col)
	container.add_child(chip)



## Guards both ship changes: a smaller hull cannot carry the current crew.
## Reports the failure on the status label and returns false.
func _crew_fits(ship: Resource, verb: String) -> bool:
	if GameManager.crew.size() <= ship.max_crew:
		return true
	_status_label.text = "Cannot %s: Crew size (%d) exceeds ship capacity (%d). Fire crew first!" % [
		verb, GameManager.crew.size(), ship.max_crew
	]
	return false


func _on_buy_ship(ship: Resource, cost: int, keep_old: bool) -> void:
	if not _crew_fits(ship, "buy"):
		return
	if not GameManager.remove_credits(cost):
		_status_label.text = "Not enough credits!"
		return
	AudioManager.play_purchase()
	var old_ship: Resource = GameManager.get_ship_data()
	var old_name: String = old_ship.ship_name if old_ship else ""
	GameManager.switch_ship(ship.resource_path, keep_old)

	if keep_old:
		EventLog.add_entry("Bought %s for %d cr (kept %s in hangar)" % [ship.ship_name, cost, old_name])
		_status_label.text = "Switched to %s (old ship stored in hangar)" % ship.ship_name
	else:
		var trade_in: int = int(old_ship.cost * 0.5) if old_ship else 0
		EventLog.add_entry("Bought %s for %d cr (trade-in: %d cr)" % [ship.ship_name, cost, trade_in])
		_status_label.text = "Switched to %s!" % ship.ship_name
	_refresh_ui()


func _on_switch_owned(ship: Resource) -> void:
	if not _crew_fits(ship, "switch"):
		return
	var fee: int = GameManager.SHIP_TRANSFER_FEE
	if not GameManager.remove_credits(fee):
		_status_label.text = "Not enough credits!"
		return
	AudioManager.play_purchase()
	GameManager.switch_ship(ship.resource_path, true)
	EventLog.add_entry("Switched to %s (transfer fee: %d cr)" % [ship.ship_name, fee])
	_status_label.text = "Switched to %s!" % ship.ship_name
	_refresh_ui()


func close() -> void:
	dealer_closed.emit()
	queue_free()
