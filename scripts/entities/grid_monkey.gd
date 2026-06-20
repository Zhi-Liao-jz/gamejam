class_name GridMonkey
extends Node2D
## 九宫格猴子（P2 / 第2天）：从边缘房间走入 → 在目标房间蓄力 → 关掉控制面板 → 逃跑。
## 移动是房间到房间（沿 RoomManager 房间图），玩家在小地图看见它逼近，切到它房间点掉它驱赶。
## 复用旧猴子的 FSM 骨架与"防扎堆选目标"；把"向量贴近设备"换成"房间图寻路 + 同房间判定"。

const SIZE := Vector2(34.0, 34.0)  # 色块 / 命中盒尺寸（略大于产品便于点击）
const ARRIVE_EPS := 6.0  # 抵达某房间中心的判定距离

@export var base_speed: float = 200.0  # 潜入移动速度 px/s（按天缩放）
@export var base_tamper_delay: float = 2.0  # 到面板后蓄力多久才关掉（= 玩家救火窗口）
@export var base_cooldown: float = 4.0  # 逃跑到边缘后再次出动的冷却秒数

var speed: float = 0.0
var flee_speed: float = 0.0
var tamper_delay: float = 0.0
var cooldown: float = 0.0

var current_room: int = 0  # 当前所在房间 id（spawner 设初值；advance_toward 跨格时更新）
var target_room: int = -1  # 目标房间 id（开着面板的交货点 / 出口）
var exit_room: int = 0  # 逃跑去的边缘房间（spawner 设为出生角）

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


## 选一个"开着面板"的房间当目标；防扎堆排除其他活猴的目标；无可关面板返回 -1。
func pick_target() -> int:
	if room_manager == null:
		return -1
	var candidates: Array[int] = []
	for room: Room in room_manager.panel_rooms():
		if room.role == &"heater" and Game.day < 5:
			continue  # 加热台第5天起才成为猴子目标
		if room.panel_open():
			candidates.append(room.room_id)
	# 第3天起把中央自爆开关纳入目标（最高威胁）；仅当它还能被破坏时
	var sd := room_manager.self_destruct
	if sd != null and Game.day >= 3 and sd.is_attackable():
		candidates.append(sd.room_id)
	# 第6天起把发电机纳入目标（切断供电瘫痪出口/加热台）；仅当供电正常时
	var pw := room_manager.power
	if pw != null and Game.day >= 6 and pw.is_attackable():
		candidates.append(pw.room_id)
	if candidates.is_empty():
		return -1
	var taken := {}
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


func _draw() -> void:
	draw_rect(Rect2(-SIZE * 0.5, SIZE), Color(0.55, 0.36, 0.18))  # 棕色色块
	draw_rect(Rect2(-SIZE * 0.5, SIZE), Color(0.20, 0.12, 0.05), false, 2.0)
