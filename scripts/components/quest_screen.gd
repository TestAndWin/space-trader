extends ColorRect

## Quest screen — fullscreen overlay for viewing/accepting/delivering quests.
## Wraps existing QuestDisplay in showroom-style overlay.

signal quest_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

const PANEL_COLOR := Color(0.02, 0.06, 0.14, 0.65)
const BORDER_COLOR := Color(0.0, 0.55, 0.85, 0.55)
const ACCENT := Color(0.0, 0.9, 1.0)
const ACCENT_DIM := Color(0.0, 0.45, 0.75, 0.6)

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
var _quest_display: Control  # QuestDisplay instance

var ShowroomBgScene := preload("res://scenes/components/dealer_showroom_bg.tscn")
var QuestDisplayScene := preload("res://scenes/components/quest_display.tscn")


func setup(planet_type: int, planet_name: String) -> void:
	_planet_type = planet_type
	_planet_name = planet_name
	if _quest_display:
		_quest_display.setup(planet_name)
	_refresh_ui()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.85)
	_build_ui()


func _build_ui() -> void:
	# Showroom background
	var showroom_bg := ShowroomBgScene.instantiate()
	showroom_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	showroom_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(showroom_bg)

	# Main panel
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	add_child(margin)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(main_vbox)

	# ── Header ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header)

	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 0)
	header.add_child(title_vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_vbox.add_child(title_row)

	var left_deco := Label.new()
	left_deco.text = QUEST_ICONS.get(_planet_type, "\u2709")
	left_deco.add_theme_font_size_override("font_size", 16)
	left_deco.add_theme_color_override("font_color", ACCENT_DIM)
	title_row.add_child(left_deco)

	var title := Label.new()
	title.text = QUEST_NAMES.get(_planet_type, "QUEST BOARD")
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ACCENT)
	title_row.add_child(title)

	var right_deco := Label.new()
	right_deco.text = QUEST_ICONS.get(_planet_type, "\u2709")
	right_deco.add_theme_font_size_override("font_size", 16)
	right_deco.add_theme_color_override("font_color", ACCENT_DIM)
	title_row.add_child(right_deco)

	var subtitle := Label.new()
	subtitle.text = "Accept and deliver cargo contracts"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.5, 0.55, 0.8))
	title_vbox.add_child(subtitle)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 20)
	_credits_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.25))
	header.add_child(_credits_label)

	var close_btn := Button.new()
	close_btn.text = "Leave"
	close_btn.custom_minimum_size = Vector2(100, 36)
	UIStyles.style_accent_button(close_btn, Color(0.5, 0.15, 0.1))
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_color_override("separator", ACCENT_DIM)
	main_vbox.add_child(sep)

	# ── Content: Quest display (centered, expanded) ──
	_quest_display = QuestDisplayScene.instantiate()
	_quest_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_quest_display)
	_quest_display.setup(_planet_name)
	_quest_display.quest_changed.connect(_on_quest_changed)


func _on_quest_changed() -> void:
	_refresh_ui()


func _refresh_ui() -> void:
	if not _credits_label:
		return
	_credits_label.text = "%d cr" % GameManager.credits


func _close() -> void:
	quest_closed.emit()
	queue_free()
