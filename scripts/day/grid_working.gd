extends BaseState
## 2.0 工作阶段：产品出口出货、玩家搬运交货；达成当天交货目标即进入结算。


func enter(_msg: Dictionary = {}) -> void:
	Ledger.reset_day()
	Ledger.working_active = true
	# P2 接入设备损坏/猴子后，当天维修费/损失的重置在此并入（届时决定并进 Ledger 还是沿用 Game.reset_day）
	EventBus.push_event("hide_day_summary")
	EventBus.push_event("work_started")


func update(_delta: float) -> void:
	if Ledger.is_quota_met():
		fsm.transition_to(&"Settlement")
