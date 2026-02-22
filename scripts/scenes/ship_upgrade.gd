extends Control


# Planet type -> allowed upgrade slots
const PLANET_UPGRADE_SLOTS := {
	0: [0, 1, 4],          # Industrial: ENGINE, HULL, WEAPONS
	1: [3, 5],             # Agricultural: CARGO, SPECIAL
	2: [1, 3],             # Mining: HULL, CARGO
	3: [0, 1, 2, 3, 4, 5], # Tech: all slots
	4: [3, 4, 5],          # Outlaw: CARGO, WEAPONS, SPECIAL
}

var all_upgrades: Array[Resource] = []
var current_planet_data: Resource = null


func _ready() -> void:
	_find_planet_data()
	_load_all_upgrades()
	_update_header()
	_populate_available_upgrades()
	_update_stats()
	$VBoxContainer/BottomBar/BackButton.pressed.connect(_on_back_pressed)


func _find_planet_data() -> void:
	for planet in EconomyManager.planets:
		if planet.planet_name == GameManager.current_planet:
			current_planet_data = planet
			return


func _load_all_upgrades() -> void:
	var loaded := ResourceRegistry.load_all(ResourceRegistry.UPGRADES)
	for res in loaded:
		all_upgrades.append(res)


func _populate_available_upgrades() -> void:
	var list := $VBoxContainer/MainContent/AvailablePanel/UpgradeScroll/UpgradeList
	for child in list.get_children():
		child.queue_free()

	var allowed_slots: Array = []
	if current_planet_data:
		var ptype: int = current_planet_data.planet_type
		allowed_slots = PLANET_UPGRADE_SLOTS.get(ptype, [])
	else:
		allowed_slots = [0, 1, 2, 3, 4, 5]

	for upgrade in all_upgrades:
		if upgrade.upgrade_name in GameManager.installed_upgrades:
			continue
		if upgrade.slot not in allowed_slots:
			continue
		_add_upgrade_row(list, upgrade)


func _add_upgrade_row(parent: Control, upgrade: Resource) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = upgrade.upgrade_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.custom_minimum_size = Vector2(150, 0)
	name_label.add_theme_font_size_override("font_size", 16)
	row.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = upgrade.description
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	row.add_child(desc_label)

	var cost_label := Label.new()
	cost_label.text = str(upgrade.cost) + " cr"
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.custom_minimum_size = Vector2(80, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cost_label)

	var buy_button := Button.new()
	buy_button.text = "Buy"
	buy_button.custom_minimum_size = Vector2(70, 0)
	if GameManager.credits < upgrade.cost:
		buy_button.disabled = true
	buy_button.pressed.connect(_on_buy_upgrade.bind(upgrade))
	row.add_child(buy_button)

	parent.add_child(row)


func _on_buy_upgrade(upgrade: Resource) -> void:
	if not GameManager.remove_credits(upgrade.cost):
		return
	GameManager.apply_upgrade(upgrade)
	EventLog.add_entry("Installed %s for %d cr" % [upgrade.upgrade_name, upgrade.cost])
	_populate_available_upgrades()
	_update_stats()
	_update_header()


func _update_header() -> void:
	var type_str := ""
	if current_planet_data:
		type_str = " - " + EconomyManager.PLANET_TYPE_NAMES.get(current_planet_data.planet_type, "Unknown")
	$VBoxContainer/HeaderBar/TitleLabel.text = "Ship Upgrades" + type_str
	$VBoxContainer/HeaderBar/CreditsLabel.text = "Credits: " + str(GameManager.credits)


func _update_stats() -> void:
	var stats_list := $VBoxContainer/MainContent/StatsPanel/StatsScroll/StatsList
	for child in stats_list.get_children():
		child.queue_free()

	_add_stat_row(stats_list, "Hull", str(GameManager.current_hull) + " / " + str(GameManager.max_hull))
	_add_stat_row(stats_list, "Shield", str(GameManager.current_shield) + " / " + str(GameManager.max_shield))
	_add_stat_row(stats_list, "Cargo Capacity", str(GameManager.cargo_capacity))
	_add_stat_row(stats_list, "Energy / Turn", str(GameManager.energy_per_turn))
	_add_stat_row(stats_list, "Hand Size", str(GameManager.hand_size))
	_add_stat_row(stats_list, "Deck Size", str(GameManager.deck.size()))

	if GameManager.installed_upgrades.size() > 0:
		var spacer := HSeparator.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_list.add_child(spacer)

		var installed_header := Label.new()
		installed_header.text = "INSTALLED"
		installed_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		installed_header.add_theme_font_size_override("font_size", 16)
		installed_header.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		stats_list.add_child(installed_header)

		for upgrade_name in GameManager.installed_upgrades:
			var lbl := Label.new()
			lbl.text = "  " + upgrade_name
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
			stats_list.add_child(lbl)


func _add_stat_row(parent: Control, stat_name: String, stat_value: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = stat_value
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	row.add_child(val_lbl)

	parent.add_child(row)


func _on_back_pressed() -> void:
	GameManager.change_scene("res://scenes/planet_screen.tscn")
