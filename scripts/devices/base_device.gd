class_name BaseDevice
extends Node2D
## 可交互设备基类：统一玩家和猴子的设备动作入口。

const ACTOR_PLAYER: StringName = &"player"
const ACTOR_MONKEY: StringName = &"monkey"

var device_id: StringName = &""
var device_type: StringName = &""
var room_id: int = -1
var is_open: bool = true
var can_player_interact: bool = true
var can_monkey_interact: bool = true
var has_shock_trap: bool = false

var _select_frame: CanvasItem = null
var _select_frame_checked: bool = false


## 玩家光标悬停时显示 / 隐藏该设备的选中框（场景里名为 SelectFrame 的子节点，无则忽略）。
func set_highlighted(on: bool) -> void:
	if not _select_frame_checked:
		_select_frame_checked = true
		if has_node("SelectFrame"):
			_select_frame = get_node("SelectFrame") as CanvasItem
			if _select_frame != null:
				_select_frame.visible = false
	if _select_frame != null and is_instance_valid(_select_frame):
		_select_frame.visible = on


## 基础设备配置。派生设备在 setup 中调用。
func setup_device(id: StringName, type: StringName, owner_room_id: int) -> void:
	device_id = id
	device_type = type
	room_id = owner_room_id
	add_to_group("devices")
	EventBus.subscribe("work_started", _on_device_work_started)


## 当前可用动作列表。派生设备按状态返回。
func available_actions(_actor: StringName) -> Array[StringName]:
	return []


## 某动作需要的交互耗时。玩家动作即时，猴子动作由状态机等待后完成。
func action_duration(_action_id: StringName, actor: StringName) -> float:
	if actor == ACTOR_MONKEY:
		return GameConfig.monkey().base_tamper_delay
	return 0.0


## 当前设备状态。派生设备按自己的状态机覆盖。
func device_state() -> StringName:
	return &"ready"


## 该猴子动作是否属于"修复 / 还原"类（与"破坏"相对）。派生设备覆盖。
## 供猴子"更爱破坏少修"的概率过滤使用；默认全部视为破坏（总会执行）。
func monkey_action_is_repair(_action_id: StringName) -> bool:
	return false


## 开始一个动作，但不立刻执行效果。猴子用它进入可被打断的交互过程。
func begin_action(action_id: StringName, actor: StringName, actor_node: Node = null) -> bool:
	if not _can_actor_interact(actor):
		return false
	if not available_actions(actor).has(action_id):
		return false
	if actor == ACTOR_MONKEY and has_shock_trap:
		_trigger_shock_trap(action_id, actor_node)
		return false
	EventBus.push_event("device_action_started", [device_id, action_id, actor_node])
	return true


## 完成一个已开始的动作。若动作在等待期间失效，按被打断处理。
func finish_action(action_id: StringName, actor: StringName, actor_node: Node = null) -> bool:
	if not _can_actor_interact(actor):
		interrupt_action(action_id, actor_node)
		return false
	if actor == ACTOR_MONKEY and has_shock_trap:
		_trigger_shock_trap(action_id, actor_node)
		return false
	if not available_actions(actor).has(action_id):
		interrupt_action(action_id, actor_node)
		return false
	var finished := _perform_action(action_id, actor, actor_node)
	if finished:
		EventBus.push_event("device_action_finished", [device_id, action_id, actor_node])
	else:
		interrupt_action(action_id, actor_node)
	return finished


## 统一即时动作入口。返回是否成功完成动作。
func start_action(action_id: StringName, actor: StringName, actor_node: Node = null) -> bool:
	if not _can_actor_interact(actor):
		return false
	if not available_actions(actor).has(action_id):
		return false
	if actor == ACTOR_MONKEY and has_shock_trap:
		_trigger_shock_trap(action_id, actor_node)
		return false
	EventBus.push_event("device_action_started", [device_id, action_id, actor_node])
	var finished := _perform_action(action_id, actor, actor_node)
	if finished:
		EventBus.push_event("device_action_finished", [device_id, action_id, actor_node])
	return finished


## 统一打断入口，供装备和后续猴子状态使用。
func interrupt_action(action_id: StringName, actor_node: Node = null) -> void:
	EventBus.push_event("device_action_interrupted", [device_id, action_id, actor_node])


## 当前设备是否允许安装电击陷阱。
func can_install_shock_trap() -> bool:
	return (
		can_monkey_interact
		and not has_shock_trap
		and not available_actions(ACTOR_MONKEY).is_empty()
	)


## 安装电击陷阱。陷阱触发后会打断猴子的本次动作并移除。
func install_shock_trap() -> bool:
	if not can_install_shock_trap():
		return false
	has_shock_trap = true
	queue_redraw()
	return true


## 设备绘制函数内调用，用于提示已安装电击陷阱。
func draw_shock_trap_marker(offset: Vector2) -> void:
	if not has_shock_trap:
		return
	draw_circle(offset, 9.0, Color(0.95, 0.90, 0.18))
	draw_circle(offset, 9.0, Color(0.10, 0.10, 0.05), false, 2.0)


## 派生设备实现实际动作。
func _perform_action(_action_id: StringName, _actor: StringName, _actor_node: Node) -> bool:
	return false


func _can_actor_interact(actor: StringName) -> bool:
	match actor:
		ACTOR_PLAYER:
			return can_player_interact
		ACTOR_MONKEY:
			return can_monkey_interact
		_:
			return false


func _trigger_shock_trap(action_id: StringName, actor_node: Node) -> void:
	has_shock_trap = false
	queue_redraw()
	SoundManager.play("alarm")
	_spawn_shock_spark()  # 特效：设备处火花
	EventBus.push_event("shock_trap_triggered", [room_id])  # UI 提示：HUD 弹出 + 小地图闪烁
	interrupt_action(action_id, actor_node)
	if actor_node != null and actor_node.has_method("interrupt_by_shock_trap"):
		actor_node.call("interrupt_by_shock_trap", self)


## 在设备视觉位置生成一次性电击火花特效。
func _spawn_shock_spark() -> void:
	if not has_method("global_rect"):
		return
	var spark := ShockSpark.new()
	add_child(spark)
	var rect: Rect2 = call("global_rect")
	spark.global_position = rect.get_center()


func _on_device_work_started() -> void:
	has_shock_trap = false
	queue_redraw()
