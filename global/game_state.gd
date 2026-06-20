extends Node
## 全局游戏状态（autoload 名: Game）：跨天进度、存档接线和输入注册。

const EQUIPMENT_SHOCK_TRAP: int = 1
const EQUIPMENT_NET: int = 2
const EQUIPMENT_NONE: int = 0
const MAX_MONKEYS: int = 3  # 同时在场猴子数上限（2 设备下 2-3 只即"顾此失彼"，再多无目标可抢只糊声音）
const EQUIPMENT_DATA: Dictionary[int, Dictionary] = {
	EQUIPMENT_SHOCK_TRAP:
	{
		"id": EQUIPMENT_SHOCK_TRAP,
		"key": &"shock_trap",
		"name": "电击陷阱",
		"price": 120,
		"max_count": 3,
		"refill_interval": 30.0,
		"description": "安装到设备上，猴子操作时触发打断。",
	},
	EQUIPMENT_NET:
	{
		"id": EQUIPMENT_NET,
		"key": &"net",
		"name": "捕网",
		"price": 100,
		"max_count": 3,
		"refill_interval": 30.0,
		"effect_duration": 10.0,
		"description": "对当前房间猴子使用，使其 10 秒不能行动。",
	},
}

var day: int = 1
var money: int = 0
var selected_day: int = 1
var highest_unlocked_day: int = 1
var cleared_days: Array[int] = []
var best_profit_by_day: Dictionary[int, int] = {}
var owned_equipment: Array[int] = []
var equipment_counts: Dictionary[int, int] = {}
var equipment_refill_left: Dictionary[int, float] = {}
var selected_equipment: int = EQUIPMENT_NONE


func _ready() -> void:
	_setup_input()
	Savegame.inti_save()  # 队友：创建/加载存档，设 Savegame.current
	load_from_save()  # 把存档回灌到运行时状态
	Config.initialize(get_tree())  # 队友：加载并应用配置(音量)


## 从存档回灌运行时状态（启动时调）。
func load_from_save() -> void:
	var s := Savegame.current
	if s == null:
		return
	var loaded_selected_day := s.selected_day
	if s.save_version < 2:
		loaded_selected_day = s.now_day
	highest_unlocked_day = maxi(
		maxi(s.highest_unlocked_day, s.now_day), maxi(loaded_selected_day, 1)
	)
	selected_day = clampi(loaded_selected_day, 1, highest_unlocked_day)
	day = selected_day
	money = s.money
	cleared_days = _sanitize_day_list(s.cleared_days)
	best_profit_by_day = _sanitize_profit_map(s.best_profit_by_day)
	owned_equipment.clear()
	if s.save_version >= 3:
		owned_equipment = _sanitize_equipment_list(s.equipments)
	reset_runtime_equipment()


## 把运行时进度写回存档并落盘（推进天 / 买装备后调）。
func sync_to_save() -> void:
	var s := Savegame.current
	if s == null:
		return
	s.now_day = day
	s.selected_day = selected_day
	s.highest_unlocked_day = highest_unlocked_day
	s.cleared_days = _copy_int_array(cleared_days)
	s.best_profit_by_day = best_profit_by_day.duplicate()
	s.money = money
	s.equipments = _copy_int_array(owned_equipment)  # 显式类型拷贝，避免退成普通 Array
	s.save_to_file()


## 开新游戏：删旧档、建新默认档、运行时状态归零（菜单"新游戏"调，之后切到主场景）。
func reset_new_game() -> void:
	if Savegame.current:
		Savegame.current.delete()  # 删旧档文件
	Savegame.inti_save()  # 文件已删 → 建新默认档并设 current
	load_from_save()  # 回灌默认值(day=1/money=0/equipments=[])到运行时


## 从选关界面进入指定天数。未解锁天数会被夹到可玩范围内。
func start_day(target_day: int) -> void:
	selected_day = clampi(target_day, 1, highest_unlocked_day)
	day = selected_day
	sync_to_save()


## 完成指定天数：入账、记录通关 / 最高利润，并解锁下一天。
func complete_day(completed_day: int, profit: int) -> void:
	money += profit
	if not cleared_days.has(completed_day):
		cleared_days.append(completed_day)
		cleared_days.sort()
	best_profit_by_day[completed_day] = maxi(best_profit_by_day.get(completed_day, profit), profit)
	highest_unlocked_day = maxi(highest_unlocked_day, completed_day + 1)
	start_day(mini(completed_day + 1, highest_unlocked_day))


## 当天该有几只猴子（难度曲线：每 2 天 +1 只，封顶 MAX_MONKEYS）
func monkey_count_today() -> int:
	return clampi(1 + (day - 1) / 2, 1, MAX_MONKEYS)


## 尝试购买长期装备。成功会扣钱、保存，并初始化运行时数量。
func buy_equipment(equipment_id: int) -> bool:
	if not EQUIPMENT_DATA.has(equipment_id):
		return false
	if owned_equipment.has(equipment_id):
		return false
	var price := equipment_price(equipment_id)
	if money < price:
		return false
	money -= price
	owned_equipment.append(equipment_id)
	owned_equipment.sort()
	_reset_one_runtime_equipment(equipment_id)
	sync_to_save()
	return true


func has_equipment(equipment_id: int) -> bool:
	return owned_equipment.has(equipment_id)


func equipment_name(equipment_id: int) -> String:
	return String(_equipment_data(equipment_id).get("name", "未知装备"))


func equipment_price(equipment_id: int) -> int:
	return int(_equipment_data(equipment_id).get("price", 0))


func equipment_description(equipment_id: int) -> String:
	return String(_equipment_data(equipment_id).get("description", ""))


func equipment_max_count(equipment_id: int) -> int:
	return int(_equipment_data(equipment_id).get("max_count", 0))


## 进入工作日时重置当天装备数量和补给倒计时。
func reset_runtime_equipment() -> void:
	equipment_counts.clear()
	equipment_refill_left.clear()
	selected_equipment = EQUIPMENT_NONE
	for equipment_id: int in owned_equipment:
		_reset_one_runtime_equipment(equipment_id)


## 推进装备自动补给。返回状态是否发生变化。
func tick_runtime_equipment(delta: float) -> bool:
	var changed := false
	for equipment_id: int in owned_equipment:
		changed = _tick_one_equipment(equipment_id, delta) or changed
	return changed


func equipment_count(equipment_id: int) -> int:
	return int(equipment_counts.get(equipment_id, 0))


func equipment_refill_remaining(equipment_id: int) -> float:
	return float(equipment_refill_left.get(equipment_id, 0.0))


func equipment_effect_duration(equipment_id: int) -> float:
	return float(_equipment_data(equipment_id).get("effect_duration", 0.0))


func select_equipment(equipment_id: int) -> bool:
	if equipment_id == EQUIPMENT_NONE:
		selected_equipment = EQUIPMENT_NONE
		return true
	if not has_equipment(equipment_id):
		return false
	selected_equipment = equipment_id
	return true


func toggle_equipment(equipment_id: int) -> bool:
	if selected_equipment == equipment_id:
		selected_equipment = EQUIPMENT_NONE
		return true
	return select_equipment(equipment_id)


func consume_equipment(equipment_id: int) -> bool:
	if not has_equipment(equipment_id):
		return false
	var current := equipment_count(equipment_id)
	if current <= 0:
		return false
	equipment_counts[equipment_id] = current - 1
	if equipment_refill_remaining(equipment_id) <= 0.0:
		equipment_refill_left[equipment_id] = _equipment_refill_interval(equipment_id)
	return true


# ---------- 启动时注册键位（避免手改 project.godot 的 InputMap） ----------
func _setup_input() -> void:
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("interact", [KEY_E, KEY_SPACE])
	_bind("retry", [KEY_R])
	_bind("next_day", [KEY_N, KEY_ENTER])
	_bind("select_shock_trap", [KEY_Z])
	_bind("select_net", [KEY_X])


func _bind(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _sanitize_day_list(days: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for value: int in days:
		if value >= 1 and not result.has(value):
			result.append(value)
	result.sort()
	return result


func _sanitize_profit_map(source: Dictionary) -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	for key: Variant in source.keys():
		var day_key := int(key)
		if day_key < 1:
			continue
		result[day_key] = int(source[key])
	return result


func _sanitize_equipment_list(equipments: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for equipment_id: int in equipments:
		if EQUIPMENT_DATA.has(equipment_id) and not result.has(equipment_id):
			result.append(equipment_id)
	result.sort()
	return result


func _copy_int_array(source: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for value: int in source:
		result.append(value)
	return result


func _reset_one_runtime_equipment(equipment_id: int) -> void:
	var max_count := equipment_max_count(equipment_id)
	equipment_counts[equipment_id] = max_count
	equipment_refill_left[equipment_id] = _equipment_refill_interval(equipment_id)


func _tick_one_equipment(equipment_id: int, delta: float) -> bool:
	var max_count := equipment_max_count(equipment_id)
	var current := equipment_count(equipment_id)
	if current >= max_count:
		equipment_refill_left[equipment_id] = _equipment_refill_interval(equipment_id)
		return false
	var remaining := maxf(0.0, equipment_refill_remaining(equipment_id) - delta)
	if remaining > 0.0:
		equipment_refill_left[equipment_id] = remaining
		return false
	equipment_counts[equipment_id] = mini(current + 1, max_count)
	equipment_refill_left[equipment_id] = _equipment_refill_interval(equipment_id)
	return true


func _equipment_refill_interval(equipment_id: int) -> float:
	return float(_equipment_data(equipment_id).get("refill_interval", 0.0))


func _equipment_data(equipment_id: int) -> Dictionary:
	return EQUIPMENT_DATA.get(equipment_id, {})
