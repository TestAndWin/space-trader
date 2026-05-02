extends PanelContainer

signal quest_changed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

var planet_name: String = ""
var just_completed: bool = false


func setup(p_planet_name: String) -> void:
	planet_name = p_planet_name
	just_completed = false
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	UIStyles.style_panel(self)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "QUEST"
	UIStyles.apply_section_title(title)
	vbox.add_child(title)

	var quality: Dictionary = QuestManager.get_offer_quality_for_planet(planet_name)
	_add_quality_summary(vbox, quality)

	# Just completed
	if just_completed:
		var done_label := Label.new()
		done_label.text = "Quest completed!"
		done_label.add_theme_font_size_override("font_size", 17)
		done_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		vbox.add_child(done_label)
		var next_btn := _make_action_btn("New Quest")
		next_btn.pressed.connect(func(): just_completed = false; _build_ui())
		vbox.add_child(next_btn)
		_add_loan_panel(vbox)
		_add_bounty_panel(vbox)
		return

	# Active quest
	if QuestManager.has_active_quest():
		var q: Dictionary = QuestManager.current_quest
		var desc := Label.new()
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.text = "%s\nDeliver %d %s to %s\nReward: %d cr" % [
			q.get("flavor", "Contract"),
			q["deliver_qty"], q["deliver_good"], q["destination"], q["reward_credits"]
		]
		desc.add_theme_font_size_override("font_size", 16)
		desc.add_theme_color_override("font_color", Color(0.4, 0.85, 0.65))
		vbox.add_child(desc)

		var chain_label := Label.new()
		chain_label.text = "%s (Reputation %s) | Stage %d/%d" % [
			q.get("issuer_faction", "Independent"),
			q.get("issuer_rep_tier", "Neutral"),
			q.get("stage", 1),
			q.get("chain_length", 1)
		]
		chain_label.add_theme_font_size_override("font_size", 15)
		chain_label.add_theme_color_override("font_color", Color(0.6, 0.78, 1.0))
		vbox.add_child(chain_label)

		_add_offer_modifiers(vbox, q)
		_add_quality_notes(vbox, q.get("quality_notes", []), Color(0.75, 0.75, 0.95))

		var days_left: int = q.get("days_left", 0)
		var penalty: int = q.get("penalty", 0)
		var route_days: int = q.get("route_days", 0)
		var deadline_label := Label.new()
		deadline_label.add_theme_font_override("font", UIStyles.FONT_MONO)
		deadline_label.add_theme_font_size_override("font_size", 15)
		if days_left <= 1:
			deadline_label.text = "LAST CHANCE! Travel: %d days | Penalty: %d cr" % [route_days, penalty]
			deadline_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			deadline_label.text = "%d days left | Travel: %d days | Penalty: %d cr" % [days_left, route_days, penalty]
			deadline_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
		vbox.add_child(deadline_label)

		# Check if we can deliver here
		if q["destination"] == planet_name and _player_has_goods(q):
			var deliver_btn := _make_action_btn("Deliver (%d %s)" % [q["deliver_qty"], q["deliver_good"]])
			deliver_btn.pressed.connect(_on_deliver)
			vbox.add_child(deliver_btn)
		elif q["destination"] == planet_name:
			var missing_label := Label.new()
			missing_label.text = "Need %d %s to deliver" % [q["deliver_qty"], q["deliver_good"]]
			missing_label.add_theme_font_size_override("font_size", 15)
			missing_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.3))
			vbox.add_child(missing_label)
		_add_loan_panel(vbox)
		_add_bounty_panel(vbox)
		return

	# No active quest — show local offer
	var offer: Dictionary = QuestManager.get_offer_for_planet(planet_name)
	if offer.is_empty():
		var none_label := Label.new()
		none_label.text = "No quests available"
		none_label.add_theme_font_size_override("font_size", 16)
		none_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		vbox.add_child(none_label)
		return
	if bool(offer.get("blocked", false)):
		var blocked_label := Label.new()
		blocked_label.text = str(offer.get("blocked_reason", "No quests available"))
		blocked_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		blocked_label.add_theme_font_size_override("font_size", 16)
		blocked_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
		vbox.add_child(blocked_label)
		_add_quality_notes(vbox, offer.get("quality_notes", []), Color(0.9, 0.72, 0.45))
		_add_loan_panel(vbox)
		_add_bounty_panel(vbox)
		return

	var offer_desc := Label.new()
	offer_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	offer_desc.text = "%s\nDeliver %d %s to %s\nReward: %d cr" % [
		offer.get("flavor", "Contract"),
		offer["deliver_qty"], offer["deliver_good"], offer["destination"], offer["reward_credits"]
	]
	offer_desc.add_theme_font_size_override("font_size", 16)
	offer_desc.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	vbox.add_child(offer_desc)

	var offer_chain := Label.new()
	offer_chain.text = "%s (Reputation %s) | Stage %d/%d" % [
		offer.get("issuer_faction", "Independent"),
		offer.get("issuer_rep_tier", "Neutral"),
		offer.get("stage", 1),
		offer.get("chain_length", 1)
	]
	offer_chain.add_theme_font_size_override("font_size", 15)
	offer_chain.add_theme_color_override("font_color", Color(0.55, 0.72, 0.95))
	vbox.add_child(offer_chain)

	_add_offer_modifiers(vbox, offer)
	_add_quality_notes(vbox, offer.get("quality_notes", []), Color(0.78, 0.78, 0.95))

	var offer_days_left: int = offer.get("days_left", 0)
	var offer_penalty: int = offer.get("penalty", 0)
	var offer_route_days: int = offer.get("route_days", 0)
	var info_label := Label.new()
	info_label.text = "Deadline: %d days | Travel: %d days | Penalty: %d cr" % [offer_days_left, offer_route_days, offer_penalty]
	info_label.add_theme_font_override("font", UIStyles.FONT_MONO)
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(info_label)

	var accept_btn := _make_action_btn("Accept Quest")
	accept_btn.pressed.connect(_on_accept)
	vbox.add_child(accept_btn)

	_add_loan_panel(vbox)
	_add_bounty_panel(vbox)


func _make_action_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(320, 40)
	UIStyles.style_secondary_button(btn, UIStyles.BODY_FONT_SIZE)
	return btn


func _player_has_goods(q: Dictionary) -> bool:
	for item in GameManager.cargo:
		if item["good_name"] == q["deliver_good"] and item["quantity"] >= q["deliver_qty"]:
			return true
	return false


func _on_accept() -> void:
	if QuestManager.accept_quest(planet_name):
		var q: Dictionary = QuestManager.current_quest
		EventLog.add_entry("Accepted quest (%s %d/%d): deliver %d %s to %s" % [
			q.get("issuer_faction", "Independent"),
			q.get("stage", 1),
			q.get("chain_length", 1),
			q["deliver_qty"],
			q["deliver_good"],
			q["destination"]
		])
	_build_ui()


func _on_deliver() -> void:
	var reward: int = QuestManager.try_complete_quest(planet_name)
	if reward > 0:
		just_completed = not QuestManager.has_active_quest()
		quest_changed.emit()
	_build_ui()


func _add_loan_panel(vbox: VBoxContainer) -> void:
	var sep := HSeparator.new()
	vbox.add_child(sep)

	var debt_label := Label.new()
	debt_label.text = GameManager.get_debt_status_text()
	debt_label.add_theme_font_override("font", UIStyles.FONT_MONO)
	debt_label.add_theme_font_size_override("font_size", 15)
	debt_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vbox.add_child(debt_label)

	if GameManager.has_active_loan():
		var repay_chunk := _make_action_btn("Repay %d cr" % GameManager.get_loan_repay_chunk())
		repay_chunk.pressed.connect(_on_repay_chunk)
		vbox.add_child(repay_chunk)

		var repay_all := _make_action_btn("Repay All (%d cr)" % GameManager.outstanding_debt)
		repay_all.pressed.connect(_on_repay_all)
		vbox.add_child(repay_all)
	else:
		var loan_btn := _make_action_btn("Take Loan (+%d cr)" % GameManager.LOAN_DEFAULT_AMOUNT)
		loan_btn.pressed.connect(_on_take_loan)
		vbox.add_child(loan_btn)


func _on_take_loan() -> void:
	if GameManager.take_loan():
		quest_changed.emit()
	_build_ui()


func _on_repay_chunk() -> void:
	GameManager.repay_loan(GameManager.get_loan_repay_chunk())
	quest_changed.emit()
	_build_ui()


func _on_repay_all() -> void:
	GameManager.repay_loan(-1)
	quest_changed.emit()
	_build_ui()


func _add_bounty_panel(vbox: VBoxContainer) -> void:
	if StandingManager.bounty_amount <= 0:
		return

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var bounty_label := Label.new()
	bounty_label.text = "Bounty: %d cr (%s)" % [StandingManager.bounty_amount, StandingManager.get_bounty_tier()]
	bounty_label.add_theme_font_size_override("font_size", 15)
	bounty_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	vbox.add_child(bounty_label)

	var pay_btn := _make_action_btn("Pay Off Bounty (%d cr)" % StandingManager.bounty_amount)
	pay_btn.pressed.connect(_on_pay_bounty)
	pay_btn.disabled = GameManager.credits < StandingManager.bounty_amount
	vbox.add_child(pay_btn)


func _on_pay_bounty() -> void:
	if StandingManager.pay_off_bounty():
		quest_changed.emit()
	_build_ui()


func _add_quality_summary(vbox: VBoxContainer, quality: Dictionary) -> void:
	var issuer_faction: String = quality.get("issuer_faction", "Independent")
	var summary := Label.new()
	summary.text = "%s | Reputation %s | Loyalty %s" % [
		issuer_faction,
		quality.get("issuer_rep_tier", "Neutral"),
		quality.get("loyalty_tier", "Unknown"),
	]
	summary.add_theme_font_size_override("font_size", 15)
	summary.add_theme_color_override("font_color", Color(0.82, 0.84, 0.6))
	vbox.add_child(summary)


func _add_offer_modifiers(vbox: VBoxContainer, offer: Dictionary) -> void:
	var reward_pct: int = int(round(float(offer.get("offer_reward_modifier", 0.0)) * 100.0))
	var deadline_bonus: int = int(offer.get("offer_deadline_modifier", 0))
	var label := Label.new()
	label.text = "Terms: reward %+d%% | deadline %+d" % [reward_pct, deadline_bonus]
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	vbox.add_child(label)


func _add_quality_notes(vbox: VBoxContainer, notes: Array, color: Color) -> void:
	if notes.is_empty():
		return
	var note_parts: Array[String] = []
	for note in notes:
		note_parts.append(str(note))
	var note_label := Label.new()
	note_label.text = "Notes: " + " | ".join(note_parts)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	note_label.add_theme_font_size_override("font_size", 14)
	note_label.add_theme_color_override("font_color", color)
	vbox.add_child(note_label)
