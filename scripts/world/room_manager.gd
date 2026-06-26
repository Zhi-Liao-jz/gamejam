class_name RoomManager
extends Node2D
## 九宫格监控核心：持有 9 个房间，WASD 切换"当前监控房间"，相机吸附到当前房间。
## 这是 2.0 玩法的空间地基——玩家交互 / 猴子寻路 / 产品搬运后续都建在房间体系上。
## 监控视角 = 相机只框住当前房间，其它房间在视野外（对应"只能操作当前房间"的核心张力）。

const DEFAULT_ROOM_LAYOUT := preload("res://params/rooms/default_room_layout.tres")
const DEFAULT_CONTROL_PANEL_SCENE := preload("res://scenes/devices/control_panel.tscn")
const DEFAULT_SELF_DESTRUCT_SCENE := preload("res://scenes/devices/self_destruct.tscn")
const DEFAULT_HEATER_SCENE := preload("res://scenes/devices/heater.tscn")
const DEFAULT_GENERATOR_SCENE := preload("res://scenes/devices/generator.tscn")
const DEFAULT_WIRING_BOX_SCENE := preload("res://scenes/devices/wiring_box.tscn")

@export var room_scene: PackedScene
@export var room_layout: RoomLayoutResource
@export var control_panel_scene: PackedScene
@export var self_destruct_scene: PackedScene
@export var heater_scene: PackedScene
@export var generator_scene: PackedScene
@export var wiring_box_scene: PackedScene

var current_room: int = -1
var self_destruct: SelfDestruct = null  # 中央自爆开关（P3）；猴子破坏 / 玩家重置 / HUD 都用它
var power: Generator = null  # 发电机（右下左半）；玩家点击弹面板调参，猴子随机打乱参数
var wiring: WiringBox = null  # 接线盒（右下右半）；玩家拖拽连线，猴子随机改线

var _rooms: Array[Room] = []

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("room_manager")
	EventBus.subscribe("work_started", _on_work_started)
	if room_layout == null:
		room_layout = DEFAULT_ROOM_LAYOUT
	_assign_default_scenes()
	current_room = start_room_id()
	_build_rooms()
	_build_panels()
	_build_self_destruct()
	_build_heater()
	_build_power()
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
	else:
		return
	get_viewport().set_input_as_handled()  # 已处理的切房间按键不再向下传播


## 房间在世界里的中心坐标（供相机吸附 / 音效声像 / 猴子定位用）。
func room_world_center(room_id: int) -> Vector2:
	var definition := room_definition(room_id)
	if definition == null:
		return Vector2.ZERO
	var step := Room.CELL_SIZE + _layout().cell_gap
	var grid := definition.grid_pos
	return Vector2(grid.x * step.x, grid.y * step.y)


## 某房间朝某方向的相邻房间 id；越界返回 -1（供后续猴子在房间图上寻路）。
func neighbor_in_direction(room_id: int, dir: Vector2i) -> int:
	var definition := room_definition(room_id)
	if definition == null:
		return -1
	var grid := definition.grid_pos + dir
	var layout := _layout()
	if grid.x < 0 or grid.x >= layout.grid_cols or grid.y < 0 or grid.y >= layout.grid_rows:
		return -1
	return _room_id_at(grid)


## 按 id 取房间节点；越界返回 null。
func room_node(room_id: int) -> Room:
	if room_id < 0 or room_id >= _rooms.size():
		return null
	return _rooms[room_id]


## 当前监控房间节点。
func current_room_node() -> Room:
	return room_node(current_room)


## 当前布局的起始监控房间 id。
func start_room_id() -> int:
	return _layout().start_room


## 当前布局的房间数量。
func room_count() -> int:
	return _layout().room_count()


## 按 id 取房间静态定义；越界返回 null。
func room_definition(room_id: int) -> RoomDefinition:
	return _layout().room_at(room_id)


## 按 id 取房间显示名称；越界返回空字符串。
func room_display_name(room_id: int) -> String:
	return _layout().room_name(room_id)


## 第一个指定用途的房间（如 product_exit）；没有返回 null。
func find_room_by_role(role: StringName) -> Room:
	for room: Room in _rooms:
		if room.role == role:
			return room
	return null


## 所有交货点房间。
func delivery_rooms() -> Array[Room]:
	var result: Array[Room] = []
	for room: Room in _rooms:
		if room.role == &"delivery":
			result.append(room)
	return result


## 所有带控制面板的房间（交货点 + 产品出口），供猴子选目标。
func panel_rooms() -> Array[Room]:
	var result: Array[Room] = []
	for room: Room in _rooms:
		if room.has_panel():
			result.append(room)
	return result


## 某房间内当前登记的设备。
func devices_in_room(target_room_id: int) -> Array[BaseDevice]:
	var result: Array[BaseDevice] = []
	for node: Node in get_tree().get_nodes_in_group("devices"):
		var device := node as BaseDevice
		if device != null and device.room_id == target_room_id:
			result.append(device)
	return result


## 某房间内指定行动者可用的设备。
func interactable_devices_in_room(target_room_id: int, actor: StringName) -> Array[BaseDevice]:
	var result: Array[BaseDevice] = []
	for device: BaseDevice in devices_in_room(target_room_id):
		if not device.available_actions(actor).is_empty():
			result.append(device)
	return result


## 清空所有房间内未交付的产品。每天重新开始时调用，避免上一天产品污染新账本。
func clear_products() -> void:
	for room: Room in _rooms:
		for product: Product in room.products():
			product.queue_free()


## 房间图上从 from_id 到 to_id 的"第一步"房间 id（BFS）；不可达返回 -1。供猴子逐格寻路。
func next_step_toward(from_id: int, to_id: int) -> int:
	if from_id == to_id:
		return from_id
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var came_from := {from_id: from_id}
	var queue: Array[int] = [from_id]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for dir: Vector2i in dirs:
			var nb := neighbor_in_direction(cur, dir)
			if nb == -1 or came_from.has(nb):
				continue
			came_from[nb] = cur
			if nb == to_id:
				var step := nb
				while came_from[step] != from_id:
					step = came_from[step]
				return step
			queue.append(nb)
	return -1


func _build_rooms() -> void:
	_rooms.resize(room_count())
	for i: int in room_count():
		var definition := room_definition(i)
		if definition == null:
			continue
		var room: Room = room_scene.instantiate()
		add_child(room)
		room.setup(
			i,
			definition.grid_pos,
			definition.role,
			definition.display_name,
			definition.accent,
			definition.color_key
		)
		room.position = room_world_center(i)
		_rooms[i] = room


## 给交货点 + 产品出口房间各挂一个控制面板。
func _build_panels() -> void:
	if control_panel_scene == null:
		return
	for room: Room in _rooms:
		if room.role == &"delivery" or room.role == &"product_exit":
			var panel := control_panel_scene.instantiate() as ControlPanel
			if panel == null:
				continue
			panel.setup(room.room_id, room.role, room.color_key)
			room.attach_panel(panel, _layout().panel_local)


## 给中央房间挂自爆开关。
func _build_self_destruct() -> void:
	var room := find_room_by_role(&"self_destruct")
	if room == null or self_destruct_scene == null:
		return
	var device := self_destruct_scene.instantiate() as SelfDestruct
	if device == null:
		return
	device.setup(room.room_id)
	room.add_child(device)
	device.position = Vector2.ZERO  # 房间中心
	self_destruct = device


## 给加热台房间挂加热台。
func _build_heater() -> void:
	var room := find_room_by_role(&"heater")
	if room == null or heater_scene == null:
		return
	var heater := heater_scene.instantiate() as Heater
	if heater == null:
		return
	room.add_child(heater)
	heater.position = Vector2.ZERO


## 给右下房间挂发电机（左半）+ 接线盒（右半）。
func _build_power() -> void:
	var room := find_room_by_role(&"power")
	if room == null:
		return
	if generator_scene != null:
		var gen := generator_scene.instantiate() as Generator
		if gen != null:
			gen.setup(room.room_id)
			room.add_child(gen)
			gen.position = Vector2.ZERO
			power = gen
	if wiring_box_scene != null:
		var wire := wiring_box_scene.instantiate() as WiringBox
		if wire != null:
			wire.setup(room.room_id)
			room.add_child(wire)
			wire.position = Vector2.ZERO
			wiring = wire


func _step(dir: Vector2i) -> void:
	var definition := room_definition(current_room)
	if definition == null:
		return
	var layout := _layout()
	var grid := definition.grid_pos + dir
	grid.x = clampi(grid.x, 0, layout.grid_cols - 1)
	grid.y = clampi(grid.y, 0, layout.grid_rows - 1)
	var target := _room_id_at(grid)
	if target == -1 or target == current_room:
		return
	current_room = target
	_snap_camera()
	_broadcast_room_changed()


func _snap_camera() -> void:
	camera.position = room_world_center(current_room)


func _broadcast_room_changed() -> void:
	EventBus.push_event("room_changed", [current_room, room_display_name(current_room)])


func _room_id_at(grid: Vector2i) -> int:
	return _layout().room_id_at(grid)


func _layout() -> RoomLayoutResource:
	if room_layout == null:
		room_layout = DEFAULT_ROOM_LAYOUT
	return room_layout


func _assign_default_scenes() -> void:
	if control_panel_scene == null:
		control_panel_scene = DEFAULT_CONTROL_PANEL_SCENE
	if self_destruct_scene == null:
		self_destruct_scene = DEFAULT_SELF_DESTRUCT_SCENE
	if heater_scene == null:
		heater_scene = DEFAULT_HEATER_SCENE
	if generator_scene == null:
		generator_scene = DEFAULT_GENERATOR_SCENE
	if wiring_box_scene == null:
		wiring_box_scene = DEFAULT_WIRING_BOX_SCENE


func _on_work_started() -> void:
	clear_products()
