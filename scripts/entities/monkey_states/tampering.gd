extends BaseState
## 捣乱：停下、放翻找声、蓄力 tamper_delay 秒（给亭内玩家的"决策窗口"）。
## 蓄力到点 → 调一次 device.tamper() 后逃跑（搞完就跑，制造扑空）；蓄力期玩家靠近 → 被吓跑、没得逞。

var monkey: Monkey
var _t: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	monkey = fsm.get_parent() as Monkey
	_t = 0.0
	monkey.play_loop("monkey_fiddle")


func physics_update(delta: float) -> void:
	var target: BaseDevice = monkey.target_device
	# 目标失效 → 回潜入重选
	if target == null or not is_instance_valid(target):
		fsm.transition_to(&"Sneaking")
		return
	# 蓄力期玩家靠近 → 吓跑，没得逞（奖励及时反应）
	var player := monkey.get_player()
	if player and monkey.global_position.distance_to(player.global_position) <= monkey.flee_trigger:
		fsm.transition_to(&"Fleeing")
		return
	_t += delta
	if _t >= monkey.tamper_delay:
		target.tamper()  # NORMAL-only 幂等，重复触达坏设备不出 bug
		fsm.transition_to(&"Fleeing")
