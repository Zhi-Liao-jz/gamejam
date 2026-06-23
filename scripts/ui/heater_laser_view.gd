class_name HeaterLaserView
extends Control
## 加热台激光可视化（面板内）：画 6 个发射器、激光路径、3 个反射镜（窗口+45°）、3 个加热盘状态。
## 几何全部取自绑定的 Heater（单一来源），随开关 / 滑块 / 猴子改动实时刷新。

const EMIT_X := 28.0
const PLATE_Y := 10.0
const PLATE_H := 30.0
const PLATE_W := 70.0
const EMITTER_COLOR := Color(0.85, 0.88, 0.92)
const LASER_ON := Color(1.0, 0.32, 0.22)
const LASER_PASS := Color(0.55, 0.22, 0.18, 0.5)
const MIRROR_COLOR := Color(0.70, 0.85, 0.95)
const OFF_TINT := Color(0.35, 0.35, 0.32)
const NORMAL_TINT := Color(0.95, 0.55, 0.12)
const OVERHEAT_TINT := Color(1.0, 0.25, 0.10)

var heater: Heater = null


func _process(_delta: float) -> void:
	if heater != null:
		queue_redraw()


## 第 j 个反射镜 / 加热盘的水平中心 x。
func mirror_x(j: int) -> float:
	return 110.0 + j * 100.0


func _draw() -> void:
	if heater == null:
		return
	var counts := heater.plate_counts()
	var right_x := size.x - 10.0
	# 激光路径
	for i: int in Heater.EMITTER_COUNT:
		var y := heater.emitter_y(i)
		var target := heater.laser_target(i)
		draw_circle(Vector2(EMIT_X, y), 5.0, EMITTER_COLOR)
		if target < 0:
			draw_line(Vector2(EMIT_X, y), Vector2(right_x, y), LASER_PASS, 2.0)
			continue
		var mx := mirror_x(target)
		draw_line(Vector2(EMIT_X, y), Vector2(mx, y), LASER_ON, 2.5)
		draw_line(Vector2(mx, y), Vector2(mx, PLATE_Y + PLATE_H), LASER_ON, 2.5)
	# 反射镜（窗口 + 45° 斜线）与加热盘
	var h := heater.mirror_height_px()
	for j: int in Heater.PLATE_COUNT:
		var mx := mirror_x(j)
		var top := heater.mirror_top(j)
		draw_rect(Rect2(mx - 6.0, top, 12.0, h), Color(0.30, 0.45, 0.55, 0.35))
		draw_line(Vector2(mx - 8.0, top + h), Vector2(mx + 8.0, top), MIRROR_COLOR, 3.0)
		var plate_rect := Rect2(mx - PLATE_W * 0.5, PLATE_Y, PLATE_W, PLATE_H)
		var color := _plate_color(counts[j])
		draw_rect(plate_rect, color.darkened(0.3))
		draw_rect(plate_rect, color, false, 2.0)


func _plate_color(count: int) -> Color:
	if count >= 2:
		return OVERHEAT_TINT
	if count >= 1:
		return NORMAL_TINT
	return OFF_TINT
