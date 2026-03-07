extends Control

const CockpitFrame := preload("res://scripts/components/cockpit_frame.gd")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")


func _ready() -> void:
	%TradesLabel.text = "Total Trades: %d" % GameManager.total_trades
	%FlightsLabel.text = "Total Flights: %d" % GameManager.total_flights
	%EncountersLabel.text = "Encounters Won: %d" % GameManager.total_encounters_won
	%CreditsLabel.text = "Final Credits: %d" % GameManager.credits
	%PlanetsLabel.text = "Planets Visited: %d / %d" % [GameManager.visited_planets.size(), GameManager.WIN_PLANETS]
	%UpgradesLabel.text = "Upgrades Installed: %d" % GameManager.installed_upgrades.size()
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	UIStyles.style_secondary_button(%MainMenuButton, 18)
	BackgroundUtils.add_fullscreen_background(self, "res://assets/sprites/bg_victory.png", 0.5, 1)
	CockpitFrame.add_to(self)


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

