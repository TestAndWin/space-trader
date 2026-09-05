extends EventChoiceModal

## Planet arrival event popup — random events triggered when landing on a planet.
## Call try_trigger(planet_type) from planet_screen. If it returns true the popup
## is visible; otherwise nothing happens.

const TRIGGER_CHANCE := 0.25
## The one event with a bespoke flow: cargo is taken up front and choice A may
## win it back, so its texts carry a {good} placeholder.
const CARGO_THEFT := "Cargo Theft!"

# Cargo theft tracking
var _stolen_good: String = ""
var _stolen_qty: int = 0


# ── Public API ───────────────────────────────────────────────────────────────

func try_trigger(planet_type: int) -> bool:
	_load_events(ResourceRegistry.PLANET_EVENTS)
	if randf() > TRIGGER_CHANCE:
		return false
	var matching: Array = []
	for ev in _all_events:
		if ev.any_planet_type or ev.planet_type == planet_type:
			# Cargo theft requires player to have cargo
			if ev.event_name == CARGO_THEFT and GameManager.cargo.is_empty():
				continue
			matching.append(ev)
	if matching.is_empty():
		return false
	_current_event = matching.pick_random()
	# Cargo theft: steal cargo before showing event
	if _current_event.event_name == CARGO_THEFT:
		_apply_cargo_theft()
	_show_event()
	visible = true
	return true


# ── Modal configuration ──────────────────────────────────────────────────────

func _modal_title_color() -> Color:
	return Color(0.4, 0.7, 1.0)


func _log_prefix() -> String:
	return "Planet event"


func _format_description(text: String) -> String:
	if _stolen_good == "":
		return text
	return text.replace("{good}", _stolen_text())


func _can_choose_a() -> bool:
	if not super():
		return false
	var ev := _current_event
	# Check required cargo
	if ev.choice_a_requires_good != "" and ev.choice_a_requires_qty > 0:
		return GameManager.get_cargo_quantity(ev.choice_a_requires_good) >= ev.choice_a_requires_qty
	return true


func _requirement_text() -> String:
	var ev := _current_event
	var parts: Array = []
	var base: String = super()
	if base != "":
		parts.append(base)
	if ev.choice_a_requires_good != "" and ev.choice_a_requires_qty > 0:
		var owned := GameManager.get_cargo_quantity(ev.choice_a_requires_good)
		if owned < ev.choice_a_requires_qty:
			parts.append("Need %d %s" % [ev.choice_a_requires_qty, ev.choice_a_requires_good])
	return ". ".join(parts)


# ── Cargo theft ─────────────────────────────────────────────────────────────

func _apply_cargo_theft() -> void:
	if GameManager.cargo.is_empty():
		return
	var item: Dictionary = GameManager.cargo.pick_random()
	_stolen_good = item["good_name"]
	_stolen_qty = clampi(randi_range(1, 3), 1, item["quantity"])
	GameManager.remove_cargo(_stolen_good, _stolen_qty)
	EventLog.add_entry("Thieves stole %d %s from your cargo!" % [_stolen_qty, _stolen_good])


func _stolen_text() -> String:
	return "%d %s" % [_stolen_qty, _stolen_good]


# ── Choice handlers ──────────────────────────────────────────────────────────

func _on_choice_a() -> void:
	var ev := _current_event
	# Cargo theft: success = recover stolen goods
	if ev.event_name == CARGO_THEFT and _stolen_good != "":
		if _roll_succeeds(ev.choice_a_success_chance):
			_apply_outcome(ev.choice_a_credits, ev.choice_a_hull, _stolen_good, _stolen_qty)
			_show_outcome(ev.choice_a_description.replace("{good}", _stolen_text()))
		else:
			_apply_outcome(ev.choice_a_alt_credits, ev.choice_a_alt_hull)
			_show_outcome(ev.choice_a_alt_description.replace("{good}", _stolen_text()))
		return
	if _roll_succeeds(ev.choice_a_success_chance):
		_resolve_and_show(ev.choice_a_credits, ev.choice_a_hull, ev.choice_a_cargo_good, ev.choice_a_cargo_qty, ev.choice_a_description)
	else:
		_resolve_and_show(ev.choice_a_alt_credits, ev.choice_a_alt_hull, ev.choice_a_alt_cargo_good, ev.choice_a_alt_cargo_qty, ev.choice_a_alt_description)


func _on_choice_b() -> void:
	var ev := _current_event
	if _roll_succeeds(ev.choice_b_success_chance):
		_resolve_and_show(ev.choice_b_credits, ev.choice_b_hull, ev.choice_b_cargo_good, ev.choice_b_cargo_qty, ev.choice_b_description)
	else:
		_resolve_and_show(ev.choice_b_alt_credits, ev.choice_b_alt_hull, ev.choice_b_alt_cargo_good, ev.choice_b_alt_cargo_qty, ev.choice_b_alt_description)
