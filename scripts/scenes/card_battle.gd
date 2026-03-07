extends Control

const CardDisplayScene = preload("res://scenes/components/card_display.tscn")

const FLEE_COST := 150
const FLEE_CHANCE := 0.5

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
var combo_active: bool = false
var recycled_this_shuffle: bool = false

@onready var ship_display := %ShipDisplay

# Special ability state
var turn_count: int = 0
var enemy_shield: int = 0
var adaptation_reduction: int = 0
var focus_fire_bonus: int = 0
var effective_energy_per_turn: int = 0


func _ready() -> void:
	encounter = GameManager.current_encounter
	_style_battle_buttons()
	_add_battle_background()
	if encounter:
		start_battle(encounter)


func _add_battle_background() -> void:
	var path: String = "res://assets/sprites/bg_battle.png"
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


func _style_battle_buttons() -> void:
	# End Turn: neon green
	var end_btn: Button = $MainLayout/PlayerPanel/PlayerVBox/ButtonsBar/EndTurnButton
	var normal_end := StyleBoxFlat.new()
	normal_end.bg_color = Color(0.0, 0.20, 0.10, 0.9)
	normal_end.border_color = Color(0.0, 0.85, 0.45, 0.9)
	normal_end.set_border_width_all(2)
	normal_end.set_corner_radius_all(6)
	normal_end.content_margin_left = 16
	normal_end.content_margin_right = 16
	normal_end.content_margin_top = 6
	normal_end.content_margin_bottom = 6
	var hover_end := normal_end.duplicate()
	hover_end.bg_color = Color(0.0, 0.30, 0.15, 0.9)
	hover_end.border_color = Color(0.0, 1.0, 0.55, 1.0)
	end_btn.add_theme_stylebox_override("normal", normal_end)
	end_btn.add_theme_stylebox_override("hover", hover_end)
	end_btn.add_theme_color_override("font_color", Color(0.0, 0.85, 0.45))
	end_btn.add_theme_color_override("font_hover_color", Color(0.0, 1.0, 0.55))
	# Flee: dim cyan/grey
	var normal_flee := StyleBoxFlat.new()
	normal_flee.bg_color = Color(0.02, 0.06, 0.14, 0.85)
	normal_flee.border_color = Color(0.0, 0.35, 0.55, 0.6)
	normal_flee.set_border_width_all(1)
	normal_flee.set_corner_radius_all(6)
	normal_flee.content_margin_left = 12
	normal_flee.content_margin_right = 12
	normal_flee.content_margin_top = 6
	normal_flee.content_margin_bottom = 6
	var hover_flee := normal_flee.duplicate()
	hover_flee.border_color = Color(0.0, 0.55, 0.75, 0.8)
	%FleeButton.add_theme_stylebox_override("normal", normal_flee)
	%FleeButton.add_theme_stylebox_override("hover", hover_flee)
	%FleeButton.add_theme_color_override("font_color", Color(0.35, 0.6, 0.8))
	%FleeButton.add_theme_color_override("font_hover_color", Color(0.5, 0.8, 1.0))


func start_battle(enc: Resource) -> void:
	encounter = enc
	enemy_health = enc.enemy_health
	enemy_max_health = enc.enemy_health
	# Shield carries over from overworld (upgrades matter)
	draw_pile = GameManager.deck.duplicate()
	draw_pile.shuffle()
	hand.clear()
	discard_pile.clear()
	battle_active = true
	skip_enemy_turn = false

	# Reset special ability state
	turn_count = 0
	enemy_shield = 0
	adaptation_reduction = 0
	focus_fire_bonus = 0
	effective_energy_per_turn = GameManager.energy_per_turn

	# ENERGY_DRAIN: reduce energy at battle start
	if enc.special_ability == EncounterData.SpecialAbility.ENERGY_DRAIN:
		effective_energy_per_turn = maxi(1, GameManager.energy_per_turn - 1)
		_show_battle_message("Energy drain! -1 energy per turn")

	# TRADE_OFFER: show offer before battle starts
	if enc.special_ability == EncounterData.SpecialAbility.TRADE_OFFER:
		_show_trade_offer()
		return

	_start_player_turn()


func _show_trade_offer() -> void:
	var cost := int(encounter.reward_credits * 0.8)

	var overlay := ColorRect.new()
	overlay.name = "TradeOfferOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.name = "TradeOfferPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.14, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.90, 0.25, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 20.0
	style.content_margin_top = 16.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.25
	panel.anchor_right = 0.75
	panel.anchor_top = 0.3
	panel.anchor_bottom = 0.5
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Trade Offer"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "The enemy offers to end the fight for %d credits." % cost
	desc.add_theme_font_size_override("font_size", 16)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var accept_btn := Button.new()
	accept_btn.text = "Accept (%dcr)" % cost
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
	decline_btn.pressed.connect(func():
		overlay.queue_free()
		_start_player_turn()
	)
	btn_row.add_child(decline_btn)


func _on_battle_won_no_reward() -> void:
	battle_active = false
	GameManager.total_encounters_won += 1
	var destination: String = GameManager.travel_destination
	GameManager.current_planet = destination
	if destination not in GameManager.visited_planets:
		GameManager.visited_planets.append(destination)
	GameManager.current_encounter = null
	GameManager.battle_result = ""
	GameManager.change_scene("res://scenes/planet_screen.tscn")


func _start_player_turn() -> void:
	turn_count += 1
	current_energy = effective_energy_per_turn
	attacks_played_this_turn = 0
	combo_active = false
	recycled_this_shuffle = false

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

	# Trigger hit animation on enemy ship display
	if damage > 0 or raw_damage > 0:
		%EnemyShipDisplay.play_hit()


func _on_card_played(card_data: Resource) -> void:
	# Calculate effective energy cost (COMBO reduces by 1)
	var effective_cost: int = card_data.energy_cost
	if combo_active:
		effective_cost = max(0, effective_cost - 1)

	if not battle_active or effective_cost > current_energy:
		return

	current_energy -= effective_cost
	# Reset combo after applying discount
	combo_active = false

	match card_data.card_type:
		0: _apply_attack_card(card_data)
		1: _apply_defense_card(card_data)
		2: _apply_utility_card(card_data)
		3: _apply_trade_card(card_data)

	# COMBO: activate for next card
	if card_data.keywords.has(CardData.CardKeyword.COMBO):
		combo_active = true

	# Handle special effects
	var should_return := _apply_special_effect(card_data)
	if should_return:
		return

	hand.erase(card_data)
	discard_pile.append(card_data)

	if enemy_health <= 0:
		_on_battle_won()
		return
	if GameManager.current_hull <= 0:
		_on_battle_lost()
		return
	_update_ui()

	# Auto end turn when no energy left for any remaining card
	if current_energy <= 0 or not _has_playable_card():
		await get_tree().create_timer(0.4).timeout
		if battle_active:
			_on_end_turn_pressed()


func _apply_attack_card(card_data: Resource) -> void:
	var damage: int = card_data.attack_value
	# Crew weapons officer bonus
	if GameManager.has_crew_bonus(CrewData.CrewBonus.ATTACK_BONUS):
		damage += int(GameManager.get_crew_bonus_value(CrewData.CrewBonus.ATTACK_BONUS))
	# CHARGE: 1.5x damage if 2+ attacks played this turn
	if card_data.keywords.has(CardData.CardKeyword.CHARGE) and attacks_played_this_turn >= 2:
		damage = int(damage * 1.5)
	# SHIELD_ECHO: bonus damage = current_shield / 2
	if card_data.keywords.has(CardData.CardKeyword.SHIELD_ECHO) and GameManager.current_shield > 0:
		damage += int(GameManager.current_shield / 2.0)
	_apply_damage_to_enemy(damage)
	attacks_played_this_turn += 1


func _apply_defense_card(card_data: Resource) -> void:
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


func _apply_special_effect(card_data: Resource) -> bool:
	## Returns true if the caller should return early (battle ended).
	if card_data.special_effect == "self_damage_5":
		GameManager.current_hull -= 5
	elif card_data.special_effect == "bonus_energy_2":
		current_energy += 2
	elif card_data.special_effect == "skip_enemy_turn":
		skip_enemy_turn = true
	elif card_data.special_effect == "end_encounter":
		# Peaceful resolution: no win/loss, remove card permanently from deck
		GameManager.remove_card_permanently(card_data.resource_path)
		_on_battle_won_no_reward()
		return true
	elif card_data.special_effect == "scavenge":
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
	lbl.add_theme_font_size_override("font_size", 18)
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
		var cost: int = card.energy_cost
		if combo_active:
			cost = max(0, cost - 1)
		if cost <= current_energy:
			return true
	return false


func _on_end_turn_pressed() -> void:
	if not battle_active:
		return

	if skip_enemy_turn:
		skip_enemy_turn = false
	else:
		var damage := enemy_intent_damage
		var shield_absorb: int = mini(damage, GameManager.current_shield)
		GameManager.current_shield -= shield_absorb
		damage -= shield_absorb
		GameManager.current_hull -= damage

		# Play hit animation on player ship
		if shield_absorb > 0 and damage == 0:
			ship_display.play_shield_hit()
		elif damage > 0:
			ship_display.play_hull_hit()

		# Apply on-hit special abilities when damage got through shields
		if damage > 0:
			_apply_enemy_on_hit_effects()

	# ADAPTATION: increase damage reduction at end of each turn
	if encounter.special_ability == EncounterData.SpecialAbility.ADAPTATION:
		adaptation_reduction += 1

	discard_pile.append_array(hand)
	hand.clear()

	if GameManager.current_hull <= 0:
		_on_battle_lost()
		return
	_start_player_turn()


func _apply_enemy_on_hit_effects() -> void:
	# PLUNDER: steal credits on hit
	if encounter.special_ability == EncounterData.SpecialAbility.PLUNDER:
		var stolen := mini(20, GameManager.credits)
		if stolen > 0:
			GameManager.remove_credits(stolen)
			_show_battle_message("Enemy stole %d credits!" % stolen)

	# BOARDING: steal 1 random cargo on hit
	if encounter.special_ability == EncounterData.SpecialAbility.BOARDING:
		if GameManager.cargo.size() > 0:
			var idx := randi_range(0, GameManager.cargo.size() - 1)
			var item: Dictionary = GameManager.cargo[idx]
			var good_name: String = item["good_name"]
			item["quantity"] -= 1
			if item["quantity"] <= 0:
				GameManager.cargo.remove_at(idx)
			GameManager.cargo_changed.emit()
			_show_battle_message("Enemy boarded! Lost 1x %s!" % good_name)


func _on_flee_pressed() -> void:
	if not encounter.can_flee:
		return
	if randf() < FLEE_CHANCE:
		GameManager.remove_credits(FLEE_COST)
		GameManager.battle_result = "fled"
		EventLog.add_entry("Fled from %s" % encounter.encounter_name)
		GameManager.change_scene("res://scenes/battle_result.tscn")
	else:
		_on_end_turn_pressed()


func _on_battle_won() -> void:
	battle_active = false
	GameManager.total_encounters_won += 1
	GameManager.battle_result = "won"
	EventLog.add_entry("Won battle vs %s" % encounter.encounter_name)
	GameManager.change_scene("res://scenes/battle_result.tscn")


func _on_battle_lost() -> void:
	battle_active = false
	# Lose half of cargo (pirates take it)
	var lost_items: Array = []
	var i := GameManager.cargo.size() - 1
	while i >= 0:
		var item: Dictionary = GameManager.cargo[i]
		var qty: int = item["quantity"]
		var lost: int = int(qty / 2.0)
		if lost > 0:
			lost_items.append("%d %s" % [lost, item["good_name"]])
			item["quantity"] -= lost
			if item["quantity"] <= 0:
				GameManager.cargo.remove_at(i)
		i -= 1
	if lost_items.size() > 0:
		GameManager.last_cargo_lost_text = "Lost: " + ", ".join(lost_items)
		EventLog.add_entry("Pirates took cargo: " + ", ".join(lost_items))
	else:
		GameManager.last_cargo_lost_text = ""
	GameManager.cargo_changed.emit()
	var lost_credits := int(GameManager.credits * 0.3)
	GameManager.remove_credits(lost_credits)
	GameManager.battle_result = "lost"
	EventLog.add_entry("Lost battle vs %s" % encounter.encounter_name)
	if GameManager.current_hull <= 0:
		GameManager.change_scene("res://scenes/game_over.tscn")
		return
	GameManager.change_scene("res://scenes/battle_result.tscn")


func _update_ui() -> void:
	_update_enemy_ui()
	_update_player_ui()
	_update_deck_info()
	_update_hand_display()


func _update_enemy_ui() -> void:
	%EnemyNameLabel.text = encounter.encounter_name
	%EnemyHealthBar.max_value = enemy_max_health
	%EnemyHealthBar.value = enemy_health
	var enemy_style := StyleBoxFlat.new()
	enemy_style.bg_color = Color(0.9, 0.2, 0.2)
	%EnemyHealthBar.add_theme_stylebox_override("fill", enemy_style)
	%EnemyHealthLabel.text = "%d / %d" % [enemy_health, enemy_max_health]

	if enemy_shield > 0:
		%EnemyHealthLabel.text = "%d / %d [Shield: %d]" % [enemy_health, enemy_max_health, enemy_shield]

	var enemy_hull_pct: float = float(enemy_health) / float(enemy_max_health) if enemy_max_health > 0 else 0.0
	var enemy_shield_pct: float = float(enemy_shield) / 10.0 if enemy_shield > 0 else 0.0
	%EnemyShipDisplay.update_enemy(enemy_hull_pct, enemy_shield_pct, encounter.encounter_name)

	%IntentLabel.text = "Enemy will deal %d damage" % enemy_intent_damage
	if GameManager.current_shield >= enemy_intent_damage:
		%IntentLabel.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	elif GameManager.current_shield > 0:
		%IntentLabel.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		%IntentLabel.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	if encounter.ability_description != "":
		%AbilityLabel.text = encounter.ability_description
		%AbilityLabel.visible = true
	else:
		%AbilityLabel.visible = false


func _update_player_ui() -> void:
	%HullBar.max_value = GameManager.max_hull
	%HullBar.value = GameManager.current_hull
	var hull_pct: float = float(GameManager.current_hull) / float(GameManager.max_hull)
	var hull_style := StyleBoxFlat.new()
	hull_style.bg_color = Color(0.3, 0.9, 0.3) if hull_pct > 0.6 else (Color(0.9, 0.8, 0.2) if hull_pct > 0.3 else Color(0.9, 0.2, 0.2))
	%HullBar.add_theme_stylebox_override("fill", hull_style)
	%HullLabel.text = "Hull: %d / %d" % [GameManager.current_hull, GameManager.max_hull]
	%ShieldBar.max_value = GameManager.max_shield
	%ShieldBar.value = GameManager.current_shield
	%ShieldLabel.text = "Shield: %d / %d" % [GameManager.current_shield, GameManager.max_shield]
	%EnergyLabel.text = "Energy: %d / %d" % [current_energy, effective_energy_per_turn]

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


func _update_deck_info() -> void:
	%DeckCountLabel.text = "Deck: %d" % draw_pile.size()
	%DiscardCountLabel.text = "Discard: %d" % discard_pile.size()


func _update_hand_display() -> void:
	for child in %HandContainer.get_children():
		child.queue_free()

	for card in hand:
		var card_display := CardDisplayScene.instantiate()
		%HandContainer.add_child(card_display)
		var effective_cost: int = card.energy_cost
		if combo_active:
			effective_cost = max(0, effective_cost - 1)
		card_display.setup(card, effective_cost <= current_energy)
		card_display.card_played.connect(_on_card_played)
