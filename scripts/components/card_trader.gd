extends ColorRect

## Card trader popup — buy and sell combat cards at planets.

signal trader_closed

const MIN_DECK_SIZE: int = 5
const SELL_RATIO: float = 0.5

# Rarity pricing ranges
const PRICE_RANGES: Dictionary = {
	0: Vector2i(50, 80),    # COMMON
	1: Vector2i(120, 200),  # UNCOMMON
	2: Vector2i(250, 400),  # RARE
}

# Planet type → preferred card types (CardType enum values)
const TYPE_WEIGHTS: Dictionary = {
	0: [1, 3],     # Industrial → DEFENSE, TRADE
	1: [2, 1],     # Agricultural → UTILITY, DEFENSE
	2: [0, 1],     # Mining → ATTACK, DEFENSE
	3: [2, 3],     # Tech → UTILITY, TRADE
	4: [0, 2],     # Outlaw → ATTACK, UTILITY
}

var _planet_type: int = 0
var _shop_cards: Array = []  # Array of { card: Resource, price: int }
var _shop_container: VBoxContainer
var _deck_container: VBoxContainer
var _credits_label: Label
var _status_label: Label


func setup(planet_type: int) -> void:
	_planet_type = planet_type
	_generate_shop()
	_refresh_ui()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 500)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	style.border_color = Color(0.4, 0.6, 1.0, 0.8)
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
	title.text = "CARD TRADER"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
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

	# Status
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_status_label)

	# Shop section
	var shop_label := Label.new()
	shop_label.text = "FOR SALE"
	shop_label.add_theme_font_size_override("font_size", 14)
	shop_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	main_vbox.add_child(shop_label)

	var shop_scroll := ScrollContainer.new()
	shop_scroll.custom_minimum_size = Vector2(0, 160)
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(shop_scroll)

	_shop_container = VBoxContainer.new()
	_shop_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_container.add_theme_constant_override("separation", 4)
	shop_scroll.add_child(_shop_container)

	# Deck section
	var deck_label := Label.new()
	deck_label.text = "YOUR DECK (sell)"
	deck_label.add_theme_font_size_override("font_size", 14)
	deck_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	main_vbox.add_child(deck_label)

	var deck_scroll := ScrollContainer.new()
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(deck_scroll)

	_deck_container = VBoxContainer.new()
	_deck_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_container.add_theme_constant_override("separation", 4)
	deck_scroll.add_child(_deck_container)


func _refresh_ui() -> void:
	if not _credits_label:
		return
	_credits_label.text = "%d cr" % GameManager.credits

	# Shop cards
	for child in _shop_container.get_children():
		child.queue_free()
	for entry in _shop_cards:
		var card: Resource = entry["card"]
		var price: int = entry["price"]
		var row := _create_card_row(card, price, true)
		_shop_container.add_child(row)

	# Deck cards
	for child in _deck_container.get_children():
		child.queue_free()
	# Group deck cards by resource path
	var card_counts: Dictionary = {}
	for card in GameManager.deck:
		var path: String = card.resource_path
		if path not in card_counts:
			card_counts[path] = { "card": card, "count": 0 }
		card_counts[path]["count"] += 1
	for path in card_counts:
		var info: Dictionary = card_counts[path]
		var card: Resource = info["card"]
		var count: int = info["count"]
		var sell_price: int = _get_sell_price(card)
		var row := _create_card_row(card, sell_price, false, count)
		_deck_container.add_child(row)


func _create_card_row(card: Resource, price: int, is_buy: bool, count: int = 0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	# Type color indicator
	var type_colors: Array = [
		Color(0.9, 0.3, 0.3),  # ATTACK
		Color(0.3, 0.5, 0.9),  # DEFENSE
		Color(0.3, 0.8, 0.4),  # UTILITY
		Color(1.0, 0.85, 0.3), # TRADE
	]
	var indicator := ColorRect.new()
	indicator.custom_minimum_size = Vector2(4, 0)
	indicator.color = type_colors[card.card_type] if card.card_type < type_colors.size() else Color.WHITE
	row.add_child(indicator)

	# Card name + info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)

	var name_lbl := Label.new()
	var rarity_tags: Array = ["C", "U", "R"]
	var rarity_tag: String = rarity_tags[card.rarity] if card.rarity < rarity_tags.size() else "?"
	var count_text: String = " x%d" % count if count > 1 else ""
	name_lbl.text = "[%s] %s%s" % [rarity_tag, card.card_name, count_text]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	var type_names: Array = ["ATK", "DEF", "UTL", "TRD"]
	var type_name: String = type_names[card.card_type] if card.card_type < type_names.size() else "?"
	var stats: String = "%s | E:%d" % [type_name, card.energy_cost]
	if card.attack_value > 0:
		stats += " DMG:%d" % card.attack_value
	if card.defense_value > 0:
		stats += " SHD:%d" % card.defense_value
	if card.heal_value > 0:
		stats += " HEAL:%d" % card.heal_value
	if card.draw_cards > 0:
		stats += " DRAW:%d" % card.draw_cards
	desc_lbl.text = stats
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	info.add_child(desc_lbl)

	# Price + button
	var btn := Button.new()
	if is_buy:
		btn.text = "Buy (%dcr)" % price
		btn.disabled = GameManager.credits < price
		btn.pressed.connect(_on_buy_card.bind(card, price))
	else:
		var sell_price: int = price
		btn.text = "Sell (%dcr)" % sell_price
		btn.disabled = GameManager.deck.size() <= MIN_DECK_SIZE
		btn.pressed.connect(_on_sell_card.bind(card, sell_price))
	btn.add_theme_font_size_override("font_size", 11)
	btn.custom_minimum_size = Vector2(90, 0)
	row.add_child(btn)

	return row


func _get_sell_price(card: Resource) -> int:
	var price_range: Vector2i = PRICE_RANGES.get(card.rarity, Vector2i(50, 80))
	var avg: int = int((price_range.x + price_range.y) / 2.0)
	return int(avg * SELL_RATIO)


func _on_buy_card(card: Resource, price: int) -> void:
	if not GameManager.remove_credits(price):
		_status_label.text = "Not enough credits!"
		return
	GameManager.deck.append(card)
	# Remove from shop
	for i in _shop_cards.size():
		if _shop_cards[i]["card"] == card:
			_shop_cards.remove_at(i)
			break
	EventLog.add_entry("Bought card %s for %d cr" % [card.card_name, price])
	_status_label.text = "Bought %s!" % card.card_name
	_refresh_ui()


func _on_sell_card(card: Resource, price: int) -> void:
	if GameManager.deck.size() <= MIN_DECK_SIZE:
		_status_label.text = "Deck minimum reached (%d cards)!" % MIN_DECK_SIZE
		return
	# Remove one instance of this card from deck
	for i in GameManager.deck.size():
		if GameManager.deck[i].resource_path == card.resource_path:
			GameManager.deck.remove_at(i)
			break
	GameManager.add_credits(price)
	EventLog.add_entry("Sold card %s for %d cr" % [card.card_name, price])
	_status_label.text = "Sold %s!" % card.card_name
	_refresh_ui()


func _close() -> void:
	trader_closed.emit()
	queue_free()
