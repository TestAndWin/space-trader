extends ColorRect

## Casino popup — Blackjack and Slot Machine mini-games.
## Full-screen immersive casino experience with showroom-style background.

signal casino_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

enum State { SELECT, PLAYING, RESULT }
enum Game { BLACKJACK, SLOTS }

# Slot symbols and their display icons
const SYMBOLS: Array = ["Credits", "Cargo", "Card", "Skull", "Star"]
const SYMBOL_ICONS: Dictionary = {
	"Credits": "\u25C9",   # ◉
	"Cargo": "\u25A3",     # ▣
	"Card": "\u2660",      # ♠
	"Skull": "\u2620",     # ☠
	"Star": "\u2605",      # ★
}
const SYMBOL_COLORS: Dictionary = {
	"Credits": Color(1.0, 0.95, 0.3),
	"Cargo": Color(0.7, 0.5, 0.25),
	"Card": Color(0.4, 0.65, 1.0),
	"Skull": Color(0.9, 0.15, 0.15),
	"Star": Color(1.0, 0.9, 0.1),
}

# Blackjack suits and values
const SUITS: Array = ["Hearts", "Diamonds", "Clubs", "Spades"]
const VALUES: Array = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUIT_SYMBOLS: Dictionary = {
	"Hearts": "\u2665",
	"Diamonds": "\u2666",
	"Clubs": "\u2663",
	"Spades": "\u2660",
}

# Casino colors — premium gold + dark blue
const PANEL_COLOR := Color(0.02, 0.06, 0.14, 0.45)
const BORDER_COLOR := Color(0.65, 0.52, 0.08, 0.35)
const GOLD := Color(1.0, 0.90, 0.25)
const GOLD_DIM := Color(0.65, 0.52, 0.08)
const ACCENT := Color(1.0, 0.85, 0.2)
const ACCENT_DIM := Color(0.65, 0.52, 0.08, 0.6)
const CARD_BG := Color(0.95, 0.93, 0.88)
const CARD_BACK := Color(0.02, 0.10, 0.28)

var _state: State = State.SELECT
var _game: Game = Game.BLACKJACK
var _bet: int = 0
var _planet_type: int = 0

# Blackjack state
var _player_hand: Array = []
var _dealer_hand: Array = []
var _bj_deck: Array = []
var _dealer_revealed: bool = false

# Slots state
var _reels: Array = ["?", "?", "?"]
var _reels_revealed: int = 0
var _result_msg: String = ""

# Round limit
var rounds_played: int = 0
var _max_rounds: int = 5

# UI references
var _main_vbox: VBoxContainer
var _content_area: VBoxContainer
var _credits_label: Label
var _status_label: Label

func setup(planet_type: int, max_rounds: int = 5) -> void:
	_planet_type = planet_type
	_max_rounds = max_rounds
	_state = State.SELECT
	_refresh_ui()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.0)
	_build_ui()


func _build_ui() -> void:
	# Background image
	BackgroundUtils.add_building_background(self, "casino", 0.4)

	# Semi-transparent casino panel
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	add_child(margin)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	_main_vbox = VBoxContainer.new()
	_main_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(_main_vbox)

	# ── Header ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_main_vbox.add_child(header)

	# Title section with subtitle
	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 0)
	header.add_child(title_vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_vbox.add_child(title_row)

	var left_deco := Label.new()
	left_deco.text = "\u2666 \u2663 \u2665 \u2660"
	left_deco.add_theme_font_size_override("font_size", 16)
	left_deco.add_theme_color_override("font_color", GOLD_DIM)
	title_row.add_child(left_deco)

	var title := Label.new()
	title.text = "SPACE CASINO"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GOLD)
	title_row.add_child(title)

	var right_deco := Label.new()
	right_deco.text = "\u2660 \u2665 \u2663 \u2666"
	right_deco.add_theme_font_size_override("font_size", 16)
	right_deco.add_theme_color_override("font_color", GOLD_DIM)
	title_row.add_child(right_deco)

	var subtitle := Label.new()
	subtitle.text = "High Stakes \u2022 Fair Games \u2022 Galactic Gaming License #4827"
	var sub_settings := LabelSettings.new()
	sub_settings.font_size = 11
	sub_settings.font_color = Color(0.8, 0.85, 0.9, 1.0)
	sub_settings.shadow_size = 3
	sub_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	sub_settings.shadow_offset = Vector2(1, 1)
	subtitle.label_settings = sub_settings
	title_vbox.add_child(subtitle)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 20)
	_credits_label.add_theme_color_override("font_color", GOLD)
	header.add_child(_credits_label)

	var close_btn := _create_casino_button(
		"Leave Casino",
		Vector2(130, 36),
		Color(0.5, 0.15, 0.1),
		_close
	)
	header.add_child(close_btn)

	# Separator line
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_color_override("separator", GOLD_DIM)
	_main_vbox.add_child(sep)

	# Status label
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_vbox.add_child(_status_label)

	# Content area (fills remaining space)
	_content_area = VBoxContainer.new()
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_area.add_theme_constant_override("separation", 16)
	_content_area.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_vbox.add_child(_content_area)


func _create_casino_button(
	text: String,
	min_size: Vector2,
	accent: Color,
	on_pressed: Callable = Callable(),
	disabled: bool = false
) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	UIStyles.style_accent_button(btn, accent)
	btn.disabled = disabled
	if on_pressed.is_valid():
		btn.pressed.connect(on_pressed)
	return btn


func _refresh_ui() -> void:
	if not _credits_label:
		return
	_credits_label.text = "%d cr" % GameManager.credits

	for child in _content_area.get_children():
		child.queue_free()

	match _state:
		State.SELECT:
			_build_select_ui()
		State.PLAYING:
			if _game == Game.BLACKJACK:
				_build_blackjack_ui()
			else:
				_build_slots_ui()
		State.RESULT:
			_build_result_ui()


func _build_select_ui() -> void:
	var has_blackjack: bool = _planet_type != EconomyManager.PT_AGRICULTURAL

	if not has_blackjack:
		_status_label.text = "Slot Machine — Place your bet!"
		_game = Game.SLOTS
	else:
		_status_label.text = "Welcome! Choose your table."

	# Game selection (only if both available)
	if has_blackjack:
		var game_row := HBoxContainer.new()
		game_row.alignment = BoxContainer.ALIGNMENT_CENTER
		game_row.add_theme_constant_override("separation", 24)
		_content_area.add_child(game_row)

		# Blackjack table
		var bj_panel := _create_game_table(
			"\u2660 Blackjack \u2665",
			"Beat the dealer to 21",
			_game == Game.BLACKJACK,
			func(): _game = Game.BLACKJACK; _refresh_ui()
		)
		game_row.add_child(bj_panel)

		# Slots table
		var slots_panel := _create_game_table(
			"\u2605 Slot Machine \u2605",
			"Match symbols to win big",
			_game == Game.SLOTS,
			func(): _game = Game.SLOTS; _refresh_ui()
		)
		game_row.add_child(slots_panel)

	# Bet section
	var bet_label := Label.new()
	var game_name: String = "Blackjack" if _game == Game.BLACKJACK else "Slot Machine"
	bet_label.text = "Place your bet on %s:" % game_name
	bet_label.add_theme_font_size_override("font_size", 18)
	bet_label.add_theme_color_override("font_color", GOLD)
	bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_area.add_child(bet_label)

	var bet_row := HBoxContainer.new()
	bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bet_row.add_theme_constant_override("separation", 12)
	_content_area.add_child(bet_row)

	var bets: Array = [25, 50, 100, 200]
	for amount in bets:
		var is_disabled: bool = GameManager.credits < amount
		var accent := Color(0.25, 0.18, 0.0) if GameManager.credits >= amount else Color(0.05, 0.08, 0.12)
		var btn := _create_casino_button(
			"%d cr" % amount,
			Vector2(100, 48),
			accent,
			_on_bet_and_play.bind(amount),
			is_disabled
		)
		bet_row.add_child(btn)

	# Payout info
	var info := Label.new()
	if _game == Game.BLACKJACK:
		info.text = "Win: 2x  |  Blackjack: 2.5x  |  Push: bet returned"
	else:
		info.text = "3 match: 3x  |  2 match: 1.5x  |  3\u2605 Jackpot: 10x  |  3\u2620: -2x"
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_area.add_child(info)


func _create_game_table(title_text: String, desc_text: String, selected: bool, on_click: Callable) -> PanelContainer:
	var table := PanelContainer.new()
	table.custom_minimum_size = Vector2(200, 100)
	var style := StyleBoxFlat.new()
	if selected:
		style.bg_color = Color(0.08, 0.06, 0.02, 0.8)
		style.border_color = GOLD
		style.shadow_color = Color(0.8, 0.6, 0.1, 0.12)
		style.shadow_size = 8
	else:
		style.bg_color = Color(0.03, 0.04, 0.08, 0.7)
		style.border_color = Color(0.3, 0.25, 0.1, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	table.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	table.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title_text
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", GOLD if selected else GOLD_DIM)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var desc := Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	# Make clickable
	table.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_click.call()
	)
	table.mouse_filter = Control.MOUSE_FILTER_STOP

	return table


func _on_bet_and_play(amount: int) -> void:
	_bet = amount
	if _game == Game.BLACKJACK:
		_start_blackjack()
	else:
		_start_slots()


# ── Blackjack ───────────────────────────────────────────────────────────────

func _start_blackjack() -> void:
	if not GameManager.remove_credits(_bet):
		return
	_game = Game.BLACKJACK
	_state = State.PLAYING
	_dealer_revealed = false
	_init_bj_deck()
	_player_hand.clear()
	_dealer_hand.clear()
	_player_hand.append(_draw_bj_card())
	_dealer_hand.append(_draw_bj_card())
	_player_hand.append(_draw_bj_card())
	_dealer_hand.append(_draw_bj_card())
	if _bj_hand_value(_player_hand) == 21:
		_dealer_revealed = true
		_resolve_blackjack()
		return
	_refresh_ui()


func _init_bj_deck() -> void:
	_bj_deck.clear()
	for suit in SUITS:
		for val in VALUES:
			_bj_deck.append({ "suit": suit, "value": val })
	_bj_deck.shuffle()


func _draw_bj_card() -> Dictionary:
	if _bj_deck.is_empty():
		_init_bj_deck()
	return _bj_deck.pop_back()


func _bj_card_value(card: Dictionary) -> int:
	match card["value"]:
		"A": return 11
		"K", "Q", "J": return 10
		_: return int(card["value"])


func _bj_hand_value(hand: Array) -> int:
	var total: int = 0
	var aces: int = 0
	for card in hand:
		var v: int = _bj_card_value(card)
		if card["value"] == "A":
			aces += 1
		total += v
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


func _create_card_display(card: Dictionary, face_up: bool) -> PanelContainer:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(65, 90)
	var style := StyleBoxFlat.new()
	if face_up:
		style.bg_color = CARD_BG
	else:
		style.bg_color = CARD_BACK
	style.border_color = Color(0.3, 0.3, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 3
	container.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(vbox)

	if face_up:
		var is_red: bool = card["suit"] == "Hearts" or card["suit"] == "Diamonds"
		var card_color: Color = Color(0.8, 0.1, 0.1) if is_red else Color(0.1, 0.1, 0.15)

		var value_lbl := Label.new()
		value_lbl.text = card["value"]
		value_lbl.add_theme_font_size_override("font_size", 22)
		value_lbl.add_theme_color_override("font_color", card_color)
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(value_lbl)

		var suit_lbl := Label.new()
		suit_lbl.text = SUIT_SYMBOLS.get(card["suit"], "?")
		suit_lbl.add_theme_font_size_override("font_size", 28)
		suit_lbl.add_theme_color_override("font_color", card_color)
		suit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(suit_lbl)
	else:
		var back_lbl := Label.new()
		back_lbl.text = "\u2660\u2665\n\u2666\u2663"
		back_lbl.add_theme_font_size_override("font_size", 18)
		back_lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.7))
		back_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(back_lbl)

	return container


func _build_blackjack_ui() -> void:
	_status_label.text = "Blackjack — Bet: %d cr" % _bet

	# Dealer section
	var dealer_header := Label.new()
	dealer_header.text = "DEALER"
	dealer_header.add_theme_font_size_override("font_size", 16)
	dealer_header.add_theme_color_override("font_color", Color(0.85, 0.35, 0.35))
	dealer_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_area.add_child(dealer_header)

	var dealer_row := HBoxContainer.new()
	dealer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dealer_row.add_theme_constant_override("separation", 10)
	_content_area.add_child(dealer_row)

	for i in _dealer_hand.size():
		var face_up: bool = i == 0 or _dealer_revealed
		var card_display := _create_card_display(_dealer_hand[i], face_up)
		dealer_row.add_child(card_display)

	var dealer_val_lbl := Label.new()
	if _dealer_revealed:
		dealer_val_lbl.text = "  = %d" % _bj_hand_value(_dealer_hand)
		dealer_val_lbl.add_theme_color_override("font_color", Color(0.9, 0.55, 0.55))
	else:
		dealer_val_lbl.text = "  = %d + ?" % _bj_card_value(_dealer_hand[0])
		dealer_val_lbl.add_theme_color_override("font_color", Color(0.5, 0.4, 0.45))
	dealer_val_lbl.add_theme_font_size_override("font_size", 20)
	dealer_row.add_child(dealer_val_lbl)

	# Divider
	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", GOLD_DIM)
	_content_area.add_child(divider)

	# Player section
	var player_header := Label.new()
	player_header.text = "YOUR HAND"
	player_header.add_theme_font_size_override("font_size", 16)
	player_header.add_theme_color_override("font_color", Color(0.0, 0.85, 0.45))
	player_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_area.add_child(player_header)

	var player_row := HBoxContainer.new()
	player_row.alignment = BoxContainer.ALIGNMENT_CENTER
	player_row.add_theme_constant_override("separation", 10)
	_content_area.add_child(player_row)

	for c in _player_hand:
		var card_display := _create_card_display(c, true)
		player_row.add_child(card_display)

	var player_val: int = _bj_hand_value(_player_hand)
	var pval_lbl := Label.new()
	pval_lbl.text = "  = %d" % player_val
	pval_lbl.add_theme_font_size_override("font_size", 22)
	if player_val == 21:
		pval_lbl.add_theme_color_override("font_color", GOLD)
	elif player_val > 21:
		pval_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		pval_lbl.add_theme_color_override("font_color", Color(0.5, 0.88, 1.0))
	player_row.add_child(pval_lbl)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.name = "BjActionButtons"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	_content_area.add_child(btn_row)

	var hit_btn := _create_casino_button(
		"HIT",
		Vector2(120, 50),
		Color(0.0, 0.22, 0.10),
		_on_bj_hit
	)
	btn_row.add_child(hit_btn)

	var stand_btn := _create_casino_button(
		"STAND",
		Vector2(120, 50),
		Color(0.25, 0.18, 0.0),
		_on_bj_stand
	)
	btn_row.add_child(stand_btn)


func _on_bj_hit() -> void:
	_player_hand.append(_draw_bj_card())
	var val: int = _bj_hand_value(_player_hand)
	if val > 21:
		_dealer_revealed = true
		_refresh_ui()  # Show the bust card first
		await get_tree().create_timer(1.0).timeout
		_resolve_blackjack()
		return
	if val == 21:
		_refresh_ui()  # Show the 21 hand first
		await get_tree().create_timer(0.8).timeout
		_on_bj_stand()
		return
	_refresh_ui()


func _on_bj_stand() -> void:
	_dealer_revealed = true
	var dealer_stands_at: int = 17
	if GameManager.has_crew_bonus(CrewData.CrewBonus.GAMBLING_EDGE):
		dealer_stands_at = 18
	while _bj_hand_value(_dealer_hand) < dealer_stands_at:
		_dealer_hand.append(_draw_bj_card())
	_resolve_blackjack()


func _resolve_blackjack() -> void:
	var player_val: int = _bj_hand_value(_player_hand)
	var dealer_val: int = _bj_hand_value(_dealer_hand)
	var winnings: int = 0
	var msg: String = ""

	if player_val > 21:
		msg = "BUST! You lose %d cr." % _bet
	elif dealer_val > 21:
		winnings = _bet * 2
		msg = "Dealer busts! You win %d cr!" % winnings
	elif player_val == 21 and _player_hand.size() == 2:
		winnings = int(_bet * 2.5)
		msg = "BLACKJACK! You win %d cr!" % winnings
	elif player_val > dealer_val:
		winnings = _bet * 2
		msg = "You win! +%d cr" % winnings
	elif player_val == dealer_val:
		winnings = _bet
		msg = "Push! Bet returned."
	else:
		msg = "Dealer wins. You lose %d cr." % _bet

	if winnings > 0:
		GameManager.add_credits(winnings)
	EventLog.add_entry("Casino BJ: %s" % msg)
	_show_result(msg)


# ── Slots ────────────────────────────────────────────────────────────────────

func _start_slots() -> void:
	if not GameManager.remove_credits(_bet):
		return
	_game = Game.SLOTS
	_state = State.PLAYING
	_reels = ["?", "?", "?"]
	_reels_revealed = 0
	_refresh_ui()
	_spin_reels()


func _get_slot_symbol() -> String:
	var pool: Array = ["Credits", "Credits", "Credits", "Cargo", "Cargo", "Cargo", "Card", "Card", "Skull", "Star"]
	if GameManager.has_crew_bonus(CrewData.CrewBonus.GAMBLING_EDGE):
		pool.erase("Skull")
	return pool[randi() % pool.size()]


func _spin_reels() -> void:
	for i in 3:
		_reels[i] = _get_slot_symbol()
	_reels_revealed = 0
	_reveal_next_reel()


func _reveal_next_reel() -> void:
	_reels_revealed += 1
	_refresh_ui()
	if _reels_revealed < 3:
		await get_tree().create_timer(0.5).timeout
		_reveal_next_reel()
	else:
		await get_tree().create_timer(0.3).timeout
		_resolve_slots()


func _build_slots_ui() -> void:
	if _state != State.RESULT:
		_status_label.text = "Slot Machine — Bet: %d cr" % _bet

	# Slot machine frame
	var machine := PanelContainer.new()
	machine.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var machine_style := StyleBoxFlat.new()
	machine_style.bg_color = Color(0.03, 0.04, 0.08, 0.8)
	machine_style.border_color = GOLD_DIM
	machine_style.set_border_width_all(3)
	machine_style.set_corner_radius_all(12)
	machine_style.content_margin_left = 32
	machine_style.content_margin_right = 32
	machine_style.content_margin_top = 24
	machine_style.content_margin_bottom = 24
	machine_style.shadow_color = Color(0.6, 0.4, 0.05, 0.12)
	machine_style.shadow_size = 8
	machine.add_theme_stylebox_override("panel", machine_style)
	_content_area.add_child(machine)

	var machine_vbox := VBoxContainer.new()
	machine_vbox.add_theme_constant_override("separation", 16)
	machine_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	machine.add_child(machine_vbox)

	var machine_title := Label.new()
	machine_title.text = "\u2605 LUCKY STARS \u2605"
	machine_title.add_theme_font_size_override("font_size", 20)
	machine_title.add_theme_color_override("font_color", GOLD)
	machine_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine_vbox.add_child(machine_title)

	# Reel display
	var reel_row := HBoxContainer.new()
	reel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reel_row.add_theme_constant_override("separation", 12)
	machine_vbox.add_child(reel_row)

	for i in 3:
		var reel_panel := PanelContainer.new()
		reel_panel.custom_minimum_size = Vector2(100, 80)
		var reel_style := StyleBoxFlat.new()
		reel_style.bg_color = Color(0.02, 0.03, 0.08)
		reel_style.border_color = Color(0.4, 0.3, 0.1, 0.6)
		reel_style.set_border_width_all(2)
		reel_style.set_corner_radius_all(4)
		reel_style.set_content_margin_all(8)
		reel_panel.add_theme_stylebox_override("panel", reel_style)
		reel_row.add_child(reel_panel)

		var reel_vbox := VBoxContainer.new()
		reel_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		reel_panel.add_child(reel_vbox)

		if i < _reels_revealed:
			var icon_lbl := Label.new()
			icon_lbl.text = SYMBOL_ICONS.get(_reels[i], "?")
			icon_lbl.add_theme_font_size_override("font_size", 36)
			icon_lbl.add_theme_color_override("font_color", SYMBOL_COLORS.get(_reels[i], Color.WHITE))
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			reel_vbox.add_child(icon_lbl)

			var name_lbl := Label.new()
			name_lbl.text = _reels[i]
			name_lbl.add_theme_font_size_override("font_size", 11)
			name_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			reel_vbox.add_child(name_lbl)
		else:
			var spin_lbl := Label.new()
			spin_lbl.text = "?"
			spin_lbl.add_theme_font_size_override("font_size", 36)
			spin_lbl.add_theme_color_override("font_color", Color(0.3, 0.25, 0.1, 0.7))
			spin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			reel_vbox.add_child(spin_lbl)

	var status := Label.new()
	if _state == State.RESULT:
		status.text = _result_msg
	elif _reels_revealed < 3:
		status.text = "Spinning..."
	else:
		status.text = "Results!"
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", GOLD_DIM if _reels_revealed < 3 else GOLD)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine_vbox.add_child(status)


func _resolve_slots() -> void:
	var winnings: int = 0
	var msg: String = ""

	if _reels[0] == _reels[1] and _reels[1] == _reels[2]:
		var sym: String = _reels[0]
		if sym == "Star":
			winnings = _bet * 10
			msg = "\u2605 JACKPOT! 3x Star! +%d cr! \u2605" % winnings
		elif sym == "Skull":
			var loss: int = _bet
			GameManager.remove_credits(mini(loss, GameManager.credits))
			msg = "\u2620 3x Skull! Lost an extra %d cr! \u2620" % loss
		elif sym == "Card":
			winnings = _bet * 3
			msg = "3x Card! +%d cr + random card!" % winnings
			var cards: Array = ResourceRegistry.load_all(ResourceRegistry.CARDS)
			if not cards.is_empty():
				var random_card: Resource = cards[randi() % cards.size()]
				GameManager.deck.append(random_card)
				msg += " Got %s!" % random_card.card_name
		else:
			winnings = _bet * 3
			msg = "3x %s! +%d cr!" % [sym, winnings]
	elif _reels[0] == _reels[1] or _reels[1] == _reels[2] or _reels[0] == _reels[2]:
		winnings = int(_bet * 1.5)
		msg = "Two match! +%d cr" % winnings
	else:
		msg = "No match. Lost %d cr." % _bet

	if winnings > 0:
		GameManager.add_credits(winnings)
	EventLog.add_entry("Casino Slots: %s" % msg)
	_show_result(msg)


# ── Result ───────────────────────────────────────────────────────────────────

func _show_result(msg: String) -> void:
	_state = State.RESULT
	rounds_played += 1
	_result_msg = msg
	_status_label.text = msg
	_refresh_ui()


func _build_result_ui() -> void:
	_credits_label.text = "%d cr" % GameManager.credits

	# Show final cards/reels
	if _game == Game.BLACKJACK:
		_build_blackjack_ui()
		# Remove the hit/stand buttons
		var action_btns := _content_area.get_node_or_null("BjActionButtons")
		if action_btns:
			action_btns.queue_free()
		# Restore result message (overwritten by _build_blackjack_ui)
		_status_label.text = _result_msg
	elif _game == Game.SLOTS:
		_status_label.text = "Slot Machine — Bet: %d cr" % _bet
		_build_slots_ui()

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	_content_area.add_child(btn_row)

	var remaining: int = _max_rounds - rounds_played
	var again_btn: Button
	if remaining > 0:
		again_btn = _create_casino_button(
			"Play Again (%d left)" % remaining,
			Vector2(160, 50),
			Color(0.25, 0.18, 0.0),
			_on_play_again_pressed
		)
	else:
		again_btn = _create_casino_button(
			"No rounds left",
			Vector2(160, 50),
			Color(0.04, 0.06, 0.10),
			Callable(),
			true
		)
	btn_row.add_child(again_btn)

	var close_btn := _create_casino_button(
		"Leave Casino",
		Vector2(140, 50),
		Color(0.4, 0.15, 0.1),
		_close
	)
	btn_row.add_child(close_btn)


func _close() -> void:
	casino_closed.emit()
	queue_free()


func _on_play_again_pressed() -> void:
	_state = State.SELECT
	_bet = 0
	_refresh_ui()
