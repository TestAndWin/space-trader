extends CanvasLayer

var _color_rect: ColorRect


func _ready() -> void:
	layer = 100
	_color_rect = ColorRect.new()
	_color_rect.color = Color(0, 0, 0, 0)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_color_rect)


func fade_to_black(duration: float = 0.3) -> void:
	var tween := create_tween()
	tween.tween_property(_color_rect, "color:a", 1.0, duration)
	await tween.finished


func fade_from_black(duration: float = 0.3) -> void:
	_color_rect.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(_color_rect, "color:a", 0.0, duration)
	await tween.finished
