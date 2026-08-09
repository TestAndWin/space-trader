extends Control

## Energy as pips instead of a "3 / 3" readout — the remaining energy is the
## number the player checks on every card, and a row of dots is read at a
## glance where a fraction has to be parsed.

## The pip is the same bolt the cards print as their energy cost, so "one bolt
## on the card" maps directly onto "one bolt in the bar".
const EnergyIcon = preload("res://scripts/components/energy_icon.gd")

const FILLED_COLOR := EnergyIcon.BOLT_COLOR
const SPENT_COLOR := Color(0.22, 0.19, 0.12)
const OUTLINE_COLOR := Color(0.05, 0.04, 0.0, 0.9)

const BOLT_SPAN: float = 21.0
const PIP_SPACING: float = 17.0
## Beyond this the pip row would crowd the stats bar, so it falls back to text.
const MAX_PIPS: int = 8

var _current: int = 0
var _maximum: int = 0


func setup(current: int, maximum: int) -> void:
	_current = maxi(current, 0)
	_maximum = maxi(maximum, 0)
	var pip_count: int = mini(_maximum, MAX_PIPS)
	custom_minimum_size = Vector2(PIP_SPACING * float(maxi(pip_count, 1)) + 6.0, BOLT_SPAN + 6.0)
	tooltip_text = "Energy: %d of %d left this turn" % [_current, _maximum]
	queue_redraw()


func _draw() -> void:
	if _maximum <= 0:
		return
	if _maximum > MAX_PIPS:
		_draw_text_fallback()
		return
	var top: float = (size.y - BOLT_SPAN) * 0.5
	for i in _maximum:
		var origin := Vector2(PIP_SPACING * float(i), top)
		var is_available: bool = i < _current
		if is_available:
			# Soft halo so the remaining energy reads first.
			draw_circle(
				origin + Vector2(BOLT_SPAN * 0.5, BOLT_SPAN * 0.5),
				BOLT_SPAN * 0.42,
				Color(FILLED_COLOR, 0.14)
			)
		EnergyIcon.draw_bolt(
			self,
			origin,
			BOLT_SPAN,
			FILLED_COLOR if is_available else SPENT_COLOR,
			OUTLINE_COLOR,
			1.5
		)


## Very high energy totals stay legible as a number rather than a long dot row.
func _draw_text_fallback() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var text: String = "%d / %d" % [_current, _maximum]
	var font_size: int = 18
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(
		font,
		Vector2(0.0, size.y * 0.5 + text_size.y * 0.35),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		FILLED_COLOR
	)
