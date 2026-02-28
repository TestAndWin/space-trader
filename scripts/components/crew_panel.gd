extends PanelContainer

signal crew_action

const BTN_BG := Color(0.02, 0.08, 0.18)
const BTN_BORDER := Color(0.0, 0.45, 0.75)
const BTN_DISABLED_BG := Color(0.02, 0.05, 0.10, 0.6)
const BTN_DISABLED_BORDER := Color(0.0, 0.2, 0.35, 0.4)

var _crew_container: VBoxContainer
var _icon_container: HBoxContainer
var _all_crew_data: Array = []
var _current_planet_type: int = 0
var status_label: Label

const CrewIcon := preload("res://scripts/components/crew_icon.gd")


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.14, 0.75)
	style.border_color = Color(0.0, 0.65, 0.95, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	var title := Label.new()
	title.text = "CREW"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		info.text = crew_res.description
		info.tooltip_text = crew_res.crew_name
		info.add_theme_font_size_override("font_size", 11)
		info.add_theme_color_override("font_color", Color(0.4, 0.85, 0.65))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(info)

		var dismiss_btn := Button.new()
		dismiss_btn.text = "Dismiss"
		dismiss_btn.add_theme_font_size_override("font_size", 10)
		_style_upgrade_button(dismiss_btn)
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
		_style_upgrade_button(hire_btn)
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


func _style_upgrade_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = BTN_BG
	normal.border_color = BTN_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 4
	normal.content_margin_right = 4
	normal.content_margin_top = 1
	normal.content_margin_bottom = 1

	var hover := normal.duplicate()
	hover.bg_color = BTN_BG.lightened(0.12)
	hover.border_color = BTN_BORDER.lightened(0.15)

	var pressed := normal.duplicate()
	pressed.bg_color = BTN_BG.darkened(0.15)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = BTN_DISABLED_BG
	disabled.border_color = BTN_DISABLED_BORDER
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
