extends BaseState
## 2.0 结算阶段：展示当天交货量与收入，按 [N] 入账并进入下一天。


func enter(_msg: Dictionary = {}) -> void:
	Ledger.working_active = false
	EventBus.push_event("day_summary", Ledger.summary_data())


func update(_delta: float) -> void:
	if Input.is_action_just_pressed("next_day"):
		Ledger.settle_and_advance()
		fsm.transition_to(&"Working")
