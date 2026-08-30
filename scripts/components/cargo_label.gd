extends BoundLabel

## Label that shows cargo usage and keeps itself in sync.
## Counterpart to credits_label.gd; see BoundLabel for the shared mechanics.
##
## format_string receives [used, capacity].


func _default_format() -> String:
	return "%d/%d"


func refresh() -> void:
	text = format_string % [GameManager.get_cargo_used(), GameManager.cargo_capacity]


func _connect_source() -> void:
	GameManager.cargo_changed.connect(refresh)
