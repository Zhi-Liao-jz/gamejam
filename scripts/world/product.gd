class_name Product
extends Node2D
## 待搬运的产品：有颜色，需送到同色交货点。部分产品是"生料"，需先在加热台加工才能交货（P4）。

const SIZE := Vector2(60.0, 60.0)
const HEAT_TIME := 3.0  # 生料加热到熟所需秒数
const BURN_TIME := 3.0  # 变熟后仍留在加热台、再过这么久就烧焦报废

var color_key: StringName = &""  # 颜色键：red / blue / green（与交货点房间匹配）
var tint := Color.WHITE
var value: int = 0
var current_room: int = -1
var requires_heat: bool = false  # 是否生料（需加热才能交货）
var heated: bool = false  # 是否已加热到熟
var burned: bool = false  # 是否已烧焦（报废，永不可交货）
var heat_progress: float = 0.0  # 在加热台累计受热时间


## 写入产品的颜色、价值、是否生料。
func setup(key: StringName, color: Color, product_value: int, raw: bool = false) -> void:
	color_key = key
	tint = color
	value = product_value
	requires_heat = raw
	queue_redraw()


## 产品在世界坐标里的包围盒（用于点击命中检测）。
func global_rect() -> Rect2:
	return Rect2(global_position - SIZE * 0.5, SIZE)


## 是否可交货：未烧焦，且（无需加热 或 已加热）。
func is_deliverable() -> bool:
	return not burned and (not requires_heat or heated)


## 由加热台逐帧推进受热：到点变熟，再过头则烧焦。返回状态是否刚发生变化。
func advance_heat(delta: float) -> bool:
	if not requires_heat or burned:
		return false
	heat_progress += delta
	var changed := false
	if not heated and heat_progress >= HEAT_TIME:
		heated = true
		changed = true
	elif heated and heat_progress >= HEAT_TIME + BURN_TIME:
		burned = true
		changed = true
	queue_redraw()
	return changed


func _draw() -> void:
	var rect := Rect2(-SIZE * 0.5, SIZE)
	if burned:
		draw_rect(rect, Color(0.15, 0.13, 0.12))  # 焦黑
		draw_rect(rect, Color(0.05, 0.05, 0.05), false, 3.0)
		return
	if requires_heat and not heated:
		draw_rect(rect, tint.darkened(0.45))  # 生料：暗色
		draw_rect(rect, Color(0.40, 0.80, 1.0), false, 3.0)  # 青边 = 需加热
		_draw_progress(heat_progress / HEAT_TIME, Color(1.0, 0.6, 0.1))
		return
	draw_rect(rect, tint)
	if heated:
		draw_rect(rect, Color(1.0, 0.55, 0.10), false, 3.0)  # 橙边 = 已熟可交货
		var burn_frac := clampf((heat_progress - HEAT_TIME) / BURN_TIME, 0.0, 1.0)
		if burn_frac > 0.0:
			_draw_progress(burn_frac, Color(0.95, 0.20, 0.10))  # 烧焦倒计时：快拿走
	else:
		draw_rect(rect, tint.lightened(0.3), false, 3.0)


## 在产品下方画一条进度条（frac 0..1）。
func _draw_progress(frac: float, color: Color) -> void:
	var bar_bg := Rect2(Vector2(-SIZE.x * 0.5, SIZE.y * 0.5 + 4.0), Vector2(SIZE.x, 8.0))
	draw_rect(bar_bg, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bar_bg.position, Vector2(SIZE.x * clampf(frac, 0.0, 1.0), 8.0)), color)
