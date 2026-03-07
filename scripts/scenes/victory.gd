extends Control

const CockpitFrame := preload("res://scripts/components/cockpit_frame.gd")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")


func _ready() -> void:
	%TradesLabel.text = "Total Trades: %d" % GameManager.total_trades
	%FlightsLabel.text = "Total Flights: %d" % GameManager.total_flights
	%EncountersLabel.text = "Encounters Won: %d" % GameManager.total_encounters_won
	%CreditsLabel.text = "Final Credits: %d" % GameManager.credits
	%PlanetsLabel.text = "Planets Visited: %d / %d" % [GameManager.visited_planets.size(), GameManager.WIN_PLANETS]
	%UpgradesLabel.text = "Upgrades Installed: %d" % GameManager.installed_upgrades.size()
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	UIStyles.style_secondary_button(%MainMenuButton, 18)
	_add_victory_background()
	CockpitFrame.add_to(self)


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _add_victory_background() -> void:
	var path: String = "res://assets/sprites/bg_victory.png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex:
		var bg := TextureRect.new()
		bg.texture = tex
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		move_child(bg, 1)  # After Background ColorRect
		var dim := ColorRect.new()
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.0, 0.0, 0.0, 0.5)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		move_child(dim, 2)
