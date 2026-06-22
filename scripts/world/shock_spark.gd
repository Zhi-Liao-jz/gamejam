class_name ShockSpark
extends Node2D
## 电击陷阱触发时的一次性火花特效：扩散的黄环 + 几道电花，约 0.45 秒后自毁。
## 由 BaseDevice._trigger_shock_trap 生成在设备视觉位置；仅当玩家正监控该房间时可见。

const LIFETIME := 0.45
const MAX_RADIUS := 46.0
const SPARK_COUNT := 6

var _t: float = 0.0


func _ready() -> void:
	z_index = 200  # 画在设备 / 产品 / 猴子之上


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var f := clampf(_t / LIFETIME, 0.0, 1.0)
	var radius := lerpf(8.0, MAX_RADIUS, f)
	var alpha := 1.0 - f
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(1.0, 0.95, 0.25, alpha), 3.0)
	draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 24, Color(0.6, 0.85, 1.0, alpha), 2.0)
	for i: int in range(SPARK_COUNT):
		var ang := TAU * float(i) / float(SPARK_COUNT)
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(dir * radius * 0.5, dir * radius, Color(1.0, 1.0, 0.55, alpha), 2.0)
