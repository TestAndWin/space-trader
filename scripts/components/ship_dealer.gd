extends ColorRect

## Ship dealer popup — buy and switch ships at planets.

signal dealer_closed

var _planet_type: int = 0
var _ship_list_container: VBoxContainer
var _credits_label: Label
var _status_label: Label
var ShipDisplayScene := preload("res://scenes/components/ship_display.tscn")


func setup(planet_type: int) -> void:
	_planet_type = planet_type
	_refresh_ui()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 460)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	style.border_color = Color(0.5, 0.7, 0.4, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(main_vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header)

	var title := Label.new()
	title.text = "SHIP DEALER"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.5, 0.8, 0.4))
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 16)
	_credits_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	header.add_child(_credits_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_status_label)

	# Current ship info
	var current_label := Label.new()
	current_label.text = "Current ship: %s" % _get_current_ship_name()
	current_label.add_theme_font_size_override("font_size", 14)
	current_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(current_label)

	# Ship list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	_ship_list_container = VBoxContainer.new()
	_ship_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_ship_list_container)


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
	var style := StyleBoxFlat.new()
	var is_current: bool = ship.resource_path == GameManager.current_ship
	style.bg_color = Color(0.12, 0.15, 0.1, 0.9) if is_current else Color(0.1, 0.1, 0.14, 0.9)
	style.border_color = Color(0.4, 0.6, 0.3) if is_current else Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Ship preview
	var ship_preview := ShipDisplayScene.instantiate()
	ship_preview.custom_minimum_size = Vector2(60, 60)
	hbox.add_child(ship_preview)
	ship_preview.update_ship(1.0, 0.5, 0, ship.base_cargo_capacity, ship.hull_shape)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = ship.ship_name + (" (CURRENT)" if is_current else "")
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85) if is_current else Color(0.8, 0.8, 0.85))
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = ship.description
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	# Stat comparison
	var stats := _build_stat_comparison(ship, current_ship)
	stats.add_theme_font_size_override("font_size", 11)
	info.add_child(stats)

	# Buy button
	if not is_current and ship.cost > 0:
		var trade_in: int = int(current_ship.cost * 0.5)
		var net_cost: int = ship.cost - trade_in
		var btn := Button.new()
		btn.text = "Buy (%dcr)" % net_cost
		btn.custom_minimum_size = Vector2(90, 30)
		btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = GameManager.credits < net_cost
		btn.pressed.connect(_on_buy_ship.bind(ship, net_cost))
		hbox.add_child(btn)

	return card


func _build_stat_comparison(ship: Resource, current: Resource) -> Label:
	var lbl := Label.new()
	var parts: Array = []

	var dh: int = ship.base_max_hull - current.base_max_hull
	var ds: int = ship.base_max_shield - current.base_max_shield
	var dc: int = ship.base_cargo_capacity - current.base_cargo_capacity
	var de: int = ship.base_energy_per_turn - current.base_energy_per_turn
	var dhnd: int = ship.base_hand_size - current.base_hand_size

	parts.append("Hull: %d (%s%d)" % [ship.base_max_hull, "+" if dh >= 0 else "", dh])
	parts.append("Shield: %d (%s%d)" % [ship.base_max_shield, "+" if ds >= 0 else "", ds])
	parts.append("Cargo: %d (%s%d)" % [ship.base_cargo_capacity, "+" if dc >= 0 else "", dc])
	if de != 0:
		parts.append("Energy: %s%d" % ["+" if de >= 0 else "", de])
	if dhnd != 0:
		parts.append("Hand Size: %s%d" % ["+" if dhnd >= 0 else "", dhnd])

	var specials: Array = []
	if ship.encounter_reduction > 0:
		specials.append("-%d%% Encounters" % int(ship.encounter_reduction * 100))
	if ship.contraband_bonus > 0:
		specials.append("+%d%% Contraband" % int(ship.contraband_bonus * 100))
	if ship.quest_reward_bonus > 0:
		specials.append("+%d%% Quest Reward" % int(ship.quest_reward_bonus * 100))

	lbl.text = " | ".join(parts)
	if specials.size() > 0:
		lbl.text += "\n" + ", ".join(specials)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	return lbl


func _on_buy_ship(ship: Resource, net_cost: int) -> void:
	if not GameManager.remove_credits(net_cost):
		_status_label.text = "Not enough credits!"
		return
	# Trade-in is handled inside switch_ship (adds back 50% of old ship cost)
	# But we already subtracted net_cost which accounts for trade-in, so we
	# need to adjust: switch_ship adds trade_in, but we already subtracted it
	# from net_cost. So we need to undo the trade-in addition from switch_ship.
	var old_ship: Resource = GameManager.get_ship_data()
	var trade_in: int = int(old_ship.cost * 0.5)
	# Temporarily remove the trade-in credits that switch_ship will add
	GameManager.switch_ship(ship.resource_path)
	# switch_ship already added trade_in credits, but we accounted for it in net_cost
	# so remove the duplicate
	GameManager.remove_credits(trade_in)

	EventLog.add_entry("Bought %s for %d cr (trade-in: %d cr)" % [ship.ship_name, net_cost, trade_in])
	_status_label.text = "Switched to %s!" % ship.ship_name
	_refresh_ui()


func _close() -> void:
	dealer_closed.emit()
	queue_free()
