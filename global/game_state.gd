extends Node
## 全局游戏状态 + 配置常量（autoload 名: Game）
## Demo 阶段数值都写死在这里，正式版再考虑配置表。

# ---------- 配置（先写死） ----------
const DAY_LENGTH: float = 30.0  # 抽完一根烟需要的秒数（= 一天长度）
const BASE_WAGE: int = 100  # 每天基础工资

# ---------- 运行时状态 ----------
var day: int = 1
var money: int = 0
var smoke_progress: float = 0.0  # 0..1，仅在亭内推进
var player_in_booth: bool = false
var today_repair_cost: int = 0
var today_loss: float = 0.0


func _ready() -> void:
	_setup_input()


func reset_day() -> void:
	smoke_progress = 0.0
	today_repair_cost = 0
	today_loss = 0.0
	# 注意：player_in_booth 由保安亭 Area2D 的进出信号维护，这里不重置


func add_repair_cost(v: int) -> void:
	today_repair_cost += v


func add_loss(v: float) -> void:
	today_loss += v


func compute_wage() -> int:
	return BASE_WAGE - today_repair_cost - int(today_loss)


## 结算入账并进入下一天（结算规则集中在 Game，状态机只负责转场）
func settle_and_advance(earned: int) -> void:
	money += earned
	day += 1


# ---------- 启动时注册键位（避免手改 project.godot 的 InputMap） ----------
func _setup_input() -> void:
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("interact", [KEY_E, KEY_SPACE])
	_bind("tamper_debug", [KEY_M])
	_bind("retry", [KEY_R])
	_bind("next_day", [KEY_N, KEY_ENTER])


func _bind(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
