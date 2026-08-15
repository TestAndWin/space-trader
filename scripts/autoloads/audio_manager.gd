extends Node

var bgm_player: AudioStreamPlayer
var ui_sfx_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var current_bgm_path: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	add_child(bgm_player)
	
	ui_sfx_player = AudioStreamPlayer.new()
	ui_sfx_player.bus = "UI"
	add_child(ui_sfx_player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	add_child(sfx_player)

func play_bgm(path: String) -> void:
	if current_bgm_path == path and bgm_player.playing:
		return
	current_bgm_path = path
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream:
		bgm_player.stream = stream
		bgm_player.play()

func stop_bgm() -> void:
	bgm_player.stop()
	current_bgm_path = ""

func play_ui_click() -> void:
	_play_sfx(ui_sfx_player, "res://assets/audio/sfx/ui_click.ogg")

func play_travel_sfx() -> void:
	_play_sfx(sfx_player, "res://assets/audio/sfx/travel.ogg")

func _play_sfx(player: AudioStreamPlayer, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream:
		player.stream = stream
		player.play()
