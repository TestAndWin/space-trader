extends Control

## Deck viewer with integrated card trading when on a planet.
## Shows deck cards in a grid with CardDisplay components.
## When trading is enabled, adds a shop row and sell buttons on deck cards.

const CardDisplayScene = preload("res://scenes/components/card_display.tscn")

const SECONDARY_BG := Color(0.1, 0.12, 0.16)
const SECONDARY_BORDER := Color(0.35, 0.38, 0.42, 0.7)

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


func setup(planet_type: int = -1) -> void:
	if planet_type >= 0:
		_trading_enabled = true
		_planet_type = planet_type
		_generate_shop()


func _ready() -> void:
	if _trading_enabled:
		_build_trading_ui()
	_populate_deck()
	_style_close_button()
	%CloseButton.pressed.connect(_on_close_pressed)


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


func _build_trading_ui() -> void:
	var main_vbox: VBoxContainer = %CloseButton.get_parent().get_parent()

	# Credits label in header (before CloseButton's parent Footer)
	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 16)
	_credits_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	_credits_label.text = "%d cr" % GameManager.credits
	# Insert credits label into the title row
	var title_label: Label = %TitleLabel
	var title_parent: Node = title_label.get_parent()
	# Add a spacer and credits label after the title
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_parent.add_child(spacer)
	title_parent.move_child(spacer, 1)
	title_parent.add_child(_credits_label)
	title_parent.move_child(_credits_label, 2)

	# Status label
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_status_label)
	main_vbox.move_child(_status_label, 1)

	# Shop section — inserted after the deck ScrollContainer, before Footer
	if _shop_cards.size() > 0:
		var footer: Node = %CloseButton.get_parent()
		var footer_idx: int = footer.get_index()

		# Separator
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 4)
		main_vbox.add_child(sep)
		main_vbox.move_child(sep, footer_idx)

		_shop_section = VBoxContainer.new()
		_shop_section.add_theme_constant_override("separation", 6)
		main_vbox.add_child(_shop_section)
		main_vbox.move_child(_shop_section, footer_idx + 1)

		var shop_label := Label.new()
		shop_label.text = "FOR SALE"
		shop_label.add_theme_font_size_override("font_size", 14)
		shop_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		_shop_section.add_child(shop_label)

		var shop_scroll := ScrollContainer.new()
		shop_scroll.custom_minimum_size = Vector2(0, 180)
		shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_shop_section.add_child(shop_scroll)

		_shop_grid = GridContainer.new()
		_shop_grid.columns = 10  # horizontal row
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
	# Clear existing cards
	for child in %CardGrid.get_children():
		child.queue_free()

	# Count duplicates
	var card_counts: Dictionary = {}
	for card in GameManager.deck:
		var cname: String = card.card_name
		if card_counts.has(cname):
			card_counts[cname]["count"] += 1
		else:
			card_counts[cname] = {"resource": card, "count": 1}

	%TitleLabel.text = "Your Deck (%d cards)" % GameManager.deck.size()

	for card_name in card_counts:
		var entry: Dictionary = card_counts[card_name]
		var card: Resource = entry["resource"]
		var count: int = entry["count"]

		if _trading_enabled:
			var sell_price: int = _get_sell_price(card)
			var can_sell: bool = GameManager.deck.size() > MIN_DECK_SIZE
			var card_display := CardDisplayScene.instantiate()
			card_display.custom_minimum_size = Vector2(130, 160)
			%CardGrid.add_child(card_display)
			card_display.setup(card, can_sell, "Sell (%dcr)" % sell_price, true)
			card_display.modulate.a = 1.0
			card_display.card_played.connect(_on_sell_card.bind(sell_price))
			# Count badge
			if count > 1:
				var count_label := Label.new()
				count_label.text = "x%d" % count
				count_label.add_theme_font_size_override("font_size", 16)
				count_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
				count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				card_display.get_node("VBoxContainer").add_child(count_label)
		else:
			var card_display := CardDisplayScene.instantiate()
			card_display.custom_minimum_size = Vector2(130, 160)
			%CardGrid.add_child(card_display)
			card_display.setup(card, false, "", false)
			card_display.modulate.a = 1.0
			if count > 1:
				var count_label := Label.new()
				count_label.text = "x%d" % count
				count_label.add_theme_font_size_override("font_size", 16)
				count_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
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
	if _credits_label:
		_credits_label.text = "%d cr" % GameManager.credits
	_populate_shop()
	_populate_deck()


func _style_close_button() -> void:
	var btn := %CloseButton
	var normal := StyleBoxFlat.new()
	normal.bg_color = SECONDARY_BG
	normal.border_color = SECONDARY_BORDER
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4

	var hover := normal.duplicate()
	hover.bg_color = SECONDARY_BG.lightened(0.15)
	hover.border_color = SECONDARY_BORDER.lightened(0.2)

	var pressed := normal.duplicate()
	pressed.bg_color = SECONDARY_BG.darkened(0.15)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(0.85, 0.87, 0.9))


func _on_close_pressed() -> void:
	queue_free()
