extends ColorRect

## Fullscreen modal overlay displaying comprehensive ship, systems, upgrades,
## crew, and cargo inventory details. Designed for both touch (iPad) and desktop.

signal closed
signal view_deck_requested

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const ShipDisplayScene: PackedScene = preload("res://scenes/components/ship_display.tscn")
const GoodIcon = preload("res://scripts/components/good_icon.gd")
const CrewIcon = preload("res://scripts/components/crew_icon.gd")

var _goods_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.82)
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Clicking the darkened border outside panel closes overlay
		_on_close()


func _on_close() -> void:
	closed.emit()
	queue_free()


func _build_ui() -> void:
	var ship_data: ShipData = GameManager.get_ship_data()
	var ship_title: String = (ship_data.ship_name if ship_data else "SCOUT").to_upper()
	var ship_desc: String = ship_data.description if ship_data else "Standard reconnaissance vessel"

	var scaffold: Dictionary = UIStyles.create_overlay_scaffold(
		self,
		"%s — SHIP & SYSTEMS" % ship_title,
		ship_desc,
		"🚀",
		"Close",
		_on_close,
		UIStyles.ACCENT,
		UIStyles.ACCENT_DIM,
		UIStyles.ACCENT_DIM
	)

	var main_vbox: VBoxContainer = scaffold["main_vbox"]

	# Two-column layout: Left = Ship & Upgrades, Right = Crew & Cargo
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	main_vbox.add_child(columns)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.0
	left_col.add_theme_constant_override("separation", 12)
	columns.add_child(left_col)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 1.15
	right_col.add_theme_constant_override("separation", 12)
	columns.add_child(right_col)

	_build_ship_specs(left_col, ship_data)
	_build_installed_upgrades(left_col)

	_build_crew_section(right_col)
	_build_cargo_section(right_col)

	# Bottom action bar
	var bottom_bar := HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 12)
	main_vbox.add_child(bottom_bar)

	var deck_btn := Button.new()
	deck_btn.text = "Combat Deck (%d Cards)" % GameManager.deck.size()
	deck_btn.custom_minimum_size = Vector2(180, 36)
	UIStyles.style_accent_button(deck_btn, Color(0.15, 0.45, 0.8))
	deck_btn.pressed.connect(func() -> void:
		view_deck_requested.emit()
		_on_close()
	)
	bottom_bar.add_child(deck_btn)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(bottom_spacer)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(130, 36)
	UIStyles.style_accent_button(close_btn, Color(0.5, 0.15, 0.1))
	close_btn.pressed.connect(_on_close)
	bottom_bar.add_child(close_btn)


func _build_ship_specs(parent: VBoxContainer, ship_data: ShipData) -> void:
	var panel := PanelContainer.new()
	UIStyles.style_panel(panel)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "SPECIFICATIONS & SYSTEMS"
	UIStyles.apply_section_title(title)
	vbox.add_child(title)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	vbox.add_child(top_row)

	# 2D ship sprite display
	var ship_display_ctrl: Control = ShipDisplayScene.instantiate()
	ship_display_ctrl.custom_minimum_size = Vector2(90, 90)
	top_row.add_child(ship_display_ctrl)

	var hull_pct: float = float(GameManager.current_hull) / float(maxi(1, GameManager.max_hull))
	var shield_pct: float = float(GameManager.current_shield) / float(maxi(1, GameManager.max_shield))
	var shape: int = ship_data.hull_shape if ship_data else 0
	ship_display_ctrl.update_ship(hull_pct, shield_pct, GameManager.get_cargo_used(), GameManager.cargo_capacity, shape)

	# Special traits / ability
	var traits_vbox := VBoxContainer.new()
	traits_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	traits_vbox.add_theme_constant_override("separation", 3)
	top_row.add_child(traits_vbox)

	if ship_data and ship_data.ability_description != "":
		var ability_lbl := Label.new()
		ability_lbl.text = "Perk: " + ship_data.ability_description
		ability_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
		ability_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		traits_vbox.add_child(ability_lbl)

	var perk_lines: Array[String] = []
	if ship_data:
		if ship_data.encounter_reduction > 0.0:
			perk_lines.append("Encounter Chance: -%d%%" % int(ship_data.encounter_reduction * 100))
		if ship_data.contraband_bonus > 0.0:
			perk_lines.append("Contraband Sell Bonus: +%d%%" % int(ship_data.contraband_bonus * 100))
		if ship_data.quest_reward_bonus > 0.0:
			perk_lines.append("Quest Reward Bonus: +%d%%" % int(ship_data.quest_reward_bonus * 100))

	for line in perk_lines:
		var lbl := Label.new()
		lbl.text = "• " + line
		lbl.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
		traits_vbox.add_child(lbl)

	# Combat energy & hand size
	var combat_lbl := Label.new()
	combat_lbl.text = "Combat: %d Energy/turn | Hand size %d cards" % [GameManager.energy_per_turn, GameManager.hand_size]
	combat_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
	combat_lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 0.95))
	traits_vbox.add_child(combat_lbl)

	# Stat Bars
	var bars_vbox := VBoxContainer.new()
	bars_vbox.add_theme_constant_override("separation", 5)
	vbox.add_child(bars_vbox)

	_add_stat_bar(bars_vbox, "Hull", GameManager.current_hull, GameManager.max_hull, UIStyles.get_hull_color(hull_pct))
	_add_stat_bar(bars_vbox, "Shield", GameManager.current_shield, GameManager.max_shield, Color(0.4, 0.65, 1.0))
	_add_stat_bar(bars_vbox, "Fuel", GameManager.current_fuel, GameManager.max_fuel, Color(1.0, 0.65, 0.1))
	_add_stat_bar(bars_vbox, "Cargo Hold", GameManager.get_cargo_used(), GameManager.cargo_capacity, Color(0.0, 0.80, 1.0))


func _add_stat_bar(parent: VBoxContainer, label_text: String, current_val: int, max_val: int, fill_color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = "%s:" % label_text
	name_lbl.custom_minimum_size = Vector2(75, 0)
	name_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
	name_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	row.add_child(name_lbl)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = maxi(1, max_val)
	bar.value = current_val
	bar.show_percentage = false

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	bg.border_color = Color(0.15, 0.25, 0.35, 0.6)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)

	var val_lbl := Label.new()
	val_lbl.text = "%d/%d" % [current_val, max_val]
	val_lbl.custom_minimum_size = Vector2(55, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
	val_lbl.add_theme_color_override("font_color", fill_color.lightened(0.2))
	row.add_child(val_lbl)


func _build_installed_upgrades(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIStyles.style_panel(panel)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "INSTALLED UPGRADES (%d)" % GameManager.installed_upgrades.size()
	UIStyles.apply_section_title(title)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	if GameManager.installed_upgrades.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No ship upgrades installed yet.\nVisit the Shipyard to install hull, shield, or component upgrades."
		empty_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		list.add_child(empty_lbl)
		return

	for upgrade_path in GameManager.installed_upgrades:
		var up: Resource = load(upgrade_path)
		if not (up is ShipUpgradeData):
			continue
		var u: ShipUpgradeData = up as ShipUpgradeData

		var item_box := HBoxContainer.new()
		item_box.add_theme_constant_override("separation", 8)
		list.add_child(item_box)

		var name_lbl := Label.new()
		name_lbl.text = "• " + u.upgrade_name
		name_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		item_box.add_child(name_lbl)

		var bonus_texts: Array[String] = []
		if u.hull_bonus > 0: bonus_texts.append("+%d Hull" % u.hull_bonus)
		if u.shield_bonus > 0: bonus_texts.append("+%d Shield" % u.shield_bonus)
		if u.cargo_bonus > 0: bonus_texts.append("+%d Cargo" % u.cargo_bonus)
		if u.fuel_capacity_bonus > 0: bonus_texts.append("+%d Fuel" % u.fuel_capacity_bonus)
		if u.energy_bonus > 0: bonus_texts.append("+%d Energy" % u.energy_bonus)
		if u.hand_size_bonus > 0: bonus_texts.append("+%d Hand" % u.hand_size_bonus)
		if u.is_crafted_only(): bonus_texts.append("T2 Crafted")

		if not bonus_texts.is_empty():
			var bonus_lbl := Label.new()
			bonus_lbl.text = "(%s)" % ", ".join(bonus_texts)
			bonus_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
			bonus_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 0.6))
			item_box.add_child(bonus_lbl)


func _build_crew_section(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	UIStyles.style_panel(panel)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var crew_resources: Array = GameManager.get_crew_resources()
	var title := Label.new()
	title.text = "CREW ROSTER (%d/%d)" % [crew_resources.size(), GameManager.MAX_CREW]
	UIStyles.apply_section_title(title)
	vbox.add_child(title)

	if crew_resources.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No crew members hired. Visit Crew Quarters on planets to hire specialists."
		empty_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		vbox.add_child(empty_lbl)
		return

	for crew_res in crew_resources:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)

		var icon := Control.new()
		icon.set_script(CrewIcon)
		icon.custom_minimum_size = Vector2(24, 24)
		icon.setup(crew_res.bonus_type)
		row.add_child(icon)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 1)
		row.add_child(info_vbox)

		var name_lbl := Label.new()
		name_lbl.text = crew_res.crew_name
		name_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
		info_vbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = crew_res.description
		desc_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
		desc_lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 0.9))
		info_vbox.add_child(desc_lbl)


func _build_cargo_section(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIStyles.style_panel(panel)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "CARGO HOLD INVENTORY (%d/%d Units)" % [GameManager.get_cargo_used(), GameManager.cargo_capacity]
	UIStyles.apply_section_title(title)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var cargo_items: Array = GameManager.cargo
	if cargo_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Cargo hold is empty.\nPurchase commodities at planet markets to begin trading."
		empty_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		list.add_child(empty_lbl)
		return

	for item in cargo_items:
		var good_name: String = item.get("good_name", "")
		var qty: int = item.get("quantity", 0)
		var good_data: GoodData = _get_good_data(good_name)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)

		var icon := Control.new()
		icon.set_script(GoodIcon)
		icon.setup(good_name)
		icon.custom_minimum_size = Vector2(20, 20)
		row.add_child(icon)

		var item_lbl := Label.new()
		item_lbl.text = "%s  x%d" % [good_name, qty]
		item_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
		item_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		row.add_child(item_lbl)

		if good_data and good_data.is_contraband:
			var contraband_lbl := Label.new()
			contraband_lbl.text = "[CONTRABAND]"
			contraband_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
			contraband_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			row.add_child(contraband_lbl)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		if good_data:
			var val_lbl := Label.new()
			var est_val: int = good_data.base_price * qty
			val_lbl.text = "~%d cr" % est_val
			val_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
			val_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.45))
			row.add_child(val_lbl)


func _get_good_data(good_name: String) -> GoodData:
	if _goods_cache.is_empty():
		for path in ResourceRegistry.GOODS:
			var res: Resource = load(path)
			if res is GoodData:
				_goods_cache[res.good_name] = res
	return _goods_cache.get(good_name, null)
