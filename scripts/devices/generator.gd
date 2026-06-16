extends BaseDevice
## 发电机：被篡改后稳定度持续下降，归零即故障；修复后恢复满稳定度。
## Demo 阶段是"一键修好"，第 4 步会改成按手册调参数到安全区间。

const SAFE_MIN: float = 60.0  # 手册里的安全下限（第4步用）

@export var drift_per_second: float = 25.0  # 被篡改时每秒掉的稳定度

var stability: float = 100.0  # 0..100


func _setup() -> void:
	device_name = "发电机"
	repair_fee = 15
	loss_per_second = 8


func _device_process(delta: float) -> void:
	if state == DeviceState.TAMPERED:
		stability -= drift_per_second * delta
		if stability <= 0.0:
			stability = 0.0
			_set_state(DeviceState.FAULT)


func _on_repair() -> void:
	stability = 100.0


func inspect() -> Dictionary:
	var d := super.inspect()
	d["stability"] = stability
	d["safe_min"] = SAFE_MIN
	return d


func _draw() -> void:
	var col := Color(0.3, 0.8, 0.3)  # 正常: 绿
	match state:
		DeviceState.TAMPERED:
			col = Color(0.9, 0.7, 0.2)  # 被篡改: 黄
		DeviceState.FAULT, DeviceState.SEVERE:
			col = Color(0.9, 0.2, 0.2)  # 故障: 红
	draw_rect(Rect2(-24, -24, 48, 48), col)
