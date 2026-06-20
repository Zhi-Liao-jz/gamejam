extends Node
## 全局游戏状态（autoload 名: Game）：跨天进度、存档接线和输入注册。

const MAX_MONKEYS: int = 3  # 同时在场猴子数上限（2 设备下 2-3 只即"顾此失彼"，再多无目标可抢只糊声音）

var day: int = 1
var money: int = 0
var selected_day: int = 1
var highest_unlocked_day: int = 1
var cleared_days: Array[int] = []
var best_profit_by_day: Dictionary[int, int] = {}
var owned_equipment: Array[int] = []  # 正式装备系统接入前保持为空，避免旧装备 id 污染新系统。


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


## 把运行时进度写回存档并落盘（推进天 / 买装备后调）。
func sync_to_save() -> void:
	var s := Savegame.current
	if s == null:
		return
	s.now_day = day
	s.selected_day = selected_day
	s.highest_unlocked_day = highest_unlocked_day
	s.cleared_days = cleared_days.duplicate()
	s.best_profit_by_day = best_profit_by_day.duplicate()
	s.money = money
	s.equipments = owned_equipment.duplicate()  # duplicate 防别名共享
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
