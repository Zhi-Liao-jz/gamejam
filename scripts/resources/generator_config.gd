class_name GeneratorConfig
extends Resource
## 发电机数值配置。燃料、开关等当天状态仍由 Generator 节点持有。

const MIN_VALID_LOAD: float = 25.0

@export var temp_divisor: float = 50.0
@export var temp_safe_min: float = 10.0
@export var temp_safe_max: float = 80.0
@export var tolerance: float = 5.0
@export var base_load: float = 30.0
@export var load_per_day: float = 6.0
@export var max_fuel_heat: float = 300.0
@export var fuel_add_rate: float = 160.0
@export var default_burn_rate: float = 0.6
@export var default_turbine_power: float = 0.5
@export var overload_fee: float = 1.0
@export var overheat_fee: float = 1.0
@export var shock_trap_unlock_day: int = 6


func load_for_day(day: int) -> float:
	return base_load + float(day - 1) * load_per_day
