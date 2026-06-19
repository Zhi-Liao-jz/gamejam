extends BaseState
## 捣乱：在目标房间蓄力 tamper_delay 秒，到点关掉面板 + 放一声全局警报，然后逃跑。
## 蓄力期玩家切到本房间点掉猴子 → Hand 调 monkey.shoo() 转逃跑（在此之外触发）。

var monkey: GridMonkey
var _t: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	monkey = fsm.get_parent() as GridMonkey
	_t = 0.0
	monkey.play_loop("monkey_fiddle")


func physics_update(delta: float) -> void:
	var room := monkey.room_manager.room_node(monkey.target_room)
	# 目标没了 / 面板已被关 / 自己已不在目标房间 → 回潜入重选
	if room == null or not room.panel_open() or monkey.current_room != monkey.target_room:
		fsm.transition_to(&"GridSneaking")
		return
	_t += delta
	if _t >= monkey.tamper_delay:
		room.control_panel.close()
		SoundManager.play("alarm")  # 一声全局警报：面板被关，提醒玩家去重开
		fsm.transition_to(&"GridFleeing")
