extends ShipSpriteDisplay

## Player ship panel: the ship sprite tinted green→yellow→red by hull health,
## with a blue shield bubble and separate shield/hull hit reactions.

const TEX_SCOUT = preload("res://assets/sprites/ships/scout.png")
const TEX_FREIGHTER = preload("res://assets/sprites/ships/freighter.png")
const TEX_WARSHIP = preload("res://assets/sprites/ships/warship.png")
const TEX_SMUGGLER = preload("res://assets/sprites/ships/smuggler.png")
const TEX_EXPLORER = preload("res://assets/sprites/ships/explorer.png")

var ship_shape: int = 0

var _hit_flash_color: Color = Color.TRANSPARENT


## Cargo is part of the shared display API but is not drawn on this panel.
func update_ship(
	p_hull_pct: float,
	p_shield_pct: float,
	_p_cargo_used: int,
	_p_cargo_max: int,
	p_ship_shape: int = -1
) -> void:
	_set_hull_and_shield(p_hull_pct, p_shield_pct)
	if p_ship_shape >= 0:
		ship_shape = p_ship_shape
	queue_redraw()


func play_shield_hit() -> void:
	_hit_flash_color = Color(0.3, 0.6, 1.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_hit_offset_x, 0.0, 3.0, 0.04)
	tween.tween_method(_set_hit_offset_x, 3.0, -2.0, 0.05).set_delay(0.04)
	tween.tween_method(_set_hit_offset_x, -2.0, 1.0, 0.04).set_delay(0.09)
	tween.tween_method(_set_hit_offset_x, 1.0, 0.0, 0.05).set_delay(0.13)
	tween.tween_method(_set_hit_flash, 0.0, 0.8, 0.05)
	tween.tween_method(_set_hit_flash, 0.8, 0.0, 0.30).set_delay(0.05)


func play_hull_hit() -> void:
	_hit_flash_color = Color(1.0, 0.3, 0.2)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_hit_offset_x, 0.0, 5.0, 0.03)
	tween.tween_method(_set_hit_offset_x, 5.0, -5.0, 0.05).set_delay(0.03)
	tween.tween_method(_set_hit_offset_x, -5.0, 4.0, 0.04).set_delay(0.08)
	tween.tween_method(_set_hit_offset_x, 4.0, -3.0, 0.04).set_delay(0.12)
	tween.tween_method(_set_hit_offset_x, -3.0, 0.0, 0.06).set_delay(0.16)
	tween.tween_method(_set_hit_flash, 0.0, 1.0, 0.04)
	tween.tween_method(_set_hit_flash, 1.0, 0.0, 0.35).set_delay(0.04)


func _draw() -> void:
	var span: float = minf(size.x, size.y)
	var center := Vector2(size.x * 0.5 + _hit_offset.x, size.y * 0.5)

	if shield_pct > 0.0:
		var shield_col := Color(0.3, 0.5, 1.0, 0.1 + shield_pct * 0.25)
		# Only a shield hit brightens the bubble — a hull hit flashes red.
		if _hit_flash > 0.01 and _hit_flash_color.b > 0.5:
			shield_col = shield_col.lerp(Color(0.5, 0.8, 1.0, 0.7), _hit_flash * 0.6)
		_draw_ellipse(center, span * 0.48, span * 0.46, shield_col)

	var hull_color := _hull_ramp(
		Color(0.3, 0.85, 0.3), Color(0.9, 0.85, 0.2), Color(0.9, 0.2, 0.2)
	)
	if _hit_flash > 0.01:
		hull_color = hull_color.lerp(_hit_flash_color, _hit_flash * 0.5)

	_draw_sprite(_texture_for_shape(), center, span, hull_color)
	_draw_cracks(center, span)


func _texture_for_shape() -> Texture2D:
	match ship_shape:
		1: return TEX_FREIGHTER
		2: return TEX_WARSHIP
		3: return TEX_SMUGGLER
		4: return TEX_EXPLORER
		_: return TEX_SCOUT
