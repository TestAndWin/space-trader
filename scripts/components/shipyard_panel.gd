extends PanelContainer

signal shipyard_action
signal ships_requested
signal upgrades_requested

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

const HULL_UPGRADE_COST := 200
const HULL_UPGRADE_AMOUNT := 5
const SHIELD_UPGRADE_COST := 250
const SHIELD_UPGRADE_AMOUNT := 3
const CARGO_UPGRADE_COST := 300
const CARGO_UPGRADE_AMOUNT := 2

var ShipDisplayScene := preload("res://scenes/components/ship_display.tscn")
var ship_display_node: Control

var hull_bar: ProgressBar
var hull_bar_label: Label
var shield_bar: ProgressBar
var shield_bar_label: Label
var repair_button: Button
var hull_upgrade_button: Button
var shield_upgrade_button: Button
var cargo_upgrade_button: Button
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

	hull_upgrade_button = Button.new()
	hull_upgrade_button.text = "+%d Max Hull (%dcr)" % [HULL_UPGRADE_AMOUNT, HULL_UPGRADE_COST]
	hull_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hull_upgrade_button.pressed.connect(_on_hull_upgrade_pressed)
	UIStyles.style_small_secondary_button(hull_upgrade_button)
	vbox.add_child(hull_upgrade_button)

	shield_upgrade_button = Button.new()
	shield_upgrade_button.text = "+%d Max Shield (%dcr)" % [SHIELD_UPGRADE_AMOUNT, SHIELD_UPGRADE_COST]
	shield_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shield_upgrade_button.pressed.connect(_on_shield_upgrade_pressed)
	UIStyles.style_small_secondary_button(shield_upgrade_button)
	vbox.add_child(shield_upgrade_button)

	cargo_upgrade_button = Button.new()
	cargo_upgrade_button.text = "+%d Cargo Space (%dcr)" % [CARGO_UPGRADE_AMOUNT, CARGO_UPGRADE_COST]
	cargo_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cargo_upgrade_button.pressed.connect(_on_cargo_upgrade_pressed)
	UIStyles.style_small_secondary_button(cargo_upgrade_button)
	vbox.add_child(cargo_upgrade_button)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 4)
	vbox.add_child(bottom_row)

	var ship_upgrades_button := Button.new()
	ship_upgrades_button.text = "Upgrades"
	ship_upgrades_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_upgrades_button.pressed.connect(_on_ship_upgrades_pressed)
	UIStyles.style_small_secondary_button(ship_upgrades_button)
	bottom_row.add_child(ship_upgrades_button)

	var ships_button := Button.new()
	ships_button.text = "Ships"
	ships_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ships_button.pressed.connect(_on_ships_pressed)
	UIStyles.style_small_secondary_button(ships_button)
	bottom_row.add_child(ships_button)

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


func setup() -> void:
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

	# Update upgrade buttons with remaining count
	var hull_remaining: int = GameManager.MAX_STAT_UPGRADES - GameManager.hull_upgrades_bought
	var shield_remaining: int = GameManager.MAX_STAT_UPGRADES - GameManager.shield_upgrades_bought
	var cargo_remaining: int = GameManager.MAX_STAT_UPGRADES - GameManager.cargo_upgrades_bought

	if hull_remaining <= 0:
		hull_upgrade_button.text = "+%d Max Hull (MAX)" % HULL_UPGRADE_AMOUNT
		hull_upgrade_button.disabled = true
	else:
		hull_upgrade_button.text = "+%d Max Hull (%dcr) [%d/%d]" % [HULL_UPGRADE_AMOUNT, HULL_UPGRADE_COST, GameManager.hull_upgrades_bought, GameManager.MAX_STAT_UPGRADES]
		hull_upgrade_button.disabled = GameManager.credits < HULL_UPGRADE_COST

	if shield_remaining <= 0:
		shield_upgrade_button.text = "+%d Max Shield (MAX)" % SHIELD_UPGRADE_AMOUNT
		shield_upgrade_button.disabled = true
	else:
		shield_upgrade_button.text = "+%d Max Shield (%dcr) [%d/%d]" % [SHIELD_UPGRADE_AMOUNT, SHIELD_UPGRADE_COST, GameManager.shield_upgrades_bought, GameManager.MAX_STAT_UPGRADES]
		shield_upgrade_button.disabled = GameManager.credits < SHIELD_UPGRADE_COST

	if cargo_remaining <= 0:
		cargo_upgrade_button.text = "+%d Cargo Space (MAX)" % CARGO_UPGRADE_AMOUNT
		cargo_upgrade_button.disabled = true
	else:
		cargo_upgrade_button.text = "+%d Cargo Space (%dcr) [%d/%d]" % [CARGO_UPGRADE_AMOUNT, CARGO_UPGRADE_COST, GameManager.cargo_upgrades_bought, GameManager.MAX_STAT_UPGRADES]
		cargo_upgrade_button.disabled = GameManager.credits < CARGO_UPGRADE_COST


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


func _apply_stat_upgrade(stat_name: String, cost: int, amount: int,
		bought_key: String, upgrade_callback: Callable) -> void:
	var bought: int = GameManager.get(bought_key)
	if bought >= GameManager.MAX_STAT_UPGRADES:
		status_label.text = "Max %s upgrades reached!" % stat_name
		return
	if not GameManager.remove_credits(cost):
		status_label.text = "Not enough credits!"
		return
	upgrade_callback.call()
	GameManager.set(bought_key, bought + 1)
	EventLog.add_entry("Upgraded %s by %d for %dcr." % [stat_name, amount, cost])
	status_label.text = "%s +%d" % [stat_name.capitalize(), amount]
	_refresh_display()
	shipyard_action.emit()


func _on_hull_upgrade_pressed() -> void:
	_apply_stat_upgrade("max hull", HULL_UPGRADE_COST, HULL_UPGRADE_AMOUNT,
		"hull_upgrades_bought", func():
			GameManager.max_hull += HULL_UPGRADE_AMOUNT
			GameManager.current_hull += HULL_UPGRADE_AMOUNT
	)


func _on_shield_upgrade_pressed() -> void:
	_apply_stat_upgrade("max shield", SHIELD_UPGRADE_COST, SHIELD_UPGRADE_AMOUNT,
		"shield_upgrades_bought", func():
			GameManager.max_shield += SHIELD_UPGRADE_AMOUNT
			GameManager.current_shield += SHIELD_UPGRADE_AMOUNT
	)


func _on_cargo_upgrade_pressed() -> void:
	_apply_stat_upgrade("cargo capacity", CARGO_UPGRADE_COST, CARGO_UPGRADE_AMOUNT,
		"cargo_upgrades_bought", func():
			GameManager.cargo_capacity += CARGO_UPGRADE_AMOUNT
	)


func _on_ship_upgrades_pressed() -> void:
	upgrades_requested.emit()


func _on_ships_pressed() -> void:
	ships_requested.emit()
