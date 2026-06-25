class_name Product
extends Node2D
## 待搬运的产品：有颜色、成本和收益。部分产品是"生料"，需先在加热台加工才能交货。

const SIZE := Vector2(60.0, 60.0)
const NORMAL_HEAT_TIME := 10.0  # 正常加热加工完成所需秒数
const OVERHEAT_HEAT_TIME := 5.0  # 过热加热加工完成所需秒数
const OVERHEAT_BURN_TIME := 3.0  # 过热加工完成后继续停留多久会烧焦
const HEAT_RESULT_NONE: StringName = &""
const HEAT_RESULT_PROCESSED: StringName = &"processed"
const HEAT_RESULT_BURNED: StringName = &"burned"

var color_key: StringName = &""  # 颜色键：red / blue / green（与交货点房间匹配）
var tint := Color.WHITE
var cost: int = 0
var base_reward: int = 0
var is_processed: bool = false
var is_damaged: bool = false
var current_room: int = -1
var requires_heat: bool = false  # 是否生料（需加热才能交货）
var heated: bool = false  # 是否已加热到熟
var burned: bool = false  # 是否已烧焦（报废，永不可交货）
var heat_progress: float = 0.0  # 当前加工累计时间
var overheat_wait_time: float = 0.0  # 过热加工完成后的待取计时
var is_overheat_processing: bool = false  # 最近一次受热是否来自过热模式
var is_heat_active: bool = false  # 本帧是否被加热台推进
var is_on_heater_surface: bool = false  # 本帧是否位于加热台有效区域

var _was_heat_active: bool = false
var _was_on_heater_surface: bool = false

@onready var visual: TextureVisual = $Visual


func _process(_delta: float) -> void:
	var needs_redraw := false
	if is_heat_active:
		_was_heat_active = true
		is_heat_active = false
	elif _was_heat_active:
		_was_heat_active = false
		needs_redraw = true
	if is_on_heater_surface:
		_was_on_heater_surface = true
		is_on_heater_surface = false
	elif _was_on_heater_surface:
		_was_on_heater_surface = false
		needs_redraw = true
	if needs_redraw:
		_update_visual()
		queue_redraw()


## 写入产品的颜色、经济数值、是否生料。
func setup(
	key: StringName, color: Color, product_cost: int, product_reward: int, raw: bool = false
) -> void:
	color_key = key
	tint = color
	cost = product_cost
	base_reward = product_reward
	requires_heat = raw
	is_processed = not raw
	is_damaged = false
	heated = false
	burned = false
	heat_progress = 0.0
	overheat_wait_time = 0.0
	is_overheat_processing = false
	is_heat_active = false
	is_on_heater_surface = false
	_was_heat_active = false
	_was_on_heater_surface = false
	_update_visual()
	queue_redraw()


## 产品在世界坐标里的包围盒（用于点击命中检测）。
func global_rect() -> Rect2:
	return Rect2(global_position - SIZE * 0.5, SIZE)


## 是否可交货：未烧焦，且（无需加热 或 已加热）。
func is_deliverable() -> bool:
	return not is_damaged and (not requires_heat or is_processed)


func mark_on_heater_surface() -> void:
	is_on_heater_surface = true


## 由加热台逐帧推进受热。正常加工不会烧焦，过热加工完成后继续过热才会烧焦。
func advance_heat(delta: float, is_overheating: bool) -> StringName:
	if not requires_heat or burned:
		return HEAT_RESULT_NONE
	is_heat_active = true
	is_overheat_processing = is_overheating
	if is_processed:
		return _advance_processed_heat(delta, is_overheating)
	heat_progress += delta
	var target_time := OVERHEAT_HEAT_TIME if is_overheating else NORMAL_HEAT_TIME
	if heat_progress < target_time:
		_update_visual()
		queue_redraw()
		return HEAT_RESULT_NONE
	heated = true
	is_processed = true
	overheat_wait_time = 0.0
	_update_visual()
	queue_redraw()
	return HEAT_RESULT_PROCESSED


func _draw() -> void:
	if _has_visual_texture():
		return
	var rect := Rect2(-SIZE * 0.5, SIZE)
	if burned:
		draw_rect(rect, Color(0.15, 0.13, 0.12))  # 焦黑
		draw_rect(rect, Color(0.05, 0.05, 0.05), false, 3.0)
		return
	if requires_heat and not heated:
		draw_rect(rect, tint.darkened(0.45))  # 生料：暗色
		draw_rect(rect, Color(0.40, 0.80, 1.0), false, 3.0)  # 青边 = 需加热
		if heat_progress > 0.0 or _is_heat_visual_active() or _is_surface_visual_active():
			var progress_color := Color(0.55, 0.55, 0.50)
			if _is_heat_visual_active():
				progress_color = Color(1.0, 0.6, 0.1)
			_draw_progress(_heat_fraction(), progress_color)
		return
	draw_rect(rect, tint)
	if heated:
		draw_rect(rect, Color(1.0, 0.55, 0.10), false, 3.0)  # 橙边 = 已熟可交货
		var burn_frac := clampf(overheat_wait_time / OVERHEAT_BURN_TIME, 0.0, 1.0)
		if burn_frac > 0.0 and _is_heat_visual_active():
			_draw_progress(burn_frac, Color(0.95, 0.20, 0.10))  # 烧焦倒计时：快拿走
	else:
		draw_rect(rect, tint.lightened(0.3), false, 3.0)


## 在产品下方画一条进度条（frac 0..1）。
func _draw_progress(frac: float, color: Color) -> void:
	var bar_bg := Rect2(Vector2(-SIZE.x * 0.5, SIZE.y * 0.5 + 4.0), Vector2(SIZE.x, 8.0))
	draw_rect(bar_bg, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bar_bg.position, Vector2(SIZE.x * clampf(frac, 0.0, 1.0), 8.0)), color)


func _advance_processed_heat(delta: float, is_overheating: bool) -> StringName:
	if not is_overheating:
		_update_visual()
		queue_redraw()
		return HEAT_RESULT_NONE
	overheat_wait_time += delta
	if overheat_wait_time < OVERHEAT_BURN_TIME:
		_update_visual()
		queue_redraw()
		return HEAT_RESULT_NONE
	burned = true
	is_damaged = true
	_update_visual()
	queue_redraw()
	return HEAT_RESULT_BURNED


func _heat_fraction() -> float:
	var target_time := OVERHEAT_HEAT_TIME if is_overheat_processing else NORMAL_HEAT_TIME
	return heat_progress / target_time


func _is_heat_visual_active() -> bool:
	return is_heat_active or _was_heat_active


func _is_surface_visual_active() -> bool:
	return is_on_heater_surface or _was_on_heater_surface


func _visual_state() -> StringName:
	if burned:
		return &"burned"
	if requires_heat and not heated:
		return &"raw"
	if heated:
		return &"heated"
	return color_key


func _update_visual() -> void:
	if visual != null:
		visual.apply_state(_visual_state())


func _has_visual_texture() -> bool:
	return visual != null and visual.has_texture()
