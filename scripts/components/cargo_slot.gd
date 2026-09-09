extends HBoxContainer

## Trades run one unit per click: `quantity` is always 1, kept in the signal
## so the market screen's buy/sell handlers stay quantity-aware.
signal action_pressed(good_name: String, quantity: int)

const GoodIconScript = preload("res://scripts/components/good_icon.gd")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

const BUY_COLOR := Color(0.0, 0.75, 0.35)
const SELL_COLOR := Color(0.85, 0.10, 0.38)
var ROW_BG: Color = Color(UIStyles.PANEL_BG, 0.75)
const ROW_BORDER := Color(0.0, 0.40, 0.65, 0.60)
const GOOD_PRICE_COLOR := UIStyles.POSITIVE
const BAD_PRICE_COLOR := UIStyles.NEGATIVE
const NEUTRAL_PRICE_COLOR := Color(0.65, 0.68, 0.7)

var good_name: String = ""
var price: int = 0
var quantity: int = 0
var mode: String = "buy"  # "buy" or "sell"
var trade_enabled: bool = true
var trade_disabled_suffix: String = ""
var price_note: String = ""


func _ready() -> void:
	# Inset the content from the painted row plate (HBoxContainer offers no
	# content margins of its own).
	custom_minimum_size.y = maxf(custom_minimum_size.y, 30.0)
	var leading := _make_edge_spacer()
	add_child(leading)
	move_child(leading, 0)
	add_child(_make_edge_spacer())


func _make_edge_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(4, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func setup(
	p_good_name: String,
	p_price: int,
	p_quantity: int,
	p_mode: String,
	avg_price: int = -1,
	p_trade_enabled: bool = true,
	p_trade_disabled_suffix: String = "",
	p_price_note: String = ""
) -> void:
	good_name = p_good_name
	price = p_price
	quantity = p_quantity
	mode = p_mode
	trade_enabled = p_trade_enabled
	trade_disabled_suffix = p_trade_disabled_suffix
	price_note = p_price_note
	_setup_row_bg()
	_setup_icon()
	queue_redraw()
	_style_buttons()
	$PriceLabel.add_theme_font_override("font", UIStyles.FONT_MONO)
	$QuantityLabel.add_theme_font_override("font", UIStyles.FONT_MONO)
	_update_display()
	_update_trade_controls()
	_update_price_indicator(avg_price)


func _setup_row_bg() -> void:
	# HBoxContainer has no "panel" stylebox, so the row plate is painted in
	# _draw() instead. A CanvasItem draws before its children, which puts it
	# behind the icon, labels and buttons.
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)


## Row plate tying name, price and buttons together visually, with zebra
## banding so the eye can follow a single row across the full width.
func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var zebra: bool = get_index() % 2 == 1
	var bg: Color = ROW_BG
	if zebra:
		bg = Color(bg.r, bg.g, bg.b, minf(bg.a + 0.12, 1.0)).lightened(0.04)
	draw_rect(rect, bg, true)
	draw_rect(rect, ROW_BORDER, false, 1.0)


func _setup_icon() -> void:
	var container := $IconContainer
	for child in container.get_children():
		child.queue_free()
	var icon := Control.new()
	icon.set_script(GoodIconScript)
	container.add_child(icon)
	icon.setup(good_name)


func _style_buttons() -> void:
	UIStyles.tint_button($ActionButton, BUY_COLOR if mode == "buy" else SELL_COLOR, UIStyles.BTN_COMPACT)


func _update_trade_controls() -> void:
	$ActionButton.visible = mode == "buy" or trade_enabled


func _update_display() -> void:
	var display_name: String = good_name
	var good_data := _find_good_data(good_name)
	# Mark contraband
	if good_data and good_data.is_contraband:
		display_name = good_name + " [!]"
		$GoodNameLabel.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	else:
		$GoodNameLabel.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	if price_note != "":
		display_name += " [%s]" % price_note
		$GoodNameLabel.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	$GoodNameLabel.text = display_name
	$PriceLabel.text = str(price) + " cr"
	if mode == "buy":
		$ActionButton.text = "BUY"
		$QuantityLabel.text = ""
	else:
		$ActionButton.text = "SELL"
		# Sell rows carry the held stock; buy rows have no count to show.
		$QuantityLabel.text = "x" + str(quantity)
		if not trade_enabled and trade_disabled_suffix != "":
			$QuantityLabel.text += " " + trade_disabled_suffix
	$QuantityLabel.add_theme_color_override("font_color", NEUTRAL_PRICE_COLOR)
	# Color price by profitability: a high price is good news when selling and
	# bad news when buying, so the two modes are mirror images of each other.
	var price_color := NEUTRAL_PRICE_COLOR
	if price > 0 and good_data and price != good_data.base_price:
		var favourable: bool = (price > good_data.base_price) == (mode == "sell")
		price_color = GOOD_PRICE_COLOR if favourable else BAD_PRICE_COLOR
	$PriceLabel.add_theme_color_override("font_color", price_color)


func _update_price_indicator(avg_price: int) -> void:
	var old_indicator := get_node_or_null("PriceIndicator")
	if old_indicator:
		old_indicator.queue_free()
	if avg_price <= 0:
		return
	var indicator := Label.new()
	indicator.name = "PriceIndicator"
	indicator.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
	if price <= int(avg_price * 0.8):
		indicator.text = "▼"
		indicator.add_theme_color_override("font_color", UIStyles.POSITIVE)
	elif price >= int(avg_price * 1.2):
		indicator.text = "▲"
		indicator.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	else:
		indicator.text = "—"
		indicator.add_theme_color_override("font_color", Color(0.4, 0.42, 0.45))
	var price_idx := $PriceLabel.get_index()
	add_child(indicator)
	move_child(indicator, price_idx + 1)


func _find_good_data(gname: String) -> Resource:
	for good in EconomyManager.goods:
		if good.good_name == gname:
			return good
	return null


func _on_action_button_pressed() -> void:
	if mode == "sell" and not trade_enabled:
		return
	action_pressed.emit(good_name, 1)
