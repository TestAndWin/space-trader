extends Control

## Procedurally drawn energy bolt for the card cost badge.
##
## None of the project fonts (Exo2, Orbitron, ShareTechMono) carry a lightning
## glyph, and relying on a system-font fallback is not dependable across the
## Windows/iOS exports — so the bolt is drawn here instead of typed.

const BOLT_COLOR := Color(1.0, 0.85, 0.25)
const OUTLINE_COLOR := Color(0.06, 0.04, 0.0, 0.9)

## Bolt outline in a normalised 0..1 box, scaled to the control rect on draw.
## Kept as Array[Vector2]: a PackedVector2Array() call is not a constant
## expression and cannot be used with const.
const BOLT: Array[Vector2] = [
	Vector2(0.62, 0.00),
	Vector2(0.16, 0.58),
	Vector2(0.44, 0.58),
	Vector2(0.34, 1.00),
	Vector2(0.86, 0.40),
	Vector2(0.54, 0.40),
]

var _color: Color = BOLT_COLOR


func setup(bolt_color: Color = BOLT_COLOR) -> void:
	_color = bolt_color
	queue_redraw()


func _draw() -> void:
	var span := minf(size.x, size.y)
	if span <= 1.0:
		return
	var origin := Vector2((size.x - span) * 0.5, (size.y - span) * 0.5)
	draw_bolt(self, origin, span, _color)


## Draws the bolt into any CanvasItem, scaled to fit a `span`-sized square with
## its top-left at `origin`. Shared so the card cost badge and the battle
## energy pips are guaranteed to show the same shape.
static func draw_bolt(
	canvas: CanvasItem,
	origin: Vector2,
	span: float,
	fill_color: Color,
	outline_color: Color = OUTLINE_COLOR,
	outline_width: float = 2.0
) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in BOLT:
		pts.append(origin + p * span)
	# Dark rim first, fill on top — keeps the bolt readable on bright art.
	var closed := pts.duplicate()
	closed.append(pts[0])
	canvas.draw_polyline(closed, outline_color, outline_width, true)
	canvas.draw_colored_polygon(pts, fill_color)
