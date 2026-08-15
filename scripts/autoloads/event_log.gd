extends Node

var _entries: Array[String] = []
func add_entry(text: String) -> void:
	_entries.append(text)


func get_entries() -> Array:
	return _entries.duplicate()


func set_entries(entries: Array) -> void:
	_entries.clear()
	for e in entries:
		_entries.append(str(e))


func clear() -> void:
	_entries.clear()
