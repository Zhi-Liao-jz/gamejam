class_name Generator
extends BaseDevice
## 发电机：玩家在控制台面板里调 燃烧速率/涡轮功率/燃料/开关，让"电量输出"匹配"负载"。
## 失配越界 → 持续维护费（扣 today_loss）；调回容差内自动恢复正常。机制见交互面板。
##   温度   = 燃料热值 × 燃烧速率 × (1 − 涡轮功率)
##   效率   = min(温度 / 50, 涡轮功率)
##   电量输出 = 燃料热值 × 燃烧速率 × 效率（关机则为 0）

const TOLERANCE := 4.0  # 容差：|输出-负载| < 此值即正常
const SEVERE_GAP := 20.0  # 失配 ≥ 此值升严重故障(FAULT)
const TEMP_K := 50.0  # 效率分母（用户给定公式常数）
const FUEL_MAX := 100.0  # 燃料热值上限
const FUEL_REFILL_PER_SEC := 80.0  # 长按加燃料速率
const LOAD_MAX := 60.0  # 负载上限：须 < 全控制空间最大输出(≈66.7) 并留容差，保证每天恒有解

# 控制量（面板与猴子读写同一组成员 = 单一数据源）
var on: bool = true
var fuel_heat: float = 100.0
var burn_rate: float = 0.5
var turbine: float = 0.5
var load: float = 20.0  # 负载，只读显示，按天写死


func _setup() -> void:
	device_name = "发电机"
	repair_fee = 0  # 无一键修；损失只来自失配期间持续扣费
	loss_per_second = 8
	_reset_to_day()
	# 新一天 / 重试开始时（Working.enter 推 hide_settlement）复位到当天清解，避免失配带入新一天
	EventBus.subscribe("hide_settlement", _reset_to_day)


# ---------- 派生量（现算不缓存，面板/状态/扣费读同一真值）----------
func temp() -> float:
	return fuel_heat * burn_rate * (1.0 - turbine)


func eff() -> float:
	return minf(temp() / TEMP_K, turbine)


func output() -> float:
	return 0.0 if not on else fuel_heat * burn_rate * eff()


func mismatch() -> float:
	return absf(output() - load)


# ---------- 按当天负载复位到一个清解（开局 / 新一天正常，不误报）----------
func _reset_to_day() -> void:
	load = minf(20.0 + 5.0 * (Game.day - 1), LOAD_MAX)
	on = true
	fuel_heat = FUEL_MAX
	burn_rate = 1.0
	# burn=1、fuel=100 时 输出=100*min(2*(1-turbine), turbine)；turbine≤2/3 时 = 100*turbine。
	# 故 turbine=load/100 即精确清解（load 是 5 的倍数→落在 0.05 网格上无残差）。
	turbine = clampf(snappedf(load / 100.0, 0.05), 0.0, 1.0)
	sync_state()
	assert(mismatch() < TOLERANCE, "每天清解开局必须为 NORMAL")


# ---------- 失配 → 离散状态（驱动既有声音 / HUD / 经济，零改框架）----------
func sync_state() -> void:
	var m := mismatch()
	if m < TOLERANCE:
		_set_state(DeviceState.NORMAL)
	elif m < SEVERE_GAP:
		_set_state(DeviceState.TAMPERED)
	else:
		_set_state(DeviceState.FAULT)


func _device_process(delta: float) -> void:
	sync_state()
	# TAMPERED 区间子类自扣；FAULT 区间交 base._process 扣（互斥同费率，零双扣）
	if state == DeviceState.TAMPERED:
		Game.add_loss(loss_per_second * delta)


# ---------- 猴子捣乱：随机拨乱一个控制量制造失配（复用统一接口）----------
func _on_tamper() -> void:
	# 清解基线是 burn=1.0，故"拨低燃烧"才有破坏力
	match randi() % 4:
		0:
			burn_rate = randf_range(0.0, 0.35)  # 燃烧拨低
		1:
			turbine = randf_range(0.85, 1.0)  # 涡轮推到高位（输出骤降）
		2:
			fuel_heat = 0.0  # 清空燃料
		_:
			on = false  # 关机
	sync_state()
	# 兜底：某些 load/分支的随机扰动可能恰好落进容差=无效捣乱，强制关机保证越界
	if state == DeviceState.NORMAL:
		on = false
		sync_state()


# ---------- 靠近交互：打开控制台面板（替代一键修）----------
func interact() -> void:
	EventBus.push_event("open_generator_panel", [self])


func inspect() -> Dictionary:
	var d := super.inspect()
	d["on"] = on
	d["fuel_heat"] = fuel_heat
	d["burn_rate"] = burn_rate
	d["turbine"] = turbine
	d["temp"] = temp()
	d["eff"] = eff()
	d["output"] = output()
	d["load"] = load
	d["mismatch"] = mismatch()
	return d


func _sound_key_for(s: DeviceState) -> String:
	match s:
		DeviceState.TAMPERED:
			return "gen_tampered"
		DeviceState.FAULT, DeviceState.SEVERE:
			return "gen_fault"
	return ""


func _draw() -> void:
	var col := Color(0.3, 0.8, 0.3)  # 正常: 绿
	match state:
		DeviceState.TAMPERED:
			col = Color(0.9, 0.7, 0.2)  # 被篡改: 黄
		DeviceState.FAULT, DeviceState.SEVERE:
			col = Color(0.9, 0.2, 0.2)  # 故障: 红
	draw_rect(Rect2(-24, -24, 48, 48), col)
