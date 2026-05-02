class_name ActionButton
extends Button

## Standard action button used across all overlay screens (Shipyard, Quest, Crew, Factory).
## Style is applied automatically via _ready(). Control layout (size_flags_horizontal,
## custom_minimum_size.x) on the instance after creation — _ready() only sets height.
##
## Change UIStyles.ACTION_BTN_FONT_SIZE / ACTION_BTN_MIN_HEIGHT to restyle all at once.

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")


func _ready() -> void:
	if custom_minimum_size.y == 0.0:
		custom_minimum_size.y = UIStyles.ACTION_BTN_MIN_HEIGHT
	UIStyles.style_action_button(self)
