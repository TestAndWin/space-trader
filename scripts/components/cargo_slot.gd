extends HBoxContainer

signal action_pressed(good_name: String, quantity: int)

const GoodIconScript = preload("res://scripts/components/good_icon.gd")
const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

const BUY_COLOR := Color(0.0, 0.75, 0.35)
const SELL_COLOR := Color(0.85, 0.10, 0.38)
const PM_BG := Color(0.02, 0.10, 0.22)
const PM_BORDER := Color(0.0, 0.50, 0.80)
var ROW_BG: Color = Color(UIStyles.PANEL_BG, 0.75)
const ROW_BORDER := Color(0.0, 0.40, 0.65, 0.60)

var good_name: String = ""
var price: int = 0
var quantity: int = 0
var mode: String = "buy"  # "buy" or "sell"
var trade_enabled: bool = true
var trade_disabled_suffix: String = ""
var price_note: String = ""

var selected_quantity: int = 1


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
	var action_color := BUY_COLOR if mode == "buy" else SELL_COLOR
	_style_action_button($ActionButton, action_color)
	_style_pm_button($MinusButton)
	_style_pm_button($PlusButton)


func _update_trade_controls() -> void:
	var show_trade_controls: bool = mode == "buy" or trade_enabled
	$ActionButton.visible = show_trade_controls
	$MinusButton.visible = show_trade_controls
	$PlusButton.visible = show_trade_controls


func _style_action_button(btn: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent
	normal.border_color = accent.lightened(0.2)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2

	var hover := normal.duplicate()
	hover.bg_color = accent.lightened(0.15)

	var pressed := normal.duplicate()
	pressed.bg_color = accent.darkened(0.2)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.12, 0.14, 0.16, 0.6)
	disabled.border_color = Color(0.2, 0.22, 0.24, 0.4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.95))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.8, 0.75))
	btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.32, 0.35))


func _style_pm_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = PM_BG
	normal.border_color = PM_BORDER
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 4
	normal.content_margin_right = 4
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2

	var hover := normal.duplicate()
	hover.bg_color = PM_BG.lightened(0.15)
	hover.border_color = PM_BORDER.lightened(0.15)

	var pressed := normal.duplicate()
	pressed.bg_color = PM_BG.darkened(0.15)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(0.85, 1.0, 0.85))


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
		$QuantityLabel.text = "x" + str(selected_quantity)
	else:
		$ActionButton.text = "SELL"
		if trade_enabled:
			$QuantityLabel.text = "x" + str(selected_quantity) + " (" + str(quantity) + ")"
		else:
			$QuantityLabel.text = "x" + str(quantity)
			if trade_disabled_suffix != "":
				$QuantityLabel.text += " " + trade_disabled_suffix
	$QuantityLabel.add_theme_color_override("font_color", Color(0.65, 0.68, 0.7))
	# Color price based on profitability
	if price > 0 and good_data:
		if mode == "sell":
			if price > good_data.base_price:
				$PriceLabel.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			elif price < good_data.base_price:
				$PriceLabel.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			else:
				$PriceLabel.add_theme_color_override("font_color", Color(0.65, 0.68, 0.7))
		elif mode == "buy":
			if price < good_data.base_price:
				$PriceLabel.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			elif price > good_data.base_price:
				$PriceLabel.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			else:
				$PriceLabel.add_theme_color_override("font_color", Color(0.65, 0.68, 0.7))
	else:
		$PriceLabel.add_theme_color_override("font_color", Color(0.65, 0.68, 0.7))


func _update_price_indicator(avg_price: int) -> void:
	var old_indicator := get_node_or_null("PriceIndicator")
	if old_indicator:
		old_indicator.queue_free()
	if avg_price <= 0:
		return
	var indicator := Label.new()
	indicator.name = "PriceIndicator"
	indicator.add_theme_font_size_override("font_size", 12)
	if price <= int(avg_price * 0.8):
		indicator.text = "▼"
		indicator.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
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
	action_pressed.emit(good_name, selected_quantity)


func _on_plus_pressed() -> void:
	if mode == "sell" and not trade_enabled:
		return
	var max_qty: int = 10 if mode == "buy" else quantity
	selected_quantity = min(selected_quantity + 1, max_qty)
	_update_display()


func _on_minus_pressed() -> void:
	if mode == "sell" and not trade_enabled:
		return
	selected_quantity = max(selected_quantity - 1, 1)
	_update_display()
