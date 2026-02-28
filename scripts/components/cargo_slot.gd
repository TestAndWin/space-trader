extends HBoxContainer

signal action_pressed(good_name: String, quantity: int)

const GoodIconScript = preload("res://scripts/components/good_icon.gd")

const BUY_COLOR := Color(0.0, 0.75, 0.35)
const SELL_COLOR := Color(0.85, 0.10, 0.38)
const PM_BG := Color(0.02, 0.10, 0.22)
const PM_BORDER := Color(0.0, 0.50, 0.80)
const ROW_BG := Color(0.02, 0.06, 0.14, 0.75)
const ROW_BORDER := Color(0.0, 0.40, 0.65, 0.60)

var good_name: String = ""
var price: int = 0
var quantity: int = 0
var mode: String = "buy"  # "buy" or "sell"

var selected_quantity: int = 1


func setup(p_good_name: String, p_price: int, p_quantity: int, p_mode: String, avg_price: int = -1) -> void:
	good_name = p_good_name
	price = p_price
	quantity = p_quantity
	mode = p_mode
	_setup_row_bg()
	_setup_icon()
	_style_buttons()
	_update_display()
	_update_price_indicator(avg_price)


func _setup_row_bg() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_BG
	style.border_color = ROW_BORDER
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)


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
	$GoodNameLabel.text = display_name
	$PriceLabel.text = str(price) + " cr"
	if mode == "buy":
		$ActionButton.text = "BUY"
		$QuantityLabel.text = "x" + str(selected_quantity)
	else:
		$ActionButton.text = "SELL"
		$QuantityLabel.text = "x" + str(selected_quantity) + " (" + str(quantity) + ")"
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
	action_pressed.emit(good_name, selected_quantity)


func _on_plus_pressed() -> void:
	var max_qty: int = 10 if mode == "buy" else quantity
	selected_quantity = min(selected_quantity + 1, max_qty)
	_update_display()


func _on_minus_pressed() -> void:
	selected_quantity = max(selected_quantity - 1, 1)
	_update_display()
