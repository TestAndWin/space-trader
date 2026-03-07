extends Control

## Deck viewer with integrated card trading when on a planet.
## Full-screen immersive style with showroom background.

const CardDisplayScene = preload("res://scenes/components/card_display.tscn")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

const PANEL_COLOR := Color(0.02, 0.06, 0.14, 0.45)
const BORDER_COLOR := Color(0.0, 0.65, 0.95, 0.35)
const ACCENT := Color(0.0, 0.9, 1.0)
const ACCENT_DIM := Color(0.0, 0.45, 0.75, 0.6)
const GOLD := Color(1.0, 0.90, 0.25)

const MIN_DECK_SIZE: int = 5
const SELL_RATIO: float = 0.5

const PRICE_RANGES: Dictionary = {
	0: Vector2i(50, 80),    # COMMON
	1: Vector2i(120, 200),  # UNCOMMON
	2: Vector2i(250, 400),  # RARE
}

const TYPE_WEIGHTS: Dictionary = {
	0: [1, 3],     # Industrial → DEFENSE, TRADE
	1: [2, 1],     # Agricultural → UTILITY, DEFENSE
	2: [0, 1],     # Mining → ATTACK, DEFENSE
	3: [2, 3],     # Tech → UTILITY, TRADE
	4: [0, 2],     # Outlaw → ATTACK, UTILITY
}

var _trading_enabled: bool = false
var _planet_type: int = 0
var _shop_cards: Array = []  # Array of { card: Resource, price: int }
var _shop_grid: GridContainer
var _shop_section: VBoxContainer
var _status_label: Label
var _credits_label: Label
var _title_label: Label
var _card_grid: GridContainer
var _main_vbox: VBoxContainer


func setup(planet_type: int = -1) -> void:
	if planet_type >= 0:
		_trading_enabled = true
		_planet_type = planet_type
		_generate_shop()


func _ready() -> void:
	_build_ui()
	_populate_deck()


func _generate_shop() -> void:
	_shop_cards.clear()
	var all_cards: Array = ResourceRegistry.load_all(ResourceRegistry.CARDS)
	if all_cards.is_empty():
		return
	var preferred: Array = TYPE_WEIGHTS.get(_planet_type, [0])
	var weighted: Array = []
	for card in all_cards:
		var weight: int = 1
		if card.card_type in preferred:
			weight = 3
		for i in weight:
			weighted.append(card)
	weighted.shuffle()
	var picked: Array = []
	for card in weighted:
		if card in picked:
			continue
		picked.append(card)
		var price_range: Vector2i = PRICE_RANGES.get(card.rarity, Vector2i(50, 80))
		var price: int = randi_range(price_range.x, price_range.y)
		_shop_cards.append({ "card": card, "price": price })
		if picked.size() >= 5:
			break


func _build_ui() -> void:
	# Dim background (click blocker)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# Background image
	_add_building_background("deck")

	# Semi-transparent main panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_main_vbox = VBoxContainer.new()
	_main_vbox.add_theme_constant_override("separation", 4)
	panel.add_child(_main_vbox)

	# ── Header ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_main_vbox.add_child(header)

	# Title section with subtitle
	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 0)
	header.add_child(title_vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_vbox.add_child(title_row)

	var left_deco := Label.new()
	left_deco.text = "\u2726 \u2660 \u2726"
	left_deco.add_theme_font_size_override("font_size", 16)
	left_deco.add_theme_color_override("font_color", ACCENT_DIM)
	title_row.add_child(left_deco)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", ACCENT)
	title_row.add_child(_title_label)

	var right_deco := Label.new()
	right_deco.text = "\u2726 \u2660 \u2726"
	right_deco.add_theme_font_size_override("font_size", 16)
	right_deco.add_theme_color_override("font_color", ACCENT_DIM)
	title_row.add_child(right_deco)

	var subtitle := Label.new()
	if _trading_enabled:
		subtitle.text = "View & Trade Cards \u2022 Sell Unwanted \u2022 Buy New Strategies"
	else:
		subtitle.text = "Review Your Battle Cards \u2022 Plan Your Strategy"
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

	if _trading_enabled:
		_credits_label = Label.new()
		_credits_label.add_theme_font_size_override("font_size", 20)
		_credits_label.add_theme_color_override("font_color", GOLD)
		header.add_child(_credits_label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(90, 36)
	_style_action_button(close_btn, Color(0.5, 0.15, 0.1))
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	sep.add_theme_color_override("separator", ACCENT_DIM)
	_main_vbox.add_child(sep)

	# Status label (trading only)
	if _trading_enabled:
		_status_label = Label.new()
		_status_label.add_theme_font_size_override("font_size", 14)
		_status_label.add_theme_color_override("font_color", Color(0.0, 0.85, 0.45))
		_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_main_vbox.add_child(_status_label)

	# Deck grid in scroll
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_vbox.add_child(scroll)

	_card_grid = GridContainer.new()
	_card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_grid.add_theme_constant_override("h_separation", 8)
	_card_grid.add_theme_constant_override("v_separation", 8)
	_card_grid.columns = 6
	scroll.add_child(_card_grid)

	# Shop section (below deck, trading only)
	if _trading_enabled and _shop_cards.size() > 0:
		var shop_sep := HSeparator.new()
		shop_sep.add_theme_constant_override("separation", 6)
		shop_sep.add_theme_color_override("separator", ACCENT_DIM)
		_main_vbox.add_child(shop_sep)

		_shop_section = VBoxContainer.new()
		_shop_section.add_theme_constant_override("separation", 6)
		_main_vbox.add_child(_shop_section)

		var shop_label := Label.new()
		shop_label.text = "\u25C6 FOR SALE \u25C6"
		shop_label.add_theme_font_size_override("font_size", 16)
		shop_label.add_theme_color_override("font_color", ACCENT)
		shop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_section.add_child(shop_label)

		var shop_scroll := ScrollContainer.new()
		shop_scroll.custom_minimum_size = Vector2(0, 180)
		shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_shop_section.add_child(shop_scroll)

		_shop_grid = GridContainer.new()
		_shop_grid.columns = 10
		_shop_grid.add_theme_constant_override("h_separation", 10)
		_shop_grid.add_theme_constant_override("v_separation", 10)
		shop_scroll.add_child(_shop_grid)

		_populate_shop()


func _populate_shop() -> void:
	if not _shop_grid:
		return
	for child in _shop_grid.get_children():
		child.queue_free()
	for entry in _shop_cards:
		var card: Resource = entry["card"]
		var price: int = entry["price"]
		var can_buy: bool = GameManager.credits >= price
		var card_display := CardDisplayScene.instantiate()
		card_display.custom_minimum_size = Vector2(130, 160)
		_shop_grid.add_child(card_display)
		card_display.setup(card, can_buy, "Buy (%dcr)" % price, true)
		if not can_buy:
			card_display.modulate.a = 0.5
		card_display.card_played.connect(_on_buy_card.bind(entry))


func _populate_deck() -> void:
	for child in _card_grid.get_children():
		child.queue_free()

	var card_counts: Dictionary = {}
	for card in GameManager.deck:
		var cname: String = card.card_name
		if card_counts.has(cname):
			card_counts[cname]["count"] += 1
		else:
			card_counts[cname] = {"resource": card, "count": 1}

	_title_label.text = "YOUR DECK (%d cards)" % GameManager.deck.size()
	if _credits_label:
		_credits_label.text = "%d cr" % GameManager.credits

	for card_name in card_counts:
		var entry: Dictionary = card_counts[card_name]
		var card: Resource = entry["resource"]
		var count: int = entry["count"]

		if _trading_enabled:
			var sell_price: int = _get_sell_price(card)
			var can_sell: bool = GameManager.deck.size() > MIN_DECK_SIZE
			var card_display := CardDisplayScene.instantiate()
			card_display.custom_minimum_size = Vector2(130, 160)
			_card_grid.add_child(card_display)
			card_display.setup(card, can_sell, "Sell (%dcr)" % sell_price, true)
			card_display.modulate.a = 1.0
			card_display.card_played.connect(_on_sell_card.bind(sell_price))
			if count > 1:
				var count_label := Label.new()
				count_label.text = "x%d" % count
				count_label.add_theme_font_size_override("font_size", 16)
				count_label.add_theme_color_override("font_color", GOLD)
				count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				card_display.get_node("VBoxContainer").add_child(count_label)
		else:
			var card_display := CardDisplayScene.instantiate()
			card_display.custom_minimum_size = Vector2(130, 160)
			_card_grid.add_child(card_display)
			card_display.setup(card, false, "", false)
			card_display.modulate.a = 1.0
			if count > 1:
				var count_label := Label.new()
				count_label.text = "x%d" % count
				count_label.add_theme_font_size_override("font_size", 16)
				count_label.add_theme_color_override("font_color", GOLD)
				count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				card_display.get_node("VBoxContainer").add_child(count_label)


func _get_sell_price(card: Resource) -> int:
	var price_range: Vector2i = PRICE_RANGES.get(card.rarity, Vector2i(50, 80))
	var avg: int = int((price_range.x + price_range.y) / 2.0)
	return int(avg * SELL_RATIO)


func _on_buy_card(_card_data: Resource, entry: Dictionary) -> void:
	var card: Resource = entry["card"]
	var price: int = entry["price"]
	if not GameManager.remove_credits(price):
		_status_label.text = "Not enough credits!"
		return
	GameManager.deck.append(card)
	for i in _shop_cards.size():
		if _shop_cards[i]["card"] == card:
			_shop_cards.remove_at(i)
			break
	EventLog.add_entry("Bought card %s for %d cr" % [card.card_name, price])
	_status_label.text = "Bought %s!" % card.card_name
	_refresh_all()


func _on_sell_card(card_data: Resource, sell_price: int) -> void:
	if GameManager.deck.size() <= MIN_DECK_SIZE:
		_status_label.text = "Deck minimum reached (%d cards)!" % MIN_DECK_SIZE
		return
	for i in GameManager.deck.size():
		if GameManager.deck[i].resource_path == card_data.resource_path:
			GameManager.deck.remove_at(i)
			break
	GameManager.add_credits(sell_price)
	EventLog.add_entry("Sold card %s for %d cr" % [card_data.card_name, sell_price])
	_status_label.text = "Sold %s!" % card_data.card_name
	_refresh_all()


func _refresh_all() -> void:
	_populate_shop()
	_populate_deck()


func _style_action_button(btn: Button, accent: Color) -> void:
	UIStyles.style_accent_button(btn, accent)


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
		var bg_dim := ColorRect.new()
		bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_dim.color = Color(0.0, 0.0, 0.0, 0.4)
		bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_dim)


func _on_close_pressed() -> void:
	queue_free()
