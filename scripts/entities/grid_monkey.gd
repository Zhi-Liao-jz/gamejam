class_name GridMonkey
extends Node2D
## 九宫格猴子：随机游荡到房间，在当前房间随机选择可交互设备和动作。
## 设备动作通过 BaseDevice 的 begin / finish 流程执行，因此玩家、捕网、电击陷阱都能打断。

const SIZE := Vector2(34.0, 34.0)  # 色块 / 命中盒尺寸（略大于产品便于点击）
const ARRIVE_EPS := 6.0  # 抵达某房间中心的判定距离
const WANDER_PAUSE_MIN := 0.6
const WANDER_PAUSE_MAX := 1.8

@export var base_speed: float = 200.0  # 潜入移动速度 px/s（按天缩放）
@export var base_tamper_delay: float = 2.0  # 设备动作基准耗时（= 玩家救火窗口）
@export var base_cooldown: float = 4.0  # 逃跑到边缘后再次出动的冷却秒数

var speed: float = 0.0
var flee_speed: float = 0.0
var tamper_delay: float = 0.0
var cooldown: float = 0.0

var current_room: int = 0  # 当前所在房间 id（spawner 设初值；advance_toward 跨格时更新）
var target_room: int = -1  # 随机游荡目标房间 id
var exit_room: int = 0  # 逃跑去的边缘房间（spawner 设为出生角）
var action_device: BaseDevice = null  # 当前准备 / 正在操作的设备
var action_id: StringName = &""  # 当前准备 / 正在操作的动作
var is_captured: bool = false

var room_manager: RoomManager = null
var audio_pitch_base: float = 1.0  # 多猴音高错开防糊，由 spawner 设置

var _audio: AudioStreamPlayer2D = null

@onready var _state_machine: BaseStateMachine = $StateMachine


func _ready() -> void:
	add_to_group("grid_monkeys")
	z_index = 50  # 画在房间地面 / 产品 / 面板之上


## 按 Game.day 缩放难度（猴子首个出现日为第 2 天，故以 d-2 为基准）。
func apply_day_scaling() -> void:
	var d := maxi(2, Game.day)
	speed = base_speed * (1.0 + 0.06 * (d - 2))
	flee_speed = speed * 1.5  # 逃跑始终快于潜入
	tamper_delay = maxf(0.8, base_tamper_delay - 0.2 * (d - 2))
	cooldown = maxf(2.0, base_cooldown - 0.5 * (d - 2))


## 随机选一个游荡目标房间；防扎堆排除其他活猴的当前目标。
func pick_target() -> int:
	return pick_wander_room()


func pick_wander_room() -> int:
	if room_manager == null:
		return -1
	var candidates: Array[int] = []
	for i: int in RoomManager.LAYOUT.size():
		if i != current_room:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	var taken: Dictionary[int, bool] = {}
	for node: Node in get_tree().get_nodes_in_group("grid_monkeys"):
		var other := node as GridMonkey
		if other and other != self and other.target_room != -1:
			taken[other.target_room] = true
	var free: Array[int] = []
	for rid: int in candidates:
		if not taken.has(rid):
			free.append(rid)
	var pool := free if not free.is_empty() else candidates
	return pool[randi() % pool.size()]


## 当前动作设备；保留旧接口名，便于状态脚本和调试调用。
func target_device() -> BaseDevice:
	return action_device


## 从当前房间随机选择一个已开放、猴子可用的设备动作。
func pick_current_room_action() -> bool:
	clear_current_action()
	var devices := _monkey_devices_in_room(current_room)
	if devices.is_empty():
		return false
	for _i: int in range(devices.size()):
		var device := devices.pick_random() as BaseDevice
		var actions := device.available_actions(BaseDevice.ACTOR_MONKEY)
		if actions.is_empty():
			continue
		action_device = device
		action_id = StringName(actions.pick_random())
		target_room = current_room
		return true
	return false


func has_current_action() -> bool:
	return action_device != null and is_instance_valid(action_device) and action_id != &""


func current_action_duration() -> float:
	if not has_current_action():
		return tamper_delay
	var duration := action_device.action_duration(action_id, BaseDevice.ACTOR_MONKEY)
	if duration <= 0.0:
		duration = base_tamper_delay
	var scale := tamper_delay / base_tamper_delay
	return maxf(0.5, duration * scale)


func clear_current_action() -> void:
	action_device = null
	action_id = &""


## 朝目标房间走一步（房间图寻路）；跨入新房间时更新 current_room；返回是否已抵达目标房间。
func advance_toward(dest_room: int, move_speed: float, delta: float) -> bool:
	if current_room == dest_room:
		return true
	var next := room_manager.next_step_toward(current_room, dest_room)
	if next == -1:
		return true  # 不可达（九宫格全连通，理论上不会发生）：视为抵达，防卡死
	var center := room_manager.room_world_center(next)
	var to_center := center - global_position
	if to_center.length() <= ARRIVE_EPS:
		global_position = center
		current_room = next
		return current_room == dest_room
	global_position += to_center.normalized() * move_speed * delta
	return false


## 被玩家点击驱赶：任何状态都转为逃跑（已在逃跑则忽略）。
func shoo() -> void:
	var cur := _state_machine.current_state
	if cur != null and cur.name == &"GridFleeing":
		return
	if cur != null and cur.name == &"GridCaptured":
		return
	interrupt_current_action()
	_state_machine.transition_to(&"GridFleeing")


func capture(duration: float) -> void:
	interrupt_current_action()
	_state_machine.transition_to(&"GridCaptured", {"duration": duration})


func interrupt_current_action() -> void:
	if has_current_action():
		action_device.interrupt_action(action_id, self)
	clear_current_action()


func interrupt_by_shock_trap(_device: BaseDevice) -> void:
	clear_current_action()
	_state_machine.transition_to(&"GridFleeing")


## 世界坐标命中盒（供 Hand 点击驱赶）。
func global_rect() -> Rect2:
	return Rect2(global_position - SIZE * 0.5, SIZE)


## 切换循环音：换 stream 才重设、未播才 play（照搬旧猴子的稳妥写法）。
func play_loop(key: String, pitch: float = 1.0) -> void:
	if _audio == null:
		_audio = $Audio
	var stream := SoundManager.get_stream(key)
	if stream and _audio.stream != stream:
		_audio.stream = stream
	_audio.pitch_scale = pitch * audio_pitch_base
	if stream and not _audio.playing:
		_audio.play()


func stop_audio() -> void:
	if _audio:
		_audio.stop()


func _monkey_devices_in_room(room_id: int) -> Array[BaseDevice]:
	var result: Array[BaseDevice] = []
	for device: BaseDevice in room_manager.interactable_devices_in_room(
		room_id, BaseDevice.ACTOR_MONKEY
	):
		if _device_unlocked(device):
			result.append(device)
	return result


func _device_unlocked(device: BaseDevice) -> bool:
	match device.device_type:
		&"self_destruct":
			return Game.day >= 3
		&"heater":
			return Game.day >= 5
		&"power":
			return Game.day >= 6
		&"control_panel":
			var panel := device as ControlPanel
			return panel == null or panel.controls != &"heater" or Game.day >= 5
		_:
			return true


func _draw() -> void:
	var fill := Color(0.28, 0.48, 0.85) if is_captured else Color(0.55, 0.36, 0.18)
	draw_rect(Rect2(-SIZE * 0.5, SIZE), fill)  # 棕色色块；捕网控制时变蓝
	draw_rect(Rect2(-SIZE * 0.5, SIZE), Color(0.20, 0.12, 0.05), false, 2.0)
