extends ColorRect

## Factory screen — fullscreen overlay for crafting on Tech planets.
## Visual pattern matches Quest/Crew/Market screens via UIStyles.create_overlay_scaffold().

signal factory_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

const TITLE_TEXT: String = "FABRICATION PLANT"
const SUBTITLE_TEXT: String = "Refine raw materials into advanced components"
const HEADER_ICON: String = "⚙"  # gear

var _planet_name: String = ""
var _credits_label: Label
var _status_label: Label
var _content_vbox: VBoxContainer


func setup(planet_name: String) -> void:
	_planet_name = planet_name


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	BackgroundUtils.add_building_background(self, "factory", 0.4)
	_build_ui()


func _build_ui() -> void:
	var scaffold: Dictionary = UIStyles.create_overlay_scaffold(
		self,
		TITLE_TEXT,
		SUBTITLE_TEXT,
		HEADER_ICON,
		"Leave Factory",
		_close,
	)
	var main_vbox: VBoxContainer = scaffold["main_vbox"]
	_credits_label = scaffold["credits_label"]

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_status_label)

	# Spacer pushes content to lower portion (matches Quest screen)
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.size_flags_stretch_ratio = 1.0
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(top_spacer)

	# Centered content panel
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.size_flags_stretch_ratio = 4.0
	content_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(content_hbox)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(560, 0)
	UIStyles.style_panel(panel, 0.55)
	content_hbox.add_child(panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 14)
	panel_margin.add_theme_constant_override("margin_right", 14)
	panel_margin.add_theme_constant_override("margin_top", 12)
	panel_margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(panel_margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 10)
	panel_margin.add_child(_content_vbox)

	_refresh()


func _refresh() -> void:
	if _credits_label:
		_credits_label.text = "%d cr" % GameManager.credits
	if _status_label:
		_status_label.text = "%s | Cargo %d/%d" % [
			_planet_name,
			GameManager.get_cargo_used(),
			GameManager.cargo_capacity,
		]
	if _content_vbox:
		for child in _content_vbox.get_children():
			child.queue_free()
		if not CraftingManager.is_facility_unlocked(_planet_name):
			_build_locked_body()
		else:
			_build_unlocked_body()


# ── Locked body ─────────────────────────────────────────────────────────────

func _build_locked_body() -> void:
	var info := Label.new()
	info.text = "No production facility on this planet yet."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", UIStyles.ACCENT_DIM)
	_content_vbox.add_child(info)

	var btn := Button.new()
	btn.text = "Establish Production Facility (%d cr)" % CraftingManager.FACILITY_COST
	btn.disabled = GameManager.credits < CraftingManager.FACILITY_COST
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(360, 40)
	UIStyles.style_buy_button(btn)
	btn.pressed.connect(_on_unlock_pressed)
	_content_vbox.add_child(btn)


func _on_unlock_pressed() -> void:
	if CraftingManager.unlock_facility(_planet_name):
		_refresh()


# ── Unlocked body ───────────────────────────────────────────────────────────

func _build_unlocked_body() -> void:
	# Slots panel
	var slots_title := Label.new()
	slots_title.text = "PRODUCTION SLOTS"
	UIStyles.apply_section_title(slots_title)
	_content_vbox.add_child(slots_title)

	var slot_count: int = CraftingManager.get_slot_count(_planet_name)
	var jobs: Array = CraftingManager.get_active_jobs(_planet_name)
	var finished: Array = CraftingManager.get_finished_items(_planet_name)

	for slot_idx in slot_count:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_content_vbox.add_child(row)

		var slot_label := Label.new()
		slot_label.text = "Slot %d:" % (slot_idx + 1)
		slot_label.custom_minimum_size = Vector2(80, 0)
		row.add_child(slot_label)

		var job_in_slot: Dictionary = {}
		for job in jobs:
			if int(job.slot_index) == slot_idx:
				job_in_slot = job
				break

		var status_lbl := Label.new()
		if not job_in_slot.is_empty():
			var recipe: Resource = CraftingManager.get_recipe(job_in_slot.recipe_id)
			status_lbl.text = "%s — building %d/%d trips" % [
				recipe.output_good.good_name,
				recipe.build_trips - int(job_in_slot.trips_remaining),
				recipe.build_trips,
			]
		else:
			status_lbl.text = "Available — pick a recipe below"
			status_lbl.add_theme_color_override("font_color", UIStyles.POSITIVE)
		row.add_child(status_lbl)

	# Slot expansion button
	var next_cost: int = CraftingManager.get_next_slot_cost(_planet_name)
	if next_cost > 0:
		var expand_btn := Button.new()
		expand_btn.text = "Buy Slot %d (%d cr)" % [slot_count + 1, next_cost]
		expand_btn.disabled = GameManager.credits < next_cost
		UIStyles.style_secondary_button(expand_btn)
		expand_btn.pressed.connect(_on_expand_pressed)
		_content_vbox.add_child(expand_btn)

	# Finished items panel
	if not finished.is_empty():
		var finished_sep := HSeparator.new()
		finished_sep.add_theme_color_override("separator", UIStyles.ACCENT_DIM)
		_content_vbox.add_child(finished_sep)

		var finished_title := Label.new()
		finished_title.text = "READY TO COLLECT"
		UIStyles.apply_section_title(finished_title, UIStyles.GOLD)
		_content_vbox.add_child(finished_title)

		for i in finished.size():
			var entry: Dictionary = finished[i]
			var good: GoodData = load(entry.good_path)
			var fin_row := HBoxContainer.new()
			fin_row.add_theme_constant_override("separation", 8)
			_content_vbox.add_child(fin_row)

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

			var sell_price: int = CraftingManager.get_finished_item_sell_price(_planet_name, good)
			var sell_btn := Button.new()
			sell_btn.text = "Sell (%d cr)" % (sell_price * int(entry.amount))
			UIStyles.style_buy_button(sell_btn)
			var idx_sell: int = i
			sell_btn.pressed.connect(func() -> void: _on_sell_pressed(idx_sell))
			fin_row.add_child(sell_btn)

	# Recipes panel
	var recipes_sep := HSeparator.new()
	recipes_sep.add_theme_color_override("separator", UIStyles.ACCENT_DIM)
	_content_vbox.add_child(recipes_sep)

	var recipes_title := Label.new()
	recipes_title.text = "AVAILABLE RECIPES"
	UIStyles.apply_section_title(recipes_title)
	_content_vbox.add_child(recipes_title)

	var recipes: Array = CraftingManager.get_recipes_for_planet(_planet_name)
	for recipe in recipes:
		_build_recipe_row(recipe)


func _build_recipe_row(recipe: Resource) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content_vbox.add_child(row)

	var label := Label.new()
	var inputs_text: String = ""
	for entry in recipe.inputs:
		var good: GoodData = entry.good
		if inputs_text != "":
			inputs_text += " + "
		var have: int = GameManager.get_cargo_quantity(good.good_name)
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
	build_btn.custom_minimum_size = Vector2(90, 32)
	build_btn.disabled = not CraftingManager.can_start_job(_planet_name, recipe)
	UIStyles.style_buy_button(build_btn)
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


func _close() -> void:
	factory_closed.emit()
	queue_free()
