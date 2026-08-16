extends Node

signal heat_changed(new_heat)
signal intel_changed(new_intel)
signal boss_defeated()

var heat: int = 0
var max_heat: int = 100
var active_intel: int = 0
var max_intel: int = 5
var jack_defeated: bool = false
var officers_defeated: Array[String] = []
var active_presence_planets: Array[String] = []

func emit_boss_defeated() -> void:
	boss_defeated.emit()

func add_heat(amount: int) -> void:
	heat = mini(max_heat, heat + amount)
	heat_changed.emit(heat)
	
func add_intel(amount: int) -> void:
	active_intel = mini(max_intel, active_intel + amount)
	intel_changed.emit(active_intel)

func defeat_officer(officer_name: String) -> void:
	if officer_name not in officers_defeated:
		officers_defeated.append(officer_name)

func tick() -> void:
	# Add 1 heat per turn, up to 100
	add_heat(1)
	
	# Determine pirate presence based on heat
	# E.g. at 20 heat, 1 planet. At 50, 2 planets. At 80, 3 planets.
	var num_planets = int(heat / 30.0)
	if num_planets > 0:
		var all_planets = []
		for path in ResourceRegistry.PLANETS:
			var res = load(path)
			all_planets.append(res.planet_name)
		
		# Always clear and reassign (they move around)
		active_presence_planets.clear()
		all_planets.shuffle()
		for i in min(num_planets, all_planets.size()):
			active_presence_planets.append(all_planets[i])
	else:
		active_presence_planets.clear()

func reset() -> void:
	heat = 0
	active_intel = 0
	jack_defeated = false
	officers_defeated.clear()
	active_presence_planets.clear()

func save_state() -> Dictionary:
	return {
		"heat": heat,
		"active_intel": active_intel,
		"jack_defeated": jack_defeated,
		"officers_defeated": officers_defeated.duplicate(),
		"active_presence_planets": active_presence_planets.duplicate()
	}

func load_state(data: Dictionary) -> void:
	heat = data.get("heat", 0)
	active_intel = data.get("active_intel", 0)
	jack_defeated = data.get("jack_defeated", false)
	officers_defeated.assign(data.get("officers_defeated", []))
	active_presence_planets.assign(data.get("active_presence_planets", []))
