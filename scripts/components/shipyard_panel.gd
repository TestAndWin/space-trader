extends PanelContainer

signal shipyard_action
signal ships_requested

signal upgrades_requested

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

const ShipDisplayScene: PackedScene = preload("res://scenes/components/ship_display_3d.tscn")
var ship_display_node: Control
var _planet_type: int = 0

var hull_bar: ProgressBar
var hull_bar_label: Label
var shield_bar: ProgressBar
var shield_bar_label: Label
var fuel_bar: ProgressBar
var fuel_bar_label: Label
var repair_button: Button
var buy_fuel_button: Button
var fill_fuel_button: Button
var emergency_fuel_button: Button
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
	UIStyles.apply_section_title(title)
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

	var fuel_container := _create_stat_bar("FUEL", Color(0.28, 0.16, 0.04), Color(1.0, 0.58, 0.12))
	fuel_bar = fuel_container.get_node("Bar")
	fuel_bar_label = fuel_container.get_node("BarLabel")
	bars_vbox.add_child(fuel_container)

	repair_button = ActionButton.new()
	repair_button.text = "Repair Hull"
	repair_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repair_button.pressed.connect(_on_repair_pressed)
	vbox.add_child(repair_button)

	var fuel_row := HBoxContainer.new()
	fuel_row.add_theme_constant_override("separation", 4)
	vbox.add_child(fuel_row)

	buy_fuel_button = ActionButton.new()
	buy_fuel_button.text = "Buy +1 Fuel"
	buy_fuel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_fuel_button.pressed.connect(_on_buy_fuel_pressed)
	fuel_row.add_child(buy_fuel_button)

	fill_fuel_button = ActionButton.new()
	fill_fuel_button.text = "Fill Tank"
	fill_fuel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill_fuel_button.pressed.connect(_on_fill_fuel_pressed)
	fuel_row.add_child(fill_fuel_button)

	emergency_fuel_button = ActionButton.new()
	emergency_fuel_button.text = "Emergency Fuel"
	emergency_fuel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emergency_fuel_button.pressed.connect(_on_emergency_fuel_pressed)
	vbox.add_child(emergency_fuel_button)

	_bottom_row = HBoxContainer.new()
	_bottom_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_bottom_row)

	var ship_upgrades_button := ActionButton.new()
	ship_upgrades_button.text = "Upgrades"
	ship_upgrades_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_upgrades_button.pressed.connect(_on_ship_upgrades_pressed)
	_bottom_row.add_child(ship_upgrades_button)

	var ships_button := ActionButton.new()
	ships_button.text = "Ships"
	ships_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ships_button.pressed.connect(_on_ships_pressed)
	_bottom_row.add_child(ships_button)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", UIStyles.BODY_FONT_SIZE)
	status_label.add_theme_color_override("font_color", UIStyles.STATUS_OK)
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
	lbl.add_theme_font_override("font", UIStyles.FONT_MONO)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 0.95))
	container.add_child(lbl)

	return container


func setup(planet_type: int = 0) -> void:
	_planet_type = planet_type
	var is_agricultural := (_planet_type == EconomyManager.PT_AGRICULTURAL)
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

	if fuel_bar:
		fuel_bar.max_value = GameManager.max_fuel if GameManager.max_fuel > 0 else 1
		fuel_bar.value = GameManager.current_fuel
		fuel_bar_label.text = "FUEL: %d/%d" % [GameManager.current_fuel, GameManager.max_fuel]

	var missing_hull: int = GameManager.max_hull - GameManager.current_hull
	var per_hp: int = GameManager.REPAIR_COST_PER_HP
	@warning_ignore("integer_division")
	var affordable_hp: int = mini(missing_hull, GameManager.credits / per_hp)
	if missing_hull <= 0:
		repair_button.text = "Repair Hull (Full)"
		repair_button.disabled = true
	elif affordable_hp <= 0:
		repair_button.text = "Repair Hull (need %dcr)" % per_hp
		repair_button.disabled = true
	elif affordable_hp >= missing_hull:
		repair_button.text = "Repair Hull (%dcr)" % (missing_hull * per_hp)
		repair_button.disabled = false
	else:
		repair_button.text = "Repair +%d HP (%dcr)" % [affordable_hp, affordable_hp * per_hp]
		repair_button.disabled = false

	_refresh_fuel_buttons()


func _refresh_fuel_buttons() -> void:
	var missing_fuel: int = GameManager.max_fuel - GameManager.current_fuel
	var per_fuel: int = GameManager.FUEL_PRICE
	var can_buy_one: bool = missing_fuel > 0 and GameManager.credits >= per_fuel
	buy_fuel_button.text = "Buy +1 Fuel (%dcr)" % per_fuel
	buy_fuel_button.disabled = not can_buy_one

	var fill_cost: int = missing_fuel * per_fuel
	fill_fuel_button.text = "Fill Tank (%dcr)" % fill_cost if missing_fuel > 0 else "Fill Tank (Full)"
	fill_fuel_button.disabled = missing_fuel <= 0 or GameManager.credits < fill_cost

	emergency_fuel_button.visible = GameManager.current_fuel == 0 and GameManager.credits < per_fuel
	emergency_fuel_button.text = "Emergency Fuel (+%dcr debt)" % GameManager.EMERGENCY_FUEL_DEBT

func _on_repair_pressed() -> void:
	var missing_hull: int = GameManager.max_hull - GameManager.current_hull
	if missing_hull <= 0:
		return
	var per_hp: int = GameManager.REPAIR_COST_PER_HP
	@warning_ignore("integer_division")
	var hp_to_repair: int = mini(missing_hull, GameManager.credits / per_hp)
	if hp_to_repair <= 0:
		status_label.text = "Not enough credits to repair even 1 hull!"
		return
	var cost: int = hp_to_repair * per_hp
	GameManager.remove_credits(cost)
	GameManager.current_hull += hp_to_repair
	EventLog.add_entry("Repaired %d hull for %dcr." % [hp_to_repair, cost])
	status_label.text = "Repaired %d hull for %dcr" % [hp_to_repair, cost]
	_refresh_display()
	shipyard_action.emit()


func _on_buy_fuel_pressed() -> void:
	if GameManager.buy_fuel(1):
		status_label.text = "Bought 1 fuel"
	else:
		status_label.text = "Cannot buy fuel"
	_refresh_display()
	shipyard_action.emit()


func _on_fill_fuel_pressed() -> void:
	var missing_fuel: int = GameManager.max_fuel - GameManager.current_fuel
	if GameManager.buy_fuel(missing_fuel):
		status_label.text = "Fuel tank filled"
	else:
		status_label.text = "Not enough credits for a full tank"
	_refresh_display()
	shipyard_action.emit()


func _on_emergency_fuel_pressed() -> void:
	if GameManager.take_emergency_fuel():
		status_label.text = "Emergency fuel loaded"
	else:
		status_label.text = "Emergency fuel unavailable"
	_refresh_display()
	shipyard_action.emit()


func _on_ship_upgrades_pressed() -> void:
	upgrades_requested.emit()


func _on_ships_pressed() -> void:
	ships_requested.emit()
