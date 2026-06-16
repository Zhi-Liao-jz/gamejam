extends BaseState
## 逃跑：朝 exit_point 撤离（被驱赶与得手共用此出口）。脚步由近及远 = 给亭内玩家"危机解除"信号。
## 到边缘后冷却 spawn_interval 秒，再重算难度、重选目标，回潜入开下一轮。

var monkey: Monkey
var _cooldown: float = -1.0  # <0 还在逃；>=0 已到边缘，倒计时冷却


func enter(_msg: Dictionary = {}) -> void:
	monkey = fsm.get_parent() as Monkey
	_cooldown = -1.0
	monkey.play_loop("monkey_step", 1.4)  # 脚步调高表现慌乱


func physics_update(delta: float) -> void:
	if _cooldown < 0.0:
		var to_exit := monkey.exit_point - monkey.global_position
		if to_exit.length() <= monkey.REACH:
			_cooldown = monkey.spawn_interval
			monkey.stop_audio()
			return
		monkey.global_position += to_exit.normalized() * monkey.flee_speed * delta
	else:
		_cooldown -= delta
		if _cooldown <= 0.0:
			monkey._apply_day_scaling()
			fsm.transition_to(&"Sneaking")
