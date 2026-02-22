extends Control

var card_display_scene: PackedScene = preload("res://scenes/components/card_display.tscn")
var card_selected: bool = false


func _ready() -> void:
	var result := GameManager.battle_result
	var destination := GameManager.travel_destination

	match result:
		"won":
			%ResultTitle.text = "Victory!"
			%ResultTitle.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			var earned: int = 0
			if GameManager.current_encounter:
				earned = int(round(GameManager.current_encounter.reward_credits * EventManager.get_reward_modifier()))
			%ResultDescription.text = "+%d credits! (Total: %d cr)\nArriving at %s." % [earned, GameManager.credits, destination]
			GameManager.current_planet = destination
			if destination not in GameManager.visited_planets:
				GameManager.visited_planets.append(destination)
			# Only offer card rewards for harder fights or 40% random chance
			var enc_diff: int = 0
			if GameManager.current_encounter:
				enc_diff = GameManager.current_encounter.difficulty
			if enc_diff >= 2 or randf() < 0.4:
				_setup_card_rewards()
				%CardRewardPanel.visible = true
				%ContinueButton.visible = false
			else:
				%CardRewardPanel.visible = false
				%ContinueButton.visible = true
		"lost":
			%ResultTitle.text = "Defeated!"
			%ResultTitle.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			%ResultDescription.text = "You crash-landed at %s.\nCredits remaining: %d cr" % [destination, GameManager.credits]
			var cargo_text := GameManager.last_cargo_lost_text
			if cargo_text != "":
				%ResultDescription.text += "\n" + cargo_text
			GameManager.current_planet = destination
			if destination not in GameManager.visited_planets:
				GameManager.visited_planets.append(destination)
			%CardRewardPanel.visible = false
			%ContinueButton.visible = true
		"fled":
			%ResultTitle.text = "Escaped!"
			%ResultTitle.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			%ResultDescription.text = "You fled back to %s. -150 credits.\nCredits remaining: %d cr" % [GameManager.travel_origin, GameManager.credits]
			GameManager.current_planet = GameManager.travel_origin
			%CardRewardPanel.visible = false
			%ContinueButton.visible = true
		_:
			%ResultTitle.text = "Battle Over"
			%ResultDescription.text = ""
			%CardRewardPanel.visible = false
			%ContinueButton.visible = true

	%ContinueButton.pressed.connect(_on_continue_pressed)
	%SkipButton.pressed.connect(_on_skip_pressed)


func _setup_card_rewards() -> void:
	var all_cards: Array = ResourceRegistry.load_all(ResourceRegistry.CARDS)

	if all_cards.is_empty():
		%CardRewardPanel.visible = false
		%ContinueButton.visible = true
		return

	# Prefer uncommon/rare cards (rarity 1 or 2)
	var preferred: Array = []
	var common: Array = []
	for card in all_cards:
		if card.rarity >= 1:
			preferred.append(card)
		else:
			common.append(card)

	# Pick 3 cards, preferring uncommon/rare
	preferred.shuffle()
	common.shuffle()
	var pool := preferred + common
	var reward_cards: Array = []
	for i in mini(3, pool.size()):
		reward_cards.append(pool[i])

	for card in reward_cards:
		var display := card_display_scene.instantiate()
		%CardChoices.add_child(display)
		display.setup(card, true, "Choose")
		display.card_played.connect(_on_reward_card_selected)


func _on_reward_card_selected(card_data: Resource) -> void:
	if card_selected:
		return
	card_selected = true
	GameManager.deck.append(card_data)
	%CardRewardPanel.visible = false
	%ContinueButton.visible = true


func _on_skip_pressed() -> void:
	if card_selected:
		return
	card_selected = true
	%CardRewardPanel.visible = false
	%ContinueButton.visible = true


func _on_continue_pressed() -> void:
	GameManager.current_encounter = null
	GameManager.battle_result = ""
	get_tree().change_scene_to_file("res://scenes/planet_screen.tscn")
