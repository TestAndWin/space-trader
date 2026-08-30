extends EventChoiceModal

## Travel event popup — random non-combat encounters during space travel.
## Call try_trigger(days) from travel_scene. If it returns true the popup is visible
## and ready for player interaction; otherwise nothing happens.

const TRIGGER_CHANCE := 0.20


# ── Public API ───────────────────────────────────────────────────────────────

func try_trigger(days: int = 1) -> bool:
	_load_events(ResourceRegistry.TRAVEL_EVENTS)
	var base_chance: float = 1.0 - pow(1.0 - TRIGGER_CHANCE, maxi(days, 1))
	var weather_modifier: float = EventManager.get_active_weather().get("travel_event_chance_modifier", 0.0)
	var chance: float = clampf(base_chance + weather_modifier, 0.0, 0.85)
	if randf() > chance:
		return false
	if _all_events.is_empty():
		return false
	_current_event = _all_events.pick_random()
	_show_event()
	visible = true
	return true


# ── Modal configuration ──────────────────────────────────────────────────────

func _modal_title_color() -> Color:
	return Color(0.5, 0.8, 1.0)


func _log_prefix() -> String:
	return "Travel event"


# ── Choice handlers ──────────────────────────────────────────────────────────

func _on_choice_a() -> void:
	var ev := _current_event
	if _roll_succeeds(ev.choice_a_success_chance):
		_apply_outcome(ev.choice_a_credits, ev.choice_a_hull)
		# Distress signal: helping improves reputation with destination faction
		if ev.event_name == "Distress Signal":
			var dest_faction: String = StandingManager.get_planet_faction(GameManager.travel_destination)
			StandingManager.add_faction_reputation(dest_faction, 5, "helped distress signal")
		_show_outcome(ev.choice_a_description)
	else:
		_apply_outcome(ev.choice_a_alt_credits, ev.choice_a_alt_hull)
		_show_outcome(ev.choice_a_alt_description)


func _on_choice_b() -> void:
	var ev := _current_event
	if _roll_succeeds(ev.choice_b_success_chance):
		_apply_outcome(ev.choice_b_credits, ev.choice_b_hull)
		_show_outcome(ev.choice_b_description)
	else:
		_apply_outcome(ev.choice_b_alt_credits, ev.choice_b_alt_hull)
		_show_outcome(ev.choice_b_alt_description)
