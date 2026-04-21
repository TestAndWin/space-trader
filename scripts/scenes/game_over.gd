extends Control

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")


func _ready() -> void:
	%TradesLabel.text = "Total Trades: %d" % GameManager.total_trades
	%FlightsLabel.text = "Total Flights: %d" % GameManager.total_flights
	%EncountersLabel.text = "Encounters Won: %d" % GameManager.total_encounters_won
	%CreditsLabel.text = "Final Credits: %d" % GameManager.credits
	%PlanetsLabel.text = "Planets Visited: %d" % GameManager.visited_planets.size()
	%UpgradesLabel.text = "Upgrades Installed: %d" % GameManager.installed_upgrades.size()
	var title_label: Label = $CenterContainer/VBoxContainer/GameOverLabel
	if title_label:
		UIStyles.apply_display_font(title_label)
	UIStyles.apply_mono_font(%TradesLabel)
	UIStyles.apply_mono_font(%FlightsLabel)
	UIStyles.apply_mono_font(%EncountersLabel)
	UIStyles.apply_mono_font(%CreditsLabel)
	UIStyles.apply_mono_font(%PlanetsLabel)
	UIStyles.apply_mono_font(%UpgradesLabel)
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	UIStyles.style_secondary_button(%MainMenuButton, 18)
	BackgroundUtils.add_fullscreen_background(self, "res://assets/sprites/scenes/bg_game_over.png", 0.5, 1)


func _on_main_menu_pressed() -> void:
	SaveManager.delete_save()
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
