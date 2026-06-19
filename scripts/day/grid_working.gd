extends BaseState
## 2.0 工作阶段：产品出口出货、玩家搬运交货；达成当天交货目标即进入结算。


func enter(_msg: Dictionary = {}) -> void:
	Ledger.reset_day()
	Ledger.working_active = true
	# P2：控制面板各自订阅 work_started 自动复位为开、猴子生成器据此清场重建；当前无金钱损失项
	# （猴子的惩罚=关面板拖慢交货）。P3 接入自爆/设备维修费时，当天损失的重置在此并入。
	EventBus.push_event("hide_day_summary")
	EventBus.push_event("work_started")


func update(_delta: float) -> void:
	if Ledger.is_quota_met():
		fsm.transition_to(&"Settlement")
