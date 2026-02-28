extends PanelContainer

signal quest_changed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const ACCENT_GREEN := Color(0.0, 0.75, 0.35)

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
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	var title := Label.new()
	title.text = "QUEST"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vbox.add_child(title)

	# Just completed
	if just_completed:
		var done_label := Label.new()
		done_label.text = "Quest completed!"
		done_label.add_theme_font_size_override("font_size", 13)
		done_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		vbox.add_child(done_label)
		var next_btn := Button.new()
		next_btn.text = "New Quest"
		next_btn.pressed.connect(func(): just_completed = false; _build_ui())
		UIStyles.style_accent_button(next_btn, ACCENT_GREEN)
		vbox.add_child(next_btn)
		return

	# Active quest
	if QuestManager.has_active_quest():
		var q: Dictionary = QuestManager.current_quest
		var desc := Label.new()
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.text = "Deliver %d %s to %s\nReward: %d cr" % [q["deliver_qty"], q["deliver_good"], q["destination"], q["reward_credits"]]
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.4, 0.85, 0.65))
		vbox.add_child(desc)

		var turns: int = q.get("turns_left", 0)
		var penalty: int = q.get("penalty", 0)
		var deadline_label := Label.new()
		deadline_label.add_theme_font_size_override("font_size", 11)
		if turns <= 1:
			deadline_label.text = "LAST CHANCE! Penalty: %d cr" % penalty
			deadline_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			deadline_label.text = "%d trips left | Penalty: %d cr" % [turns, penalty]
			deadline_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
		vbox.add_child(deadline_label)

		# Check if we can deliver here
		if q["destination"] == planet_name and _player_has_goods(q):
			var deliver_btn := Button.new()
			deliver_btn.text = "Deliver (%d %s)" % [q["deliver_qty"], q["deliver_good"]]
			deliver_btn.pressed.connect(_on_deliver)
			UIStyles.style_accent_button(deliver_btn, ACCENT_GREEN)
			vbox.add_child(deliver_btn)
		elif q["destination"] == planet_name:
			var missing_label := Label.new()
			missing_label.text = "Need %d %s to deliver" % [q["deliver_qty"], q["deliver_good"]]
			missing_label.add_theme_font_size_override("font_size", 11)
			missing_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.3))
			vbox.add_child(missing_label)
		return

	# No active quest — show local offer
	var offer: Dictionary = QuestManager.get_offer_for_planet(planet_name)
	if offer.is_empty():
		var none_label := Label.new()
		none_label.text = "No quests available"
		none_label.add_theme_font_size_override("font_size", 12)
		none_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		vbox.add_child(none_label)
		return

	var offer_desc := Label.new()
	offer_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	offer_desc.text = "Deliver %d %s to %s\nReward: %d cr" % [offer["deliver_qty"], offer["deliver_good"], offer["destination"], offer["reward_credits"]]
	offer_desc.add_theme_font_size_override("font_size", 12)
	offer_desc.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	vbox.add_child(offer_desc)

	var offer_turns: int = offer.get("turns_left", 0)
	var offer_penalty: int = offer.get("penalty", 0)
	var info_label := Label.new()
	info_label.text = "Deadline: %d trips | Penalty: %d cr" % [offer_turns, offer_penalty]
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(info_label)

	var accept_btn := Button.new()
	accept_btn.text = "Accept Quest"
	accept_btn.pressed.connect(_on_accept)
	UIStyles.style_accent_button(accept_btn, ACCENT_GREEN)
	vbox.add_child(accept_btn)


func _player_has_goods(q: Dictionary) -> bool:
	for item in GameManager.cargo:
		if item["good_name"] == q["deliver_good"] and item["quantity"] >= q["deliver_qty"]:
			return true
	return false


func _on_accept() -> void:
	if QuestManager.accept_quest(planet_name):
		var q: Dictionary = QuestManager.current_quest
		EventLog.add_entry("Accepted quest: deliver %d %s to %s" % [q["deliver_qty"], q["deliver_good"], q["destination"]])
	_build_ui()


func _on_deliver() -> void:
	var reward: int = QuestManager.try_complete_quest(planet_name)
	if reward > 0:
		just_completed = true
		quest_changed.emit()
	_build_ui()
