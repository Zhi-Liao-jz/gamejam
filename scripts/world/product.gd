class_name Product
extends Node2D
## 待搬运的产品：有颜色，需送到同色交货点。P1 用色块表示。

const SIZE := Vector2(60.0, 60.0)

var color_key: StringName = &""  # 颜色键：red / blue / green（与交货点房间匹配）
var tint := Color.WHITE
var value: int = 0
var current_room: int = -1


## 写入产品的颜色与价值。
func setup(key: StringName, color: Color, product_value: int) -> void:
	color_key = key
	tint = color
	value = product_value
	queue_redraw()


## 产品在世界坐标里的包围盒（用于点击命中检测）。
func global_rect() -> Rect2:
	return Rect2(global_position - SIZE * 0.5, SIZE)


func _draw() -> void:
	var rect := Rect2(-SIZE * 0.5, SIZE)
	draw_rect(rect, tint)
	draw_rect(rect, tint.lightened(0.3), false, 3.0)
