class_name Monkey
extends Node2D
## 猴子：潜入 → 捣乱 → 逃跑的循环（状态机见子节点）。Demo 用色块表示。
## 捣乱 = 调设备已有的 device.tamper()，不另造破坏逻辑。
## 声音走自带 AudioStreamPlayer2D（按距离衰减+声像），亭内黑屏也能听见——这是"靠声音判断"卖点的延伸。

const SIZE := Vector2(28, 28)
const REACH: float = 40.0  # 到达判定距离（手感参数，不随天数变）

# ---------- 难度基础值（写死/手填；_apply_day_scaling 按天数缩放）----------
@export var base_speed: float = 110.0  # 潜入移动速度 px/s
@export var base_flee_trigger: float = 90.0  # 玩家靠多近才逃（须 > player.interact_range 70）
@export var base_tamper_delay: float = 1.6  # 到设备后蓄力多久才得手（= 决策窗口长度）
@export var base_spawn_interval: float = 6.0  # 两次入侵间冷却秒数

var exit_point: Vector2 = Vector2(560, -200)  # 生成点 = 逃跑点（地图边缘外）

# 运行时数值（_apply_day_scaling 算出）
var speed: float = 0.0
var flee_speed: float = 0.0
var flee_trigger: float = 0.0
var tamper_delay: float = 0.0
var spawn_interval: float = 0.0

var target_device: BaseDevice = null

var _audio: AudioStreamPlayer2D = null
var _player: Node2D = null

@onready var _state_machine: BaseStateMachine = $StateMachine


func _ready() -> void:
	add_to_group("monkeys")
	_apply_day_scaling()
	# 结算期清场：复用已有事件，零新增系统（Settlement.enter 推 show，Working.enter 推 hide）
	EventBus.subscribe("show_settlement", _on_settlement)
	EventBus.subscribe("hide_settlement", _on_work)


## 按 Game.day 缩放难度，系数写死在一处。首日数值宽松，否则玩家一出亭猴子又来、推不动进度。
func _apply_day_scaling() -> void:
	var d := Game.day
	speed = base_speed * (1.0 + 0.08 * (d - 1))
	flee_speed = speed * 1.5  # 逃跑始终快于潜入
	tamper_delay = maxf(0.5, base_tamper_delay - 0.2 * (d - 1))
	spawn_interval = maxf(2.5, base_spawn_interval - 0.6 * (d - 1))
	# 越来越大胆，但封底须 > player.interact_range(70)，否则"走近就吓跑/扑空"机制失效
	flee_trigger = maxf(75.0, base_flee_trigger - 5.0 * (d - 1))


## 选一个 NORMAL 设备当目标；无可篡改设备返回 null。只依赖统一接口，以后多设备零改动。
func pick_target() -> BaseDevice:
	var candidates: Array[BaseDevice] = []
	for node: Node in get_tree().get_nodes_in_group("devices"):
		var dev := node as BaseDevice
		if dev and dev.state == BaseDevice.DeviceState.NORMAL:
			candidates.append(dev)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


## 取玩家引用（懒缓存，避免每帧全量遍历分组）。
func get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player


## 切换循环音：照搬 base_device._update_sound 的"换 stream 才重设、未播才 play"写法。
## _audio 是场景里的子节点（见 main.tscn），实例化时就在树里——不能在状态 enter 期 add_child，
## 因为状态机的 _ready 早于猴子本体 _ready，那时本体仍在"设置子节点"中，运行时 add_child 会失败。
func play_loop(key: String, pitch: float = 1.0) -> void:
	if _audio == null:
		_audio = $Audio
	var stream := SoundManager.get_stream(key)
	if stream and _audio.stream != stream:
		_audio.stream = stream
	_audio.pitch_scale = pitch
	if stream and not _audio.playing:
		_audio.play()


func stop_audio() -> void:
	if _audio:
		_audio.stop()


# ---------- 结算清场 ----------
func _on_settlement(_data: Dictionary) -> void:
	stop_audio()
	hide()
	_state_machine.set_process(false)
	_state_machine.set_physics_process(false)


func _on_work() -> void:
	show()
	global_position = exit_point
	_apply_day_scaling()
	_state_machine.set_process(true)
	_state_machine.set_physics_process(true)
	_state_machine.transition_to(&"Sneaking")


func _draw() -> void:
	draw_rect(Rect2(-SIZE * 0.5, SIZE), Color(0.55, 0.36, 0.18))  # 棕色色块
