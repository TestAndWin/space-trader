extends ColorRect

## Shipyard screen — fullscreen overlay for ship repairs, upgrades and trades.
##
## Repair/Fuel, Upgrades and Ships live side by side as tabs. They used to be
## stacked sub-screens (Shipyard -> Upgrades -> back -> Ships -> back), which
## made comparing an upgrade against a new ship needlessly slow.

signal shipyard_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

const SHIPYARD_ICONS = {
	0: "⚙",  # ⚙
	1: "⚒",  # ⚒
	2: "⚒",  # ⚒
	3: "✦",  # ✦
	4: "☠",  # ☠
}

enum Tab { SERVICE, UPGRADES, SHIPS }

const TAB_TITLES: Dictionary = {
	Tab.SERVICE: "Repair & Fuel",
	Tab.UPGRADES: "Upgrades",
	Tab.SHIPS: "Ships",
}

var _planet_type: int = 0
var _title_label: Label
var _subtitle_label: Label
var _icon_labels: Array = []
var _tab_bar: TabBar
var _tab_content: MarginContainer
var _active_tab: int = Tab.SERVICE
var _shipyard_panel: Control  # ShipyardPanel instance, only on the SERVICE tab

const ShipyardPanelScene: PackedScene = preload("res://scenes/components/shipyard_panel.tscn")
const ShipDealerScene: PackedScene = preload("res://scenes/components/ship_dealer.tscn")
const ShipUpgradeScene: PackedScene = preload("res://scenes/ship_upgrade.tscn")


func setup(planet_type: int) -> void:
	_planet_type = planet_type
	_apply_planet_theme()
	_refresh_tab_availability()
	_show_tab(_active_tab)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.0)
	_build_ui()


## The overlay is built in _ready() before setup() delivers the planet type,
## so every planet-dependent header value is (re-)applied here.
func _apply_planet_theme() -> void:
	if not _title_label:
		return
	_title_label.text = CityMap.get_building_name(CityMap.BUILDING_SHIPYARD, _planet_type).to_upper()
	_subtitle_label.text = "Repairs only" if _planet_type == EconomyManager.PT_AGRICULTURAL \
		else "Repair, upgrade, and customize your vessel"
	for icon: Label in _icon_labels:
		icon.text = SHIPYARD_ICONS.get(_planet_type, "⚙")


func _build_ui() -> void:
	BackgroundUtils.add_building_background(self, "shipyard", 0.4)

	var scaffold: Dictionary = UIStyles.create_overlay_scaffold(
		self,
		"",
		"",
		SHIPYARD_ICONS.get(_planet_type, "⚙"),
		"Back to City",
		close,
	)
	var main_vbox: VBoxContainer = scaffold["main_vbox"]
	_title_label = scaffold["title_label"]
	_subtitle_label = scaffold["subtitle_label"]
	_icon_labels = scaffold["icon_labels"]
	_apply_planet_theme()

	_tab_bar = TabBar.new()
	for tab: int in [Tab.SERVICE, Tab.UPGRADES, Tab.SHIPS]:
		_tab_bar.add_tab(TAB_TITLES[tab])
	_tab_bar.add_theme_font_size_override("font_size", 16)
	_tab_bar.tab_changed.connect(_on_tab_changed)
	main_vbox.add_child(_tab_bar)

	_tab_content = MarginContainer.new()
	_tab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_content.add_theme_constant_override("margin_top", 8)
	main_vbox.add_child(_tab_content)

	_refresh_tab_availability()
	_show_tab(_active_tab)


## Agricultural planets offer repairs only — the other two tabs would be empty.
func _refresh_tab_availability() -> void:
	if _tab_bar == null:
		return
	var services_only: bool = _planet_type == EconomyManager.PT_AGRICULTURAL
	_tab_bar.set_tab_disabled(Tab.UPGRADES, services_only)
	_tab_bar.set_tab_disabled(Tab.SHIPS, services_only)
	if services_only:
		_active_tab = Tab.SERVICE
		_tab_bar.current_tab = Tab.SERVICE


func _on_tab_changed(tab: int) -> void:
	_show_tab(tab)


func _show_tab(tab: int) -> void:
	if _tab_content == null:
		return
	_active_tab = tab
	_shipyard_panel = null
	for child in _tab_content.get_children():
		child.queue_free()
	match tab:
		Tab.UPGRADES:
			var upgrades := ShipUpgradeScene.instantiate()
			upgrades.set_embedded(true)
			_tab_content.add_child(upgrades)
			upgrades.setup(_planet_type)
		Tab.SHIPS:
			var dealer := ShipDealerScene.instantiate()
			dealer.set_embedded(true)
			_tab_content.add_child(dealer)
			dealer.setup(_planet_type)
		_:
			_build_service_tab()


func _build_service_tab() -> void:
	var centre := HBoxContainer.new()
	centre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_content.add_child(centre)

	_shipyard_panel = ShipyardPanelScene.instantiate()
	_shipyard_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shipyard_panel.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	_shipyard_panel.custom_minimum_size = Vector2(480, 0)
	centre.add_child(_shipyard_panel)
	_shipyard_panel.setup(_planet_type)


func close() -> void:
	shipyard_closed.emit()
	queue_free()
