class_name Room
extends Node2D
## 九宫格中的单个房间（可复用单元）。
## 承载本房间的内容——产品 / 设备 / 面板后续都挂进 Contents。
## P0 阶段只有数据 + 占位色块视觉，用来验证"切监控房间"。

const CELL_SIZE := Vector2(480.0, 300.0)  # 单个房间的世界尺寸（监控视角下铺满画面）
const TILE_SIZE := 16
const FLOOR_COORD := Vector2i(0, 0)  # wall_tiles.png：地板
const WALL_H_COORD := Vector2i(1, 0)  # 横墙（上边；转置后做左右竖墙）
const BRICK_COORD := Vector2i(2, 0)  # 砖纹（下边）
const TILE_SOURCE := 0

var room_id: int = 0
var grid_pos := Vector2i.ZERO  # (列, 行)，取值 0..2
var role: StringName = &"empty"  # 房间用途：empty/delivery/product_exit/self_destruct/heater/power
var display_name: String = ""
var accent := Color(0.5, 0.5, 0.5)  # 房间主题色（占位，后续随天数随机交货点颜色时从这里改）
var color_key: StringName = &""  # 交货点房间的颜色键（red/blue/green）；非交货点为空
var control_panel: ControlPanel = null  # 交货点 / 出口房间的控制面板；其它房间为空

@onready var contents: Node2D = $Contents
@onready var name_label: Label = $NameLabel
@onready var _tiles: TileMapLayer = $TileMap


func _ready() -> void:
	_build_floor()
	_apply_visual()


## 用 TileMapLayer 铺满房间地板，并在四周铺一圈墙壁瓦片。
func _build_floor() -> void:
	if _tiles == null or _tiles.tile_set == null:
		return
	var cols := int(ceil(CELL_SIZE.x / TILE_SIZE))
	var rows := int(ceil(CELL_SIZE.y / TILE_SIZE))
	_tiles.position = -Vector2(cols * TILE_SIZE, rows * TILE_SIZE) * 0.5
	var transpose := TileSetAtlasSource.TRANSFORM_TRANSPOSE  # 横墙转置→竖墙（左右）
	for y: int in rows:
		for x: int in cols:
			var pos := Vector2i(x, y)
			if y == 0:  # 上边
				_tiles.set_cell(pos, TILE_SOURCE, WALL_H_COORD)
			elif y == rows - 1:  # 下边
				_tiles.set_cell(pos, TILE_SOURCE, BRICK_COORD)
			elif x == 0 or x == cols - 1:  # 左右边：横墙转置成竖墙
				_tiles.set_cell(pos, TILE_SOURCE, WALL_H_COORD, transpose)
			else:  # 内部地板
				_tiles.set_cell(pos, TILE_SOURCE, FLOOR_COORD)


## 由 RoomManager 在实例化后写入本房间的静态配置。
func setup(
	id: int,
	grid: Vector2i,
	room_role: StringName,
	label: String,
	color: Color,
	key: StringName = &""
) -> void:
	room_id = id
	grid_pos = grid
	role = room_role
	display_name = label
	accent = color
	color_key = key
	name = "Room%d" % id
	if is_node_ready():
		_apply_visual()


## 是否为交货点房间。
func is_delivery() -> bool:
	return role == &"delivery"


## 本房间内的所有产品。
func products() -> Array[Product]:
	var result: Array[Product] = []
	for child: Node in contents.get_children():
		var product := child as Product
		if product:
			result.append(product)
	return result


## 世界坐标点命中的产品（后加入的在上，优先返回）；无则 null。
func product_at(world_pos: Vector2) -> Product:
	var found := products()
	for i: int in range(found.size() - 1, -1, -1):
		if found[i].global_rect().has_point(world_pos):
			return found[i]
	return null


## 把产品放进本房间（reparent 到 Contents，设房间局部坐标）。
func add_product(product: Product, local_pos: Vector2) -> void:
	if product.get_parent():
		product.reparent(contents)
	else:
		contents.add_child(product)
	product.position = local_pos
	product.current_room = room_id
	product.z_index = 1


## 给房间挂一个控制面板（交货点 / 出口用），记录引用供门控与点击重开。
func attach_panel(panel: ControlPanel, local_pos: Vector2) -> void:
	add_child(panel)
	panel.position = local_pos
	control_panel = panel


## 是否有控制面板。
func has_panel() -> bool:
	return control_panel != null and is_instance_valid(control_panel)


## 面板是否允许工作（无面板视为常开）。出口出货 / 交货结算据此门控。
func panel_open() -> bool:
	return not has_panel() or control_panel.is_open


## 世界坐标点命中的"可重开面板"（仅当面板关闭时返回，避免开着的面板挡住产品点击）；否则 null。
func panel_at(world_pos: Vector2) -> ControlPanel:
	if (
		has_panel()
		and not control_panel.is_open
		and control_panel.global_rect().has_point(world_pos)
	):
		return control_panel
	return null


func _apply_visual() -> void:
	if name_label:
		name_label.text = display_name
	queue_redraw()


func _draw() -> void:
	if _has_visual_texture():
		return
	var rect := Rect2(-CELL_SIZE * 0.5, CELL_SIZE)
	draw_rect(rect, accent.darkened(0.55))  # 房间地面
	draw_rect(rect, accent, false, 4.0)  # 边框用主题色


func _has_visual_texture() -> bool:
	return _tiles != null and _tiles.tile_set != null
