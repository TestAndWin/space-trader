## UIStyles — centralized UI styling utility.
## Usage: const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
## All methods are static — no autoload needed.

# ── Color constants ──────────────────────────────────────────────────────────

const GOLD := Color(1.0, 0.90, 0.25)
const ACCENT := Color(0.0, 0.9, 1.0)
const ACCENT_DIM := Color(0.0, 0.45, 0.75, 0.6)
const POSITIVE := Color(0.2, 0.9, 0.35)
const NEGATIVE := Color(1.0, 0.35, 0.3)
const PANEL_BG := Color(0.02, 0.06, 0.14)
const PANEL_BORDER := Color(0.0, 0.65, 0.95, 0.85)


# ── Accent button ────────────────────────────────────────────────────────────
# Used for: close/action buttons with a colored accent background.
# Replaces: _style_action_button() in ship_upgrade, ship_dealer, deck_viewer,
#           _style_casino_button() in casino_popup,
#           _style_nav_button() in galaxy_map.

static func style_accent_button(btn: Button, accent: Color, font_size: int = 14) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent
	normal.border_color = accent.lightened(0.3)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := normal.duplicate()
	hover.bg_color = accent.lightened(0.15)

	var pressed := normal.duplicate()
	pressed.bg_color = accent.darkened(0.2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.95))


# ── Buy button ───────────────────────────────────────────────────────────────
# Used for: green "BUY" buttons with disabled state.
# Replaces: _style_buy_button() in ship_upgrade, ship_dealer.

static func style_buy_button(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 14)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.18, 0.10)
	normal.border_color = Color(0.0, 0.6, 0.4, 0.7)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
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
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

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
	disabled.content_margin_left = 16
	disabled.content_margin_right = 16
	disabled.content_margin_top = 8
	disabled.content_margin_bottom = 8

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.85, 0.98, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.2, 0.35, 0.45))
	if font_size > 0:
		btn.add_theme_font_size_override("font_size", font_size)


# ── Small secondary button ──────────────────────────────────────────────────
# Used for: compact buttons in panels (upgrade, hire, dismiss).
# Replaces: _style_upgrade_button() in crew_panel, shipyard_panel
# with smaller margins for inline use.

static func style_small_secondary_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.08, 0.18)
	normal.border_color = Color(0.0, 0.45, 0.75)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 4
	normal.content_margin_right = 4
	normal.content_margin_top = 1
	normal.content_margin_bottom = 1

	var hover := normal.duplicate()
	hover.bg_color = Color(0.02, 0.08, 0.18).lightened(0.12)
	hover.border_color = Color(0.0, 0.45, 0.75).lightened(0.15)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.02, 0.08, 0.18).darkened(0.15)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.02, 0.05, 0.10, 0.6)
	disabled.border_color = Color(0.0, 0.2, 0.35, 0.4)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(3)
	disabled.content_margin_left = 4
	disabled.content_margin_right = 4
	disabled.content_margin_top = 1
	disabled.content_margin_bottom = 1

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.85, 0.98, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.2, 0.35, 0.45))


# ── Panel styling ────────────────────────────────────────────────────────────
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


# ── Overlay panel styling ────────────────────────────────────────────────────
# Used for: full-screen popup overlays (ship dealer, casino, etc.).
# Replaces: inline overlay StyleBox code in ship_upgrade, casino_popup,
#           ship_dealer, deck_viewer.

static func style_overlay_panel(node: Control) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, 0.65)
	style.border_color = Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	node.add_theme_stylebox_override("panel", style)
