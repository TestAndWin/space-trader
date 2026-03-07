extends ColorRect

## Market screen — fullscreen overlay for buying and selling goods.
## Consistent showroom-style with Casino, Ship Dealer, Ship Upgrades.

signal market_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const CargoSlotScene = preload("res://scenes/components/cargo_slot.tscn")
const GoodIcon = preload("res://scripts/components/good_icon.gd")

const PANEL_COLOR := Color(0.02, 0.06, 0.14, 0.45)
const BORDER_COLOR := Color(0.0, 0.55, 0.85, 0.35)
const ACCENT := Color(0.0, 0.9, 1.0)
const ACCENT_DIM := Color(0.0, 0.45, 0.75, 0.6)

const TYPE_COLORS = {
	0: Color(0.4, 0.6, 1.0),
	1: Color(0.4, 0.9, 0.4),
	2: Color(0.9, 0.6, 0.3),
	3: Color(0.3, 0.9, 1.0),
	4: Color(1.0, 0.3, 0.3),
}

const MARKET_NAMES = {
	0: "CYBER MARKET",
	1: "FARM STAND",
	2: "MINING EXCHANGE",
	3: "TRADE HUB",
	4: "BLACK MARKET",
}

const MARKET_FLAVOR = {
	0: "Factory surplus and manufactured goods",
	1: "Fresh produce and organic supplies",
	2: "Extracted minerals and heavy equipment",
	3: "Cutting-edge technology and research materials",
	4: "No questions asked. Contraband welcome.",
}

const MARKET_ICONS = {
	0: "\u25C8",  # ◈
	1: "\u2618",  # ☘
	2: "\u26CF",  # ⛏
	3: "\u2699",  # ⚙
	4: "\u2620",  # ☠
}

var _planet_type: int = 0
var _arrival_gained_cargo: Dictionary = {}
var _credits_label: Label
var _cargo_label: Label
var _market_list: VBoxContainer
var _cargo_list: VBoxContainer
var _status_label: Label

func setup(planet_type: int, arrival_gained_cargo: Dictionary = {}) -> void:
	_planet_type = planet_type
	_arrival_gained_cargo = arrival_gained_cargo
	_refresh_all()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.0)
	_build_ui()


func _build_ui() -> void:
	# Background image
	_add_building_background("market")

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
	header.z_index = 10
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	main_vbox.add_child(header)

	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 0)
	header.add_child(title_vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_vbox.add_child(title_row)

	var left_deco := Label.new()
	left_deco.text = MARKET_ICONS.get(_planet_type, "\u25C8")
	left_deco.add_theme_font_size_override("font_size", 16)
	left_deco.add_theme_color_override("font_color", ACCENT_DIM)
	title_row.add_child(left_deco)

	var title := Label.new()
	title.text = MARKET_NAMES.get(_planet_type, "MARKET")
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", TYPE_COLORS.get(_planet_type, ACCENT))
	title_row.add_child(title)

	var right_deco := Label.new()
	right_deco.text = MARKET_ICONS.get(_planet_type, "\u25C8")
	right_deco.add_theme_font_size_override("font_size", 16)
	right_deco.add_theme_color_override("font_color", ACCENT_DIM)
	title_row.add_child(right_deco)

	var subtitle := Label.new()
	subtitle.text = MARKET_FLAVOR.get(_planet_type, "")
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

	_cargo_label = Label.new()
	_cargo_label.add_theme_font_size_override("font_size", 16)
	_cargo_label.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))
	header.add_child(_cargo_label)

	var close_btn := Button.new()
	close_btn.text = "Leave Market"
	close_btn.custom_minimum_size = Vector2(140, 36)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyles.style_accent_button(close_btn, Color(0.5, 0.15, 0.1))
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_color_override("separator", ACCENT_DIM)
	main_vbox.add_child(sep)

	# Status
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.6))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_status_label)

	# Spacer to push content to lower half
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(top_spacer)

	# ── Content: Market (left) + Cargo (right) ──
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	main_vbox.add_child(content)

	# Market panel (Buy side)
	var market_panel := PanelContainer.new()
	market_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var market_style := StyleBoxFlat.new()
	market_style.bg_color = Color(0.015, 0.04, 0.10, 0.5)
	market_style.border_color = ACCENT_DIM
	market_style.set_border_width_all(1)
	market_style.set_corner_radius_all(8)
	market_style.set_content_margin_all(8)
	market_panel.add_theme_stylebox_override("panel", market_style)
	content.add_child(market_panel)

	var market_vbox := VBoxContainer.new()
	market_vbox.add_theme_constant_override("separation", 6)
	market_panel.add_child(market_vbox)

	var market_header := Label.new()
	market_header.text = "\u25C6 BUY GOODS \u25C6"
	market_header.add_theme_font_size_override("font_size", 16)
	market_header.add_theme_color_override("font_color", TYPE_COLORS.get(_planet_type, ACCENT))
	market_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	market_vbox.add_child(market_header)

	var market_scroll := ScrollContainer.new()
	market_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	market_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	market_vbox.add_child(market_scroll)

	_market_list = VBoxContainer.new()
	_market_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_list.add_theme_constant_override("separation", 2)
	market_scroll.add_child(_market_list)

	# Cargo panel (Sell side)
	var cargo_panel := PanelContainer.new()
	cargo_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cargo_style := market_style.duplicate()
	cargo_panel.add_theme_stylebox_override("panel", cargo_style)
	content.add_child(cargo_panel)

	var cargo_vbox := VBoxContainer.new()
	cargo_vbox.add_theme_constant_override("separation", 6)
	cargo_panel.add_child(cargo_vbox)

	var cargo_header := Label.new()
	cargo_header.text = "\u25C6 SELL CARGO \u25C6"
	cargo_header.add_theme_font_size_override("font_size", 16)
	cargo_header.add_theme_color_override("font_color", Color(0.0, 0.85, 0.45))
	cargo_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cargo_vbox.add_child(cargo_header)

	var cargo_scroll := ScrollContainer.new()
	cargo_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cargo_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cargo_vbox.add_child(cargo_scroll)

	_cargo_list = VBoxContainer.new()
	_cargo_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cargo_list.add_theme_constant_override("separation", 2)
	cargo_scroll.add_child(_cargo_list)


func _refresh_all() -> void:
	if not _credits_label:
		return
	_credits_label.text = "%d cr" % GameManager.credits
	var used: int = GameManager.get_cargo_used()
	var cap: int = GameManager.cargo_capacity
	_cargo_label.text = "Cargo: %d/%d" % [used, cap]
	_populate_market()
	_populate_cargo()


func _populate_market() -> void:
	for child in _market_list.get_children():
		child.queue_free()
	var planet_name: String = GameManager.current_planet
	for good in EconomyManager.goods:
		var good_name: String = good.good_name
		var buy_price: int = EconomyManager.get_buy_price(planet_name, good_name)
		if buy_price < 0:
			continue
		var slot := CargoSlotScene.instantiate()
		_market_list.add_child(slot)
		var avg: int = EconomyManager.get_average_price(good_name)
		slot.setup(good_name, buy_price, 0, "buy", avg)
		slot.action_pressed.connect(_on_buy)


func _populate_cargo() -> void:
	for child in _cargo_list.get_children():
		child.queue_free()
	var has_rows: bool = false
	var planet_name: String = GameManager.current_planet
	for item in GameManager.cargo:
		var good_name: String = item["good_name"]
		var qty: int = item["quantity"]
		# Reduce sellable quantity by goods gained on arrival this visit.
		var blocked: int = mini(_arrival_gained_cargo.get(good_name, 0), qty)
		var sellable_qty: int = maxi(qty - blocked, 0)
		var sell_price: int = EconomyManager.get_sell_price(planet_name, good_name)
		if sell_price < 0:
			sell_price = 0
		var avg_sell: int = EconomyManager.get_average_price(good_name)
		if avg_sell > 0:
			avg_sell = int(round(avg_sell * EconomyManager.SELL_RATIO))
		if sellable_qty > 0:
			var slot := CargoSlotScene.instantiate()
			_cargo_list.add_child(slot)
			slot.setup(good_name, sell_price, sellable_qty, "sell", avg_sell)
			slot.action_pressed.connect(_on_sell)
			has_rows = true
		if blocked > 0:
			var locked_slot := CargoSlotScene.instantiate()
			_cargo_list.add_child(locked_slot)
			locked_slot.setup(good_name, sell_price, blocked, "sell", avg_sell, false, "(arrival)")
			has_rows = true

	if not has_rows:
		var empty_lbl := Label.new()
		empty_lbl.text = "Cargo hold is empty"
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.42, 0.45))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cargo_list.add_child(empty_lbl)


func _on_buy(good_name: String, quantity: int) -> void:
	var planet_name: String = GameManager.current_planet
	var buy_price: int = EconomyManager.get_buy_price(planet_name, good_name)
	if buy_price < 0:
		return
	var total_cost: int = buy_price * quantity
	if not GameManager.can_add_cargo(good_name, quantity):
		return
	if not GameManager.remove_credits(total_cost):
		return
	GameManager.add_cargo(good_name, quantity)
	GameManager.total_trades += 1
	EventLog.add_entry("Bought %d %s for %d cr" % [quantity, good_name, total_cost])
	_status_label.text = "Bought %d %s for %d cr" % [quantity, good_name, total_cost]
	_refresh_all()


func _on_sell(good_name: String, quantity: int) -> void:
	var planet_name: String = GameManager.current_planet
	var sell_price: int = EconomyManager.get_sell_price(planet_name, good_name)
	if sell_price < 0:
		return
	var total_income: int = sell_price * quantity
	GameManager.remove_cargo(good_name, quantity)
	GameManager.add_credits(total_income)
	GameManager.total_trades += 1
	EventLog.add_entry("Sold %d %s for %d cr" % [quantity, good_name, total_income])
	_status_label.text = "Sold %d %s for %d cr" % [quantity, good_name, total_income]
	_refresh_all()
	if GameManager.check_win_condition():
		get_tree().change_scene_to_file("res://scenes/victory.tscn")


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
		# Dim overlay so UI remains readable
		var dim := ColorRect.new()
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.0, 0.0, 0.0, 0.4)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)


func _close() -> void:
	# Close first so the overlay always disappears, even if listeners error.
	queue_free()
	market_closed.emit()
