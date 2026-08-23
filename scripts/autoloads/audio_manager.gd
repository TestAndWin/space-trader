extends Node

## Central audio playback. Music runs on a single looping player, sound
## effects go through a small round-robin pool so overlapping cues (laser
## followed by an impact) do not cut each other off.

const SFX_DIR: String = "res://assets/audio/sfx/"
const SFX_POOL_SIZE: int = 6

var bgm_player: AudioStreamPlayer
var ui_sfx_player: AudioStreamPlayer

var current_bgm_path: String = ""

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _stream_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	add_child(bgm_player)

	ui_sfx_player = AudioStreamPlayer.new()
	ui_sfx_player.bus = "UI"
	add_child(ui_sfx_player)

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

	# Every button in the game clicks, without each screen having to remember to
	# wire it up. Buttons are built programmatically all over this project and
	# not all of them go through UIStyles, so hooking them at creation time is
	# the only way to catch them all.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not (node as BaseButton).pressed.is_connected(play_ui_click):
		(node as BaseButton).pressed.connect(play_ui_click)

# --- Music ---

func play_bgm(path: String) -> void:
	if current_bgm_path == path and bgm_player.playing:
		return
	current_bgm_path = path
	var stream: AudioStream = _get_stream(path)
	if stream == null:
		return
	bgm_player.stream = stream
	bgm_player.play()

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
	ui_sfx_player.stream = stream
	ui_sfx_player.pitch_scale = 1.0
	ui_sfx_player.play()

# --- Cards ---

func play_card_play() -> void:
	play_sfx("card_play", 0.06)

func play_card_draw() -> void:
	play_sfx("card_draw", 0.08)

# --- Combat ---

func play_laser() -> void:
	play_sfx("laser", 0.08)

func play_enemy_laser() -> void:
	play_sfx("enemy_laser", 0.08, 0.6) # Deeper and more menacing tone

func play_shield_hit() -> void:
	play_sfx("shield_hit", 0.06)
	
func play_shield_up() -> void:
	var stream: AudioStream = _get_stream(SFX_DIR + "shield_hit.wav")
	if stream == null: return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.pitch_scale = 0.6  # lower pitch for powering up
	player.play()

func play_hull_hit() -> void:
	play_sfx("hull_hit", 0.06)

func play_explosion() -> void:
	play_sfx("explosion", 0.04)

# --- Trading ---

func play_purchase() -> void:
	play_sfx("purchase")

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

func play_travel_sfx() -> void:
	play_sfx("travel")

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
