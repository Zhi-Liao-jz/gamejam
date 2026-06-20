extends BaseState
## 捣乱：在目标房间蓄力 tamper_delay 秒，到点通过统一设备动作完成捣乱。
## 蓄力期玩家切到本房间点掉猴子 → Hand 调 monkey.shoo() 转逃跑（在此之外触发）。

var monkey: GridMonkey
var _t: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	monkey = fsm.get_parent() as GridMonkey
	_t = 0.0
	monkey.play_loop("monkey_fiddle")


func physics_update(delta: float) -> void:
	var room := monkey.room_manager.room_node(monkey.target_room)
	if room == null or monkey.current_room != monkey.target_room:
		fsm.transition_to(&"GridSneaking")
		return
	var device := monkey.target_device()
	if device == null:
		fsm.transition_to(&"GridSneaking")
		return
	_t += delta
	if _t >= monkey.tamper_delay:
		_finish_device_action(device)


func _finish_device_action(device: BaseDevice) -> void:
	var actions := device.available_actions(BaseDevice.ACTOR_MONKEY)
	if actions.is_empty():
		fsm.transition_to(&"GridSneaking")
		return
	var action_id := actions[randi() % actions.size()]
	if not device.start_action(action_id, BaseDevice.ACTOR_MONKEY, monkey):
		fsm.transition_to(&"GridSneaking")
		return
	SoundManager.play("alarm")
	if device.device_type == &"self_destruct" and action_id == SelfDestruct.ACTION_OPEN_COVER:
		_t = 0.0
		return
	fsm.transition_to(&"GridFleeing")
