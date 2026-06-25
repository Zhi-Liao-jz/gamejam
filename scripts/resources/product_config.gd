class_name ProductConfig
extends Resource
## 产品生成与加工配置。产品实例状态仍由 Product 节点持有。

@export var max_waiting: int = 4
@export var slot_per_row: int = 4
@export var slot_start_x: float = -180.0
@export var slot_spacing: float = 90.0
@export var raw_unlock_day: int = 4
@export_range(0.0, 1.0) var raw_chance: float = 0.4
@export var normal_heat_time: float = 10.0
@export var overheat_heat_time: float = 5.0
@export var overheat_burn_time: float = 3.0


func should_spawn_raw(day: int) -> bool:
	return day >= raw_unlock_day and randf() < raw_chance
