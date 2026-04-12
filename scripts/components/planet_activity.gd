extends ColorRect

## Planet Activity — planet-type-specific mini-game / risk-reward activity.
## Launched from the "mission" building on the planet hub. Each planet type
## has its own activity flavor and mechanic. Once completed (or aborted with
## an outcome) the activity is flagged as done for this landing.

signal activity_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

# Activity kinds — mapped from planet_type
enum Kind { HACKING, MINING, HARVEST, SMUGGLER_RACE, FACTORY }

const ENTRY_FEE: int = 100

var _kind: int = Kind.FACTORY
var _planet_type: int = 0

# UI nodes (built in _build_ui)
var _title_label: Label
var _subtitle_label: Label
var _description_label: Label
var _status_label: Label
var _button_box: VBoxContainer
var _log_label: Label
var _close_btn: Button

# Shared state
var _log_lines: Array[String] = []
var _finished: bool = false

# Hacking state
var _hack_layer: int = 0
var _hack_haul: int = 0
var _hack_noise: int = 0
var _hack_hull_loss: int = 0
const HACK_LAYERS: int = 3

# Mining state
var _mine_depth: int = 0
var _mine_haul: int = 0
const MINE_MAX_DEPTH: int = 4

# Smuggler race state
var _race_leg: int = 0
var _race_prize: int = 0
var _race_heat: int = 0
var _race_hull_loss: int = 0
var _race_bounty_gain: int = 0
const RACE_LEGS: int = 3

# Forge Strike state (Industrial)
const FORGE_STRIKES: int = 3
const FORGE_BAR_WIDTH: float = 420.0
const FORGE_BAR_HEIGHT: float = 40.0
var _forge_strike: int = 0
var _forge_haul: int = 0
var _forge_hull_loss: int = 0
var _forge_active: bool = false
var _forge_marker_pos: float = 0.0   # 0.0 .. 1.0 along the bar
var _forge_marker_dir: float = 1.0
var _forge_speed: float = 0.9        # full traversals per second
var _forge_bar: Control = null
var _forge_marker: ColorRect = null


# ── Public API ───────────────────────────────────────────────────────────────

func try_open(planet_type: int) -> bool:
	if GameManager.mission_done_this_landing:
		return false
	if GameManager.credits < ENTRY_FEE:
		EventLog.add_entry("Not enough credits for planet activity (%dcr required)." % ENTRY_FEE)
		return false
	_planet_type = planet_type
	_kind = _kind_for_type(planet_type)
	GameManager.remove_credits(ENTRY_FEE)
	GameManager.mission_done_this_landing = true
	EventLog.add_entry("Started %s activity (-%dcr)." % [_activity_name(), ENTRY_FEE])
	visible = true
	_start_activity()
	return true


func _kind_for_type(pt: int) -> int:
	match pt:
		PlanetData.PlanetType.TECH:         return Kind.HACKING
		PlanetData.PlanetType.MINING:       return Kind.MINING
		PlanetData.PlanetType.AGRICULTURAL: return Kind.HARVEST
		PlanetData.PlanetType.OUTLAW:       return Kind.SMUGGLER_RACE
		_:                                   return Kind.FACTORY


func _activity_name() -> String:
	match _kind:
		Kind.HACKING:        return "Data Heist"
		Kind.MINING:         return "Deep Mining Expedition"
		Kind.HARVEST:        return "Harvest Market"
		Kind.SMUGGLER_RACE:  return "Smuggler Race"
		_:                    return "Forge Strike"


func _activity_subtitle() -> String:
	match _kind:
		Kind.HACKING:        return "Slice through corporate ICE layer by layer."
		Kind.MINING:         return "Push the drill deeper. Each layer richer — and riskier."
		Kind.HARVEST:        return "Pick a bulk harvest lot at a local discount."
		Kind.SMUGGLER_RACE:  return "Three checkpoints. Push hard or cruise."
		_:                    return "Time the hammer strike on the molten core."


# ── UI construction ──────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.12, 0.96)
	style.border_color = Color(0.0, 0.65, 0.95, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 12)
	_subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	_subtitle_label.custom_minimum_size = Vector2(420, 0)
	vbox.add_child(_subtitle_label)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.2, 0.4, 0.6))
	vbox.add_child(sep)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(_status_label)

	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 13)
	_description_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	_description_label.custom_minimum_size = Vector2(420, 0)
	vbox.add_child(_description_label)

	_button_box = VBoxContainer.new()
	_button_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_button_box)

	var log_frame := PanelContainer.new()
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.0, 0.04, 0.08, 0.7)
	log_style.border_color = Color(0.0, 0.3, 0.55, 0.5)
	log_style.set_border_width_all(1)
	log_style.set_corner_radius_all(4)
	log_style.set_content_margin_all(6)
	log_frame.add_theme_stylebox_override("panel", log_style)
	vbox.add_child(log_frame)

	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.add_theme_font_size_override("font_size", 11)
	_log_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.9))
	_log_label.custom_minimum_size = Vector2(420, 72)
	log_frame.add_child(_log_label)

	_close_btn = Button.new()
	_close_btn.custom_minimum_size = Vector2(160, 36)
	_close_btn.text = "Leave"
	_close_btn.visible = false
	UIStyles.style_accent_button(_close_btn, Color(0.2, 0.4, 0.7))
	_close_btn.pressed.connect(_close)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.add_child(_close_btn)
	vbox.add_child(close_row)


# ── Shared helpers ───────────────────────────────────────────────────────────

func _log(line: String) -> void:
	_log_lines.append(line)
	if _log_lines.size() > 6:
		_log_lines = _log_lines.slice(_log_lines.size() - 6)
	_log_label.text = "\n".join(_log_lines)


func _clear_buttons() -> void:
	for child in _button_box.get_children():
		child.queue_free()


func _add_choice(label: String, callback: Callable, disabled: bool = false, hint: String = "") -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(420, 36)
	UIStyles.style_secondary_button(btn, 13)
	btn.disabled = disabled
	if hint != "":
		btn.tooltip_text = hint
	btn.pressed.connect(callback)
	_button_box.add_child(btn)


func _finish(summary: String) -> void:
	_finished = true
	_clear_buttons()
	_status_label.text = "Completed"
	_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	_description_label.text = summary
	_close_btn.visible = true
	_close_btn.text = "Continue"


func _close() -> void:
	activity_closed.emit()
	queue_free()


# ── Dispatcher ───────────────────────────────────────────────────────────────

func _start_activity() -> void:
	_title_label.text = _activity_name().to_upper()
	_subtitle_label.text = _activity_subtitle()
	match _kind:
		Kind.HACKING:        _hacking_show()
		Kind.MINING:         _mining_show()
		Kind.HARVEST:        _harvest_show()
		Kind.SMUGGLER_RACE:  _race_show()
		_:                    _factory_show()


# ── TECH: Data Heist ─────────────────────────────────────────────────────────
# Three ICE layers. Each layer choose Stealth (low success, low noise) or
# Brute (high success, raises noise). Fail = -3 hull, layer retries. After
# layer 3, extract payout. High noise risks bounty on exit.

func _hacking_show() -> void:
	_status_label.text = "Layer %d / %d — Haul: %d cr — Noise: %d" % [_hack_layer + 1, HACK_LAYERS, _hack_haul, _hack_noise]
	_description_label.text = "Slice through the ICE. Stealth keeps you quiet; Brute is loud but reliable."
	_clear_buttons()
	if _hack_layer >= HACK_LAYERS:
		_hacking_extract()
		return
	_add_choice("Stealth Slice  (50% — +180cr)", Callable(self, "_hacking_try").bind(0.50, 180, 0))
	_add_choice("Brute Force    (70% — +240cr, +2 noise)", Callable(self, "_hacking_try").bind(0.70, 240, 2))
	_add_choice("Abort & Run", Callable(self, "_hacking_abort"))


func _hacking_try(success_chance: float, reward: int, noise_gain: int) -> void:
	if randf() < success_chance:
		_hack_haul += reward
		_hack_noise += noise_gain
		_hack_layer += 1
		_log("Layer %d breached (+%dcr, noise +%d)." % [_hack_layer, reward, noise_gain])
	else:
		# Brute fails hurt more and still add a point of noise (alarms).
		var dmg: int = 4 if noise_gain == 0 else 6
		GameManager.current_hull = maxi(GameManager.current_hull - dmg, 1)
		_hack_hull_loss += dmg
		if noise_gain > 0:
			_hack_noise += 1
			_log("Trace burn! Hull -%d, noise +1." % dmg)
		else:
			_log("Trace burn! Hull -%d." % dmg)
	_hacking_show()


func _hacking_abort() -> void:
	var keep: int = int(_hack_haul * 0.4)
	GameManager.add_credits(keep)
	_log("Aborted. Kept %dcr from partial haul." % keep)
	var abort_log: String = "Data Heist aborted: +%dcr (partial haul)" % keep
	if _hack_hull_loss > 0:
		abort_log += ", -%d hull" % _hack_hull_loss
	EventLog.add_entry(abort_log + ".")
	_finish("You pulled out early with %dcr." % keep)


func _hacking_extract() -> void:
	var payout: int = _hack_haul
	GameManager.add_credits(payout)
	var summary: String = "Extraction complete. +%dcr." % payout
	# Each point of noise is an independent 15% trace roll on exit.
	var traces: int = 0
	for i in _hack_noise:
		if randf() < 0.15:
			traces += 1
	var log_parts: Array[String] = ["+%dcr" % payout]
	if traces > 0:
		var bounty_gain: int = traces * 15
		var hull_loss: int = traces * 2
		GameManager.add_bounty(bounty_gain, "Corporate data heist traced")
		GameManager.current_hull = maxi(GameManager.current_hull - hull_loss, 1)
		_hack_hull_loss += hull_loss
		var plural: String = "s" if traces > 1 else ""
		summary += "\n%d trace hit%s on exit: +%d bounty, -%d hull." % [traces, plural, bounty_gain, hull_loss]
		_log("Corp sec logged %d trace hit%s." % [traces, plural])
		log_parts.append("+%d bounty" % bounty_gain)
	else:
		_log("Silent exit. %dcr banked." % payout)
	if _hack_hull_loss > 0:
		log_parts.append("-%d hull" % _hack_hull_loss)
	EventLog.add_entry("Data Heist complete: " + ", ".join(log_parts) + ".")
	_finish(summary)


# ── MINING: Deep Expedition ──────────────────────────────────────────────────
# Each dig yields credits but cave-in risk grows with depth.
# "Extract Now" ends with current haul.
# Cave-in: hull damage + haul halved.

func _mining_show() -> void:
	_status_label.text = "Depth %d / %d — Haul: %d cr" % [_mine_depth, MINE_MAX_DEPTH, _mine_haul]
	_description_label.text = "Drill deeper for richer deposits, or extract your haul. Cave-in risk rises each layer."
	_clear_buttons()
	if _mine_depth >= MINE_MAX_DEPTH:
		_mining_extract(false)
		return
	var cavein_pct: int = 15 + _mine_depth * 15
	_add_choice("Dig Deeper  (+80–220cr, %d%% cave-in)" % cavein_pct, Callable(self, "_mining_dig"))
	_add_choice("Extract Now (+0cr, safe)", Callable(self, "_mining_extract").bind(false))


func _mining_dig() -> void:
	var cavein_chance: float = 0.15 + float(_mine_depth) * 0.15
	if randf() < cavein_chance:
		_mine_haul = _mine_haul / 2
		var dmg: int = 6 + _mine_depth * 3
		GameManager.current_hull = maxi(GameManager.current_hull - dmg, 1)
		_log("Cave-in at depth %d! Hull -%d, haul halved." % [_mine_depth + 1, dmg])
		_mining_extract(true)
		return
	var yield_cr: int = randi_range(80, 220) + _mine_depth * 30
	_mine_haul += yield_cr
	_mine_depth += 1
	_log("Struck ore at depth %d (+%dcr)." % [_mine_depth, yield_cr])
	_mining_show()


func _mining_extract(after_cavein: bool) -> void:
	GameManager.add_credits(_mine_haul)
	var summary: String = ""
	if after_cavein:
		var dmg: int = 6 + _mine_depth * 3
		summary = "Barely escaped with %dcr." % _mine_haul
		EventLog.add_entry("Mining Expedition: cave-in at depth %d, +%dcr salvaged, -%d hull." % [_mine_depth + 1, _mine_haul, dmg])
	else:
		summary = "Crew returned safe with %dcr." % _mine_haul
		EventLog.add_entry("Mining Expedition complete: +%dcr (depth %d)." % [_mine_haul, _mine_depth])
	_finish(summary)


# ── AGRICULTURAL: Harvest Market ─────────────────────────────────────────────
# Pick one of three bulk lots (goods at a discount). Adds to cargo.

const HARVEST_LOTS: Array = [
	{"good": "Food Rations", "qty": 4,  "price": 72,  "label": "Small lot — 4x Food Rations  @18cr"},
	{"good": "Food Rations", "qty": 8,  "price": 128, "label": "Medium lot — 8x Food Rations @16cr"},
	{"good": "Food Rations", "qty": 14, "price": 196, "label": "Bulk lot — 14x Food Rations  @14cr"},
]


func _harvest_show() -> void:
	_status_label.text = "Open air bazaar — bulk discount prices"
	_description_label.text = "The co-op is auctioning off today's harvest. Pick a lot to haul off-world."
	_clear_buttons()
	for lot in HARVEST_LOTS:
		var can_afford: bool = GameManager.credits >= lot.price
		var has_space: bool = GameManager.can_add_cargo(lot.good, lot.qty)
		var disabled: bool = not (can_afford and has_space)
		var hint: String = ""
		if not can_afford:
			hint = "Need %d cr" % lot.price
		elif not has_space:
			hint = "Not enough cargo space"
		var label: String = "%s  (%d cr)" % [lot.label, lot.price]
		var captured: Dictionary = lot
		_add_choice(label, Callable(self, "_harvest_buy").bind(captured), disabled, hint)
	_add_choice("Walk away", Callable(self, "_harvest_walk"))


func _harvest_buy(lot: Dictionary) -> void:
	GameManager.remove_credits(lot.price)
	GameManager.add_cargo(lot.good, lot.qty)
	_log("Bought %dx %s for %dcr." % [lot.qty, lot.good, lot.price])
	EventLog.add_entry("Harvest Market: -%dcr, +%dx %s." % [lot.price, lot.qty, lot.good])
	_finish("Loaded %dx %s into the hold for %dcr." % [lot.qty, lot.good, lot.price])


func _harvest_walk() -> void:
	_log("Left the bazaar empty-handed.")
	EventLog.add_entry("Harvest Market: walked away empty-handed.")
	_finish("You turned down today's lots.")


# ── OUTLAW: Smuggler Race ────────────────────────────────────────────────────
# Three checkpoints. Boost (big prize, patrol risk) or Cruise (small prize, safe).
# Patrol hit: -5 hull, +30 bounty.

func _race_show() -> void:
	_status_label.text = "Checkpoint %d / %d — Prize: %d cr — Heat: %d" % [_race_leg + 1, RACE_LEGS, _race_prize, _race_heat]
	_description_label.text = "Thread the asteroid belt. Boost for big purses, cruise to stay off patrol scopes."
	_clear_buttons()
	if _race_leg >= RACE_LEGS:
		_race_finish()
		return
	_add_choice("Boost  (+300cr, 35% patrol)", Callable(self, "_race_choice").bind(true, 300, 0.35))
	_add_choice("Cruise (+110cr, 5% patrol)", Callable(self, "_race_choice").bind(false, 110, 0.05))


func _race_choice(boosted: bool, prize: int, patrol_pct: float) -> void:
	_race_prize += prize
	if randf() < patrol_pct:
		var dmg: int = 5
		GameManager.current_hull = maxi(GameManager.current_hull - dmg, 1)
		GameManager.add_bounty(30, "Smuggler race patrol clip")
		_race_heat += 1
		_race_hull_loss += dmg
		_race_bounty_gain += 30
		var tag: String = "Boost" if boosted else "Cruise"
		_log("%s leg %d: patrol clipped you! -%d hull, +30 bounty." % [tag, _race_leg + 1, dmg])
	else:
		var tag2: String = "Boost" if boosted else "Cruise"
		_log("%s leg %d clean. +%dcr." % [tag2, _race_leg + 1, prize])
	_race_leg += 1
	_race_show()


func _race_finish() -> void:
	GameManager.add_credits(_race_prize)
	var summary: String = "Crossed the finish line with %dcr." % _race_prize
	var parts: Array[String] = ["+%dcr" % _race_prize]
	if _race_hull_loss > 0:
		parts.append("-%d hull" % _race_hull_loss)
	if _race_bounty_gain > 0:
		parts.append("+%d bounty" % _race_bounty_gain)
	if _race_heat == 0:
		summary += "\nGhost run — zero heat."
		EventLog.add_entry("Smuggler Race complete: " + ", ".join(parts) + " (ghost run).")
	else:
		EventLog.add_entry("Smuggler Race complete: " + ", ".join(parts) + ".")
	_finish(summary)


# ── INDUSTRIAL: Forge Strike ─────────────────────────────────────────────────
# Timing mini-game. A marker sweeps left/right across a bar with color zones.
# The player hits STRIKE (button click) to lock the marker. Closer to the
# sweet centre = bigger payout. Missing the scored zones recoils the hammer
# into the hull. Each strike speeds the marker up and shrinks the zones.


func _factory_show() -> void:
	_status_label.text = "Strike %d / %d — Haul: %d cr" % [_forge_strike + 1, FORGE_STRIKES, _forge_haul]
	_description_label.text = "Time the hammer on the glowing core. Zones shrink and the marker speeds up with each strike."
	_clear_buttons()
	if _forge_strike >= FORGE_STRIKES:
		_forge_finish()
		return
	_build_forge_bar()
	var btn := Button.new()
	btn.text = "▼  STRIKE  ▼"
	btn.custom_minimum_size = Vector2(FORGE_BAR_WIDTH, 40)
	UIStyles.style_secondary_button(btn, 16)
	btn.pressed.connect(_forge_on_strike)
	_button_box.add_child(btn)
	_forge_marker_pos = 0.0
	_forge_marker_dir = 1.0
	_forge_speed = 0.9 + _forge_strike * 0.45
	_forge_active = true


func _forge_zone_widths() -> Dictionary:
	# Half-widths (pixels from centre). Shrink per strike.
	return {
		"perfect": maxf(22.0 - _forge_strike * 5.0, 10.0),
		"green":   maxf(65.0 - _forge_strike * 10.0, 30.0),
		"yellow":  maxf(120.0 - _forge_strike * 12.0, 60.0),
	}


func _build_forge_bar() -> void:
	if _forge_bar and is_instance_valid(_forge_bar):
		_forge_bar.queue_free()
	_forge_bar = Control.new()
	_forge_bar.custom_minimum_size = Vector2(FORGE_BAR_WIDTH, FORGE_BAR_HEIGHT)
	_forge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button_box.add_child(_forge_bar)

	# Background (miss zone)
	var bg := ColorRect.new()
	bg.size = Vector2(FORGE_BAR_WIDTH, FORGE_BAR_HEIGHT)
	bg.color = Color(0.35, 0.08, 0.08, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forge_bar.add_child(bg)

	var centre_x: float = FORGE_BAR_WIDTH * 0.5
	var widths: Dictionary = _forge_zone_widths()
	_add_forge_zone(centre_x - widths.yellow,  widths.yellow  * 2.0, Color(0.85, 0.65, 0.1, 0.9))
	_add_forge_zone(centre_x - widths.green,   widths.green   * 2.0, Color(0.2, 0.75, 0.3, 0.95))
	_add_forge_zone(centre_x - widths.perfect, widths.perfect * 2.0, Color(1.0, 0.95, 0.35, 1.0))

	# Centre hairline
	var line := ColorRect.new()
	line.position = Vector2(centre_x - 1, 0)
	line.size = Vector2(2, FORGE_BAR_HEIGHT)
	line.color = Color(1.0, 1.0, 1.0, 0.55)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forge_bar.add_child(line)

	# Moving marker — tall vertical bar that overhangs above + below the zones,
	# with a dark outline and a bright white core so it stays visible over any
	# zone color.
	_forge_marker = ColorRect.new()
	_forge_marker.size = Vector2(8, FORGE_BAR_HEIGHT + 20)
	_forge_marker.position = Vector2(0, -10)
	_forge_marker.color = Color(0.05, 0.0, 0.0, 1.0)
	_forge_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forge_bar.add_child(_forge_marker)

	var marker_core := ColorRect.new()
	marker_core.size = Vector2(2, FORGE_BAR_HEIGHT + 20)
	marker_core.position = Vector2(3, 0)
	marker_core.color = Color(1.0, 1.0, 1.0, 1.0)
	marker_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forge_marker.add_child(marker_core)


func _add_forge_zone(x: float, w: float, color: Color) -> void:
	var r := ColorRect.new()
	r.position = Vector2(x, 0)
	r.size = Vector2(w, FORGE_BAR_HEIGHT)
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forge_bar.add_child(r)


func _process(delta: float) -> void:
	if not _forge_active:
		return
	if _forge_marker == null or not is_instance_valid(_forge_marker):
		return
	_forge_marker_pos += _forge_marker_dir * _forge_speed * delta
	if _forge_marker_pos >= 1.0:
		_forge_marker_pos = 1.0
		_forge_marker_dir = -1.0
	elif _forge_marker_pos <= 0.0:
		_forge_marker_pos = 0.0
		_forge_marker_dir = 1.0
	var x: float = _forge_marker_pos * (FORGE_BAR_WIDTH - _forge_marker.size.x)
	_forge_marker.position = Vector2(x, 0)


func _forge_on_strike() -> void:
	if not _forge_active:
		return
	_forge_active = false
	var marker_centre: float = _forge_marker_pos * (FORGE_BAR_WIDTH - _forge_marker.size.x) + _forge_marker.size.x * 0.5
	var bar_centre: float = FORGE_BAR_WIDTH * 0.5
	var dist: float = abs(marker_centre - bar_centre)
	var widths: Dictionary = _forge_zone_widths()
	var payout: int = 0
	var label: String = ""
	if dist <= widths.perfect:
		payout = 260
		label = "PERFECT STRIKE"
	elif dist <= widths.green:
		payout = 150
		label = "Solid strike"
	elif dist <= widths.yellow:
		payout = 60
		label = "Glancing blow"
	else:
		payout = 0
		var dmg: int = 5
		GameManager.current_hull = maxi(GameManager.current_hull - dmg, 1)
		_forge_hull_loss += dmg
		label = "Missed — hammer recoil, hull -%d" % dmg
	if payout > 0:
		_forge_haul += payout
		_log("%s (+%dcr)." % [label, payout])
	else:
		_log("%s." % label)
	_forge_strike += 1
	_factory_show()


func _forge_finish() -> void:
	_forge_active = false
	GameManager.add_credits(_forge_haul)
	var parts: Array[String] = ["+%dcr" % _forge_haul]
	if _forge_hull_loss > 0:
		parts.append("-%d hull" % _forge_hull_loss)
	EventLog.add_entry("Forge Strike complete: " + ", ".join(parts) + ".")
	_finish("Contract delivered. %dcr of finished steel logged." % _forge_haul)
