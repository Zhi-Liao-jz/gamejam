class_name RoomManager
extends Node2D
## 九宫格监控核心：持有 9 个房间，WASD 切换"当前监控房间"，相机吸附到当前房间。
## 这是 2.0 玩法的空间地基——玩家交互 / 猴子寻路 / 产品搬运后续都建在房间体系上。
## 监控视角 = 相机只框住当前房间，其它房间在视野外（对应"只能操作当前房间"的核心张力）。

const GRID_COLS := 3
const GRID_ROWS := 3
const CELL_GAP := 160.0  # 房间之间的世界间距（够大以保证非当前房间在视野外）
const START_ROOM := 4  # 默认从中央房间（自爆开关）开始监控

# 九宫格布局（数据化，不写死在逻辑里）。grid=(列,行)，行 0 在最上。
# 数组下标即 room_id，且按行优先排列 → id == grid.y * 3 + grid.x。
# 颜色仅占位，后续"每天随机交货点颜色"时改这张表即可。
const LAYOUT: Array[Dictionary] = [
	{"grid": Vector2i(0, 0), "role": &"empty", "name": "左上 · 待定", "color": Color(0.42, 0.44, 0.48)},
	{
		"grid": Vector2i(1, 0),
		"role": &"delivery",
		"name": "上交货点 · 红",
		"color": Color(0.86, 0.27, 0.24)
	},
	{"grid": Vector2i(2, 0), "role": &"empty", "name": "右上 · 待定", "color": Color(0.42, 0.44, 0.48)},
	{
		"grid": Vector2i(0, 1),
		"role": &"product_exit",
		"name": "产品出口",
		"color": Color(0.55, 0.60, 0.66)
	},
	{
		"grid": Vector2i(1, 1),
		"role": &"self_destruct",
		"name": "中央自爆开关",
		"color": Color(0.90, 0.20, 0.18)
	},
	{
		"grid": Vector2i(2, 1),
		"role": &"delivery",
		"name": "右交货点 · 蓝",
		"color": Color(0.26, 0.50, 0.92)
	},
	{"grid": Vector2i(0, 2), "role": &"heater", "name": "加热台", "color": Color(0.92, 0.70, 0.24)},
	{
		"grid": Vector2i(1, 2),
		"role": &"delivery",
		"name": "下交货点 · 绿",
		"color": Color(0.30, 0.74, 0.40)
	},
	{
		"grid": Vector2i(2, 2),
		"role": &"power",
		"name": "发电机 / 接线盒",
		"color": Color(0.18, 0.62, 0.58)
	},
]

@export var room_scene: PackedScene

var current_room: int = START_ROOM
var _rooms: Array[Room] = []

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_build_rooms()
	_snap_camera()
	camera.make_current()
	_broadcast_room_changed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_step(Vector2i(0, -1))
	elif event.is_action_pressed("move_down"):
		_step(Vector2i(0, 1))
	elif event.is_action_pressed("move_left"):
		_step(Vector2i(-1, 0))
	elif event.is_action_pressed("move_right"):
		_step(Vector2i(1, 0))


## 房间在世界里的中心坐标（供相机吸附 / 音效声像 / 猴子定位用）。
func room_world_center(room_id: int) -> Vector2:
	var grid: Vector2i = LAYOUT[room_id]["grid"]
	var step := Room.CELL_SIZE + Vector2(CELL_GAP, CELL_GAP)
	return Vector2(grid.x * step.x, grid.y * step.y)


## 某房间朝某方向的相邻房间 id；越界返回 -1（供后续猴子在房间图上寻路）。
func neighbor_in_direction(room_id: int, dir: Vector2i) -> int:
	var grid: Vector2i = LAYOUT[room_id]["grid"] + dir
	if grid.x < 0 or grid.x >= GRID_COLS or grid.y < 0 or grid.y >= GRID_ROWS:
		return -1
	return _room_id_at(grid)


func _build_rooms() -> void:
	for i: int in LAYOUT.size():
		var data: Dictionary = LAYOUT[i]
		var room: Room = room_scene.instantiate()
		add_child(room)
		room.setup(i, data["grid"], data["role"], data["name"], data["color"])
		room.position = room_world_center(i)
		_rooms.append(room)


func _step(dir: Vector2i) -> void:
	var grid: Vector2i = LAYOUT[current_room]["grid"] + dir
	grid.x = clampi(grid.x, 0, GRID_COLS - 1)
	grid.y = clampi(grid.y, 0, GRID_ROWS - 1)
	var target := _room_id_at(grid)
	if target == -1 or target == current_room:
		return
	current_room = target
	_snap_camera()
	_broadcast_room_changed()


func _snap_camera() -> void:
	camera.position = room_world_center(current_room)


func _broadcast_room_changed() -> void:
	EventBus.push_event("room_changed", [current_room, String(LAYOUT[current_room]["name"])])


func _room_id_at(grid: Vector2i) -> int:
	for i: int in LAYOUT.size():
		if LAYOUT[i]["grid"] == grid:
			return i
	return -1
