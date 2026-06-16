extends Node

const MAX_PLAYERS: int = 16
const SFX_VOLUME: float = 1.0
const PITCH_VARIANCE: float = 0.08
const OVERLAP_COOLDOWN_MSEC: int = 200
const SOUNDS: Dictionary = {}

var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0

var _last_played_times: Dictionary = {}


func _ready() -> void:
	for i in MAX_PLAYERS:
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = linear_to_db(SFX_VOLUME)
		add_child(p)
		_pool.append(p)
	print("SoundManager ready, pool: ", _pool.size())


func _is_on_cooldown(sound_key: String) -> bool:
	if "dialogue" in sound_key:
		return false
	if _last_played_times.has(sound_key):
		var time_since_last_play = Time.get_ticks_msec() - _last_played_times[sound_key]
		if time_since_last_play < OVERLAP_COOLDOWN_MSEC:
			return true
	return false


func _is_on_screen(node: Node2D) -> bool:
	var viewport = node.get_viewport()
	if not viewport:
		return true
	var cam = viewport.get_camera_2d()
	if not cam:
		return true
	var visible_size = viewport.get_visible_rect().size / cam.zoom
	var screen_rect = Rect2(cam.get_screen_center_position() - visible_size * 0.5, visible_size)

	screen_rect = screen_rect.grow(16.0)
	return screen_rect.has_point(node.global_position)


func play(sound_key: String, randomize_pitch: bool = false, prevent_overlap: bool = true) -> void:
	if not SOUNDS.has(sound_key):
		push_warning("SoundManager: 声音不存在 «%s»" % sound_key)
		return
	if prevent_overlap and _is_on_cooldown(sound_key):
		return
	var path: String = _pick_path(SOUNDS[sound_key])
	if path.is_empty():
		return
	var stream = _load_stream(path)
	if stream == null:
		return
	var player: AudioStreamPlayer = _next_player()
	player.stream = stream
	player.pitch_scale = 1.0
	if randomize_pitch:
		player.pitch_scale = 1.0 + randf_range(-PITCH_VARIANCE, PITCH_VARIANCE)
	_last_played_times[sound_key] = Time.get_ticks_msec()
	player.play()


func play_at(
	sound_key: String,
	source_node: Node2D,
	randomize_pitch: bool = false,
	prevent_overlap: bool = true
) -> void:
	if not is_instance_valid(source_node):
		return
	if not _is_on_screen(source_node):
		return
	play(sound_key, randomize_pitch, prevent_overlap)


func sfx_pitched(sound_key: String, pitch: float, prevent_overlap: bool = true) -> void:
	if not SOUNDS.has(sound_key):
		return
	if prevent_overlap and _is_on_cooldown(sound_key):
		return
	var path: String = _pick_path(SOUNDS[sound_key])
	if path.is_empty():
		return
	var stream = _load_stream(path)
	if stream == null:
		return
	var player = _next_player()
	player.stream = stream
	player.pitch_scale = pitch
	_last_played_times[sound_key] = Time.get_ticks_msec()
	player.play()


func play_delayed(
	sound_key: String, delay: float, randomize_pitch: bool = false, prevent_overlap: bool = true
) -> void:
	await get_tree().create_timer(delay).timeout
	play(sound_key, randomize_pitch, prevent_overlap)


func _pick_path(value) -> String:
	if value is Array:
		if value.is_empty():
			return ""
		return value[randi() % value.size()]
	return value as String


func _next_player() -> AudioStreamPlayer:
	var p = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % MAX_PLAYERS
	return p


func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null
