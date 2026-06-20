class_name PowerBox
extends BaseDevice
## 发电机 / 接线盒（P6 / 第6-7天，文档模块8 右下）：供电系统。
## 猴子第6天起可切断供电 → 停电时产品出口 + 加热台停摆（"部分设备关闭"）。
## 玩家切到右下房间点它修复恢复供电。状态镜像到 Ledger.power_on，供出口/加热台读取。

enum State { POWERED, OUTAGE }  # 通电 / 停电

const ACTION_CUT_POWER: StringName = &"cut_power"
const ACTION_REPAIR_POWER: StringName = &"repair_power"
const SIZE := Vector2(150.0, 150.0)  # 命中盒 / 视觉尺寸（房间局部坐标）

var state: State = State.POWERED


func _ready() -> void:
	add_to_group("power")
	EventBus.subscribe("work_started", _on_work_started)


## 由 RoomManager 在挂载前写入归属房间（右下）。
func setup(owner_room_id: int) -> void:
	setup_device(&"power_box", &"power", owner_room_id)


## 世界坐标命中盒（玩家点击修复用）。
func global_rect() -> Rect2:
	return Rect2(global_position - SIZE * 0.5, SIZE)


## 猴子是否能下手：通电时可切断；已停电则不必再来。
func is_attackable() -> bool:
	return state == State.POWERED


## 玩家是否能修：停电时。
func is_repairable() -> bool:
	return state == State.OUTAGE


func available_actions(actor: StringName) -> Array[StringName]:
	if actor == ACTOR_PLAYER and is_repairable():
		return [ACTION_REPAIR_POWER]
	if actor == ACTOR_MONKEY and is_attackable():
		return [ACTION_CUT_POWER]
	return []


func device_state() -> StringName:
	return &"powered" if state == State.POWERED else &"outage"


## 猴子切断供电。
func cut() -> void:
	start_action(ACTION_CUT_POWER, ACTOR_MONKEY, null)


## 玩家修复供电。
func repair() -> void:
	start_action(ACTION_REPAIR_POWER, ACTOR_PLAYER, null)


func _perform_action(action_id: StringName, _actor: StringName, _actor_node: Node) -> bool:
	match action_id:
		ACTION_CUT_POWER:
			if state == State.OUTAGE:
				return false
			state = State.OUTAGE
			Ledger.power_on = false
			queue_redraw()
			return true
		ACTION_REPAIR_POWER:
			if state == State.POWERED:
				return false
			state = State.POWERED
			Ledger.power_on = true
			queue_redraw()
			return true
		_:
			return false


func _on_work_started() -> void:
	state = State.POWERED
	Ledger.power_on = true
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-SIZE * 0.5, SIZE)
	if state == State.POWERED:
		draw_rect(rect, Color(0.12, 0.40, 0.38))
		draw_rect(rect, Color(0.30, 0.85, 0.75), false, 4.0)  # 青绿 = 通电
	else:
		draw_rect(rect, Color(0.20, 0.10, 0.05))
		draw_rect(rect, Color(0.95, 0.35, 0.10), false, 4.0)  # 橙红 = 停电
