extends Control

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")


func _ready() -> void:
	# Set up first: if any of the stat labels below were to fail, _ready() would
	# abort and the screen would render without its background.
	BackgroundUtils.add_fullscreen_background(self, "res://assets/sprites/scenes/bg_victory.png", 0.5, 1)
	AchievementManager.unlock("winner")
	%TradesLabel.text = "Total Trades: %d" % GameManager.total_trades
	%TravelDaysLabel.text = "Travel Days: %d" % GameManager.total_travel_days
	%EncountersLabel.text = "Encounters Won: %d" % GameManager.total_encounters_won
	%CreditsLabel.text = "Final Credits: %d" % GameManager.credits
	%PlanetsLabel.text = "Planets Visited: %d / %d" % [GameManager.visited_planets.size(), GameManager.WIN_PLANETS]
	%UpgradesLabel.text = "Upgrades Installed: %d" % GameManager.installed_upgrades.size()
	var title_label: Label = $CenterContainer/VBoxContainer/VictoryLabel
	if title_label:
		UIStyles.apply_display_font(title_label)
	for stat_label: Label in [%TradesLabel, %TravelDaysLabel, %EncountersLabel,
			%CreditsLabel, %PlanetsLabel, %UpgradesLabel]:
		UIStyles.apply_mono_font(stat_label)
	%ContinueButton.pressed.connect(_on_continue_pressed)
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	
	# Font and height stay at the standard button metrics -- the display font is
	# for the title above, not for buttons. Only the accent colors are custom.
	for btn: Button in [%ContinueButton, %MainMenuButton]:
		btn.custom_minimum_size.y = UIStyles.ACTION_BTN_MIN_HEIGHT
	UIStyles.style_accent_button(%ContinueButton, Color(0.2, 0.6, 0.2))
	UIStyles.style_accent_button(%MainMenuButton, Color(0.2, 0.3, 0.5))


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/planet_screen.tscn")


func _on_main_menu_pressed() -> void:
	_show_confirmation_dialog()


func _show_confirmation_dialog() -> void:
	var modal: Dictionary = UIStyles.create_confirm_modal(
		self, 0.8, Color(0.05, 0.05, 0.08, 0.95), Color(0.8, 0.2, 0.2, 0.8), 20, Vector2.ZERO
	)
	var overlay: ColorRect = modal["overlay"]
	overlay.z_index = 100
	var vbox: VBoxContainer = modal["vbox"]

	var title := Label.new()
	title.text = "END GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIStyles.FONT_HEADING)
	title.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.text = "Are you sure you want to end your run?\nThis will delete your save and return to the main menu."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)
	
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)
	
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	UIStyles.style_accent_button(cancel_btn, Color(0.5, 0.15, 0.1), UIStyles.FONT_BODY)
	cancel_btn.pressed.connect(overlay.queue_free)
	btn_row.add_child(cancel_btn)
	
	var confirm_btn := Button.new()
	confirm_btn.text = "End Game"
	confirm_btn.custom_minimum_size = Vector2(120, 40)
	UIStyles.style_accent_button(confirm_btn, Color(0.6, 0.2, 0.2))
	confirm_btn.pressed.connect(func():
		GameManager.end_run_to_main_menu()
	)
	btn_row.add_child(confirm_btn)
