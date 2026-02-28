extends Control

var card_display_scene: PackedScene = preload("res://scenes/components/card_display.tscn")
var card_selected: bool = false
var reward_chosen: bool = false


func _ready() -> void:
	var result := GameManager.battle_result
	var destination := GameManager.travel_destination

	match result:
		"won":
			%ResultTitle.text = "Victory!"
			%ResultTitle.add_theme_color_override("font_color", Color(0.0, 0.85, 0.45))
			GameManager.current_planet = destination
			if destination not in GameManager.visited_planets:
				GameManager.visited_planets.append(destination)

			# Roll reward type: 60% credits+card, 25% upgrade, 15% crew
			var roll: float = randf()
			if roll < 0.15:
				_setup_crew_reward(destination)
			elif roll < 0.40:
				_setup_upgrade_reward(destination)
			else:
				_setup_credits_card_reward(destination)
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
			%RewardPanel.visible = false
			%ContinueButton.visible = true
		"fled":
			%ResultTitle.text = "Escaped!"
			%ResultTitle.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			%ResultDescription.text = "You fled back to %s. -150 credits.\nCredits remaining: %d cr" % [GameManager.travel_origin, GameManager.credits]
			GameManager.current_planet = GameManager.travel_origin
			%CardRewardPanel.visible = false
			%RewardPanel.visible = false
			%ContinueButton.visible = true
		_:
			%ResultTitle.text = "Battle Over"
			%ResultDescription.text = ""
			%CardRewardPanel.visible = false
			%RewardPanel.visible = false
			%ContinueButton.visible = true

	%ContinueButton.pressed.connect(_on_continue_pressed)
	%SkipButton.pressed.connect(_on_skip_pressed)
	_style_buttons()
	_add_cockpit_frame()


# ── Credits + Card reward (original behavior) ───────────────────────────────

func _setup_credits_card_reward(destination: String) -> void:
	var earned: int = 0
	if GameManager.current_encounter:
		earned = int(round(GameManager.current_encounter.reward_credits * EventManager.get_reward_modifier()))
		GameManager.add_credits(earned)
	%ResultDescription.text = "+%d credits! (Total: %d cr)\nArriving at %s." % [earned, GameManager.credits, destination]
	%RewardPanel.visible = false

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


# ── Upgrade reward ───────────────────────────────────────────────────────────

func _setup_upgrade_reward(destination: String) -> void:
	var earned: int = 0
	if GameManager.current_encounter:
		earned = int(round(GameManager.current_encounter.reward_credits * EventManager.get_reward_modifier()))
		GameManager.add_credits(earned)
	%ResultDescription.text = "+%d credits! (Total: %d cr)\nArriving at %s." % [earned, GameManager.credits, destination]
	%CardRewardPanel.visible = false
	%ContinueButton.visible = false

	var combat_upgrades: Array = ResourceRegistry.load_all(ResourceRegistry.COMBAT_UPGRADES)
	combat_upgrades.shuffle()

	# Find one that's not already installed
	var chosen: Resource = null
	var all_installed: bool = true
	for upg in combat_upgrades:
		if upg.upgrade_name not in GameManager.installed_upgrades:
			chosen = upg
			all_installed = false
			break

	if all_installed and combat_upgrades.size() > 0:
		# Bad luck — show what it would have been
		chosen = combat_upgrades[0]

	if not chosen:
		# Fallback: no upgrades available at all
		%RewardPanel.visible = false
		%ContinueButton.visible = true
		return

	var already_owned: bool = chosen.upgrade_name in GameManager.installed_upgrades
	_build_reward_panel(
		"Ship Upgrade Found!",
		_get_upgrade_icon(chosen),
		chosen.upgrade_name,
		chosen.description,
		"Install" if not already_owned else "",
		already_owned,
		"Already installed" if already_owned else ""
	)

	if not already_owned:
		%AcceptButton.pressed.connect(func() -> void:
			if reward_chosen:
				return
			reward_chosen = true
			GameManager.apply_upgrade(chosen)
			%RewardPanel.visible = false
			%ContinueButton.visible = true
		)


func _get_upgrade_icon(upgrade: Resource) -> String:
	match upgrade.upgrade_name:
		"Armor Plating":
			return "🛡"
		"Combat Scanner":
			return "📡"
		"Shield Capacitor":
			return "⚡"
		_:
			return "🔧"


# ── Crew reward ──────────────────────────────────────────────────────────────

func _setup_crew_reward(destination: String) -> void:
	var earned: int = 0
	if GameManager.current_encounter:
		earned = int(round(GameManager.current_encounter.reward_credits * EventManager.get_reward_modifier()))
		GameManager.add_credits(earned)
	%ResultDescription.text = "+%d credits! (Total: %d cr)\nArriving at %s." % [earned, GameManager.credits, destination]
	%CardRewardPanel.visible = false
	%ContinueButton.visible = false

	var all_crew: Array = ResourceRegistry.load_all(ResourceRegistry.CREW)
	all_crew.shuffle()

	var chosen: Resource = null
	for c in all_crew:
		if c.resource_path not in GameManager.crew:
			chosen = c
			break

	if not chosen:
		# All crew already recruited — pick random to show
		if all_crew.size() > 0:
			chosen = all_crew[0]
		else:
			%RewardPanel.visible = false
			%ContinueButton.visible = true
			return

	var already_recruited: bool = chosen.resource_path in GameManager.crew
	var crew_full: bool = GameManager.crew.size() >= GameManager.MAX_CREW

	var blocked: bool = already_recruited or crew_full
	var block_reason: String = ""
	if already_recruited:
		block_reason = "Already recruited"
	elif crew_full:
		block_reason = "Crew full (%d/%d)" % [GameManager.crew.size(), GameManager.MAX_CREW]

	_build_reward_panel(
		"Crew Member Rescued!",
		"👤",
		"%s — %s" % [chosen.crew_name, chosen.title],
		chosen.description,
		"Recruit" if not blocked else "",
		blocked,
		block_reason
	)

	if not blocked:
		%AcceptButton.pressed.connect(func() -> void:
			if reward_chosen:
				return
			reward_chosen = true
			GameManager.crew.append(chosen.resource_path)
			GameManager.crew_changed.emit()
			%RewardPanel.visible = false
			%ContinueButton.visible = true
		)


# ── Reward panel builder ─────────────────────────────────────────────────────

func _build_reward_panel(title_text: String, icon: String, item_name: String,
		desc: String, accept_label: String, is_blocked: bool, block_text: String) -> void:
	%RewardTitle.text = title_text
	%RewardIcon.text = icon
	%RewardName.text = item_name
	%RewardDescription.text = desc

	if is_blocked:
		%BlockedLabel.text = block_text
		%BlockedLabel.visible = true
		%AcceptButton.visible = false
	else:
		%BlockedLabel.visible = false
		%AcceptButton.text = accept_label
		%AcceptButton.visible = true

	%RewardSkipButton.pressed.connect(func() -> void:
		if reward_chosen:
			return
		reward_chosen = true
		%RewardPanel.visible = false
		%ContinueButton.visible = true
	)

	%RewardPanel.visible = true


# ── Continue ─────────────────────────────────────────────────────────────────

func _style_buttons() -> void:
	for btn: Button in [%ContinueButton, %SkipButton, %AcceptButton, %RewardSkipButton]:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.02, 0.06, 0.14, 0.85)
		normal.border_color = Color(0.0, 0.45, 0.75, 0.7)
		normal.set_border_width_all(2)
		normal.set_corner_radius_all(6)
		normal.content_margin_left = 16
		normal.content_margin_right = 16
		normal.content_margin_top = 8
		normal.content_margin_bottom = 8
		var hover := normal.duplicate()
		hover.bg_color = Color(0.03, 0.10, 0.22, 0.9)
		hover.border_color = Color(0.0, 0.65, 0.95, 0.85)
		var pressed := normal.duplicate()
		pressed.bg_color = Color(0.01, 0.04, 0.10, 0.9)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.8, 0.98, 1.0))


func _on_continue_pressed() -> void:
	GameManager.current_encounter = null
	GameManager.battle_result = ""
	GameManager.change_scene("res://scenes/planet_screen.tscn")


func _add_cockpit_frame() -> void:
	var frame := Control.new()
	frame.name = "CockpitFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_script(load("res://scripts/components/cockpit_frame.gd"))
	add_child(frame)
