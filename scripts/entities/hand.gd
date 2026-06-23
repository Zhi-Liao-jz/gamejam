class_name Hand
extends Node2D
## 玩家的手：点击拿起 / 放下产品，跨房间携带。
## 九宫格玩法没有走动的角色，"手" = 光标 + 当前持有物（持有时跟随鼠标）。

const SELECT_SHOCK_TRAP_ACTION: StringName = &"select_shock_trap"
const SELECT_NET_ACTION: StringName = &"select_net"

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
	if _try_select_equipment(event):
		get_viewport().set_input_as_handled()
		return
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var pos := get_global_mouse_position()
	if _try_use_selected_equipment(pos):
		get_viewport().set_input_as_handled()
		return
	# 点击优先级：赶猴子 > 重开面板 > 出口按钮 > 加热台 > 重置自爆 > 开发电机面板 > 拿放产品
	if (
		_try_shoo_monkey(pos)
		or _try_open_panel(pos)
		or _try_spawn_from_exit(pos)
		or _try_toggle_heater(pos)
		or _try_reset_self_destruct(pos)
		or _try_open_generator_panel(pos)
	):
		get_viewport().set_input_as_handled()
		return
	if _held:
		_drop_or_deliver()
	else:
		_pick_up()
	get_viewport().set_input_as_handled()  # 已处理的左键不再向下传播


func _try_select_equipment(event: InputEvent) -> bool:
	if event.is_action_pressed(SELECT_SHOCK_TRAP_ACTION):
		return Game.toggle_equipment(Game.EQUIPMENT_SHOCK_TRAP)
	if event.is_action_pressed(SELECT_NET_ACTION):
		return Game.toggle_equipment(Game.EQUIPMENT_NET)
	return false


func _try_use_selected_equipment(world_pos: Vector2) -> bool:
	match Game.selected_equipment:
		Game.EQUIPMENT_SHOCK_TRAP:
			return _try_install_shock_trap(world_pos)
		Game.EQUIPMENT_NET:
			return _try_capture_monkey(world_pos)
		_:
			return false


## 选中电击陷阱后，点击当前房间任意猴子可交互设备安装。
func _try_install_shock_trap(world_pos: Vector2) -> bool:
	var device := _device_at_current_room(world_pos)
	if device == null:
		return false
	if not device.can_install_shock_trap():
		return false
	if not Game.consume_equipment(Game.EQUIPMENT_SHOCK_TRAP):
		return false
	if not device.install_shock_trap():
		return false
	Game.select_equipment(Game.EQUIPMENT_NONE)
	SoundManager.play("boop")
	return true


## 选中捕网后，点击当前房间猴子，使其暂停行动。
func _try_capture_monkey(world_pos: Vector2) -> bool:
	var monkey := _monkey_at_current_room(world_pos)
	if monkey == null:
		return false
	if not Game.consume_equipment(Game.EQUIPMENT_NET):
		return false
	monkey.capture(Game.equipment_effect_duration(Game.EQUIPMENT_NET))
	Game.select_equipment(Game.EQUIPMENT_NONE)
	SoundManager.play("boop")
	return true


## 点掉当前监控房间里的猴子 → 驱赶；命中返回 true。
func _try_shoo_monkey(world_pos: Vector2) -> bool:
	var monkey := _monkey_at_current_room(world_pos)
	if monkey != null:
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
	return panel.start_action(ControlPanel.ACTION_OPEN, BaseDevice.ACTOR_PLAYER, self)


## 点击产品出口面板按钮 → 生成一个产品；失败也消费这次点击，避免误拿面板下的产品。
func _try_spawn_from_exit(world_pos: Vector2) -> bool:
	var room := room_manager.current_room_node()
	if room == null or room.role != &"product_exit":
		return false
	if not room.has_panel() or not room.control_panel.global_rect().has_point(world_pos):
		return false
	if product_exit != null:
		product_exit.start_action(ProductExit.ACTION_SPAWN, BaseDevice.ACTOR_PLAYER, self)
	return true


## 点击加热台控制区：玩家按当前状态循环切换 关闭 / 正常 / 过热。
func _try_toggle_heater(world_pos: Vector2) -> bool:
	var room := room_manager.current_room_node()
	if room == null or room.role != &"heater":
		return false
	var heater := _heater_at_current_room(world_pos)
	if heater == null:
		return false
	var action_id := heater.next_player_action()
	if action_id == &"":
		return true
	heater.start_action(action_id, BaseDevice.ACTOR_PLAYER, self)
	return true


## 在中央房间点击自爆开关（罩被开 / 倒计时中）→ 重置；命中返回 true。
func _try_reset_self_destruct(world_pos: Vector2) -> bool:
	var sd := room_manager.self_destruct
	if sd == null or room_manager.current_room != sd.room_id:
		return false
	if not sd.is_resettable() or not sd.global_rect().has_point(world_pos):
		return false
	return sd.start_action(SelfDestruct.ACTION_RESET, BaseDevice.ACTOR_PLAYER, self)


## 在右下房间点击发电机 → 弹出发电机面板（调参在面板内进行）；命中返回 true。
func _try_open_generator_panel(world_pos: Vector2) -> bool:
	var gen := room_manager.power
	if gen == null or room_manager.current_room != gen.room_id:
		return false
	if not gen.global_rect().has_point(world_pos):
		return false
	EventBus.push_event("open_generator_panel")
	return true


func _heater_at_current_room(world_pos: Vector2) -> Heater:
	for device: BaseDevice in room_manager.devices_in_room(room_manager.current_room):
		var heater := device as Heater
		if heater != null and _device_contains_point(heater, world_pos):
			return heater
	return null


func _device_at_current_room(world_pos: Vector2) -> BaseDevice:
	for device: BaseDevice in room_manager.devices_in_room(room_manager.current_room):
		if not device.can_monkey_interact:
			continue
		if _device_contains_point(device, world_pos):
			return device
	return null


func _device_contains_point(device: BaseDevice, world_pos: Vector2) -> bool:
	if device.has_method("global_rect"):
		var rect: Rect2 = device.call("global_rect")
		return rect.has_point(world_pos)
	return false


func _monkey_at_current_room(world_pos: Vector2) -> GridMonkey:
	var current := room_manager.current_room
	for node: Node in get_tree().get_nodes_in_group("grid_monkeys"):
		var monkey := node as GridMonkey
		if monkey and monkey.current_room == current and monkey.global_rect().has_point(world_pos):
			return monkey
	return null


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
