extends ColorRect

## Smuggler event popup — a shady deal offered when landing on a planet.
## Call try_spawn() from planet_screen. If it returns true the popup is visible
## and ready for player interaction; otherwise nothing happens.

signal deal_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const SPAWN_CHANCE := 0.15
const CATCH_CHANCE := 0.25
const FINE_MIN := 50
const FINE_MAX := 150

const DISCOUNT_MIN := 0.40
const DISCOUNT_MAX := 0.60
const PREMIUM_MIN := 1.80
const PREMIUM_MAX := 2.50

const QTY_MIN := 1
const QTY_MAX := 5

enum DealType { DISCOUNT_BUY, PREMIUM_SELL }

var _deal_type: DealType
var _good_name: String
var _quantity: int
var _total_price: int

var _description_label: Label
var _accept_button: Button
var _decline_button: Button


# ── Public API ───────────────────────────────────────────────────────────────

func try_spawn() -> bool:
	if randf() > SPAWN_CHANCE:
		return false
	_generate_deal()
	if _good_name.is_empty():
		return false
	visible = true
	return true


# ── Deal generation ──────────────────────────────────────────────────────────

func _generate_deal() -> void:
	if EconomyManager.goods.is_empty():
		_good_name = ""
		return

	_deal_type = DealType.DISCOUNT_BUY if randf() < 0.5 else DealType.PREMIUM_SELL

	if _deal_type == DealType.PREMIUM_SELL:
		# Need something in cargo to sell
		if GameManager.cargo.is_empty():
			_deal_type = DealType.DISCOUNT_BUY
		else:
			var item: Dictionary = GameManager.cargo[randi() % GameManager.cargo.size()]
			_good_name = item["good_name"]
			_quantity = clampi(randi_range(QTY_MIN, QTY_MAX), 1, item["quantity"])
			var base_price := _get_base_price(_good_name)
			var multiplier := randf_range(PREMIUM_MIN, PREMIUM_MAX)
			_total_price = int(round(base_price * multiplier * _quantity))

	if _deal_type == DealType.DISCOUNT_BUY:
		var good: Resource = EconomyManager.goods[randi() % EconomyManager.goods.size()]
		_good_name = good.good_name
		_quantity = randi_range(QTY_MIN, QTY_MAX)
		var multiplier := randf_range(DISCOUNT_MIN, DISCOUNT_MAX)
		_total_price = int(round(good.base_price * multiplier * _quantity))
		_total_price = maxi(_total_price, 1)

	_update_description()


func _get_base_price(gname: String) -> int:
	for good in EconomyManager.goods:
		if good.good_name == gname:
			return good.base_price
	return 10


func _update_description() -> void:
	if _description_label == null:
		return
	if _deal_type == DealType.DISCOUNT_BUY:
		_description_label.text = (
			"A shady figure offers you %d %s for only %d cr. "
			+ "\"Don't ask where it came from,\" they mutter."
		) % [_quantity, _good_name, _total_price]
	else:
		_description_label.text = (
			"Someone whispers they'll pay %d cr for your %s (x%d). "
			+ "\"Quick, before anyone notices.\""
		) % [_total_price, _good_name, _quantity]


# ── UI construction ──────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var scaffold := UIStyles.create_event_modal_scaffold(self, 350.0, Color(1.0, 0.6, 0.15))
	var vbox: VBoxContainer = scaffold["vbox"]
	var title: Label = scaffold["title_label"]
	title.text = "SHADY DEAL"
	_description_label = scaffold["description_label"]
	_description_label.custom_minimum_size = Vector2(310, 0)

	# Buttons
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	_accept_button = Button.new()
	_accept_button.text = "Accept"
	_accept_button.custom_minimum_size = Vector2(120, 36)
	var accept_style := StyleBoxFlat.new()
	accept_style.bg_color = Color(0.7, 0.25, 0.1)
	accept_style.set_corner_radius_all(4)
	accept_style.set_content_margin_all(6)
	_accept_button.add_theme_stylebox_override("normal", accept_style)
	var accept_hover := StyleBoxFlat.new()
	accept_hover.bg_color = Color(0.85, 0.35, 0.15)
	accept_hover.set_corner_radius_all(4)
	accept_hover.set_content_margin_all(6)
	_accept_button.add_theme_stylebox_override("hover", accept_hover)
	var accept_pressed := StyleBoxFlat.new()
	accept_pressed.bg_color = Color(0.55, 0.18, 0.08)
	accept_pressed.set_corner_radius_all(4)
	accept_pressed.set_content_margin_all(6)
	_accept_button.add_theme_stylebox_override("pressed", accept_pressed)
	_accept_button.pressed.connect(_on_accept)
	hbox.add_child(_accept_button)

	_decline_button = Button.new()
	_decline_button.text = "Decline"
	_decline_button.custom_minimum_size = Vector2(120, 36)
	var decline_style := StyleBoxFlat.new()
	decline_style.bg_color = Color(0.25, 0.25, 0.28)
	decline_style.set_corner_radius_all(4)
	decline_style.set_content_margin_all(6)
	_decline_button.add_theme_stylebox_override("normal", decline_style)
	var decline_hover := StyleBoxFlat.new()
	decline_hover.bg_color = Color(0.35, 0.35, 0.38)
	decline_hover.set_corner_radius_all(4)
	decline_hover.set_content_margin_all(6)
	_decline_button.add_theme_stylebox_override("hover", decline_hover)
	var decline_pressed := StyleBoxFlat.new()
	decline_pressed.bg_color = Color(0.18, 0.18, 0.2)
	decline_pressed.set_corner_radius_all(4)
	decline_pressed.set_content_margin_all(6)
	_decline_button.add_theme_stylebox_override("pressed", decline_pressed)
	_decline_button.pressed.connect(_on_decline)
	hbox.add_child(_decline_button)


# ── Button handlers ──────────────────────────────────────────────────────────

func _on_accept() -> void:
	if _deal_type == DealType.DISCOUNT_BUY:
		if not GameManager.can_add_cargo(_good_name, _quantity):
			EventLog.add_entry("Smuggler deal failed — not enough cargo space.")
			close()
			return
		if not GameManager.remove_credits(_total_price):
			EventLog.add_entry("Smuggler deal failed — not enough credits.")
			close()
			return
		GameManager.add_cargo(_good_name, _quantity)
		EventLog.add_entry(
			"Bought %d %s from a smuggler for %d cr." % [_quantity, _good_name, _total_price]
		)
	else:
		GameManager.remove_cargo(_good_name, _quantity)
		GameManager.add_credits(_total_price)
		EventLog.add_entry(
			"Sold %d %s to a smuggler for %d cr." % [_quantity, _good_name, _total_price]
		)

	GameManager.total_smuggler_deals += 1
	AchievementManager.check_smuggler_deals(GameManager.total_smuggler_deals)

	# Risk: chance of getting caught
	if randf() < CATCH_CHANCE:
		_show_caught_options()
		return

	close()


func _show_caught_options() -> void:
	var fine := randi_range(FINE_MIN, FINE_MAX)
	if GameManager.has_crew_bonus(4):  # SMUGGLE_PROTECTION
		fine = int(fine * GameManager.get_crew_bonus_value(4))
	var bribe_cost := fine * 2

	# Replace current UI content
	_description_label.text = "Authorities caught wind of the deal! Choose how to handle it."
	_accept_button.visible = false
	_decline_button.visible = false

	var caught_vbox := VBoxContainer.new()
	caught_vbox.add_theme_constant_override("separation", 8)
	_description_label.get_parent().add_child(caught_vbox)

	# Option 1: Pay fine (fine + bounty)
	var fine_btn := Button.new()
	fine_btn.text = "Pay Fine (%d cr)" % fine
	fine_btn.custom_minimum_size = Vector2(280, 34)
	_style_caught_button(fine_btn, Color(0.7, 0.25, 0.1))
	fine_btn.pressed.connect(func():
		GameManager.remove_credits(fine)
		StandingManager.add_bounty(100, "caught smuggling")
		StandingManager.add_trade_loyalty(GameManager.current_planet, -15)
		EventLog.add_entry("Paid smuggling fine: %d cr." % fine)
		close()
	)
	if GameManager.credits < fine:
		fine_btn.disabled = true
	caught_vbox.add_child(fine_btn)

	# Option 2: Bribe (2x fine, no bounty, 80% success)
	var bribe_btn := Button.new()
	bribe_btn.text = "Bribe Official (%d cr, no bounty)" % bribe_cost
	bribe_btn.custom_minimum_size = Vector2(280, 34)
	_style_caught_button(bribe_btn, Color(0.6, 0.5, 0.1))
	bribe_btn.pressed.connect(func():
		if randf() < 0.80:
			GameManager.remove_credits(bribe_cost)
			EventLog.add_entry("Bribed official for %d cr. No record." % bribe_cost)
		else:
			GameManager.remove_credits(bribe_cost)
			StandingManager.add_bounty(150, "failed bribe attempt")
			StandingManager.add_trade_loyalty(GameManager.current_planet, -20)
			EventLog.add_entry("Bribe failed! Fined %d cr + bounty." % bribe_cost)
		close()
	)
	if GameManager.credits < bribe_cost:
		bribe_btn.disabled = true
	caught_vbox.add_child(bribe_btn)

	# Option 3: Accept punishment (fine + bounty + reputation hit)
	var accept_btn := Button.new()
	accept_btn.text = "Accept Punishment"
	accept_btn.custom_minimum_size = Vector2(280, 34)
	_style_caught_button(accept_btn, Color(0.25, 0.25, 0.28))
	accept_btn.pressed.connect(func():
		GameManager.remove_credits(mini(fine, GameManager.credits))
		StandingManager.add_bounty(100, "caught smuggling")
		StandingManager.add_trade_loyalty(GameManager.current_planet, -15)
		EventLog.add_entry("Caught smuggling. Fined %d cr." % fine)
		close()
	)
	caught_vbox.add_child(accept_btn)


func _style_caught_button(btn: Button, bg_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.15)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)


func _on_decline() -> void:
	EventLog.add_entry("Declined a shady deal.")
	close()


func close() -> void:
	deal_closed.emit()
	queue_free()
