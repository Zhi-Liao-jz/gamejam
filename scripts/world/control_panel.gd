class_name ControlPanel
extends BaseDevice
## 房间控制面板（交货点 / 产品出口）：开 = 正常工作，关 = 停摆。
## 猴子捣乱 = 把面板关掉；玩家切到该房间点面板重新打开。
## 每天工作开始（work_started）自动复位为开，避免上一天的关闭状态残留。

const ACTION_OPEN: StringName = &"open"
const ACTION_CLOSE: StringName = &"close"
const SIZE := Vector2(96.0, 54.0)  # 面板命中盒 / 视觉尺寸（房间局部坐标）

var controls: StringName = &""  # 本面板管哪个系统：delivery / product_exit（仅记录用）


func _ready() -> void:
	EventBus.subscribe("work_started", _on_work_started)


## 由 RoomManager 在挂载前写入：归属房间 + 管控的系统类别。
func setup(owner_room_id: int, controlled: StringName) -> void:
	controls = controlled
	setup_device(StringName("panel_%d" % owner_room_id), &"control_panel", owner_room_id)


## 世界坐标命中盒（供玩家点击重开）。
func global_rect() -> Rect2:
	return Rect2(global_position - SIZE * 0.5, SIZE)


func available_actions(actor: StringName) -> Array[StringName]:
	if actor == ACTOR_PLAYER and not is_open:
		return [ACTION_OPEN]
	if actor == ACTOR_MONKEY:
		# 全随机：猴子可能关掉面板，也可能把关上的面板重新打开（§8.2 可坏可修）
		if is_open:
			return [ACTION_CLOSE]
		return [ACTION_OPEN]
	return []


func device_state() -> StringName:
	return &"open" if is_open else &"closed"


## 打开面板（已开则不重复广播）。
func open() -> void:
	if is_open:
		return
	is_open = true
	queue_redraw()
	EventBus.push_event("panel_changed", [room_id, true])


## 关闭面板（已关则不重复广播）。
func close() -> void:
	if not is_open:
		return
	is_open = false
	queue_redraw()
	EventBus.push_event("panel_changed", [room_id, false])


func _perform_action(action_id: StringName, _actor: StringName, _actor_node: Node) -> bool:
	match action_id:
		ACTION_OPEN:
			open()
			return true
		ACTION_CLOSE:
			close()
			return true
		_:
			return false


func _on_work_started() -> void:
	open()  # 新一天复位为开


func _draw() -> void:
	var rect := Rect2(-SIZE * 0.5, SIZE)
	var fill := Color(0.20, 0.62, 0.32) if is_open else Color(0.72, 0.18, 0.16)
	draw_rect(rect, fill)
	draw_rect(rect, Color(0.92, 0.92, 0.92), false, 2.0)
	draw_shock_trap_marker(Vector2(SIZE.x * 0.34, -SIZE.y * 0.28))
