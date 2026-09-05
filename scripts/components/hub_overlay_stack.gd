extends RefCounted

## Tracks actual overlay instances in opening order, independent of node names.
var _overlays: Array[Node] = []


func register(overlay: Node) -> void:
	if overlay in _overlays:
		return
	_overlays.append(overlay)
	overlay.tree_exiting.connect(_forget.bind(overlay), CONNECT_ONE_SHOT)


func has_open_overlay() -> bool:
	return _top() != null


func close_top() -> bool:
	var overlay: Node = _top()
	if overlay == null:
		return false
	if overlay.has_method("close"):
		overlay.call("close")
	else:
		overlay.queue_free()
	return true


func _top() -> Node:
	for i: int in range(_overlays.size() - 1, -1, -1):
		var overlay: Node = _overlays[i]
		if is_instance_valid(overlay) and not overlay.is_queued_for_deletion():
			return overlay
	return null


func _forget(overlay: Node) -> void:
	_overlays.erase(overlay)
