extends Control

## Planet Hub — visual scene with clickable buildings that open sub-screens.
## Market, Cargo, Crew, and Shipyard are now separate fullscreen overlays.

const PlanetArrival = preload("res://scripts/components/planet_arrival.gd")
const HubOverlayStack = preload("res://scripts/components/hub_overlay_stack.gd")
const HubDebug = preload("res://scripts/components/hub_debug.gd")

var _arrival: Control
var _overlays: RefCounted = HubOverlayStack.new()
var _debug: Node

const DeckViewerScene = preload("res://scenes/deck_viewer.tscn")
const CasinoPopupScene: PackedScene = preload("res://scenes/components/casino_popup.tscn")
const MarketScreenScene: PackedScene = preload("res://scenes/components/market_screen.tscn")
const CrewScreenScene: PackedScene = preload("res://scenes/components/crew_screen.tscn")
const ShipyardScreenScene: PackedScene = preload("res://scenes/components/shipyard_screen.tscn")
const QuestScreenScene: PackedScene = preload("res://scenes/components/quest_screen.tscn")
const FactoryScreenScene: PackedScene = preload("res://scenes/factory_screen.tscn")
const ShipStatusOverlayScene: PackedScene = preload("res://scenes/components/ship_status_overlay.tscn")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")
const GoodIcon = preload("res://scripts/components/good_icon.gd")
const CrewIcon = preload("res://scripts/components/crew_icon.gd")
const PlanetActivityScene = preload("res://scenes/components/planet_activity.tscn")
# Scripts (not scenes) — used for their static mission metadata in the
# pre-mission confirmation dialog.
const PlanetActivity = preload("res://scripts/components/planet_activity.gd")
const StarportDefense = preload("res://scripts/scenes/starport_defense.gd")



# Hologram panel style constants
const HOLO_BORDER := UIStyles.PANEL_BORDER
const ACCENT_DEPART := Color(0.0, 0.85, 0.45)
const HOLO_SHADOW := Color(0.0, 0.45, 0.9, 0.25)
const CARGO_ICON_SLOT_WIDTH: float = 20.0
const CARGO_FALLBACK_ROW_WIDTH: float = 120.0

## Bounds both the rendered log and the Copy button.
const EVENT_LOG_VISIBLE: int = 50

var current_planet_data: Resource = null
var _news_full_text: String = ""
var _hotspot_pulse_tween: Tween = null

@onready var planet_name_label := $VBoxContainer/PlanetNameLabel
@onready var info_bar: Control = $InfoBar
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
@onready var fuel_label := $ShipStatusPanel/ShipStatusBox/ShipStats/FuelLabel
@onready var fuel_bar := $ShipStatusPanel/ShipStatusBox/ShipStats/FuelBar
@onready var bg_image: TextureRect = $BgImage


# ── Building IDs ─────────────────────────────────────────────────────────────

# Building IDs are defined in CityMap and referenced here as CityMap.BUILDING_*.


func _ready() -> void:
	_debug = HubDebug.new()
	add_child(_debug)
	_debug.state_changed.connect(_update_ui)
	_debug.toast_requested.connect(_show_toast)
	_arrival = PlanetArrival.new()
	_arrival.state_changed.connect(_update_ui)
	_arrival.finished.connect(_on_arrival_finished)
	# Hints are created by HintManager; register them when attached to this hub.
	child_entered_tree.connect(_on_child_entered)
	AudioManager.play_bgm("res://assets/audio/bgm/planet.ogg")
	GameManager.cargo_changed.connect(_update_cargo_display)
	StandingManager.reputation_changed.connect(_on_standing_changed)
	StandingManager.loyalty_changed.connect(_on_standing_changed)
	StandingManager.bounty_changed.connect(_on_standing_changed)
	tree_exiting.connect(_disconnect_standing_signals)
	current_planet_data = EconomyManager.get_planet_data(GameManager.current_planet)
	# Check quest penalty after battle credits have been awarded
	if QuestManager.check_expired_quest():
		_arrival.free()
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")
		return
	# Battle/quest credits and the 7th planet visit complete the win condition
	# away from the market, so re-check on every arrival.
	GameManager.try_trigger_victory()
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

	quest_widget.clicked.connect(func() -> void: _on_building_clicked(CityMap.BUILDING_QUEST))
	call_deferred("_refresh_info_bar_text_layout")
	call_deferred("_update_cargo_items")
	SaveManager.save_game()

	# Background image
	if current_planet_data:
		_load_background_image()
	add_child(_arrival)
	if not GameManager.arrival_events_done:
		_arrival.run(current_planet_data)


func _on_arrival_finished() -> void:
	_update_ui()
	if GameManager.current_day == 1 and not GameManager.intro_shown:
		GameManager.intro_shown = true
		SaveManager.save_game()
		call_deferred("_show_intro_overlay")
	else:
		call_deferred("_show_planet_hub_hint")


func _show_planet_hub_hint() -> void:
	if is_inside_tree():
		HintManager.show_hint_popup("planet_hub", self)

func _show_intro_overlay() -> void:
	var diff_text: String = "%d cr required" % GameManager.get_win_credits()
	_show_hint_card(
		"WELCOME TO STARPORT ALPHA",
		"Your goal is to locate and defeat the infamous pirate lord Crimson Jack.\n\nTo find his hidden base, you must meet the following prerequisites:\n• Amass wealth (" + diff_text + ")\n• Visit all 7 planets\n• Install a T2 upgrade (crafted via Fabrication)\n• Have no open bounty\n\nGood luck, captain.",
		"",
		"Start Adventure",
		func() -> void:
			call_deferred("_show_planet_hub_hint")
	)



func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if _arrival.running:
		return
	if _debug.handle_key(key_event):
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_ESCAPE:
		if _close_top_overlay():
			get_viewport().set_input_as_handled()
		return

	if _has_overlay_open():
		return

	# Routed through _on_building_clicked so the keyboard shortcuts get the same
	# first-visit hint as clicking the building on the map.
	var handled := true
	match key_event.keycode:
		KEY_M: _on_building_clicked(CityMap.BUILDING_MARKET)
		KEY_C: _on_building_clicked(CityMap.BUILDING_CREW)
		KEY_Q: _on_building_clicked(CityMap.BUILDING_QUEST)
		KEY_S: _on_building_clicked(CityMap.BUILDING_SHIPYARD)
		KEY_D: _on_building_clicked(CityMap.BUILDING_DECK)
		KEY_K: _on_building_clicked(CityMap.BUILDING_CASINO)
		KEY_I: _on_building_clicked(CityMap.BUILDING_MISSION)
		KEY_F: _on_building_clicked(CityMap.BUILDING_FACTORY)
		KEY_G: _on_depart_pressed()       # Depart / Galaxy
		KEY_L: _on_event_log_pressed()    # Event log
		_: handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _has_overlay_open() -> bool:
	return _arrival.running or _overlays.has_open_overlay()


func _close_top_overlay() -> bool:
	if _arrival.running:
		return false
	if not _overlays.close_top():
		return false
	_update_ui()
	return true


func _on_child_entered(node: Node) -> void:
	if str(node.name).begins_with("HintPopup_"):
		_overlays.register(node)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_info_bar_text_layout()


func _load_background_image() -> void:
	var planet_name: String = current_planet_data.planet_name.to_lower().replace(" ", "_").replace("'", "")
	if planet_name == "crimson_jacks_hideout":
		planet_name = "crimson_base"
	var path := "res://assets/sprites/scenes/bg_%s.png" % planet_name
	var tex := BackgroundUtils.load_texture(path)
	if tex:
		bg_image.texture = tex
		bg_image.visible = true
		_create_image_hotspots()


func _on_building_clicked(building_id: String) -> void:
	if _has_overlay_open():
		return
	# First visit to a building explains it once; afterwards it opens directly.
	if not HintManager.take_hint(building_id).is_empty():
		HintManager.show_hint_popup(building_id, self, func() -> void: _open_building(building_id))
		return
	_open_building(building_id)


## Planet type of the current planet; Industrial (0) when planet data is missing.
func _current_planet_type() -> int:
	return current_planet_data.planet_type if current_planet_data else EconomyManager.PT_INDUSTRIAL


## Opens one of the fullscreen building overlays: refuses a second instance,
## registers it with the overlay stack, and refreshes the hub when it closes.
## The overlays build their UI in _ready(), so the caller applies setup() to the
## returned node — after it is in the tree.
func _open_screen_overlay(node_name: String, scene: PackedScene, close_signal: StringName) -> Node:
	if has_node(node_name):
		return null
	var overlay: Node = scene.instantiate()
	overlay.name = node_name
	add_child(overlay)
	_overlays.register(overlay)
	overlay.connect(close_signal, _update_ui)
	return overlay


func _open_building(building_id: String) -> void:
	match building_id:
		CityMap.BUILDING_MARKET:   _on_market_pressed()
		CityMap.BUILDING_SHIPYARD: _on_shipyard_pressed()
		CityMap.BUILDING_CASINO:   _on_casino_pressed()
		CityMap.BUILDING_CREW:     _on_crew_pressed()
		CityMap.BUILDING_QUEST:    _on_quest_pressed()
		CityMap.BUILDING_DECK:     _on_view_deck_pressed()
		CityMap.BUILDING_DEPART:   _on_depart_pressed()
		CityMap.BUILDING_MISSION:  _on_mission_pressed()
		CityMap.BUILDING_FACTORY:  _on_factory_pressed()


# ── Building callbacks ───────────────────────────────────────────────────────

func _on_market_pressed() -> void:
	var market := _open_screen_overlay("MarketScreen", MarketScreenScene, "market_closed")
	if market:
		market.setup(_current_planet_type(), GameManager.arrival_gained_cargo)


func _on_shipyard_pressed() -> void:
	var shipyard := _open_screen_overlay("ShipyardScreen", ShipyardScreenScene, "shipyard_closed")
	if shipyard:
		shipyard.setup(_current_planet_type())


func _on_casino_pressed() -> void:
	if GameManager.casino_rounds_this_landing >= 5:
		AudioManager.play_ui_denied()
		_show_toast("Casino limit reached for this landing!", Color(1.0, 0.75, 0.3))
		return
	var popup := _open_screen_overlay("CasinoPopup", CasinoPopupScene, "casino_closed")
	if popup == null:
		return
	popup.setup(_current_planet_type(), 5 - GameManager.casino_rounds_this_landing)
	popup.casino_closed.connect(func():
		GameManager.casino_rounds_this_landing += popup.rounds_played
		if GameManager.casino_rounds_this_landing >= 5:
			_rebuild_hub_buildings()
	)


func _on_crew_pressed() -> void:
	var crew := _open_screen_overlay("CrewScreen", CrewScreenScene, "crew_closed")
	if crew:
		crew.setup(_current_planet_type())


func _on_quest_pressed() -> void:
	var quest := _open_screen_overlay("QuestScreen", QuestScreenScene, "quest_closed")
	if quest:
		quest.setup(_current_planet_type(), GameManager.current_planet)


func _on_mission_pressed() -> void:
	if GameManager.mission_done_this_landing:
		AudioManager.play_ui_denied()
		_show_toast("Mission already completed for this landing!", Color(1.0, 0.75, 0.3))
		return
	if has_node("MissionConfirm") or has_node("PlanetActivity"):
		return
	# Entering a mission costs credits and cannot be undone, so the player sees
	# name, rules and full cost before anything is charged.
	if GameManager.current_planet == "Starport Alpha":
		_show_mission_confirm(
			"Starport Defense",
			"Shoot down all %d raiders before you run out of lives. Winning pays %dcr; losing costs hull. Aborting mid-run costs an extra %dcr." % [
				StarportDefense.GRID_COLS * StarportDefense.GRID_ROWS,
				StarportDefense.WIN_REWARD,
				StarportDefense.ABORT_PENALTY,
			],
			StarportDefense.ENTRY_COST,
			StarportDefense.ABORT_PENALTY,
			_start_starport_defense,
		)
		return
	var pt: int = _current_planet_type()
	var kind: int = PlanetActivity.kind_for_type(pt)
	_show_mission_confirm(
		PlanetActivity.name_for_kind(kind),
		PlanetActivity.rules_for_kind(kind),
		PlanetActivity.entry_fee_for_kind(kind),
		0,
		_start_planet_activity.bind(pt),
	)


func _start_starport_defense() -> void:
	GameManager.remove_credits(StarportDefense.ENTRY_COST)
	GameManager.mission_return_planet = GameManager.current_planet
	EventLog.add_entry("Entered Starport Defense mission (-%dcr)." % StarportDefense.ENTRY_COST)
	GameManager.change_scene("res://scenes/starport_defense.tscn")


func _start_planet_activity(planet_type: int) -> void:
	if has_node("PlanetActivity"):
		return
	var activity := PlanetActivityScene.instantiate()
	activity.name = "PlanetActivity"
	add_child(activity)
	_overlays.register(activity)
	if not activity.try_open(planet_type):
		activity.queue_free()
		_update_ui()
		return
	activity.activity_closed.connect(func() -> void:
		GameManager.mission_done_this_landing = true
		_rebuild_hub_buildings()
		_update_ui()
	)




## Modal onboarding card: title, wrapped body, optional footnote and one
## acknowledge button. Shared by the intro and the per-building hints, which are
## mutually exclusive — both live under the "HintPopup" node.
func _show_hint_card(
	title_text: String,
	body_text: String,
	note_text: String,
	button_text: String,
	on_ack: Callable = Callable(),
) -> void:
	if has_node("HintPopup"):
		return
	var modal := _create_modal_overlay("HintPopup", 470, 0.7)
	var overlay: ColorRect = modal.overlay
	var vbox: VBoxContainer = modal.vbox

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	title.add_theme_font_size_override("font_size", UIStyles.FONT_HEADING)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	vbox.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(420, 0)
	body.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
	body.add_theme_color_override("font_color", Color(0.88, 0.93, 0.97))
	vbox.add_child(body)

	if note_text != "":
		var note := Label.new()
		note.text = note_text
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
		note.add_theme_color_override("font_color", Color(0.5, 0.62, 0.72))
		vbox.add_child(note)

	var btn := Button.new()
	btn.text = button_text
	btn.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
	btn.theme_type_variation = UIStyles.BTN_PRIMARY
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		if on_ack.is_valid():
			on_ack.call()
	)
	vbox.add_child(btn)


## Modal shown before a paid mission starts: what it is, how it works, what it
## costs, and what walking out early costs. Emits nothing — runs on_confirm.
func _show_mission_confirm(
	mission_name: String,
	rules_text: String,
	entry_fee: int,
	abort_penalty: int,
	on_confirm: Callable,
) -> void:
	var modal := _create_modal_overlay("MissionConfirm", 460, 0.75)
	var overlay: ColorRect = modal.overlay
	var vbox: VBoxContainer = modal.vbox

	var title := Label.new()
	title.text = mission_name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	title.add_theme_font_size_override("font_size", UIStyles.FONT_HEADING)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	vbox.add_child(title)

	var rules := Label.new()
	rules.text = rules_text
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size = Vector2(400, 0)
	rules.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
	rules.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	vbox.add_child(rules)

	var cost_lines: Array[String] = []
	if entry_fee > 0:
		cost_lines.append("Entry fee: %d cr" % entry_fee)
	else:
		cost_lines.append("Entry fee: Free")
	if abort_penalty > 0:
		cost_lines.append("Leaving early: %d cr extra" % abort_penalty)
	cost_lines.append("One mission per landing.")
	var cost := Label.new()
	cost.text = "\n".join(cost_lines)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_font_override("font", UIStyles.FONT_MONO)
	cost.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
	cost.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(cost)

	var can_afford: bool = GameManager.credits >= entry_fee
	var btn_start := Button.new()
	if entry_fee > 0:
		btn_start.text = "Start (%dcr)" % entry_fee if can_afford else "Need %d cr" % entry_fee
	else:
		btn_start.text = "Start"
	btn_start.disabled = not can_afford
	btn_start.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
	btn_start.theme_type_variation = UIStyles.BTN_PRIMARY
	btn_start.pressed.connect(func() -> void:
		overlay.queue_free()
		on_confirm.call()
	)
	vbox.add_child(btn_start)

	var btn_back := Button.new()
	btn_back.text = "Back"
	btn_back.theme_type_variation = UIStyles.BTN_DANGER
	btn_back.pressed.connect(func() -> void: overlay.queue_free())
	vbox.add_child(btn_back)


func _rebuild_hub_buildings() -> void:
	if _hotspot_pulse_tween and _hotspot_pulse_tween.is_valid():
		_hotspot_pulse_tween.kill()
		_hotspot_pulse_tween = null
	var hotspot_node := get_node_or_null("ImageHotspots")
	if hotspot_node:
		hotspot_node.queue_free()
		_create_image_hotspots()


func _create_image_hotspots() -> void:
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

	var dots: Array[ColorRect] = []
	var glows: Array[ColorRect] = []
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
		btn.disabled = false
		# Invisible hit areas over the city map -- deliberately unthemed.
		btn.add_theme_stylebox_override("normal",   empty)
		btn.add_theme_stylebox_override("pressed",  empty)
		btn.add_theme_stylebox_override("disabled", empty)
		btn.add_theme_stylebox_override("focus",    empty)
		btn.add_theme_stylebox_override("hover",    hover_style)

		var captured_bid: String = bid
		btn.pressed.connect(func() -> void: _on_building_clicked(captured_bid))
		container.add_child(btn)

		# Hover label with the canonical building name, so the map and the
		# overlay title always agree (the painted signage is decorated variants).
		var name_label := _create_hotspot_label(bid, rect)
		container.add_child(name_label)
		btn.mouse_entered.connect(func() -> void: name_label.visible = true)
		btn.mouse_exited.connect(func() -> void: name_label.visible = false)

		# Pulsing dot indicator
		var dot := ColorRect.new()
		dot.size = Vector2(8, 8)
		dot.color = Color(1.0, 0.85, 0.25, 0.95) if bid == CityMap.BUILDING_FACTORY else Color(1.0, 0.95, 0.15, 0.9)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(rect.position.x + rect.size.x * 0.5 - 4, rect.position.y + rect.size.y * 0.5 - 4)
		container.add_child(dot)
		dots.append(dot)

		# Glow ring around dot
		var glow := ColorRect.new()
		glow.size = Vector2(16, 16)
		glow.color = Color(0.2, 0.85, 1.0, 0.5) if bid == CityMap.BUILDING_FACTORY else Color(1.0, 0.25, 0.85, 0.35)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.position = Vector2(rect.position.x + rect.size.x * 0.5 - 8, rect.position.y + rect.size.y * 0.5 - 8)
		container.add_child(glow)
		glows.append(glow)

	# Start pulsing animation + initial flash
	_animate_hotspot_dots(container, dots, glows)


## Floating name plate shown while a building hotspot is hovered.
## Anchors mirror the hotspot rect (authored against the 1280x720 design size)
## and grow sideways so long names stay centred and readable.
func _create_hotspot_label(building_id: String, rect: Rect2) -> Label:
	var label := Label.new()
	var bname: String = CityMap.get_building_name(building_id, _current_planet_type())
	label.text = bname
	label.visible = false
	label.anchor_left = rect.position.x / 1280.0
	label.anchor_right = (rect.position.x + rect.size.x) / 1280.0
	label.anchor_top = rect.position.y / 720.0
	label.anchor_bottom = rect.position.y / 720.0
	label.offset_left = -70.0
	label.offset_right = 70.0
	label.offset_top = -28.0
	label.offset_bottom = -6.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	label.add_theme_font_size_override("font_size", UIStyles.FONT_DETAIL)
	label.add_theme_color_override("font_color", Color(0.85, 0.97, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	return label


func _animate_hotspot_dots(container: Control, dots: Array[ColorRect], glows: Array[ColorRect]) -> void:
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


func _create_modal_overlay(overlay_name: String, min_width: float, alpha: float = 0.7) -> Dictionary:
	var overlay := ColorRect.new()
	if overlay_name != "":
		overlay.name = overlay_name
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, alpha)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_overlays.register(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_holo_panel_style(0.96, HOLO_BORDER, 14, 24, false))
	if min_width > 0:
		panel.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	return { "overlay": overlay, "panel": panel, "vbox": vbox }

func _make_holo_panel_style(
	bg_alpha: float = 0.75,
	border_color: Color = HOLO_BORDER,
	corner_radius: int = 8,
	content_margin: int = 8,
	with_shadow: bool = true
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UIStyles.PANEL_BG, bg_alpha)
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
	_apply_header_label_style(planet_name_label, UIStyles.FONT_TITLE, Color(0.82, 0.97, 1.0), UIStyles.FONT_DISPLAY)
	_apply_header_label_style(news_banner, 12, Color(0.92, 0.96, 1.0))
	news_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	news_banner.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	news_banner.gui_input.connect(_on_news_banner_input)
	_apply_header_label_style(goal_label, 13, Color(1.0, 0.94, 0.62), UIStyles.FONT_MONO)
	# Tooltips only fire on Controls that accept mouse input.
	goal_label.mouse_filter = Control.MOUSE_FILTER_STOP
	goal_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Tooltip target for the reputation/loyalty readout written in _update_header().
	planet_name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	# Tooltips never fire on touch (iPad), so a tap opens the same text as a popup.
	goal_label.gui_input.connect(_on_goal_label_input)
	_wrap_planet_title_in_panel()


## The planet title sits over the planet artwork, which is bright on some
## planets (e.g. Starport Alpha). Give it the same holo backdrop as the other
## header panels instead of relying on the outline alone.
func _wrap_planet_title_in_panel() -> void:
	var parent := planet_name_label.get_parent()
	if parent is PanelContainer:
		return
	var title_index: int = planet_name_label.get_index()
	var row := HBoxContainer.new()
	row.name = "PlanetTitleRow"
	var backdrop := PanelContainer.new()
	backdrop.name = "PlanetTitlePanel"
	backdrop.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	backdrop.add_theme_stylebox_override("panel", _make_holo_panel_style(0.62, HOLO_BORDER, 8, 10))
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	backdrop.gui_input.connect(_on_planet_title_input)
	parent.remove_child(planet_name_label)
	planet_name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	backdrop.add_child(planet_name_label)
	row.add_child(backdrop)
	parent.add_child(row)
	parent.move_child(row, title_index)


func _apply_header_label_style(label: Label, font_size: int, font_color: Color, font_override: FontFile = null) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	var settings := LabelSettings.new()
	if font_override != null:
		settings.font = font_override
	settings.font_size = font_size
	settings.font_color = font_color
	settings.shadow_size = 6
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.9)
	settings.shadow_offset = Vector2(2, 2)
	label.label_settings = settings


var _hull_bar_fill: StyleBoxFlat


func _style_ship_panel() -> void:
	ship_status_panel.add_theme_stylebox_override("panel", _make_holo_panel_style())
	ship_status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ship_status_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ship_status_panel.gui_input.connect(_on_ship_panel_input)
	$ShipStatusPanel/ShipStatusBox.mouse_filter = Control.MOUSE_FILTER_PASS
	$ShipStatusPanel/ShipStatusBox/ShipColumn.mouse_filter = Control.MOUSE_FILTER_PASS
	$ShipStatusPanel/ShipStatusBox/ShipStats.mouse_filter = Control.MOUSE_FILTER_PASS
	$ShipStatusPanel/ShipStatusBox/ShipStats/CargoRow.mouse_filter = Control.MOUSE_FILTER_PASS
	ship_display.mouse_filter = Control.MOUSE_FILTER_PASS
	hull_label.mouse_filter = Control.MOUSE_FILTER_PASS
	shield_label.mouse_filter = Control.MOUSE_FILTER_PASS
	fuel_label.mouse_filter = Control.MOUSE_FILTER_PASS
	capacity_label.mouse_filter = Control.MOUSE_FILTER_PASS
	hull_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	shield_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	fuel_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	cargo_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	cargo_items_row.mouse_filter = Control.MOUSE_FILTER_PASS
	crew_items_row.mouse_filter = Control.MOUSE_FILTER_PASS

	UIStyles.apply_mono_font(hull_label)
	UIStyles.apply_mono_font(shield_label)
	UIStyles.apply_mono_font(fuel_label)
	UIStyles.apply_mono_font(capacity_label)
	var ship_title: Label = $ShipStatusPanel/ShipStatusBox/ShipStats/ShipTitle
	if ship_title:
		UIStyles.apply_display_font(ship_title)
	var cargo_label_node: Label = $ShipStatusPanel/ShipStatusBox/ShipStats/CargoRow/CargoLabel
	if cargo_label_node:
		UIStyles.apply_mono_font(cargo_label_node)

	hull_bar.add_theme_stylebox_override("background", _make_bar_background_style(Color(0.08, 0.04, 0.04), Color(0.3, 0.1, 0.1)))
	_hull_bar_fill = _make_bar_fill_style(Color(0.2, 0.9, 0.2))
	hull_bar.add_theme_stylebox_override("fill", _hull_bar_fill)

	shield_bar.add_theme_stylebox_override("background", _make_bar_background_style(Color(0.04, 0.08, 0.16), Color(0.1, 0.2, 0.4)))
	shield_bar.add_theme_stylebox_override("fill", _make_bar_fill_style(Color(0.4, 0.65, 1.0)))

	fuel_bar.add_theme_stylebox_override("background", _make_bar_background_style(Color(0.12, 0.08, 0.02), Color(0.35, 0.2, 0.0)))
	fuel_bar.add_theme_stylebox_override("fill", _make_bar_fill_style(Color(1.0, 0.65, 0.1)))


func _style_cargo_bar() -> void:
	var bar_bg := _make_bar_background_style(Color(0.02, 0.06, 0.16), Color(0.0, 0.30, 0.50))
	cargo_bar.add_theme_stylebox_override("background", bar_bg)

	cargo_bar.add_theme_stylebox_override("fill", _make_bar_fill_style(Color(0.0, 0.80, 1.0)))


func _on_event_log_pressed() -> void:
	if _arrival.running:
		return
	if has_node("EventLogPopup"):
		return
	var overlay := ColorRect.new()
	overlay.name = "EventLogPopup"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_overlays.register(overlay)

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
		_make_holo_panel_style(0.85, HOLO_BORDER, 12, 16, false)
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
	title.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	title.add_theme_font_size_override("font_size", UIStyles.FONT_HEADING)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	header.add_child(title)

	var log_header_spacer := Control.new()
	log_header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(log_header_spacer)

	var copy_btn := Button.new()
	copy_btn.text = "Copy Last 50"
	copy_btn.theme_type_variation = UIStyles.BTN_INFO
	copy_btn.pressed.connect(func():
		var txt: String = ""
		var ents: Array = EventLog.get_entries()
		var start_idx: int = maxi(0, ents.size() - EVENT_LOG_VISIBLE)
		for i in range(ents.size() - 1, start_idx - 1, -1):
			txt += ents[i] + "\n"
		DisplayServer.clipboard_set(txt.strip_edges())
		copy_btn.text = "Copied!"
	)
	header.add_child(copy_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.theme_type_variation = UIStyles.BTN_DANGER
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

	# The log itself is intentionally unbounded, but rendering it is not: one
	# Label per entry would build thousands of nodes in a long run. Show the most
	# recent EVENT_LOG_VISIBLE, matching what the Copy button exports.
	var entries := EventLog.get_entries()
	var oldest_shown: int = maxi(0, entries.size() - EVENT_LOG_VISIBLE)
	for i in range(entries.size() - 1, oldest_shown - 1, -1):
		var lbl := Label.new()
		lbl.text = entries[i]
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
		lbl.add_theme_color_override("font_color", Color(0.35, 0.65, 0.85))
		list.add_child(lbl)


func _on_factory_pressed() -> void:
	if current_planet_data == null or current_planet_data.planet_type != EconomyManager.PT_TECH:
		return
	if has_node("FactoryScreen"):
		return
	var factory := FactoryScreenScene.instantiate()
	factory.name = "FactoryScreen"
	factory.setup(GameManager.current_planet)
	add_child(factory)
	_overlays.register(factory)
	factory.tree_exited.connect(_update_ui)



func _on_standing_changed(_a = null, _b = null, _c = null) -> void:
	_update_header()


func _disconnect_standing_signals() -> void:
	StandingManager.reputation_changed.disconnect(_on_standing_changed)
	StandingManager.loyalty_changed.disconnect(_on_standing_changed)
	StandingManager.bounty_changed.disconnect(_on_standing_changed)


func _update_header() -> void:
	var faction: String = StandingManager.get_planet_faction(GameManager.current_planet)
	var display_name: String = GameManager.get_display_planet_name(GameManager.current_planet)
	if display_name != GameManager.current_planet:
		faction = "Player Base"
	var rep: int = StandingManager.get_faction_reputation(faction)
	var rep_tier: String = StandingManager.get_reputation_tier(faction)
	var loyalty: int = StandingManager.get_trade_loyalty(GameManager.current_planet)
	var loyalty_text: String = _get_loyalty_status_text(GameManager.current_planet)
	planet_name_label.text = "%s | %s" % [display_name, faction]
	
	planet_name_label.tooltip_text = "Reputation: %+d %s\nLoyalty: %d (%s)" % [
		rep,
		rep_tier,
		loyalty,
		loyalty_text
	]


func _get_loyalty_status_text(planet_name: String) -> String:
	var loyalty_tier: String = StandingManager.get_loyalty_tier(planet_name)
	if loyalty_tier == "Unknown":
		return "No standing yet"
	return loyalty_tier


func _update_news_banner() -> void:
	var event_text: String = EventManager.get_event_display_text()
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
	_update_cargo_display()
	_update_crew_items()
	_update_ship_status()
	_update_quest_label()
	var planets_visited: int = GameManager.visited_planets.size()
	var win_credits: int = GameManager.get_win_credits()
	var t2_installed: bool = GameManager.has_crafted_upgrade_installed()
	var t2_marker: String = "T2 ✓" if t2_installed else "T2 ✗"
	var bounty_ok := StandingManager.bounty_amount <= 0
	var credits_ok := GameManager.credits >= win_credits
	var planets_ok := planets_visited >= GameManager.WIN_PLANETS
	# Every prerequisite met except the bounty: the hideout stays locked until paid.
	var bounty_blocks_win := credits_ok and planets_ok and t2_installed and not bounty_ok

	if GameManager.victory_triggered:
		goal_label.text = "Day %d | %d/%d cr | %d/%d planets | %s | GALAXY SECURED" % [GameManager.current_day, GameManager.credits, win_credits, planets_visited, GameManager.WIN_PLANETS, t2_marker]
		goal_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.8))
	elif GameManager.crimson_base_unlocked:
		goal_label.text = "Day %d | MAIN GOAL: DEFEAT CRIMSON JACK" % GameManager.current_day
		goal_label.add_theme_color_override("font_color", UIStyles.NEGATIVE)
	elif credits_ok and planets_ok and t2_installed and bounty_ok:
		goal_label.text = "Day %d | GOAL REACHED! Check your logs." % GameManager.current_day
		goal_label.add_theme_color_override("font_color", UIStyles.POSITIVE)
	elif bounty_blocks_win:
		goal_label.text = "Day %d | HIDEOUT LOCKED — pay off bounty (%d cr)" % [
			GameManager.current_day, StandingManager.bounty_amount
		]
		goal_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
	else:
		goal_label.text = "Day %d | %d/%d cr | %d/%d planets | %s" % [GameManager.current_day, GameManager.credits, win_credits, planets_visited, GameManager.WIN_PLANETS, t2_marker]
		var credit_progress: float = clampf(float(GameManager.credits) / float(win_credits), 0.0, 1.0)
		var planet_progress: float = clampf(float(planets_visited) / float(GameManager.WIN_PLANETS), 0.0, 1.0)
		var t2_progress: float = 1.0 if t2_installed else 0.0
		var bounty_progress: float = 1.0 if bounty_ok else 0.0
		var progress: float = (credit_progress + planet_progress + t2_progress + bounty_progress) / 4.0
		var goal_color := Color(0.5 + progress * 0.5, 0.4 + progress * 0.6, 0.1 + progress * 0.2)
		goal_label.add_theme_color_override("font_color", goal_color)

	if GameManager.has_active_loan():
		goal_label.text += " | Debt %d (%d days)" % [GameManager.outstanding_debt, GameManager.debt_due_in_days]
	var suppress_bounty := GameManager.crimson_base_unlocked and not GameManager.victory_triggered
	if StandingManager.bounty_amount > 0 and not (suppress_bounty or bounty_blocks_win):
		goal_label.text += " | %s %d cr" % [StandingManager.get_bounty_tier(), StandingManager.bounty_amount]
	goal_label.tooltip_text = _build_goal_tooltip(t2_installed, planets_visited, win_credits)
	_refresh_info_bar_text_layout()

## Explains the compact goal readout — "T2 ✗" and the bounty tier in particular
## are the two markers players cannot decode from the label alone.
func _build_goal_tooltip(t2_installed: bool, planets_visited: int, win_credits: int) -> String:
	if GameManager.crimson_base_unlocked:
		return "MAIN GOAL\nTravel to Crimson Jack's Hideout on the Galaxy Map and defeat the pirate lord to win the game!"
	var lines: Array[String] = [
		"LOCATE CRIMSON JACK'S HIDEOUT (PREREQUISITES)",
		"• Credits: %d / %d" % [GameManager.credits, win_credits],
		"• Planets visited: %d / %d" % [planets_visited, GameManager.WIN_PLANETS],
		"• T2 upgrade installed: %s" % ("yes" if t2_installed else "not yet"),
		"• Bounty cleared: %s" % ("yes" if StandingManager.bounty_amount <= 0 else "no (%d cr)" % StandingManager.bounty_amount),
		"",
		"HOW TO GET THE T2 UPGRADE",
		"1. Fabrication Plant (Tech planets only) — start a recipe",
		"2. Wait out the build days, then collect the component",
		"3. Shipyard → Ship Upgrades → install the crafted upgrade",
	]
	if GameManager.has_active_loan():
		lines.append("")
		lines.append("Debt: %d cr due in %d days. Miss it and the lenders take it out of your run." % [
			GameManager.outstanding_debt, GameManager.debt_due_in_days
		])
	if StandingManager.bounty_amount > 0:
		lines.append("")
		lines.append("Bounty %d cr (%s): patrols hunt you more often and dock fees rise." % [
			StandingManager.bounty_amount, StandingManager.get_bounty_tier()
		])
		lines.append("Pay it off at the contract office (%s)." % CityMap.get_building_name(
			CityMap.BUILDING_QUEST, _current_planet_type()
		))
	return "\n".join(lines)


func _on_goal_label_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		AudioManager.play_ui_click()
		_show_goal_popup()


func _on_planet_title_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		AudioManager.play_ui_click()
		_show_standing_popup()


func _on_news_banner_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		AudioManager.play_ui_click()
		_show_news_popup()


func _on_ship_panel_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		AudioManager.play_ui_click()
		_show_ship_status_overlay()


func _show_ship_status_overlay() -> void:
	if _has_overlay_open():
		return
	if has_node("ShipStatusOverlay"):
		return
	var overlay: Node = ShipStatusOverlayScene.instantiate()
	overlay.name = "ShipStatusOverlay"
	add_child(overlay)
	_overlays.register(overlay)
	overlay.connect("closed", _update_ui)
	overlay.connect("view_deck_requested", _on_view_deck_pressed)


func _show_standing_popup() -> void:
	if _arrival.running:
		return
	if get_node_or_null("StandingPopup"):
		return
	var overlay := ColorRect.new()
	overlay.name = "StandingPopup"
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free()
	)
	add_child(overlay)
	_overlays.register(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	UIStyles.style_panel(panel)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "PLANET & FACTION STANDING"
	UIStyles.apply_section_title(title)
	vbox.add_child(title)

	var display_name: String = GameManager.get_display_planet_name(GameManager.current_planet)
	var faction: String = StandingManager.get_planet_faction(GameManager.current_planet)
	var rep: int = StandingManager.get_faction_reputation(faction)
	var rep_tier: String = StandingManager.get_reputation_tier(faction)
	var loyalty: int = StandingManager.get_trade_loyalty(GameManager.current_planet)
	var loyalty_tier: String = StandingManager.get_loyalty_tier(GameManager.current_planet)
	var pt_name: String = EconomyManager.PLANET_TYPE_NAMES.get(_current_planet_type(), "Unknown")

	var info_lines: Array[String] = [
		"PLANET: %s (%s Economy)" % [display_name, pt_name],
		"FACTION: %s" % faction,
		"• Reputation: %+d (%s)" % [rep, rep_tier],
		"  Market buy/sell modifier: x%.2f / x%.2f" % [
			StandingManager.get_market_buy_modifier(GameManager.current_planet),
			StandingManager.get_market_sell_modifier(GameManager.current_planet)
		],
		"",
		"TRADE LOYALTY: %d (%s)" % [loyalty, loyalty_tier],
		"• Loyalty grows through local trade and unlocks commercial benefits.",
		"",
		"LEGAL STATUS & PATROL RISK:",
		"• Bounty: %d cr (%s)" % [StandingManager.bounty_amount, StandingManager.get_bounty_tier()],
	]
	if StandingManager.bounty_amount > 0:
		info_lines.append("  Active bounty increases authority encounter chance and adds dock fees.")
	else:
		info_lines.append("  You are in good standing with local authorities.")

	var body := Label.new()
	body.text = "\n".join(info_lines)
	body.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.theme_type_variation = UIStyles.BTN_DANGER
	close_btn.pressed.connect(overlay.queue_free)
	vbox.add_child(close_btn)


func _show_news_popup() -> void:
	if _arrival.running:
		return
	if get_node_or_null("NewsPopup"):
		return
	var overlay := ColorRect.new()
	overlay.name = "NewsPopup"
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free()
	)
	add_child(overlay)
	_overlays.register(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	UIStyles.style_panel(panel)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "SECTOR NEWS & BROADCASTS"
	UIStyles.apply_section_title(title)
	vbox.add_child(title)

	var lines: Array[String] = []
	var event_text: String = EventManager.get_event_display_text()
	if event_text != "":
		lines.append("GALACTIC BULLETIN:")
		lines.append(event_text)
		lines.append("")

	var weather: Dictionary = EventManager.get_active_weather()
	if not weather.is_empty():
		lines.append("SPACE WEATHER: %s (%d days remaining)" % [weather.get("title", ""), EventManager.weather_days_remaining])
		lines.append(weather.get("description", ""))
		lines.append("")

	var status_notes: Array[String] = _get_local_status_notes()
	if not status_notes.is_empty():
		lines.append("LOCAL CONDITIONS:")
		for note in status_notes:
			lines.append("• " + note)
	elif event_text == "" and weather.is_empty():
		lines.append("No active crisis or weather interference reported in this sector.")

	var body := Label.new()
	body.text = "\n".join(lines)
	body.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.theme_type_variation = UIStyles.BTN_DANGER
	close_btn.pressed.connect(overlay.queue_free)
	vbox.add_child(close_btn)


## Same content as the goal tooltip, but reachable by tap — hover tooltips do
## not exist on touch devices, and the one-shot hints may already be dismissed.
func _show_goal_popup() -> void:
	if _arrival.running:
		return
	if get_node_or_null("GoalPopup"):
		return
	var overlay := ColorRect.new()
	overlay.name = "GoalPopup"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free()
	)
	add_child(overlay)
	_overlays.register(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	UIStyles.style_panel(panel)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "VICTORY CONDITIONS"
	UIStyles.apply_section_title(title)
	vbox.add_child(title)

	var body := Label.new()
	body.text = _build_goal_tooltip(
		GameManager.has_crafted_upgrade_installed(),
		GameManager.visited_planets.size(),
		GameManager.get_win_credits()
	)
	body.add_theme_font_size_override("font_size", UIStyles.FONT_DETAIL)
	vbox.add_child(body)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.theme_type_variation = UIStyles.BTN_DANGER
	close_btn.pressed.connect(overlay.queue_free)
	vbox.add_child(close_btn)


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
	hull_label.add_theme_color_override("font_color", UIStyles.get_hull_color(hull_pct))

	if hull_pct > 0.6:
		_hull_bar_fill.bg_color = Color(0.2, 0.9, 0.2)
	elif hull_pct > 0.3:
		_hull_bar_fill.bg_color = Color(0.9, 0.75, 0.1)
	else:
		_hull_bar_fill.bg_color = Color(0.9, 0.2, 0.15)
	hull_bar.max_value = max_hull
	hull_bar.value = hull

	shield_label.text = "Shield: %d/%d" % [shield, max_shield]
	shield_bar.max_value = max(max_shield, 1)
	shield_bar.value = shield

	var fuel: int = GameManager.current_fuel
	var max_fuel: int = GameManager.max_fuel
	fuel_label.text = "Fuel: %d/%d" % [fuel, max_fuel]
	var fuel_pct: float = float(fuel) / float(max_fuel) if max_fuel > 0 else 0.0
	if fuel_pct > 0.5:
		fuel_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28))
	elif fuel_pct > 0.25:
		fuel_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1))
	else:
		fuel_label.add_theme_color_override("font_color", UIStyles.NEGATIVE)
	fuel_bar.max_value = max(max_fuel, 1)
	fuel_bar.value = fuel


func _update_quest_label() -> void:
	if quest_widget:
		quest_widget.update_widget()
		if quest_widget.visible:
			info_bar.offset_right = -264.0
		else:
			info_bar.offset_right = -8.0
		_refresh_info_bar_text_layout()


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
	
	var right_offset: float = 264.0 if (quest_widget and quest_widget.visible) else 8.0
	var expected_width: float = size.x - 228.0 - right_offset - 32.0 # Extra safe margin
	var available: float = expected_width - reserved - 60.0 # Force earlier truncation

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
	var faction: String = StandingManager.get_planet_faction(GameManager.current_planet)
	var rep_tier: String = StandingManager.get_reputation_tier(faction)
	var loyalty_tier: String = StandingManager.get_loyalty_tier(GameManager.current_planet)
	var bounty_tier: String = StandingManager.get_bounty_tier()

	if rep_tier in ["Trusted", "Allied"]:
		notes.append("Trusted trader discounts active")
	elif rep_tier == "Hostile":
		notes.append("Local authorities are openly hostile")

	if loyalty_tier in ["Preferred", "Local Hero"]:
		notes.append("Local trade network favors you")

	if bounty_tier in ["Wanted", "Most Wanted"] and StandingManager.get_planet_faction(GameManager.current_planet) != StandingManager.FACTION_BY_PLANET_TYPE.get(EconomyManager.PT_OUTLAW, "Free Cartel"):
		notes.append("Patrols intensified for wanted traffic")

	return notes


## Bar, capacity readout and icon row are one unit — bound to
## GameManager.cargo_changed so a sale from any overlay updates the hub.
func _update_cargo_display() -> void:
	var used: int = GameManager.get_cargo_used()
	var cap: int = GameManager.cargo_capacity
	cargo_bar.value = used
	cargo_bar.max_value = cap
	capacity_label.text = str(used) + "/" + str(cap)
	_update_cargo_items()


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
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		cargo_items_row.add_child(icon)

	if hidden_count > 0:
		var more_label := Label.new()
		more_label.text = "+%d" % hidden_count
		more_label.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
		more_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.35))
		more_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		more_label.tooltip_text = "%d more cargo types" % hidden_count
		more_label.mouse_filter = Control.MOUSE_FILTER_PASS
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
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		crew_items_row.add_child(icon)
		icon.setup(crew_res.bonus_type)


# ── Bottom Bar ───────────────────────────────────────────────────────────────

func _on_depart_pressed() -> void:
	if _has_overlay_open():
		return
	if has_node("DepartOverlay"):
		return
	var modal := _create_modal_overlay("DepartOverlay", 340, 0.75)
	var overlay: ColorRect = modal.overlay
	var vbox: VBoxContainer = modal.vbox
	# Departing is the one green-accented modal; the rest use the holo blue.
	(modal.panel as PanelContainer).add_theme_stylebox_override(
		"panel", _make_holo_panel_style(0.95, ACCENT_DEPART, 14, 32, false)
	)
	vbox.add_theme_constant_override("separation", 20)

	var title := Label.new()
	title.text = "Ready to depart?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	title.add_theme_font_size_override("font_size", UIStyles.FONT_HEADING)
	title.add_theme_color_override("font_color", ACCENT_DEPART)
	vbox.add_child(title)

	var btn_depart := Button.new()
	btn_depart.text = "Depart"
	btn_depart.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
	btn_depart.theme_type_variation = UIStyles.BTN_PRIMARY
	btn_depart.pressed.connect(func(): overlay.queue_free(); _do_depart())
	vbox.add_child(btn_depart)

	var btn_stay := Button.new()
	btn_stay.text = "Stay on Planet"
	btn_stay.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
	btn_stay.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(btn_stay)


func _do_depart() -> void:
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
	_overlays.register(viewer)
	viewer.tree_exited.connect(_update_ui)





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
	btn.theme_type_variation = UIStyles.BTN_COMPACT
	btn.pressed.connect(callback)
	return btn


func _on_menu_pressed() -> void:
	if _has_overlay_open():
		return
	SaveManager.save_game()
	GameManager.change_scene("res://scenes/main_menu.tscn")



var _active_toast_container: Control = null
var _active_toast_tween: Tween = null


func _show_toast(text: String, text_color: Color = UIStyles.CAUTION) -> void:
	if _active_toast_tween and _active_toast_tween.is_valid():
		_active_toast_tween.kill()
		_active_toast_tween = null

	if is_instance_valid(_active_toast_container):
		_active_toast_container.queue_free()
		_active_toast_container = null

	var container := Control.new()
	container.name = "ToastContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_active_toast_container = container

	var toast := Label.new()
	toast.text = text
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	toast.add_theme_font_size_override("font_size", UIStyles.FONT_HEADING)
	toast.add_theme_color_override("font_color", text_color)
	toast.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	toast.add_theme_constant_override("outline_size", 8)

	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	toast.position = Vector2(0, -140)

	container.add_child(toast)

	var tween := container.create_tween()
	_active_toast_tween = tween
	tween.tween_property(toast, "position:y", -60.0, 2.2).as_relative().set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(toast, "modulate:a", 0.0, 2.2).set_ease(Tween.EASE_IN).set_delay(0.6)
	tween.tween_callback(container.queue_free)


func _show_quest_arrival_toast() -> void:
	_show_toast("Quest Destination Reached!", Color(1.0, 0.9, 0.2))
