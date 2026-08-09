extends Label

## Label that shows the player's credit balance and keeps itself in sync.
##
## The binding lives on the label rather than on the screen, so the connection
## is released automatically when the screen is freed, and a screen no longer
## has to remember to re-read the balance after every action. That gap is what
## left the shipyard header stale when an embedded tab spent credits.

## Set before binding — the text is rendered through it.
var format_string: String = "%d cr"

var _bound: bool = false


func _ready() -> void:
	bind()


## Starts tracking the balance. Runs automatically on tree entry; call it
## explicitly after attaching this script to a scene-authored label that is
## already inside the tree, where _ready() has come and gone.
func bind() -> void:
	if _bound:
		return
	_bound = true
	_apply(GameManager.credits)
	GameManager.credits_changed.connect(_apply)


func _apply(amount: int) -> void:
	text = format_string % amount
