extends Control

## Cockpit overlay drawn on top of the entire planet screen.
## Renders vignette corners, outer frame, L-brackets with rivets,
## accent lines and pulsing glow points for a holographic cockpit feel.

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y

	# 1. Outer frame: thin line around the entire screen
	var frame_color := Color(0.0, 0.55, 0.85, 0.6)
	draw_rect(Rect2(0.0, 0.0, w, h), frame_color, false, 2.0)

	# 3. L-brackets in all four corners
	var bracket_color := Color(0.35, 0.42, 0.50, 0.85)
	var rivet_color := Color(0.45, 0.52, 0.60, 0.9)
	var bl := 60.0   # bracket arm length
	var bw := 4.0    # bracket line width
	var rr := 3.0    # rivet radius

	# Top-left
	draw_line(Vector2(0.0, 0.0), Vector2(bl, 0.0), bracket_color, bw)
	draw_line(Vector2(0.0, 0.0), Vector2(0.0, bl), bracket_color, bw)
	draw_circle(Vector2(bl, 0.0), rr, rivet_color)
	draw_circle(Vector2(0.0, bl), rr, rivet_color)

	# Top-right
	draw_line(Vector2(w, 0.0), Vector2(w - bl, 0.0), bracket_color, bw)
	draw_line(Vector2(w, 0.0), Vector2(w, bl), bracket_color, bw)
	draw_circle(Vector2(w - bl, 0.0), rr, rivet_color)
	draw_circle(Vector2(w, bl), rr, rivet_color)

	# Bottom-left
	draw_line(Vector2(0.0, h), Vector2(bl, h), bracket_color, bw)
	draw_line(Vector2(0.0, h), Vector2(0.0, h - bl), bracket_color, bw)
	draw_circle(Vector2(bl, h), rr, rivet_color)
	draw_circle(Vector2(0.0, h - bl), rr, rivet_color)

	# Bottom-right
	draw_line(Vector2(w, h), Vector2(w - bl, h), bracket_color, bw)
	draw_line(Vector2(w, h), Vector2(w, h - bl), bracket_color, bw)
	draw_circle(Vector2(w - bl, h), rr, rivet_color)
	draw_circle(Vector2(w, h - bl), rr, rivet_color)

	# 4. Top and bottom accent lines
	var accent_color := Color(0.0, 0.65, 0.95, 0.4)
	draw_line(Vector2(0.0, 0.0), Vector2(w, 0.0), accent_color, 1.0)
	draw_line(Vector2(0.0, h), Vector2(w, h), accent_color, 1.0)

	# 5. Pulsing glow points at bracket arm endpoints
	var pulse := (sin(_time * 1.8) + 1.0) * 0.5  # 0..1
	var glow_alpha := lerpf(0.3, 0.7, pulse)
	var glow_radius := lerpf(3.0, 5.0, pulse)
	var glow_color := Color(0.0, 0.7, 1.0, glow_alpha)

	# Top-left endpoints
	draw_circle(Vector2(bl, 0.0), glow_radius, glow_color)
	draw_circle(Vector2(0.0, bl), glow_radius, glow_color)
	# Top-right endpoints
	draw_circle(Vector2(w - bl, 0.0), glow_radius, glow_color)
	draw_circle(Vector2(w, bl), glow_radius, glow_color)
	# Bottom-left endpoints
	draw_circle(Vector2(bl, h), glow_radius, glow_color)
	draw_circle(Vector2(0.0, h - bl), glow_radius, glow_color)
	# Bottom-right endpoints
	draw_circle(Vector2(w - bl, h), glow_radius, glow_color)
	draw_circle(Vector2(w, h - bl), glow_radius, glow_color)
