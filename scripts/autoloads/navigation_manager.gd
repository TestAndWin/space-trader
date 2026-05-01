extends Node

## Central travel helper for galaxy travel.
## All planets can be flown to directly. PlanetData.connected_planets describes
## known safe lanes, not hard reachability.

const DISTANCE_PER_DAY: float = 250.0
const DISTANCE_PER_FUEL: float = 250.0


func get_route(origin: String, destination: String) -> Array[String]:
	if origin == "" or destination == "":
		return []
	if origin == destination:
		var same_route: Array[String] = [origin]
		return same_route
	if EconomyManager.get_planet_data(origin) == null or EconomyManager.get_planet_data(destination) == null:
		return []
	var direct_route: Array[String] = [origin, destination]
	return direct_route


func is_reachable(origin: String, destination: String) -> bool:
	return not get_route(origin, destination).is_empty()


func get_distance(origin: String, destination: String) -> float:
	var origin_planet: Resource = EconomyManager.get_planet_data(origin)
	var dest_planet: Resource = EconomyManager.get_planet_data(destination)
	if origin_planet == null or dest_planet == null:
		return -1.0
	return origin_planet.map_position.distance_to(dest_planet.map_position)


func get_travel_days(origin: String, destination: String) -> int:
	if origin == destination:
		return 0
	var distance: float = get_distance(origin, destination)
	if distance < 0.0:
		return -1
	return maxi(1, int(ceil(distance / DISTANCE_PER_DAY)))


func get_fuel_cost(origin: String, destination: String) -> int:
	if origin == destination:
		return 0
	var distance: float = get_distance(origin, destination)
	if distance < 0.0:
		return -1
	return maxi(1, int(ceil(distance / DISTANCE_PER_FUEL)))


func is_safe_lane(origin: String, destination: String) -> bool:
	var origin_planet: Resource = EconomyManager.get_planet_data(origin)
	var dest_planet: Resource = EconomyManager.get_planet_data(destination)
	if origin_planet == null or dest_planet == null:
		return false
	return destination in origin_planet.connected_planets or origin in dest_planet.connected_planets


func get_route_danger(route: Array[String]) -> int:
	var danger: int = 1
	for planet_name in route:
		var planet: Resource = EconomyManager.get_planet_data(planet_name)
		if planet:
			danger = maxi(danger, int(planet.danger_level))
	return danger
