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


## 目标仍可捣乱：自爆开关看 is_attackable，面板房间看 panel_open（已被关则换目标）。
func _target_valid() -> bool:
	var room := monkey.room_manager.room_node(monkey.target_room)
	if room == null:
		return false
	if room.role == &"self_destruct":
		var sd: SelfDestruct = monkey.room_manager.self_destruct
		return sd != null and sd.is_attackable()
	if room.role == &"power":
		var pw: PowerBox = monkey.room_manager.power
		return pw != null and pw.is_attackable()
	return room.panel_open()
