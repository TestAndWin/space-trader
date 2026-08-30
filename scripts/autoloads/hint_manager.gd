extends Node

## One-shot onboarding hints — shown the first time the player opens a place,
## then never again. Persisted independently of savegames (like achievements),
## so a second run does not repeat the tutorial.
##
## The hints double as the only explanation the game gives for Fuel, Loyalty,
## Reputation, Bounty and the T2 win condition, which are never introduced in
## the normal flow.

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
		"text": "Craft components here over several days, then install the finished T2 upgrade at the shipyard. You need a T2 upgrade to survive locating Crimson Jack's Hideout, along with 10k credits, 0 bounty, and all planets visited.",
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


# ── Persistence ─────────────────────────────────────────────────────────────

func _save() -> void:
	JsonStore.save(SAVE_PATH, { "seen": seen })



func _load() -> void:
	var data: Dictionary = JsonStore.load_dict(SAVE_PATH)
	if data.has("seen"):
		seen = data["seen"]
