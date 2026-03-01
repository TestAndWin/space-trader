extends Control

## Planet Hub — visual scene with clickable buildings that open sub-screens.
## Market, Cargo, Crew, and Shipyard are now separate fullscreen overlays.

const DeckViewerScene = preload("res://scenes/deck_viewer.tscn")
const SmugglerEventScene = preload("res://scenes/components/smuggler_event.tscn")
const PlanetEventScene = preload("res://scenes/components/planet_event.tscn")
const CasinoPopupScene: PackedScene = preload("res://scenes/components/casino_popup.tscn")
const MarketScreenScene: PackedScene = preload("res://scenes/components/market_screen.tscn")
const CrewScreenScene: PackedScene = preload("res://scenes/components/crew_screen.tscn")
const ShipyardScreenScene: PackedScene = preload("res://scenes/components/shipyard_screen.tscn")
const QuestScreenScene: PackedScene = preload("res://scenes/components/quest_screen.tscn")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const GoodIcon = preload("res://scripts/components/good_icon.gd")
const CrewIcon = preload("res://scripts/components/crew_icon.gd")

const TYPE_COLORS = {
	0: Color(0.4, 0.6, 1.0),
	1: Color(0.4, 0.9, 0.4),
	2: Color(0.9, 0.6, 0.3),
	3: Color(0.3, 0.9, 1.0),
	4: Color(1.0, 0.3, 0.3),
}

# Hologram panel style constants
const HOLO_BORDER := Color(0.0, 0.65, 0.95, 0.85)
const ACCENT_DEPART := Color(0.0, 0.85, 0.45)
const HOLO_SHADOW := Color(0.0, 0.45, 0.9, 0.25)

var current_planet_data: Resource = null
var _smuggler_bought: Dictionary = {}  # good_name -> qty bought from smuggler this visit
var _mission_done: bool = false
var _casino_done: bool = false
var _casino_rounds: int = 0

@onready var planet_name_label := $VBoxContainer/PlanetNameLabel
@onready var news_banner := $InfoBar/InfoBarBox/NewsBanner
@onready var quest_label := $InfoBar/InfoBarBox/QuestLabel
@onready var goal_label := $InfoBar/InfoBarBox/GoalLabel

@onready var cargo_bar := $ShipStatusPanel/ShipStatusBox/ShipStats/CargoBar
@onready var capacity_label := $ShipStatusPanel/ShipStatusBox/ShipStats/CargoRow/CapacityLabel
@onready var cargo_items_row := $ShipStatusPanel/ShipStatusBox/ShipStats/CargoItemsRow
@onready var crew_items_row := $ShipStatusPanel/ShipStatusBox/ShipColumn/CrewItemsRow
@onready var planet_background := $VBoxContainer/MainContent/LeftColumn/PlanetBackground
@onready var ship_status_panel := $ShipStatusPanel
@onready var ship_display := $ShipStatusPanel/ShipStatusBox/ShipColumn/ShipDisplay
@onready var hull_label := $ShipStatusPanel/ShipStatusBox/ShipStats/HullLabel
@onready var hull_bar := $ShipStatusPanel/ShipStatusBox/ShipStats/HullBar
@onready var shield_label := $ShipStatusPanel/ShipStatusBox/ShipStats/ShieldLabel
@onready var shield_bar := $ShipStatusPanel/ShipStatusBox/ShipStats/ShieldBar
@onready var space_background := $Background
@onready var bg_image: TextureRect = $BgImage


# ── Building IDs ─────────────────────────────────────────────────────────────

const BUILDING_MARKET = "market"
const BUILDING_SHIPYARD = "shipyard"
const BUILDING_CASINO = "casino"
const BUILDING_CREW = "crew"
const BUILDING_QUEST = "quest"
const BUILDING_DECK = "deck"
const BUILDING_DEPART = "depart"
const BUILDING_MISSION = "mission"


func _ready() -> void:
	_find_planet_data()
	# Check quest penalty after battle credits have been awarded
	if QuestManager.check_expired_quest():
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")
		return
	# Crew engineer bonus: hull regen on planet visit
	if GameManager.has_crew_bonus(CrewData.CrewBonus.HULL_REGEN):
		var regen: int = int(GameManager.get_crew_bonus_value(CrewData.CrewBonus.HULL_REGEN))
		GameManager.current_hull = min(GameManager.current_hull + regen, GameManager.max_hull)
	_update_header()
	_update_news_banner()

	_style_cargo_bar()
	_style_ship_panel()
	_style_info_bar()
	_update_ui()
	_add_header_buttons()

	# Space background — use image if available, else procedural
	if current_planet_data:
		_load_background_image()
		if not bg_image.visible:
			space_background.setup(current_planet_data.planet_type, current_planet_data.danger_level)
	# Planet background
	if current_planet_data:
		planet_background.setup(current_planet_data.planet_type)
	# Mark mission as done if already played this landing
	if GameManager.mission_done_this_landing:
		_mission_done = true
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
				_update_ui(); _update_log()
			)
		# Planet arrival event (only if no smuggler event)
		if not smuggler_active and current_planet_data:
			var planet_event := PlanetEventScene.instantiate()
			add_child(planet_event)
			if not planet_event.try_trigger(current_planet_data.planet_type):
				planet_event.queue_free()
			else:
				planet_event.event_resolved.connect(func():
					_update_ui(); _update_log()
				)


func _find_planet_data() -> void:
	current_planet_data = EconomyManager.get_planet_data(GameManager.current_planet)


func _load_background_image() -> void:
	var planet_name: String = current_planet_data.planet_name.to_lower().replace(" ", "_")
	for ext: String in ["jpg", "jpeg", "png"]:
		var tex := load("res://assets/sprites/bg_%s.%s" % [planet_name, ext]) as Texture2D
		if tex:
			bg_image.texture = tex
			bg_image.visible = true
			space_background.visible = false
			planet_background.visible = false
			_create_image_hotspots(_get_building_states())
			return


func _get_building_states() -> Dictionary:
	return {
		BUILDING_CASINO: _casino_done,
		BUILDING_MISSION: _mission_done,
	}


func _on_building_clicked(building_id: String) -> void:
	match building_id:
		BUILDING_MARKET:   _on_market_pressed()
		BUILDING_SHIPYARD: _on_shipyard_pressed()
		BUILDING_CASINO:   _on_casino_pressed()
		BUILDING_CREW:     _on_crew_pressed()
		BUILDING_QUEST:    _on_quest_pressed()
		BUILDING_DECK:     _on_view_deck_pressed()
		BUILDING_DEPART:   _on_depart_pressed()
		BUILDING_MISSION:  _on_mission_pressed()


# ── Building callbacks ───────────────────────────────────────────────────────

func _on_market_pressed() -> void:
	if has_node("MarketScreen"):
		return
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	var market := MarketScreenScene.instantiate()
	market.name = "MarketScreen"
	add_child(market)
	market.setup(pt, _smuggler_bought)
	market.market_closed.connect(func(): _update_ui(); _update_log())


func _on_shipyard_pressed() -> void:
	if has_node("ShipyardScreen"):
		return
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	var shipyard := ShipyardScreenScene.instantiate()
	shipyard.name = "ShipyardScreen"
	add_child(shipyard)
	shipyard.setup(pt)
	shipyard.shipyard_closed.connect(func(): _update_ui(); _update_log())


func _on_casino_pressed() -> void:
	if has_node("CasinoPopup"):
		return
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	var popup := CasinoPopupScene.instantiate()
	popup.name = "CasinoPopup"
	add_child(popup)
	var rounds_left: int = 5 - _casino_rounds
	popup.setup(pt, rounds_left)
	popup.casino_closed.connect(func():
		_casino_rounds += popup.rounds_played
		if _casino_rounds >= 5:
			_casino_done = true
			_rebuild_hub_buildings()
		_update_ui(); _update_log()
	)


func _on_crew_pressed() -> void:
	if has_node("CrewScreen"):
		return
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	var crew := CrewScreenScene.instantiate()
	crew.name = "CrewScreen"
	add_child(crew)
	crew.setup(pt)
	crew.crew_closed.connect(func(): _update_ui(); _update_log())

func _on_quest_pressed() -> void:
	if has_node("QuestScreen"):
		return
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	var quest := QuestScreenScene.instantiate()
	quest.name = "QuestScreen"
	add_child(quest)
	quest.setup(pt, GameManager.current_planet)
	quest.quest_closed.connect(func(): _update_ui(); _update_log())


func _on_mission_pressed() -> void:
	if GameManager.credits < 100:
		EventLog.add_entry("Not enough credits for mission (100cr required).")
		_update_log()
		return
	GameManager.remove_credits(100)
	GameManager.mission_return_planet = GameManager.current_planet
	EventLog.add_entry("Entered Space Invaders mission (-100cr).")
	GameManager.change_scene("res://scenes/space_invaders.tscn")


func _rebuild_hub_buildings() -> void:
	var states := _get_building_states()
	var hotspot_node := get_node_or_null("ImageHotspots")
	if hotspot_node:
		hotspot_node.free()
		_create_image_hotspots(states)


func _create_image_hotspots(states: Dictionary) -> void:
	if not current_planet_data:
		return
	var hotspot_map: Dictionary = current_planet_data.image_hotspots
	if hotspot_map.is_empty():
		return

	var container := Control.new()
	container.name = "ImageHotspots"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	# StyleBoxes shared across all hotspot buttons
	var empty := StyleBoxEmpty.new()
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	hover_style.border_color = HOLO_BORDER
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(4)

	for bid: String in hotspot_map:
		var rect: Rect2 = hotspot_map[bid]

		var btn := Button.new()
		# Rect2 values are in pixels (1280x720); convert to normalized anchors at runtime
		btn.anchor_left   = rect.position.x / 1280.0
		btn.anchor_top    = rect.position.y / 720.0
		btn.anchor_right  = (rect.position.x + rect.size.x) / 1280.0
		btn.anchor_bottom = (rect.position.y + rect.size.y) / 720.0
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.disabled = states.get(bid, false)
		btn.add_theme_stylebox_override("normal",   empty)
		btn.add_theme_stylebox_override("pressed",  empty)
		btn.add_theme_stylebox_override("disabled", empty)
		btn.add_theme_stylebox_override("focus",    empty)
		btn.add_theme_stylebox_override("hover",    hover_style)

		var captured_bid: String = bid
		btn.pressed.connect(func() -> void: _on_building_clicked(captured_bid))
		container.add_child(btn)


# ── Header & Info ────────────────────────────────────────────────────────────


func _style_info_bar() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.14, 0.75)
	style.border_color = HOLO_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = HOLO_SHADOW
	style.shadow_size = 6
	style.set_content_margin_all(8)
	$InfoBar.add_theme_stylebox_override("panel", style)


func _style_ship_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.14, 0.75)
	style.border_color = HOLO_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = HOLO_SHADOW
	style.shadow_size = 6
	style.set_content_margin_all(8)
	ship_status_panel.add_theme_stylebox_override("panel", style)

	# Hull bar colors
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.04, 0.04)
	bar_bg.set_corner_radius_all(3)
	bar_bg.border_color = Color(0.3, 0.1, 0.1)
	bar_bg.set_border_width_all(1)
	hull_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.2, 0.9, 0.2)
	bar_fill.set_corner_radius_all(3)
	hull_bar.add_theme_stylebox_override("fill", bar_fill)


func _style_cargo_bar() -> void:
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.02, 0.06, 0.16)
	bar_bg.set_corner_radius_all(3)
	bar_bg.border_color = Color(0.0, 0.30, 0.50)
	bar_bg.set_border_width_all(1)
	cargo_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.0, 0.80, 1.0)
	bar_fill.set_corner_radius_all(3)
	cargo_bar.add_theme_stylebox_override("fill", bar_fill)


func _on_event_log_pressed() -> void:
	if has_node("EventLogPopup"):
		return
	var overlay := ColorRect.new()
	overlay.name = "EventLogPopup"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	overlay.add_child(margin)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.14, 0.85)
	style.border_color = Color(0.0, 0.65, 0.95, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "EVENT LOG"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	header.add_child(title)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var close_btn := Button.new()
	close_btn.text = "Close"
	UIStyles.style_accent_button(close_btn, Color(0.5, 0.15, 0.1))
	close_btn.pressed.connect(func(): overlay.queue_free())
	header.add_child(close_btn)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.0, 0.45, 0.75, 0.6))
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	var entries := EventLog.get_entries()
	for i in range(entries.size() - 1, -1, -1):
		var lbl := Label.new()
		lbl.text = entries[i]
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.35, 0.65, 0.85))
		list.add_child(lbl)


func _update_header() -> void:
	planet_name_label.text = GameManager.current_planet


func _update_news_banner() -> void:
	var event_text := EventManager.get_event_display_text()
	if event_text != "":
		news_banner.text = "SPACE NEWS: " + event_text
		news_banner.visible = true
	else:
		news_banner.visible = false


func _update_ui() -> void:
	var used: int = GameManager.get_cargo_used()
	var cap: int = GameManager.cargo_capacity
	cargo_bar.value = used
	cargo_bar.max_value = cap
	capacity_label.text = str(used) + "/" + str(cap)
	# Update cargo item icons
	_update_cargo_items()
	# Update crew item icons
	_update_crew_items()
	# Update ship status
	_update_ship_status()
	# Update quest header label
	_update_quest_label()
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


func _update_ship_status() -> void:
	var hull: int = GameManager.current_hull
	var max_hull: int = GameManager.max_hull
	var shield: int = GameManager.current_shield
	var max_shield: int = GameManager.max_shield
	var hull_pct: float = float(hull) / float(max_hull) if max_hull > 0 else 0.0
	var shield_pct: float = float(shield) / float(max_shield) if max_shield > 0 else 0.0

	var ship_data: Resource = GameManager.get_ship_data()
	var shape: int = ship_data.hull_shape if ship_data else 0
	ship_display.update_ship(hull_pct, shield_pct, GameManager.get_cargo_used(), GameManager.cargo_capacity, shape)

	hull_label.text = "Hull: %d/%d" % [hull, max_hull]
	if hull_pct > 0.6:
		hull_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	elif hull_pct > 0.3:
		hull_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.1))
	else:
		hull_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))

	# Hull bar fill color mirrors hull status
	var bar_fill := StyleBoxFlat.new()
	bar_fill.set_corner_radius_all(3)
	if hull_pct > 0.6:
		bar_fill.bg_color = Color(0.2, 0.9, 0.2)
	elif hull_pct > 0.3:
		bar_fill.bg_color = Color(0.9, 0.75, 0.1)
	else:
		bar_fill.bg_color = Color(0.9, 0.2, 0.15)
	hull_bar.add_theme_stylebox_override("fill", bar_fill)
	hull_bar.max_value = max_hull
	hull_bar.value = hull

	shield_label.text = "Shield: %d/%d" % [shield, max_shield]
	shield_bar.max_value = max(max_shield, 1)
	shield_bar.value = shield


func _update_quest_label() -> void:
	if not QuestManager.has_active_quest():
		quest_label.visible = false
		return
	var q: Dictionary = QuestManager.current_quest
	var trips_left: int = q.get("turns_left", 0)
	quest_label.text = "%dx %s → %s  |  %d trips left  |  +%d cr" % [
		q["deliver_qty"], q["deliver_good"], q["destination"], trips_left, q["reward_credits"]
	]
	if trips_left <= 1:
		quest_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	elif trips_left == 2:
		quest_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.1))
	else:
		quest_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.25))
	quest_label.visible = true


func _update_cargo_items() -> void:
	for child in cargo_items_row.get_children():
		child.queue_free()
	for item in GameManager.cargo:
		var good_name: String = item["good_name"]
		var qty: int = item["quantity"]
		var icon := Control.new()
		icon.set_script(GoodIcon)
		icon.setup(good_name)
		icon.tooltip_text = "%s x%d" % [good_name, qty]
		cargo_items_row.add_child(icon)


func _update_crew_items() -> void:
	for child in crew_items_row.get_children():
		child.queue_free()
	var crew_resources := GameManager.get_crew_resources()
	for crew_res in crew_resources:
		var icon := Control.new()
		icon.set_script(CrewIcon)
		icon.custom_minimum_size = Vector2(22, 22)
		icon.tooltip_text = crew_res.crew_name + " - " + crew_res.description
		crew_items_row.add_child(icon)
		icon.setup(crew_res.bonus_type)


# ── Bottom Bar ───────────────────────────────────────────────────────────────

func _on_depart_pressed() -> void:
	if has_node("DepartOverlay"):
		return
	var overlay := ColorRect.new()
	overlay.name = "DepartOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.14, 0.95)
	style.border_color = ACCENT_DEPART
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(340, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Ready to depart?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ACCENT_DEPART)
	vbox.add_child(title)

	var btn_depart := Button.new()
	btn_depart.text = "Depart"
	btn_depart.add_theme_font_size_override("font_size", 16)
	_style_primary_button(btn_depart, ACCENT_DEPART)
	btn_depart.pressed.connect(func(): overlay.queue_free(); _do_depart())
	vbox.add_child(btn_depart)

	var btn_stay := Button.new()
	btn_stay.text = "Stay on Planet"
	btn_stay.add_theme_font_size_override("font_size", 14)
	_style_secondary_button(btn_stay)
	btn_stay.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(btn_stay)


func _do_depart() -> void:
	GameManager.arrival_events_done = false
	GameManager.mission_done_this_landing = false
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
	var pt: int = current_planet_data.planet_type if current_planet_data else -1
	viewer.setup(pt)
	add_child(viewer)
	viewer.tree_exited.connect(func(): _update_ui(); _update_log())



func _update_log() -> void:
	# No-op — log is now shown via overlay popup
	pass


func _add_header_buttons() -> void:
	var header := $InfoBar/InfoBarBox
	# Small button style shared by Menu and Event Log
	var _make_small_btn := func(text: String, callback: Callable) -> Button:
		var btn := Button.new()
		btn.text = text
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(0.35, 0.6, 0.8))
		btn.add_theme_color_override("font_hover_color", Color(0.55, 0.78, 0.98))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.04, 0.08, 0.5)
		style.border_color = Color(0.0, 0.25, 0.45, 0.4)
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", style)
		var hover_style := style.duplicate()
		hover_style.bg_color = Color(0.04, 0.08, 0.14, 0.6)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.pressed.connect(callback)
		return btn

	var event_log_btn: Button = _make_small_btn.call("Event Log", _on_event_log_pressed)
	header.add_child(event_log_btn)

	var menu_btn: Button = _make_small_btn.call("Menu", _on_menu_pressed)
	header.add_child(menu_btn)


func _on_menu_pressed() -> void:
	GameManager.change_scene("res://scenes/main_menu.tscn")


func _style_primary_button(btn: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent
	normal.border_color = accent.lightened(0.25)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.shadow_color = Color(0.0, 0.85, 0.45, 0.35)
	normal.shadow_size = 8
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
	btn.add_theme_color_override("font_color", Color(0.0, 0.05, 0.05))
	btn.add_theme_color_override("font_hover_color", Color(0.0, 0.1, 0.05))
	btn.add_theme_color_override("font_pressed_color", Color(0.0, 0.05, 0.02))


func _style_secondary_button(btn: Button) -> void:
	UIStyles.style_secondary_button(btn)
