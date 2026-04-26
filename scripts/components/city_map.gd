class_name CityMap
extends Control

## Isometric procedural city map drawn via _draw().
## Each building is rendered as 3 visible box faces (top, front, right).
## Emits building_clicked(id) when an interactive building is clicked.

signal building_clicked(building_id: String)

# ── Building IDs ──────────────────────────────────────────────────────────────
const BUILDING_MARKET   = "market"
const BUILDING_SHIPYARD = "shipyard"
const BUILDING_CASINO   = "casino"
const BUILDING_CREW     = "crew"
const BUILDING_QUEST    = "quest"
const BUILDING_DECK     = "deck"
const BUILDING_DEPART   = "depart"
const BUILDING_MISSION  = "mission"
const BUILDING_FACTORY  = "factory"

# ── Visual data ───────────────────────────────────────────────────────────────
const BUILDING_NAMES: Dictionary = {
	"market":   {0: "Trade Hub",    1: "Farm Stand",      2: "Mining Exchange", 3: "Trade Hub",      4: "Black Market"},
	"shipyard": {0: "Tech Bay",     1: "Repair Shed",     2: "Repair Depot",    3: "Workshop",       4: "Chop Shop"},
	"casino":   {0: "Neon Arcade",  1: "Barn Games",      2: "Casino",          3: "Casino",         4: "Smuggler's Den"},
	"crew":     {0: "Tech Academy", 1: "Farmhands Guild", 2: "Miners Guild",    3: "Engineers Corps",4: "Mercenary Outpost"},
	"quest":    {0: "Intel Office", 1: "Post Office",     2: "Dispatch Center", 3: "Logistics HQ",   4: "Dead Drop"},
	"deck":     {0: "Armory",       1: "Barn Vault",      2: "Gear Locker",     3: "Arsenal",        4: "Stash"},
	"depart":   {0: "Starport",     1: "Landing Pad",     2: "Launch Bay",      3: "Spaceport",      4: "Smuggler's Dock"},
	"mission":  {0: "Bounty Board", 1: "Bounty Board",    2: "Bounty Board",    3: "Bounty Board",   4: "Contract Board"},
	"factory":  {3: "Fabrication Plant"},
}

const BUILDING_ACCENTS: Dictionary = {
	"market":   Color(0.0, 0.85, 1.0),
	"shipyard": Color(0.4, 0.75, 1.0),
	"casino":   Color(1.0, 0.75, 0.1),
	"crew":     Color(0.3, 0.9,  0.6),
	"quest":    Color(0.4, 0.85, 0.65),
	"deck":     Color(0.7, 0.5,  1.0),
	"depart":   Color(0.0, 0.85, 0.45),
	"mission":  Color(0.3, 0.85, 1.0),
	"factory":  Color(0.8, 0.7,  0.2),
}

const BUILDING_BGS: Dictionary = {
	"market":   Color(0.04, 0.12, 0.26),
	"shipyard": Color(0.06, 0.10, 0.22),
	"casino":   Color(0.24, 0.12, 0.02),
	"crew":     Color(0.04, 0.14, 0.08),
	"quest":    Color(0.06, 0.14, 0.10),
	"deck":     Color(0.12, 0.06, 0.22),
	"depart":   Color(0.02, 0.16, 0.08),
	"mission":  Color(0.04, 0.12, 0.28),
	"factory":  Color(0.16, 0.12, 0.04),
}

# ── Iso-grid layouts ──────────────────────────────────────────────────────────
# Each entry: [id, col, row, width, depth, height]
# Grid uses cols 0..10, rows 0..10.  Streets are the gaps between buildings.

const LAYOUT_STANDARD: Array = [
	["market",   0, 0,  5, 2, 4],
	["shipyard", 6, 0,  5, 2, 3],
	["casino",   0, 3,  5, 2, 3],
	["crew",     6, 3,  5, 2, 2],
	["quest",    0, 6,  5, 2, 2],
	["deck",     6, 6,  5, 2, 2],
	["depart",   0, 9, 11, 2, 1],
]

const LAYOUT_MISSION: Array = [
	["market",   0, 0,  4, 2, 4],
	["shipyard", 7, 0,  4, 2, 3],
	["casino",   0, 3,  4, 2, 3],
	["crew",     7, 3,  4, 2, 2],
	["quest",    0, 6,  4, 2, 2],
	["mission",  4, 6,  3, 2, 2],
	["deck",     7, 6,  4, 2, 2],
	["depart",   0, 9, 11, 2, 1],
]

const LAYOUT_TECH: Array = [
	["market",   0, 0,  4, 2, 4],
	["shipyard", 7, 0,  4, 2, 3],
	["casino",   0, 3,  4, 2, 3],
	["crew",     7, 3,  4, 2, 2],
	["quest",    0, 6,  4, 2, 2],
	["mission",  4, 6,  3, 2, 2],
	["deck",     7, 6,  4, 2, 2],
	["factory",  0, 9,  5, 2, 3],
	["depart",   6, 9,  5, 2, 1],
]

# Grid bounding box (used for scaling)
const GRID_COLS := 11
const GRID_ROWS := 11
const MAX_Z     :=  4   # tallest building height

# ── Runtime state ─────────────────────────────────────────────────────────────
var _planet_type: int = 0
var _building_states: Dictionary = {}
var _buildings: Array = []
var _hovered_building: String = ""
var _time: float = 0.0

# Iso projection values (recomputed each frame in _compute_scale)
var _hw: float = 32.0   # half tile width
var _hh: float = 16.0   # half tile height
var _hz: float = 28.0   # screen pixels per z-unit
var _origin: Vector2 = Vector2.ZERO   # screen pos of grid (0,0,0)

# ── Public API ────────────────────────────────────────────────────────────────

func setup(planet_type: int, building_states: Dictionary) -> void:
	_planet_type = planet_type
	_building_states = building_states
	_build_buildings()
	queue_redraw()


func update_states(states: Dictionary) -> void:
	_building_states = states
	_build_buildings()
	queue_redraw()


# ── Internal helpers ──────────────────────────────────────────────────────────

func _build_buildings() -> void:
	_buildings = []
	var pt := _planet_type
	var has_mission := (pt == 3 or pt == 4)
	var layout: Array
	if pt == 3:
		layout = LAYOUT_TECH
	elif has_mission:
		layout = LAYOUT_MISSION
	else:
		layout = LAYOUT_STANDARD

	for entry: Array in layout:
		var bid: String = entry[0]
		var is_done: bool = _building_states.get(bid, false)
		var interactive := not is_done
		if bid == BUILDING_CASINO and pt == 2:
			is_done = true
			interactive = false
		_buildings.append({
			"id":          bid,
			"col":         float(entry[1]),
			"row":         float(entry[2]),
			"w":           float(entry[3]),
			"d":           float(entry[4]),
			"h":           float(entry[5]),
			"label":       (BUILDING_NAMES as Dictionary)[bid].get(pt, bid),
			"accent":      (BUILDING_ACCENTS as Dictionary).get(bid, Color.WHITE),
			"bg":          (BUILDING_BGS as Dictionary).get(bid, Color(0.08, 0.10, 0.18)),
			"interactive": interactive,
			"done":        is_done,
		})


# ── Isometric projection ──────────────────────────────────────────────────────

## Convert iso-grid coordinates to screen position.
## col/row are the horizontal grid axes; z is the vertical (height) axis.
func _iso(col: float, row: float, z: float = 0.0) -> Vector2:
	return Vector2(
		_origin.x + (col - row) * _hw,
		_origin.y + (col + row) * _hh - z * _hz
	)


## Convert a screen position back to iso-grid coordinates (at z=0).
func _screen_to_iso(pos: Vector2) -> Vector2:
	var dx := (pos.x - _origin.x) / _hw
	var dy := (pos.y - _origin.y) / _hh
	return Vector2((dx + dy) * 0.5, (dy - dx) * 0.5)


## Recompute tile sizes to fill the Control rect.
func _compute_scale() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var pad := 12.0
	# hz / hh ratio stays at BASE_HZ/BASE_HH (≈ 1.75)
	var hz_ratio := 1.75
	# Map screen-width  = (GRID_COLS + GRID_ROWS) * hw
	# Map screen-height = (GRID_COLS + GRID_ROWS) * hh  +  MAX_Z * hz
	#                   = hh * ( (GRID_COLS+GRID_ROWS) + MAX_Z * hz_ratio )
	var map_span   := float(GRID_COLS + GRID_ROWS)
	var hh_from_w  := (size.x - pad * 2.0) / (map_span * 2.0)
	var hh_from_h  := (size.y - pad * 2.0) / (map_span + float(MAX_Z) * hz_ratio)
	_hh = min(hh_from_w, hh_from_h)
	_hw = _hh * 2.0
	_hz = _hh * hz_ratio
	# Center horizontally; place z=0 origin so the tallest z is visible at top
	_origin.x = size.x * 0.5 - float(GRID_COLS - GRID_ROWS) * _hw * 0.5
	_origin.y = float(MAX_Z) * _hz + pad


# ── Main draw entry ───────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0 or _buildings.is_empty():
		return
	_compute_scale()
	_draw_ground()
	_draw_roads()
	# Painter's algorithm: draw back buildings first (smallest col+row = furthest)
	var sorted := _buildings.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["col"] + a["row"]) < (b["col"] + b["row"])
	)
	for b: Dictionary in sorted:
		if b["id"] == BUILDING_DEPART:
			_draw_launch_bay(b)
		else:
			_draw_iso_box(b)
	_draw_all_labels(sorted)


# ── Ground & roads ────────────────────────────────────────────────────────────

func _draw_ground() -> void:
	draw_colored_polygon(PackedVector2Array([
		_iso(0.0,             0.0,             0.0),
		_iso(float(GRID_COLS),0.0,             0.0),
		_iso(float(GRID_COLS),float(GRID_ROWS),0.0),
		_iso(0.0,             float(GRID_ROWS),0.0),
	]), Color(0.055, 0.07, 0.10))


func _draw_roads() -> void:
	var road_col  := Color(0.07, 0.09, 0.12)
	var mark_col  := Color(0.22, 0.28, 0.36, 0.55)
	var gc := float(GRID_COLS)
	var gr := float(GRID_ROWS)

	# Horizontal road strips (row gaps between building tiers)
	for ry: float in [2.0, 5.0, 8.0]:
		draw_colored_polygon(PackedVector2Array([
			_iso(0.0, ry,       0.0),
			_iso(gc,  ry,       0.0),
			_iso(gc,  ry + 1.0, 0.0),
			_iso(0.0, ry + 1.0, 0.0),
		]), road_col)
		# Dashed centre line
		draw_line(_iso(0.0, ry + 0.5, 0.0), _iso(gc, ry + 0.5, 0.0), mark_col, 1.0)

	# Vertical road strip (column gap between left and right building blocks)
	var cx := 5.0
	draw_colored_polygon(PackedVector2Array([
		_iso(cx,       0.0, 0.0),
		_iso(cx + 1.0, 0.0, 0.0),
		_iso(cx + 1.0, gr,  0.0),
		_iso(cx,       gr,  0.0),
	]), road_col)
	draw_line(_iso(cx + 0.5, 0.0, 0.0), _iso(cx + 0.5, gr, 0.0), mark_col, 1.0)


# ── Building drawing ──────────────────────────────────────────────────────────

## Draw one building as three iso faces: right wall, front wall, top face.
func _draw_iso_box(b: Dictionary) -> void:
	var c: float = b["col"]; var r: float = b["row"]
	var w: float = b["w"];   var d: float = b["d"]; var h: float = b["h"]
	var accent: Color  = b["accent"]
	var base: Color    = b["bg"]
	var hovered: bool  = (b["id"] == _hovered_building) and b["interactive"]
	var done: bool     = b["done"]
	var dim: float     = 0.5 if done else 1.0

	# Three face shades: top (lightest), front (medium), right (darkest/shadow)
	var col_top   := base.lightened(0.18) if not done else base.darkened(0.1)
	var col_front := base
	var col_right := base.darkened(0.30) if not done else base.darkened(0.4)
	if hovered:
		col_top   = col_top.lightened(0.22)
		col_front = col_front.lightened(0.12)
		col_right = col_right.lightened(0.12)

	# Right face  (col = c+w, row varies)
	var rf := PackedVector2Array([
		_iso(c+w, r,   0.0), _iso(c+w, r+d, 0.0),
		_iso(c+w, r+d, h),   _iso(c+w, r,   h),
	])
	draw_colored_polygon(rf, col_right)
	draw_polyline(PackedVector2Array([rf[0], rf[1], rf[2], rf[3], rf[0]]),
		Color(accent, 0.25 * dim), 0.7)

	# Front face  (row = r+d, facing the viewer)
	var ff := PackedVector2Array([
		_iso(c,   r+d, 0.0), _iso(c+w, r+d, 0.0),
		_iso(c+w, r+d, h),   _iso(c,   r+d, h),
	])
	draw_colored_polygon(ff, col_front)
	draw_polyline(PackedVector2Array([ff[0], ff[1], ff[2], ff[3], ff[0]]),
		Color(accent, 0.25 * dim), 0.7)

	# Window dots on front face (2 rows × 3 cols)
	_draw_windows_on_face(c, r + d, w, h, accent, dim)

	# Top face
	var tf := PackedVector2Array([
		_iso(c,   r,   h), _iso(c+w, r,   h),
		_iso(c+w, r+d, h), _iso(c,   r+d, h),
	])
	draw_colored_polygon(tf, col_top)

	# Top outline
	var ow: float  = 2.0 if hovered else 1.0
	var ocol: Color = accent if hovered else Color(accent, 0.55 * dim)
	draw_polyline(PackedVector2Array([tf[0], tf[1], tf[2], tf[3], tf[0]]), ocol, ow)

	# Animated glow ring on hover
	if hovered:
		var pulse := (sin(_time * 4.0) + 1.0) * 0.5
		draw_polyline(PackedVector2Array([tf[0], tf[1], tf[2], tf[3], tf[0]]),
			Color(accent, 0.18 + pulse * 0.18), 4.5)

	# Desaturate done buildings with a dark overlay
	if done:
		var ov := Color(0.0, 0.0, 0.0, 0.38)
		draw_colored_polygon(rf, ov)
		draw_colored_polygon(ff, ov)
		draw_colored_polygon(tf, ov)

	# Decorative rooftop element: small box on top for tall buildings
	if h >= 3.0 and not done:
		_draw_rooftop(b, accent)


## r_front is the row-coordinate of the front face (= building row + depth).
func _draw_windows_on_face(c: float, r_front: float, w: float, h: float,
		accent: Color, dim: float) -> void:
	if w < 1.5 or h < 1.5:
		return
	var win_col := Color(accent, 0.45 * dim)
	var cols_n := 3
	var rows_n := 2
	for wr in range(rows_n):
		for wc in range(cols_n):
			var fc := c + w * (float(wc) + 0.5) / float(cols_n + 0.5)
			var fz := h * (float(wr) + 0.6) / float(rows_n + 0.5)
			var p0 := _iso(fc,          r_front, fz)
			var p1 := _iso(fc + w*0.09, r_front, fz)
			var p2 := _iso(fc + w*0.09, r_front, fz + h*0.12)
			var p3 := _iso(fc,          r_front, fz + h*0.12)
			draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), win_col)


func _draw_rooftop(b: Dictionary, accent: Color) -> void:
	# Small centered box raised above the building top
	var c: float = b["col"]; var r: float = b["row"]
	var w: float = b["w"];   var d: float = b["d"]; var h: float = b["h"]
	var rw := w * 0.35; var rd := d * 0.35; var rh := 0.6
	var rc := c + (w - rw) * 0.5; var rr := r + (d - rd) * 0.5
	var base: Color = b["bg"]
	# Right face
	draw_colored_polygon(PackedVector2Array([
		_iso(rc+rw, rr,    h), _iso(rc+rw, rr+rd, h),
		_iso(rc+rw, rr+rd, h+rh), _iso(rc+rw, rr, h+rh),
	]), base.lightened(0.1))
	# Front face (facing viewer = row side at rr+rd)
	draw_colored_polygon(PackedVector2Array([
		_iso(rc,    rr+rd, h), _iso(rc+rw, rr+rd, h),
		_iso(rc+rw, rr+rd, h+rh), _iso(rc, rr+rd, h+rh),
	]), base.lightened(0.25))
	# Top face
	draw_colored_polygon(PackedVector2Array([
		_iso(rc,    rr,    h+rh), _iso(rc+rw, rr,    h+rh),
		_iso(rc+rw, rr+rd, h+rh), _iso(rc,    rr+rd, h+rh),
	]), base.lightened(0.35))
	# Outline
	draw_polyline(PackedVector2Array([
		_iso(rc,    rr,    h+rh), _iso(rc+rw, rr,    h+rh),
		_iso(rc+rw, rr+rd, h+rh), _iso(rc,    rr+rd, h+rh),
		_iso(rc,    rr,    h+rh),
	]), Color(accent, 0.6), 1.0)


## Special drawing for the Launch Bay (flat with landing-pad markings).
func _draw_launch_bay(b: Dictionary) -> void:
	var c: float = b["col"]; var r: float = b["row"]
	var w: float = b["w"];   var d: float = b["d"]; var h: float = b["h"]
	var accent: Color = b["accent"]
	var base: Color   = b["bg"]
	var hovered: bool = (b["id"] == _hovered_building)

	# Right wall
	var rf := PackedVector2Array([
		_iso(c+w, r,   0.0), _iso(c+w, r+d, 0.0),
		_iso(c+w, r+d, h),   _iso(c+w, r,   h),
	])
	draw_colored_polygon(rf, base.darkened(0.3))

	# Front wall (facing viewer = row = r+d)
	var ff := PackedVector2Array([
		_iso(c,   r+d, 0.0), _iso(c+w, r+d, 0.0),
		_iso(c+w, r+d, h),   _iso(c,   r+d, h),
	])
	draw_colored_polygon(ff, base)

	# Top / floor of bay
	var tf := PackedVector2Array([
		_iso(c,   r,   h), _iso(c+w, r,   h),
		_iso(c+w, r+d, h), _iso(c,   r+d, h),
	])
	draw_colored_polygon(tf, base.lightened(0.08))

	# Landing pad: concentric diamond rings centred on top face
	var pad_c  := c + w * 0.35
	var pad_r  := r + d * 0.5
	var pad_sz := minf(w, d) * 0.38
	for ring_frac: float in [1.0, 0.7, 0.4]:
		var rr := pad_sz * ring_frac
		draw_polyline(PackedVector2Array([
			_iso(pad_c - rr, pad_r,      h),
			_iso(pad_c,      pad_r - rr, h),
			_iso(pad_c + rr, pad_r,      h),
			_iso(pad_c,      pad_r + rr, h),
			_iso(pad_c - rr, pad_r,      h),
		]), Color(0.0, 0.8, 0.4, 0.35 * ring_frac), 1.2)

	# Animated blink lights at pad corners
	var blink := (sin(_time * 2.2) + 1.0) * 0.5
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var lp := Vector2(pad_c + cos(angle) * pad_sz * 0.65,
						  pad_r + sin(angle) * pad_sz * 0.35)
		draw_circle(_iso(lp.x, lp.y, h), 2.5, Color(1.0, 0.3, 0.1, blink))

	# Top outline
	var ow: float   = 2.0 if hovered else 1.0
	var ocol: Color = accent if hovered else Color(accent, 0.55)
	draw_polyline(PackedVector2Array([tf[0], tf[1], tf[2], tf[3], tf[0]]), ocol, ow)
	if hovered:
		var pulse := (sin(_time * 4.0) + 1.0) * 0.5
		draw_polyline(PackedVector2Array([tf[0], tf[1], tf[2], tf[3], tf[0]]),
			Color(accent, 0.18 + pulse * 0.18), 4.5)


# ── Labels ────────────────────────────────────────────────────────────────────

func _draw_all_labels(sorted_buildings: Array) -> void:
	var font := get_theme_default_font()
	for b: Dictionary in sorted_buildings:
		var c: float = b["col"]; var r: float = b["row"]
		@warning_ignore("unused_variable")
		var w: float = b["w"];   var d: float = b["d"]; var h: float = b["h"]
		var accent: Color = b["accent"]
		var done: bool    = b["done"]

		# Label position: above the front-top edge of the building
		var label_pos := _iso(c + w * 0.5, r, h + 0.25)
		var fs := 9
		var text: String = b["label"]
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var alpha := 0.45 if done else 1.0
		var tcol  := Color(accent, alpha)

		# Small dark backdrop
		draw_rect(Rect2(label_pos.x - tw * 0.5 - 2.0, label_pos.y - float(fs) - 1.0,
			tw + 4.0, float(fs) + 3.0), Color(0.0, 0.0, 0.0, 0.55 * alpha))
		draw_string(font, Vector2(label_pos.x - tw * 0.5, label_pos.y),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)


# ── Input ─────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_click(mb.position)


## Returns the building whose floor footprint contains iso_pos, or null.
## Buildings are checked back-to-front so front ones take priority.
func _hit_building(iso_pos: Vector2) -> Dictionary:
	# Iterate front to back (reverse of paint order)
	for i in range(_buildings.size() - 1, -1, -1):
		var b: Dictionary = _buildings[i]
		var fc := iso_pos.x
		var fr := iso_pos.y
		if fc >= b["col"] and fc <= b["col"] + b["w"] \
				and fr >= b["row"] and fr <= b["row"] + b["d"]:
			return b
	return {}


func _update_hover(screen_pos: Vector2) -> void:
	var iso_pos := _screen_to_iso(screen_pos)
	var hit     := _hit_building(iso_pos)
	var new_id  := hit.get("id", "") as String
	# Only hover interactive buildings
	if new_id != "" and not (hit.get("interactive", false) as bool):
		new_id = ""
	if new_id == _hovered_building:
		return
	_hovered_building = new_id
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND \
		if new_id != "" else Control.CURSOR_ARROW
	queue_redraw()


func _handle_click(screen_pos: Vector2) -> void:
	var iso_pos := _screen_to_iso(screen_pos)
	var hit     := _hit_building(iso_pos)
	if hit.is_empty():
		return
	if hit.get("interactive", false):
		building_clicked.emit(hit["id"] as String)
