extends ColorRect

signal boarding_finished(status: int)

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
var CardDisplay: PackedScene = preload("res://scenes/components/card_display.tscn")
var BackgroundUtils: GDScript = preload("res://scripts/tools/background_utils.gd")

var starting_alarm: int = 0
var _is_ending: bool = false
var _alarm_level: int = 0
var _max_alarm: int = 100
var _current_room_idx: int = 0
var _bag_capacity: int = 4
var _current_bag: Array = [] # array of dictionaries {name: String, slots: int, type: String, value: int/String}

var _deck_draw: Array = []
var _hand: Array = []

enum ThreatType { AIRLOCK, GUARDS, LOCKED_DOOR, TERMINAL, CELL, VAULT }

var _rooms: Array = []
var _intel_active: bool = false

var _ui_alarm_bar: ProgressBar
var _ui_room_title: Label
var _ui_room_desc: Label
var _ui_actions_vbox: VBoxContainer
var _ui_cards_hbox: HBoxContainer
var _ui_bag_label: Label
var _ui_room_loot_vbox: VBoxContainer
var _ui_log: Label
var _ui_advance_btn: Button
var _ui_retreat_btn: Button

func _ready() -> void:
	_alarm_level = starting_alarm
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	
	BackgroundUtils.add_fullscreen_background(self, "res://assets/sprites/scenes/bg_battle.png", 0.85, 1, true, TextureRect.STRETCH_SCALE)
	
	_init_rooms()
	_draw_hand()
	_build_ui()
	_update_room_view()

func _init_rooms() -> void:
	_rooms.clear()
	_rooms.append({ "type": ThreatType.AIRLOCK, "cleared": false, "loot": [], "revealed": true })
	
	var pool: Array = [ThreatType.GUARDS, ThreatType.GUARDS, ThreatType.LOCKED_DOOR, ThreatType.TERMINAL, ThreatType.CELL, ThreatType.VAULT]
	pool.shuffle()
	
	var has_intel = GameManager.has_crew_bonus(CrewData.CrewBonus.BOARDING_INTEL)
	for i in range(3): # 4 rooms total
		_rooms.append({ "type": pool[i], "cleared": false, "loot": [], "revealed": has_intel })
		
	# Pre-generate loot for rooms
	for i in range(4):
		if _rooms[i].type == ThreatType.VAULT:
			_rooms[i].loot.append({"name": "Secure Data (1 slot)", "slots": 1, "type": "data", "value": 250})
			_rooms[i].loot.append({"name": "Secure Data (1 slot)", "slots": 1, "type": "data", "value": 250})
		elif _rooms[i].type == ThreatType.GUARDS:
			_rooms[i].loot.append({"name": "Credits (1 slot)", "slots": 1, "type": "credits", "value": randi_range(50, 150)})
		elif _rooms[i].type == ThreatType.LOCKED_DOOR:
			_rooms[i].loot.append({"name": "Contraband (1 slot)", "slots": 1, "type": "cargo", "value": "Spice"})
			_rooms[i].loot.append({"name": "Contraband (1 slot)", "slots": 1, "type": "cargo", "value": "Spice"})
		elif _rooms[i].type == ThreatType.AIRLOCK:
			# Boarding Loot Bonus (Smuggler)
			if GameManager.has_crew_bonus(CrewData.CrewBonus.BOARDING_LOOT):
				var crew_name = ""
				for c in GameManager.get_crew_resources():
					if c.bonus_type == CrewData.CrewBonus.BOARDING_LOOT or c.secondary_bonus_type == CrewData.CrewBonus.BOARDING_LOOT:
						crew_name = c.crew_name
						break
				var label_name = "Smuggler Stash"
				if crew_name != "":
					label_name = "%s's Found Stash" % crew_name
				_rooms[i].loot.append({"name": label_name + " (1 slot)", "slots": 1, "type": "credits", "value": 150})
			
			# 50% chance for a small reward after securing airlock
			if randf() < 0.5:
				if randf() < 0.5:
					_rooms[i].loot.append({"name": "Loose Credits (1 slot)", "slots": 1, "type": "credits", "value": randi_range(15, 40)})
				else:
					var cheap_goods: Array = ["Food Rations", "Raw Ore"]
					var good_name: String = cheap_goods[randi() % cheap_goods.size()]
					_rooms[i].loot.append({"name": good_name + " (1 slot)", "slots": 1, "type": "cargo", "value": good_name})

func _draw_hand() -> void:
	randomize()
	_deck_draw = GameManager.deck.duplicate()
	_deck_draw.shuffle()
	for i in range(min(4, _deck_draw.size())):
		var card: Resource = _deck_draw[i].duplicate()
		var type_int: int = int(card.card_type)
		if card.get("boarding_description") != null and card.boarding_description != "":
			card.description = card.boarding_description
		else:
			if type_int == 0:
				var a1 = card.get("boarding_alarm_vs_guards") if card.get("boarding_alarm_vs_guards") != null and card.get("boarding_alarm_vs_guards") >= 0 else max(0, (card.attack_value - 4) * 3)
				var a2 = card.get("boarding_alarm_vs_doors") if card.get("boarding_alarm_vs_doors") != null and card.get("boarding_alarm_vs_doors") >= 0 else clampi(45 - (card.attack_value * 3), 10, 50)
				card.description = "Attack: Defeat Guards (+%d Alarm) or blow up doors (+%d Alarm)." % [a1, a2]
			elif type_int == 1:
				var a1 = card.get("boarding_alarm_vs_guards") if card.get("boarding_alarm_vs_guards") != null and card.get("boarding_alarm_vs_guards") >= 0 else clampi(35 - (card.defense_value * 3), 0, 35)
				var a2 = card.get("boarding_alarm_vs_hostage") if card.get("boarding_alarm_vs_hostage") != null and card.get("boarding_alarm_vs_hostage") >= 0 else clampi(30 - (card.defense_value * 2), 0, 30)
				card.description = "Defense: Tank through Guards (+%d Alarm) or protect Hostage (+%d Alarm)." % [a1, a2]
			elif type_int == 2:
				var rarity_val: int = int(card.rarity if card.rarity != null else 0)
				var a1 = card.get("boarding_alarm_vs_doors") if card.get("boarding_alarm_vs_doors") != null and card.get("boarding_alarm_vs_doors") >= 0 else max(0, 15 - (card.energy_cost * 5) - (rarity_val * 5))
				card.description = "Utility: Hack Terminal/Door/Vault (+%d Alarm)." % a1
			elif type_int == 3:
				card.description = "Trade: Not very effective in boarding."
		_hand.append(card)

func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_vbox)
	
	# TOP: Alarm & Bag status
	var top_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(top_hbox)
	
	var title: Label = Label.new()
	title.text = "BOARDING ACTION"
	title.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UIStyles.ACCENT)
	top_hbox.add_child(title)
	
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)
	
	_ui_bag_label = Label.new()
	_ui_bag_label.text = "Extraction Bag: 0 / 4 Slots"
	_ui_bag_label.add_theme_font_size_override("font_size", 20)
	top_hbox.add_child(_ui_bag_label)
	
	_ui_alarm_bar = ProgressBar.new()
	_ui_alarm_bar.custom_minimum_size = Vector2(0, 30)
	_ui_alarm_bar.max_value = _max_alarm
	_ui_alarm_bar.value = _alarm_level
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.8, 0.2, 0.2)
	_ui_alarm_bar.add_theme_stylebox_override("fill", sb)
	main_vbox.add_child(_ui_alarm_bar)
	
	# MIDDLE: Room & Cards
	var middle_hbox: HBoxContainer = HBoxContainer.new()
	middle_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_hbox.add_theme_constant_override("separation", 30)
	main_vbox.add_child(middle_hbox)
	
	# CREW BUFFS BAR
	var crew_hbox: HBoxContainer = HBoxContainer.new()
	crew_hbox.add_theme_constant_override("separation", 10)
	
	var has_crew = false
	for crew_member in GameManager.get_crew_resources():
		var bonus_text = ""
		if crew_member.bonus_type == CrewData.CrewBonus.BOARDING_RISK or crew_member.secondary_bonus_type == CrewData.CrewBonus.BOARDING_RISK:
			bonus_text = "-20% Alarm Gain"
		elif crew_member.bonus_type == CrewData.CrewBonus.BOARDING_LOOT or crew_member.secondary_bonus_type == CrewData.CrewBonus.BOARDING_LOOT:
			bonus_text = "Extra Airlock Loot"
		elif crew_member.bonus_type == CrewData.CrewBonus.BOARDING_BREACH or crew_member.secondary_bonus_type == CrewData.CrewBonus.BOARDING_BREACH:
			bonus_text = "-15 Brute Force Alarm"
		elif crew_member.bonus_type == CrewData.CrewBonus.BOARDING_INTEL or crew_member.secondary_bonus_type == CrewData.CrewBonus.BOARDING_INTEL:
			bonus_text = "Rooms Revealed"
		elif crew_member.bonus_type == CrewData.CrewBonus.BOARDING_MEDIC or crew_member.secondary_bonus_type == CrewData.CrewBonus.BOARDING_MEDIC:
			bonus_text = "-10 Hull Dmg on Fail"
			
		if bonus_text != "":
			has_crew = true
			var badge: Label = Label.new()
			badge.text = " 👤 " + crew_member.crew_name + ": " + bonus_text + " "
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color(0.15, 0.35, 0.55, 0.8)
			style.border_color = Color(0.3, 0.6, 0.8, 1.0)
			style.set_border_width_all(1)
			style.corner_radius_top_left = 5
			style.corner_radius_top_right = 5
			style.corner_radius_bottom_left = 5
			style.corner_radius_bottom_right = 5
			badge.add_theme_stylebox_override("normal", style)
			crew_hbox.add_child(badge)
			
	if has_crew:
		main_vbox.add_child(crew_hbox)
		main_vbox.move_child(crew_hbox, main_vbox.get_child_count() - 2) # Move above middle_hbox
	
	# Left: Room Info
	var room_panel: PanelContainer = PanelContainer.new()
	room_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p_style: StyleBoxFlat = StyleBoxFlat.new()
	p_style.bg_color = UIStyles.PANEL_COLOR
	p_style.border_color = UIStyles.BORDER_COLOR
	p_style.set_border_width_all(2)
	p_style.content_margin_left = 20
	p_style.content_margin_top = 20
	p_style.content_margin_right = 20
	p_style.content_margin_bottom = 20
	room_panel.add_theme_stylebox_override("panel", p_style)
	middle_hbox.add_child(room_panel)
	
	var room_vbox: VBoxContainer = VBoxContainer.new()
	room_vbox.add_theme_constant_override("separation", 15)
	room_panel.add_child(room_vbox)
	
	_ui_room_title = Label.new()
	_ui_room_title.add_theme_font_size_override("font_size", 24)
	room_vbox.add_child(_ui_room_title)
	
	_ui_room_desc = Label.new()
	_ui_room_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_ui_room_desc.add_theme_font_size_override("font_size", 18)
	room_vbox.add_child(_ui_room_desc)
	
	_ui_actions_vbox = VBoxContainer.new()
	_ui_actions_vbox.add_theme_constant_override("separation", 10)
	room_vbox.add_child(_ui_actions_vbox)
	
	_ui_room_loot_vbox = VBoxContainer.new()
	room_vbox.add_child(_ui_room_loot_vbox)
	
	var rspacer: Control = Control.new()
	rspacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room_vbox.add_child(rspacer)
	
	_ui_log = Label.new()
	_ui_log.add_theme_color_override("font_color", UIStyles.GOLD)
	room_vbox.add_child(_ui_log)
	
	# Right: Hand Cards
	var cards_panel: PanelContainer = PanelContainer.new()
	cards_panel.add_theme_stylebox_override("panel", p_style)
	middle_hbox.add_child(cards_panel)
	
	var cards_vbox: VBoxContainer = VBoxContainer.new()
	cards_panel.add_child(cards_vbox)
	
	var cards_title: Label = Label.new()
	cards_title.text = "Combat Deck (Tools)"
	cards_title.add_theme_font_size_override("font_size", 20)
	cards_vbox.add_child(cards_title)
	
	_ui_cards_hbox = HBoxContainer.new()
	_ui_cards_hbox.add_theme_constant_override("separation", 10)
	cards_vbox.add_child(_ui_cards_hbox)
	
	# BOTTOM: Navigation
	var nav_hbox: HBoxContainer = HBoxContainer.new()
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_hbox.add_theme_constant_override("separation", 30)
	main_vbox.add_child(nav_hbox)
	
	_ui_retreat_btn = Button.new()
	_ui_retreat_btn.text = "Extract & Back to ship"
	_ui_retreat_btn.custom_minimum_size = Vector2(200, 50)
	UIStyles.style_accent_button(_ui_retreat_btn, Color(0.3, 0.3, 0.3))
	_ui_retreat_btn.pressed.connect(_finish_boarding.bind(1))
	nav_hbox.add_child(_ui_retreat_btn)
	
	_ui_advance_btn = Button.new()
	_ui_advance_btn.text = "Next Room (+10 Alarm)"
	_ui_advance_btn.custom_minimum_size = Vector2(200, 50)
	UIStyles.style_accent_button(_ui_advance_btn, Color(0.2, 0.4, 0.8))
	_ui_advance_btn.pressed.connect(func():
		_current_room_idx += 1
		if _current_room_idx >= _rooms.size():
			_finish_boarding(2)
		else:
			_add_alarm(10) # Moving causes a bit of alarm
			if _is_ending: return
			_update_room_view()
	)
	nav_hbox.add_child(_ui_advance_btn)
	
func _refresh_cards() -> void:
	for c in _ui_cards_hbox.get_children():
		c.queue_free()
	
	var is_cleared: bool = false
	if _current_room_idx < _rooms.size():
		is_cleared = _rooms[_current_room_idx].cleared
		
	for i in range(_hand.size()):
		var card: Resource = _hand[i]
		var c_disp: Control = CardDisplay.instantiate()
		_ui_cards_hbox.add_child(c_disp)
		c_disp.setup(card, true, "Use", not is_cleared and not _is_ending, true)
		c_disp.card_played.connect(_on_card_used.bind(i))

func _on_card_used(_card_data: Resource, hand_index: int) -> void:
	var room: Dictionary = _rooms[_current_room_idx]
	if room.cleared: return
	
	var card: Resource = _hand[hand_index]
	var type_int: int = int(card.card_type)
	var success: bool = false
	var log_msg: String = ""
	
	if room.type == ThreatType.GUARDS:
		if type_int == 0: # Attack
			var base_alarm: int = card.get("boarding_alarm_vs_guards") if card.get("boarding_alarm_vs_guards") != null and card.get("boarding_alarm_vs_guards") >= 0 else max(0, (card.attack_value - 4) * 3)
			success = true
			var actual = 0
			if base_alarm > 0: actual = _add_alarm(base_alarm)
			log_msg = "Used " + card.card_name + " to eliminate guards! (+%d Alarm)" % actual + _last_alarm_reduction_text
		elif type_int == 1: # Defense
			var base_alarm: int = card.get("boarding_alarm_vs_guards") if card.get("boarding_alarm_vs_guards") != null and card.get("boarding_alarm_vs_guards") >= 0 else clampi(35 - (card.defense_value * 3), 0, 35)
			success = true
			var actual = 0
			if base_alarm > 0: actual = _add_alarm(base_alarm)
			log_msg = "Used " + card.card_name + " to tank through guards! (+%d Alarm)" % actual + _last_alarm_reduction_text
		else:
			_ui_log.text = "Card ineffective against guards!"
			return
	elif room.type == ThreatType.LOCKED_DOOR:
		if type_int == 2: # Utility
			var rarity_val: int = int(card.rarity if card.rarity != null else 0)
			var base_alarm: int = card.boarding_alarm_vs_doors if card.boarding_alarm_vs_doors != null and card.boarding_alarm_vs_doors >= 0 else max(0, 15 - (card.energy_cost * 5) - (rarity_val * 5))
			success = true
			var actual = 0
			if base_alarm > 0: actual = _add_alarm(base_alarm)
			log_msg = "Used " + card.card_name + " to bypass door. (+%d Alarm)" % actual + _last_alarm_reduction_text
		elif type_int == 0: # Attack
			var base_alarm: int = card.boarding_alarm_vs_doors if card.boarding_alarm_vs_doors != null and card.boarding_alarm_vs_doors >= 0 else clampi(45 - (card.attack_value * 3), 10, 50)
			success = true
			var actual = _add_alarm(base_alarm)
			log_msg = "Used " + card.card_name + " to blow the door! (+%d Alarm)" % actual + _last_alarm_reduction_text
		else:
			_ui_log.text = "Need Attack or Utility to pass door!"
			return
	elif room.type == ThreatType.TERMINAL:
		if type_int == 2: # Utility
			var rarity_val: int = int(card.rarity if card.rarity != null else 0)
			var base_alarm: int = card.boarding_alarm_vs_terminals if card.boarding_alarm_vs_terminals != null and card.boarding_alarm_vs_terminals >= 0 else max(0, 15 - (card.energy_cost * 5) - (rarity_val * 5))
			success = true
			_intel_active = true
			var actual = 0
			if base_alarm > 0: actual = _add_alarm(base_alarm)
			log_msg = "Hacked terminal! Remaining rooms revealed. (+%d Alarm)" % actual + _last_alarm_reduction_text
			for r in _rooms: r.revealed = true
		else:
			_ui_log.text = "Need Utility card to hack terminal."
			return
	elif room.type == ThreatType.CELL:
		if type_int == 1: # Defense
			var base_alarm: int = card.boarding_alarm_vs_hostage if card.boarding_alarm_vs_hostage != null and card.boarding_alarm_vs_hostage >= 0 else clampi(30 - (card.defense_value * 2), 0, 30)
			success = true
			var actual = 0
			if base_alarm > 0: actual = _add_alarm(base_alarm)
			log_msg = "Used " + card.card_name + " to rescue hostage! (+%d Alarm)" % actual + _last_alarm_reduction_text
			_rooms[_current_room_idx].loot.append({"name": "Grateful Hostage (0 slots)", "slots": 0, "type": "hostage", "value": 0})
		else:
			var base_alarm: int = 20
			success = true
			var actual = _add_alarm(base_alarm)
			log_msg = "Used " + card.card_name + " to rescue hostage! (+%d Alarm)" % actual + _last_alarm_reduction_text
			_rooms[_current_room_idx].loot.append({"name": "Grateful Hostage (0 slots)", "slots": 0, "type": "hostage", "value": 0})
	elif room.type == ThreatType.VAULT:
		if type_int == 2:
			var rarity_val: int = int(card.rarity if card.rarity != null else 0)
			var base_alarm: int = card.boarding_alarm_vs_vaults if card.boarding_alarm_vs_vaults != null and card.boarding_alarm_vs_vaults >= 0 else max(0, 15 - (card.energy_cost * 5) - (rarity_val * 5))
			success = true
			var actual = 0
			if base_alarm > 0: actual = _add_alarm(base_alarm)
			log_msg = "Vault unlocked silently. (+%d Alarm)" % actual + _last_alarm_reduction_text
		else:
			success = true
			var base_alarm: int = 40
			if type_int == 0: 
				base_alarm = card.boarding_alarm_vs_vaults if card.boarding_alarm_vs_vaults != null and card.boarding_alarm_vs_vaults >= 0 else clampi(45 - (card.attack_value * 3), 10, 50)
			var actual = _add_alarm(base_alarm)
			log_msg = "Vault cracked loud! (+%d Alarm)" % actual + _last_alarm_reduction_text
	elif room.type == ThreatType.AIRLOCK:
		success = true
		log_msg = "Secured airlock."

	if success:
		_hand.remove_at(hand_index)
		room.cleared = true
		
		if _is_ending:
			return
			
		_ui_log.text = log_msg
			
		_update_room_view()
		_refresh_cards()

func _update_room_view() -> void:
	var room: Dictionary = _rooms[_current_room_idx]
	
	var is_unknown: bool = (not room.revealed and not room.cleared and _current_room_idx > 0)
	
	if is_unknown:
		_ui_room_title.text = "Room %d: Unknown Threat" % (_current_room_idx + 1)
		_ui_room_desc.text = "Proceed with caution. The area ahead is not mapped."
	else:
		room.revealed = true
		_ui_room_title.text = "Room %d: %s" % [_current_room_idx + 1, _get_room_name(room.type)]
		_ui_room_desc.text = _get_room_desc(room.type, room.cleared)
		
	for c in _ui_actions_vbox.get_children(): c.queue_free()
	for c in _ui_room_loot_vbox.get_children(): c.queue_free()
	
	if not room.cleared:
		# Brute force option
		var bf_btn: Button = Button.new()
		var bf_alarm: int = _get_brute_force_alarm(room.type)
		if is_unknown:
			bf_btn.text = "Blind Brute Force (? Alarm)"
		else:
			bf_btn.text = "Brute Force (+%d Alarm)" % bf_alarm
			
		UIStyles.style_accent_button(bf_btn, Color(0.6, 0.2, 0.2))
		bf_btn.pressed.connect(func():
			var actual = _add_alarm(bf_alarm)
			room.cleared = true
			if _is_ending: return
			_ui_log.text = "Used brute force! (+%d Alarm)" % actual + _last_alarm_reduction_text
			_update_room_view()
		)
		_ui_actions_vbox.add_child(bf_btn)
	else:
		# Show loot if cleared
		if room.loot.size() > 0:
			var l_lbl: Label = Label.new()
			l_lbl.text = "Found Loot:"
			_ui_room_loot_vbox.add_child(l_lbl)
			for i in range(room.loot.size()):
				var item: Dictionary = room.loot[i]
				var l_btn: Button = Button.new()
				l_btn.text = "Take: " + item.name
				UIStyles.style_secondary_button(l_btn)
				l_btn.pressed.connect(func():
					_take_loot(item, i)
				)
				_ui_room_loot_vbox.add_child(l_btn)
				
	_ui_advance_btn.disabled = not room.cleared
	if _current_room_idx >= _rooms.size() - 1:
		_ui_advance_btn.text = "Finish Boarding"
	else:
		_ui_advance_btn.text = "Next Room (+10 Alarm)"
		
	_refresh_cards()

func _take_loot(item: Dictionary, loot_idx: int) -> void:
	var used: int = 0
	for b in _current_bag: used += b.slots
	if used + item.slots > _bag_capacity:
		_ui_log.text = "Not enough space in extraction bag!"
		return
		
	_current_bag.append(item)
	_rooms[_current_room_idx].loot.remove_at(loot_idx)
	_ui_log.text = "Took " + item.name
	_update_bag_display()
	_update_room_view()

func _update_bag_display() -> void:
	var used: int = 0
	for b in _current_bag: used += b.slots
	_ui_bag_label.text = "Extraction Bag: %d / %d Slots" % [used, _bag_capacity]

func _get_room_name(type: int) -> String:
	match type:
		ThreatType.AIRLOCK: return "Airlock"
		ThreatType.GUARDS: return "Security Patrol"
		ThreatType.LOCKED_DOOR: return "Blast Door"
		ThreatType.TERMINAL: return "Security Terminal"
		ThreatType.CELL: return "Brig / Holding Cell"
		ThreatType.VAULT: return "Cargo Vault"
	return "Unknown"
	
func _get_room_desc(type: int, cleared: bool) -> String:
	if cleared: return "Area secured."
	match type:
		ThreatType.AIRLOCK: return "The entry point. Quiet for now."
		ThreatType.GUARDS: return "Guards block the way. Defeat them (Attack card) or tank through (Defense)."
		ThreatType.LOCKED_DOOR: return "A heavy blast door. Hack it (Utility) or blow it up (Attack)."
		ThreatType.TERMINAL: return "A terminal. Hack it (Utility) to reveal the ship layout."
		ThreatType.CELL: return "Someone is locked in here. Rescue them for a reward."
		ThreatType.VAULT: return "A reinforced vault. Needs delicate cracking (Utility) or explosives."
	return ""

func _get_brute_force_alarm(type: int) -> int:
	var base = 0
	match type:
		ThreatType.AIRLOCK: base = 0
		ThreatType.GUARDS: base = 40
		ThreatType.LOCKED_DOOR: base = 45
		ThreatType.TERMINAL: base = 10
		ThreatType.CELL: base = 20
		ThreatType.VAULT: base = 50
		
	if base > 0 and GameManager.has_crew_bonus(CrewData.CrewBonus.BOARDING_BREACH):
		base = max(0, base - 15)
		
	return base

var _last_alarm_reduction_text: String = ""

func _add_alarm(amount: int) -> int:
	_last_alarm_reduction_text = ""
	var orig_amount = amount
	var crew_name = ""
	for c in GameManager.get_crew_resources():
		if c.bonus_type == CrewData.CrewBonus.BOARDING_RISK or c.secondary_bonus_type == CrewData.CrewBonus.BOARDING_RISK:
			crew_name = c.crew_name
			break
			
	if crew_name != "":
		amount = int(float(amount) * 0.8)
		if orig_amount > 0 and orig_amount != amount:
			_last_alarm_reduction_text = " (-20%% by %s)" % crew_name
		
	_alarm_level += amount
	
	if _alarm_level >= _max_alarm:
		_alarm_level = _max_alarm
		_ui_alarm_bar.value = _alarm_level
		_ui_alarm_bar.get_theme_stylebox("fill").bg_color = Color(1, 0, 0)
		_fail_boarding()
	else:
		_ui_alarm_bar.value = _alarm_level
		
	return amount

func _fail_boarding() -> void:
	if _is_ending: return
	_is_ending = true
	
	var dmg = 20
	if GameManager.has_crew_bonus(CrewData.CrewBonus.BOARDING_MEDIC):
		dmg = 10
		
	GameManager.current_hull -= dmg
	GameManager.current_shield = int(float(GameManager.current_shield) * 0.5)
	
	_ui_room_title.text = "CRITICAL FAILURE!"
	_ui_room_title.add_theme_color_override("font_color", Color(1, 0, 0))
	if dmg == 10:
		_ui_room_desc.text = "ALARM 100%! The enemy ship locked down its bulkheads... Thanks to your Boarding Medic, casualties were minimized! Your ship took 10 hull damage and lost shields during emergency undocking!\n\n>>> RESUMING SHIP COMBAT... <<<"
	else:
		_ui_room_desc.text = "ALARM 100%! The enemy ship locked down its bulkheads and activated automated defenses. Your boarding party barely escaped under heavy fire, but your ship took 20 hull damage and lost shields during the emergency undocking!\n\n>>> RESUMING SHIP COMBAT... <<<"
	
	_ui_log.text = ""
	for c in _ui_actions_vbox.get_children(): c.queue_free()
	_ui_actions_vbox.hide()
	for c in _ui_room_loot_vbox.get_children(): c.queue_free()
	_ui_room_loot_vbox.hide()
	for c in _ui_cards_hbox.get_children(): c.queue_free()
	if _ui_advance_btn: _ui_advance_btn.hide()
	
	_ui_retreat_btn.text = "Flee to ship"
	for c in _ui_retreat_btn.pressed.get_connections():
		_ui_retreat_btn.pressed.disconnect(c.callable)
	_ui_retreat_btn.pressed.connect(func():
		boarding_finished.emit(0)
		queue_free()
	)
	_ui_retreat_btn.show()

func _finish_boarding(status: int) -> void:
	if _is_ending: return
	
	if status == 0:
		_is_ending = true
		boarding_finished.emit(0)
		queue_free()
		return
		
	_is_ending = true
	var total_cr: int = 0
	var loot_summary: PackedStringArray = PackedStringArray()
	for item in _current_bag:
		if item.type == "credits":
			total_cr += item.value
		elif item.type == "cargo":
			GameManager.add_cargo(item.value, 1)
			loot_summary.append("1x " + item.value)
		elif item.type == "data":
			total_cr += item.value
			loot_summary.append("Data sold for %d cr" % item.value)
		elif item.type == "hostage":
			GameManager.add_credits(200) # Quick reward for hostage
			loot_summary.append("Hostage Reward: 200 cr")
			
	if total_cr > 0:
		GameManager.add_credits(total_cr)
		loot_summary.insert(0, "%d cr" % total_cr)
		
	GameManager.extra_battle_message = ", ".join(loot_summary)
	
	if status == 2:
		_ui_room_title.text = "Ship Captured!"
		_ui_room_desc.text = "Enemy crew defeated! Securing ship and loot...\n\n>>> ENEMY DEFEATED <<<"
	else:
		_ui_room_title.text = "Extraction Successful!"
		_ui_room_desc.text = "Returning to ship with secured loot...\n\n>>> RESUMING SHIP COMBAT... <<<"
	for c in _ui_actions_vbox.get_children(): c.queue_free()
	_ui_actions_vbox.hide()
	for c in _ui_room_loot_vbox.get_children(): c.queue_free()
	_ui_room_loot_vbox.hide()
	for c in _ui_cards_hbox.get_children(): c.queue_free()
	if _ui_advance_btn: _ui_advance_btn.hide()
	
	_ui_retreat_btn.text = "Continue"
	for c in _ui_retreat_btn.pressed.get_connections():
		_ui_retreat_btn.pressed.disconnect(c.callable)
	_ui_retreat_btn.pressed.connect(func():
		boarding_finished.emit(status)
		if status == 1:
			queue_free()
	)
	_ui_retreat_btn.show()
