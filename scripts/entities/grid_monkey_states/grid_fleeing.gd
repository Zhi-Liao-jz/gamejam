extends BaseState
## 逃跑：朝出生边缘房间撤离（被驱赶与得手共用此出口）。
## 到边缘后冷却 cooldown 秒，再重算难度、回潜入开下一轮，维持当天持续压力。

var monkey: GridMonkey
var _cooldown_left: float = -1.0  # <0 还在撤离；>=0 已到边缘，倒计时冷却


func enter(_msg: Dictionary = {}) -> void:
	monkey = fsm.get_parent() as GridMonkey
	_cooldown_left = -1.0
	monkey.target_room = -1
	monkey.play_loop("monkey_step", 1.4)  # 脚步调高表现慌乱


func physics_update(delta: float) -> void:
	if _cooldown_left < 0.0:
		if monkey.advance_toward(monkey.exit_room, monkey.flee_speed, delta):
			_cooldown_left = monkey.cooldown
			monkey.stop_audio()
		return
	_cooldown_left -= delta
	if _cooldown_left <= 0.0:
		monkey.apply_day_scaling()
		fsm.transition_to(&"GridSneaking")
