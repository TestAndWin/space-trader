## UIStyles — centralized UI styling utility.
## Usage: const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
## All methods are static — no autoload needed.

# ── Font constants ───────────────────────────────────────────────────────────
# Body default (Exo 2) is set project-wide via resources/default_theme.tres.

const FONT_DISPLAY: FontFile = preload("res://assets/fonts/Orbitron.ttf")
const FONT_MONO: FontFile = preload("res://assets/fonts/ShareTechMono.ttf")
const CreditsLabelScript = preload("res://scripts/components/credits_label.gd")
const CargoLabelScript = preload("res://scripts/components/cargo_label.gd")


## Self-updating cargo readout, bound to GameManager.cargo_changed.
static func create_cargo_label(format_string: String = "Cargo: %d/%d", font_size: int = 16) -> Label:
	var label := Label.new()
	label.set_script(CargoLabelScript)
	label.format_string = format_string
	label.add_theme_font_override("font", FONT_MONO)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))
	return label


## The standard gold credit readout. It binds itself to
## GameManager.credits_changed, so callers must not assign its text.
static func create_credits_label(format_string: String = "%d cr", font_size: int = 20) -> Label:
	var label := Label.new()
	label.set_script(CreditsLabelScript)
	label.format_string = format_string
	label.add_theme_font_override("font", FONT_MONO)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", GOLD)
	return label


static func apply_display_font(ctrl: Control) -> void:
	if ctrl is Label or ctrl is Button:
		ctrl.add_theme_font_override("font", FONT_DISPLAY)


static func apply_mono_font(ctrl: Control) -> void:
	if ctrl is Label or ctrl is Button:
		ctrl.add_theme_font_override("font", FONT_MONO)


# ── Title helpers ────────────────────────────────────────────────────────────
# Use these for consistent overlay-screen titles. Default color is ACCENT.
# Reserve GOLD for highlight/reward emphasis (e.g. "READY TO COLLECT", credits).

# ── Type scale ──────────────────────────────────────────────────────────────
# Nine steps, named by role. Never write a raw font size: if none of these fits,
# the design needs a new step here, not a one-off number at the call site.
# Two roles may share a value (FONT_BODY/FONT_DETAIL are close on purpose);
# picking by role is what keeps the intent readable.
const FONT_HERO: int       = 52  # Main menu wordmark, galaxy-map planet labels
const FONT_TITLE: int      = 28  # Screen titles
const FONT_HEADING: int    = 22  # Modal titles, panel headings
const FONT_SUBHEADING: int = 18  # Card titles, sub-panel headings
const FONT_BODY: int       = 16  # Primary content: descriptions, status labels
const FONT_DETAIL: int     = 15  # Secondary rows: stats, chain labels, deadlines
const FONT_LABEL: int      = 13  # Buttons, compact labels, overlay subtitles
const FONT_CAPTION: int    = 12  # Fine print: notes, modifiers, log lines
const FONT_MICRO: int      = 10  # Technically constrained: bar and chip labels


static func apply_screen_title(label: Label, color: Color = ACCENT) -> void:
	apply_display_font(label)
	label.add_theme_font_size_override("font_size", FONT_TITLE)
	label.add_theme_color_override("font_color", color)


static func apply_section_title(label: Label, color: Color = ACCENT) -> void:
	apply_display_font(label)
	label.add_theme_font_size_override("font_size", FONT_BODY)
	label.add_theme_color_override("font_color", color)


# ── Color constants ──────────────────────────────────────────────────────────

const GOLD := Color(1.0, 0.90, 0.25)
const ACCENT := Color(0.0, 0.9, 1.0)
const ACCENT_DIM := Color(0.0, 0.45, 0.75, 0.6)
const POSITIVE := Color(0.2, 0.9, 0.35)
const NEGATIVE := Color(1.0, 0.35, 0.3)
const CAUTION  := Color(1.0, 0.85, 0.3)   # Amber: the middle step between POSITIVE and NEGATIVE
const PANEL_BG := Color(0.02, 0.06, 0.14)
const PANEL_BORDER := Color(0.0, 0.65, 0.95, 0.85)

# Overlay-screen panel colors (used by market, shipyard, casino, crew, etc.)
const PANEL_COLOR := Color(0.02, 0.06, 0.14, 0.45)
const BORDER_COLOR := Color(0.0, 0.55, 0.85, 0.35)

# Status / feedback label colors
const STATUS_WARN := Color(0.9, 0.82, 0.55)     # Amber: informational status (quest, factory, market)

# ── ActionButton constants ───────────────────────────────────────────────────
# Change these to restyle all ActionButtons project-wide.
const ACTION_BTN_FONT_SIZE: int = FONT_BODY
const ACTION_BTN_MIN_HEIGHT: int = 36

# Planet-type accent colors (indexed by planet_type int)
const TYPE_COLORS := {
	0: Color(0.4, 0.6, 1.0),    # INDUSTRIAL - blue
	1: Color(0.4, 0.9, 0.4),    # AGRICULTURAL - green
	2: Color(0.9, 0.6, 0.3),    # MINING - orange
	3: Color(0.3, 0.9, 1.0),    # TECH - cyan
	4: Color(1.0, 0.3, 0.3),    # OUTLAW - red
}


# ── Shared button metrics ────────────────────────────────────────────────────
# All button styles derive their padding from the font size, so two buttons with
# the same font end up exactly the same height no matter which style they use.
# FONT_BODY (16) yields the historic 16/8 padding.

static func apply_button_padding(sb: StyleBoxFlat, font_size: int) -> void:
	var size: int = font_size if font_size > 0 else FONT_DETAIL
	sb.content_margin_left = size
	sb.content_margin_right = size
	sb.content_margin_top = roundi(size * 0.5)
	sb.content_margin_bottom = roundi(size * 0.5)


# ── Accent button ────────────────────────────────────────────────────────────
# Used for: close/action buttons with a colored accent background.
# Replaces: _style_action_button() in ship_upgrade, ship_dealer, deck_viewer,
#           _style_casino_button() in casino_popup,
#           _style_nav_button() in galaxy_map.

static func style_accent_button(btn: Button, accent: Color, font_size: int = ACTION_BTN_FONT_SIZE) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent
	normal.border_color = accent.lightened(0.3)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	apply_button_padding(normal, font_size)

	var hover := normal.duplicate()
	hover.bg_color = accent.lightened(0.15)

	var pressed := normal.duplicate()
	pressed.bg_color = accent.darkened(0.2)

	# Without this the disabled state falls back to the engine default, which is
	# near-invisible on the dark panels -- a blocked button then reads as dead
	# text instead of as a button the player can unblock.
	var disabled := normal.duplicate()
	disabled.bg_color = accent.darkened(0.55)
	disabled.border_color = accent.darkened(0.3)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.95))
	btn.add_theme_color_override("font_disabled_color", Color(0.62, 0.62, 0.6))


# ── Buy button ───────────────────────────────────────────────────────────────
# Used for: green "BUY" buttons with disabled state.
# Replaces: _style_buy_button() in ship_upgrade, ship_dealer.

static func style_buy_button(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", FONT_LABEL)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.18, 0.10)
	normal.border_color = Color(0.0, 0.6, 0.4, 0.7)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	apply_button_padding(normal, FONT_LABEL)
	normal.shadow_color = Color(0.0, 0.5, 0.3, 0.15)
	normal.shadow_size = 4

	var hover := normal.duplicate()
	hover.bg_color = Color(0.0, 0.25, 0.15)
	hover.border_color = Color(0.0, 0.8, 0.5, 0.9)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.0, 0.12, 0.06)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.04, 0.06, 0.10, 0.5)
	disabled.border_color = Color(0.1, 0.15, 0.2, 0.4)
	disabled.shadow_size = 0

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(0.8, 1.0, 0.85))
	btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.35))


# ── Secondary button ─────────────────────────────────────────────────────────
# Used for: dark background buttons with cyan border/font.
# Replaces: _style_upgrade_button() in crew_panel, shipyard_panel,
#           _style_secondary_button() in planet_screen,
#           _style_buttons() in main_menu, battle_result,
#           _style_main_menu_button() in game_over, victory,
#           _style_back_button() in tutorial.

static func style_secondary_button(btn: Button, font_size: int = 0) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.06, 0.14, 0.85)
	normal.border_color = Color(0.0, 0.45, 0.75, 0.7)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	apply_button_padding(normal, font_size)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.03, 0.10, 0.22, 0.9)
	hover.border_color = Color(0.0, 0.65, 0.95, 0.85)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.01, 0.04, 0.10, 0.9)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.02, 0.05, 0.10, 0.6)
	disabled.border_color = Color(0.0, 0.2, 0.35, 0.4)
	disabled.set_border_width_all(2)
	disabled.set_corner_radius_all(6)
	apply_button_padding(disabled, font_size)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.85, 0.98, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.2, 0.35, 0.45))
	if font_size > 0:
		btn.add_theme_font_size_override("font_size", font_size)


# ── Action button ────────────────────────────────────────────────────────────
# Unified style for all main-action buttons across overlay screens.
# Use ActionButton (class_name) — this method is called automatically by it.

static func style_action_button(btn: Button) -> void:
	style_secondary_button(btn, ACTION_BTN_FONT_SIZE)
	btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, ACTION_BTN_MIN_HEIGHT)
	# Buttons in a tall row (header, HBox next to big labels) would otherwise be
	# stretched to the row height and stop matching their siblings elsewhere.
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

static func style_continue_button(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(160, 40)
	style_secondary_button(btn, FONT_BODY)


# ── Panel styling ───────────────────────────────────────────────────
# Used for: PanelContainer backgrounds with border.
# Replaces: inline panel StyleBox code in crew_panel, shipyard_panel,
#           quest_display, planet_screen info boxes.

static func style_panel(node: Control, bg_alpha: float = 0.75) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, bg_alpha)
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 8
	node.add_theme_stylebox_override("panel", style)


# ── Fullscreen overlay panel ──────────────────────────────────
# Chrome for the fullscreen showroom screens (ship dealer, ship upgrade).
# Embedded variants sit inside another panel and draw no chrome of their own,
# so callers pass their _embedded flag straight through.

static func style_overlay_panel(panel: Control, embedded: bool = false) -> void:
	if embedded:
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return
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


# ── Confirmation modal scaffold ─────────────────────────────────────────────
# Overlay + centred panel + content VBox, as used by the main menu and the end
# screens. Returns { "overlay", "vbox" }; callers fill the VBox and free the
# overlay to dismiss.

static func create_confirm_modal(
	parent: Control,
	overlay_alpha: float,
	bg_color: Color,
	border_color: Color,
	separation: int,
	content_min_size: Vector2,
) -> Dictionary:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, overlay_alpha)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = bg_color
	panel_style.border_color = border_color
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	vbox.custom_minimum_size = content_min_size
	panel.add_child(vbox)

	return { "overlay": overlay, "vbox": vbox }


# ── Event modal button style ────────────────────────────────────────────────
# Three-state flat button styling used by event popups (planet/travel/customs).

static func style_event_button(btn: Button, normal_color: Color, hover_color: Color, pressed_color: Color) -> void:
	for pair in [["normal", normal_color], ["hover", hover_color], ["pressed", pressed_color]]:
		var style := StyleBoxFlat.new()
		style.bg_color = pair[1]
		style.set_corner_radius_all(4)
		style.set_content_margin_all(6)
		btn.add_theme_stylebox_override(pair[0], style)


## Standardized event modal dialog frame (used by PlanetEvent, TravelEvent, CustomsScan, SmugglerEvent).
static func create_event_modal_scaffold(
	parent: Control,
	min_width: float = 400.0,
	title_color: Color = Color(0.4, 0.7, 1.0)
) -> Dictionary:
	parent.mouse_filter = Control.MOUSE_FILTER_STOP
	if parent is ColorRect:
		(parent as ColorRect).color = Color(0.0, 0.0, 0.0, 0.75)
		parent.set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.3, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_DISPLAY)
	title.add_theme_color_override("font_color", title_color)
	title.add_theme_font_size_override("font_size", FONT_HEADING)
	vbox.add_child(title)

	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc.custom_minimum_size = Vector2(min_width - 40, 0)
	vbox.add_child(desc)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.2, 0.35, 0.55))
	vbox.add_child(sep)

	return {
		"vbox": vbox,
		"title_label": title,
		"description_label": desc,
		"panel": panel,
		"separator": sep,
	}



# ── Hull color helper ────────────────────────────────────────────────────────
# Returns green / yellow / red based on hull percentage.

static func get_hull_color(pct: float) -> Color:
	if pct > 0.6:
		return Color(0.2, 0.9, 0.35)
	elif pct > 0.3:
		return Color(1.0, 0.9, 0.2)
	else:
		return Color(1.0, 0.3, 0.2)


# ── Overlay scaffold ────────────────────────────────────────────────────────
# Builds the standard header + panel chrome used by every overlay screen.
# Returns a Dictionary with:
#   "main_vbox": the VBoxContainer below the separator (add your content here)
#   "credits_label": the Label showing credits — self-updating, do not assign
#     its text manually (see create_credits_label)
#   "separator": the HSeparator (for reference if needed)
#   "header": the HBoxContainer for the header row
#   "title_label" / "subtitle_label" / "icon_labels": header text nodes.
#     Overlays are built in _ready() but receive their planet type in a later
#     setup() call, so anything planet-dependent must be re-applied there.

static func create_overlay_scaffold(
	parent: Control,
	title_text: String,
	subtitle_text: String,
	icon_text: String,
	close_text: String,
	close_callback: Callable,
	title_color: Color = ACCENT,
	icon_color: Color = ACCENT_DIM,
	sep_color: Color = ACCENT_DIM,
) -> Dictionary:
	# Main panel
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	parent.add_child(margin)

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
	left_deco.text = icon_text
	left_deco.add_theme_font_size_override("font_size", FONT_BODY)
	left_deco.add_theme_color_override("font_color", icon_color)
	title_row.add_child(left_deco)

	var title := Label.new()
	title.text = title_text
	apply_screen_title(title, title_color)
	title_row.add_child(title)

	var right_deco := Label.new()
	right_deco.text = icon_text
	right_deco.add_theme_font_size_override("font_size", FONT_BODY)
	right_deco.add_theme_color_override("font_color", icon_color)
	title_row.add_child(right_deco)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	var sub_settings := LabelSettings.new()
	sub_settings.font_size = FONT_LABEL
	sub_settings.font_color = Color(0.8, 0.85, 0.9, 1.0)
	sub_settings.shadow_size = 3
	sub_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	sub_settings.shadow_offset = Vector2(1, 1)
	subtitle.label_settings = sub_settings
	title_vbox.add_child(subtitle)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var credits_label := create_credits_label()
	header.add_child(credits_label)

	var close_btn := Button.new()
	close_btn.text = close_text
	close_btn.custom_minimum_size = Vector2(140, ACTION_BTN_MIN_HEIGHT)
	# The header is as tall as the title block; without this the close button
	# would fill that height and dwarf every other button on the screen.
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_accent_button(close_btn, Color(0.5, 0.15, 0.1))
	close_btn.pressed.connect(close_callback)
	header.add_child(close_btn)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_color_override("separator", sep_color)
	main_vbox.add_child(sep)

	return {
		"main_vbox": main_vbox,
		"credits_label": credits_label,
		"separator": sep,
		"header": header,
		"title_label": title,
		"subtitle_label": subtitle,
		"icon_labels": [left_deco, right_deco],
	}
