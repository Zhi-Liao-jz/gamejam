class_name ProductExit
extends Node2D
## 产品出口：工作阶段定时在"产品出口"房间吐出随机颜色的产品。
## 颜色取自当前交货点房间，保证每个产品都有对应交货点。P1 只做"定时出货 + 积压封顶"。

const SPAWN_INTERVAL := 3.0  # 出货间隔（秒）
const MAX_WAITING := 4  # 出口房间内最多积压的产品数
const SLOT_PER_ROW := 4  # 摆放槽位每行数量
const SLOT_START_X := -180.0  # 出口房间内产品摆放起始 x（房间局部坐标）
const SLOT_SPACING := 90.0  # 槽位水平间距

@export var product_scene: PackedScene

var _timer: Timer

@onready var room_manager := get_node("../RoomManager") as RoomManager


func _ready() -> void:
	EventBus.subscribe("work_started", _on_work_started)
	_timer = Timer.new()
	_timer.wait_time = SPAWN_INTERVAL
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func _on_work_started() -> void:
	_timer.start()  # 工作阶段才开始计时
	_try_spawn.call_deferred()  # 首件立即出（延后一帧确保房间已建好）


func _on_timer_timeout() -> void:
	_try_spawn()


func _try_spawn() -> void:
	if not Ledger.working_active:
		return
	var exit_room := room_manager.find_room_by_role(&"product_exit")
	if exit_room == null:
		return
	var waiting := exit_room.products().size()
	if waiting >= MAX_WAITING:
		return
	var targets := room_manager.delivery_rooms()
	if targets.is_empty():
		return
	var target: Room = targets[randi() % targets.size()]
	var product: Product = product_scene.instantiate()
	product.setup(target.color_key, target.accent, Ledger.PRODUCT_VALUE)
	exit_room.add_product(product, _slot_position(waiting))


## 出口房间内第 index 个产品的摆放槽位（底部排布）。
func _slot_position(index: int) -> Vector2:
	var col := index % SLOT_PER_ROW
	return Vector2(SLOT_START_X + col * SLOT_SPACING, 90.0)
