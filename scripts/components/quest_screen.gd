extends ColorRect

## Quest screen — fullscreen overlay for viewing/accepting/delivering quests.
## Wraps existing QuestDisplay in showroom-style overlay.

signal quest_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

const QUEST_NAMES = {
	0: "INTEL OFFICE",
	1: "POST OFFICE",
	2: "DISPATCH CENTER",
	3: "LOGISTICS HQ",
	4: "DEAD DROP",
}

const QUEST_ICONS = {
	0: "\u2709",  # ✉
	1: "\u2709",  # ✉
	2: "\u2709",  # ✉
	3: "\u2709",  # ✉
	4: "\u2709",  # ✉
}

var _planet_type: int = 0
var _planet_name: String = ""
var _credits_label: Label
var _status_label: Label
var _quest_display: Control  # QuestDisplay instance

const QuestDisplayScene: PackedScene = preload("res://scenes/components/quest_display.tscn")


func setup(planet_type: int, planet_name: String) -> void:
	_planet_type = planet_type
	_planet_name = planet_name
	if _quest_display:
		_quest_display.setup(planet_name)
	_refresh_ui()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.0)
	_build_ui()


func _build_ui() -> void:
	# Background image
	BackgroundUtils.add_building_background(self, "quest", 0.4)

	var scaffold: Dictionary = UIStyles.create_overlay_scaffold(
		self,
		QUEST_NAMES.get(_planet_type, "QUEST BOARD"),
		"Accept and deliver cargo contracts",
		QUEST_ICONS.get(_planet_type, "\u2709"),
		"Leave Office",
		_close,
	)
	var main_vbox: VBoxContainer = scaffold["main_vbox"]
	_credits_label = scaffold["credits_label"]

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_status_label)

	# Spacer to push content to lower third
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.size_flags_stretch_ratio = 4.0
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(top_spacer)

	# ── Content: Quest display (centered, compact) ──
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.size_flags_stretch_ratio = 0.7
	content_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(content_hbox)

	_quest_display = QuestDisplayScene.instantiate()
	_quest_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_display.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	_quest_display.custom_minimum_size = Vector2(350, 0)
	content_hbox.add_child(_quest_display)
	_quest_display.setup(_planet_name)
	_quest_display.quest_changed.connect(_on_quest_changed)


func _on_quest_changed() -> void:
	_refresh_ui()


func _refresh_ui() -> void:
	if not _credits_label:
		return
	_credits_label.text = "%d cr" % GameManager.credits
	if _status_label:
		var faction: String = StandingManager.get_planet_faction(_planet_name)
		_status_label.text = "%s | Reputation %s | Loyalty %s | Bounty %s" % [
			faction,
			StandingManager.get_reputation_tier(faction),
			_get_loyalty_status_text(_planet_name),
			StandingManager.get_bounty_tier(),
		]


func _get_loyalty_status_text(planet_name: String) -> String:
	var loyalty_tier: String = StandingManager.get_loyalty_tier(planet_name)
	if loyalty_tier == "Unknown":
		return "No standing yet"
	return loyalty_tier


func _close() -> void:
	quest_closed.emit()
	queue_free()
