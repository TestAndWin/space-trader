extends Control

const CardDisplayScene: PackedScene = preload("res://scenes/components/card_display.tscn")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")
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
			AchievementManager.check_planets(GameManager.visited_planets)

			# Check if this was a rival encounter
			var is_rival: bool = GameManager.current_encounter != null and GameManager.current_encounter.is_rival
			if is_rival:
				# Rival always gives upgrade reward + possible phase 4 bonus
				if GameManager.current_encounter.rival_phase >= RivalManager.FINAL_PHASE:
					var rival_bonus: int = 500
					GameManager.add_credits(rival_bonus)
					EventLog.add_entry("Rival vanquished! Bonus: +%d cr" % rival_bonus)
				_setup_upgrade_reward(destination)
				return

			# Normal roll reward type: 60% credits+card, 25% upgrade, 15% crew
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
			AchievementManager.check_planets(GameManager.visited_planets)
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

	UIStyles.apply_display_font(%ResultTitle)
	UIStyles.apply_display_font(%RewardTitle)
	%ContinueButton.pressed.connect(_on_continue_pressed)
	%SkipButton.pressed.connect(_on_skip_pressed)
	_style_buttons()
	BackgroundUtils.add_fullscreen_background(self, "res://assets/sprites/scenes/bg_battle_result.png", 0.5, 1)


# ── Credits + Card reward (original behavior) ───────────────────────────────

func _award_battle_credits() -> int:
	var earned: int = 0
	if GameManager.current_encounter:
		earned = int(round(GameManager.current_encounter.reward_credits * EventManager.get_reward_modifier()))
		GameManager.add_credits(earned)
	# Crew medic bonus: heal hull after combat win
	if GameManager.has_crew_bonus(CrewData.CrewBonus.COMBAT_HEAL):
		var heal: int = int(GameManager.get_crew_bonus_value(CrewData.CrewBonus.COMBAT_HEAL))
		GameManager.current_hull = mini(GameManager.current_hull + heal, GameManager.max_hull)
	return earned


func _setup_credits_card_reward(destination: String) -> void:
	var earned: int = _award_battle_credits()
	%ResultDescription.text = "+%d credits!\nArriving at %s." % [earned, destination]
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
		var display := CardDisplayScene.instantiate()
		%CardChoices.add_child(display)
		display.setup(card, true, "Choose")
		display.card_played.connect(_on_reward_card_selected)


func _on_reward_card_selected(card_data: Resource) -> void:
	if card_selected:
		return
	card_selected = true
	GameManager.deck.append(card_data)
	AchievementManager.check_deck(GameManager.deck.size())
	_on_continue_pressed()


func _on_skip_pressed() -> void:
	if card_selected:
		return
	card_selected = true
	_on_continue_pressed()


# ── Upgrade reward ───────────────────────────────────────────────────────────

func _setup_upgrade_reward(destination: String) -> void:
	var earned: int = _award_battle_credits()
	%ResultDescription.text = "+%d credits!\nArriving at %s." % [earned, destination]
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
			_on_continue_pressed()
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
	var earned: int = _award_battle_credits()
	%ResultDescription.text = "+%d credits!\nArriving at %s." % [earned, destination]
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
			_on_continue_pressed()
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

	if not %RewardSkipButton.pressed.is_connected(_on_reward_skip_pressed):
		%RewardSkipButton.pressed.connect(_on_reward_skip_pressed)

	%RewardPanel.visible = true


func _on_reward_skip_pressed() -> void:
	if reward_chosen:
		return
	reward_chosen = true
	_on_continue_pressed()


# ── Continue ─────────────────────────────────────────────────────────────────

func _style_buttons() -> void:
	for btn: Button in [%ContinueButton, %SkipButton, %AcceptButton, %RewardSkipButton]:
		UIStyles.style_secondary_button(btn)


func _on_continue_pressed() -> void:
	GameManager.current_encounter = null
	GameManager.battle_result = ""
	GameManager.change_scene("res://scenes/planet_screen.tscn")
