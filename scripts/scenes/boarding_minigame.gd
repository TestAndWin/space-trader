extends ColorRect

signal boarding_finished(success: bool)

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

var _current_area: int = 0
var _secured_loot: Array = []
var _current_loot: Array = []
var _crew_used: Dictionary = {} # bonus_type -> bool

var _loot_label: Label
var _secured_label: Label
var _status_label: Label
var _btn_vbox: VBoxContainer
var _crew_btn_hbox: HBoxContainer

const AREAS = [
	{ "name": "Cargo Hold", "base_risk": 0.20, "loot_type": "cargo", "loot_val": [1, 2] },
	{ "name": "Engine Room", "base_risk": 0.35, "loot_type": "credits", "loot_val": [200, 350] },
	{ "name": "Bridge", "base_risk": 0.50, "loot_type": "intel", "loot_val": [1, 1] }
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	
	var BackgroundUtils = preload("res://scripts/tools/background_utils.gd")
	BackgroundUtils.add_fullscreen_background(self, "res://assets/sprites/scenes/bg_battle.png", 0.75, 1, true, TextureRect.STRETCH_SCALE)
	
	_build_ui()
	_start_area()


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIStyles.PANEL_COLOR
	style.border_color = UIStyles.BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(800, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "BOARDING ACTION"
	title.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIStyles.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Breaching..."
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)
	
	var data_hbox = HBoxContainer.new()
	data_hbox.add_theme_constant_override("separation", 40)
	data_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(data_hbox)
	
	_secured_label = Label.new()
	_secured_label.text = "Secured: None"
	_secured_label.add_theme_color_override("font_color", UIStyles.GOLD)
	data_hbox.add_child(_secured_label)
	
	_loot_label = Label.new()
	_loot_label.text = "At Risk: None"
	_loot_label.add_theme_color_override("font_color", UIStyles.NEGATIVE)
	data_hbox.add_child(_loot_label)

	_crew_btn_hbox = HBoxContainer.new()
	_crew_btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_crew_btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(_crew_btn_hbox)

	_btn_vbox = VBoxContainer.new()
	_btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_vbox.add_theme_constant_override("separation", 16)
	vbox.add_child(_btn_vbox)


func _start_area() -> void:
	if _current_area >= AREAS.size():
		_finish_boarding(true)
		return
		
	var area = AREAS[_current_area]
	_status_label.text = "Area %d: %s" % [_current_area + 1, area["name"]]
	
	_update_loot_displays()
	_build_area_buttons()


func _update_loot_displays() -> void:
	if _secured_loot.is_empty():
		_secured_label.text = "Secured: None"
	else:
		_secured_label.text = "Secured: " + ", ".join(_secured_loot)
		
	if _current_loot.is_empty():
		_loot_label.text = "At Risk: None"
	else:
		_loot_label.text = "At Risk: " + ", ".join(_current_loot)


func _build_area_buttons() -> void:
	for c in _btn_vbox.get_children():
		c.queue_free()
	for c in _crew_btn_hbox.get_children():
		c.queue_free()
		
	var area = AREAS[_current_area]
	
	var risk_safe = _calculate_risk(area["base_risk"], false)
	var risk_greedy = _calculate_risk(area["base_risk"], true)
	
	var safe_btn = Button.new()
	safe_btn.text = "Cautious Advance (Risk: %d%%)" % int(risk_safe * 100)
	safe_btn.custom_minimum_size = Vector2(300, 40)
	UIStyles.style_accent_button(safe_btn, Color(0.2, 0.4, 0.8))
	safe_btn.pressed.connect(_on_advance.bind(false, risk_safe))
	_btn_vbox.add_child(safe_btn)
	
	var greedy_btn = Button.new()
	greedy_btn.text = "Aggressive Push (Risk: %d%%, Better Loot)" % int(risk_greedy * 100)
	greedy_btn.custom_minimum_size = Vector2(300, 40)
	UIStyles.style_accent_button(greedy_btn, Color(0.6, 0.2, 0.2))
	greedy_btn.pressed.connect(_on_advance.bind(true, risk_greedy))
	_btn_vbox.add_child(greedy_btn)
	
	if not _current_loot.is_empty():
		var retreat_btn = Button.new()
		retreat_btn.text = "Fall Back & Secure Loot"
		retreat_btn.custom_minimum_size = Vector2(300, 40)
		UIStyles.style_accent_button(retreat_btn, Color(0.3, 0.3, 0.3))
		retreat_btn.pressed.connect(_finish_boarding.bind(true))
		_btn_vbox.add_child(retreat_btn)
		
	_build_crew_abilities()


func _build_crew_abilities() -> void:
	# Add crew abilities if they haven't been used yet
	var skills = [
		{"type": CrewData.CrewBonus.BOARDING_RISK, "name": "Weapons Officer: Suppress (-20% Risk)"},
		{"type": CrewData.CrewBonus.BOARDING_BREACH, "name": "Engineer: Bypass (0% Risk this area)"},
		{"type": CrewData.CrewBonus.BOARDING_LOOT, "name": "Smuggler: Scavenge (+Loot)"},
	]
	
	for skill in skills:
		if GameManager.has_crew_bonus(skill["type"]) and not _crew_used.get(skill["type"], false):
			var btn = Button.new()
			btn.text = skill["name"]
			btn.custom_minimum_size = Vector2(0, 40)
			UIStyles.style_secondary_button(btn)
			btn.pressed.connect(_use_crew_ability.bind(skill["type"]))
			_crew_btn_hbox.add_child(btn)


func _calculate_risk(base_risk: float, is_greedy: bool) -> float:
	var risk = base_risk
	if is_greedy:
		risk += 0.20
		
	# Subtract risk based on hull percentage (high hull = safer boarding)
	var hull_pct = float(GameManager.current_hull) / float(GameManager.max_hull) if GameManager.max_hull > 0 else 0.0
	risk -= (hull_pct * 0.15)
	
	if _crew_used.get(CrewData.CrewBonus.BOARDING_BREACH, false):
		return 0.0
	
	if _crew_used.get(CrewData.CrewBonus.BOARDING_RISK, false):
		risk -= GameManager.get_crew_secondary_bonus_value(CrewData.CrewBonus.BOARDING_RISK)
		
	return clampf(risk, 0.05, 0.95)


func _use_crew_ability(type: int) -> void:
	_crew_used[type] = true
	
	if type == CrewData.CrewBonus.BOARDING_LOOT:
		var bonus_loot = _generate_loot(AREAS[_current_area], false)
		_current_loot.append(bonus_loot)
		_status_label.text = "Smuggler found extra: " + bonus_loot
		_update_loot_displays()
	
	_build_area_buttons()


func _on_advance(is_greedy: bool, risk: float) -> void:
	for c in _btn_vbox.get_children():
		c.disabled = true
	for c in _crew_btn_hbox.get_children():
		c.disabled = true
		
	var roll = randf()
	if roll < risk:
		# Fail
		var dmg = 5 if not is_greedy else 10
		if GameManager.has_crew_bonus(CrewData.CrewBonus.BOARDING_MEDIC) and not _crew_used.get(CrewData.CrewBonus.BOARDING_MEDIC, false):
			dmg = 0
			_crew_used[CrewData.CrewBonus.BOARDING_MEDIC] = true
			_status_label.text = "Ambush! Medic prevented casualties."
		else:
			var unwounded_crew: Array = []
			for c in GameManager.crew:
				if c not in GameManager.wounded_crew:
					unwounded_crew.append(c)
			
			if unwounded_crew.size() > 0:
				var to_wound = unwounded_crew[randi() % unwounded_crew.size()]
				GameManager.wounded_crew.append(to_wound)
				var res = load(to_wound)
				_status_label.text = "Ambush! %s wounded, team routed! %d dmg." % [res.crew_name, dmg]
			else:
				_status_label.text = "Ambush! Team routed, taking %d hull damage." % dmg
				
			GameManager.current_hull -= dmg
		
		_status_label.add_theme_color_override("font_color", UIStyles.NEGATIVE)
		_current_loot.clear() # Lost un-secured loot
		_update_loot_displays()
		
		await get_tree().create_timer(2.0).timeout
		_finish_boarding(false)
	else:
		# Success
		_status_label.add_theme_color_override("font_color", UIStyles.POSITIVE)
		var loot = _generate_loot(AREAS[_current_area], is_greedy)
		_current_loot.append(loot)
		_status_label.text = "Area cleared! Found: " + loot
		
		# Move one un-secured to secured
		if _current_loot.size() > 0:
			var to_secure = _current_loot.pop_front()
			_secured_loot.append(to_secure)
			
		_update_loot_displays()
		_current_area += 1
		await get_tree().create_timer(1.5).timeout
		_status_label.remove_theme_color_override("font_color")
		_start_area()


func _generate_loot(area: Dictionary, is_greedy: bool) -> String:
	var mult = 1.5 if is_greedy else 1.0
	var min_val = int(area["loot_val"][0] * mult)
	var max_val = int(area["loot_val"][1] * mult)
	
	if area["loot_type"] == "credits":
		var amt = randi_range(min_val, max_val)
		return "%d cr" % amt
	elif area["loot_type"] == "cargo":
		var contraband = ["Spice", "Stolen Tech"]
		var item = contraband[randi() % contraband.size()]
		var cargo_str = "1x %s" % item
		var credits_str = "%d cr" % randi_range(50, 150)
		
		if is_greedy:
			return "%s & %s" % [cargo_str, credits_str]
		else:
			return cargo_str if randf() > 0.5 else credits_str
	elif area["loot_type"] == "intel":
		var roll = randf()
		if roll < 0.20:
			return "Intel Data & Crew Member"
		elif roll < 0.60:
			return "Intel Data & Ship Upgrade"
		else:
			return "Intel Data & Access Card"
		
	return "Unknown"


func _finish_boarding(success: bool) -> void:
	var loot_summary = []
	var total_cr = 0
	for combined_loot_str in _secured_loot + _current_loot:
		var parts = combined_loot_str.split(" & ")
		for loot_str in parts:
			if loot_str.ends_with("cr"):
				var cr = loot_str.to_int()
				GameManager.add_credits(cr)
				total_cr += cr
			elif "x " in loot_str:
				var split_cargo = loot_str.split("x ", true, 1)
				if split_cargo.size() == 2:
					GameManager.add_cargo(split_cargo[1], split_cargo[0].to_int())
					loot_summary.append(loot_str)
			elif loot_str.begins_with("Intel Data"):
				GameManager.pirate_intel += 1
				loot_summary.append("1x Intel Data")
				if "Ship Upgrade" in loot_str:
					GameManager.boarding_special_loot = "upgrade"
				elif "Access Card" in loot_str:
					GameManager.boarding_special_loot = "card"
				elif "Crew Member" in loot_str:
					GameManager.boarding_special_loot = "crew"
			
	if success:
		if total_cr > 0:
			loot_summary.insert(0, "%d cr" % total_cr)
		GameManager.extra_battle_message = ", ".join(loot_summary)
	boarding_finished.emit(success)
	if not success:
		queue_free()
