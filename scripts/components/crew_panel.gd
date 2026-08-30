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
	UIStyles.apply_section_title(title)
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
	status_label.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
	status_label.add_theme_color_override("font_color", UIStyles.POSITIVE)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)

	_all_crew_data = ResourceRegistry.load_all(ResourceRegistry.CREW)


func setup(planet_type: int = 0) -> void:
	_current_planet_type = planet_type
	_refresh_crew_ui()


func _refresh_crew_ui() -> void:
	for child in _icon_container.get_children():
		child.queue_free()
	for child in _crew_container.get_children():
		child.queue_free()

	# Populate crew portrait icons
	for path: String in GameManager.crew:
		var crew_res: Resource = load(path)
		if crew_res == null:
			continue
		var icon := Control.new()
		icon.set_script(CrewIcon)
		icon.custom_minimum_size = Vector2(60, 70)
		_icon_container.add_child(icon)
		icon.setup(crew_res.bonus_type)

	# Show current crew members
	for i in GameManager.crew.size():
		var path: String = GameManager.crew[i]
		var is_wounded: bool = path in GameManager.wounded_crew
		var crew_res: Resource = load(path)
		if crew_res == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_crew_container.add_child(row)

		var secondary_text: String = _get_secondary_bonus_text(crew_res)
		var info := Label.new()
		var text: String = crew_res.crew_name + " (" + str(crew_res.daily_wage) + "cr/day): " + crew_res.description
		if is_wounded:
			var days_left: int = int(GameManager.wounded_crew[path])
			text = "[WOUNDED (" + str(days_left) + " days left)] " + text
		if secondary_text != "":
			text += " | " + secondary_text
		info.text = text
		info.tooltip_text = crew_res.crew_name
		info.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
		if is_wounded:
			info.add_theme_color_override("font_color", UIStyles.NEGATIVE)
		else:
			info.add_theme_color_override("font_color", Color(0.4, 0.85, 0.65))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(info)

		var dismiss_btn := ActionButton.new()
		dismiss_btn.text = "Dismiss"
		var idx := i
		var crew_name: String = crew_res.crew_name
		dismiss_btn.pressed.connect(func():
			GameManager.dismiss_crew(idx)
			status_label.text = "%s dismissed" % crew_name
			_refresh_crew_ui()
			crew_action.emit()
		)
		row.add_child(dismiss_btn)

	if GameManager.crew.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No crew hired"
		empty_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_DETAIL)
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
		_crew_container.add_child(_build_hire_card(crew_res))


## Recruit offer as an info card: what the specialist does is visible *before*
## the hire, not only afterwards in the roster.
func _build_hire_card(crew_res: Resource) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.08, 0.06, 0.55)
	style.border_color = Color(0.15, 0.45, 0.35, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var icon := Control.new()
	icon.set_script(CrewIcon)
	icon.custom_minimum_size = Vector2(24, 24)
	header.add_child(icon)
	icon.setup(crew_res.bonus_type)

	var name_lbl := Label.new()
	name_lbl.text = crew_res.crew_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
	name_lbl.add_theme_color_override("font_color", Color(0.75, 0.95, 0.85))
	header.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "Hire: %d cr | %d cr/day" % [crew_res.recruit_cost, crew_res.daily_wage]
	UIStyles.apply_mono_font(cost_lbl)
	cost_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
	cost_lbl.add_theme_color_override("font_color", UIStyles.GOLD)
	header.add_child(cost_lbl)

	var bonus_lines: Array[String] = [crew_res.description]
	var secondary_text: String = _get_secondary_bonus_text(crew_res)
	if secondary_text != "":
		bonus_lines.append(secondary_text)
	var bonus_lbl := Label.new()
	bonus_lbl.text = "\n".join(bonus_lines)
	bonus_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_DETAIL)
	bonus_lbl.add_theme_color_override("font_color", Color(0.55, 0.8, 0.7))
	vbox.add_child(bonus_lbl)

	var crew_full: bool = GameManager.crew.size() >= GameManager.get_max_crew()
	var too_poor: bool = GameManager.credits < crew_res.recruit_cost
	var hire_btn := ActionButton.new()
	hire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hire_btn.disabled = crew_full or too_poor
	if crew_full:
		hire_btn.text = "Crew full (%d/%d)" % [GameManager.crew.size(), GameManager.get_max_crew()]
	elif too_poor:
		hire_btn.text = "Need %d cr" % crew_res.recruit_cost
	else:
		hire_btn.text = "Hire (%dcr)" % crew_res.recruit_cost
	var res_ref: Resource = crew_res
	hire_btn.pressed.connect(func():
		if GameManager.hire_crew(res_ref):
			AudioManager.play_purchase()
			EventLog.add_entry("Hired crew: %s" % res_ref.crew_name)
			status_label.text = "%s hired" % res_ref.crew_name
			_refresh_crew_ui()
			crew_action.emit()
	)
	vbox.add_child(hire_btn)
	return card


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
			return "+%.0f%% chance to dodge enemy first attack" % (secondary_value * 100.0)
		_:
			return ""
