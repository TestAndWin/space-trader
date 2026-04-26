extends ColorRect

## Crew screen — fullscreen overlay for hiring and dismissing crew.
## Wraps existing CrewPanel in showroom-style overlay.

signal crew_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

const CREW_NAMES = {
	0: "TECH ACADEMY",
	1: "FARMHANDS GUILD",
	2: "MINERS GUILD",
	3: "ENGINEERING CORPS",
	4: "MERCENARY OUTPOST",
}

const CREW_ICONS = {
	0: "\u2726",  # ✦
	1: "\u2698",  # ⚘
	2: "\u2692",  # ⚒
	3: "\u2699",  # ⚙
	4: "\u2694",  # ⚔
}

var _planet_type: int = 0
var _credits_label: Label
var _crew_panel: Control  # CrewPanel instance

const CrewPanelScene: PackedScene = preload("res://scenes/components/crew_panel.tscn")


func setup(planet_type: int) -> void:
	_planet_type = planet_type
	if _crew_panel:
		_crew_panel.setup(planet_type)
	_refresh_ui()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.0)
	_build_ui()


func _build_ui() -> void:
	# Background image
	BackgroundUtils.add_building_background(self, "crew", 0.4)

	var scaffold: Dictionary = UIStyles.create_overlay_scaffold(
		self,
		CREW_NAMES.get(_planet_type, "CREW QUARTERS"),
		"Recruit specialists to aid your journey",
		CREW_ICONS.get(_planet_type, "\u2726"),
		"Leave Crew Quarters",
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

	# ── Content: Crew panel (half width, centered) ──
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.size_flags_stretch_ratio = 1.0
	content_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(content_hbox)

	_crew_panel = CrewPanelScene.instantiate()
	_crew_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crew_panel.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	_crew_panel.custom_minimum_size = Vector2(280, 0)
	content_hbox.add_child(_crew_panel)
	_crew_panel.setup(_planet_type)
	_crew_panel.crew_action.connect(_on_crew_action)


func _on_crew_action() -> void:
	_refresh_ui()


func _refresh_ui() -> void:
	if not _credits_label:
		return
	_credits_label.text = "%d cr" % GameManager.credits


func _close() -> void:
	crew_closed.emit()
	queue_free()
