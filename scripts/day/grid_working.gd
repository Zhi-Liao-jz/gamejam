extends BaseState
## 2.0 工作阶段：产品出口出货、玩家搬运交货；固定时长结束后进入结算。


func enter(_msg: Dictionary = {}) -> void:
	Ledger.reset_day()
	Game.reset_runtime_equipment()
	Ledger.working_active = true
	# P2：控制面板各自订阅 work_started 自动复位为开、猴子生成器据此清场重建；当前无金钱损失项
	# （猴子的惩罚=关面板拖慢交货）。正式迁移时当天利润 / 连击 / 损坏统一放 Ledger。
	EventBus.push_event("hide_day_summary")
	EventBus.push_event("work_started")


func update(delta: float) -> void:
	Game.tick_runtime_equipment(delta)
	if Ledger.day_failed:
		fsm.transition_to(&"Failed", {"reason": "self_destruct"})  # 自爆引爆 → 当天失败（优先于结算）
	elif Ledger.tick(delta):
		# 时间到：达成今日交货目标才算通关进结算，否则当天失败、重试本日（不解锁、不入账）
		if Ledger.is_quota_met():
			fsm.transition_to(&"Settlement")
		else:
			fsm.transition_to(&"Failed", {"reason": "quota"})
