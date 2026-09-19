extends Node

## Central audio playback. Music runs on a single looping player, sound
## effects go through a small round-robin pool so overlapping cues (laser
## followed by an impact) do not cut each other off.

const SFX_DIR: String = "res://assets/audio/sfx/"
const SFX_POOL_SIZE: int = 6
const SILENT_CLICK_GROUP: StringName = &"silent_click"
## Master switch for background music. Set to false to judge the sound
## effects on their own.
const MUSIC_ENABLED: bool = true
## Fade at the end of the travel sound, so the cut lands on the warp exit.
const TRAVEL_FADE: float = 0.6

var bgm_player: AudioStreamPlayer
var ui_sfx_player: AudioStreamPlayer
var travel_player: AudioStreamPlayer

var current_bgm_path: String = ""

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
## Bumped by every sound except the click, so a queued click can tell whether
## its action already made a sound of its own.
var _sfx_serial: int = 0
var _click_pending_release: bool = false
var _travel_tween: Tween
var _stream_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	add_child(bgm_player)

	ui_sfx_player = AudioStreamPlayer.new()
	ui_sfx_player.bus = "UI"
	add_child(ui_sfx_player)

	# Own player rather than the pool: the travel sound runs for seconds and
	# must not be cut off by the round-robin, nor its fade leak onto a pool slot.
	travel_player = AudioStreamPlayer.new()
	travel_player.bus = "SFX"
	add_child(travel_player)

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)


## Every left click and tap in the game makes a sound. Handling it here in
## _input catches buttons, tabs, overlay backdrops, the city map and the 3D
## galaxy map alike, without each screen having to remember to wire it up.
## Touch arrives here as emulated mouse presses, so it is not handled twice.
## A control that takes clicks as gameplay input (the Starport Defense
## canvas) joins SILENT_CLICK_GROUP to opt out.
##
## The click is only a fallback: when the click's own action plays a sound
## (a purchase chime, a denied buzz), the click is dropped so the two do not
## stack. Buttons act on release, so their click waits for the release;
## everything else acts on press and clicks then. Either way the decision is
## deferred to the end of that frame, after the action has run.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var target: Control = get_viewport().gui_get_hovered_control()
			if _is_silent(target):
				return
			if _acts_on_release(target):
				_click_pending_release = true
			else:
				_queue_click()
		elif _click_pending_release:
			_click_pending_release = false
			_queue_click()
		return
	# Buttons activated from the keyboard or a gamepad get the same click.
	if get_viewport().gui_get_focus_owner() is BaseButton:
		if event.is_action_pressed("ui_accept"):
			_click_pending_release = true
		elif event.is_action_released("ui_accept") and _click_pending_release:
			_click_pending_release = false
			_queue_click()


func _acts_on_release(control: Control) -> bool:
	var button := control as BaseButton
	return button != null and button.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE


func _queue_click() -> void:
	_play_click_if_quiet.call_deferred(_sfx_serial)


## Plays the click unless another sound started since serial was taken.
func _play_click_if_quiet(serial: int) -> void:
	if serial == _sfx_serial:
		play_ui_click()


func _is_silent(control: Control) -> bool:
	var node: Node = control
	while node != null:
		if node.is_in_group(SILENT_CLICK_GROUP):
			return true
		node = node.get_parent()
	return false


# --- Music ---

func play_bgm(path: String) -> void:
	if not MUSIC_ENABLED:
		return
	if current_bgm_path == path and bgm_player.playing:
		return
	current_bgm_path = path
	var stream: AudioStream = _get_stream(path)
	if stream == null:
		return
	_ensure_looping(stream)
	bgm_player.stream = stream
	bgm_player.play()


## Godot's audio importer leaves `loop` off by default, and re-importing the
## file resets it. Background tracks are all seamless loops, so force the flag
## here instead of relying on per-file import settings.
func _ensure_looping(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

# --- UI ---

func play_ui_click() -> void:
	_play_ui("ui_click")


## For clicks the game refuses: locked buildings, actions already spent.
func play_ui_denied() -> void:
	_play_ui("ui_denied")


func _play_ui(sfx_name: String) -> void:
	var stream: AudioStream = _get_stream(SFX_DIR + sfx_name + ".wav")
	if stream == null:
		return
	if sfx_name != "ui_click":
		_sfx_serial += 1
	ui_sfx_player.stream = stream
	ui_sfx_player.pitch_scale = 1.0
	ui_sfx_player.play()

# --- Cards ---

func play_card_play() -> void:
	play_sfx("card_play", 0.06)

func play_card_draw() -> void:
	play_sfx("card_draw", 0.08)

# --- Combat ---

## The player's shot sound, per CardData.DamageType, so the weapon family
## is audible: kinetic slugs bang, ion bolts crackle, piercing keeps the laser.
const SHOT_SFX: Dictionary = {
	CardData.DamageType.KINETIC: "kinetic_shot",
	CardData.DamageType.ION: "ion_shot",
	CardData.DamageType.PIERCING: "laser",
}

func play_shot(damage_type: int) -> void:
	play_sfx(SHOT_SFX.get(damage_type, "laser"), 0.08)

func play_enemy_laser() -> void:
	play_sfx("enemy_laser", 0.08, 0.6) # Deeper and more menacing tone

func play_shield_hit() -> void:
	play_sfx("shield_hit", 0.06)
	
func play_shield_up() -> void:
	play_sfx("shield_hit", 0.0, 0.6)  # lower pitch for powering up

func play_hull_hit() -> void:
	play_sfx("hull_hit", 0.06)

func play_explosion() -> void:
	play_sfx("explosion", 0.04)

# --- Trading ---

func play_purchase() -> void:
	play_sfx("purchase")

## Buying goods at the market. Kept apart from play_purchase(), which covers
## repairs, upgrades, crew and ships.
func play_cargo_buy() -> void:
	play_sfx("cargo_buy", 0.04)

## Buying fuel at the shipyard (single unit, full tank or emergency fuel).
func play_fuel_buy() -> void:
	play_sfx("fuel_buy", 0.04)

func play_sell() -> void:
	play_sfx("sell")

# --- Casino ---

func play_casino_spin() -> void:
	play_sfx("casino_spin")

func play_casino_win() -> void:
	play_sfx("casino_win")

func play_casino_lose() -> void:
	play_sfx("casino_lose")

# --- Travel ---

## Plays the travel drone for exactly `duration` seconds - the length of the
## warp animation. travel.wav is a long sustained take with no ending of its
## own; it is faded out so it stops the moment the animation does.
func play_travel_sfx(duration: float) -> void:
	var stream: AudioStream = _get_stream(SFX_DIR + "travel.wav")
	if stream == null:
		return
	_sfx_serial += 1
	if _travel_tween:
		_travel_tween.kill()
	travel_player.stream = stream
	travel_player.volume_db = 0.0
	travel_player.play()
	_travel_tween = create_tween()
	_travel_tween.tween_interval(maxf(duration - TRAVEL_FADE, 0.0))
	_travel_tween.tween_property(travel_player, "volume_db", -60.0, TRAVEL_FADE)
	_travel_tween.tween_callback(travel_player.stop)

func play_arrive_sfx() -> void:
	play_sfx("arrive")

# --- Generic ---

## Plays an effect from SFX_DIR by file name (without extension).
## pitch_variance randomizes the pitch by +/- that fraction, which keeps
## repeated cues (laser fire, impacts) from sounding mechanical.
func play_sfx(sfx_name: String, pitch_variance: float = 0.0, base_pitch: float = 1.0) -> void:
	var stream: AudioStream = _get_stream(SFX_DIR + sfx_name + ".wav")
	if stream == null:
		return
	_sfx_serial += 1
	var player: AudioStreamPlayer = _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.pitch_scale = base_pitch if is_zero_approx(pitch_variance) else base_pitch + randf_range(-pitch_variance, pitch_variance)
	player.play()

func _get_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		_stream_cache[path] = null
		return null
	var stream: AudioStream = load(path) as AudioStream
	_stream_cache[path] = stream
	return stream
