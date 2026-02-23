extends ColorRect

## Ship dealer popup — buy and switch ships at planets.
## Full-screen immersive style matching Casino and Ship Upgrades.

signal dealer_closed

const BG_COLOR := Color(0.04, 0.06, 0.14)
const PANEL_COLOR := Color(0.06, 0.08, 0.16)
const BORDER_COLOR := Color(0.15, 0.25, 0.5, 0.8)
const ACCENT := Color(0.3, 0.5, 1.0)
const ACCENT_DIM := Color(0.2, 0.35, 0.7, 0.6)
const GOLD := Color(1.0, 0.95, 0.4)

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
	color = Color(0, 0, 0, 0.75)
	_build_ui()


func _build_ui() -> void:
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
	title.text = "SHIP DEALER"
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
	close_btn.pressed.connect(_close)
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

	# Current ship info
	var current_label := Label.new()
	current_label.text = "Current ship: %s" % _get_current_ship_name()
	current_label.add_theme_font_size_override("font_size", 16)
	current_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
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
	var card_style := StyleBoxFlat.new()
	var is_current: bool = ship.resource_path == GameManager.current_ship
	card_style.bg_color = Color(0.08, 0.12, 0.22, 0.9) if is_current else Color(0.08, 0.1, 0.18, 0.8)
	card_style.border_color = ACCENT if is_current else Color(0.2, 0.25, 0.4, 0.6)
	card_style.set_border_width_all(1 if not is_current else 2)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", card_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Ship preview
	var ship_preview := ShipDisplayScene.instantiate()
	ship_preview.custom_minimum_size = Vector2(70, 70)
	hbox.add_child(ship_preview)
	ship_preview.update_ship(1.0, 0.5, 0, ship.base_cargo_capacity, ship.hull_shape)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = ship.ship_name + (" (CURRENT)" if is_current else "")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", ACCENT if is_current else Color(0.8, 0.85, 0.95))
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = ship.description
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	# Stat comparison
	var stats := _build_stat_comparison(ship, current_ship)
	stats.add_theme_font_size_override("font_size", 12)
	info.add_child(stats)

	# Buy button
	if not is_current and ship.cost > 0:
		var trade_in: int = int(current_ship.cost * 0.5)
		var net_cost: int = ship.cost - trade_in
		var btn := Button.new()
		btn.text = "Buy (%dcr)" % net_cost
		btn.custom_minimum_size = Vector2(120, 36)
		btn.disabled = GameManager.credits < net_cost
		_style_buy_button(btn)
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
	lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.75))
	return lbl


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


func _close() -> void:
	dealer_closed.emit()
	queue_free()
