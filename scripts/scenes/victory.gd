extends Control


func _ready() -> void:
	%TradesLabel.text = "Total Trades: %d" % GameManager.total_trades
	%FlightsLabel.text = "Total Flights: %d" % GameManager.total_flights
	%EncountersLabel.text = "Encounters Won: %d" % GameManager.total_encounters_won
	%CreditsLabel.text = "Final Credits: %d" % GameManager.credits
	%PlanetsLabel.text = "Planets Visited: %d / %d" % [GameManager.visited_planets.size(), GameManager.WIN_PLANETS]
	%UpgradesLabel.text = "Upgrades Installed: %d" % GameManager.installed_upgrades.size()
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	_style_main_menu_button(%MainMenuButton)
	_add_cockpit_frame()


func _style_main_menu_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.06, 0.14, 0.85)
	normal.border_color = Color(0.0, 0.65, 0.95, 0.85)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.shadow_color = Color(0.0, 0.45, 0.9, 0.25)
	normal.shadow_size = 6
	var hover := normal.duplicate()
	hover.bg_color = Color(0.03, 0.10, 0.22, 0.9)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.01, 0.04, 0.10, 0.9)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.8, 0.98, 1.0))
	btn.add_theme_font_size_override("font_size", 18)


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _add_cockpit_frame() -> void:
	var frame := Control.new()
	frame.name = "CockpitFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_script(load("res://scripts/components/cockpit_frame.gd"))
	add_child(frame)
