extends Control

var good_type: String = ""

const ICON_MAP = {
	"Medicine": "pill",
	"Luxury Goods": "diamond",
	"Weapons": "crosshair",
	"Electronics": "chip",
	"Food Rations": "circle",
	"Raw Ore": "hexagon",
	"Spice": "star",
	"Stolen Tech": "triangle",
}

const COLOR_MAP = {
	"Medicine": Color(0.9, 0.25, 0.3),
	"Luxury Goods": Color(0.3, 0.5, 1.0),
	"Weapons": Color(1.0, 0.6, 0.2),
	"Electronics": Color(0.2, 0.85, 0.9),
	"Food Rations": Color(0.3, 0.85, 0.3),
	"Raw Ore": Color(0.65, 0.45, 0.25),
	"Spice": Color(0.7, 0.3, 0.9),
	"Stolen Tech": Color(1.0, 0.2, 0.2),
}


func setup(p_good_name: String) -> void:
	good_type = p_good_name
	custom_minimum_size = Vector2(18, 18)
	queue_redraw()


func _draw() -> void:
	var color: Color = COLOR_MAP.get(good_type, Color(0.5, 0.5, 0.6))
	var shape: String = ICON_MAP.get(good_type, "circle")
	var center := Vector2(9, 9)
	var r := 6.0

	match shape:
		"pill":
			draw_rect(Rect2(center.x - 3, center.y - r, 6, r * 2), color, true)
			draw_circle(Vector2(center.x, center.y - r + 3), 3, color)
			draw_circle(Vector2(center.x, center.y + r - 3), 3, color)
			draw_line(Vector2(center.x - 4, center.y), Vector2(center.x + 4, center.y), Color(0.1, 0.1, 0.15), 1.5)
		"diamond":
			var points := PackedVector2Array([
				Vector2(center.x, center.y - r),
				Vector2(center.x + r * 0.7, center.y),
				Vector2(center.x, center.y + r),
				Vector2(center.x - r * 0.7, center.y),
			])
			draw_colored_polygon(points, color)
		"crosshair":
			draw_arc(center, r * 0.6, 0, TAU, 16, color, 1.5)
			draw_line(Vector2(center.x, center.y - r), Vector2(center.x, center.y + r), color, 1.5)
			draw_line(Vector2(center.x - r, center.y), Vector2(center.x + r, center.y), color, 1.5)
		"chip":
			draw_rect(Rect2(center.x - 5, center.y - 5, 10, 10), color, true)
			for i in range(3):
				var offset := (i - 1) * 4.0
				draw_line(Vector2(center.x + offset, center.y - 5), Vector2(center.x + offset, center.y - 8), color, 1.5)
				draw_line(Vector2(center.x + offset, center.y + 5), Vector2(center.x + offset, center.y + 8), color, 1.5)
		"circle":
			draw_circle(center, r, color)
		"hexagon":
			var hex_points := PackedVector2Array()
			for i in range(6):
				var angle := TAU / 6.0 * i - PI / 6.0
				hex_points.append(center + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(hex_points, color)
		"star":
			var star_points := PackedVector2Array()
			for i in range(10):
				var angle := TAU / 10.0 * i - PI / 2.0
				var dist := r if i % 2 == 0 else r * 0.45
				star_points.append(center + Vector2(cos(angle), sin(angle)) * dist)
			draw_colored_polygon(star_points, color)
		"triangle":
			var tri_points := PackedVector2Array([
				Vector2(center.x, center.y - r),
				Vector2(center.x + r * 0.87, center.y + r * 0.5),
				Vector2(center.x - r * 0.87, center.y + r * 0.5),
			])
			draw_colored_polygon(tri_points, color)
		_:
			draw_circle(center, r, color)
