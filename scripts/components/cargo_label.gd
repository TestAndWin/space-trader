extends Label

## Label that shows cargo usage and keeps itself in sync.
##
## Counterpart to credits_label.gd: the binding lives on the label, so it is
## released with the screen and no screen has to remember to re-read the hold
## after something changed it.

## Set before binding — receives [used, capacity].
var format_string: String = "%d/%d"

var _bound: bool = false


func _ready() -> void:
	bind()


## Starts tracking the hold. Runs automatically on tree entry; call it
## explicitly after attaching this script to a scene-authored label that is
## already inside the tree, where _ready() has come and gone.
func bind() -> void:
	if _bound:
		return
	_bound = true
	_apply()
	GameManager.cargo_changed.connect(_apply)


func _apply() -> void:
	text = format_string % [GameManager.get_cargo_used(), GameManager.cargo_capacity]
