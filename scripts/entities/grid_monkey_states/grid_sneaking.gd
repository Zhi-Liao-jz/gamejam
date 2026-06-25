extends BaseState
## 游荡：猴子在房间之间随机移动，抵达后随机挑当前房间设备动作。

var monkey: GridMonkey
var _pause_left: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	monkey = fsm.get_parent() as GridMonkey
	_pause_left = randf_range(GridMonkey.WANDER_PAUSE_MIN, GridMonkey.WANDER_PAUSE_MAX)
	monkey.clear_current_action()
	monkey.set_visual_state(&"sneaking")


func physics_update(delta: float) -> void:
	if monkey.target_room != -1 and monkey.current_room != monkey.target_room:
		monkey.play_loop("monkey_step")
		if monkey.advance_toward(monkey.target_room, monkey.speed, delta):
			monkey.target_room = -1
			monkey.stop_audio()
			_pause_left = randf_range(GridMonkey.WANDER_PAUSE_MIN, GridMonkey.WANDER_PAUSE_MAX)
		return
	monkey.stop_audio()
	_pause_left -= delta
	if _pause_left > 0.0:
		return
	if monkey.pick_current_room_action():
		fsm.transition_to(&"GridTampering")
		return
	monkey.target_room = monkey.pick_wander_room()
	if monkey.target_room == -1:
		_pause_left = randf_range(GridMonkey.WANDER_PAUSE_MIN, GridMonkey.WANDER_PAUSE_MAX)
	elif monkey.target_room == monkey.current_room:
		_pause_left = 0.0


func exit() -> void:
	if monkey != null:
		monkey.stop_audio()
