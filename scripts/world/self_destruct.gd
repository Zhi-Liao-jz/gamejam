class_name SelfDestruct
extends BaseDevice
## 中央自爆开关（P3 / 第3天，文档模块6）：玻璃罩保护 → 猴子先开罩再按钮 → 倒计时 → 当天失败。
## 玩家切到中央房间点它可重置（关罩 / 取消倒计时）。状态走小地图 + HUD 提示。
## 倒计时归零只置 Ledger.day_failed 标志，由 DayManager(Working.update) 转入 Failed 状态收尾。

enum State { PROTECTED, EXPOSED, ARMED, TRIGGERED }  # 受保护 / 罩被打开 / 已按下倒计时 / 已引爆

const ACTION_OPEN_COVER: StringName = &"open_cover"
const ACTION_PRESS_BUTTON: StringName = &"press_button"
const ACTION_RESET: StringName = &"reset"
const SIZE := Vector2(140.0, 140.0)  # 命中盒 / 视觉尺寸（房间局部坐标）
const COUNTDOWN := 8.0  # 按下后到引爆的秒数（= 玩家切到中央取消的窗口）

var state: State = State.PROTECTED

var _remaining: float = 0.0


func _ready() -> void:
	add_to_group("self_destruct")
	EventBus.subscribe("work_started", _on_work_started)
	set_process(false)  # 仅 ARMED 倒计时阶段才逐帧


func _process(delta: float) -> void:
	if state != State.ARMED:
		return
	_remaining -= delta
	queue_redraw()
	if _remaining <= 0.0:
		_remaining = 0.0
		state = State.TRIGGERED
		set_process(false)
		Ledger.day_failed = true  # 由 Working.update 据此转 Failed
		queue_redraw()


## 由 RoomManager 在挂载前写入归属房间（中央格）。
func setup(owner_room_id: int) -> void:
	setup_device(&"self_destruct", &"self_destruct", owner_room_id)


## 世界坐标命中盒（玩家点击重置用）。
func global_rect() -> Rect2:
	return Rect2(global_position - SIZE * 0.5, SIZE)


## 猴子是否还能下手：受保护 / 罩开着可继续破坏；已按下 / 已引爆则不必再来。
func is_attackable() -> bool:
	return state == State.PROTECTED or state == State.EXPOSED


## 玩家是否能重置：罩被开 / 倒计时中。
func is_resettable() -> bool:
	return state == State.EXPOSED or state == State.ARMED


## 倒计时剩余秒数（HUD 显示）。
func remaining() -> float:
	return _remaining


func available_actions(actor: StringName) -> Array[StringName]:
	var actions: Array[StringName] = []
	if actor == ACTOR_PLAYER and is_resettable():
		actions.append(ACTION_RESET)
	if actor == ACTOR_MONKEY:
		# 确定性升级：罩受保护→开罩；罩已开→按下按钮。猴子不会自己关罩撤销（拆弹只能靠玩家）。
		# 已按下倒计时（ARMED）猴子无动作可选。
		if state == State.PROTECTED:
			actions.append(ACTION_OPEN_COVER)
		elif state == State.EXPOSED:
			actions.append(ACTION_PRESS_BUTTON)
	return actions


## 猴子破坏自爆的时序是固定设计窗口：开罩 5 秒、按下 1 秒（不随天数缩放，见 GridMonkey）。
func action_duration(action_id: StringName, actor: StringName) -> float:
	if actor == ACTOR_MONKEY:
		match action_id:
			ACTION_OPEN_COVER:
				return 5.0
			ACTION_PRESS_BUTTON:
				return 1.0
	return super.action_duration(action_id, actor)


## 确定性升级序列：开罩成功后猴子留在原地，1 秒后按下按钮（不会中途改主意关罩）。
func monkey_followup_action(finished_action: StringName) -> StringName:
	if finished_action == ACTION_OPEN_COVER and state == State.EXPOSED:
		return ACTION_PRESS_BUTTON
	return &""


## 按下自爆按钮（起爆倒计时）后，猴子逃离现场。
func monkey_flees_after(finished_action: StringName) -> bool:
	return finished_action == ACTION_PRESS_BUTTON


func device_state() -> StringName:
	match state:
		State.PROTECTED:
			return &"protected"
		State.EXPOSED:
			return &"exposed"
		State.ARMED:
			return &"armed"
		State.TRIGGERED:
			return &"triggered"
		_:
			return &"unknown"


func can_install_shock_trap() -> bool:
	return Game.day >= 3 and super.can_install_shock_trap()


## 玩家重置：关罩 / 取消倒计时 → 回受保护。
func player_reset() -> void:
	start_action(ACTION_RESET, ACTOR_PLAYER, null)


func _perform_action(action_id: StringName, _actor: StringName, _actor_node: Node) -> bool:
	match action_id:
		ACTION_OPEN_COVER:
			return _open_cover()
		ACTION_PRESS_BUTTON:
			return _press_button()
		ACTION_RESET:
			return _reset_protection()
		_:
			return false


func _open_cover() -> bool:
	if state != State.PROTECTED:
		return false
	state = State.EXPOSED
	queue_redraw()
	return true


func _press_button() -> bool:
	if state != State.EXPOSED:
		return false
	state = State.ARMED
	_remaining = COUNTDOWN
	set_process(true)
	queue_redraw()
	return true


func _reset_protection() -> bool:
	if not is_resettable():
		return false
	_force_reset_protection()
	return true


func _force_reset_protection() -> void:
	state = State.PROTECTED
	_remaining = 0.0
	set_process(false)
	queue_redraw()


func _on_work_started() -> void:
	_force_reset_protection()


func _draw() -> void:
	var rect := Rect2(-SIZE * 0.5, SIZE)
	draw_rect(rect, Color(0.30, 0.05, 0.05))  # 底座
	var btn := Rect2(-SIZE * 0.30, SIZE * 0.6)
	var btn_color := Color(1.0, 0.85, 0.10) if state == State.ARMED else Color(0.90, 0.20, 0.18)
	draw_rect(btn, btn_color)  # 红按钮；倒计时中变黄
	if state == State.PROTECTED:
		draw_rect(rect, Color(0.70, 0.85, 1.0, 0.85), false, 5.0)  # 玻璃罩盖着：浅蓝边框
	else:
		draw_rect(rect, Color(0.95, 0.30, 0.20), false, 5.0)  # 罩开 / 危险：红框
	draw_shock_trap_marker(Vector2(SIZE.x * 0.32, -SIZE.y * 0.32))
