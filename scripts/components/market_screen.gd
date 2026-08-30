extends ColorRect

## Market screen — fullscreen overlay for buying and selling goods.
## Consistent showroom-style with Casino, Ship Dealer, Ship Upgrades.

signal market_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")
const CargoSlotScene = preload("res://scenes/components/cargo_slot.tscn")

const MARKET_FLAVOR: Dictionary = {
	0: "Factory surplus and manufactured goods",
	1: "Fresh produce and organic supplies",
	2: "Extracted minerals and heavy equipment",
	3: "Cutting-edge technology and research materials",
	4: "No questions asked. Contraband welcome.",
}

const MARKET_ICONS: Dictionary = {
	0: "\u25C8",  # ◈
	1: "\u2618",  # ☘
	2: "\u26CF",  # ⛏
	3: "\u2699",  # ⚙
	4: "\u2620",  # ☠
}

var _planet_type: int = 0
var _arrival_gained_cargo: Dictionary = {}
var _title_label: Label
var _subtitle_label: Label
var _icon_labels: Array = []
var _buy_header_label: Label
var _credits_label: Label
var _cargo_label: Label
var _market_list: VBoxContainer
var _cargo_list: VBoxContainer
var _status_label: Label
var _status_detail_label: Label
var _saturation_flow: HFlowContainer
var _saturation_hint_label: Label

func setup(planet_type: int, arrival_gained_cargo: Dictionary = {}) -> void:
	_planet_type = planet_type
	_arrival_gained_cargo = arrival_gained_cargo
	_apply_planet_theme()
	_refresh_all()


## The overlay is built in _ready() before setup() delivers the planet type,
## so every planet-dependent header value is (re-)applied here.
func _apply_planet_theme() -> void:
	if not _title_label:
		return
	_title_label.text = CityMap.get_building_name(CityMap.BUILDING_MARKET, _planet_type).to_upper()
	_title_label.add_theme_color_override(
		"font_color", UIStyles.TYPE_COLORS.get(_planet_type, UIStyles.ACCENT)
	)
	_subtitle_label.text = MARKET_FLAVOR.get(_planet_type, "")
	for icon: Label in _icon_labels:
		icon.text = MARKET_ICONS.get(_planet_type, "◈")
	if _buy_header_label:
		_buy_header_label.add_theme_color_override(
			"font_color", UIStyles.TYPE_COLORS.get(_planet_type, UIStyles.ACCENT)
		)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.0)
	_build_ui()


func _build_ui() -> void:
	BackgroundUtils.add_building_background(self, "market", 0.4)

	var scaffold: Dictionary = UIStyles.create_overlay_scaffold(
		self,
		"",
		"",
		"",
		"Back to City",
		close
	)
	var main_vbox: VBoxContainer = scaffold["main_vbox"]
	var header: HBoxContainer = scaffold["header"]
	header.z_index = 10
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label = scaffold["title_label"]
	_subtitle_label = scaffold["subtitle_label"]
	_icon_labels = scaffold["icon_labels"]
	_credits_label = scaffold["credits_label"]
	_cargo_label = UIStyles.create_cargo_label()
	header.add_child(_cargo_label)
	_apply_planet_theme()

	# Status
	_status_detail_label = Label.new()
	_status_detail_label.add_theme_font_size_override("font_size", UIStyles.FONT_DETAIL)
	_status_detail_label.add_theme_color_override("font_color", UIStyles.STATUS_WARN)
	_status_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_status_detail_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", UIStyles.FONT_BODY)
	_status_label.add_theme_color_override("font_color", UIStyles.POSITIVE)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_status_label)

	_build_saturation_panel(main_vbox)

	# Spacer to push content to lower half (small share so the lists get more height)
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.size_flags_stretch_ratio = 1.0
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(top_spacer)

	# ── Content: Market (left) + Cargo (right) — 50% taller via stretch ratio ──
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_stretch_ratio = 3.0
	content.add_theme_constant_override("separation", 16)
	main_vbox.add_child(content)

	# Buy side (left) and sell side (right) share the same column frame
	_market_list = _build_trade_column(
		content, "\u25C6 BUY GOODS \u25C6", UIStyles.ACCENT, true
	)
	_cargo_list = _build_trade_column(content, "\u25C6 SELL CARGO \u25C6", UIStyles.POSITIVE)


## Panel above the trade columns listing every market the player has flooded,
## and how long each needs to pay full price again. This is the only place the
## saturation state is shown, so it also carries the one-line rule.
func _build_saturation_panel(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.04, 0.10, 0.5)
	style.border_color = UIStyles.ACCENT_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "◆ MARKET SATURATION ◆"
	UIStyles.apply_section_title(header, UIStyles.STATUS_WARN)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	_saturation_flow = HFlowContainer.new()
	_saturation_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	_saturation_flow.add_theme_constant_override("h_separation", 10)
	_saturation_flow.add_theme_constant_override("v_separation", 2)
	vbox.add_child(_saturation_flow)

	_saturation_hint_label = Label.new()
	_saturation_hint_label.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
	_saturation_hint_label.add_theme_color_override("font_color", Color(0.5, 0.54, 0.58))
	_saturation_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_saturation_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_saturation_hint_label)


func _populate_saturation_panel() -> void:
	if not _saturation_flow:
		return
	for child in _saturation_flow.get_children():
		child.queue_free()

	var flooded: Array[Dictionary] = EconomyManager.get_flooded_markets()
	_saturation_hint_label.text = (
		"Contraband sells %d at full price, other cargo %d. Every unit past that lowers the price; markets absorb 1 unit per day."
		% [
			int(EconomyManager.SATURATION_FULL_PRICE_UNITS_CONTRABAND),
			int(EconomyManager.SATURATION_FULL_PRICE_UNITS_NORMAL),
		]
	)
	if flooded.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No markets flooded — every good sells at full price."
		empty_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_DETAIL)
		empty_lbl.add_theme_color_override("font_color", UIStyles.POSITIVE)
		_saturation_flow.add_child(empty_lbl)
		return

	var here: String = GameManager.current_planet
	for entry in flooded:
		_saturation_flow.add_child(_build_saturation_chip(entry, entry["planet"] == here))


## One "Spice @ Dust Haven -36% 3d" chip. Markets on the current planet are
## highlighted: those are the ones blocking the sale in front of the player.
func _build_saturation_chip(entry: Dictionary, is_here: bool) -> Control:
	var modifier: float = float(entry["modifier"])
	var days: int = int(entry["days"])
	var label := Label.new()
	UIStyles.apply_mono_font(label)
	label.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
	var where: String = "HERE" if is_here else GameManager.get_display_planet_name(str(entry["planet"]))
	label.text = "%s @ %s  %d%%  %dd" % [
		entry["good"], where, int(round((modifier - 1.0) * 100.0)), days,
	]
	# Amber while the market is merely dented, red once it has bottomed out.
	var severity: Color = UIStyles.CAUTION if modifier > 0.7 else UIStyles.NEGATIVE
	label.add_theme_color_override("font_color", severity if is_here else severity.darkened(0.25))
	return label


## One trade column: framed panel with a section header over a scrolling list.
## Returns the list container the rows are added to.
## `planet_themed` marks the column whose header colour follows the planet
## type. That colour is only known after setup(), so the label is kept and
## recoloured in _apply_planet_theme().
func _build_trade_column(
	parent: HBoxContainer,
	header_text: String,
	header_color: Color,
	planet_themed: bool = false,
) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.04, 0.10, 0.5)
	style.border_color = UIStyles.ACCENT_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = header_text
	UIStyles.apply_section_title(header, header_color)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if planet_themed:
		_buy_header_label = header
	vbox.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	return list


func _refresh_all() -> void:
	if not _credits_label:
		return
	# _cargo_label keeps itself in sync via GameManager.cargo_changed.
	_record_market_snapshot()
	_status_detail_label.text = _build_market_context_text()
	_populate_saturation_panel()
	_populate_market()
	_populate_cargo()


func _populate_market() -> void:
	for child in _market_list.get_children():
		child.queue_free()
	var planet_name: String = GameManager.current_planet
	for good in EconomyManager.goods:
		var good_name: String = good.good_name
		var buy_price: int = EconomyManager.get_buy_price(planet_name, good_name)
		if buy_price < 0:
			continue
		var slot := CargoSlotScene.instantiate()
		_market_list.add_child(slot)
		var avg: int = EconomyManager.get_average_price(good_name)
		slot.setup(good_name, buy_price, 0, "buy", avg, true, "", _get_price_note(good_name, "buy", buy_price))
		slot.tooltip_text = _build_trade_tooltip(good_name, "buy")
		slot.action_pressed.connect(_on_buy)


func _populate_cargo() -> void:
	for child in _cargo_list.get_children():
		child.queue_free()
	var has_rows: bool = false
	var planet_name: String = GameManager.current_planet
	for item in GameManager.cargo:
		var good_name: String = item["good_name"]
		var qty: int = item["quantity"]
		# Reduce sellable quantity by goods gained on arrival this visit.
		var blocked: int = mini(_arrival_gained_cargo.get(good_name, 0), qty)
		var sellable_qty: int = maxi(qty - blocked, 0)
		var sell_price: int = maxi(EconomyManager.get_sell_price(planet_name, good_name), 0)
		var avg_sell: int = EconomyManager.get_average_price(good_name)
		if avg_sell > 0:
			avg_sell = int(round(avg_sell * EconomyManager.SELL_RATIO))
		if sellable_qty > 0:
			_add_cargo_row(good_name, sell_price, sellable_qty, avg_sell, true, "")
			has_rows = true
		if blocked > 0:
			_add_cargo_row(good_name, sell_price, blocked, avg_sell, false, "(arrival)")
			has_rows = true

	if not has_rows:
		var empty_lbl := Label.new()
		empty_lbl.text = "Cargo hold is empty"
		empty_lbl.add_theme_font_size_override("font_size", UIStyles.FONT_DETAIL)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.42, 0.45))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cargo_list.add_child(empty_lbl)


## One row in the sell list. Arrival-locked rows are shown but not tradeable.
func _add_cargo_row(good_name: String, sell_price: int, quantity: int, avg_sell: int,
		tradeable: bool, disabled_suffix: String) -> void:
	var slot := CargoSlotScene.instantiate()
	_cargo_list.add_child(slot)
	slot.setup(
		good_name,
		sell_price,
		quantity,
		"sell",
		avg_sell,
		tradeable,
		disabled_suffix,
		_get_price_note(good_name, "sell", sell_price)
	)
	slot.tooltip_text = _build_trade_tooltip(good_name, "sell")
	if tradeable:
		slot.action_pressed.connect(_on_sell)


func _on_buy(good_name: String, quantity: int) -> void:
	var planet_name: String = GameManager.current_planet
	var buy_price: int = EconomyManager.get_buy_price(planet_name, good_name)
	if buy_price < 0:
		return
	var unit_price: int = buy_price
	# BULK_DISCOUNT: -8% buy price with the Freighter. Trades are one unit per
	# click, so this can no longer be gated on a bulk quantity.
	var ship: Resource = GameManager.get_ship_data()
	if ship and ship.ship_ability == ShipData.ShipAbility.BULK_DISCOUNT:
		unit_price = int(round(float(unit_price) * 0.92))
	var total_cost: int = unit_price * quantity
	if not GameManager.can_add_cargo(good_name, quantity):
		return
	if not GameManager.remove_credits(total_cost):
		return
	GameManager.add_cargo(good_name, quantity)
	AudioManager.play_purchase()
	GameManager.total_trades += 1
	StandingManager.add_trade_loyalty(planet_name, StandingManager.get_trade_loyalty_gain(quantity, total_cost))
	GameManager.record_market_observation(planet_name, good_name, buy_price, EconomyManager.get_sell_price(planet_name, good_name))
	AchievementManager.check_trades(GameManager.total_trades)
	EventLog.add_entry("Bought %d %s for %d cr" % [quantity, good_name, total_cost])
	_status_label.text = "Bought %d %s for %d cr" % [quantity, good_name, total_cost]
	_refresh_all()


func _on_sell(good_name: String, quantity: int) -> void:
	var planet_name: String = GameManager.current_planet
	var sell_price: int = EconomyManager.get_sell_price(planet_name, good_name)
	if sell_price < 0:
		return
	# Priced unit by unit, so a big stack cannot outrun the saturation penalty.
	var total_income: int = EconomyManager.get_sell_total(planet_name, good_name, quantity)
	GameManager.remove_cargo(good_name, quantity)
	GameManager.add_credits(total_income)
	EconomyManager.register_sale(planet_name, good_name, quantity)
	AudioManager.play_sell()
	GameManager.total_trades += 1
	StandingManager.add_trade_loyalty(planet_name, StandingManager.get_trade_loyalty_gain(quantity, total_income))
	GameManager.record_market_observation(planet_name, good_name, EconomyManager.get_buy_price(planet_name, good_name), sell_price)
	AchievementManager.check_trades(GameManager.total_trades)
	if _planet_type != EconomyManager.PT_OUTLAW and EconomyManager.is_contraband_good(good_name):
		var faction: String = StandingManager.get_planet_faction(planet_name)
		var rep_loss: int = maxi(1, quantity)
		match StandingManager.get_reputation_tier(faction):
			"Trusted":
				rep_loss += 1
			"Allied":
				rep_loss += 2
		StandingManager.add_faction_reputation(
			faction,
			-rep_loss,
			"contraband sale"
		)
		StandingManager.add_trade_loyalty(planet_name, -mini(quantity * 2, 6))
		StandingManager.add_faction_reputation(
			StandingManager.FACTION_BY_PLANET_TYPE.get(EconomyManager.PT_OUTLAW, "Free Cartel"),
			maxi(1, quantity),
			"contraband network"
		)
	EventLog.add_entry("Sold %d %s for %d cr" % [quantity, good_name, total_income])
	_status_label.text = "Sold %d %s for %d cr" % [quantity, good_name, total_income]
	_refresh_all()
	GameManager.try_trigger_victory()


func close() -> void:
	# Close first so the overlay always disappears, even if listeners error.
	queue_free()
	market_closed.emit()


func _record_market_snapshot() -> void:
	var planet_name: String = GameManager.current_planet
	for good in EconomyManager.goods:
		var good_name: String = good.good_name
		var buy_price: int = EconomyManager.get_buy_price(planet_name, good_name)
		var sell_price: int = EconomyManager.get_sell_price(planet_name, good_name)
		if buy_price >= 0 or sell_price >= 0:
			GameManager.record_market_observation(planet_name, good_name, buy_price, sell_price)


func _build_market_context_text() -> String:
	var planet_name: String = GameManager.current_planet
	var faction: String = StandingManager.get_planet_faction(planet_name)
	var rep: int = StandingManager.get_faction_reputation(faction)
	var loyalty: int = StandingManager.get_trade_loyalty(planet_name)
	var loyalty_text: String = _get_loyalty_status_text(planet_name)
	var notes: Array[String] = [
		"%s | Reputation %+d (%s) | Loyalty %d (%s)" % [
			faction,
			rep,
			StandingManager.get_reputation_tier(faction),
			loyalty,
			loyalty_text,
		],
		_get_service_fee_text(planet_name),
	]
	var event_lines: Array[String] = EventManager.get_planet_status_lines(planet_name)
	if not event_lines.is_empty():
		notes.append(event_lines[0])
	return "\n".join(notes)


func _get_loyalty_status_text(planet_name: String) -> String:
	var loyalty_tier: String = StandingManager.get_loyalty_tier(planet_name)
	if loyalty_tier == "Unknown":
		return "No standing yet"
	return loyalty_tier


func _get_service_fee_text(planet_name: String) -> String:
	var fee_modifier: float = StandingManager.get_planet_service_fee_modifier(planet_name)
	var fee_percent: float = (fee_modifier - 1.0) * 100.0
	var faction: String = StandingManager.get_planet_faction(planet_name)
	var rep: int = StandingManager.get_faction_reputation(faction)
	var bounty_tier: String = StandingManager.get_bounty_tier()
	var loyalty: int = StandingManager.get_trade_loyalty(planet_name)
	var rep_fee: float = 0.0
	if rep <= StandingManager.REPUTATION_HOSTILE_MAX:
		rep_fee = 10.0
	elif rep <= StandingManager.REPUTATION_COLD_MAX:
		rep_fee = 5.0

	var bounty_fee: float = 0.0
	match bounty_tier:
		"Wanted":
			bounty_fee = 4.0
		"Most Wanted":
			bounty_fee = 8.0

	var loyalty_discount: float = clampf(float(loyalty) * 0.05, 0.0, 5.0)
	return "Dock/Market Fee: %+.1f%% (Reputation %+.1f%%, Loyalty -%.1f%%, Bounty %+.1f%%)" % [
		fee_percent,
		rep_fee,
		loyalty_discount,
		bounty_fee,
	]


func _build_trade_tooltip(good_name: String, mode: String) -> String:
	var planet_name: String = GameManager.current_planet
	var lines: Array[String] = []
	if mode == "buy":
		var breakdown: Dictionary = EconomyManager.get_buy_price_breakdown(planet_name, good_name)
		if not breakdown.is_empty():
			lines.append("%s buy breakdown" % good_name)
			lines.append("Base: %d cr" % int(breakdown.get("base_price", 0)))
			lines.append("Event x%.2f | Reputation x%.2f | Loyalty x%.2f | Service x%.2f" % [
				float(breakdown.get("event_modifier", 1.0)),
				float(breakdown.get("rep_modifier", 1.0)),
				float(breakdown.get("loyalty_modifier", 1.0)),
				float(breakdown.get("service_fee_modifier", 1.0)),
			])
	else:
		var sell_breakdown: Dictionary = EconomyManager.get_sell_price_breakdown(planet_name, good_name)
		if not sell_breakdown.is_empty():
			lines.append("%s sell breakdown" % good_name)
			lines.append("Base: %d cr" % int(sell_breakdown.get("base_price", 0)))
			lines.append("Event x%.2f | Ratio x%.2f | Reputation x%.2f | Loyalty x%.2f" % [
				float(sell_breakdown.get("event_modifier", 1.0)),
				float(sell_breakdown.get("sell_ratio", EconomyManager.SELL_RATIO)),
				float(sell_breakdown.get("rep_modifier", 1.0)),
				float(sell_breakdown.get("loyalty_modifier", 1.0)),
			])
			lines.append("Service x%.2f" % (1.0 / float(sell_breakdown.get("service_fee_modifier", 1.0))))

			# Per-good detail; the rule itself lives in the saturation panel.
			var saturation: float = float(sell_breakdown.get("saturation_modifier", 1.0))
			var units: float = EconomyManager.get_saturation_units(planet_name, good_name)
			var full_price_units: float = EconomyManager.get_full_price_units(good_name)
			if saturation < 1.0:
				lines.append("Market flooded x%.2f — full price again in %d days" % [
					saturation, EconomyManager.get_days_until_recovered(planet_name, good_name),
				])
			else:
				lines.append("Absorbs %d more units at full price" % int(round(full_price_units - units)))

			var buy_breakdown: Dictionary = EconomyManager.get_buy_price_breakdown(planet_name, good_name)
			if not buy_breakdown.is_empty():
				var buy_price: int = int(buy_breakdown.get("final_price", -1))
				var final_sell_price: int = int(sell_breakdown.get("final_price", -1))
				if buy_price > 0 and final_sell_price == buy_price:
					var uncapped_sell_price: int = max(
						1,
						int(round(
							float(sell_breakdown.get("base_price", 0)) * 
							float(sell_breakdown.get("event_modifier", 1.0)) * 
							float(sell_breakdown.get("sell_ratio", EconomyManager.SELL_RATIO)) * 
							float(sell_breakdown.get("contraband_modifier", 1.0)) * 
							float(sell_breakdown.get("rep_modifier", 1.0)) * 
							float(sell_breakdown.get("loyalty_modifier", 1.0)) * 
							float(sell_breakdown.get("service_fee_modifier", 1.0)) *
							float(sell_breakdown.get("pirate_modifier", 1.0)) *
							float(sell_breakdown.get("saturation_modifier", 1.0))
						))
					)
					if uncapped_sell_price > buy_price:
						lines.append("(Capped at local buy price)")

	var best_buy: Dictionary = GameManager.get_best_buy_hint(good_name)
	if not best_buy.is_empty():
		lines.append("Best buy seen: %s %d cr" % [best_buy.get("planet", "?"), int(best_buy.get("price", 0))])
	var best_sell: Dictionary = GameManager.get_best_sell_hint(good_name)
	if not best_sell.is_empty():
		lines.append("Best sell seen: %s %d cr" % [best_sell.get("planet", "?"), int(best_sell.get("price", 0))])
	var last_seen: Dictionary = GameManager.get_last_seen_prices(planet_name, good_name)
	if not last_seen.is_empty():
		lines.append("Last seen here: buy %s / sell %s" % [
			str(last_seen.get("buy", "-")),
			str(last_seen.get("sell", "-")),
		])
	return "\n".join(lines)


func _get_price_note(good_name: String, mode: String, price: int) -> String:
	if _get_known_market_count(good_name) < 2:
		return ""
	if mode == "buy":
		var best_buy: Dictionary = GameManager.get_best_buy_hint(good_name)
		if not best_buy.is_empty() and int(best_buy.get("price", price + 1)) == price:
			return "BEST"
		return ""
	var best_sell: Dictionary = GameManager.get_best_sell_hint(good_name)
	if not best_sell.is_empty() and int(best_sell.get("price", price - 1)) == price:
		return "BEST"
	return ""


func _get_known_market_count(good_name: String) -> int:
	var good_memory: Dictionary = GameManager.trade_route_memory.get(good_name, {})
	var last_seen: Dictionary = good_memory.get("last_seen", {})
	return last_seen.size()
