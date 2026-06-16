extends BaseState
## 一天的"结算"状态：算工资、弹结算面板，等玩家选择下一天 / 重试。

var wage: int = 0


func enter(_msg: Dictionary = {}) -> void:
	wage = Game.compute_wage()
	var data := {
		"base": Game.BASE_WAGE,
		"repair": Game.today_repair_cost,
		"loss": int(Game.today_loss),
		"wage": wage,
	}
	EventBus.push_event("show_settlement", data)


func update(_delta: float) -> void:
	if Input.is_action_just_pressed("next_day"):
		Game.settle_and_advance(wage)
		fsm.transition_to(&"Working")
	elif Input.is_action_just_pressed("retry"):
		fsm.transition_to(&"Working")
