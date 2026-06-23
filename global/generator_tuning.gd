extends Node
## 发电机调参（autoload 名: GeneratorTuning）。集中存放发电机数值旋钮，
## 由调试面板（DebugGeneratorTuning, F2）即时修改。仅影响手感，不进存档；正式版保留默认值即可。

const MIN_VALID_LOAD: float = 25.0  # 开局自动配平的最低负载（低于此效率公式不再线性，见 generator.gd）

## 输出效率公式分母：效率 = min(温度 / temp_divisor, 涡轮功率)。
var temp_divisor: float = 50.0
## 温度安全下限：低于此 = 温度过低（仅警报，通常伴随输出不足）。
var temp_safe_min: float = 10.0
## 温度安全上限：高于此 = 温度过高，持续扣维护费。
var temp_safe_max: float = 80.0
## 容差：电量输出与负载允许的误差范围。
var tolerance: float = 5.0
## 第 1 天的负载（每关需要的电量）。
var base_load: float = 30.0
## 之后每天负载递增量。
var load_per_day: float = 6.0
## 燃料热值上限（长按添加 / 猴子乱加都受此限）。
var max_fuel_heat: float = 300.0
## 长按"添加燃料"时每秒增加的热值。
var fuel_add_rate: float = 160.0
## 每天开局的燃烧速率（0~1）。
var default_burn_rate: float = 0.6
## 每天开局的涡轮功率（0~1）。
var default_turbine_power: float = 0.5
## 输出过高时每秒维护费。
var overload_fee: float = 1.0
## 温度过高时每秒维护费。
var overheat_fee: float = 1.0


## 当前天数对应的负载。
func load_for_day(day: int) -> float:
	return base_load + float(day - 1) * load_per_day
