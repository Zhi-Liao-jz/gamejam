class_name EconomyConfig
extends Resource
## 工作日经济配置。运行时账本状态仍由 Ledger 持有。

@export var day_duration: float = 300.0
@export var base_quota: int = 5
@export var quota_per_day: int = 2
@export var min_product_cost: int = 5
@export var max_product_cost: int = 15
@export var min_base_reward: int = 15
@export var max_base_reward: int = 40
@export var combo_tip_step: int = 2
@export var combo_tip_cap: int = 20


func quota_for_day(day: int) -> int:
	return base_quota + (day - 1) * quota_per_day
