extends BaseState
## 一天的"结算"状态：算工资、弹结算面板，等玩家选择下一天 / 重试。

var wage: int = 0
var outcome: String = "win_day"  # win_day / fail_fatal / fail_bankrupt


func enter(msg: Dictionary = {}) -> void:
	outcome = msg.get("outcome", "win_day")
	wage = Game.compute_wage()
	var data := {
		"base": Game.BASE_WAGE,
		"repair": Game.today_repair_cost,
		"loss": int(Game.today_loss),
		"wage": wage,
		"outcome": outcome,
		"rating": Game.rate_wage(wage),
	}
	EventBus.push_event("show_settlement", data)


func update(_delta: float) -> void:
	# 失败(game over)时屏蔽 [N]：当天工资不入账、不推进天，只能 [R] 重试当天
	# 通关时 [N] 先发工资(day++)，再进商店逛店买装备，逛完才进下一天
	if outcome == "win_day" and Input.is_action_just_pressed("next_day"):
		Game.settle_and_advance(wage)
		fsm.transition_to(&"Shop")
	elif Input.is_action_just_pressed("retry"):
		fsm.transition_to(&"Working")
