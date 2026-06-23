class_name WiringView
extends Control
## 接线盒可视化控件（可复用）：画左右两列连接点 + 当前线缆。
## 交互模式（绑定一个 WiringBox）：拖拽一个点到对侧点 = 连接；拖到空白 = 断开起点的线。
## 只读模式（box 为空，用 ro_count / ro_connections）：仅显示，供手册 SubViewport 截图用。

const MARGIN := 34.0
const POINT_RADIUS := 9.0
const HIT_RADIUS := 20.0
const POINT_COLOR := Color(0.85, 0.88, 0.92)
const CABLE_COLOR := Color(0.30, 0.85, 0.75)
const PREVIEW_COLOR := Color(0.95, 0.82, 0.30)

var box: WiringBox = null  # 交互模式绑定的接线盒；为空则只读
var ro_count: int = 0  # 只读模式的点数
var ro_connections: Dictionary = {}  # 只读模式的连接

var _drag_active: bool = false
var _drag_side: int = 0  # 0=左 1=右
var _drag_index: int = -1
var _drag_mouse: Vector2 = Vector2.ZERO


func _process(_delta: float) -> void:
	if box != null:
		queue_redraw()  # 交互模式实时反映猴子改动


func _gui_input(event: InputEvent) -> void:
	if box == null:
		return
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed:
			_begin_drag(click.position)
		else:
			_end_drag(click.position)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _drag_active:
		_drag_mouse = motion.position
		queue_redraw()


func _count() -> int:
	return box.point_count if box != null else ro_count


func _conns() -> Dictionary:
	return box.connections if box != null else ro_connections


## 第 side 列（0左/1右）第 index 个点的控件局部坐标。
func point_pos(side: int, index: int) -> Vector2:
	var count := _count()
	var x := MARGIN if side == 0 else size.x - MARGIN
	var usable := size.y - MARGIN * 2.0
	var y := MARGIN
	if count > 1:
		y += usable * float(index) / float(count - 1)
	else:
		y += usable * 0.5
	return Vector2(x, y)


func _begin_drag(pos: Vector2) -> void:
	var hit := _point_at(pos)
	if hit.x < 0:
		return
	_drag_active = true
	_drag_side = int(hit.x)
	_drag_index = int(hit.y)
	_drag_mouse = pos
	queue_redraw()


func _end_drag(pos: Vector2) -> void:
	if not _drag_active:
		return
	var target := _point_at(pos)
	var done := false
	if target.x >= 0 and int(target.x) != _drag_side:
		var left := _drag_index if _drag_side == 0 else int(target.y)
		var right := int(target.y) if _drag_side == 0 else _drag_index
		box.connect_points(left, right)
		done = true
	if not done:
		# 拖到空白：若起点是已连接的左点，或起点右点被某左点连着 → 断开。
		if _drag_side == 0:
			box.disconnect_left(_drag_index)
		else:
			for l: int in box.connections.keys():
				if box.connections[l] == _drag_index:
					box.disconnect_left(l)
	_drag_active = false
	_drag_index = -1
	queue_redraw()


## 命中哪个点：返回 Vector2(side, index)，未命中返回 Vector2(-1,-1)。
func _point_at(pos: Vector2) -> Vector2:
	var count := _count()
	for side: int in 2:
		for i: int in count:
			if pos.distance_to(point_pos(side, i)) <= HIT_RADIUS:
				return Vector2(side, i)
	return Vector2(-1, -1)


func _draw() -> void:
	var count := _count()
	var conns := _conns()
	for left: int in conns.keys():
		var right: int = conns[left]
		draw_line(point_pos(0, left), point_pos(1, right), CABLE_COLOR, 3.0)
	if _drag_active and _drag_index >= 0:
		draw_line(point_pos(_drag_side, _drag_index), _drag_mouse, PREVIEW_COLOR, 2.0)
	for side: int in 2:
		for i: int in count:
			draw_circle(point_pos(side, i), POINT_RADIUS, POINT_COLOR)
			draw_circle(point_pos(side, i), POINT_RADIUS, CABLE_COLOR.darkened(0.2), false, 2.0)
