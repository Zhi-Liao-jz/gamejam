class_name BaseDevice
extends Area2D
## 所有设备的统一接口。子类只重写行为，不改框架。
## 这是 Demo 阶段最值得"做对"的抽象：以后加接线盒/油箱只是新增子类。

enum DeviceState { NORMAL, TAMPERED, FAULT, SEVERE }  # 正常 / 被篡改 / 故障 / 严重故障

@export var device_name: String = "设备"
@export var repair_fee: int = 10  # 每次修复的费用
@export var loss_per_second: int = 5  # 故障时每秒造成的损失

var state: DeviceState = DeviceState.NORMAL


func _ready() -> void:
	add_to_group("devices")
	_setup()
	set_process(false)  # NORMAL 时无需逐帧；状态变化时再开（见 _set_state）


func _process(delta: float) -> void:
	_device_process(delta)
	if state == DeviceState.FAULT or state == DeviceState.SEVERE:
		Game.add_loss(loss_per_second * delta)


# ---------- 子类重写点 ----------
func _setup() -> void:
	pass


func _device_process(_delta: float) -> void:
	pass


func _on_tamper() -> void:
	pass


func _on_repair() -> void:
	pass


# ---------- 统一接口 ----------
## 猴子篡改
func tamper() -> void:
	if state == DeviceState.NORMAL:
		_set_state(DeviceState.TAMPERED)
		_on_tamper()


## 玩家检查 —— 返回给手册/UI 的信息
func inspect() -> Dictionary:
	return {"name": device_name, "state": state}


## 玩家修复
func repair() -> void:
	if state == DeviceState.NORMAL:
		return
	Game.add_repair_cost(repair_fee)
	_on_repair()
	_set_state(DeviceState.NORMAL)


func state_text() -> String:
	match state:
		DeviceState.NORMAL:
			return "正常"
		DeviceState.TAMPERED:
			return "被篡改"
		DeviceState.FAULT:
			return "故障"
		DeviceState.SEVERE:
			return "严重故障"
	return "?"


func _set_state(s: DeviceState) -> void:
	if s == state:
		return
	state = s
	set_process(s != DeviceState.NORMAL)  # 仅异常态需要逐帧推进/累损
	queue_redraw()  # 外观只依赖 state，状态变化时重绘一次即可
	# 通过事件总线广播，以后声音/UI 订阅它（"会发出声音提示"）
	EventBus.push_event("device_state_changed", [self, s])
