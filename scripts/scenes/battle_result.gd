extends Control

const CardDisplayScene: PackedScene = preload("res://scenes/components/card_display.tscn")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")
const TravelEventScene: PackedScene = preload("res://scenes/components/travel_event.tscn")

## Icon per combat-upgrade reward; anything unlisted falls back to the wrench.
const UPGRADE_ICONS: Dictionary = {
	"Armor Plating": "🛡",
	"Combat Scanner": "📡",
	"Shield Capacitor": "⚡",
}

var card_selected: bool = false
var reward_chosen: bool = false


func _ready() -> void:
	# Set up first — see victory.gd: a failure below must not take the
	# background down with it.
	BackgroundUtils.add_fullscreen_background(self, "res://assets/sprites/scenes/bg_battle_result.png", 0.5, 1)
	var result := GameManager.battle_result
	var destination := GameManager.travel_destination

	match result:
		"won", "boarded":
			%ResultTitle.text = "Victory!"
			%ResultTitle.add_theme_color_override("font_color", UIStyles.POSITIVE)
			GameManager.complete_travel_arrival(destination)

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

			if result == "boarded":
				if GameManager.boarding_special_loot == "crew":
					_setup_crew_reward(destination)
				elif GameManager.boarding_special_loot == "upgrade":
					_setup_upgrade_reward(destination)
				elif GameManager.boarding_special_loot == "card":
					# Only show card selection, no credits
					%ResultDescription.text = "You salvaged an access card from the wreck.\nArriving at %s." % destination
					if GameManager.extra_battle_message != "":
						%ResultDescription.text += "\n" + GameManager.extra_battle_message
					%RewardPanel.visible = false
					_setup_card_rewards()
					%CardRewardPanel.visible = true
					%ContinueButton.visible = false
				else:
					# Fallback if no special loot was found
					_setup_credits_only_reward(destination)
			else:
				# Normal destruction (won without boarding) -> just credits
				_setup_credits_only_reward(destination)
		"lost":
			%ResultTitle.text = "Defeated!"
			%ResultTitle.add_theme_color_override("font_color", UIStyles.NEGATIVE)
			var cargo_text := GameManager.last_cargo_lost_text
			if destination == GameManager.CRIMSON_BASE_NAME and not GameManager.victory_triggered:
				%ResultDescription.text = "You were defeated by Crimson Jack!\nYou barely escaped back to %s.\nCredits remaining: %d cr" % [GameManager.travel_origin, GameManager.credits]
				GameManager.complete_travel_arrival(GameManager.travel_origin)
			else:
				%ResultDescription.text = "You crash-landed at %s.\nCredits remaining: %d cr" % [destination, GameManager.credits]
				GameManager.complete_travel_arrival(destination)
			if cargo_text != "":
				%ResultDescription.text += "\n" + cargo_text
			_show_continue_only()
		"fled":
			%ResultTitle.text = "Escaped!"
			%ResultTitle.add_theme_color_override("font_color", UIStyles.CAUTION)
			%ResultDescription.text = "You fled back to %s. -150 credits.\nCredits remaining: %d cr" % [GameManager.travel_origin, GameManager.credits]
			GameManager.complete_travel_arrival(GameManager.travel_origin, false)
			_show_continue_only()
		"lost_backup":
			%ResultTitle.text = "Ship Destroyed!"
			%ResultTitle.add_theme_color_override("font_color", UIStyles.NEGATIVE)
			%ResultDescription.text = "Your ship was destroyed! You managed to escape in a pod and retrieve your backup ship. However, all cargo and crew on board were lost.\n\nYou have returned to %s." % GameManager.travel_origin
			GameManager.complete_travel_arrival(GameManager.travel_origin, false)
			_show_continue_only()
		"boarding_failed":
			%ResultTitle.text = "Boarding Failed!"
			%ResultTitle.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
			%ResultDescription.text = "You barely escaped the exploding ship!\nYour hull took 5 damage.\nArriving at %s." % destination
			GameManager.complete_travel_arrival(destination)
			_show_continue_only()
		_:
			%ResultTitle.text = "Battle Over"
			%ResultDescription.text = ""
			_show_continue_only()

	UIStyles.apply_display_font(%ResultTitle)
	UIStyles.apply_display_font(%RewardTitle)
	%ContinueButton.pressed.connect(_on_continue_pressed)
	%SkipButton.pressed.connect(_on_skip_pressed)
	_style_buttons()


# ── Credits + Card reward (original behavior) ───────────────────────────────

## Hides both reward panels and offers only "Continue".
func _show_continue_only() -> void:
	%CardRewardPanel.visible = false
	%RewardPanel.visible = false
	%ContinueButton.visible = true


## Awards the battle credits and writes the standard arrival description.
## `extra_separator` exists only because the crew reward has always put a
## single newline in front of the extra battle message where the others put two.
func _describe_battle_reward(destination: String, extra_separator: String = "\n\n") -> void:
	var earned: int = _award_battle_credits()
	var msg: String = "Combat Reward: %d cr" % earned
	if GameManager.extra_battle_message != "":
		msg += extra_separator + GameManager.extra_battle_message
	msg += "\n\nArriving at %s." % destination
	%ResultDescription.text = msg


func _award_battle_credits() -> int:
	var earned: int = 0
	if GameManager.current_encounter:
		earned = int(round(GameManager.current_encounter.reward_credits * EventManager.get_reward_modifier()))
		GameManager.add_credits(earned)
		EventLog.add_entry("Combat reward: %d cr" % earned)
	# Crew medic bonus: heal hull after combat win
	if GameManager.has_crew_bonus(CrewData.CrewBonus.COMBAT_HEAL):
		var heal: int = int(GameManager.get_crew_bonus_value(CrewData.CrewBonus.COMBAT_HEAL))
		GameManager.current_hull = mini(GameManager.current_hull + heal, GameManager.max_hull)
	return earned


func _setup_credits_only_reward(destination: String) -> void:
	_describe_battle_reward(destination)
	_show_continue_only()


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
	EventLog.add_entry("Salvaged card: %s" % card_data.card_name)
	AchievementManager.check_deck(GameManager.deck.size())
	_on_continue_pressed()


func _on_skip_pressed() -> void:
	if card_selected:
		return
	card_selected = true
	_on_continue_pressed()


# ── Upgrade reward ───────────────────────────────────────────────────────────

func _setup_upgrade_reward(destination: String) -> void:
	_describe_battle_reward(destination)
	%CardRewardPanel.visible = false
	%ContinueButton.visible = false

	var combat_upgrades: Array = ResourceRegistry.load_all(ResourceRegistry.COMBAT_UPGRADES)
	combat_upgrades.shuffle()

	# Find one that's not already installed
	var chosen: Resource = null
	for upg in combat_upgrades:
		if upg.upgrade_name not in GameManager.installed_upgrades:
			chosen = upg
			break

	if chosen == null and not combat_upgrades.is_empty():
		# Bad luck, everything is installed already — show what it would have been
		chosen = combat_upgrades[0]

	if not chosen:
		# Fallback: no upgrades available at all
		%RewardPanel.visible = false
		%ContinueButton.visible = true
		return

	var already_owned: bool = chosen.upgrade_name in GameManager.installed_upgrades
	_build_reward_panel(
		"Ship Upgrade Found!",
		UPGRADE_ICONS.get(chosen.upgrade_name, "🔧"),
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
			EventLog.add_entry("Installed upgrade: %s" % chosen.upgrade_name)
			_on_continue_pressed()
		)


# ── Crew reward ──────────────────────────────────────────────────────────────

func _setup_crew_reward(destination: String) -> void:
	_describe_battle_reward(destination, "\n")
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
	var crew_full: bool = GameManager.crew.size() >= GameManager.get_max_crew()

	var blocked: bool = already_recruited or crew_full
	var block_reason: String = ""
	if already_recruited:
		block_reason = "Already recruited"
	elif crew_full:
		block_reason = "Crew full (%d/%d)" % [GameManager.crew.size(), GameManager.get_max_crew()]

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
			EventLog.add_entry("Rescued crew: %s" % chosen.crew_name)
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
	# Everything else here is the theme's plain Button look.
	%ContinueButton.custom_minimum_size = Vector2(160, 0)


func _on_continue_pressed() -> void:
	if GameManager.battle_result == "won":
		var travel_event := TravelEventScene.instantiate()
		add_child(travel_event)
		if travel_event.try_trigger(GameManager.travel_days):
			travel_event.event_resolved.connect(_finish_continue)
			return
		travel_event.queue_free()

	_finish_continue()


func _finish_continue() -> void:
	GameManager.current_encounter = null
	GameManager.battle_result = ""
	GameManager.extra_battle_message = ""
	if GameManager.current_hull <= 0:
		# If defeated at Crimson Jack's Hideout (before victory), survive with 1 HP
		if GameManager.travel_destination == GameManager.CRIMSON_BASE_NAME and not GameManager.victory_triggered:
			GameManager.current_hull = 1
			GameManager.change_scene("res://scenes/planet_screen.tscn")
		else:
			GameManager.change_scene("res://scenes/game_over.tscn")
	else:
		if GameManager.try_trigger_actual_victory():
			return
		GameManager.change_scene("res://scenes/planet_screen.tscn")
