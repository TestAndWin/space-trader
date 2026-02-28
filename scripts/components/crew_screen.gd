extends ColorRect

## Crew screen — fullscreen overlay for hiring and dismissing crew.
## Wraps existing CrewPanel in showroom-style overlay.

signal crew_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

const PANEL_COLOR := Color(0.02, 0.06, 0.14, 0.65)
const BORDER_COLOR := Color(0.0, 0.55, 0.85, 0.55)
const ACCENT := Color(0.0, 0.9, 1.0)
const ACCENT_DIM := Color(0.0, 0.45, 0.75, 0.6)

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

var ShowroomBgScene := preload("res://scenes/components/dealer_showroom_bg.tscn")
var CrewPanelScene := preload("res://scenes/components/crew_panel.tscn")


func setup(planet_type: int) -> void:
	_planet_type = planet_type
	if _crew_panel:
		_crew_panel.setup(planet_type)
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
	left_deco.text = CREW_ICONS.get(_planet_type, "\u2726")
	left_deco.add_theme_font_size_override("font_size", 16)
	left_deco.add_theme_color_override("font_color", ACCENT_DIM)
	title_row.add_child(left_deco)

	var title := Label.new()
	title.text = CREW_NAMES.get(_planet_type, "CREW QUARTERS")
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ACCENT)
	title_row.add_child(title)

	var right_deco := Label.new()
	right_deco.text = CREW_ICONS.get(_planet_type, "\u2726")
	right_deco.add_theme_font_size_override("font_size", 16)
	right_deco.add_theme_color_override("font_color", ACCENT_DIM)
	title_row.add_child(right_deco)

	var subtitle := Label.new()
	subtitle.text = "Recruit specialists to aid your journey"
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
	close_btn.text = "Leave Crew Quarters"
	close_btn.custom_minimum_size = Vector2(170, 36)
	UIStyles.style_accent_button(close_btn, Color(0.5, 0.15, 0.1))
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_color_override("separator", ACCENT_DIM)
	main_vbox.add_child(sep)

	# ── Content: Crew panel (centered, expanded) ──
	_crew_panel = CrewPanelScene.instantiate()
	_crew_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crew_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_crew_panel)
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
