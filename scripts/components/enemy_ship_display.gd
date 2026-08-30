extends ShipSpriteDisplay

## Enemy ship panel: the same sprite/crack drawing as the player display, on an
## orange→red hull ramp, with a lunge animation for the enemy's attack turn.

const TEX_ENEMY_FIGHTER = preload("res://assets/sprites/enemies/fighter_ship.png")
const TEX_ENEMY_PATROL = preload("res://assets/sprites/enemies/patrol_ship.png")
const TEX_ENEMY_PIRATE = preload("res://assets/sprites/enemies/pirate_ship.png")
const TEX_ENEMY_AI_DRONE = preload("res://assets/sprites/enemies/rogue_ai_ship.png")
const TEX_ENEMY_ANOMALY = preload("res://assets/sprites/enemies/anomaly_ship.png")
const TEX_ENEMY_HUNTER = preload("res://assets/sprites/enemies/hunter_ship.png")
const TEX_FREIGHTER = preload("res://assets/sprites/ships/freighter.png")

var _ship_type: int = 0


func update_enemy(p_hull_pct: float, p_shield_pct: float, encounter_name: String) -> void:
	_set_hull_and_shield(p_hull_pct, p_shield_pct)
	_ship_type = _type_from_name(encounter_name)
	queue_redraw()


func play_hit() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_hit_offset_x, 0.0, 5.0, 0.04)
	tween.tween_method(_set_hit_offset_x, 5.0, -4.0, 0.06).set_delay(0.04)
	tween.tween_method(_set_hit_offset_x, -4.0, 3.0, 0.05).set_delay(0.10)
	tween.tween_method(_set_hit_offset_x, 3.0, -2.0, 0.04).set_delay(0.15)
	tween.tween_method(_set_hit_offset_x, -2.0, 0.0, 0.06).set_delay(0.19)
	tween.tween_method(_set_hit_flash, 0.0, 1.0, 0.06)
	tween.tween_method(_set_hit_flash, 1.0, 0.0, 0.25).set_delay(0.06)


## Lunge towards the player as the enemy attacks.
func play_attack() -> void:
	var tween := create_tween()
	tween.tween_method(_set_hit_offset_y, 0.0, 15.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_hit_offset_y, 15.0, 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _type_from_name(encounter_name: String) -> int:
	match encounter_name:
		"Wandering Trader": return 1     # Freighter
		"System Patrol", "Smuggler Ambush": return 2  # Scout
		"Pirate Captain", "Crimson Enforcer", "Crimson Jack": return 3       # Warship
		"Rogue AI": return 4             # Explorer
		"Space Anomaly": return 5        # Smuggler
		"Bounty Hunter": return 6        # Warship/Smuggler
		_: return 0                      # Scout


func _draw() -> void:
	var span: float = minf(size.x, size.y)
	var center := Vector2(size.x * 0.5, size.y * 0.5) + _hit_offset

	var hull_color := _hull_ramp(
		Color(0.9, 0.55, 0.15), Color(0.9, 0.3, 0.15), Color(0.35, 0.08, 0.08)
	)
	if _hit_flash > 0.01:
		hull_color = hull_color.lerp(Color(1.0, 0.85, 0.7), _hit_flash * 0.7)

	if shield_pct > 0.0:
		_draw_ellipse(center, span * 0.48, span * 0.46, Color(0.8, 0.3, 0.3, 0.1 + shield_pct * 0.25))

	# No outline: the sprites already carry their own cel shading.
	_draw_sprite(_texture_for_type(), center, span, hull_color)
	_draw_cracks(center, span)

	if _hit_flash > 0.05:
		draw_circle(center, span * 0.35, Color(1.0, 0.5, 0.2, _hit_flash * 0.3))


func _texture_for_type() -> Texture2D:
	match _ship_type:
		1: return TEX_FREIGHTER
		2: return TEX_ENEMY_PATROL
		3: return TEX_ENEMY_PIRATE
		4: return TEX_ENEMY_AI_DRONE
		5: return TEX_ENEMY_ANOMALY
		6: return TEX_ENEMY_HUNTER
		_: return TEX_ENEMY_FIGHTER
