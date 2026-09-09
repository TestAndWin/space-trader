extends PanelContainer

signal bounty_paid

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	UIStyles.style_panel(self)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var title := Label.new()
	title.text = "BOUNTIES & FINES"
	UIStyles.apply_section_title(title)
	vbox.add_child(title)

	if StandingManager.bounty_amount <= 0:
		var clear_label := Label.new()
		clear_label.text = "No active bounties."
		clear_label.add_theme_font_size_override("font_size", UIStyles.FONT_DETAIL)
		clear_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
		vbox.add_child(clear_label)
		return

	var bounty_label := Label.new()
	bounty_label.text = "Bounty: %d cr (%s)" % [StandingManager.bounty_amount, StandingManager.get_bounty_tier()]
	bounty_label.add_theme_font_size_override("font_size", UIStyles.FONT_DETAIL)
	bounty_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	vbox.add_child(bounty_label)

	var pay_btn := _make_action_btn("Pay Off Bounty (%d cr)" % StandingManager.bounty_amount)
	pay_btn.pressed.connect(_on_pay_bounty)
	pay_btn.disabled = GameManager.credits < StandingManager.bounty_amount
	vbox.add_child(pay_btn)


func _make_action_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(320, 0)
	return btn


func _on_pay_bounty() -> void:
	if StandingManager.pay_off_bounty():
		bounty_paid.emit()
		GameManager.try_trigger_victory()
	_build_ui()
