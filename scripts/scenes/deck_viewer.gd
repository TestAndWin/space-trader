extends Control

## Deck viewer with integrated card trading when on a planet.
## Full-screen immersive style with showroom background.

const CardDisplayScene = preload("res://scenes/components/card_display.tscn")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")



const MIN_DECK_SIZE: int = 5
const SELL_RATIO: float = 0.5

const PRICE_RANGES: Dictionary = {
	0: Vector2i(50, 80),    # COMMON
	1: Vector2i(120, 200),  # UNCOMMON
	2: Vector2i(250, 400),  # RARE
}

# ── Sell price weighting ─────────────────────────────────────────────────────
# A card's sell price is placed inside its rarity band by a power score, so a
# Torpedo pays more than a Battle Fury even though both are Uncommon.

const HEAL_WEIGHT: float = 1.5
const CREDITS_WEIGHT: float = 0.12

## Power contribution per CardData.CardKeyword. A flat per-keyword value badly
## undervalued SHIELD_ECHO, whose bonus (half your current shield) is worth more
## than the printed attack value on Shield Bash.
const KEYWORD_POWER: Dictionary = {
	0: 2.5,   # CHARGE — 1.5x damage once 2+ attacks were played this turn
	1: 1.5,   # COMBO — next card costs 1 less energy
	2: 5.0,   # SHIELD_ECHO — bonus damage of half the current shield (base 10)
	3: 1.0,   # RECYCLING — one extra draw per reshuffle
	4: -4.0,  # BOUNCES — dead card while an enemy shield still stands
}

## Power contribution per CardData.DamageType. Piercing is the premium: it never
## has a bad matchup. Ion is situational — it needs a shield to be worth its
## halved hull damage, so it barely moves the score.
const DAMAGE_TYPE_POWER: Dictionary = {
	0: 0.0,   # KINETIC — the baseline every printed attack value assumes
	1: 1.0,   # ION
	2: 3.0,   # PIERCING
}

## Energy — not hand size — is the bottleneck: 3 energy per turn against a hand
## of 5 means roughly two cards go unplayed anyway. An extra draw therefore buys
## selection, not throughput, and is worth far less than its raw card count.
const DRAW_WEIGHT: float = 1.5

## Cheap cards do more per turn than expensive ones with the same numbers, so
## price in the energy cost relative to a 2-energy baseline.
const ENERGY_BASELINE: float = 2.0
const ENERGY_WEIGHT: float = 1.5

## Power contribution per CardData.SpecialEffect.
## SELF_DAMAGE_5 is a drawback and therefore negative.
const SPECIAL_POWER: Dictionary = {
	0: 0.0,    # NONE
	1: -2.0,   # SELF_DAMAGE_5
	2: 6.0,    # BONUS_ENERGY_2
	3: 8.0,    # SKIP_ENEMY_TURN
	4: 10.0,   # END_ENCOUNTER
	5: 4.0,    # SCAVENGE
	6: 5.0,    # PIERCE_NEXT
}

## Power span mapped onto each rarity band (min power -> band low,
## max power -> band high). Fixed rather than derived from the current card
## pool, so adding a card does not silently reprice every other card.
const POWER_REFERENCE: Dictionary = {
	0: Vector2(3.0, 9.5),    # COMMON
	1: Vector2(4.0, 14.0),   # UNCOMMON
	2: Vector2(5.0, 18.0),   # RARE
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
var _status_label: Label
var _title_label: Label
var _subtitle_label: Label
var _card_grid: GridContainer


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
	BackgroundUtils.add_building_background(self, "deck", 0.4)

	# Chrome, header and separator come from the shared overlay scaffold so this
	# screen matches Market/Crew/Quest/Shipyard exactly. Title and subtitle text
	# are filled in by _populate_deck(), which runs right after _build_ui().
	var scaffold: Dictionary = UIStyles.create_overlay_scaffold(
		self, "", "", "\u2726 \u2660 \u2726", "Back to City", close
	)
	var main_vbox: VBoxContainer = scaffold["main_vbox"]
	_title_label = scaffold["title_label"]
	_subtitle_label = scaffold["subtitle_label"]

	# Status label (trading only)
	if _trading_enabled:
		_status_label = Label.new()
		_status_label.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
		_status_label.add_theme_color_override("font_color", UIStyles.POSITIVE)
		_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_vbox.add_child(_status_label)

	# Deck grid in scroll
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var deck_margin := MarginContainer.new()
	deck_margin.add_theme_constant_override("margin_top", 16)
	deck_margin.add_theme_constant_override("margin_bottom", 16)
	deck_margin.add_theme_constant_override("margin_left", 8)
	deck_margin.add_theme_constant_override("margin_right", 8)
	deck_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(deck_margin)

	_card_grid = GridContainer.new()
	_card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_grid.add_theme_constant_override("h_separation", 8)
	_card_grid.add_theme_constant_override("v_separation", 8)
	_card_grid.columns = 8
	deck_margin.add_child(_card_grid)

	# Shop section (below deck, trading only)
	if _trading_enabled and _shop_cards.size() > 0:
		var shop_sep := HSeparator.new()
		shop_sep.add_theme_constant_override("separation", 6)
		shop_sep.add_theme_color_override("separator", UIStyles.ACCENT_DIM)
		main_vbox.add_child(shop_sep)

		var shop_section := VBoxContainer.new()
		shop_section.add_theme_constant_override("separation", 6)
		main_vbox.add_child(shop_section)

		var shop_label := Label.new()
		shop_label.text = "\u25C6 FOR SALE \u25C6"
		UIStyles.apply_section_title(shop_label)
		shop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop_section.add_child(shop_label)

		var shop_scroll := ScrollContainer.new()
		shop_scroll.custom_minimum_size = Vector2(0, 270)
		shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		shop_section.add_child(shop_scroll)

		var shop_margin := MarginContainer.new()
		shop_margin.add_theme_constant_override("margin_top", 16)
		shop_margin.add_theme_constant_override("margin_bottom", 16)
		shop_margin.add_theme_constant_override("margin_left", 8)
		shop_margin.add_theme_constant_override("margin_right", 8)
		shop_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		shop_scroll.add_child(shop_margin)

		_shop_grid = GridContainer.new()
		_shop_grid.columns = 10
		_shop_grid.add_theme_constant_override("h_separation", 10)
		_shop_grid.add_theme_constant_override("v_separation", 10)
		shop_margin.add_child(_shop_grid)

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

	# Title matches the building name painted on the planet; the deck size moves
	# into the subtitle so the header stays consistent with the other overlays.
	_title_label.text = CityMap.get_building_name(CityMap.BUILDING_DECK, _planet_type).to_upper() \
		if _trading_enabled else "YOUR DECK"
	if _subtitle_label:
		_subtitle_label.text = "%d cards • %s" % [
			GameManager.deck.size(),
			"Sell Unwanted • Buy New Strategies" if _trading_enabled else "Plan Your Strategy",
		]

	for card_name in card_counts:
		var entry: Dictionary = card_counts[card_name]
		var card: Resource = entry["resource"]
		var count: int = entry["count"]

		var card_display := CardDisplayScene.instantiate()
		_card_grid.add_child(card_display)
		if _trading_enabled:
			var sell_price: int = _get_sell_price(card)
			var can_sell: bool = GameManager.deck.size() > MIN_DECK_SIZE
			card_display.setup(card, can_sell, "Sell (%dcr)" % sell_price, true)
			card_display.card_played.connect(_on_sell_card.bind(sell_price))
		else:
			card_display.setup(card, false, "", false)
		if count > 1:
			card_display.set_count(count)


## Rough power score of a card, used to place its sell price inside the band
## for its rarity. Without this every Common sold for exactly the same 32cr,
## because the price was just the band midpoint.
func _card_power(card: Resource) -> float:
	var power: float = float(card.attack_value) + float(card.defense_value)
	power += float(card.heal_value) * HEAL_WEIGHT
	power += float(card.draw_cards) * DRAW_WEIGHT
	power += float(card.credits_gain) * CREDITS_WEIGHT
	power += float(SPECIAL_POWER.get(card.special_effect, 0.0))
	if card.card_type == CardData.CardType.ATTACK:
		power += float(DAMAGE_TYPE_POWER.get(card.damage_type, 0.0))
	for keyword: int in card.keywords:
		power += float(KEYWORD_POWER.get(keyword, 1.0))
	power += (ENERGY_BASELINE - float(card.energy_cost)) * ENERGY_WEIGHT
	return maxf(power, 0.0)


func _get_sell_price(card: Resource) -> int:
	var price_range: Vector2i = PRICE_RANGES.get(card.rarity, Vector2i(50, 80))
	var reference: Vector2 = POWER_REFERENCE.get(card.rarity, Vector2(2.0, 10.0))
	var span: float = maxf(reference.y - reference.x, 1.0)
	var t: float = clampf((_card_power(card) - reference.x) / span, 0.0, 1.0)
	var value: float = lerpf(float(price_range.x), float(price_range.y), t)
	return int(round(value * SELL_RATIO))


func _on_buy_card(_card_data: Resource, entry: Dictionary) -> void:
	var card: Resource = entry["card"]
	var price: int = entry["price"]
	if not GameManager.remove_credits(price):
		_status_label.text = "Not enough credits!"
		return
	GameManager.deck.append(card)
	AchievementManager.check_deck(GameManager.deck.size())
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


func close() -> void:
	queue_free()
