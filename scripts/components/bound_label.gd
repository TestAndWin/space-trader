class_name BoundLabel
extends Label

## Label that renders a slice of GameManager state and keeps itself in sync.
##
## The binding lives on the label rather than on the screen, so the connection
## is released automatically when the screen is freed, and a screen no longer
## has to remember to re-read the value after every action. That gap is what
## left the shipyard header stale when an embedded tab spent credits.
##
## A subclass supplies _connect_source() and refresh(); see credits_label.gd.

## Set before binding — the text is rendered through it. Left empty, the
## concrete label's own default is used.
var format_string: String = ""

var _bound: bool = false


func _ready() -> void:
	bind()


## Starts tracking the value. Runs automatically on tree entry; call it
## explicitly after attaching this script to a scene-authored label that is
## already inside the tree, where _ready() has come and gone.
func bind() -> void:
	if _bound:
		return
	_bound = true
	if format_string.is_empty():
		format_string = _default_format()
	refresh()
	_connect_source()


## Format used when the caller did not set one.
func _default_format() -> String:
	return ""


## Renders the current state. Overridden by the concrete label.
func refresh() -> void:
	pass


## Subscribes to the GameManager signal that marks this label as stale.
## Separate from refresh() because the signals differ in arity.
func _connect_source() -> void:
	pass
