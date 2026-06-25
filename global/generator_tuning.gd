extends Node
## 发电机调参（autoload 名: GeneratorTuning）。集中存放发电机数值旋钮，
## 由调试面板（DebugGeneratorTuning, F2）即时修改。当前作为 GameConfig.generator 的兼容代理。

const MIN_VALID_LOAD: float = 25.0  # 开局自动配平的最低负载（低于此效率公式不再线性，见 generator.gd）

## 输出效率公式分母：效率 = min(温度 / temp_divisor, 涡轮功率)。
var temp_divisor: float:
	get:
		return GameConfig.generator().temp_divisor
	set(value):
		GameConfig.generator().temp_divisor = value
## 温度安全下限：低于此 = 温度过低（仅警报，通常伴随输出不足）。
var temp_safe_min: float:
	get:
		return GameConfig.generator().temp_safe_min
	set(value):
		GameConfig.generator().temp_safe_min = value
## 温度安全上限：高于此 = 温度过高，持续扣维护费。
var temp_safe_max: float:
	get:
		return GameConfig.generator().temp_safe_max
	set(value):
		GameConfig.generator().temp_safe_max = value
## 容差：电量输出与负载允许的误差范围。
var tolerance: float:
	get:
		return GameConfig.generator().tolerance
	set(value):
		GameConfig.generator().tolerance = value
## 第 1 天的负载（每关需要的电量）。
var base_load: float:
	get:
		return GameConfig.generator().base_load
	set(value):
		GameConfig.generator().base_load = value
## 之后每天负载递增量。
var load_per_day: float:
	get:
		return GameConfig.generator().load_per_day
	set(value):
		GameConfig.generator().load_per_day = value
## 燃料热值上限（长按添加 / 猴子乱加都受此限）。
var max_fuel_heat: float:
	get:
		return GameConfig.generator().max_fuel_heat
	set(value):
		GameConfig.generator().max_fuel_heat = value
## 长按"添加燃料"时每秒增加的热值。
var fuel_add_rate: float:
	get:
		return GameConfig.generator().fuel_add_rate
	set(value):
		GameConfig.generator().fuel_add_rate = value
## 每天开局的燃烧速率（0~1）。
var default_burn_rate: float:
	get:
		return GameConfig.generator().default_burn_rate
	set(value):
		GameConfig.generator().default_burn_rate = value
## 每天开局的涡轮功率（0~1）。
var default_turbine_power: float:
	get:
		return GameConfig.generator().default_turbine_power
	set(value):
		GameConfig.generator().default_turbine_power = value
## 输出过高时每秒维护费。
var overload_fee: float:
	get:
		return GameConfig.generator().overload_fee
	set(value):
		GameConfig.generator().overload_fee = value
## 温度过高时每秒维护费。
var overheat_fee: float:
	get:
		return GameConfig.generator().overheat_fee
	set(value):
		GameConfig.generator().overheat_fee = value


## 当前天数对应的负载。
func load_for_day(day: int) -> float:
	return GameConfig.generator().load_for_day(day)
