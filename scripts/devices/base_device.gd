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


## 基础设备配置。派生设备在 setup 中调用。
func setup_device(id: StringName, type: StringName, owner_room_id: int) -> void:
	device_id = id
	device_type = type
	room_id = owner_room_id
	add_to_group("devices")


## 当前可用动作列表。派生设备按状态返回。
func available_actions(_actor: StringName) -> Array[StringName]:
	return []


## 某动作需要的交互耗时。当前玩家动作即时，猴子由状态机蓄力后调用完成。
func action_duration(_action_id: StringName, _actor: StringName) -> float:
	return 0.0


## 当前设备状态。派生设备按自己的状态机覆盖。
func device_state() -> StringName:
	return &"ready"


## 统一动作入口。返回是否成功完成动作。
func start_action(action_id: StringName, actor: StringName, actor_node: Node = null) -> bool:
	if not _can_actor_interact(actor):
		return false
	if not available_actions(actor).has(action_id):
		return false
	EventBus.push_event("device_action_started", [device_id, action_id, actor_node])
	var finished := _perform_action(action_id, actor, actor_node)
	if finished:
		EventBus.push_event("device_action_finished", [device_id, action_id, actor_node])
	return finished


## 统一打断入口，供装备和后续猴子状态使用。
func interrupt_action(action_id: StringName, actor_node: Node = null) -> void:
	EventBus.push_event("device_action_interrupted", [device_id, action_id, actor_node])


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
