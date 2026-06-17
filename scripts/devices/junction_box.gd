class_name JunctionBox
extends BaseDevice
## 接线盒：N 个左端子各接到一个右端子，玩家在面板里把连线接回正确组合。
## 错接越多越严重；短路(两根接同一处)= 严重故障(致命预备)。猴子捣乱 = 拔线/交换/乱接。
## 照搬发电机的子类模板，只新增重写点，不动 BaseDevice 框架（验证设备统一接口）。

const N := 4  # 4 个左端子 A/B/C/D ↔ 4 个右端子 0/1/2/3
const TARGET: Array[int] = [0, 1, 2, 3]  # 正确组合 = 恒等直连（写死，所有天相同）
const SHORT_CIRCUIT_FINE := 15  # 每次跌入短路的一次性罚款（计入今日维修费）

var wiring: Array[int] = [0, 1, 2, 3]  # wiring[i] = 第 i 个左端子当前接到的右端子编号
var _was_short := false


func _setup() -> void:
	device_name = "接线盒"
	repair_fee = 0  # 无一键修，只能在面板里接对
	loss_per_second = 10  # 略高于发电机 8，短路更烧钱
	_reset_to_day()
	EventBus.subscribe("hide_settlement", _reset_to_day)


# ---------- 派生量（现算不缓存）----------
func wrong_count() -> int:
	var c := 0
	for i in N:
		if wiring[i] != TARGET[i]:
			c += 1
	return c


## 是否短路：有两根线接到同一个右端子（连线非排列）。
func is_short() -> bool:
	var counts: Array[int] = []
	counts.resize(N)
	counts.fill(0)
	for i in N:
		counts[wiring[i]] += 1
	for c in counts:
		if c >= 2:
			return true
	return false


# ---------- 失配 → 离散状态（复用 _set_state，零改框架）----------
## 短路或错接≥3根 → SEVERE（致命预备，倒计时）；这是让失败判定真正可达的关键。
func sync_state() -> void:
	# 短路罚款：本帧短路且上帧不短路 = 上升沿，罚一次（玩家误接或猴子乱接都算）
	var short_now := is_short()
	if short_now and not _was_short:
		Game.add_repair_cost(SHORT_CIRCUIT_FINE)
	_was_short = short_now

	if short_now or wrong_count() >= 3:
		_set_state(DeviceState.SEVERE)
	elif wrong_count() == 0:
		_set_state(DeviceState.NORMAL)
	elif wrong_count() <= 1:
		_set_state(DeviceState.TAMPERED)
	else:  # 错接 2 根
		_set_state(DeviceState.FAULT)


func _device_process(delta: float) -> void:
	sync_state()
	# TAMPERED 区间子类自扣；FAULT/SEVERE 交 base._process 扣（互斥，零双扣）
	if state == DeviceState.TAMPERED:
		Game.add_loss(loss_per_second * delta)


# ---------- 按当天复位到正确连线（开局/新一天正常）----------
func _reset_to_day() -> void:
	wiring = TARGET.duplicate()
	_was_short = false
	_severe_time = 0.0
	sync_state()


# ---------- 猴子捣乱：随机拔线/交换/乱接（复用统一接口）----------
func _on_tamper() -> void:
	# 1/3 乱接短路 → 严重故障(致命倒计时)；2/3 交换两根线 → 故障(持续扣费)。
	# 形成"致命 vs 仅烧钱"的梯度（注：恒等基线上单根改线必撞车=短路，故只用交换做非短路的错接）。
	if randi() % 3 == 0:
		var i := randi() % N
		var k := (i + 1 + randi() % (N - 1)) % N
		wiring[i] = wiring[k]  # 把某根接到另一根已占用的右端子 = 短路
	else:
		_swap_two()
	sync_state()
	# 兜底：随机恰好仍正确 → 强制交换一对，保证越界，猴子不空跑
	if state == DeviceState.NORMAL:
		_swap_two()
		sync_state()


func _swap_two() -> void:
	var i := randi() % N
	var j := (i + 1 + randi() % (N - 1)) % N
	var tmp := wiring[i]
	wiring[i] = wiring[j]
	wiring[j] = tmp


# ---------- 靠近交互：打开连线面板 ----------
func interact() -> void:
	EventBus.push_event("open_junction_panel", [self])


func inspect() -> Dictionary:
	var d := super.inspect()
	d["wiring"] = wiring
	d["wrong"] = wrong_count()
	d["short"] = is_short()
	return d


func _sound_key_for(s: DeviceState) -> String:
	match s:
		DeviceState.TAMPERED:
			return "jbox_tampered"
		DeviceState.FAULT, DeviceState.SEVERE:
			return "jbox_fault"
	return ""


func _draw() -> void:
	var col := Color(0.3, 0.5, 0.9)  # 正常: 蓝（区别于发电机绿）
	match state:
		DeviceState.TAMPERED:
			col = Color(0.95, 0.6, 0.2)  # 被篡改: 橙
		DeviceState.FAULT, DeviceState.SEVERE:
			col = Color(0.9, 0.2, 0.2)  # 故障/严重: 红
	draw_rect(Rect2(-24, -24, 48, 48), col)
