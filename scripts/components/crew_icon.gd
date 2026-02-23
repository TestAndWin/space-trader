extends Control

# Procedurally drawn crew badge icon using _draw()
# Hexagonal badge with centered symbol per crew type

var _bonus_type: int = -1

const CREW_COLORS := {
	0: Color(0.3, 0.7, 0.9),       # Navigator - Cyan
	1: Color(0.9, 0.35, 0.2),      # Weapons Officer - Red/Orange
	2: Color(0.9, 0.75, 0.2),      # Engineer - Gold
	3: Color(0.3, 0.8, 0.4),       # Trader - Green
	4: Color(0.6, 0.3, 0.8),       # Smuggler - Purple
	5: Color(0.7, 0.85, 0.95),     # Medic - Light Blue
}


func setup(bonus_type: int) -> void:
	_bonus_type = bonus_type
	queue_redraw()


func _draw() -> void:
	if _bonus_type < 0:
		return

	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var cy := h * 0.5
	var r := minf(w, h) * 0.42
	var col: Color = CREW_COLORS.get(_bonus_type, CREW_COLORS[0])

	# Layer 1: Outer glow
	draw_circle(Vector2(cx, cy), r * 1.15, col * Color(1, 1, 1, 0.12))

	# Layer 2: Dark filled hexagon
	var hex_pts := _hex_points(cx, cy, r)
	draw_colored_polygon(hex_pts, Color(0.06, 0.08, 0.12, 0.9))

	# Layer 3: Colored hex border
	var border_pts := _hex_points(cx, cy, r)
	border_pts.append(border_pts[0])
	draw_polyline(border_pts, col * Color(1, 1, 1, 0.8), 1.5, true)

	# Layer 4: Inner accent ring
	draw_arc(Vector2(cx, cy), r * 0.6, 0, TAU, 32, col * Color(1, 1, 1, 0.15), 1.0, true)

	# Layer 5: Symbol
	match _bonus_type:
		0: _draw_compass(cx, cy, r, col)
		1: _draw_crosshair(cx, cy, r, col)
		2: _draw_gear(cx, cy, r, col)
		3: _draw_credits(cx, cy, r, col)
		4: _draw_mask(cx, cy, r, col)
		5: _draw_cross(cx, cy, r, col)


func _hex_points(cx: float, cy: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle := -PI / 2 + i * TAU / 6
		pts.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))
	return pts


func _draw_compass(cx: float, cy: float, r: float, col: Color) -> void:
	# 4-point compass star
	var s := r * 0.55
	var t := r * 0.15
	# North point (bright)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, cy - s), Vector2(cx - t, cy), Vector2(cx + t, cy)
	]), col)
	# South point
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, cy + s), Vector2(cx - t, cy), Vector2(cx + t, cy)
	]), col.darkened(0.35))
	# East point
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + s, cy), Vector2(cx, cy - t), Vector2(cx, cy + t)
	]), col.darkened(0.2))
	# West point
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - s, cy), Vector2(cx, cy - t), Vector2(cx, cy + t)
	]), col.darkened(0.2))
	# Center dot
	draw_circle(Vector2(cx, cy), r * 0.06, Color.WHITE)


func _draw_crosshair(cx: float, cy: float, r: float, col: Color) -> void:
	# Targeting crosshair
	var s := r * 0.5
	var gap := r * 0.12
	# Outer ring
	draw_arc(Vector2(cx, cy), s, 0, TAU, 24, col, 1.5, true)
	# Cross lines with center gap
	draw_line(Vector2(cx - s, cy), Vector2(cx - gap, cy), col, 1.5)
	draw_line(Vector2(cx + gap, cy), Vector2(cx + s, cy), col, 1.5)
	draw_line(Vector2(cx, cy - s), Vector2(cx, cy - gap), col, 1.5)
	draw_line(Vector2(cx, cy + gap), Vector2(cx, cy + s), col, 1.5)
	# Center dot
	draw_circle(Vector2(cx, cy), r * 0.05, col.lightened(0.3))


func _draw_gear(cx: float, cy: float, r: float, col: Color) -> void:
	# Gear/cog with 6 teeth
	var outer := r * 0.5
	var inner := r * 0.35
	var teeth := 6
	var pts := PackedVector2Array()
	for i in teeth:
		var a1 := i * TAU / teeth - PI / 2
		var a2 := a1 + TAU / teeth * 0.3
		var _a3 := a2 + TAU / teeth * 0.2
		pts.append(Vector2(cx + cos(a1) * inner, cy + sin(a1) * inner))
		pts.append(Vector2(cx + cos(a1) * outer, cy + sin(a1) * outer))
		pts.append(Vector2(cx + cos(a2) * outer, cy + sin(a2) * outer))
		pts.append(Vector2(cx + cos(a2) * inner, cy + sin(a2) * inner))
	draw_colored_polygon(pts, col)
	# Center hole
	draw_circle(Vector2(cx, cy), r * 0.13, Color(0.06, 0.08, 0.12))


func _draw_credits(cx: float, cy: float, r: float, col: Color) -> void:
	# Credit symbol (diamond with horizontal lines)
	var s := r * 0.45
	# Diamond
	var diamond := PackedVector2Array([
		Vector2(cx, cy - s), Vector2(cx + s * 0.6, cy),
		Vector2(cx, cy + s), Vector2(cx - s * 0.6, cy),
	])
	draw_colored_polygon(diamond, col.darkened(0.2))
	draw_polyline(PackedVector2Array([
		diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]
	]), col, 1.5, true)
	# Horizontal lines through diamond
	var lw := s * 0.4
	draw_line(Vector2(cx - lw, cy - s * 0.25), Vector2(cx + lw, cy - s * 0.25), col.lightened(0.3), 1.0)
	draw_line(Vector2(cx - lw, cy + s * 0.25), Vector2(cx + lw, cy + s * 0.25), col.lightened(0.3), 1.0)


func _draw_mask(cx: float, cy: float, r: float, col: Color) -> void:
	# Stylized eye/mask shape
	var s := r * 0.5
	# Mask body - pointed oval
	var pts := PackedVector2Array()
	var segments := 16
	for i in range(segments + 1):
		var t := float(i) / segments
		var angle := -PI + t * TAU
		var rx := s
		var ry := s * 0.5
		pts.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
	draw_colored_polygon(pts, col.darkened(0.3))
	# Eye slits
	var eye_w := s * 0.22
	var eye_h := s * 0.12
	draw_rect(Rect2(cx - s * 0.45 - eye_w, cy - eye_h, eye_w * 2, eye_h * 2), col.lightened(0.4))
	draw_rect(Rect2(cx + s * 0.45 - eye_w, cy - eye_h, eye_w * 2, eye_h * 2), col.lightened(0.4))


func _draw_cross(cx: float, cy: float, r: float, col: Color) -> void:
	# Medical cross
	var arm := r * 0.45
	var t := r * 0.17
	# Vertical bar
	draw_rect(Rect2(cx - t, cy - arm, t * 2, arm * 2), col)
	# Horizontal bar
	draw_rect(Rect2(cx - arm, cy - t, arm * 2, t * 2), col)
	# Subtle inner highlight
	var hi := r * 0.08
	draw_rect(Rect2(cx - hi, cy - arm * 0.7, hi * 2, arm * 1.4), col.lightened(0.2))
