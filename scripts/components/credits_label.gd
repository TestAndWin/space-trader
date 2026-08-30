extends BoundLabel

## Label that shows the player's credit balance and keeps itself in sync.
## See BoundLabel for why the binding lives on the label.


func _default_format() -> String:
	return "%d cr"


func refresh() -> void:
	_apply(GameManager.credits)


func _connect_source() -> void:
	GameManager.credits_changed.connect(_apply)


func _apply(amount: int) -> void:
	text = format_string % amount
