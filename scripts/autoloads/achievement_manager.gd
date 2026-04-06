extends Node

## Global achievement system — persisted independently of savegames.
## Achievements unlock once and stay unlocked across all playthroughs.

signal achievement_unlocked(id: String)

const SAVE_PATH := "user://achievements.json"

# Achievement definitions: id -> { name, description }
const ACHIEVEMENTS := {
	"first_blood":     { "name": "First Blood",     "description": "Win your first battle." },
	"trader":          { "name": "Trader",           "description": "Complete 10 trades." },
	"master_trader":   { "name": "Master Trader",    "description": "Complete 50 trades." },
	"explorer":        { "name": "Explorer",         "description": "Visit all 7 planets." },
	"rich":            { "name": "Rich",             "description": "Hold 5000 credits at once." },
	"smuggler_king":   { "name": "Smuggler King",    "description": "Accept 10 smuggler deals." },
	"bounty_survivor": { "name": "Bounty Survivor",  "description": "Defeat a Bounty Hunter." },
	"debt_free":       { "name": "Debt Free",        "description": "Fully repay a loan." },
	"full_crew":       { "name": "Full Crew",        "description": "Have 3 crew members at once." },
	"card_collector":  { "name": "Card Collector",   "description": "Have 15+ cards in your deck." },
	"quest_champion":  { "name": "Quest Champion",   "description": "Complete 5 quests." },
	"winner":          { "name": "Winner",           "description": "Win the game." },
}

var unlocked: Dictionary = {}  # { achievement_id: bool }


func _ready() -> void:
	_load()
	achievement_unlocked.connect(_show_notification)


func unlock(id: String) -> void:
	if id not in ACHIEVEMENTS:
		return
	if unlocked.get(id, false):
		return
	unlocked[id] = true
	achievement_unlocked.emit(id)
	_save()


func is_unlocked(id: String) -> bool:
	return unlocked.get(id, false)


func get_unlocked_count() -> int:
	var count: int = 0
	for id in ACHIEVEMENTS:
		if unlocked.get(id, false):
			count += 1
	return count


func get_total_count() -> int:
	return ACHIEVEMENTS.size()


# ── Convenience check methods ───────────────────────────────────────────────

func check_credits(amount: int) -> void:
	if amount >= 5000:
		unlock("rich")


func check_trades(total: int) -> void:
	if total >= 10:
		unlock("trader")
	if total >= 50:
		unlock("master_trader")


func check_planets(visited: Array) -> void:
	if visited.size() >= 7:
		unlock("explorer")


func check_crew(crew_size: int) -> void:
	if crew_size >= 3:
		unlock("full_crew")


func check_deck(deck_size: int) -> void:
	if deck_size >= 15:
		unlock("card_collector")


func check_quests(total: int) -> void:
	if total >= 5:
		unlock("quest_champion")


func check_smuggler_deals(total: int) -> void:
	if total >= 10:
		unlock("smuggler_king")


# ── Notification ────────────────────────────────────────────────────────────

func _show_notification(id: String) -> void:
	var info: Dictionary = ACHIEVEMENTS.get(id, {})
	if info.is_empty():
		return

	var panel := PanelContainer.new()
	panel.z_index = 100
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.06, 0.95)
	style.border_color = Color(1.0, 0.9, 0.25, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var star := Label.new()
	star.text = "★"
	star.add_theme_font_size_override("font_size", 28)
	star.add_theme_color_override("font_color", Color(1.0, 0.9, 0.25))
	hbox.add_child(star)

	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vbox)

	var title := Label.new()
	title.text = "Achievement Unlocked!"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6))
	text_vbox.add_child(title)

	var name_label := Label.new()
	name_label.text = info["name"]
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.25))
	text_vbox.add_child(name_label)

	# Position top-right
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	anchor.anchor_left = 1.0
	anchor.anchor_right = 1.0
	anchor.anchor_top = 0.0
	anchor.anchor_bottom = 0.0
	anchor.offset_left = -320
	anchor.offset_top = 16
	anchor.offset_right = -16
	anchor.offset_bottom = 80
	canvas.add_child(anchor)
	anchor.add_child(panel)

	# Fade in, wait, fade out
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(3.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(canvas.queue_free)


# ── Persistence ─────────────────────────────────────────────────────────────

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	var data: Dictionary = { "unlocked": unlocked }
	file.store_string(JSON.stringify(data))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.data
	if data is Dictionary and data.has("unlocked"):
		unlocked = data["unlocked"]
