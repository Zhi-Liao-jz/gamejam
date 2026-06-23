class_name Heater
extends BaseDevice
## 加热台（阶段5）：6 个水平激光发射器 + 3 个 45° 反射镜（各由垂直滑块控制高度）+ 3 个加热盘 + 总开关。
## 反射镜把水平激光向上反射到正上方加热盘；盘收 0/1/2 道激光 = 不加热 / 正常 / 过热。
## 激光从左向右，先被 x 较小的反射镜挡下并反射（遮挡规则）。玩家用弹出面板调开关与滑块，猴子随机乱调。
## 房间里 3 个加热盘对应 3 个产品槽位：放在某槽的产品按该盘状态加工（正常 10s / 过热 5s，过热熟后 3s 烧焦）。

const ACTION_M_RANDOMIZE: StringName = &"heater_randomize"
const EMITTER_COUNT := 6
const PLATE_COUNT := 3
const EMPTY_FACTOR := 2.0  # 发射器上方留 LaserGap * 2 空白
const SURFACE := Rect2(-200.0, -10.0, 400.0, 150.0)  # 产品摆放区（房间局部坐标）
const CONTROL_SIZE := Vector2(120.0, 52.0)
const CONTROL_OFFSET := Vector2(-150.0, -95.0)
const OFF_TINT := Color(0.35, 0.35, 0.32)
const NORMAL_TINT := Color(0.95, 0.55, 0.12)
const OVERHEAT_TINT := Color(1.0, 0.25, 0.10)
const OFFLINE_TINT := Color(0.24, 0.24, 0.24)

var switch_on: bool = false
var mirror_heights: Array[float] = [0.5, 0.5, 0.5]  # 每个反射镜高度 0~1（1=最上=不反射）

var _room: Room = null


func _ready() -> void:
	_room = get_parent() as Room
	var owner_room_id := -1 if _room == null else _room.room_id
	setup_device(StringName("heater_%d" % owner_room_id), &"heater", owner_room_id)
	add_to_group("heater")
	EventBus.subscribe("work_started", _on_work_started)
	queue_redraw()


func _process(delta: float) -> void:
	if _room == null or not Ledger.working_active:
		return
	queue_redraw()
	var powered := Ledger.is_device_powered(&"heater")
	var counts := plate_counts()
	for product: Product in _products_on_surface():
		product.mark_on_heater_surface()
		if not powered:
			continue
		var plate := _plate_of(product)
		if plate < 0 or counts[plate] < 1:
			continue
		_handle_heat_result(product.advance_heat(delta, counts[plate] >= 2))


## 由 RoomManager 挂载（代码创建）。设备类型 &"heater"（猴子第5天解锁）。
func global_rect() -> Rect2:
	return Rect2(global_position + CONTROL_OFFSET - CONTROL_SIZE * 0.5, CONTROL_SIZE)


## 反射镜 / 激光几何（面板与本体共用，单一来源）。
func laser_gap() -> float:
	return HeaterTuning.laser_gap


func mirror_height_px() -> float:
	return HeaterTuning.laser_gap * HeaterTuning.mirror_factor


func emitter_top() -> float:
	return HeaterTuning.laser_gap * EMPTY_FACTOR


## 第 i 道激光（发射器）的 y（面板坐标）。
func emitter_y(i: int) -> float:
	return emitter_top() + i * HeaterTuning.laser_gap


## 反射镜上沿可移动到的最低 y（滑块到底时）。
func max_top() -> float:
	return emitter_top() + (EMITTER_COUNT - 1) * HeaterTuning.laser_gap - mirror_height_px()


## 反射镜 j 当前覆盖的上沿 y（滑块 1=最上→top=0=不反射）。
func mirror_top(j: int) -> float:
	return (1.0 - mirror_heights[j]) * max_top()


## 第 i 道激光首先命中的反射镜下标（按 x 从左到右遍历，遮挡规则）；未命中返回 -1。
func laser_target(i: int) -> int:
	var y := emitter_y(i)
	var h := mirror_height_px()
	for j: int in PLATE_COUNT:
		var top := mirror_top(j)
		if y >= top and y <= top + h:
			return j
	return -1


## 各加热盘收到的激光数（关机 / 停电 / 未启用时全 0）。
func plate_counts() -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	if not _active():
		return counts
	for i: int in EMITTER_COUNT:
		var j := laser_target(i)
		if j >= 0:
			counts[j] += 1
	return counts


## 是否有盘过热（供 HUD 提示）。
func has_overheat() -> bool:
	for c: int in plate_counts():
		if c >= 2:
			return true
	return false


## 是否有产品烧坏（供 HUD 提示 + 小地图黑框）。
func has_burned() -> bool:
	for product: Product in _products_on_surface():
		if product.requires_heat and product.is_damaged:
			return true
	return false


func is_offline() -> bool:
	return not Ledger.is_device_powered(&"heater")


func toggle_switch() -> void:
	switch_on = not switch_on
	queue_redraw()


func set_mirror(index: int, value: float) -> void:
	if index < 0 or index >= PLATE_COUNT:
		return
	mirror_heights[index] = clampf(value, 0.0, 1.0)
	queue_redraw()


## 指定世界坐标是否允许放下产品：每个加热盘最多容纳 1 个产品。
func can_place_product_at(world_pos: Vector2, ignored_product: Product = null) -> bool:
	var plate := _plate_at_local(to_local(world_pos))
	if plate < 0:
		return true
	for product: Product in _products_on_surface():
		if product == ignored_product:
			continue
		if _plate_of(product) == plate:
			return false
	return true


## 猴子一次操作 = 随机化总开关 + 全部反射镜（见 _perform_action）。玩家走面板不走此接口。
func available_actions(actor: StringName) -> Array[StringName]:
	if actor != ACTOR_MONKEY or not Ledger.working_active or not _is_unlocked():
		return []
	return [ACTION_M_RANDOMIZE]


func device_state() -> StringName:
	if is_offline():
		return &"offline"
	if not switch_on:
		return &"off"
	if has_overheat():
		return &"overheat"
	for c: int in plate_counts():
		if c >= 1:
			return &"normal"
	return &"idle"


func can_install_shock_trap() -> bool:
	return Game.day >= 5 and super.can_install_shock_trap()


func _perform_action(action_id: StringName, _actor: StringName, _actor_node: Node) -> bool:
	if action_id != ACTION_M_RANDOMIZE:
		return false
	# 猴子一次操作 = 对每个参数各自等概率随机取值（总开关 + 3 个反射镜高度），无修复偏向。
	switch_on = randf() < 0.5
	for j: int in PLATE_COUNT:
		mirror_heights[j] = randf()
	queue_redraw()
	return true


func _on_work_started() -> void:
	switch_on = false
	mirror_heights = [0.5, 0.5, 0.5]
	queue_redraw()


func _active() -> bool:
	return switch_on and _is_unlocked() and Ledger.is_device_powered(&"heater")


func _is_unlocked() -> bool:
	return Game.day >= 4


## 第 j 个加热盘对应的房间局部矩形（把摆放区横向三等分）。
func _plate_rect(j: int) -> Rect2:
	var w := SURFACE.size.x / float(PLATE_COUNT)
	return Rect2(SURFACE.position.x + j * w, SURFACE.position.y, w, SURFACE.size.y)


## 产品落在哪个加热盘上；不在任何盘上返回 -1。
func _plate_of(product: Product) -> int:
	return _plate_at_local(to_local(product.global_position))


func _plate_at_local(local: Vector2) -> int:
	for j: int in PLATE_COUNT:
		if _plate_rect(j).has_point(local):
			return j
	return -1


func _products_on_surface() -> Array[Product]:
	var result: Array[Product] = []
	if _room == null:
		return result
	for product: Product in _room.products():
		if SURFACE.has_point(to_local(product.global_position)):
			result.append(product)
	return result


func _handle_heat_result(result: StringName) -> void:
	match result:
		Product.HEAT_RESULT_PROCESSED:
			SoundManager.play("boop")
		Product.HEAT_RESULT_BURNED:
			SoundManager.play("alarm")


func _draw() -> void:
	var counts := plate_counts()
	var offline := is_offline()
	for j: int in PLATE_COUNT:
		var rect := _plate_rect(j)
		var color := _plate_color(counts[j], offline)
		draw_rect(rect, color.darkened(0.3))
		draw_rect(rect, color, false, 3.0)
	var control_rect := Rect2(CONTROL_OFFSET - CONTROL_SIZE * 0.5, CONTROL_SIZE)
	var ctrl_color := OFFLINE_TINT if offline else (NORMAL_TINT if switch_on else OFF_TINT)
	draw_rect(control_rect, ctrl_color.darkened(0.45))
	draw_rect(control_rect, ctrl_color.lightened(0.2), false, 2.0)
	draw_shock_trap_marker(CONTROL_OFFSET + Vector2(CONTROL_SIZE.x * 0.34, -CONTROL_SIZE.y * 0.28))


func _plate_color(count: int, offline: bool) -> Color:
	if offline:
		return OFFLINE_TINT
	if count >= 2:
		return OVERHEAT_TINT
	if count >= 1:
		return NORMAL_TINT
	return OFF_TINT
