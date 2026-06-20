extends BaseState
## 2.0 结算阶段：展示当天交货量与收入，按 [N] 入账并进入下一天。


func enter(_msg: Dictionary = {}) -> void:
	Ledger.working_active = false
	var data := {
		"day": Game.day,
		"delivered": Ledger.delivered_today,
		"quota": Ledger.quota_today(),
		"profit": Ledger.profit_today,
		"combo": Ledger.combo_count,
	}
	EventBus.push_event("day_summary", data)


func update(_delta: float) -> void:
	if Input.is_action_just_pressed("next_day"):
		Ledger.settle_and_advance()
		fsm.transition_to(&"Working")
