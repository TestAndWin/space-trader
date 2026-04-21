extends PanelContainer

signal crew_action

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

var _crew_container: VBoxContainer
var _icon_container: HBoxContainer
var _all_crew_data: Array = []
var _current_planet_type: int = 0
var status_label: Label

const CrewIcon := preload("res://scripts/components/crew_icon.gd")


func _ready() -> void:
	UIStyles.style_panel(self)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	var title := Label.new()
	title.text = "CREW"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vbox.add_child(title)

	_icon_container = HBoxContainer.new()
	_icon_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_icon_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_icon_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_icon_container)

	_crew_container = VBoxContainer.new()
	_crew_container.add_theme_constant_override("separation", 2)
	vbox.add_child(_crew_container)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.6))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)

	_load_all_crew_data()


func setup(planet_type: int = 0) -> void:
	_current_planet_type = planet_type
	_refresh_crew_ui()


func _load_all_crew_data() -> void:
	_all_crew_data = ResourceRegistry.load_all(ResourceRegistry.CREW)


func _refresh_crew_ui() -> void:
	for child in _icon_container.get_children():
		child.queue_free()
	for child in _crew_container.get_children():
		child.queue_free()

	var crew_resources := GameManager.get_crew_resources()

	# Populate crew portrait icons
	for crew_res in crew_resources:
		var icon := Control.new()
		icon.set_script(CrewIcon)
		icon.custom_minimum_size = Vector2(60, 70)
		_icon_container.add_child(icon)
		icon.setup(crew_res.bonus_type)

	# Show current crew members
	for i in crew_resources.size():
		var crew_res: Resource = crew_resources[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_crew_container.add_child(row)

		var info := Label.new()
		var secondary_text: String = _get_secondary_bonus_text(crew_res)
		info.text = crew_res.description + (("\n+ " + secondary_text) if secondary_text != "" else "")
		info.tooltip_text = crew_res.crew_name
		info.add_theme_font_size_override("font_size", 11)
		info.add_theme_color_override("font_color", Color(0.4, 0.85, 0.65))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(info)

		var dismiss_btn := Button.new()
		dismiss_btn.text = "Dismiss"
		dismiss_btn.add_theme_font_size_override("font_size", 10)
		UIStyles.style_small_secondary_button(dismiss_btn)
		var idx := i
		var crew_name: String = crew_res.crew_name
		dismiss_btn.pressed.connect(func():
			GameManager.dismiss_crew(idx)
			status_label.text = "%s dismissed" % crew_name
			_refresh_crew_ui()
			crew_action.emit()
		)
		row.add_child(dismiss_btn)

	if crew_resources.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No crew hired"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.42, 0.45))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_crew_container.add_child(empty_lbl)

	# Show available crew for hire at this planet type
	var hired_paths: Array = GameManager.crew
	var available: Array = []
	for crew_res in _all_crew_data:
		if crew_res.resource_path in hired_paths:
			continue
		if _current_planet_type in crew_res.available_planet_types:
			available.append(crew_res)

	for crew_res in available:
		var hire_btn := Button.new()
		hire_btn.text = "Hire %s (%dcr)" % [crew_res.crew_name, crew_res.recruit_cost]
		hire_btn.tooltip_text = crew_res.description
		hire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIStyles.style_small_secondary_button(hire_btn)
		hire_btn.disabled = GameManager.credits < crew_res.recruit_cost or GameManager.crew.size() >= GameManager.MAX_CREW
		var res_ref: Resource = crew_res
		hire_btn.pressed.connect(func():
			if GameManager.hire_crew(res_ref):
				EventLog.add_entry("Hired crew: %s" % res_ref.crew_name)
				status_label.text = "%s hired" % res_ref.crew_name
				_refresh_crew_ui()
				crew_action.emit()
		)
		_crew_container.add_child(hire_btn)


func _get_secondary_bonus_text(crew_res: Resource) -> String:
	var secondary_type: int = crew_res.secondary_bonus_type
	var secondary_value: float = crew_res.secondary_bonus_value
	if secondary_value <= 0.0:
		return ""
	match secondary_type:
		CrewData.CrewBonus.EVENT_SKILL:
			return "+%.0f%% event success chance" % (secondary_value * 100.0)
		CrewData.CrewBonus.QUEST_NEGOTIATION:
			return "+1 quest deadline, +%.0f%% reward" % (secondary_value * 10.0)
		CrewData.CrewBonus.COMBAT_TACTICAL:
			return "%.0f%% chance to dodge enemy first attack" % (secondary_value * 100.0)
		_:
			return ""
