extends BaseState
## 2.0 结算阶段：展示当天交货量与收入，玩家选择 进入商店(选关) 或 直接进入下一天。
## 两个出口都会先入账（Ledger.settle_and_advance → 利润进总钱、解锁下一天、落盘）。
## [N] 仍等价于"进入下一天"；商店复用选关界面（day_select 内已有商店视图）。

const DAY_SELECT_SCENE := "res://scenes/menu/day_select.tscn"


func enter(_msg: Dictionary = {}) -> void:
	Ledger.working_active = false
	EventBus.push_event("day_summary", Ledger.summary_data())
	EventBus.subscribe("settlement_next", _on_next)
	EventBus.subscribe("settlement_shop", _on_shop)


func exit() -> void:
	EventBus.unsubscribe("settlement_next", _on_next)
	EventBus.unsubscribe("settlement_shop", _on_shop)


func update(_delta: float) -> void:
	if Input.is_action_just_pressed("next_day"):
		_on_next()


## 入账并直接开始下一天（留在本场景）。
func _on_next() -> void:
	Ledger.settle_and_advance()
	fsm.transition_to(&"Working")


## 入账后回到选关界面（那里可进商店买装备、再选下一天）。
func _on_shop() -> void:
	EventBus.unsubscribe("settlement_next", _on_next)
	EventBus.unsubscribe("settlement_shop", _on_shop)
	Ledger.settle_and_advance()
	get_tree().change_scene_to_file(DAY_SELECT_SCENE)
