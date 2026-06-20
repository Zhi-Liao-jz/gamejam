extends BaseState
## 潜入：选一个开着面板的房间，沿房间图走过去；走到目标房间 → 捣乱。
## 无可关面板（都被关了 / 玩家全开着没动）→ 原地静默待命，不放假预警脚步声。

var monkey: GridMonkey


func enter(_msg: Dictionary = {}) -> void:
	monkey = fsm.get_parent() as GridMonkey
	monkey.play_loop("monkey_step")


func physics_update(delta: float) -> void:
	if monkey.target_room == -1 or not _target_valid():
		monkey.target_room = monkey.pick_target()
		if monkey.target_room == -1:
			monkey.stop_audio()
			return
		monkey.play_loop("monkey_step")  # 重新有目标 → 脚步声恢复
	if monkey.advance_toward(monkey.target_room, monkey.speed, delta):
		fsm.transition_to(&"GridTampering")


## 目标仍可捣乱：房间内仍有猴子可用设备动作才继续。
func _target_valid() -> bool:
	return monkey.target_device() != null
