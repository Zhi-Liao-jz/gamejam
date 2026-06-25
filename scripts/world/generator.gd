class_name Generator
extends BaseDevice
## 发电机（阶段3 右下房间左半）：模拟燃料热值 / 燃烧速率 / 涡轮功率，按公式算温度与输出，
## 与当天负载比对判定是否供电（写入 Ledger.generator_powered）；输出过高 / 温度过高实时扣维护费。
## 玩家通过弹出面板（GeneratorPanel）调参；猴子通过 BaseDevice 动作把参数随机打乱。
## 数值默认见 GeneratorTuning（autoload），可由 F2 调试面板实时调整。

const ACTION_M_RANDOMIZE: StringName = &"gen_randomize"

const SIZE := Vector2(150.0, 150.0)  # 发电机命中盒 / 视觉外框（房间局部坐标，占房间左半）
const OFFSET := Vector2(-85.0, 8.0)
const POWERED_COLOR := Color(0.30, 0.85, 0.75)
const OFFLINE_COLOR := Color(0.95, 0.38, 0.12)

var switch_on: bool = true
var fuel_heat: float = 0.0
var burn_rate: float = 0.6
var turbine_power: float = 0.5

var _adding_fuel: bool = false  # 面板"添加燃料"按钮按住时为 true，逐帧加燃料

@onready var visual: TextureVisual = $Visual


func _ready() -> void:
	add_to_group("power")
	EventBus.subscribe("work_started", _on_work_started)
	_reset_to_default()
	_update_visual()


func _physics_process(delta: float) -> void:
	if _adding_fuel:
		add_fuel(GeneratorTuning.fuel_add_rate * delta)
	if not Ledger.working_active:
		return
	Ledger.generator_powered = is_powered()
	_apply_maintenance(delta)
	_update_visual()
	queue_redraw()


## 由 RoomManager 在挂载前写入归属房间（右下）。设备类型沿用 &"power"（猴子第6天解锁该类型）。
func setup(owner_room_id: int) -> void:
	setup_device(&"generator", &"power", owner_room_id)


## 世界坐标命中盒（玩家点击打开面板 / 安装电击陷阱用）。
func global_rect() -> Rect2:
	return Rect2(global_position + OFFSET - SIZE * 0.5, SIZE)


## 当前温度：关机为 0。温度 = 燃料热值 * 燃烧速率 * (1 - 涡轮功率)。
func temperature() -> float:
	if not switch_on:
		return 0.0
	return fuel_heat * burn_rate * (1.0 - turbine_power)


## 输出效率（0~1）：min(温度 / 分母, 涡轮功率)。
func efficiency() -> float:
	if not switch_on:
		return 0.0
	return minf(temperature() / GeneratorTuning.temp_divisor, turbine_power)


## 当前电量输出：关机为 0。电量输出 = 燃料热值 * 燃烧速率 * 输出效率。
func power_output() -> float:
	if not switch_on:
		return 0.0
	return fuel_heat * burn_rate * efficiency()


## 当前关卡负载（需要的电量）。注意：方法名不可叫 load，会与内置 load() 冲突。
func current_load() -> float:
	return GeneratorTuning.load_for_day(Game.day)


## 是否正常供电：开机且输出不低于"负载 - 容差"（输出过高仍算通电，只是扣维护费）。
func is_powered() -> bool:
	if not switch_on:
		return false
	return power_output() >= current_load() - GeneratorTuning.tolerance


## 供 HUD 小地图 / 警告判断是否停电。
func is_outage() -> bool:
	return not is_powered()


## 当前警报集合（供面板显示）。
func alarms() -> Array[StringName]:
	var result: Array[StringName] = []
	if not switch_on:
		return result
	var out := power_output()
	var lo := current_load() - GeneratorTuning.tolerance
	var hi := current_load() + GeneratorTuning.tolerance
	if out > hi:
		result.append(&"output_high")
	elif out < lo:
		result.append(&"output_low")
	if temperature() > GeneratorTuning.temp_safe_max:
		result.append(&"temp_high")
	elif temperature() < GeneratorTuning.temp_safe_min:
		result.append(&"temp_low")
	return result


## 供 HUD 顶部提示用的故障文案。
func fault_text() -> String:
	if not switch_on:
		return "发电机已关闭"
	if power_output() < current_load() - GeneratorTuning.tolerance:
		return "供电不足"
	return "供电正常"


func toggle_switch() -> void:
	switch_on = not switch_on
	_update_visual()
	queue_redraw()


func add_fuel(amount: float) -> void:
	fuel_heat = clampf(fuel_heat + amount, 0.0, GeneratorTuning.max_fuel_heat)


func clear_fuel() -> void:
	fuel_heat = 0.0


func set_burn_rate(value: float) -> void:
	burn_rate = clampf(value, 0.0, 1.0)


func set_turbine_power(value: float) -> void:
	turbine_power = clampf(value, 0.0, 1.0)


## 面板"添加燃料"按钮按下 / 抬起。
func set_adding_fuel(value: bool) -> void:
	_adding_fuel = value


## 猴子一次操作 = 随机化发电机全部参数（见 _perform_action）。玩家走面板不走此接口。
func available_actions(actor: StringName) -> Array[StringName]:
	if actor != ACTOR_MONKEY or not Ledger.working_active:
		return []
	return [ACTION_M_RANDOMIZE]


func device_state() -> StringName:
	if not switch_on:
		return &"off"
	if is_powered():
		return &"powered"
	return &"outage"


func can_install_shock_trap() -> bool:
	return Game.day >= 6 and super.can_install_shock_trap()


func _perform_action(action_id: StringName, _actor: StringName, _actor_node: Node) -> bool:
	if action_id != ACTION_M_RANDOMIZE:
		return false
	# 猴子一次操作 = 对每个参数各自等概率随机取值（开关 / 燃料热值 / 燃烧速率 / 涡轮功率），无修复偏向。
	switch_on = randf() < 0.5
	set_burn_rate(randf())
	set_turbine_power(randf())
	fuel_heat = randf() * GeneratorTuning.max_fuel_heat
	_update_visual()
	queue_redraw()
	return true


## 每天开局把发电机配平到"正常通电且温度安全"的默认状态。
func _on_work_started() -> void:
	_reset_to_default()
	_update_visual()
	queue_redraw()


## 默认参数 = GeneratorTuning 给定的燃烧速率 / 涡轮功率，并反解出使输出≈负载的燃料热值。
## 由于温度 = 燃料*燃烧*(1-涡轮) 且效率封顶在涡轮功率，配平后温度≈输出≈负载（负载需≥25）。
func _reset_to_default() -> void:
	switch_on = true
	burn_rate = GeneratorTuning.default_burn_rate
	turbine_power = GeneratorTuning.default_turbine_power
	var denom := burn_rate * turbine_power
	if denom <= 0.0:
		fuel_heat = 0.0
	else:
		fuel_heat = clampf(current_load() / denom, 0.0, GeneratorTuning.max_fuel_heat)


func _apply_maintenance(delta: float) -> void:
	if not switch_on:
		return
	var fee := 0.0
	if power_output() > current_load() + GeneratorTuning.tolerance:
		fee += GeneratorTuning.overload_fee
	if temperature() > GeneratorTuning.temp_safe_max:
		fee += GeneratorTuning.overheat_fee
	Ledger.charge_maintenance(fee * delta)


func _draw() -> void:
	if _has_visual_texture():
		return
	var rect := Rect2(OFFSET - SIZE * 0.5, SIZE)
	var accent := POWERED_COLOR if is_powered() else OFFLINE_COLOR
	if not switch_on:
		accent = Color(0.45, 0.45, 0.45)
	draw_rect(rect, Color(0.09, 0.14, 0.14))
	draw_rect(rect, accent, false, 3.0)
	draw_circle(OFFSET, 30.0, Color(0.12, 0.30, 0.30))
	draw_circle(OFFSET, 30.0, accent, false, 3.0)
	# 输出 / 负载条：底部一条，绿=输出，白线=负载位置。
	var bar := Rect2(OFFSET.x - 60.0, OFFSET.y + 48.0, 120.0, 12.0)
	draw_rect(bar, Color(0.06, 0.10, 0.10))
	var span := maxf(1.0, current_load() * 2.0)
	var fill_w := clampf(power_output() / span, 0.0, 1.0) * bar.size.x
	draw_rect(Rect2(bar.position, Vector2(fill_w, bar.size.y)), accent)
	var load_x := bar.position.x + clampf(current_load() / span, 0.0, 1.0) * bar.size.x
	draw_line(
		Vector2(load_x, bar.position.y),
		Vector2(load_x, bar.position.y + bar.size.y),
		Color.WHITE,
		2.0
	)
	draw_shock_trap_marker(OFFSET + Vector2(SIZE.x * 0.34, -SIZE.y * 0.4))


func _update_visual() -> void:
	if visual != null:
		visual.apply_state(device_state())


func _has_visual_texture() -> bool:
	return visual != null and visual.has_texture()
