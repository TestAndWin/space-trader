extends Control

const CardDisplayScene = preload("res://scenes/components/card_display.tscn")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const EnergyPips = preload("res://scripts/components/energy_pips.gd")

const FLEE_COST := 150
const FLEE_CHANCE := 0.5

## Gap between a shot and the impact it causes, in seconds.
const SFX_IMPACT_DELAY := 0.18

var encounter: Resource = null
var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []
var current_energy: int = 0
var enemy_health: int = 0
var enemy_max_health: int = 0
var enemy_intent_damage: int = 0
var battle_active: bool = false
var skip_enemy_turn: bool = false
var attacks_played_this_turn: int = 0
var _boarding_attempted: bool = false
var combo_active: bool = false
var recycled_this_shuffle: bool = false

const RAMMING_SPEED_HULL_THRESHOLD := 0.70

@onready var ship_display := %ShipDisplay
@onready var end_turn_button: Button = $MainLayout/PlayerPanel/PlayerVBox/ButtonsBar/EndTurnButton

var _energy_pips: Control = null

# Special ability state
var turn_count: int = 0
var enemy_shield: int = 0
var adaptation_reduction: int = 0
var focus_fire_bonus: int = 0
var effective_energy_per_turn: int = 0


func _ready() -> void:
	encounter = GameManager.current_encounter
	_style_battle_buttons()
	UIStyles.apply_display_font(%EnemyNameLabel)
	UIStyles.apply_mono_font(%EnemyHealthLabel)
	UIStyles.apply_mono_font(%EnergyLabel)
	UIStyles.apply_mono_font(%IntentLabel)
	UIStyles.apply_mono_font(%HullLabel)
	UIStyles.apply_mono_font(%ShieldLabel)
	UIStyles.apply_mono_font(%DeckCountLabel)
	UIStyles.apply_mono_font(%DiscardCountLabel)
	%DeckCountLabel.visible = false
	%DiscardCountLabel.visible = false
	_style_readability()
	_build_energy_pips()
	BackgroundUtils.add_fullscreen_background(
		self,
		"res://assets/sprites/scenes/bg_battle.png",
		0.5,
		1,
		true,
		TextureRect.STRETCH_SCALE
	)
	if encounter:
		start_battle(encounter)

	HintManager.show_hint_popup("battle", self)
## The enemy ability line and the deck counters sit directly on the battle
## artwork. Outline them and lift the counter size so they stop disappearing
## into the background.
func _style_readability() -> void:
	for label: Label in [%AbilityLabel, %IntentLabel, %EnemyNameLabel, %EnemyHealthLabel]:
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		label.add_theme_constant_override("outline_size", 6)
	%AbilityLabel.add_theme_color_override("font_color", Color(0.86, 0.72, 1.0))
	%AbilityLabel.add_theme_font_size_override("font_size", UIStyles.FONT_DETAIL)
	%AbilityLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	for counter: Label in [%DeckCountLabel, %DiscardCountLabel]:
		counter.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
		counter.add_theme_color_override("font_color", Color(0.62, 0.85, 1.0))
		counter.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		counter.add_theme_constant_override("outline_size", 5)
		counter.mouse_filter = Control.MOUSE_FILTER_STOP
	%DeckCountLabel.tooltip_text = "Cards left in your draw pile"
	%DiscardCountLabel.tooltip_text = "Cards in the discard pile — reshuffled when the draw pile runs out"


func _build_energy_pips() -> void:
	var energy_label: Label = %EnergyLabel
	energy_label.text = "Energy"
	energy_label.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
	energy_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	energy_label.add_theme_constant_override("outline_size", 5)

	_energy_pips = Control.new()
	_energy_pips.set_script(EnergyPips)
	_energy_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_energy_pips.mouse_filter = Control.MOUSE_FILTER_STOP
	energy_label.get_parent().add_child(_energy_pips)
	energy_label.get_parent().move_child(_energy_pips, energy_label.get_index() + 1)


func _style_battle_buttons() -> void:
	UIStyles.style_accent_button(end_turn_button, Color(0.0, 0.40, 0.20), UIStyles.FONT_LABEL)
	UIStyles.style_secondary_button(%FleeButton, UIStyles.FONT_LABEL)
	UIStyles.style_accent_button(%BoardButton, Color(0.5, 0.15, 0.1), UIStyles.FONT_LABEL)


func start_battle(enc: Resource) -> void:
	AudioManager.play_bgm("res://assets/audio/bgm/battle.ogg")
	encounter = enc
	enemy_health = enc.enemy_health
	enemy_max_health = enc.enemy_health
	GameManager.boarding_special_loot = ""
	
	if enc.encounter_name == "Crimson Jack":
		match GameManager.difficulty:
			GameManager.Difficulty.EASY: enemy_health = 100
			GameManager.Difficulty.NORMAL: enemy_health = 150
			GameManager.Difficulty.HARD: enemy_health = 200
		var weaken: int = PirateLordManager.officers_defeated.size() * 15
		enemy_health = max(1, enemy_health - weaken)
		enemy_max_health = enemy_health
		
	# Shield carries over from overworld (upgrades matter)
	_reset_deck_piles()
	battle_active = true
	skip_enemy_turn = false

	# Reset special ability state
	turn_count = 0
	enemy_shield = 0
	adaptation_reduction = 0
	focus_fire_bonus = 0
	effective_energy_per_turn = GameManager.energy_per_turn

	# Show rival taunt if this is a rival encounter
	if _is_rival_encounter():
		var taunt: String = enc.taunt_line
		if taunt != "":
			_show_battle_message(taunt)

	# ENERGY_DRAIN: reduce energy at battle start
	if enc.special_ability == EncounterData.SpecialAbility.ENERGY_DRAIN:
		effective_energy_per_turn = maxi(1, GameManager.energy_per_turn - 1)
		_show_battle_message("Energy drain! -1 energy per turn")

	# TRADE_OFFER: show offer before battle starts
	if enc.special_ability == EncounterData.SpecialAbility.TRADE_OFFER:
		_show_trade_offer()
		return

	_start_player_turn()


func _is_rival_encounter() -> bool:
	return encounter != null and encounter.is_rival


## Crimson Jack and his enforcers refuse every non-combat way out.
func _is_crimson_foe() -> bool:
	return encounter.encounter_name in ["Crimson Jack", "Crimson Enforcer"]


## The battle reshuffles the whole deck for every hand, so draw/hand/discard
## always start over from GameManager.deck.
func _reset_deck_piles() -> void:
	draw_pile = GameManager.deck.duplicate()
	draw_pile.shuffle()
	hand.clear()
	discard_pile.clear()


## Energy a card costs right now — COMBO shaves off one point.
func _effective_cost(card_data: Resource) -> int:
	if combo_active:
		return max(0, card_data.energy_cost - 1)
	return card_data.energy_cost


func _show_trade_offer() -> void:
	var cost := int(encounter.reward_credits * 0.8)

	# Same chrome as the planet/travel/customs popups so every in-run modal reads
	# as one family; the overlay itself carries the name and z_index.
	var overlay := ColorRect.new()
	overlay.name = "TradeOfferOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)

	var scaffold: Dictionary = UIStyles.create_event_modal_scaffold(overlay, 400.0, UIStyles.CAUTION)
	var vbox: VBoxContainer = scaffold["vbox"]
	scaffold["title_label"].text = "Trade Offer"
	var desc: Label = scaffold["description_label"]
	desc.text = "The enemy offers to end the fight for %d credits." % cost
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var accept_btn := Button.new()
	accept_btn.text = "Accept (%dcr)" % cost
	accept_btn.custom_minimum_size = Vector2(160, 36)
	UIStyles.style_event_button(
		accept_btn, Color(0.2, 0.4, 0.7), Color(0.25, 0.5, 0.85), Color(0.15, 0.3, 0.55)
	)
	accept_btn.pressed.connect(func():
		overlay.queue_free()
		if GameManager.credits >= cost:
			GameManager.remove_credits(cost)
			_show_battle_message("Paid %d credits to avoid battle" % cost)
			EventLog.add_entry("Paid %d cr to %s to avoid battle" % [cost, encounter.encounter_name])
			await get_tree().create_timer(0.5).timeout
			_on_battle_won_no_reward()
		else:
			_show_battle_message("Not enough credits! Fight!")
			_start_player_turn()
	)
	btn_row.add_child(accept_btn)

	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.custom_minimum_size = Vector2(160, 36)
	UIStyles.style_event_button(
		decline_btn, Color(0.25, 0.25, 0.28), Color(0.35, 0.35, 0.38), Color(0.18, 0.18, 0.2)
	)
	decline_btn.pressed.connect(func():
		overlay.queue_free()
		_start_player_turn()
	)
	btn_row.add_child(decline_btn)


func _on_battle_won_no_reward() -> void:
	battle_active = false
	GameManager.total_encounters_won += 1
	var destination: String = GameManager.travel_destination
	GameManager.complete_travel_arrival(destination)
	GameManager.current_encounter = null
	GameManager.battle_result = ""
	GameManager.change_scene("res://scenes/planet_screen.tscn")


func _start_player_turn() -> void:
	turn_count += 1
	current_energy = effective_energy_per_turn
	attacks_played_this_turn = 0
	combo_active = false
	recycled_this_shuffle = false

	end_turn_button.disabled = false

	# Crew per-turn regen (Medic / Engineer) — kicks in from turn 2 to avoid free start-of-fight buffs.
	if turn_count >= 2:
		var heal: int = GameManager.get_combat_heal_per_turn()
		if heal > 0 and GameManager.current_hull < GameManager.max_hull:
			GameManager.current_hull = mini(GameManager.max_hull, GameManager.current_hull + heal)
			_show_battle_message("Medic patches +%d HP" % heal)
		var shield_regen: int = GameManager.get_combat_shield_regen_per_turn()
		if shield_regen > 0 and GameManager.current_shield < GameManager.max_shield:
			GameManager.current_shield = mini(GameManager.max_shield, GameManager.current_shield + shield_regen)
			_show_battle_message("Engineer reroutes power +%d shield" % shield_regen)

	# SHIELD_BOOST: enemy gains shield every 2nd turn
	if encounter.special_ability == EncounterData.SpecialAbility.SHIELD_BOOST and turn_count % 2 == 0:
		enemy_shield += 3
		_show_battle_message("Enemy shield reinforced! (+3)")

	# FOCUS_FIRE: attack bonus increases from turn 2 onward
	if encounter.special_ability == EncounterData.SpecialAbility.FOCUS_FIRE and turn_count >= 2:
		focus_fire_bonus += 2

	_draw_cards(GameManager.hand_size)

	# FLASH_GRENADE: discard 1 random card after drawing
	if encounter.special_ability == EncounterData.SpecialAbility.FLASH_GRENADE and hand.size() > 0:
		var idx := randi_range(0, hand.size() - 1)
		var discarded_card: Resource = hand[idx]
		hand.remove_at(idx)
		discard_pile.append(discarded_card)
		_show_battle_message("Flash grenade! Discarded %s!" % discarded_card.card_name)

	# Calculate enemy intent with focus fire bonus
	var base_min: int = encounter.enemy_attack_range.x + focus_fire_bonus
	var base_max: int = encounter.enemy_attack_range.y + focus_fire_bonus
	enemy_intent_damage = randi_range(base_min, base_max)

	_update_ui()
	# Flash intent label
	%IntentLabel.modulate = Color(1.5, 1.5, 1.5, 1.0)
	var flash_tween := create_tween()
	flash_tween.tween_property(%IntentLabel, "modulate", Color(1, 1, 1, 1), 0.4)


func _draw_cards(count: int) -> void:
	var hand_size_before: int = hand.size()
	for i in count:
		if draw_pile.is_empty():
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
			# RECYCLING: draw 1 extra card on reshuffle if a hand card has the keyword
			if not recycled_this_shuffle and _hand_has_keyword(CardData.CardKeyword.RECYCLING):
				recycled_this_shuffle = true
				if not draw_pile.is_empty():
					hand.append(draw_pile.pop_back())
		if not draw_pile.is_empty():
			hand.append(draw_pile.pop_back())

	# One swipe per draw batch, not per card - drawing a full hand of 5 would
	# otherwise fire five overlapping cues.
	if hand.size() > hand_size_before:
		AudioManager.play_card_draw()


func _hand_has_keyword(keyword: int) -> bool:
	for card in hand:
		if card.keywords.has(keyword):
			return true
	return false


func _apply_damage_to_enemy(raw_damage: int) -> void:
	var damage := raw_damage
	var shield_absorb: int = 0

	# ADAPTATION: reduce damage taken each turn
	if encounter.special_ability == EncounterData.SpecialAbility.ADAPTATION:
		var min_damage := ceili(raw_damage * 0.5)
		damage = maxi(min_damage, raw_damage - adaptation_reduction)
		if damage < raw_damage:
			_show_battle_message("Adapted! Damage reduced to %d" % damage)

	# SHIELD_BOOST: enemy shield absorbs damage first
	if enemy_shield > 0:
		shield_absorb = mini(damage, enemy_shield)
		enemy_shield -= shield_absorb
		damage -= shield_absorb
		if shield_absorb > 0:
			_show_battle_message("Enemy shield absorbed %d damage" % shield_absorb)

	enemy_health -= damage

	# Shot first, impact a moment later - fired together they smear into one noise.
	if raw_damage > 0:
		%EnemyShipDisplay.play_hit()
		AudioManager.play_laser()
		if enemy_health > 0:
			_play_delayed_sfx("shield_hit" if damage == 0 and shield_absorb > 0 else "hull_hit", SFX_IMPACT_DELAY)


## Schedules a sound without blocking the caller. The battle flow is
## synchronous, so awaiting here would delay game logic, not just audio.
func _play_delayed_sfx(sfx_name: String, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(
		func() -> void: AudioManager.play_sfx(sfx_name, 0.06)
	)


func _on_card_played(card_data: Resource) -> void:
	var effective_cost: int = _effective_cost(card_data)
	if not battle_active or effective_cost > current_energy:
		return

	if _is_crimson_foe():
		if card_data.special_effect == CardData.SpecialEffect.END_ENCOUNTER:
			_show_battle_message("This enemy cannot be negotiated with!")
			AudioManager.play_ui_click()
			return
		if card_data.card_name == "Bribe":
			_show_battle_message("This enemy cannot be bribed!")
			AudioManager.play_ui_click()
			return

	current_energy -= effective_cost
	AudioManager.play_card_play()
	# Reset combo after applying discount
	combo_active = false

	match card_data.card_type:
		CardData.CardType.ATTACK: _apply_attack_card(card_data)
		CardData.CardType.DEFENSE: _apply_defense_card(card_data)
		CardData.CardType.UTILITY: _apply_utility_card(card_data)
		CardData.CardType.TRADE: _apply_trade_card(card_data)

	# COMBO: activate for next card
	if card_data.keywords.has(CardData.CardKeyword.COMBO):
		combo_active = true

	# Handle special effects
	var should_return := _apply_special_effect(card_data)
	if should_return:
		return

	hand.erase(card_data)
	discard_pile.append(card_data)

	_update_ui()

	if enemy_health <= 0:
		_handle_enemy_defeated()
		return
	if GameManager.current_hull <= 0:
		_on_battle_lost()
		return

	# Auto end turn when no energy left for any remaining card
	if current_energy <= 0 or not _has_playable_card():
		await get_tree().create_timer(0.8).timeout
		if battle_active:
			_on_end_turn_pressed()


func _apply_attack_card(card_data: Resource) -> void:
	var damage: int = card_data.attack_value
	# Crew weapons officer bonus
	if GameManager.has_crew_bonus(CrewData.CrewBonus.ATTACK_BONUS):
		damage += int(GameManager.get_crew_bonus_value(CrewData.CrewBonus.ATTACK_BONUS))
	# RAMMING_SPEED: First attack each round +3 damage when Hull > 70%
	if attacks_played_this_turn == 0:
		var ship: Resource = GameManager.get_ship_data()
		if ship and ship.ship_ability == ShipData.ShipAbility.RAMMING_SPEED:
			var hull_pct: float = float(GameManager.current_hull) / float(GameManager.max_hull) if GameManager.max_hull > 0 else 0.0
			if hull_pct > RAMMING_SPEED_HULL_THRESHOLD:
				damage += 3
				_show_battle_message("Ramming Speed! +3 damage")
	# Rival encounter: crew with 'combat' tag deals +2 damage on first attack (Finding #8)
	if _is_rival_encounter() and attacks_played_this_turn == 0:
		if GameManager.has_crew_flavor_tag("combat"):
			damage += 2
			_show_battle_message("%s strikes hard! +2 vs Rival" % GameManager.get_crew_name_by_flavor_tag("combat"))
	# CHARGE: 1.5x damage if 2+ attacks played this turn
	if card_data.keywords.has(CardData.CardKeyword.CHARGE) and attacks_played_this_turn >= 2:
		damage = int(damage * 1.5)
	# SHIELD_ECHO: bonus damage = current_shield / 2
	if card_data.keywords.has(CardData.CardKeyword.SHIELD_ECHO) and GameManager.current_shield > 0:
		damage += int(GameManager.current_shield / 2.0)
	# Targeting Computer (crafted upgrade): +20% damage
	if "Targeting Computer" in GameManager.installed_upgrades:
		damage = int(round(damage * 1.2))
	_apply_damage_to_enemy(damage)
	attacks_played_this_turn += 1


func _apply_defense_card(card_data: Resource) -> void:
	if card_data.defense_value > 0:
		AudioManager.play_shield_up()
	GameManager.current_shield = min(GameManager.max_shield, GameManager.current_shield + card_data.defense_value)
	# SHIELD_ECHO on defense: deal shield/2 as damage
	if card_data.keywords.has(CardData.CardKeyword.SHIELD_ECHO) and GameManager.current_shield > 0:
		_apply_damage_to_enemy(int(GameManager.current_shield / 2.0))
	if card_data.draw_cards > 0:
		_draw_cards(card_data.draw_cards)


func _apply_utility_card(card_data: Resource) -> void:
	if card_data.heal_value > 0:
		GameManager.current_hull = min(GameManager.max_hull, GameManager.current_hull + card_data.heal_value)
	if card_data.draw_cards > 0:
		_draw_cards(card_data.draw_cards)


func _apply_trade_card(card_data: Resource) -> void:
	if card_data.credits_gain > 0:
		GameManager.add_credits(card_data.credits_gain)
		EventLog.add_entry("Played %s: +%d cr" % [card_data.card_name, card_data.credits_gain])


## Returns true if the caller should return early (battle ended).
func _apply_special_effect(card_data: Resource) -> bool:
	match card_data.special_effect:
		CardData.SpecialEffect.SELF_DAMAGE_5:
			GameManager.current_hull -= 5
		CardData.SpecialEffect.BONUS_ENERGY_2:
			current_energy += 2
		CardData.SpecialEffect.SKIP_ENEMY_TURN:
			skip_enemy_turn = true
		CardData.SpecialEffect.END_ENCOUNTER:
			# Peaceful resolution: no win/loss, remove card permanently from deck
			GameManager.remove_card_permanently(card_data.resource_path)
			_on_battle_won_no_reward()
			return true
		CardData.SpecialEffect.SCAVENGE:
			_resolve_scavenge()
	return false


func _resolve_scavenge() -> void:
	var roll := randi_range(0, 3)
	var msg: String
	match roll:
		0: # Credits
			var amount := randi_range(15, 50)
			GameManager.add_credits(amount)
			msg = "Found %d credits!" % amount
			EventLog.add_entry("Scavenged %d cr" % amount)
		1: # Shield
			var amount := randi_range(2, 5)
			GameManager.current_shield = mini(GameManager.max_shield, GameManager.current_shield + amount)
			msg = "Found shield parts! +%d shield" % amount
		2: # Energy
			current_energy += 1
			msg = "Found a power cell! +1 energy"
		3: # Hull repair
			var amount := randi_range(2, 5)
			GameManager.current_hull = mini(GameManager.max_hull, GameManager.current_hull + amount)
			msg = "Found repair kit! +%d hull" % amount
	_show_battle_message(msg)


func _show_battle_message(text: String) -> void:
	var container := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	container.add_theme_stylebox_override("panel", style)
	container.anchor_left = 0.15
	container.anchor_right = 0.85
	container.anchor_top = 0.4
	container.position.y = -20
	add_child(container)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", UIStyles.FONT_SUBHEADING)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.25))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(lbl)

	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.chain().set_parallel(true)
	tween.tween_property(container, "position:y", container.position.y - 40, 1.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "modulate:a", 0.0, 1.8).set_delay(0.4)
	tween.chain().tween_callback(container.queue_free)


func _has_playable_card() -> bool:
	for card in hand:
		if _effective_cost(card) <= current_energy:
			return true
	return false


func _on_end_turn_pressed() -> void:
	if not battle_active:
		return
		
	# Disable button immediately to prevent double clicks
	end_turn_button.disabled = true

	if skip_enemy_turn:
		skip_enemy_turn = false
	else:
		var damage := enemy_intent_damage
		# COMBAT_TACTICAL: chance that enemy's first attack (round 1 only) misses
		if turn_count == 1:
			var dodge_chance: float = GameManager.get_combat_tactical_dodge_chance()
			if dodge_chance > 0.0 and randf() < dodge_chance:
				_show_battle_message("Tactical Dodge! Enemy first attack misses.")
				damage = 0
				
		if damage > 0:
			%EnemyShipDisplay.play_attack()
			await get_tree().create_timer(0.15).timeout
			
		var shield_absorb: int = mini(damage, GameManager.current_shield)
		GameManager.current_shield -= shield_absorb
		damage -= shield_absorb
		GameManager.current_hull -= damage

		# Play hit animation on player ship
		if shield_absorb > 0 and damage == 0:
			ship_display.play_shield_hit()
			AudioManager.play_enemy_laser()
			_play_delayed_sfx("shield_hit", SFX_IMPACT_DELAY)
		elif damage > 0:
			ship_display.play_hull_hit()
			AudioManager.play_enemy_laser()
			_play_delayed_sfx("hull_hit", SFX_IMPACT_DELAY)

		# Apply on-hit special abilities when damage got through shields
		if damage > 0:
			_apply_enemy_on_hit_effects()

	# ADAPTATION: increase damage reduction at end of each turn
	if encounter.special_ability == EncounterData.SpecialAbility.ADAPTATION:
		adaptation_reduction += 1

	# Reshuffle entire deck at end of turn
	_reset_deck_piles()

	if GameManager.current_hull <= 0:
		_on_battle_lost()
		return
	_start_player_turn()


func _apply_enemy_on_hit_effects() -> void:
	match encounter.special_ability:
		EncounterData.SpecialAbility.PLUNDER:
			# Steal credits on hit
			var stolen := mini(20, GameManager.credits)
			if stolen > 0:
				GameManager.remove_credits(stolen)
				_show_battle_message("Enemy stole %d credits!" % stolen)

		EncounterData.SpecialAbility.BOARDING:
			# Steal 1 random cargo on hit, may wound crew
			var lost_msg: String = ""
			if GameManager.cargo.size() > 0:
				var idx := randi_range(0, GameManager.cargo.size() - 1)
				var good_name: String = GameManager.cargo[idx]["good_name"]
				GameManager.remove_cargo(good_name, 1)
				lost_msg = "Lost 1x %s" % good_name
			else:
				var stolen: int = mini(50, GameManager.credits)
				GameManager.remove_credits(stolen)
				lost_msg = "Lost %d cr" % stolen

			var unwounded: Array = []
			for c in GameManager.crew:
				if c not in GameManager.wounded_crew:
					unwounded.append(c)
			if unwounded.size() > 0 and randf() < 0.5:
				var to_wound: String = unwounded.pick_random()
				GameManager.wounded_crew[to_wound] = randi_range(4, 7)
				var res: Resource = load(to_wound)
				lost_msg += " & %s wounded" % res.crew_name

			_show_battle_message("Enemy boarded! " + lost_msg)

		EncounterData.SpecialAbility.CRIMSON_FURY:
			# Boss gains max damage on hit
			encounter.enemy_attack_range.y += 5
			_show_battle_message("Crimson Jack's fury grows! (+5 Max Dmg)")


## Enemy hull is down: offer to board unless that door is already closed.
func _handle_enemy_defeated() -> void:
	if not _boarding_attempted and encounter.encounter_name != "Crimson Jack":
		_show_boarding_choice()
	else:
		_on_battle_won(false)


func _launch_boarding_minigame() -> void:
	_boarding_attempted = true
	var minigame_scene: PackedScene = load("res://scenes/boarding_minigame.tscn")
	var minigame: Node = minigame_scene.instantiate()
	minigame.starting_alarm = int(maxf(0.0, float(enemy_health)) / float(enemy_max_health) * 100.0)
	add_child(minigame)
	minigame.boarding_finished.connect(_on_boarding_finished)


func _show_boarding_choice() -> void:
	battle_active = false
	
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var container := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.9)
	style.border_color = Color(0.8, 0.8, 0.8, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	container.add_theme_stylebox_override("panel", style)
	center.add_child(container)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Enemy disabled! Do you want to board their ship?"
	lbl.add_theme_font_size_override("font_size", UIStyles.FONT_SUBHEADING)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.25))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var board_btn := Button.new()
	board_btn.text = "Board Ship!"
	board_btn.custom_minimum_size = Vector2(120, 40)
	UIStyles.style_accent_button(board_btn, Color(0.6, 0.2, 0.2))
	board_btn.pressed.connect(func():
		overlay.queue_free()
		_launch_boarding_minigame()
	)
	btn_row.add_child(board_btn)

	var destroy_btn := Button.new()
	destroy_btn.text = "Destroy & Loot"
	destroy_btn.custom_minimum_size = Vector2(140, 40)
	UIStyles.style_accent_button(destroy_btn, Color(0.3, 0.3, 0.3))
	destroy_btn.pressed.connect(func():
		overlay.queue_free()
		var scrap: int = randi_range(20, 50)
		GameManager.add_credits(scrap)
		GameManager.extra_battle_message = "Scrapped for %d cr" % scrap
		EventLog.add_entry("Scrapped enemy ship for %d cr" % scrap)
		_on_battle_won()
	)
	btn_row.add_child(destroy_btn)


func _on_boarding_finished(status: int) -> void:
	if status == 2:
		var loot_str: String = GameManager.extra_battle_message
		GameManager.extra_battle_message = "Boarding successful!"
		
		var log_msg: String = "Boarding successful!"
		if loot_str != "":
			GameManager.extra_battle_message += "\n\nLoot: " + loot_str
			log_msg += " Loot: " + loot_str
			
		# Intact Capture Bonus
		if enemy_health > 0:
			var hp_pct: float = float(enemy_health) / float(enemy_max_health)
			# Scale reward by hull integrity (50% value if nearly destroyed, 100% if fully intact)
			var hull_mult: float = lerp(0.5, 1.0, hp_pct)
			
			var base_bonus: float = float(GameManager.CAPTURED_SHIP_BASE_PRICE)
			var variance: float = randf_range(0.8, 1.2)
			var capture_bonus: int = int(round(base_bonus * variance * hull_mult))
			
			GameManager.add_credits(capture_bonus)
			GameManager.extra_battle_message += "\n\nCaptured Ship Sold: %d cr" % capture_bonus
			log_msg += ", Captured Ship Sold: %d cr" % capture_bonus
			
			# Instantly defeat the enemy ship
			enemy_health = 0
			
		EventLog.add_entry(log_msg)
			
		_on_battle_won(true)
	else:
		if status == 1:
			var loot_str: String = GameManager.extra_battle_message
			if loot_str != "":
				GameManager.extra_battle_message = "Boarding Loot: " + loot_str
			EventLog.add_entry("Boarding team extracted. Loot: " + loot_str)
			_show_battle_message("Extracted Loot:\n" + loot_str + "\n\nCombat Resumes!")
		else:
			EventLog.add_entry("Boarding failed! Team routed.")
			_show_battle_message("Boarding Failed! Combat Resumes!")
			
		if GameManager.current_hull <= 0:
			_on_battle_lost()
			return
		
		if enemy_health > 0:
			# Reshuffle and deal new hand per user request
			_reset_deck_piles()
			current_energy = effective_energy_per_turn
			_draw_cards(GameManager.hand_size)
			
			_update_ui()
			return
			
		_on_battle_boarding_failed()


## Score, achievements and heat — the bookkeeping every won battle shares.
func _register_victory(result: String, log_text: String) -> void:
	GameManager.total_encounters_won += 1
	GameManager.battle_result = result
	EventLog.add_entry(log_text)
	AchievementManager.unlock("first_blood")
	if encounter.encounter_name == "Bounty Hunter":
		AchievementManager.unlock("bounty_survivor")
	PirateLordManager.add_heat(3)


## Rival/bounty standing updates and the exit to the result screen. A beaten
## rival never also counts as a bounty target.
func _leave_won_battle() -> void:
	if _is_rival_encounter():
		RivalManager.on_rival_defeated()
	elif encounter.encounter_name == "Bounty Hunter":
		StandingManager.add_bounty(50, "killed authorized bounty hunter")
	elif encounter.encounter_name == "System Patrol":
		StandingManager.add_bounty(50, "defeated patrol")
	GameManager.change_scene("res://scenes/battle_result.tscn")


func _on_battle_boarding_failed() -> void:
	battle_active = false
	_register_victory("boarding_failed", "Won battle vs %s, but boarding failed" % encounter.encounter_name)
	_leave_won_battle()


func _on_flee_pressed() -> void:
	if not encounter.can_flee:
		return
	if randf() < FLEE_CHANCE:
		GameManager.remove_credits(FLEE_COST)
		GameManager.battle_result = "fled"
		EventLog.add_entry("Fled from %s" % encounter.encounter_name)
		GameManager.change_scene("res://scenes/battle_result.tscn")
	else:
		_show_battle_message("Escape failed!")
		_on_end_turn_pressed()


func _on_battle_won(was_boarded: bool = false) -> void:
	# Stop enemy actions and show explosion
	battle_active = false
	
	if not was_boarded:
		# TODO: Play enemy ship explosion animation here
		AudioManager.play_explosion()
		await get_tree().create_timer(2.0).timeout
		
	_register_victory("boarded" if was_boarded else "won", "Won battle vs %s" % encounter.encounter_name)
	# A rival defeat skips the pirate-lord messages below.
	if _is_rival_encounter():
		_leave_won_battle()
		return
	# Pirate Lord system
	if encounter.encounter_name == "Crimson Enforcer":
		PirateLordManager.defeat_officer("Enforcer")
		GameManager.extra_battle_message = "Defeated Enforcer! Crimson Jack's fleet weakened."
	elif encounter.encounter_name == "Pirate Captain":
		GameManager.extra_battle_message = "Found Contraband!"
		
	if encounter.encounter_name == "Crimson Jack":
		PirateLordManager.jack_defeated = true
		GameManager.extra_battle_message = "Crimson Jack Defeated!"

	_leave_won_battle()


func _on_battle_lost() -> void:
	battle_active = false
	AudioManager.play_explosion()
	# Lose half of cargo (pirates take it). Decide first, then remove through
	# GameManager so the change is reported — mutating its array directly used
	# to skip cargo_changed entirely.
	var lost_items: Array = []
	var losses: Array[Dictionary] = []
	for item: Dictionary in GameManager.cargo:
		var lost: int = int(item["quantity"] / 2.0)
		if lost > 0:
			lost_items.append("%d %s" % [lost, item["good_name"]])
			losses.append({"good_name": item["good_name"], "quantity": lost})
	for loss: Dictionary in losses:
		GameManager.remove_cargo(loss["good_name"], loss["quantity"])
	if lost_items.size() > 0:
		GameManager.last_cargo_lost_text = "Lost: " + ", ".join(lost_items)
		EventLog.add_entry("Pirates took cargo: " + ", ".join(lost_items))
	else:
		GameManager.last_cargo_lost_text = ""
	var lost_credits := int(GameManager.credits * 0.3)
	GameManager.remove_credits(lost_credits)
	GameManager.battle_result = "lost"
	EventLog.add_entry("Lost battle vs %s" % encounter.encounter_name)
	# Rival handling
	if _is_rival_encounter():
		RivalManager.on_rival_won()
	if GameManager.current_hull <= 0:
		if GameManager.travel_destination == GameManager.CRIMSON_BASE_NAME:
			GameManager.battle_result = "lost"
			GameManager.change_scene("res://scenes/battle_result.tscn")
			return
		elif GameManager.owned_ships.size() > 1:
			var old_ship = GameManager.current_ship
			var new_ship = ""
			for s in GameManager.owned_ships:
				if s != old_ship:
					new_ship = s
					break
			GameManager.switch_ship(new_ship)
			GameManager.current_hull = GameManager.max_hull
			GameManager.current_shield = GameManager.max_shield
			GameManager.cargo.clear()
			GameManager.crew.clear()
			GameManager.cargo_changed.emit()
			GameManager.crew_changed.emit()
			GameManager.battle_result = "lost_backup"
			GameManager.change_scene("res://scenes/battle_result.tscn")
			return
		else:
			GameManager.change_scene("res://scenes/game_over.tscn")
			return
	GameManager.change_scene("res://scenes/battle_result.tscn")


func _update_ui() -> void:
	_update_enemy_ui()
	_update_player_ui()
	_update_deck_info()
	_update_hand_display()


func _update_enemy_ui() -> void:
	var display_health: int = max(0, enemy_health)
	%EnemyNameLabel.text = encounter.encounter_name
	%EnemyHealthBar.max_value = enemy_max_health
	%EnemyHealthBar.value = display_health
	var enemy_style := StyleBoxFlat.new()
	enemy_style.bg_color = Color(0.9, 0.2, 0.2)
	%EnemyHealthBar.add_theme_stylebox_override("fill", enemy_style)
	%EnemyHealthLabel.text = "%d / %d" % [display_health, enemy_max_health]
	if enemy_shield > 0:
		%EnemyHealthLabel.text += " [Shield: %d]" % enemy_shield

	var enemy_hull_pct: float = float(display_health) / float(enemy_max_health) if enemy_max_health > 0 else 0.0
	var enemy_shield_pct: float = float(enemy_shield) / 10.0 if enemy_shield > 0 else 0.0
	%EnemyShipDisplay.update_enemy(enemy_hull_pct, enemy_shield_pct, encounter.encounter_name)

	%IntentLabel.text = "Enemy will deal %d damage" % enemy_intent_damage
	if GameManager.current_shield >= enemy_intent_damage:
		%IntentLabel.add_theme_color_override("font_color", UIStyles.POSITIVE)
	elif GameManager.current_shield > 0:
		%IntentLabel.add_theme_color_override("font_color", UIStyles.CAUTION)
	else:
		%IntentLabel.add_theme_color_override("font_color", UIStyles.NEGATIVE)

	if encounter.ability_description != "":
		%AbilityLabel.text = encounter.ability_description
		%AbilityLabel.visible = true
	else:
		%AbilityLabel.visible = false


func _update_player_ui() -> void:
	var display_hull: int = max(0, GameManager.current_hull)
	%HullBar.max_value = GameManager.max_hull
	%HullBar.value = display_hull
	var hull_pct: float = float(display_hull) / float(GameManager.max_hull)
	var hull_style := StyleBoxFlat.new()
	hull_style.bg_color = Color(0.3, 0.9, 0.3) if hull_pct > 0.6 else (Color(0.9, 0.8, 0.2) if hull_pct > 0.3 else Color(0.9, 0.2, 0.2))
	%HullBar.add_theme_stylebox_override("fill", hull_style)
	%HullLabel.text = "Hull: %d / %d" % [display_hull, GameManager.max_hull]
	%ShieldBar.max_value = GameManager.max_shield
	%ShieldBar.value = GameManager.current_shield
	%ShieldLabel.text = "Shield: %d / %d" % [GameManager.current_shield, GameManager.max_shield]
	if _energy_pips:
		_energy_pips.setup(current_energy, effective_energy_per_turn)

	# Ship display
	var shield_pct: float = float(GameManager.current_shield) / float(GameManager.max_shield) if GameManager.max_shield > 0 else 0.0
	var ship_data: Resource = GameManager.get_ship_data()
	var shape: int = ship_data.hull_shape if ship_data else 0
	ship_display.update_ship(hull_pct, shield_pct, GameManager.get_cargo_used(), GameManager.cargo_capacity, shape)

	# Flee button
	%FleeButton.disabled = not encounter.can_flee
	if not encounter.can_flee:
		%FleeButton.tooltip_text = "Cannot flee from this enemy!"
		%FleeButton.text = "Flee (blocked)"
	else:
		%FleeButton.tooltip_text = "%d%% chance to escape (-%dcr). Failure ends your turn!" % [int(FLEE_CHANCE * 100), FLEE_COST]
		%FleeButton.text = "Flee"
		
	# Board Button
	var threshold_pct: int = 50 if "Grappling Hook" in GameManager.installed_upgrades else 30
	if encounter.encounter_name == "Crimson Jack":
		%BoardButton.visible = false
		return
	var threshold_hp: int = ceili(float(enemy_max_health) * float(threshold_pct) / 100.0)
	%BoardButton.disabled = (enemy_health > threshold_hp) or (enemy_health <= 0) or _boarding_attempted
	%BoardButton.visible = true
	if %BoardButton.disabled:
		if _boarding_attempted:
			%BoardButton.tooltip_text = "Boarding party already routed!"
		else:
			%BoardButton.tooltip_text = "Enemy hull must be at or below %d HP to board." % threshold_hp
	else:
		%BoardButton.tooltip_text = "Launch boarding party! Ends the battle if successful."

func _on_board_pressed() -> void:
	if not battle_active or _boarding_attempted: return
	_launch_boarding_minigame()


func _update_deck_info() -> void:
	%DeckCountLabel.text = "Deck: %d" % draw_pile.size()
	%DiscardCountLabel.text = "Discard: %d" % discard_pile.size()


func _update_hand_display() -> void:
	for child in %HandContainer.get_children():
		child.queue_free()

	for card in hand:
		var card_display := CardDisplayScene.instantiate()
		%HandContainer.add_child(card_display)
		card_display.setup(card, _effective_cost(card) <= current_energy)
		card_display.card_played.connect(_on_card_played)

func _unhandled_input(event: InputEvent) -> void:
	if not battle_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			enemy_health -= 30
			_show_battle_message("CHEAT (F8): Enemy hull -30 HP")
			if %EnemyShipDisplay:
				%EnemyShipDisplay.play_hit()
			_update_ui()
			if enemy_health <= 0:
				_handle_enemy_defeated()
