extends Node

const MAX_PLAYERS: int = 16
const SFX_VOLUME: float = 1.0
const PITCH_VARIANCE: float = 0.08
const OVERLAP_COOLDOWN_MSEC: int = 200
const SOUNDS: Dictionary = {}

var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0

var _last_played_times: Dictionary = {}

# 运行时程序化合成的占位音（Demo 阶段，无需素材文件）。
# 取流时优先查这里，没有再回退到 SOUNDS 里的素材路径。
# 第 2 步用：以后接真音频素材时把对应 key 填进 SOUNDS 即可，调用方不用改。
var _streams: Dictionary = {}


func _ready() -> void:
	for i in MAX_PLAYERS:
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = linear_to_db(SFX_VOLUME)
		add_child(p)
		_pool.append(p)
	_build_placeholder_streams()
	print("SoundManager ready, pool: ", _pool.size())


# ---------- 程序化占位音（临时，换真素材时整段删掉） ----------
func _build_placeholder_streams() -> void:
	# 被篡改：低音量隐约嗡鸣（循环）
	_streams["gen_tampered"] = _make_tone(200.0, "sine", 0.5, true, 0.18)
	# 故障：较响低频锯齿 + 轻微调幅，像发电机喘振（循环）
	_streams["gen_fault"] = _make_tone(80.0, "saw", 0.5, true, 0.5, 6.0)
	# 警报：880Hz 方波间断哔声（一次性，故障爆发时全局提示）
	_streams["alarm"] = _make_tone(880.0, "square", 1.2, false, 0.4, 0.0, 4.0)


## 合成一段 16-bit 单声道 PCM 音。loop=true 时按整数周期取样以保证无缝循环。
## tremolo_hz>0 加缓慢音量起伏；gate_hz>0 按方波硬开关（做间断哔声）。
func _make_tone(
	freq: float,
	wave: String,
	secs: float,
	loop: bool,
	volume: float,
	tremolo_hz: float = 0.0,
	gate_hz: float = 0.0
) -> AudioStreamWAV:
	var rate := 22050
	var n := int(secs * rate)
	if loop and freq > 0.0:
		var cycles := maxi(1, int(round(secs * freq)))
		n = int(round(cycles * rate / freq))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var phase := fposmod(t * freq, 1.0)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if phase < 0.5 else -1.0
			"saw":
				s = 2.0 * phase - 1.0
			_:
				s = sin(TAU * phase)
		if tremolo_hz > 0.0:
			s *= 0.6 + 0.4 * sin(TAU * tremolo_hz * t)
		if gate_hz > 0.0 and fposmod(t * gate_hz, 1.0) >= 0.5:
			s = 0.0
		var v := int(clampf(s * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


## 取一段音频流：优先程序化占位音，其次 SOUNDS 素材路径。供设备的位置音频取循环流用。
func get_stream(sound_key: String) -> AudioStream:
	if _streams.has(sound_key):
		return _streams[sound_key]
	if SOUNDS.has(sound_key):
		var path: String = _pick_path(SOUNDS[sound_key])
		if not path.is_empty():
			return _load_stream(path)
	return null


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
	if prevent_overlap and _is_on_cooldown(sound_key):
		return
	var stream = get_stream(sound_key)
	if stream == null:
		push_warning("SoundManager: 声音不存在 «%s»" % sound_key)
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
