class_name Room
extends Node2D
## 九宫格中的单个房间（可复用单元）。
## 承载本房间的内容——产品 / 设备 / 面板后续都挂进 Contents。
## P0 阶段只有数据 + 占位色块视觉，用来验证"切监控房间"。

const CELL_SIZE := Vector2(480.0, 300.0)  # 单个房间的世界尺寸（监控视角下铺满画面）

var room_id: int = 0
var grid_pos := Vector2i.ZERO  # (列, 行)，取值 0..2
var role: StringName = &"empty"  # 房间用途：empty/delivery/product_exit/self_destruct/heater/power
var display_name: String = ""
var accent := Color(0.5, 0.5, 0.5)  # 房间主题色（占位，后续随天数随机交货点颜色时从这里改）

@onready var contents: Node2D = $Contents
@onready var name_label: Label = $NameLabel


func _ready() -> void:
	_apply_visual()


## 由 RoomManager 在实例化后写入本房间的静态配置。
func setup(id: int, grid: Vector2i, room_role: StringName, label: String, color: Color) -> void:
	room_id = id
	grid_pos = grid
	role = room_role
	display_name = label
	accent = color
	name = "Room%d" % id
	if is_node_ready():
		_apply_visual()


func _apply_visual() -> void:
	if name_label:
		name_label.text = display_name
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-CELL_SIZE * 0.5, CELL_SIZE)
	draw_rect(rect, accent.darkened(0.55))  # 房间地面
	draw_rect(rect, accent, false, 4.0)  # 边框用主题色
