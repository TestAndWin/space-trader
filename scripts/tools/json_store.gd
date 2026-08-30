extends RefCounted

## Small JSON-file helper for the two settings stores that live outside the
## savegame (achievements, onboarding hints). Both used to carry their own copy
## of the same open/parse/guard sequence.
##
## Loaded via preload(), not an autoload.


## Writes `data` as JSON. Silently does nothing if the file cannot be opened —
## these stores are conveniences, a failed write must never break the game.
static func save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(data))


## Reads a JSON dictionary. Returns {} when the file is missing, unreadable or
## does not contain a dictionary, so callers can index it without checking.
static func load_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data: Variant = json.data
	return data if data is Dictionary else {}
