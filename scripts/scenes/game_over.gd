extends Control


func _ready() -> void:
	%TradesLabel.text = "Total Trades: %d" % GameManager.total_trades
	%FlightsLabel.text = "Total Flights: %d" % GameManager.total_flights
	%EncountersLabel.text = "Encounters Won: %d" % GameManager.total_encounters_won
	%CreditsLabel.text = "Final Credits: %d" % GameManager.credits
	%PlanetsLabel.text = "Planets Visited: %d" % GameManager.visited_planets.size()
	%UpgradesLabel.text = "Upgrades Installed: %d" % GameManager.installed_upgrades.size()
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)


func _on_main_menu_pressed() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
