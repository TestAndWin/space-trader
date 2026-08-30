extends Node

## One-shot onboarding hints — shown the first time the player opens a place,
## then never again. Persisted independently of savegames (like achievements),
## so a second run does not repeat the tutorial.
##
## The hints double as the only explanation the game gives for Fuel, Loyalty,
## Reputation, Bounty and the T2 win condition, which are never introduced in
## the normal flow.

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const JsonStore = preload("res://scripts/tools/json_store.gd")
const SAVE_PATH := "user://hints_seen.json"

## Hint id -> { title, text }. Ids for buildings match CityMap.BUILDING_*.
const HINTS: Dictionary = {
	"market": {
		"title": "Trading",
		"text": "Buy low here, sell high elsewhere — the arrows compare a price against what you have seen on other planets. Every trade raises your Loyalty on this planet, which quietly lowers its prices for you.",
	},
	"shipyard": {
		"title": "Shipyard",
		"text": "Repair your hull, refuel, install upgrades and trade ships — all in the tabs. Fuel is spent on every jump, and a dry tank strands you, so top up before a long route.",
	},
	"crew": {
		"title": "Crew",
		"text": "You can carry up to three specialists. Each one adds a passive bonus that lasts for the rest of the run, and the bonus is listed on the card before you pay.",
	},
	"quest": {
		"title": "Contracts",
		"text": "Delivery contracts pay well but expire — miss the deadline and you pay a penalty. The issuing faction's Reputation shifts your rewards and market prices, and this is also where you pay off a Bounty before patrols start hunting you.",
	},
	"deck": {
		"title": "Your Deck",
		"text": "These are the cards you fight with. Sell what you never play and buy something better — stronger cards fetch more, so a weak Common is cheap to clear out.",
	},
	"casino": {
		"title": "Casino",
		"text": "A few rounds of chance per landing. The odds are shown before you commit, and the house edge is real.",
	},
	"mission": {
		"title": "Missions",
		"text": "A planet-specific job for credits. It costs an entry fee, you get one per landing, and most of them can cost you hull if you push your luck.",
	},
	"factory": {
		"title": "Fabrication",
		"text": "Craft components here over several days, then install the finished T2 upgrade at the shipyard.",
	},
	"galaxy_map": {
		"title": "Galaxy Map",
		"text": "Plan your route. The danger level affects what you might encounter in deep space. Your Fuel determines how far you can travel. Click on a planet to see details, then click Travel to depart.",
	},
	"battle": {
		"title": "Combat",
		"text": "Play cards to attack or defend. You start with limited energy each turn. Any shield you have carries over from the overworld, so prepare before you fly.",
	},
	"planet_hub": {
		"title": "Planet Hub",
		"text": "Click on the buildings to access various facilities. The top left shows the current planet and faction. The status bar displays space news, your credits, and your main goal. The bottom left tracks your ship's hull, shields, fuel, and cargo.",
	},
}

var seen: Dictionary = {}  # { hint_id: bool }


func _ready() -> void:
	_load()


func has_seen(hint_id: String) -> bool:
	return seen.get(hint_id, false)


func mark_seen(hint_id: String) -> void:
	if seen.get(hint_id, false):
		return
	seen[hint_id] = true
	_save()


## Returns the hint to show, or an empty dictionary when there is nothing to
## show (unknown id, or the player has already acknowledged it).
func take_hint(hint_id: String) -> Dictionary:
	if hint_id not in HINTS or has_seen(hint_id):
		return {}
	return HINTS[hint_id]


func show_hint_popup(hint_id: String, parent_node: Node, on_ack: Callable = Callable()) -> void:
	var hint: Dictionary = take_hint(hint_id)
	if hint.is_empty():
		return
	var popup_name := "HintPopup_" + hint_id
	if parent_node.has_node(popup_name):
		return
		
	var overlay := ColorRect.new()
	overlay.name = popup_name
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# High Z-index so it appears above other UI elements in the current scene
	overlay.z_index = 100
	parent_node.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UIStyles.PANEL_BG, 0.96)
	style.border_color = UIStyles.PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(470, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = str(hint.get("title", "")).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIStyles.FONT_DISPLAY)
	title.add_theme_font_size_override("font_size", UIStyles.FONT_HEADING)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	vbox.add_child(title)

	var body := Label.new()
	body.text = str(hint.get("text", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(420, 0)
	body.add_theme_font_size_override("font_size", UIStyles.FONT_LABEL)
	body.add_theme_color_override("font_color", Color(0.88, 0.93, 0.97))
	vbox.add_child(body)

	var note := Label.new()
	note.text = str(hint.get("note", "This hint is only shown once."))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", UIStyles.FONT_CAPTION)
	note.add_theme_color_override("font_color", Color(0.5, 0.62, 0.72))
	vbox.add_child(note)

	var btn := Button.new()
	btn.text = "Continue"
	UIStyles.style_accent_button(btn, Color(0.0, 0.85, 0.45), UIStyles.FONT_BODY)

	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		mark_seen(hint_id)
		if on_ack.is_valid():
			on_ack.call()
	)
	vbox.add_child(btn)

# ── Persistence ─────────────────────────────────────────────────────────────

func _save() -> void:
	JsonStore.save(SAVE_PATH, { "seen": seen })



func _load() -> void:
	var data: Dictionary = JsonStore.load_dict(SAVE_PATH)
	if data.has("seen"):
		seen = data["seen"]
