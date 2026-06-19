extends Node2D
## 按天数生成九宫格猴子（第 2 天起）。工作开始(work_started)清场重建、结算(day_summary)清空，
## 猴子生命周期集中在此——只在工作阶段存在，结算期无猴。依赖"场景里排在 DayManager 之前"以接住开局事件。

const SPAWN_ROOMS := [0, 2, 8, 6]  # 出生 / 逃跑边缘房间（四角），按序号错开
const PITCH_BY_INDEX := [1.0, 0.92, 1.08]  # 多猴音高错开防糊

@export var monkey_scene: PackedScene

@onready var room_manager := get_node("../RoomManager") as RoomManager


func _ready() -> void:
	EventBus.subscribe("work_started", _on_work_started)
	EventBus.subscribe("day_summary", _on_day_summary)


func _on_work_started() -> void:
	_clear_all()
	_spawn_for_day.call_deferred()  # 延后一帧，确保房间 / 面板已建好


func _on_day_summary(_data: Dictionary) -> void:
	_clear_all()


func _spawn_for_day() -> void:
	var count := _monkey_count(Game.day)
	for i: int in count:
		_spawn_one(i)


## 第几天该有几只猴子：第 1 天 0（P1 保持无猴），之后随天数递增、封顶 3。
func _monkey_count(day: int) -> int:
	if day < 2:
		return 0
	return clampi(day - 1, 1, 3)


func _spawn_one(index: int) -> void:
	if monkey_scene == null:
		return
	var spawn_room: int = SPAWN_ROOMS[index % SPAWN_ROOMS.size()]
	var m: GridMonkey = monkey_scene.instantiate()
	# 入树前写好初值：FSM 的首个 enter 在 add_child 时即触发，那时这些必须就位
	m.room_manager = room_manager
	m.current_room = spawn_room
	m.exit_room = spawn_room
	m.audio_pitch_base = PITCH_BY_INDEX[index % PITCH_BY_INDEX.size()]
	m.apply_day_scaling()
	m.position = room_manager.room_world_center(spawn_room)
	add_child(m)


func _clear_all() -> void:
	for node: Node in get_tree().get_nodes_in_group("grid_monkeys"):
		node.queue_free()
