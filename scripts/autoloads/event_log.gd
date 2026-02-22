extends Node

var _entries: Array[String] = []
const MAX_ENTRIES: int = 50


func add_entry(text: String) -> void:
	_entries.append(text)
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()


func get_entries() -> Array:
	return _entries.duplicate()


func set_entries(entries: Array) -> void:
	_entries.clear()
	for e in entries:
		_entries.append(str(e))


func clear() -> void:
	_entries.clear()
