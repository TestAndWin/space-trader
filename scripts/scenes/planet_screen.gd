extends Control

const CargoSlotScene = preload("res://scenes/components/cargo_slot.tscn")
const DeckViewerScene = preload("res://scenes/deck_viewer.tscn")
const SmugglerEventScene = preload("res://scenes/components/smuggler_event.tscn")
const PlanetEventScene = preload("res://scenes/components/planet_event.tscn")
var CardTraderScene: PackedScene = load("res://scenes/components/card_trader.tscn")
var CasinoPopupScene: PackedScene = load("res://scenes/components/casino_popup.tscn")
var ShipDealerScene: PackedScene = load("res://scenes/components/ship_dealer.tscn")

const TYPE_COLORS = {
	0: Color(0.4, 0.6, 1.0),
	1: Color(0.4, 0.9, 0.4),
	2: Color(0.9, 0.6, 0.3),
	3: Color(0.3, 0.9, 1.0),
	4: Color(1.0, 0.3, 0.3),
}

const MARKET_FLAVOR = {
	0: "Factory surplus and manufactured goods",
	1: "Fresh produce and organic supplies",
	2: "Extracted minerals and heavy equipment",
	3: "Cutting-edge technology and research materials",
	4: "No questions asked. Contraband welcome.",
}

# Metallic panel style constants
const PANEL_BORDER := Color(0.35, 0.38, 0.42, 0.8)
const ACCENT_GREEN := Color(0.25, 0.55, 0.2)
const SECONDARY_BG := Color(0.1, 0.12, 0.16)
const SECONDARY_BORDER := Color(0.35, 0.38, 0.42, 0.7)

var current_planet_data: Resource = null
var _smuggler_bought: Dictionary = {}  # good_name -> qty bought from smuggler this visit

@onready var news_banner := $VBoxContainer/NewsBanner
@onready var planet_name_label := $VBoxContainer/PlanetHeader/PlanetNameLabel
@onready var planet_type_label := $VBoxContainer/PlanetHeader/PlanetTypeLabel
@onready var danger_label := $VBoxContainer/PlanetHeader/DangerLabel
@onready var goal_label := $VBoxContainer/PlanetHeader/GoalLabel
@onready var market_label := $VBoxContainer/MainContent/LeftColumn/MarketPanel/MarketVBox/MarketLabel
@onready var market_flavor_label := $VBoxContainer/MainContent/LeftColumn/MarketPanel/MarketVBox/MarketFlavorLabel
@onready var market_list := $VBoxContainer/MainContent/LeftColumn/MarketPanel/MarketVBox/MarketScroll/MarketList
@onready var cargo_list := $VBoxContainer/MainContent/MiddleColumn/CargoPanel/CargoVBox/CargoScroll/CargoList
@onready var credits_label := $VBoxContainer/TopInfoBar/CreditsBox/CreditsLabel
@onready var credits_box := $VBoxContainer/TopInfoBar/CreditsBox
@onready var cargo_box := $VBoxContainer/TopInfoBar/CargoBox
@onready var cargo_bar := $VBoxContainer/TopInfoBar/CargoBox/CargoCapacity/CargoBar
@onready var capacity_label := $VBoxContainer/TopInfoBar/CargoBox/CargoCapacity/CapacityLabel
@onready var save_button := $VBoxContainer/BottomBar/BottomHBox/SaveButton
@onready var view_deck_button := $VBoxContainer/BottomBar/BottomHBox/ViewDeckButton
@onready var depart_button := $VBoxContainer/BottomBar/BottomHBox/DepartButton
@onready var planet_background := $VBoxContainer/MainContent/RightColumn/PlanetBackground
@onready var shipyard_panel := $VBoxContainer/MainContent/LeftColumn/ShipyardPanel
@onready var crew_panel := $VBoxContainer/MainContent/MiddleColumn/CrewPanel
@onready var quest_display := $VBoxContainer/MainContent/RightColumn/QuestDisplay
@onready var log_list := $VBoxContainer/MainContent/RightColumn/LogPanel/LogVBox/LogScroll/LogList
@onready var action_icon_row := $VBoxContainer/MainContent/RightColumn/ActionIconRow
@onready var space_background := $Background


func _ready() -> void:
	if GameManager.check_win_condition():
		get_tree().change_scene_to_file("res://scenes/victory.tscn")
		return
	_find_planet_data()
	# Check quest penalty after battle credits have been awarded
	if QuestManager.check_expired_quest():
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")
		return
	# Crew engineer bonus: hull regen on planet visit
	if GameManager.has_crew_bonus(2):  # HULL_REGEN
		var regen: int = int(GameManager.get_crew_bonus_value(2))
		GameManager.current_hull = min(GameManager.current_hull + regen, GameManager.max_hull)
	_update_header()
	_update_news_banner()
	_style_info_boxes()
	_style_cargo_bar()
	_populate_market()
	_populate_cargo()
	_update_ui()
	depart_button.pressed.connect(_on_depart_pressed)
	save_button.pressed.connect(_on_save_pressed)
	view_deck_button.pressed.connect(_on_view_deck_pressed)
	_add_menu_button()
	_style_bottom_buttons()
	_update_log()
	# Space background
	if current_planet_data:
		space_background.setup(current_planet_data.planet_type, current_planet_data.danger_level)
	# Planet background
	if current_planet_data:
		planet_background.setup(current_planet_data.planet_type)
	# Shipyard
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	shipyard_panel.setup()
	shipyard_panel.shipyard_action.connect(_on_shipyard_action)
	shipyard_panel.ships_requested.connect(_on_ship_dealer_pressed)
	# Crew
	crew_panel.setup(pt)
	crew_panel.crew_action.connect(_on_shipyard_action)
	# Sync crew panel height to shipyard panel
	shipyard_panel.resized.connect(func(): crew_panel.custom_minimum_size.y = shipyard_panel.size.y, CONNECT_ONE_SHOT)
	# Quest
	quest_display.setup(GameManager.current_planet)
	quest_display.quest_changed.connect(func(): _populate_cargo(); _update_ui(); _update_log())
	# Action icons
	_build_action_icons()
	# Arrival events only on first visit (not when returning from sub-screens)
	if not GameManager.arrival_events_done:
		GameManager.arrival_events_done = true
		# Smuggler event
		var smuggler := SmugglerEventScene.instantiate()
		add_child(smuggler)
		var smuggler_active: bool = smuggler.try_spawn()
		if not smuggler_active:
			smuggler.queue_free()
		else:
			# Snapshot cargo before the deal to detect smuggler purchases
			var cargo_before: Dictionary = {}
			for item in GameManager.cargo:
				cargo_before[item["good_name"]] = item["quantity"]
			smuggler.deal_closed.connect(func():
				# Track goods added by smuggler deal
				for item in GameManager.cargo:
					var gname: String = item["good_name"]
					var old_qty: int = cargo_before.get(gname, 0)
					if item["quantity"] > old_qty:
						_smuggler_bought[gname] = _smuggler_bought.get(gname, 0) + (item["quantity"] - old_qty)
				_populate_cargo(); _update_ui(); _update_log()
			)
		# Planet arrival event (only if no smuggler event)
		if not smuggler_active and current_planet_data:
			var planet_event := PlanetEventScene.instantiate()
			add_child(planet_event)
			if not planet_event.try_trigger(current_planet_data.planet_type):
				planet_event.queue_free()
			else:
				planet_event.event_resolved.connect(func():
					_populate_market(); _populate_cargo(); _update_ui(); _update_log()
				)


func _find_planet_data() -> void:
	for planet in EconomyManager.planets:
		if planet.planet_name == GameManager.current_planet:
			current_planet_data = planet
			return


func _style_info_boxes() -> void:
	for box in [credits_box, cargo_box]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.07, 0.1, 0.75)
		style.border_color = PANEL_BORDER
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		box.add_theme_stylebox_override("panel", style)


func _style_cargo_bar() -> void:
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.14, 0.18)
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	bar_bg.border_color = Color(0.25, 0.28, 0.32)
	bar_bg.border_width_left = 1
	bar_bg.border_width_right = 1
	bar_bg.border_width_top = 1
	bar_bg.border_width_bottom = 1
	cargo_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.5, 0.8)
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	cargo_bar.add_theme_stylebox_override("fill", bar_fill)


func _update_header() -> void:
	planet_name_label.text = GameManager.current_planet
	if current_planet_data:
		var type_name: String = EconomyManager.PLANET_TYPE_NAMES.get(current_planet_data.planet_type, "Unknown")
		planet_type_label.text = type_name
		var type_color: Color = TYPE_COLORS.get(current_planet_data.planet_type, Color(0.5, 0.6, 0.8))
		planet_type_label.add_theme_color_override("font_color", type_color)
		var danger: int = current_planet_data.danger_level
		danger_label.text = "Danger: " + str(danger)
		if danger >= 3:
			danger_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif danger >= 2:
			danger_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		else:
			danger_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))


func _update_news_banner() -> void:
	var event_text := EventManager.get_event_display_text()
	if event_text != "":
		news_banner.text = "SPACE NEWS: " + event_text
		news_banner.visible = true
	else:
		news_banner.visible = false


func _populate_market() -> void:
	for child in market_list.get_children():
		child.queue_free()
	# Market header color and flavor text based on planet type
	if current_planet_data:
		var type_color: Color = TYPE_COLORS.get(current_planet_data.planet_type, Color(0.4, 0.7, 1.0))
		market_label.add_theme_color_override("font_color", type_color)
		market_flavor_label.text = MARKET_FLAVOR.get(current_planet_data.planet_type, "")
	var planet_name: String = GameManager.current_planet
	for good in EconomyManager.goods:
		var good_name: String = good.good_name
		var buy_price: int = EconomyManager.get_buy_price(planet_name, good_name)
		if buy_price < 0:
			continue
		var slot := CargoSlotScene.instantiate()
		market_list.add_child(slot)
		var avg: int = EconomyManager.get_average_price(good_name)
		slot.setup(good_name, buy_price, 0, "buy", avg)
		slot.action_pressed.connect(_on_buy)


func _populate_cargo() -> void:
	for child in cargo_list.get_children():
		child.queue_free()
	var planet_name: String = GameManager.current_planet
	for item in GameManager.cargo:
		var good_name: String = item["good_name"]
		var qty: int = item["quantity"]
		# Reduce sellable quantity by goods bought from smuggler this visit
		var blocked: int = _smuggler_bought.get(good_name, 0)
		var sellable_qty: int = qty - blocked
		if sellable_qty <= 0:
			continue
		var sell_price: int = EconomyManager.get_sell_price(planet_name, good_name)
		if sell_price < 0:
			sell_price = 0
		var slot := CargoSlotScene.instantiate()
		cargo_list.add_child(slot)
		var avg_sell: int = EconomyManager.get_average_price(good_name)
		if avg_sell > 0:
			avg_sell = int(round(avg_sell * EconomyManager.SELL_RATIO))
		slot.setup(good_name, sell_price, sellable_qty, "sell", avg_sell)
		slot.action_pressed.connect(_on_sell)


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
	_populate_cargo()
	_update_ui()
	_update_log()


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
	_populate_cargo()
	_update_ui()
	_update_log()
	if GameManager.check_win_condition():
		get_tree().change_scene_to_file("res://scenes/victory.tscn")


func _on_shipyard_action() -> void:
	_update_ui()
	_update_log()


func _on_depart_pressed() -> void:
	GameManager.arrival_events_done = false
	QuestManager.tick()
	EventManager.tick()
	EconomyManager.tick_economy()
	SaveManager.save_game()
	GameManager.change_scene("res://scenes/galaxy_map.tscn")


func _on_view_deck_pressed() -> void:
	if has_node("DeckViewer"):
		return
	var viewer := DeckViewerScene.instantiate()
	viewer.name = "DeckViewer"
	add_child(viewer)


func _update_ui() -> void:
	credits_label.text = "CREDITS: " + str(GameManager.credits)
	var used: int = GameManager.get_cargo_used()
	var cap: int = GameManager.cargo_capacity
	cargo_bar.value = used
	cargo_bar.max_value = cap
	capacity_label.text = str(used) + "/" + str(cap)
	# Goal progress
	var planets_visited: int = GameManager.visited_planets.size()
	var credits_ok := GameManager.credits >= GameManager.WIN_CREDITS
	var planets_ok := planets_visited >= GameManager.WIN_PLANETS
	if credits_ok and planets_ok:
		goal_label.text = "GOAL REACHED!"
		goal_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		goal_label.text = "%d/%d cr | %d/%d planets" % [mini(GameManager.credits, GameManager.WIN_CREDITS), GameManager.WIN_CREDITS, planets_visited, GameManager.WIN_PLANETS]
		var credit_progress: float = clampf(float(GameManager.credits) / float(GameManager.WIN_CREDITS), 0.0, 1.0)
		var planet_progress: float = clampf(float(planets_visited) / float(GameManager.WIN_PLANETS), 0.0, 1.0)
		var progress: float = (credit_progress + planet_progress) / 2.0
		var goal_color := Color(0.5 + progress * 0.5, 0.4 + progress * 0.6, 0.1 + progress * 0.2)
		goal_label.add_theme_color_override("font_color", goal_color)
	# Refresh shipyard and crew (updates ship display + button states)
	var refresh_pt: int = current_planet_data.planet_type if current_planet_data else 0
	shipyard_panel.setup()
	crew_panel.setup(refresh_pt)


func _on_save_pressed() -> void:
	SaveManager.save_game()
	save_button.text = "Saved!"
	await get_tree().create_timer(1.0).timeout
	save_button.text = "Save"


func _update_log() -> void:
	for child in log_list.get_children():
		child.queue_free()
	var entries := EventLog.get_entries()
	var start_idx: int = maxi(0, entries.size() - 20)
	for i in range(entries.size() - 1, start_idx - 1, -1):
		var lbl := Label.new()
		lbl.text = entries[i]
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.45, 0.48, 0.5))
		log_list.add_child(lbl)


func _add_menu_button() -> void:
	var bottom_hbox := $VBoxContainer/BottomBar/BottomHBox
	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	menu_btn.add_theme_font_size_override("font_size", 11)
	menu_btn.add_theme_color_override("font_color", Color(0.45, 0.48, 0.52))
	menu_btn.add_theme_color_override("font_hover_color", Color(0.65, 0.68, 0.72))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.5)
	style.border_color = Color(0.2, 0.22, 0.26, 0.4)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	menu_btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.1, 0.12, 0.16, 0.6)
	menu_btn.add_theme_stylebox_override("hover", hover_style)
	menu_btn.pressed.connect(_on_menu_pressed)
	bottom_hbox.add_child(menu_btn)
	bottom_hbox.move_child(menu_btn, 0)
	# Spacer to push other buttons right
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_hbox.add_child(spacer)
	bottom_hbox.move_child(spacer, 1)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _style_bottom_buttons() -> void:
	_style_primary_button(depart_button, ACCENT_GREEN)
	_style_secondary_button(save_button)
	_style_secondary_button(view_deck_button)
	depart_button.add_theme_font_size_override("font_size", 16)


func _style_primary_button(btn: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent
	normal.border_color = accent.lightened(0.25)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := normal.duplicate()
	hover.bg_color = accent.lightened(0.15)

	var pressed := normal.duplicate()
	pressed.bg_color = accent.darkened(0.2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.95))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.8, 0.75))


func _style_secondary_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = SECONDARY_BG
	normal.border_color = SECONDARY_BORDER
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4

	var hover := normal.duplicate()
	hover.bg_color = SECONDARY_BG.lightened(0.12)
	hover.border_color = SECONDARY_BORDER.lightened(0.15)

	var pressed := normal.duplicate()
	pressed.bg_color = SECONDARY_BG.darkened(0.15)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(0.85, 0.87, 0.9))


func _build_action_icons() -> void:
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	# Casino: all except Mining (2)
	if pt != 2:
		var btn := Button.new()
		btn.text = "Casino"
		btn.custom_minimum_size = Vector2(56, 36)
		_style_secondary_button(btn)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_casino_pressed)
		action_icon_row.add_child(btn)
	# Mission: only Tech (3) and Outlaw (4)
	if pt == 3 or pt == 4:
		var btn := Button.new()
		btn.text = "Mission"
		btn.custom_minimum_size = Vector2(56, 36)
		_style_secondary_button(btn)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_mission_pressed)
		action_icon_row.add_child(btn)
	# Cards: everywhere
	var cards_btn := Button.new()
	cards_btn.text = "Cards"
	cards_btn.custom_minimum_size = Vector2(56, 36)
	_style_secondary_button(cards_btn)
	cards_btn.add_theme_font_size_override("font_size", 11)
	cards_btn.pressed.connect(_on_card_trader_pressed)
	action_icon_row.add_child(cards_btn)


func _on_casino_pressed() -> void:
	if has_node("CasinoPopup"):
		return
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	var popup := CasinoPopupScene.instantiate()
	popup.name = "CasinoPopup"
	add_child(popup)
	popup.setup(pt)
	popup.casino_closed.connect(func(): _update_ui(); _update_log())


func _on_mission_pressed() -> void:
	if GameManager.credits < 100:
		EventLog.add_entry("Not enough credits for mission (100cr required).")
		_update_log()
		return
	GameManager.remove_credits(100)
	GameManager.mission_return_planet = GameManager.current_planet
	EventLog.add_entry("Entered Space Invaders mission (-100cr).")
	GameManager.change_scene("res://scenes/space_invaders.tscn")


func _on_card_trader_pressed() -> void:
	if has_node("CardTrader"):
		return
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	var trader := CardTraderScene.instantiate()
	trader.name = "CardTrader"
	add_child(trader)
	trader.setup(pt)
	trader.trader_closed.connect(func(): _populate_cargo(); _update_ui(); _update_log())


func _on_ship_dealer_pressed() -> void:
	if has_node("ShipDealer"):
		return
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	var dealer := ShipDealerScene.instantiate()
	dealer.name = "ShipDealer"
	add_child(dealer)
	dealer.setup(pt)
	dealer.dealer_closed.connect(func(): _update_ui(); _update_log())
