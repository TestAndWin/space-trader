extends Node

## RivalManager — handles the recurring Captain Vex rival questline.
## 4 phases triggered at flight thresholds (3, 6, 9, 12 flights).

const RIVAL_PATH := "res://data/rivals/captain_vex.tres"
const PHASE_THRESHOLDS := [3, 6, 9, 12]
const PHASE_COOLDOWNS  := [3, 2, 2, 0]  # Flights before rival can reappear after defeat
const LOSS_COOLDOWN    := 1              # Flights before rival returns after beating player
const FINAL_PHASE      := 3             # Index of the last phase (PHASE_THRESHOLDS.size() - 1)

var _rival_data: Resource = null
var _current_phase: int = 0             # 0-indexed
var _phase_defeated: Array = [false, false, false, false]
var _cooldown_remaining: int = 0
var _rivalry_active: bool = true        # false once phase 4 is fully defeated


func _ready() -> void:
	_rival_data = load(RIVAL_PATH)


func reset() -> void:
	_current_phase = 0
	_phase_defeated = [false, false, false, false]
	_cooldown_remaining = 0
	_rivalry_active = true


## Call this once per flight BEFORE should_rival_appear().
## Keeps the cooldown decrement out of the query function (no side effects).
func on_flight_completed() -> void:
	if _cooldown_remaining > 0:
		_cooldown_remaining -= 1


## Pure query — no side effects. Call on_flight_completed() first.
func should_rival_appear(total_flights: int) -> bool:
	if not _rivalry_active or _rival_data == null or _cooldown_remaining > 0:
		return false
	for i in PHASE_THRESHOLDS.size():
		if total_flights >= PHASE_THRESHOLDS[i] and not _phase_defeated[i]:
			_current_phase = i
			return true
	return false


func get_rival_encounter() -> EncounterData:
	if _rival_data == null:
		return null
	var phase: int = _current_phase
	var hp: int = _rival_data.base_health + phase * _rival_data.health_per_phase
	var atk_min: int = _rival_data.base_attack_range.x + phase * _rival_data.attack_bonus_per_phase
	var atk_max: int = _rival_data.base_attack_range.y + phase * _rival_data.attack_bonus_per_phase
	var ability_idx: int = _rival_data.special_abilities_by_phase[phase] if phase < _rival_data.special_abilities_by_phase.size() else 0
	var reward: int = _rival_data.reward_credits_base + phase * _rival_data.reward_credits_per_phase

	var enc := EncounterData.new()
	enc.encounter_name    = _rival_data.rival_name
	enc.enemy_health      = hp
	enc.enemy_attack_range = Vector2i(atk_min, atk_max)
	enc.special_ability   = ability_idx as EncounterData.SpecialAbility
	enc.ability_description = _rival_data.phase_descriptions[phase] if phase < _rival_data.phase_descriptions.size() else ""
	enc.reward_credits    = reward
	enc.can_flee          = phase < FINAL_PHASE
	enc.difficulty        = 2 + phase
	# Typed rival fields — no set_meta() needed
	enc.is_rival          = true
	enc.taunt_line        = _rival_data.taunt_lines[phase] if phase < _rival_data.taunt_lines.size() else ""
	enc.rival_phase       = phase
	return enc


func on_rival_defeated() -> void:
	_phase_defeated[_current_phase] = true
	_cooldown_remaining = PHASE_COOLDOWNS[_current_phase] if _current_phase < PHASE_COOLDOWNS.size() else 0
	EventLog.add_entry("Defeated %s (Phase %d)!" % [_rival_data.rival_name, _current_phase + 1])
	if _current_phase >= FINAL_PHASE:
		_rivalry_active = false
		EventLog.add_entry("The rivalry is over. %s will trouble you no more." % _rival_data.rival_name)


func on_rival_won() -> void:
	_cooldown_remaining = LOSS_COOLDOWN
	EventLog.add_entry("%s bested you this time. They'll be back soon." % _rival_data.rival_name)


func save_data() -> Dictionary:
	return {
		"current_phase":     _current_phase,
		"phase_defeated":    _phase_defeated.duplicate(),
		"cooldown_remaining": _cooldown_remaining,
		"rivalry_active":    _rivalry_active,
	}


func load_data(data: Dictionary) -> void:
	_current_phase      = int(data.get("current_phase", 0))
	_cooldown_remaining = int(data.get("cooldown_remaining", 0))
	_rivalry_active     = bool(data.get("rivalry_active", true))
	var saved: Array    = data.get("phase_defeated", [])
	_phase_defeated     = [false, false, false, false]
	for i in mini(saved.size(), _phase_defeated.size()):
		_phase_defeated[i] = bool(saved[i])
