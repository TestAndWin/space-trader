extends Control

const CockpitFrame := preload("res://scripts/components/cockpit_frame.gd")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")


func _ready() -> void:
	%TradesLabel.text = "Total Trades: %d" % GameManager.total_trades
	%FlightsLabel.text = "Total Flights: %d" % GameManager.total_flights
	%EncountersLabel.text = "Encounters Won: %d" % GameManager.total_encounters_won
	%CreditsLabel.text = "Final Credits: %d" % GameManager.credits
	%PlanetsLabel.text = "Planets Visited: %d" % GameManager.visited_planets.size()
	%UpgradesLabel.text = "Upgrades Installed: %d" % GameManager.installed_upgrades.size()
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	UIStyles.style_secondary_button(%MainMenuButton, 18)
	CockpitFrame.add_to(self)


func _on_main_menu_pressed() -> void:
	SaveManager.delete_save()
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
