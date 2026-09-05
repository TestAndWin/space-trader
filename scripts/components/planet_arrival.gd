extends Control

## Owns the arrival event sequence. The hub only refreshes its presentation.
signal state_changed
signal finished

const SmugglerScene: PackedScene = preload("res://scenes/components/smuggler_event.tscn")
const PirateScene: PackedScene = preload("res://scenes/components/pirate_incursion_event.tscn")
const PlanetScene: PackedScene = preload("res://scenes/components/planet_event.tscn")
const CustomsScene: PackedScene = preload("res://scenes/components/customs_scan.tscn")

var running: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func run(planet: Resource) -> void:
	if running or GameManager.arrival_events_done:
		return
	running = true
	AudioManager.play_arrive_sfx()
	var before: Dictionary = _snapshot_cargo()
	var smuggler: Node = SmugglerScene.instantiate()
	add_child(smuggler)
	var had_smuggler: bool = smuggler.try_spawn()
	if had_smuggler:
		await smuggler.deal_closed
		_track_cargo_gains(before)
		state_changed.emit()
	else:
		smuggler.queue_free()

	var had_incursion: bool = false
	if planet and planet.planet_name in PirateLordManager.active_presence_planets:
		var pirate: Node = PirateScene.instantiate()
		add_child(pirate)
		had_incursion = pirate.try_trigger(planet.planet_name)
		if had_incursion:
			await pirate.event_resolved
			state_changed.emit()
		else:
			pirate.queue_free()

	if planet and not had_smuggler and not had_incursion:
		before = _snapshot_cargo()
		var event: Node = PlanetScene.instantiate()
		add_child(event)
		if event.try_trigger(planet.planet_type):
			await event.event_resolved
			_track_cargo_gains(before)
			state_changed.emit()
		else:
			event.queue_free()

	# Customs sees the hold after all other arrival choices have resolved.
	var customs: Node = CustomsScene.instantiate()
	add_child(customs)
	if customs.try_scan():
		await customs.scan_closed
		state_changed.emit()
	else:
		customs.queue_free()

	GameManager.arrival_events_done = true
	running = false
	SaveManager.save_game()
	finished.emit()


func _snapshot_cargo() -> Dictionary:
	var snapshot: Dictionary = {}
	for item: Dictionary in GameManager.cargo:
		snapshot[item["good_name"]] = item["quantity"]
	return snapshot


func _track_cargo_gains(before: Dictionary) -> void:
	for item: Dictionary in GameManager.cargo:
		var good_name: String = item["good_name"]
		var gained: int = int(item["quantity"]) - int(before.get(good_name, 0))
		if gained > 0:
			GameManager.arrival_gained_cargo[good_name] = int(GameManager.arrival_gained_cargo.get(good_name, 0)) + gained
