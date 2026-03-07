extends PanelContainer

signal shipyard_action
signal ships_requested

const AGRICULTURAL_TYPE := 1
signal upgrades_requested

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

var ShipDisplayScene := preload("res://scenes/components/ship_display_3d.tscn")
var ship_display_node: Control
var _planet_type: int = 0

var hull_bar: ProgressBar
var hull_bar_label: Label
var shield_bar: ProgressBar
var shield_bar_label: Label
var repair_button: Button
var _bottom_row: HBoxContainer
var status_label: Label



func _ready() -> void:
	UIStyles.style_panel(self)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	var title := Label.new()
	title.text = "SHIPYARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vbox.add_child(title)

	# Ship display + Hull/Shield bars side by side
	var ship_row := HBoxContainer.new()
	ship_row.add_theme_constant_override("separation", 6)
	vbox.add_child(ship_row)

	ship_display_node = ShipDisplayScene.instantiate()
	ship_display_node.custom_minimum_size = Vector2(70, 70)
	ship_row.add_child(ship_display_node)

	var bars_vbox := VBoxContainer.new()
	bars_vbox.add_theme_constant_override("separation", 3)
	bars_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ship_row.add_child(bars_vbox)

	var hull_container := _create_stat_bar("HULL", Color(0.5, 0.12, 0.1), Color(0.3, 0.75, 0.25))
	hull_bar = hull_container.get_node("Bar")
	hull_bar_label = hull_container.get_node("BarLabel")
	bars_vbox.add_child(hull_container)

	var shield_container := _create_stat_bar("SHIELD", Color(0.1, 0.15, 0.4), Color(0.2, 0.45, 0.9))
	shield_bar = shield_container.get_node("Bar")
	shield_bar_label = shield_container.get_node("BarLabel")
	bars_vbox.add_child(shield_container)

	repair_button = Button.new()
	repair_button.text = "Repair Hull"
	repair_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repair_button.pressed.connect(_on_repair_pressed)
	UIStyles.style_small_secondary_button(repair_button)
	vbox.add_child(repair_button)

	_bottom_row = HBoxContainer.new()
	_bottom_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_bottom_row)

	var ship_upgrades_button := Button.new()
	ship_upgrades_button.text = "Upgrades"
	ship_upgrades_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_upgrades_button.pressed.connect(_on_ship_upgrades_pressed)
	UIStyles.style_small_secondary_button(ship_upgrades_button)
	_bottom_row.add_child(ship_upgrades_button)

	var ships_button := Button.new()
	ships_button.text = "Ships"
	ships_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ships_button.pressed.connect(_on_ships_pressed)
	UIStyles.style_small_secondary_button(ships_button)
	_bottom_row.add_child(ships_button)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.6))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)



func _create_stat_bar(label_text: String, bg_color: Color, fill_color: Color) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(0, 18)

	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(0, 16)
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.show_percentage = false
	bar.max_value = 100
	bar.value = 100

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = bg_color.darkened(0.4)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	bar_bg.border_color = Color(0.3, 0.32, 0.35, 0.5)
	bar_bg.border_width_left = 1
	bar_bg.border_width_right = 1
	bar_bg.border_width_top = 1
	bar_bg.border_width_bottom = 1
	bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = fill_color
	bar_fill.corner_radius_top_left = 2
	bar_fill.corner_radius_top_right = 2
	bar_fill.corner_radius_bottom_left = 2
	bar_fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", bar_fill)

	container.add_child(bar)

	var lbl := Label.new()
	lbl.name = "BarLabel"
	lbl.text = "%s: 0/0" % label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 0.95))
	container.add_child(lbl)

	return container


func setup(planet_type: int = 0) -> void:
	_planet_type = planet_type
	var is_agricultural := (_planet_type == AGRICULTURAL_TYPE)
	_bottom_row.visible = not is_agricultural
	_refresh_display()


func _refresh_display() -> void:
	var hull_pct := float(GameManager.current_hull) / float(GameManager.max_hull) if GameManager.max_hull > 0 else 1.0
	var shield_pct := float(GameManager.current_shield) / float(GameManager.max_shield) if GameManager.max_shield > 0 else 0.0
	var cargo_used := GameManager.get_cargo_used()
	var ship_data: Resource = GameManager.get_ship_data()
	var shape: int = ship_data.hull_shape if ship_data else 0
	ship_display_node.update_ship(hull_pct, shield_pct, cargo_used, GameManager.cargo_capacity, shape)

	if hull_bar:
		hull_bar.max_value = GameManager.max_hull
		hull_bar.value = GameManager.current_hull
		hull_bar_label.text = "HULL: %d/%d" % [GameManager.current_hull, GameManager.max_hull]
		var fill_color: Color
		if hull_pct > 0.6:
			fill_color = Color(0.3, 0.75, 0.25)
		elif hull_pct > 0.3:
			fill_color = Color(0.85, 0.65, 0.15)
		else:
			fill_color = Color(0.85, 0.2, 0.15)
		var fill_style := hull_bar.get_theme_stylebox("fill").duplicate()
		fill_style.bg_color = fill_color
		hull_bar.add_theme_stylebox_override("fill", fill_style)

	if shield_bar:
		shield_bar.max_value = GameManager.max_shield if GameManager.max_shield > 0 else 1
		shield_bar.value = GameManager.current_shield
		shield_bar_label.text = "SHIELD: %d/%d" % [GameManager.current_shield, GameManager.max_shield]

	var missing_hull := GameManager.max_hull - GameManager.current_hull
	var repair_cost := missing_hull * GameManager.REPAIR_COST_PER_HP
	if missing_hull <= 0:
		repair_button.text = "Repair Hull (Full)"
		repair_button.disabled = true
	else:
		repair_button.text = "Repair Hull (%dcr)" % repair_cost
		repair_button.disabled = GameManager.credits < repair_cost

func _on_repair_pressed() -> void:
	var missing_hull := GameManager.max_hull - GameManager.current_hull
	if missing_hull <= 0:
		return
	var repair_cost := missing_hull * GameManager.REPAIR_COST_PER_HP
	if not GameManager.remove_credits(repair_cost):
		status_label.text = "Not enough credits!"
		return
	GameManager.current_hull = GameManager.max_hull
	EventLog.add_entry("Repaired %d hull for %dcr." % [missing_hull, repair_cost])
	status_label.text = "Repaired %d hull for %dcr" % [missing_hull, repair_cost]
	_refresh_display()
	shipyard_action.emit()


func _on_ship_upgrades_pressed() -> void:
	upgrades_requested.emit()


func _on_ships_pressed() -> void:
	ships_requested.emit()
