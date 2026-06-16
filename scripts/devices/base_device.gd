class_name BaseDevice
extends Area2D
## 所有设备的统一接口。子类只重写行为，不改框架。
## 这是 Demo 阶段最值得"做对"的抽象：以后加接线盒/油箱只是新增子类。

enum DeviceState { NORMAL, TAMPERED, FAULT, SEVERE }  # 正常 / 被篡改 / 故障 / 严重故障

@export var device_name: String = "设备"
@export var repair_fee: int = 10  # 每次修复的费用
@export var loss_per_second: int = 5  # 故障时每秒造成的损失

var state: DeviceState = DeviceState.NORMAL

# 设备自带的位置音频：用 Godot 内建 2D 音频，自动按距离衰减 + 左右声像。
# 不走 SoundManager 的 _is_on_screen 过滤——亭内画面被遮、设备不在屏幕，但声音必须照常播放。
var _audio: AudioStreamPlayer2D


func _ready() -> void:
	add_to_group("devices")
	_audio = AudioStreamPlayer2D.new()
	_audio.max_distance = 900.0  # demo 调一个能听出远近差异的值
	_audio.bus = "Master"
	add_child(_audio)
	_setup()
	set_process(false)  # NORMAL 时无需逐帧；状态变化时再开（见 _set_state）


func _process(delta: float) -> void:
	_device_process(delta)
	if state == DeviceState.FAULT or state == DeviceState.SEVERE:
		Game.add_loss(loss_per_second * delta)


# ---------- 子类重写点 ----------
func _setup() -> void:
	pass


func _device_process(_delta: float) -> void:
	pass


## 子类重写：返回某状态下要循环播放的音效 key（SoundManager 里的）。空串表示该状态不发声。
func _sound_key_for(_s: DeviceState) -> String:
	return ""


func _on_tamper() -> void:
	pass


func _on_repair() -> void:
	pass


# ---------- 统一接口 ----------
## 猴子篡改
func tamper() -> void:
	if state == DeviceState.NORMAL:
		_set_state(DeviceState.TAMPERED)
		_on_tamper()


## 玩家检查 —— 返回给手册/UI 的信息
func inspect() -> Dictionary:
	return {"name": device_name, "state": state}


## 玩家修复
func repair() -> void:
	if state == DeviceState.NORMAL:
		return
	Game.add_repair_cost(repair_fee)
	_on_repair()
	_set_state(DeviceState.NORMAL)


func state_text() -> String:
	match state:
		DeviceState.NORMAL:
			return "正常"
		DeviceState.TAMPERED:
			return "被篡改"
		DeviceState.FAULT:
			return "故障"
		DeviceState.SEVERE:
			return "严重故障"
	return "?"


func _set_state(s: DeviceState) -> void:
	if s == state:
		return
	var was_faulted := state == DeviceState.FAULT or state == DeviceState.SEVERE
	state = s
	set_process(s != DeviceState.NORMAL)  # 仅异常态需要逐帧推进/累损
	queue_redraw()  # 外观只依赖 state，状态变化时重绘一次即可
	_update_sound(was_faulted)
	# 通过事件总线广播，以后声音/UI 订阅它（"会发出声音提示"）
	EventBus.push_event("device_state_changed", [self, s])


## 按当前状态切换设备循环音；刚跌入故障时额外放一声全局警报。
func _update_sound(was_faulted: bool) -> void:
	var key := _sound_key_for(state)
	if key.is_empty():
		_audio.stop()
	else:
		var stream := SoundManager.get_stream(key)
		if stream and _audio.stream != stream:
			_audio.stream = stream
		if stream and not _audio.playing:
			_audio.play()
	# 首次跌入故障：放一次性警报（非位置，保证亭内也听得到）
	var now_faulted := state == DeviceState.FAULT or state == DeviceState.SEVERE
	if now_faulted and not was_faulted:
		SoundManager.play("alarm")
