extends RefCounted

## Ambient light effects per planet background, drawn by HubAmbience.
## Keys are background names (bg_<key>.png). Positions, rects and paths are in
## texture UV (0..1 across the full image, before the screen's aspect crop);
## radii are design pixels at 1280x720. Effect types and their fields:
##   beacon  pos, color, radius, period, phase   -- short periodic flash
##   glow    pos, color, radius, period, strength -- slow breathing halo
##   neon    rect, color, strength, dropouts_per_minute -- sign halo + flicker
##   scan    rect, color, period, phase           -- band sweeping a screen
##   traffic path, color, count, duration, radius, phase -- lights on a lane
##   launch  path, color, duration, interval, radius, phase -- craft lifting off

const WARNING_RED := Color(1.0, 0.22, 0.18)
const SIGNAL_AMBER := Color(1.0, 0.6, 0.15)
const NEON_CYAN := Color(0.3, 0.85, 1.0)
const NEON_PINK := Color(1.0, 0.3, 0.8)
const HOLO_GREEN := Color(0.45, 1.0, 0.65)
const ENGINE_WARM := Color(1.0, 0.78, 0.5)
const SUNLIGHT := Color(1.0, 0.95, 0.8)

## Effects for a background, empty when it has none.
static func effects_for(background_key: String) -> Array:
	return _presets().get(background_key, [])


# A function, not a const: PackedVector2Array literals are not constant
# expressions in GDScript.
static func _presets() -> Dictionary:
	return {
	"starport_alpha": [
		# Sun and aircraft warning lights on the towers
		{"type": "glow", "pos": Vector2(0.863, 0.059), "color": SUNLIGHT, "radius": 70.0, "period": 7.0, "strength": 0.3},
		{"type": "beacon", "pos": Vector2(0.463, 0.055), "color": WARNING_RED, "radius": 7.0, "period": 1.8, "phase": 0.0},
		{"type": "beacon", "pos": Vector2(0.612, 0.029), "color": WARNING_RED, "radius": 6.0, "period": 1.6, "phase": 0.7},
		{"type": "beacon", "pos": Vector2(0.788, 0.049), "color": WARNING_RED, "radius": 7.0, "period": 2.1, "phase": 0.4},
		{"type": "beacon", "pos": Vector2(0.662, 0.247), "color": WARNING_RED, "radius": 6.0, "period": 1.9, "phase": 0.2},
		{"type": "beacon", "pos": Vector2(0.625, 0.407), "color": WARNING_RED, "radius": 7.0, "period": 2.3, "phase": 0.55},
		# Neon signs
		{"type": "neon", "rect": Rect2(0.053, 0.254, 0.137, 0.046), "color": NEON_CYAN, "strength": 0.22, "dropouts_per_minute": 1.0},
		{"type": "neon", "rect": Rect2(0.389, 0.277, 0.063, 0.052), "color": NEON_PINK, "strength": 0.4, "dropouts_per_minute": 5.0},
		{"type": "neon", "rect": Rect2(0.456, 0.283, 0.016, 0.173), "color": NEON_PINK, "strength": 0.4, "dropouts_per_minute": 3.0},
		{"type": "neon", "rect": Rect2(0.338, 0.42, 0.071, 0.08), "color": NEON_CYAN, "strength": 0.22, "dropouts_per_minute": 0.5},
		{"type": "neon", "rect": Rect2(0.14, 0.505, 0.11, 0.11), "color": NEON_CYAN, "strength": 0.22, "dropouts_per_minute": 0.5},
		{"type": "neon", "rect": Rect2(0.64, 0.319, 0.082, 0.055), "color": NEON_CYAN, "strength": 0.2, "dropouts_per_minute": 0.5},
		{"type": "neon", "rect": Rect2(0.531, 0.507, 0.111, 0.032), "color": NEON_CYAN, "strength": 0.2, "dropouts_per_minute": 0.5},
		{"type": "neon", "rect": Rect2(0.814, 0.423, 0.176, 0.049), "color": NEON_CYAN, "strength": 0.2, "dropouts_per_minute": 0.5},
		{"type": "neon", "rect": Rect2(0.536, 0.705, 0.162, 0.114), "color": NEON_CYAN, "strength": 0.25, "dropouts_per_minute": 1.5},
		# Screens: price boards, holo panels, the mission wall
		{"type": "scan", "rect": Rect2(0.15, 0.62, 0.11, 0.2), "color": HOLO_GREEN, "period": 3.2, "phase": 0.0},
		{"type": "scan", "rect": Rect2(0.111, 0.66, 0.033, 0.214), "color": NEON_CYAN, "period": 4.5, "phase": 0.3},
		{"type": "scan", "rect": Rect2(0.531, 0.539, 0.111, 0.153), "color": NEON_CYAN, "period": 5.0, "phase": 0.6},
		{"type": "scan", "rect": Rect2(0.825, 0.2, 0.022, 0.086), "color": NEON_CYAN, "period": 3.8, "phase": 0.1},
		# Sky lane along the light ring, both directions, and the lane on the right
		{"type": "traffic", "path": PackedVector2Array([Vector2(0.40, 0.16), Vector2(0.44, 0.152), Vector2(0.55, 0.143), Vector2(0.70, 0.14), Vector2(0.85, 0.136), Vector2(0.97, 0.135)]),
			"color": NEON_CYAN, "count": 4, "duration": 16.0, "radius": 6.0},
		{"type": "traffic", "path": PackedVector2Array([Vector2(0.97, 0.13), Vector2(0.85, 0.131), Vector2(0.70, 0.135), Vector2(0.55, 0.138), Vector2(0.44, 0.147), Vector2(0.40, 0.155)]),
			"color": ENGINE_WARM, "count": 2, "duration": 21.0, "radius": 5.0, "phase": 0.3},
		{"type": "traffic", "path": PackedVector2Array([Vector2(0.86, 0.305), Vector2(1.0, 0.37)]),
			"color": NEON_CYAN, "count": 2, "duration": 6.0, "radius": 6.0},
		# Road into the city: light pulses running up the lane, cars coming down
		{"type": "traffic", "path": PackedVector2Array([Vector2(0.765, 1.0), Vector2(0.765, 0.78), Vector2(0.755, 0.6), Vector2(0.745, 0.42)]),
			"color": NEON_CYAN, "count": 3, "duration": 5.0, "radius": 9.0},
		{"type": "traffic", "path": PackedVector2Array([Vector2(0.743, 0.42), Vector2(0.753, 0.6), Vector2(0.762, 0.8), Vector2(0.766, 1.0)]),
			"color": ENGINE_WARM, "count": 2, "duration": 7.0, "radius": 6.0, "phase": 0.5},
		# Cargo on the logistics conveyor
		{"type": "traffic", "path": PackedVector2Array([Vector2(0.869, 0.559), Vector2(0.843, 0.663), Vector2(0.86, 0.773), Vector2(0.892, 0.956)]),
			"color": SIGNAL_AMBER, "count": 3, "duration": 12.0, "radius": 4.0},
		# Vehicles on the spaceport apron
		{"type": "traffic", "path": PackedVector2Array([Vector2(0.02, 0.46), Vector2(0.12, 0.44), Vector2(0.2, 0.41), Vector2(0.3, 0.38)]),
			"color": SIGNAL_AMBER, "count": 2, "duration": 14.0, "radius": 4.0},
		# Turn signals on the hover trucks, drone status light
		{"type": "beacon", "pos": Vector2(0.802, 0.855), "color": SIGNAL_AMBER, "radius": 5.0, "period": 1.0, "phase": 0.0},
		{"type": "beacon", "pos": Vector2(0.842, 0.878), "color": SIGNAL_AMBER, "radius": 5.0, "period": 1.0, "phase": 0.5},
		{"type": "beacon", "pos": Vector2(0.754, 0.832), "color": HOLO_GREEN, "radius": 4.0, "period": 1.3, "phase": 0.2},
		# A shuttle lifting off from the spaceport
		{"type": "launch", "path": PackedVector2Array([Vector2(0.218, 0.365), Vector2(0.23, 0.30), Vector2(0.28, 0.18), Vector2(0.37, 0.06), Vector2(0.45, -0.02)]),
			"color": ENGINE_WARM, "duration": 7.0, "interval": 18.0, "radius": 9.0, "phase": 16.0},
	],
	}
