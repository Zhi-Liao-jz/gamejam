class_name PowerBox
extends BaseDevice
## 发电机 / 接线盒（P6 / 第6-7天，文档模块8 右下）：供电系统。
## 猴子第6天起会制造发电机或接线盒故障，玩家需要点对应部件恢复供电。
## 状态镜像到 Ledger.power_on，供产品出口 / 加热台读取。

enum State { POWERED, GENERATOR_STALLED, WIRING_BROKEN }

const ACTION_STALL_GENERATOR: StringName = &"stall_generator"
const ACTION_BREAK_WIRING: StringName = &"break_wiring"
const ACTION_RESTART_GENERATOR: StringName = &"restart_generator"
const ACTION_RECONNECT_WIRING: StringName = &"reconnect_wiring"
const SIZE := Vector2(330.0, 170.0)  # 电击陷阱命中盒 / 视觉外框（房间局部坐标）
const GENERATOR_SIZE := Vector2(140.0, 135.0)
const GENERATOR_OFFSET := Vector2(-85.0, 8.0)
const WIRING_SIZE := Vector2(140.0, 135.0)
const WIRING_OFFSET := Vector2(85.0, 8.0)
const GENERATOR_FAULT_COLOR := Color(0.95, 0.38, 0.12)
const WIRING_FAULT_COLOR := Color(0.95, 0.72, 0.16)
const POWERED_COLOR := Color(0.30, 0.85, 0.75)
const OFFLINE_COLOR := Color(0.18, 0.14, 0.12)

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


## 发电机区域命中盒。
func generator_rect() -> Rect2:
	return Rect2(global_position + GENERATOR_OFFSET - GENERATOR_SIZE * 0.5, GENERATOR_SIZE)


## 接线盒区域命中盒。
func wiring_rect() -> Rect2:
	return Rect2(global_position + WIRING_OFFSET - WIRING_SIZE * 0.5, WIRING_SIZE)


## 猴子是否能下手：通电时制造一种故障；已停电则不必再来。
func is_attackable() -> bool:
	return state == State.POWERED


## 玩家是否能修：存在任一故障时。
func is_repairable() -> bool:
	return state != State.POWERED


func is_outage() -> bool:
	return state != State.POWERED


func repair_action_at(world_pos: Vector2) -> StringName:
	match state:
		State.GENERATOR_STALLED:
			if generator_rect().has_point(world_pos):
				return ACTION_RESTART_GENERATOR
		State.WIRING_BROKEN:
			if wiring_rect().has_point(world_pos):
				return ACTION_RECONNECT_WIRING
	return &""


func fault_text() -> String:
	match state:
		State.GENERATOR_STALLED:
			return "发电机停转"
		State.WIRING_BROKEN:
			return "接线盒断线"
		_:
			return "供电正常"


func available_actions(actor: StringName) -> Array[StringName]:
	if actor == ACTOR_PLAYER and is_repairable():
		match state:
			State.GENERATOR_STALLED:
				return [ACTION_RESTART_GENERATOR]
			State.WIRING_BROKEN:
				return [ACTION_RECONNECT_WIRING]
	if actor == ACTOR_MONKEY and is_attackable():
		return [ACTION_STALL_GENERATOR, ACTION_BREAK_WIRING]
	return []


func device_state() -> StringName:
	match state:
		State.POWERED:
			return &"powered"
		State.GENERATOR_STALLED:
			return &"generator_stalled"
		State.WIRING_BROKEN:
			return &"wiring_broken"
		_:
			return &"unknown"


func can_install_shock_trap() -> bool:
	return Game.day >= 6 and super.can_install_shock_trap()


## 调试 / 兼容入口：猴子随机制造一种供电故障。
func cut() -> void:
	var actions := available_actions(ACTOR_MONKEY)
	if actions.is_empty():
		return
	start_action(StringName(actions.pick_random()), ACTOR_MONKEY, null)


## 调试 / 兼容入口：玩家修复当前故障。
func repair() -> void:
	var actions := available_actions(ACTOR_PLAYER)
	if actions.is_empty():
		return
	start_action(actions[0], ACTOR_PLAYER, null)


func _perform_action(action_id: StringName, _actor: StringName, _actor_node: Node) -> bool:
	var next_state: State = state
	var should_play_repair_sound := false
	match action_id:
		ACTION_STALL_GENERATOR:
			if state == State.POWERED:
				next_state = State.GENERATOR_STALLED
		ACTION_BREAK_WIRING:
			if state == State.POWERED:
				next_state = State.WIRING_BROKEN
		ACTION_RESTART_GENERATOR:
			if state == State.GENERATOR_STALLED:
				next_state = State.POWERED
				should_play_repair_sound = true
		ACTION_RECONNECT_WIRING:
			if state == State.WIRING_BROKEN:
				next_state = State.POWERED
				should_play_repair_sound = true
		_:
			return false
	if next_state == state:
		return false
	state = next_state
	_sync_power_state()
	queue_redraw()
	if should_play_repair_sound:
		SoundManager.play("boop")
	return true


func _on_work_started() -> void:
	state = State.POWERED
	_sync_power_state()
	queue_redraw()


func _draw() -> void:
	var outer := Rect2(-SIZE * 0.5, SIZE)
	var generator := Rect2(GENERATOR_OFFSET - GENERATOR_SIZE * 0.5, GENERATOR_SIZE)
	var wiring := Rect2(WIRING_OFFSET - WIRING_SIZE * 0.5, WIRING_SIZE)
	draw_rect(outer, Color(0.09, 0.14, 0.14))
	draw_rect(outer, POWERED_COLOR if state == State.POWERED else OFFLINE_COLOR, false, 3.0)
	_draw_generator(generator)
	_draw_wiring(wiring)
	draw_line(
		GENERATOR_OFFSET + Vector2(GENERATOR_SIZE.x * 0.42, 0.0),
		WIRING_OFFSET - Vector2(WIRING_SIZE.x * 0.42, 0.0),
		POWERED_COLOR if state == State.POWERED else OFFLINE_COLOR.lightened(0.35),
		5.0
	)
	draw_shock_trap_marker(Vector2(SIZE.x * 0.42, -SIZE.y * 0.36))


func _sync_power_state() -> void:
	Ledger.power_on = state == State.POWERED


func _draw_generator(rect: Rect2) -> void:
	var is_fault := state == State.GENERATOR_STALLED
	var fill := GENERATOR_FAULT_COLOR if is_fault else Color(0.12, 0.38, 0.36)
	if state == State.WIRING_BROKEN:
		fill = OFFLINE_COLOR
	draw_rect(rect, fill)
	draw_rect(rect, GENERATOR_FAULT_COLOR if is_fault else POWERED_COLOR, false, 3.0)
	draw_circle(GENERATOR_OFFSET, 32.0, fill.darkened(0.25))
	draw_circle(GENERATOR_OFFSET, 32.0, POWERED_COLOR if not is_fault else Color.WHITE, false, 3.0)
	draw_line(
		GENERATOR_OFFSET + Vector2(-20.0, 0.0),
		GENERATOR_OFFSET + Vector2(20.0, 0.0),
		Color.WHITE,
		3.0
	)
	draw_line(
		GENERATOR_OFFSET + Vector2(0.0, -20.0),
		GENERATOR_OFFSET + Vector2(0.0, 20.0),
		Color.WHITE,
		3.0
	)


func _draw_wiring(rect: Rect2) -> void:
	var is_fault := state == State.WIRING_BROKEN
	var fill := WIRING_FAULT_COLOR if is_fault else Color(0.12, 0.38, 0.36)
	if state == State.GENERATOR_STALLED:
		fill = OFFLINE_COLOR
	draw_rect(rect, fill)
	draw_rect(rect, WIRING_FAULT_COLOR if is_fault else POWERED_COLOR, false, 3.0)
	for i: int in range(4):
		var y := WIRING_OFFSET.y - 42.0 + i * 28.0
		var color := Color(0.95, 0.90, 0.62) if is_fault else POWERED_COLOR
		draw_line(
			Vector2(WIRING_OFFSET.x - 45.0, y), Vector2(WIRING_OFFSET.x + 45.0, y), color, 4.0
		)
