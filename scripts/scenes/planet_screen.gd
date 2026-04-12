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
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")
const GoodIcon = preload("res://scripts/components/good_icon.gd")
const CrewIcon = preload("res://scripts/components/crew_icon.gd")
const CustomsScanScene = preload("res://scenes/components/customs_scan.tscn")
const PlanetActivityScene = preload("res://scenes/components/planet_activity.tscn")



# Hologram panel style constants
const HOLO_BORDER := Color(0.0, 0.65, 0.95, 0.85)
const ACCENT_DEPART := Color(0.0, 0.85, 0.45)
const HOLO_SHADOW := Color(0.0, 0.45, 0.9, 0.25)
const CARGO_ICON_SLOT_WIDTH: float = 20.0
const CARGO_FALLBACK_ROW_WIDTH: float = 120.0

var current_planet_data: Resource = null
var _arrival_gained_cargo: Dictionary = {}  # good_name -> qty gained on arrival and blocked from market sell
var _mission_done: bool = false
var _casino_done: bool = false
var _casino_rounds: int = 0
var _news_full_text: String = ""
var _hotspot_pulse_tween: Tween = null

@onready var planet_name_label := $VBoxContainer/PlanetNameLabel
@onready var info_bar_box: HBoxContainer = $InfoBar/InfoBarBox
@onready var header_spacer: Control = $InfoBar/InfoBarBox/HeaderSpacer
@onready var news_banner := $InfoBar/InfoBarBox/NewsBanner
@onready var goal_label := $InfoBar/InfoBarBox/GoalLabel
@onready var quest_widget := $QuestWidget

@onready var cargo_bar := $ShipStatusPanel/ShipStatusBox/ShipStats/CargoBar
@onready var capacity_label := $ShipStatusPanel/ShipStatusBox/ShipStats/CargoRow/CapacityLabel
@onready var cargo_items_row := $ShipStatusPanel/ShipStatusBox/ShipStats/CargoItemsRow
@onready var crew_items_row := $ShipStatusPanel/ShipStatusBox/ShipColumn/CrewItemsRow
@onready var ship_status_panel := $ShipStatusPanel
@onready var ship_display := $ShipStatusPanel/ShipStatusBox/ShipColumn/ShipDisplay
@onready var hull_label := $ShipStatusPanel/ShipStatusBox/ShipStats/HullLabel
@onready var hull_bar := $ShipStatusPanel/ShipStatusBox/ShipStats/HullBar
@onready var shield_label := $ShipStatusPanel/ShipStatusBox/ShipStats/ShieldLabel
@onready var shield_bar := $ShipStatusPanel/ShipStatusBox/ShipStats/ShieldBar
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
	ship_status_panel.clip_contents = true
	cargo_items_row.clip_contents = true
	_update_ui()
	_add_header_buttons()
	var current_quest_dest: String = QuestManager.current_quest.get("destination", "") if QuestManager.has_active_quest() else ""
	if current_quest_dest == GameManager.current_planet and current_planet_data:
		call_deferred("_show_quest_arrival_toast")

	quest_widget.clicked.connect(_on_quest_pressed)
	call_deferred("_refresh_info_bar_text_layout")
	call_deferred("_update_cargo_items")
	SaveManager.save_game()

	# Background image
	if current_planet_data:
		_load_background_image()
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
			var cargo_before := _snapshot_cargo()
			smuggler.deal_closed.connect(func():
				_track_arrival_cargo_gains(cargo_before)
				_update_ui()
			)
		# Planet arrival event (only if no smuggler event)
		if not smuggler_active and current_planet_data:
			var cargo_before_event := _snapshot_cargo()
			var planet_event := PlanetEventScene.instantiate()
			add_child(planet_event)
			if not planet_event.try_trigger(current_planet_data.planet_type):
				planet_event.queue_free()
			else:
				planet_event.event_resolved.connect(func():
					_track_arrival_cargo_gains(cargo_before_event)
					_update_ui()
				)
		# Customs scan (after other events, on non-Outlaw planets with contraband)
		var customs := CustomsScanScene.instantiate()
		add_child(customs)
		if not customs.try_scan():
			customs.queue_free()
		else:
			customs.scan_closed.connect(_update_ui)


var _debug_label: Label = null
var _systems_debug_label: Label = null

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_F9:
		if _debug_label:
			_debug_label.queue_free()
			_debug_label = null
		else:
			_debug_label = Label.new()
			_debug_label.z_index = 100
			_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_debug_label.add_theme_color_override("font_color", Color.YELLOW)
			_debug_label.add_theme_font_size_override("font_size", 16)
			_debug_label.position = Vector2(10, 700)
			add_child(_debug_label)
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_F10:
		if _systems_debug_label:
			_systems_debug_label.queue_free()
			_systems_debug_label = null
		else:
			_systems_debug_label = Label.new()
			_systems_debug_label.z_index = 110
			_systems_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_systems_debug_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.85))
			_systems_debug_label.add_theme_font_size_override("font_size", 13)
			_systems_debug_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
			_systems_debug_label.add_theme_constant_override("outline_size", 6)
			_systems_debug_label.position = Vector2(12, 10)
			add_child(_systems_debug_label)
			_systems_debug_label.text = _build_systems_debug_text()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_ESCAPE:
		if _close_top_overlay():
			get_viewport().set_input_as_handled()
		return

	if _has_overlay_open():
		return

	var handled := true
	match key_event.keycode:
		KEY_M: _on_market_pressed()       # Market
		KEY_C: _on_crew_pressed()         # Crew
		KEY_Q: _on_quest_pressed()        # Quest
		KEY_S: _on_shipyard_pressed()     # Shipyard
		KEY_D: _on_view_deck_pressed()    # Deck
		KEY_K: _on_casino_pressed()       # Casino
		KEY_I: _on_mission_pressed()      # Mission
		KEY_G: _on_depart_pressed()       # Depart / Galaxy
		KEY_L: _on_event_log_pressed()    # Event log
		_: handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _has_overlay_open() -> bool:
	return _get_top_overlay() != null


func _get_top_overlay() -> Node:
	# Prioritize nested overlays first (inside ShipyardScreen), then root overlays.
	var overlay_paths: Array[String] = [
		"ShipyardScreen/ShipUpgrades",
		"ShipyardScreen/ShipDealer",
		"DeckViewer",
		"QuestScreen",
		"CrewScreen",
		"MarketScreen",
		"CasinoPopup",
		"ShipyardScreen",
		"EventLogPopup",
		"DepartOverlay",
		"SmugglerEvent",
		"PlanetEvent",
		"PlanetActivity",
	]
	for path in overlay_paths:
		var node := get_node_or_null(path)
		if node:
			return node
	return null


func _close_top_overlay() -> bool:
	var overlay := _get_top_overlay()
	if overlay == null:
		return false
	_close_overlay_node(overlay)
	_update_ui()
	return true


func _close_overlay_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.has_method("_close"):
		node.call("_close")
	elif node.has_method("_on_close_pressed"):
		node.call("_on_close_pressed")
	else:
		node.queue_free()

func _process(_delta: float) -> void:
	if _debug_label:
		var pos: Vector2 = get_viewport().get_mouse_position()
		_debug_label.text = "X: %d  Y: %d" % [int(pos.x), int(pos.y)]
	if _systems_debug_label:
		_systems_debug_label.text = _build_systems_debug_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_info_bar_text_layout()


func _find_planet_data() -> void:
	current_planet_data = EconomyManager.get_planet_data(GameManager.current_planet)


func _snapshot_cargo() -> Dictionary:
	var snapshot: Dictionary = {}
	for item in GameManager.cargo:
		snapshot[item["good_name"]] = item["quantity"]
	return snapshot


func _track_arrival_cargo_gains(cargo_before: Dictionary) -> void:
	for item in GameManager.cargo:
		var gname: String = item["good_name"]
		var old_qty: int = cargo_before.get(gname, 0)
		if item["quantity"] > old_qty:
			_arrival_gained_cargo[gname] = _arrival_gained_cargo.get(gname, 0) + (item["quantity"] - old_qty)


func _load_background_image() -> void:
	var planet_name: String = current_planet_data.planet_name.to_lower().replace(" ", "_")
	var path := "res://assets/sprites/bg_%s.png" % planet_name
	var tex := BackgroundUtils.load_texture(path)
	if tex:
		bg_image.texture = tex
		bg_image.visible = true
		_create_image_hotspots(_get_building_states())


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
	market.setup(pt, _arrival_gained_cargo)
	market.market_closed.connect(func(): _update_ui())


func _on_shipyard_pressed() -> void:
	if has_node("ShipyardScreen"):
		return
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	var shipyard := ShipyardScreenScene.instantiate()
	shipyard.name = "ShipyardScreen"
	add_child(shipyard)
	shipyard.setup(pt)
	shipyard.shipyard_closed.connect(func(): _update_ui())


func _on_casino_pressed() -> void:
	if _casino_done:
		return
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
		_update_ui()
	)


func _on_crew_pressed() -> void:
	if has_node("CrewScreen"):
		return
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	var crew := CrewScreenScene.instantiate()
	crew.name = "CrewScreen"
	add_child(crew)
	crew.setup(pt)
	crew.crew_closed.connect(func(): _update_ui())

func _on_quest_pressed() -> void:
	if has_node("QuestScreen"):
		return
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	var quest := QuestScreenScene.instantiate()
	quest.name = "QuestScreen"
	add_child(quest)
	quest.setup(pt, GameManager.current_planet)
	quest.quest_closed.connect(func(): _update_ui())


func _on_mission_pressed() -> void:
	if _mission_done:
		return
	var pt: int = current_planet_data.planet_type if current_planet_data else 0
	# Starport Alpha keeps the Space Invaders mini-game as the mission.
	# All other planets open the type-specific activity modal.
	if GameManager.current_planet == "Starport Alpha":
		if GameManager.credits < 100:
			EventLog.add_entry("Not enough credits for mission (100cr required).")
			_update_ui()
			return
		GameManager.remove_credits(100)
		GameManager.mission_return_planet = GameManager.current_planet
		EventLog.add_entry("Entered Space Invaders mission (-100cr).")
		GameManager.change_scene("res://scenes/space_invaders.tscn")
		return
	# Other planet types: open the type-specific activity modal.
	if has_node("PlanetActivity"):
		return
	var activity := PlanetActivityScene.instantiate()
	activity.name = "PlanetActivity"
	add_child(activity)
	if not activity.try_open(pt):
		activity.queue_free()
		_update_ui()
		return
	activity.activity_closed.connect(func() -> void:
		_mission_done = true
		_rebuild_hub_buildings()
		_update_ui()
	)


func _rebuild_hub_buildings() -> void:
	var states := _get_building_states()
	if _hotspot_pulse_tween and _hotspot_pulse_tween.is_valid():
		_hotspot_pulse_tween.kill()
		_hotspot_pulse_tween = null
	var hotspot_node := get_node_or_null("ImageHotspots")
	if hotspot_node:
		hotspot_node.queue_free()
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
	hover_style.bg_color = Color(1.0, 1.0, 1.0, 0.08)
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

		# Pulsing dot indicator
		var dot := ColorRect.new()
		dot.size = Vector2(8, 8)
		dot.color = Color(1.0, 0.95, 0.15, 0.9)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(rect.position.x + rect.size.x * 0.5 - 4, rect.position.y + rect.size.y * 0.5 - 4)
		container.add_child(dot)

		# Glow ring around dot
		var glow := ColorRect.new()
		glow.size = Vector2(16, 16)
		glow.color = Color(1.0, 0.25, 0.85, 0.35)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.position = Vector2(rect.position.x + rect.size.x * 0.5 - 8, rect.position.y + rect.size.y * 0.5 - 8)
		container.add_child(glow)

	# Start pulsing animation + initial flash
	_animate_hotspot_dots(container)


func _animate_hotspot_dots(container: Control) -> void:
	# Collect dots and glows (every 3rd child after buttons: dot, glow pairs)
	var dots: Array[ColorRect] = []
	var glows: Array[ColorRect] = []
	for child in container.get_children():
		if child is ColorRect:
			if child.size.x == 8:
				dots.append(child)
			elif child.size.x == 16:
				glows.append(child)

	# Initial flash: briefly highlight all hotspots then fade
	var pair_count: int = mini(dots.size(), glows.size())
	for i: int in pair_count:
		var dot: ColorRect = dots[i]
		var glow: ColorRect = glows[i]
		# Flash bright
		dot.color = Color(1.0, 1.0, 0.3, 1.0)
		glow.color = Color(1.0, 0.3, 0.9, 0.75)
		glow.size = Vector2(24, 24)
		glow.position -= Vector2(4, 4)

	# Fade flash after short delay, then start pulse
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(container):
			return
		for i: int in pair_count:
			var glow: ColorRect = glows[i]
			if is_instance_valid(glow):
				glow.size = Vector2(16, 16)
				glow.position += Vector2(4, 4)
		_start_pulse_loop(container, dots, glows)
	)


func _start_pulse_loop(container: Control, dots: Array[ColorRect], glows: Array[ColorRect]) -> void:
	if _hotspot_pulse_tween and _hotspot_pulse_tween.is_valid():
		_hotspot_pulse_tween.kill()
	var tween := create_tween().set_loops()
	_hotspot_pulse_tween = tween
	tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(container):
			tween.kill()
			return
		var pulse: float = sin(t * TAU)
		var alpha: float = 0.55 + pulse * 0.4
		var glow_alpha: float = 0.25 + pulse * 0.25
		var glow_scale: float = 1.0 + pulse * 0.35
		# Lerp between neon yellow and hot magenta in sync with the pulse.
		var mix: float = 0.5 + pulse * 0.5
		var dot_color: Color = Color(1.0, 0.95, 0.15).lerp(Color(1.0, 0.3, 0.9), mix)
		var glow_color: Color = Color(1.0, 0.3, 0.9).lerp(Color(1.0, 0.95, 0.15), mix)
		var has_live_nodes: bool = false
		for dot: ColorRect in dots:
			if is_instance_valid(dot):
				dot.color = Color(dot_color.r, dot_color.g, dot_color.b, alpha)
				has_live_nodes = true
		for glow: ColorRect in glows:
			if is_instance_valid(glow):
				glow.color = Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha)
				var center: Vector2 = glow.position + glow.size * 0.5
				var new_size: float = 16.0 * glow_scale
				glow.size = Vector2(new_size, new_size)
				glow.position = center - glow.size * 0.5
				has_live_nodes = true
		if not has_live_nodes:
			tween.kill()
	, 0.0, 1.0, 2.0)


# ── Header & Info ────────────────────────────────────────────────────────────


func _make_holo_panel_style(
	bg_alpha: float = 0.75,
	border_color: Color = HOLO_BORDER,
	corner_radius: int = 8,
	content_margin: int = 8,
	with_shadow: bool = true
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.14, bg_alpha)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(corner_radius)
	if with_shadow:
		style.shadow_color = HOLO_SHADOW
		style.shadow_size = 6
	style.set_content_margin_all(content_margin)
	return style


func _make_bar_background_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(3)
	style.border_color = border_color
	style.set_border_width_all(1)
	return style


func _make_bar_fill_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.set_corner_radius_all(3)
	return style


func _style_info_bar() -> void:
	$InfoBar.add_theme_stylebox_override("panel", _make_holo_panel_style())
	header_spacer.visible = true
	_apply_header_label_style(planet_name_label, 26, Color(0.82, 0.97, 1.0))
	_apply_header_label_style(news_banner, 12, Color(0.92, 0.96, 1.0))
	_apply_header_label_style(goal_label, 13, Color(1.0, 0.94, 0.62))


func _apply_header_label_style(label: Label, font_size: int, font_color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = font_color
	settings.shadow_size = 6
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.9)
	settings.shadow_offset = Vector2(2, 2)
	label.label_settings = settings


func _style_ship_panel() -> void:
	ship_status_panel.add_theme_stylebox_override("panel", _make_holo_panel_style())

	# Hull bar colors
	var bar_bg := _make_bar_background_style(Color(0.08, 0.04, 0.04), Color(0.3, 0.1, 0.1))
	hull_bar.add_theme_stylebox_override("background", bar_bg)

	hull_bar.add_theme_stylebox_override("fill", _make_bar_fill_style(Color(0.2, 0.9, 0.2)))


func _style_cargo_bar() -> void:
	var bar_bg := _make_bar_background_style(Color(0.02, 0.06, 0.16), Color(0.0, 0.30, 0.50))
	cargo_bar.add_theme_stylebox_override("background", bar_bg)

	cargo_bar.add_theme_stylebox_override("fill", _make_bar_fill_style(Color(0.0, 0.80, 1.0)))


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
	panel.add_theme_stylebox_override(
		"panel",
		_make_holo_panel_style(0.85, Color(0.0, 0.65, 0.95, 0.85), 12, 16, false)
	)
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

	var log_header_spacer := Control.new()
	log_header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(log_header_spacer)

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
	var faction: String = GameManager.get_planet_faction(GameManager.current_planet)
	var rep: int = GameManager.get_faction_reputation(faction)
	var rep_tier: String = GameManager.get_reputation_tier(faction)
	var loyalty: int = GameManager.get_trade_loyalty(GameManager.current_planet)
	var loyalty_text: String = _get_loyalty_status_text(GameManager.current_planet)
	planet_name_label.text = "%s | %s | Reputation %+d %s | Loyalty %d (%s)" % [
		GameManager.current_planet,
		faction,
		rep,
		rep_tier,
		loyalty,
		loyalty_text,
	]


func _get_loyalty_status_text(planet_name: String) -> String:
	var loyalty_tier: String = GameManager.get_loyalty_tier(planet_name)
	if loyalty_tier == "Unknown":
		return "No standing yet"
	return loyalty_tier


func _update_news_banner() -> void:
	var event_text := EventManager.get_event_display_text()
	var status_notes: Array[String] = _get_local_status_notes()
	if event_text != "" or not status_notes.is_empty():
		var parts: Array[String] = []
		if event_text != "":
			parts.append("SPACE NEWS: " + _compact_news_text(event_text))
		for note in status_notes:
			parts.append(note)
		_news_full_text = " | ".join(parts)
		news_banner.visible = true
	else:
		_news_full_text = ""
		news_banner.visible = false
	_refresh_info_bar_text_layout()


func _update_ui() -> void:
	_update_header()
	_update_news_banner()
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
	if GameManager.has_active_loan():
		goal_label.text += " | Debt %d (%d)" % [GameManager.outstanding_debt, GameManager.debt_due_in_trips]
	if GameManager.bounty_amount > 0:
		goal_label.text += " | %s %d cr" % [GameManager.get_bounty_tier(), GameManager.bounty_amount]
	_refresh_info_bar_text_layout()


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
	var bar_fill := _make_bar_fill_style(Color(0.2, 0.9, 0.2))
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
	
	var shield_bar_bg := _make_bar_background_style(Color(0.04, 0.08, 0.16), Color(0.1, 0.2, 0.4))
	shield_bar.add_theme_stylebox_override("background", shield_bar_bg)
	
	shield_bar.add_theme_stylebox_override("fill", _make_bar_fill_style(Color(0.4, 0.65, 1.0)))
	
	shield_bar.max_value = max(max_shield, 1)
	shield_bar.value = shield


func _update_quest_label() -> void:
	if quest_widget:
		quest_widget.update_widget()


func _refresh_info_bar_text_layout() -> void:
	if not is_instance_valid(info_bar_box):
		return
	if info_bar_box.size.x <= 8.0:
		return

	news_banner.tooltip_text = _news_full_text

	var button_width: float = 0.0
	var button_count: int = 0
	for child in info_bar_box.get_children():
		if child is Button and child.visible:
			button_width += float((child as Control).get_combined_minimum_size().x)
			button_count += 1

	var separator: float = float(info_bar_box.get_theme_constant("separation"))
	var goal_width: float = _measure_label_text(goal_label, goal_label.text)
	var reserved: float = button_width + goal_width + separator * float(button_count + 3) + 24.0
	var available: float = float(info_bar_box.size.x) - reserved

	if available <= 0.0:
		news_banner.text = ""
		return

	var show_news: bool = _news_full_text != ""
	if not show_news:
		news_banner.visible = false
	else:
		news_banner.visible = true
		news_banner.text = _truncate_label_text(news_banner, _news_full_text, available)


func _truncate_label_text(label: Label, text: String, max_width: float) -> String:
	if text == "":
		return ""
	if max_width <= 0.0:
		return ""
	if _measure_label_text(label, text) <= max_width:
		return text

	var ellipsis := "..."
	if _measure_label_text(label, ellipsis) > max_width:
		return ""

	var low: int = 0
	var high: int = text.length()
	while low < high:
		@warning_ignore("integer_division")
		var mid: int = (low + high + 1) / 2
		var candidate := text.substr(0, mid).strip_edges(false, true) + ellipsis
		if _measure_label_text(label, candidate) <= max_width:
			low = mid
		else:
			high = mid - 1
	return text.substr(0, low).strip_edges(false, true) + ellipsis


func _measure_label_text(label: Label, text: String) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	if font:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return float(text.length()) * float(maxi(6, font_size)) * 0.55


func _compact_news_text(text: String) -> String:
	var compact := text
	compact = compact.replace("encounter chance", "encounters")
	return compact


func _get_local_status_notes() -> Array[String]:
	var notes: Array[String] = []
	var faction: String = GameManager.get_planet_faction(GameManager.current_planet)
	var rep_tier: String = GameManager.get_reputation_tier(faction)
	var loyalty_tier: String = GameManager.get_loyalty_tier(GameManager.current_planet)
	var bounty_tier: String = GameManager.get_bounty_tier()

	if rep_tier in ["Trusted", "Allied"]:
		notes.append("Trusted trader discounts active")
	elif rep_tier == "Hostile":
		notes.append("Local authorities are openly hostile")

	if loyalty_tier in ["Preferred", "Local Hero"]:
		notes.append("Local trade network favors you")

	if bounty_tier in ["Wanted", "Most Wanted"] and GameManager.get_planet_faction(GameManager.current_planet) != GameManager.FACTION_BY_PLANET_TYPE.get(EconomyManager.PT_OUTLAW, "Free Cartel"):
		notes.append("Patrols intensified for wanted traffic")

	return notes


func _build_systems_debug_text() -> String:
	var faction: String = GameManager.get_planet_faction(GameManager.current_planet)
	var rep: int = GameManager.get_faction_reputation(faction)
	var rep_tier: String = GameManager.get_reputation_tier(faction)
	var loyalty: int = GameManager.get_trade_loyalty(GameManager.current_planet)
	var loyalty_tier: String = GameManager.get_loyalty_tier(GameManager.current_planet)
	var bounty_tier: String = GameManager.get_bounty_tier()
	var buy_mod: float = GameManager.get_market_buy_modifier(GameManager.current_planet)
	var sell_mod: float = GameManager.get_market_sell_modifier(GameManager.current_planet)
	var customs_scan_mod: float = GameManager.get_customs_scan_modifier(GameManager.current_planet)
	var customs_fine_mod: float = GameManager.get_customs_fine_modifier(GameManager.current_planet)
	var customs_hide_mod: float = GameManager.get_customs_hide_modifier(GameManager.current_planet)
	var quest_reward_mod: float = GameManager.get_quest_reward_modifier(faction)
	var quest_deadline_mod: int = GameManager.get_quest_deadline_modifier(faction)
	var service_fee_mod: float = GameManager.get_planet_service_fee_modifier(GameManager.current_planet)
	var chance: float = EncounterManager.estimate_encounter_chance(
		current_planet_data.danger_level if current_planet_data else 1,
		GameManager.current_planet
	)

	var rep_parts: Array[String] = []
	for f in GameManager.faction_reputation.keys():
		rep_parts.append("%s:%d" % [str(f), int(GameManager.faction_reputation[f])])
	rep_parts.sort()

	var quest_text := "none"
	if QuestManager.has_active_quest():
		var q: Dictionary = QuestManager.current_quest
		quest_text = "%s %d/%d | %d trips" % [
			q.get("issuer_faction", "Independent"),
			q.get("stage", 1),
			q.get("chain_length", 1),
			q.get("turns_left", 0)
		]

	return "DEBUG [F10]\nPlanet: %s\nLocal Faction: %s (%+d, %s)\nLoyalty: %d (%s)\nBounty: %d cr (%s)\nBuy/Sell Mod: %.2f / %.2f\nCustoms: Scan %+.0f%% | Fine x%.2f | Hide %+.0f%%\nQuest Terms: Reward %+.0f%% | Deadline %+d\nService Fee: x%.2f\nEncounter Chance: %.0f%%\nDebt: %s | Risk +%.0f%%\nQuest: %s\nTracked Goods: %d\nAll Reps: %s" % [
		GameManager.current_planet,
		faction,
		rep,
		rep_tier,
		loyalty,
		loyalty_tier,
		GameManager.bounty_amount,
		bounty_tier,
		buy_mod,
		sell_mod,
		customs_scan_mod * 100.0,
		customs_fine_mod,
		customs_hide_mod * 100.0,
		quest_reward_mod * 100.0,
		quest_deadline_mod,
		service_fee_mod,
		chance * 100.0,
		GameManager.get_debt_status_text(),
		GameManager.get_debt_risk_modifier() * 100.0,
		quest_text,
		GameManager.trade_route_memory.size(),
		", ".join(rep_parts)
	]


func _update_cargo_items() -> void:
	for child in cargo_items_row.get_children():
		child.queue_free()
	var cargo_items: Array = GameManager.cargo
	if cargo_items.is_empty():
		return

	var available_width: float = cargo_items_row.size.x
	if available_width <= 2.0:
		var parent_ctrl := cargo_items_row.get_parent() as Control
		if parent_ctrl:
			available_width = parent_ctrl.size.x
	if available_width <= 2.0:
		available_width = CARGO_FALLBACK_ROW_WIDTH

	var max_icons: int = maxi(1, int(floor((available_width + 2.0) / CARGO_ICON_SLOT_WIDTH)))
	var visible_count: int = mini(cargo_items.size(), max_icons)
	var hidden_count: int = 0
	if cargo_items.size() > max_icons:
		# Reserve one slot for overflow indicator (e.g. +3).
		visible_count = maxi(1, max_icons - 1)
		hidden_count = cargo_items.size() - visible_count

	for i in visible_count:
		var item: Dictionary = cargo_items[i]
		var good_name: String = item["good_name"]
		var qty: int = item["quantity"]
		var icon := Control.new()
		icon.set_script(GoodIcon)
		icon.setup(good_name)
		icon.tooltip_text = "%s x%d" % [good_name, qty]
		cargo_items_row.add_child(icon)

	if hidden_count > 0:
		var more_label := Label.new()
		more_label.text = "+%d" % hidden_count
		more_label.add_theme_font_size_override("font_size", 12)
		more_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.35))
		more_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		more_label.tooltip_text = "%d more cargo types" % hidden_count
		cargo_items_row.add_child(more_label)

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
	panel.add_theme_stylebox_override("panel", _make_holo_panel_style(0.95, ACCENT_DEPART, 14, 32, false))
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
	GameManager.reset_ghost_run()
	QuestManager.tick()
	EventManager.tick()
	EconomyManager.tick_economy()
	GameManager.process_loan_tick()
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
	viewer.tree_exited.connect(func(): _update_ui())





func _add_header_buttons() -> void:
	var header := $InfoBar/InfoBarBox
	var event_log_btn := _create_small_header_button("Event Log", _on_event_log_pressed)
	header.add_child(event_log_btn)

	var menu_btn := _create_small_header_button("Menu", _on_menu_pressed)
	header.add_child(menu_btn)
	header.move_child(header_spacer, header.get_child_count() - 3)
	_refresh_info_bar_text_layout()


func _create_small_header_button(text: String, callback: Callable) -> Button:
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


func _on_menu_pressed() -> void:
	SaveManager.save_game()
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

func _show_quest_arrival_toast() -> void:
	var toast := Label.new()
	toast.text = "Quest Destination Reached!"
	toast.add_theme_font_size_override("font_size", 24)
	toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	toast.add_theme_color_override("font_outline_color", Color(0,0,0, 0.8))
	toast.add_theme_constant_override("outline_size", 8)
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.position = Vector2(0, -80)
	
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	container.add_child(toast)
	
	var tween = create_tween()
	tween.tween_property(toast, "position:y", -180.0, 4.0).as_relative().set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(toast, "modulate:a", 0.0, 4.0).set_ease(Tween.EASE_IN)
	tween.tween_callback(container.queue_free)
