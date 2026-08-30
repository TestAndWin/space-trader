extends Control

signal event_resolved()

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

var _description_label: Label
var _vbox: VBoxContainer

func _ready() -> void:
	_build_ui()

func try_trigger(planet_name: String) -> bool:
	if not PirateLordManager.active_presence_planets.has(planet_name):
		return false
	if randf() > 0.4:
		return false

	# Setup event based on random type
	_setup_event(randi_range(0, 3))
	return true

func _build_ui() -> void:
	var scaffold := UIStyles.create_event_modal_scaffold(self, 400.0, Color(0.9, 0.2, 0.2))
	_vbox = scaffold["vbox"]
	var title: Label = scaffold["title_label"]
	title.text = "PIRATE INCURSION"
	_description_label = scaffold["description_label"]
	_description_label.custom_minimum_size = Vector2(360, 0)

func _setup_event(event_type: int) -> void:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	_vbox.add_child(hbox)

	match event_type:
		0: # Tribute
			_description_label.text = "Crimson Jack's fleet is blockading this planet. They demand a tribute of 200 credits to let you land safely."
			var pay_btn := _create_button("Pay 200 cr")
			if GameManager.credits < 200:
				pay_btn.disabled = true
			pay_btn.pressed.connect(func():
				GameManager.remove_credits(200)
				EventLog.add_entry("Paid 200cr pirate tribute.")
				_close()
			)
			hbox.add_child(pay_btn)

			var refuse_btn := _create_button("Refuse (Take 15 Hull Dmg)")
			refuse_btn.pressed.connect(func():
				GameManager.current_hull = maxi(0, GameManager.current_hull - 15)
				EventLog.add_entry("Refused pirate tribute, took 15 damage.")
				if GameManager.current_hull == 0:
					GameManager.change_scene("res://scenes/game_over.tscn")
				else:
					_close()
			)
			hbox.add_child(refuse_btn)

		1: # Sabotage
			_description_label.text = "Pirate saboteurs have damaged your ship systems upon landing!"
			GameManager.current_hull = maxi(0, GameManager.current_hull - 20)
			var ok_btn := _create_button("Brace for impact")
			ok_btn.pressed.connect(func():
				EventLog.add_entry("Pirate sabotage caused 20 damage.")
				if GameManager.current_hull == 0:
					GameManager.change_scene("res://scenes/game_over.tscn")
				else:
					_close()
			)
			hbox.add_child(ok_btn)

		2: # Kidnapping (if unwounded crew exists)
			var unwounded: Array = []
			for c: String in GameManager.crew:
				if c not in GameManager.wounded_crew:
					unwounded.append(c)
			if unwounded.size() > 0:
				var target: String = unwounded.pick_random()
				var res: Resource = load(target)
				_description_label.text = "Pirates ambushed your crew on the docks! %s has been severely wounded." % res.crew_name
				GameManager.wounded_crew[target] = randi_range(4, 7)
				var ok_btn := _create_button("Retreat")
				ok_btn.pressed.connect(func():
					EventLog.add_entry("%s wounded by pirates." % res.crew_name)
					_close()
				)
				hbox.add_child(ok_btn)
			else:
				# No unwounded crew: fall back to sabotage. Drop the row built for this
				# branch first — otherwise it stays behind as an empty child and adds a
				# stray separation gap above the real buttons.
				hbox.queue_free()
				_setup_event(0)
				return
		3: # No Landing
			_description_label.text = "Pirate blockade is too dense. You cannot dock here. You must leave immediately!"
			var leave_btn := _create_button("Flee to Orbit")
			leave_btn.pressed.connect(func():
				EventLog.add_entry("Forced to leave planet due to pirate blockade.")
				_close()
				GameManager.change_scene("res://scenes/galaxy_map.tscn")
			)
			hbox.add_child(leave_btn)

func _create_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 36)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.7, 0.2, 0.2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.85, 0.3, 0.3)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)
	return btn

func _close() -> void:
	event_resolved.emit()
	queue_free()
