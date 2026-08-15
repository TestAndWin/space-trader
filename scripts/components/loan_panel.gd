extends PanelContainer

signal loan_changed

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
	title.text = "LOANS & DEBT"
	UIStyles.apply_section_title(title)
	vbox.add_child(title)

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


func _make_action_btn(text: String) -> ActionButton:
	var btn := ActionButton.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(320, 0)
	return btn


func _on_take_loan() -> void:
	if GameManager.take_loan():
		loan_changed.emit()
	_build_ui()


func _on_repay_chunk() -> void:
	GameManager.repay_loan(GameManager.get_loan_repay_chunk())
	loan_changed.emit()
	_build_ui()


func _on_repay_all() -> void:
	GameManager.repay_loan(-1)
	loan_changed.emit()
	_build_ui()
