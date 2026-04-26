extends Control

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

var _planet_name: String = ""

@onready var _root_vbox: VBoxContainer = null


func setup(planet_name: String) -> void:
	_planet_name = planet_name


func _ready() -> void:
	BackgroundUtils.add_fullscreen_background(
		self,
		BackgroundUtils.BUILDING_BACKGROUND_KEYS.get("shipyard", ""),
		0.45,
	)
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		if child is VBoxContainer:
			child.queue_free()

	_root_vbox = VBoxContainer.new()
	_root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_vbox.add_theme_constant_override("separation", 12)
	add_child(_root_vbox)

	# Header
	var header := HBoxContainer.new()
	_root_vbox.add_child(header)
	var title := Label.new()
	title.text = "FABRICATION PLANT — %s" % _planet_name
	UIStyles.apply_display_font(title)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UIStyles.GOLD if "GOLD" in UIStyles else Color.GOLD)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var close := Button.new()
	close.text = "Close"
	UIStyles.style_secondary_button(close)
	close.pressed.connect(queue_free)
	header.add_child(close)

	# Status line: credits + cargo
	var status := Label.new()
	status.text = "Credits: %d cr  Cargo: %d/%d" % [
		GameManager.credits, GameManager.get_cargo_used(), GameManager.cargo_capacity,
	]
	status.add_theme_color_override("font_color", UIStyles.ACCENT if "ACCENT" in UIStyles else Color.CYAN)
	_root_vbox.add_child(status)

	# Body — locked or unlocked
	if not CraftingManager.is_facility_unlocked(_planet_name):
		_build_locked_body()
	else:
		_build_unlocked_body()


func _refresh() -> void:
	_build_ui()


# ── Locked body ─────────────────────────────────────────────────────────────

func _build_locked_body() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_root_vbox.add_child(box)

	var info := Label.new()
	info.text = "No production facility on this planet yet."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", UIStyles.DIM if "DIM" in UIStyles else Color.DARK_GRAY)
	box.add_child(info)

	var btn := Button.new()
	btn.text = "Establish Production Facility (%d cr)" % CraftingManager.FACILITY_COST
	btn.disabled = GameManager.credits < CraftingManager.FACILITY_COST
	UIStyles.style_accent_button(btn)
	btn.pressed.connect(_on_unlock_pressed)
	box.add_child(btn)


func _on_unlock_pressed() -> void:
	if CraftingManager.unlock_facility(_planet_name):
		_refresh()


# ── Unlocked body ───────────────────────────────────────────────────────────

func _build_unlocked_body() -> void:
	# Slots panel
	var slots_panel := VBoxContainer.new()
	slots_panel.add_theme_constant_override("separation", 6)
	_root_vbox.add_child(slots_panel)

	var slots_title := Label.new()
	slots_title.text = "PRODUCTION SLOTS"
	UIStyles.apply_display_font(slots_title)
	slots_title.add_theme_font_size_override("font_size", 16)
	slots_title.add_theme_color_override("font_color", UIStyles.ACCENT if "ACCENT" in UIStyles else Color.CYAN)
	slots_panel.add_child(slots_title)

	var slot_count: int = CraftingManager.get_slot_count(_planet_name)
	var jobs: Array = CraftingManager.get_active_jobs(_planet_name)
	var finished: Array = CraftingManager.get_finished_items(_planet_name)

	# Build per-slot row
	for slot_idx in slot_count:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		slots_panel.add_child(row)

		var slot_label := Label.new()
		slot_label.text = "Slot %d:" % (slot_idx + 1)
		slot_label.custom_minimum_size = Vector2(80, 0)
		row.add_child(slot_label)

		var job_in_slot: Dictionary = {}
		for job in jobs:
			if int(job.slot_index) == slot_idx:
				job_in_slot = job
				break

		if not job_in_slot.is_empty():
			var recipe: Resource = CraftingManager.get_recipe(job_in_slot.recipe_id)
			var status_lbl := Label.new()
			status_lbl.text = "%s — building %d/%d trips" % [
				recipe.output_good.good_name,
				recipe.build_trips - int(job_in_slot.trips_remaining),
				recipe.build_trips,
			]
			row.add_child(status_lbl)
		else:
			var status_lbl := Label.new()
			status_lbl.text = "Empty"
			status_lbl.add_theme_color_override("font_color", UIStyles.DIM if "DIM" in UIStyles else Color.DARK_GRAY)
			row.add_child(status_lbl)

	# Slot expansion button
	var next_cost: int = CraftingManager.get_next_slot_cost(_planet_name)
	if next_cost > 0:
		var expand_btn := Button.new()
		expand_btn.text = "Buy Slot %d (%d cr)" % [slot_count + 1, next_cost]
		expand_btn.disabled = GameManager.credits < next_cost
		UIStyles.style_secondary_button(expand_btn)
		expand_btn.pressed.connect(_on_expand_pressed)
		slots_panel.add_child(expand_btn)

	# Finished items panel
	if not finished.is_empty():
		var sep := HSeparator.new()
		_root_vbox.add_child(sep)

		var finished_title := Label.new()
		finished_title.text = "READY TO COLLECT"
		UIStyles.apply_display_font(finished_title)
		finished_title.add_theme_font_size_override("font_size", 16)
		finished_title.add_theme_color_override("font_color", UIStyles.GOLD if "GOLD" in UIStyles else Color.GOLD)
		_root_vbox.add_child(finished_title)

		for i in finished.size():
			var entry: Dictionary = finished[i]
			var good: GoodData = load(entry.good_path)
			var fin_row := HBoxContainer.new()
			fin_row.add_theme_constant_override("separation", 8)
			_root_vbox.add_child(fin_row)

			var fin_lbl := Label.new()
			fin_lbl.text = "%d x %s" % [int(entry.amount), good.good_name]
			fin_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fin_row.add_child(fin_lbl)

			var collect_btn := Button.new()
			collect_btn.text = "Collect"
			var free_space: int = GameManager.get_free_cargo_space()
			collect_btn.disabled = free_space < int(entry.amount)
			if collect_btn.disabled:
				collect_btn.tooltip_text = "Cargo full — sell or store goods first"
			UIStyles.style_secondary_button(collect_btn)
			var idx_collect: int = i
			collect_btn.pressed.connect(func() -> void: _on_collect_pressed(idx_collect))
			fin_row.add_child(collect_btn)

			var sell_price: int = EconomyManager.get_sell_price(_planet_name, good.good_name)
			var sell_btn := Button.new()
			sell_btn.text = "Sell (%d cr)" % (sell_price * int(entry.amount))
			UIStyles.style_accent_button(sell_btn)
			var idx_sell: int = i
			sell_btn.pressed.connect(func() -> void: _on_sell_pressed(idx_sell))
			fin_row.add_child(sell_btn)

	# Recipes panel
	var sep2 := HSeparator.new()
	_root_vbox.add_child(sep2)

	var recipes_title := Label.new()
	recipes_title.text = "AVAILABLE RECIPES"
	UIStyles.apply_display_font(recipes_title)
	recipes_title.add_theme_font_size_override("font_size", 16)
	recipes_title.add_theme_color_override("font_color", UIStyles.ACCENT if "ACCENT" in UIStyles else Color.CYAN)
	_root_vbox.add_child(recipes_title)

	var recipes: Array = CraftingManager.get_recipes_for_planet(_planet_name)
	for recipe in recipes:
		_build_recipe_row(recipe)


func _build_recipe_row(recipe: Resource) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_root_vbox.add_child(row)

	var label := Label.new()
	var inputs_text: String = ""
	for entry in recipe.inputs:
		var good: GoodData = entry.good
		if inputs_text != "":
			inputs_text += " + "
		
		# Find the quantity of good in cargo
		var have: int = 0
		for item in GameManager.cargo:
			if item.get("good_name") == good.good_name:
				have = item.get("quantity", 0)
				break
				
		var need: int = int(entry.amount)
		var marker: String = "✓" if have >= need else "✗"
		inputs_text += "%s %dx %s" % [marker, need, good.good_name]
	label.text = "[T%d] %s  ←  %s  (%d trips)" % [
		recipe.tier, recipe.output_good.good_name, inputs_text, recipe.build_trips,
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var build_btn := Button.new()
	build_btn.text = "Build"
	build_btn.disabled = not CraftingManager.can_start_job(_planet_name, recipe)
	UIStyles.style_accent_button(build_btn)
	build_btn.pressed.connect(func() -> void: _on_build_pressed(recipe))
	row.add_child(build_btn)


# ── Button handlers ─────────────────────────────────────────────────────────

func _on_expand_pressed() -> void:
	if CraftingManager.expand_slots(_planet_name):
		_refresh()


func _on_collect_pressed(finished_index: int) -> void:
	if CraftingManager.collect_finished_item(_planet_name, finished_index):
		_refresh()


func _on_sell_pressed(finished_index: int) -> void:
	if CraftingManager.sell_finished_item(_planet_name, finished_index) > 0:
		_refresh()


func _on_build_pressed(recipe: Resource) -> void:
	if CraftingManager.start_job(_planet_name, recipe):
		_refresh()
