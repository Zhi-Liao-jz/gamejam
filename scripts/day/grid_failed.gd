extends BaseState
## 2.0 当天失败（P3）：自爆未阻止 / 未达交货目标 → 本日作废、收入归零，按 [N] 重试本日（天数不变、不入账）。
## 失败原因经转入时的 msg.reason 传入（"self_destruct" / "quota"），供 HUD 区分提示文案。


func enter(msg: Dictionary = {}) -> void:
	Ledger.working_active = false
	var data := {
		"day": Game.day,
		"delivered": Ledger.delivered_today,
		"quota": Ledger.quota_today(),
		"reason": String(msg.get("reason", "self_destruct")),
	}
	EventBus.push_event("day_failed", data)


func update(_delta: float) -> void:
	if Input.is_action_just_pressed("next_day"):
		# 重试本日：转回 Working，其 enter 会 reset_day（清 day_failed/收入）+ work_started（复位面板/猴子/自爆）
		fsm.transition_to(&"Working")
