extends ColorRect

## Shipyard screen — fullscreen overlay for ship repairs and stat upgrades.
## Wraps existing ShipyardPanel in showroom-style overlay, with access to
## Ship Dealer and Ship Upgrades sub-screens.

signal shipyard_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

const SHIPYARD_NAMES = {
	0: "TECH BAY",
	1: "REPAIR SHED",
	2: "REPAIR DEPOT",
	3: "WORKSHOP",
	4: "CHOP SHOP",
}

const SHIPYARD_ICONS = {
	0: "\u2699",  # ⚙
	1: "\u2692",  # ⚒
	2: "\u2692",  # ⚒
	3: "\u2726",  # ✦
	4: "\u2620",  # ☠
}

var _planet_type: int = 0
var _credits_label: Label
var _shipyard_panel: Control  # ShipyardPanel instance

var ShipyardPanelScene := preload("res://scenes/components/shipyard_panel.tscn")
var ShipDealerScene: PackedScene = preload("res://scenes/components/ship_dealer.tscn")
var ShipUpgradeScene: PackedScene = preload("res://scenes/ship_upgrade.tscn")


func setup(planet_type: int) -> void:
	_planet_type = planet_type
	if _shipyard_panel:
		_shipyard_panel.setup(_planet_type)
	_refresh_ui()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.0)
	_build_ui()


func _build_ui() -> void:
	# Background image
	BackgroundUtils.add_building_background(self, "shipyard", 0.4)

	var subtitle_text: String = "Repairs only" if _planet_type == EconomyManager.PT_AGRICULTURAL else "Repair, upgrade, and customize your vessel"
	var scaffold: Dictionary = UIStyles.create_overlay_scaffold(
		self,
		SHIPYARD_NAMES.get(_planet_type, "SHIPYARD"),
		subtitle_text,
		SHIPYARD_ICONS.get(_planet_type, "\u2699"),
		"Leave Shipyard",
		_close,
	)
	var main_vbox: VBoxContainer = scaffold["main_vbox"]
	_credits_label = scaffold["credits_label"]

	# Spacer to push content to lower third
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.size_flags_stretch_ratio = 2.0
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(top_spacer)

	# ── Content: Shipyard panel (half width, centered) ──
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(content_hbox)

	_shipyard_panel = ShipyardPanelScene.instantiate()
	_shipyard_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shipyard_panel.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	_shipyard_panel.custom_minimum_size = Vector2(480, 0)
	content_hbox.add_child(_shipyard_panel)
	_shipyard_panel.setup(_planet_type)
	_shipyard_panel.shipyard_action.connect(_on_shipyard_action)
	_shipyard_panel.ships_requested.connect(_on_ship_dealer_pressed)
	_shipyard_panel.upgrades_requested.connect(_on_ship_upgrades_pressed)


func _on_shipyard_action() -> void:
	_refresh_ui()


func _on_ship_dealer_pressed() -> void:
	if has_node("ShipDealer"):
		return
	var dealer := ShipDealerScene.instantiate()
	dealer.name = "ShipDealer"
	add_child(dealer)
	dealer.setup(_planet_type)
	dealer.dealer_closed.connect(func():
		_refresh_ui()
		if _shipyard_panel:
			_shipyard_panel.setup(_planet_type)
	)


func _on_ship_upgrades_pressed() -> void:
	if has_node("ShipUpgrades"):
		return
	var upgrades := ShipUpgradeScene.instantiate()
	upgrades.name = "ShipUpgrades"
	add_child(upgrades)
	upgrades.setup(_planet_type)
	upgrades.upgrades_closed.connect(func():
		_refresh_ui()
		if _shipyard_panel:
			_shipyard_panel.setup(_planet_type)
	)


func _refresh_ui() -> void:
	if not _credits_label:
		return
	_credits_label.text = "%d cr" % GameManager.credits


func _close() -> void:
	shipyard_closed.emit()
	queue_free()
