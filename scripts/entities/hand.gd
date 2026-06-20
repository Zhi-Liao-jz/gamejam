class_name Hand
extends Node2D
## 玩家的手：点击拿起 / 放下产品，跨房间携带。
## 九宫格玩法没有走动的角色，"手" = 光标 + 当前持有物（持有时跟随鼠标）。

var _held: Product = null

@onready var room_manager := get_node("../RoomManager") as RoomManager
@onready var product_exit := get_node("../ProductExit") as ProductExit


func _ready() -> void:
	EventBus.subscribe("work_started", _on_work_started)


func _process(_delta: float) -> void:
	if _held:
		_held.global_position = get_global_mouse_position()


func _unhandled_input(event: InputEvent) -> void:
	if not Ledger.working_active:
		return
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var pos := get_global_mouse_position()
	# 点击优先级：赶猴子 > 重开面板 > 出口按钮 > 重置自爆 > 修发电机 > 拿放产品
	if (
		_try_shoo_monkey(pos)
		or _try_open_panel(pos)
		or _try_spawn_from_exit(pos)
		or _try_reset_self_destruct(pos)
		or _try_repair_power(pos)
	):
		get_viewport().set_input_as_handled()
		return
	if _held:
		_drop_or_deliver()
	else:
		_pick_up()
	get_viewport().set_input_as_handled()  # 已处理的左键不再向下传播


## 点掉当前监控房间里的猴子 → 驱赶；命中返回 true。
func _try_shoo_monkey(world_pos: Vector2) -> bool:
	var current := room_manager.current_room
	for node: Node in get_tree().get_nodes_in_group("grid_monkeys"):
		var monkey := node as GridMonkey
		if monkey and monkey.current_room == current and monkey.global_rect().has_point(world_pos):
			monkey.shoo()
			return true
	return false


## 点击当前房间里"关闭的面板" → 重开；命中返回 true。
func _try_open_panel(world_pos: Vector2) -> bool:
	var room := room_manager.current_room_node()
	if room == null:
		return false
	var panel := room.panel_at(world_pos)
	if panel == null:
		return false
	panel.open()
	return true


## 点击产品出口面板按钮 → 生成一个产品；失败也消费这次点击，避免误拿面板下的产品。
func _try_spawn_from_exit(world_pos: Vector2) -> bool:
	var room := room_manager.current_room_node()
	if room == null or room.role != &"product_exit":
		return false
	if not room.has_panel() or not room.control_panel.global_rect().has_point(world_pos):
		return false
	if product_exit != null:
		product_exit.try_spawn_product()
	return true


## 在中央房间点击自爆开关（罩被开 / 倒计时中）→ 重置；命中返回 true。
func _try_reset_self_destruct(world_pos: Vector2) -> bool:
	var sd := room_manager.self_destruct
	if sd == null or room_manager.current_room != sd.room_id:
		return false
	if not sd.is_resettable() or not sd.global_rect().has_point(world_pos):
		return false
	sd.player_reset()
	return true


## 在右下房间点击发电机（停电时）→ 修复恢复供电；命中返回 true。
func _try_repair_power(world_pos: Vector2) -> bool:
	var pw := room_manager.power
	if pw == null or room_manager.current_room != pw.room_id:
		return false
	if not pw.is_repairable() or not pw.global_rect().has_point(world_pos):
		return false
	pw.repair()
	return true


func _pick_up() -> void:
	var room := room_manager.current_room_node()
	if room == null:
		return
	var product := room.product_at(get_global_mouse_position())
	if product == null:
		return
	product.reparent(self)
	product.global_position = get_global_mouse_position()
	product.z_index = 100
	_held = product
	EventBus.push_event("hand_changed", [true, _held_label(product)])


func _drop_or_deliver() -> void:
	var room := room_manager.current_room_node()
	if room == null:
		return
	if room.is_delivery():
		if not room.panel_open():
			return  # 面板被猴子关闭：放上去也不结算，保持持有，先去点面板重开
		if room.color_key == _held.color_key and _held.is_deliverable():
			Ledger.deliver(_held)
			SoundManager.play("boop")
		else:
			Ledger.record_wrong_delivery(_held, _held.is_damaged)
			SoundManager.play("alarm")
		_held.queue_free()
		_clear_held()
		return
	# 非交货点房间：把产品放进当前房间
	room.add_product(_held, room.contents.to_local(get_global_mouse_position()))
	_clear_held()


func _clear_held() -> void:
	_held = null
	EventBus.push_event("hand_changed", [false, ""])


## 新一天开始（结算 / 失败 / 调试跳天后）：清掉手里残留的上一天产品，保持手净。
func _on_work_started() -> void:
	if _held:
		_held.queue_free()
	_clear_held()


func _color_name(key: StringName) -> String:
	match key:
		&"red":
			return "红色产品"
		&"blue":
			return "蓝色产品"
		&"green":
			return "绿色产品"
		_:
			return "产品"


## 手持标签带加工状态：生料 / 已熟 / 焦（供 HUD 提示是否要先去加热）。
func _held_label(product: Product) -> String:
	var base := _color_name(product.color_key)
	if product.burned:
		return base + "·焦"
	if product.requires_heat and not product.heated:
		return base + "·生"
	if product.heated:
		return base + "·熟"
	return base
