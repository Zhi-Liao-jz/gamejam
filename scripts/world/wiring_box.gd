class_name WiringBox
extends BaseDevice
## 接线盒（阶段4 右下房间右半）：左右各若干连接点，正确连接每关随机、开局即正确。
## 玩家通过弹出面板（WiringPanel）拖拽连线；猴子随机改线造成错接/短路 → 随机切断受供电设备。
## 当前接线与正确接线不一致 = 故障：把某个受供电设备写入 Ledger.wiring_cut；改回正确则恢复。
## 注意：接线盒与发电机供电互相独立（is_device_powered = 发电机正常 AND 未被接线盒切断）。

const ACTION_M_RANDOMIZE: StringName = &"wiring_randomize"
const SIZE := Vector2(42.0, 54.0)  # 命中盒 / 视觉外框（房间局部坐标，占房间右半）
const OFFSET := Vector2(85.0, 8.0)
const OK_COLOR := Color(0.30, 0.85, 0.75)
const FAULT_COLOR := Color(0.95, 0.72, 0.16)

var point_count: int = 4
var correct: Dictionary = {}  # left_idx(int) -> right_idx(int)：本关正确连接（开局固定，手册截图依据）
var connections: Dictionary = {}  # left_idx(int) -> right_idx(int)：当前连接

@onready var visual: TextureVisual = $Visual


func _ready() -> void:
	add_to_group("wiring")
	EventBus.subscribe("work_started", _on_work_started)
	randomize_for_day()
	_update_visual()


## 由 RoomManager 在挂载前写入归属房间。设备类型沿用 &"power"（猴子第6天解锁该类型）。
func setup(owner_room_id: int) -> void:
	setup_device(&"wiring", &"power", owner_room_id)


## 世界坐标命中盒（玩家点击打开面板 / 安装电击陷阱用）。
func global_rect() -> Rect2:
	return Rect2(global_position + OFFSET - SIZE * 0.5, SIZE)


## 重置为本关随机的"正确连接"。开局即正确 → 无故障。
func randomize_for_day() -> void:
	point_count = WiringTuning.roll_point_count()
	correct = _make_random_wiring(point_count)
	connections = correct.duplicate()
	_update_wiring_power()
	_update_visual()
	queue_redraw()


## 当前接线是否完全正确。
func is_correct() -> bool:
	return connections == correct


## 连接左点 left 到右点 right（强制一对一：清掉占用了任一端的旧连接）。
func connect_points(left: int, right: int) -> void:
	if left < 0 or left >= point_count or right < 0 or right >= point_count:
		return
	connections.erase(left)
	for l: int in connections.keys():
		if connections[l] == right:
			connections.erase(l)
	connections[left] = right
	_after_change()


## 断开左点 left 的连接。
func disconnect_left(left: int) -> void:
	if connections.has(left):
		connections.erase(left)
		_after_change()


## 左点当前连到的右点；未连返回 -1。
func right_of(left: int) -> int:
	return connections.get(left, -1)


## 猴子一次操作 = 随机化全部连接（见 _perform_action）。玩家走面板不走此接口。
func available_actions(actor: StringName) -> Array[StringName]:
	if actor != ACTOR_MONKEY or not Ledger.working_active:
		return []
	return [ACTION_M_RANDOMIZE]


func device_state() -> StringName:
	return &"ok" if is_correct() else &"fault"


func can_install_shock_trap() -> bool:
	return Game.day >= GameConfig.wiring().shock_trap_unlock_day and super.can_install_shock_trap()


func _perform_action(action_id: StringName, _actor: StringName, _actor_node: Node) -> bool:
	if action_id != ACTION_M_RANDOMIZE:
		return false
	_randomize_connections()
	return true


## 猴子一次操作：每个左点各自等概率取一个值（不连 / 某个右点），保持一对一约束。
func _randomize_connections() -> void:
	connections = {}
	var used: Dictionary = {}
	for left: int in point_count:
		var choice := randi() % (point_count + 1)  # == point_count 表示该左点不连
		if choice >= point_count or used.has(choice):
			continue
		used[choice] = true
		connections[left] = choice
	_after_change()


## 每天开局重新随机正确连接并复位为正确。
func _on_work_started() -> void:
	randomize_for_day()


func _after_change() -> void:
	_update_wiring_power()
	_update_visual()
	queue_redraw()
	EventBus.push_event("wiring_changed")


## 接线正确 → 清掉接线盒造成的断电；错误 → 确保有一个受影响设备处于断电（每次随机）。
func _update_wiring_power() -> void:
	if is_correct():
		for t: StringName in GameConfig.wiring().affected_devices:
			Ledger.wiring_cut.erase(t)
		return
	if not _any_affected_cut():
		var affected := GameConfig.wiring().affected_devices
		if not affected.is_empty():
			Ledger.wiring_cut[affected[randi() % affected.size()]] = true


func _any_affected_cut() -> bool:
	for t: StringName in GameConfig.wiring().affected_devices:
		if Ledger.wiring_cut.has(t):
			return true
	return false


## 生成一个随机"正确连接"：每侧 count 个点，随机选若干对一对一连接，可能留 1 个迷惑点不连。
func _make_random_wiring(count: int) -> Dictionary:
	var lefts: Array[int] = []
	var rights: Array[int] = []
	for i: int in count:
		lefts.append(i)
		rights.append(i)
	lefts.shuffle()
	rights.shuffle()
	var connect_count := count
	if GameConfig.wiring().should_leave_decoy(count):
		connect_count = count - 1  # 留一个迷惑点
	var result: Dictionary = {}
	for i: int in connect_count:
		result[lefts[i]] = rights[i]
	return result


func _draw() -> void:
	if _has_visual_texture():
		draw_shock_trap_marker(OFFSET + Vector2(SIZE.x * 0.34, -SIZE.y * 0.4))
		return
	var rect := Rect2(OFFSET - SIZE * 0.5, SIZE)
	var accent := OK_COLOR if is_correct() else FAULT_COLOR
	draw_rect(rect, Color(0.09, 0.14, 0.14))
	draw_rect(rect, accent, false, 3.0)
	# 简化示意：左右两列小点 + 当前连线（详细交互在面板里）。
	var top := OFFSET.y - 52.0
	var step := 104.0 / float(maxi(1, point_count - 1))
	var lx := OFFSET.x - 48.0
	var rx := OFFSET.x + 48.0
	for left: int in connections.keys():
		var right: int = connections[left]
		draw_line(Vector2(lx, top + left * step), Vector2(rx, top + right * step), accent, 2.0)
	for i: int in point_count:
		draw_circle(Vector2(lx, top + i * step), 5.0, accent)
		draw_circle(Vector2(rx, top + i * step), 5.0, accent)
	draw_shock_trap_marker(OFFSET + Vector2(SIZE.x * 0.34, -SIZE.y * 0.4))


func _update_visual() -> void:
	if visual != null:
		visual.apply_state(device_state())


func _has_visual_texture() -> bool:
	return visual != null and visual.has_texture()
