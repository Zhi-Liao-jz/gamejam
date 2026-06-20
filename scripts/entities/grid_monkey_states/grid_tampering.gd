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
	if room == null or monkey.current_room != monkey.target_room:
		fsm.transition_to(&"GridSneaking")
		return
	if room.role == &"self_destruct":
		_tamper_self_destruct(delta)
		return
	if room.role == &"power":
		_tamper_power(delta)
		return
	# 交货 / 出口面板：面板已被关 → 回潜入重选
	if not room.panel_open():
		fsm.transition_to(&"GridSneaking")
		return
	_t += delta
	if _t >= monkey.tamper_delay:
		room.control_panel.close()
		SoundManager.play("alarm")  # 一声全局警报：面板被关，提醒玩家去重开
		fsm.transition_to(&"GridFleeing")


## 破坏中央自爆开关：每 tamper_delay 推进一步（开罩→按钮），按下后逃跑。
func _tamper_self_destruct(delta: float) -> void:
	var sd: SelfDestruct = monkey.room_manager.self_destruct
	if sd == null or not sd.is_attackable():
		fsm.transition_to(&"GridSneaking")  # 已被按下 / 玩家正处理 → 换目标
		return
	_t += delta
	if _t >= monkey.tamper_delay:
		_t = 0.0
		var armed := sd.sabotage_step()
		SoundManager.play("alarm")  # 开罩 / 按下都报警一声
		if armed:
			fsm.transition_to(&"GridFleeing")


## 破坏发电机：蓄力到点切断供电，然后逃跑。
func _tamper_power(delta: float) -> void:
	var pw: PowerBox = monkey.room_manager.power
	if pw == null or not pw.is_attackable():
		fsm.transition_to(&"GridSneaking")
		return
	_t += delta
	if _t >= monkey.tamper_delay:
		pw.cut()
		SoundManager.play("alarm")  # 停电：报警提示
		fsm.transition_to(&"GridFleeing")
