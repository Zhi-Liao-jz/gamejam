extends BaseState
## 潜入：选目标、直线接近、放脚步声。到设备旁 → 捣乱；玩家靠近 → 逃跑。

var monkey: Monkey
var target: BaseDevice


func enter(_msg: Dictionary = {}) -> void:
	monkey = fsm.get_parent() as Monkey
	target = monkey.pick_target()
	monkey.target_device = target
	# 仅在有目标（有威胁）时放脚步声；无目标时静默，避免"脚步=预警"语义失真
	if target != null:
		monkey.play_loop("monkey_step")
	else:
		monkey.stop_audio()


func physics_update(delta: float) -> void:
	# 目标失效（被修/没了）→ 重选
	if (
		target == null
		or not is_instance_valid(target)
		or target.state != BaseDevice.DeviceState.NORMAL
	):
		target = monkey.pick_target()
		monkey.target_device = target
		# 无可篡改设备（全坏，常见于玩家摸鱼时）→ 原地静默待命，不放假预警脚步声
		if target == null:
			monkey.stop_audio()
			return
		monkey.play_loop("monkey_step")  # 重新有目标→脚步声恢复
	# 玩家靠近 → 逃跑
	var player := monkey.get_player()
	if player and monkey.global_position.distance_to(player.global_position) <= monkey.flee_trigger:
		fsm.transition_to(&"Fleeing")
		return
	# 直线接近目标
	var to_target := target.global_position - monkey.global_position
	if to_target.length() <= monkey.REACH:
		fsm.transition_to(&"Tampering")
		return
	monkey.global_position += to_target.normalized() * monkey.speed * delta
