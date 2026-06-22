extends BaseState
## 随机交互：猴子开始当前设备动作，等待动作耗时后通过统一设备接口完成。
## 等待期玩家驱赶、捕网、电击陷阱都能打断。

var monkey: GridMonkey
var _t: float = 0.0
var _duration: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	monkey = fsm.get_parent() as GridMonkey
	_t = 0.0
	_duration = 0.0
	if not monkey.has_current_action():
		fsm.transition_to(&"GridSneaking")
		return
	_duration = monkey.current_action_duration()
	if not monkey.action_device.begin_action(monkey.action_id, BaseDevice.ACTOR_MONKEY, monkey):
		if fsm.current_state == self:
			monkey.clear_current_action()
			fsm.transition_to(&"GridSneaking")
		return
	monkey.play_loop("monkey_fiddle")


func physics_update(delta: float) -> void:
	if not monkey.has_current_action():
		fsm.transition_to(&"GridSneaking")
		return
	if monkey.current_room != monkey.action_device.room_id:
		monkey.interrupt_current_action()
		fsm.transition_to(&"GridSneaking")
		return
	_t += delta
	if _t >= _duration:
		_finish_device_action()


func exit() -> void:
	if monkey != null:
		monkey.stop_audio()


func _finish_device_action() -> void:
	var device := monkey.action_device
	var finished_action := monkey.action_id
	if not device.finish_action(finished_action, BaseDevice.ACTOR_MONKEY, monkey):
		# finish 失败可能是电击陷阱触发——那时 interrupt_by_shock_trap 已把猴子转入 GridFleeing。
		# 仅当仍停留在本状态才回游荡，否则会把"被电逃跑"覆盖成游荡，陷阱形同虚设。
		if fsm.current_state == self:
			monkey.clear_current_action()
			fsm.transition_to(&"GridSneaking")
		return
	SoundManager.play("alarm")
	monkey.clear_current_action()
	monkey.target_room = -1
	fsm.transition_to(&"GridSneaking")
