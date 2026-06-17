extends BaseState
## 商店状态：通关结算后、进下一天前逛店买装备。
## 开店时【不推 hide_settlement】——否则会把结算面板/设备复位/猴子重生提前触发，还会关掉商店面板。
## 按 [N] 关店并进 Working，此时 Working.enter 才推 hide_settlement（顺序天然正确）。


func enter(_msg: Dictionary = {}) -> void:
	EventBus.push_event("open_shop")


func update(_delta: float) -> void:
	if Input.is_action_just_pressed("next_day"):
		EventBus.push_event("close_shop")
		fsm.transition_to(&"Working")
