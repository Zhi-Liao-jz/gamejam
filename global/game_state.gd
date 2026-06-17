extends Node
## 全局游戏状态 + 配置常量（autoload 名: Game）
## Demo 阶段数值都写死在这里，正式版再考虑配置表。

# ---------- 配置（先写死） ----------
const DAY_LENGTH: float = 30.0  # 抽完一根烟需要的秒数（= 一天长度）
const BASE_WAGE: int = 100  # 每天基础工资
const BANKRUPT_LINE: int = 0  # 预计存款低于此值即破产（对应文档"工资为负"的累计语义）
const MAX_MONKEYS: int = 3  # 同时在场猴子数上限（2 设备下 2-3 只即"顾此失彼"，再多无目标可抢只糊声音）

# ---------- 装备（数据驱动；加装备只往表加一行）----------
# ⚠ 装备 id 已入存档(Savegame.equipments)：一经发布只增不改不复用，否则旧档静默错位。
const EQUIP_SKATES := 1  # 轮滑鞋
const EQUIP_ALARM := 2  # 警报器
const EQUIP_LOCK := 3  # 加固锁
const EQUIPMENT := {
	EQUIP_SKATES: {"name": "轮滑鞋", "price": 80, "desc": "移动速度 +40%，救火往返更快"},
	EQUIP_ALARM: {"name": "警报器", "price": 120, "desc": "亭内显示哪台设备出事 + 致命倒计时"},
	EQUIP_LOCK: {"name": "加固锁", "price": 100, "desc": "猴子捣乱蓄力 +0.8s，救火窗口更宽"},
}

# ---------- 评分档位（降序遍历取首个 wage>=min）----------
const RATINGS := [
	{"min": 90, "title": "优秀保安"},
	{"min": 40, "title": "凑合干"},
	{"min": -2147483648, "title": "公司要找你谈谈"},
]

# ---------- 运行时状态 ----------
var day: int = 1
var money: int = 0
var smoke_progress: float = 0.0  # 0..1，仅在亭内推进
var player_in_booth: bool = false
var today_repair_cost: int = 0
var today_loss: float = 0.0
var owned_equipment: Array[int] = []  # 已购装备 id；跨天保留(reset_day 不清)，形状同 Savegame.equipments


func _ready() -> void:
	_setup_input()
	Savegame.inti_save()  # 队友：创建/加载存档，设 Savegame.current
	load_from_save()  # 把存档回灌到运行时状态
	Config.initialize(get_tree())  # 队友：加载并应用配置(音量)


# ---------- 存档接线（适配队友 Savegame：now_day↔day / money / equipments↔owned_equipment）----------
## 从存档回灌运行时状态（启动时调）。过滤 EQUIPMENT 表里不存在的装备 id（防旧档/改表后加载崩）。
func load_from_save() -> void:
	var s := Savegame.current
	if s == null:
		return
	day = s.now_day
	money = s.money
	owned_equipment.clear()
	for id: int in s.equipments:
		if EQUIPMENT.has(id):  # 健壮性：跳过未知 id
			owned_equipment.append(id)


## 把运行时进度写回存档并落盘（推进天 / 买装备后调）。
func sync_to_save() -> void:
	var s := Savegame.current
	if s == null:
		return
	s.now_day = day
	s.money = money
	s.equipments = owned_equipment.duplicate()  # duplicate 防别名共享
	s.save_to_file()


## 开新游戏：删旧档、建新默认档、运行时状态归零（菜单"新游戏"调，之后切到主场景）。
func reset_new_game() -> void:
	if Savegame.current:
		Savegame.current.delete()  # 删旧档文件
	Savegame.inti_save()  # 文件已删 → 建新默认档并设 current
	load_from_save()  # 回灌默认值(day=1/money=0/equipments=[])到运行时
	reset_day()  # 清局内瞬态(smoke/loss/repair)


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


# ---------- 失败 / 通关判定（纯函数，集中在 Game）----------
## 是否有设备彻底损坏（致命）—— 任一设备 is_fatal()。
func has_fatal_fault() -> bool:
	for node: Node in get_tree().get_nodes_in_group("devices"):
		var dev := node as BaseDevice
		if dev and dev.is_fatal():
			return true
	return false


## 结算后的预计存款 = 当前存款 + 当天工资（工资含损失/维修费扣除）。
func projected_money() -> int:
	return money + compute_wage()


## 是否资不抵债（破产）。
func is_bankrupt() -> bool:
	return projected_money() < BANKRUPT_LINE


# ---------- 装备查询 / 购买（单向 pull：各系统只读这里，Game 不反向 push 改它们）----------
func has_equipment(id: int) -> bool:
	return owned_equipment.has(id)


func can_buy(id: int) -> bool:
	return not has_equipment(id) and money >= int(EQUIPMENT[id]["price"])


func buy_equipment(id: int) -> bool:
	if not can_buy(id):
		return false
	money -= int(EQUIPMENT[id]["price"])
	owned_equipment.append(id)
	sync_to_save()  # 买装备即落盘
	return true


## 装备派生修正值（集中一处，player/monkey 只读结果、不见 id 与系数）
func equip_speed_mult() -> float:
	return 1.4 if has_equipment(EQUIP_SKATES) else 1.0


func equip_tamper_bonus() -> float:
	return 0.8 if has_equipment(EQUIP_LOCK) else 0.0  # 加法，穿过 maxf(0.5) 封底


## 按当天工资评分（降序取首个 wage>=min）
func rate_wage(w: int) -> String:
	for r in RATINGS:
		if w >= int(r["min"]):
			return String(r["title"])
	return ""


## 当天该有几只猴子（难度曲线：每 2 天 +1 只，封顶 MAX_MONKEYS）
func monkey_count_today() -> int:
	return clampi(1 + (day - 1) / 2, 1, MAX_MONKEYS)


## 结算入账并进入下一天（结算规则集中在 Game，状态机只负责转场）
func settle_and_advance(earned: int) -> void:
	money += earned
	day += 1
	sync_to_save()  # 通关推进即落盘


# ---------- 启动时注册键位（避免手改 project.godot 的 InputMap） ----------
func _setup_input() -> void:
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("interact", [KEY_E, KEY_SPACE])
	_bind("retry", [KEY_R])
	_bind("next_day", [KEY_N, KEY_ENTER])


func _bind(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
