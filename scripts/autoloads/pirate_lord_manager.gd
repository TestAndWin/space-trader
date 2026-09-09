extends Node

## Every defeated officer thins out Jack's fleet before the final fight.
const OFFICER_WEAKEN_HP: int = 10

## Jack's health is decided here, not by his .tres: it scales with the
## difficulty and with the officers the player has already hunted down.
const JACK_BASE_HEALTH_EASY: int = 70
const JACK_BASE_HEALTH_NORMAL: int = 100
const JACK_BASE_HEALTH_HARD: int = 130


var heat: int = 0
var max_heat: int = 100
var jack_defeated: bool = false
var officers_defeated: Array[String] = []
var active_presence_planets: Array[String] = []

func add_heat(amount: int) -> void:
	heat = mini(max_heat, heat + amount)
	
func defeat_officer(officer_name: String) -> void:
	officers_defeated.append(officer_name)

## Health for the Crimson Jack encounter, difficulty and officer kills applied.
func get_jack_health() -> int:
	var base: int = JACK_BASE_HEALTH_NORMAL
	match GameManager.difficulty:
		GameManager.Difficulty.EASY: base = JACK_BASE_HEALTH_EASY
		GameManager.Difficulty.HARD: base = JACK_BASE_HEALTH_HARD
	return maxi(1, base - officers_defeated.size() * OFFICER_WEAKEN_HP)


func tick() -> void:
	if GameManager.victory_triggered:
		heat = 0
		active_presence_planets.clear()
		return
	# Add 1 heat per turn, up to 100
	add_heat(1)
	
	# Determine pirate presence based on heat
	# E.g. at 20 heat, 1 planet. At 50, 2 planets. At 80, 3 planets.
	var num_planets: int = int(heat / 30.0)
	if num_planets > 0:
		var all_planets: Array = []
		for path in ResourceRegistry.PLANETS:
			var res: Resource = load(path)
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
	jack_defeated = false
	officers_defeated.clear()
	active_presence_planets.clear()

func save_state() -> Dictionary:
	return {
		"heat": heat,
		"jack_defeated": jack_defeated,
		"officers_defeated": officers_defeated.duplicate(),
		"active_presence_planets": active_presence_planets.duplicate()
	}

func load_state(data: Dictionary) -> void:
	heat = data.get("heat", 0)
	jack_defeated = data.get("jack_defeated", false)
	officers_defeated.assign(data.get("officers_defeated", []))
	active_presence_planets.assign(data.get("active_presence_planets", []))
