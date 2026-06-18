class_name Hand
extends Node2D
## 玩家的手：点击拿起 / 放下产品，跨房间携带。
## 九宫格玩法没有走动的角色，"手" = 光标 + 当前持有物（持有时跟随鼠标）。

var _held: Product = null

@onready var room_manager := get_node("../RoomManager") as RoomManager


func _process(_delta: float) -> void:
	if _held:
		_held.global_position = get_global_mouse_position()


func _unhandled_input(event: InputEvent) -> void:
	if not Ledger.working_active:
		return
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	if _held:
		_drop_or_deliver()
	else:
		_pick_up()
	get_viewport().set_input_as_handled()  # 已处理的左键不再向下传播


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
	EventBus.push_event("hand_changed", [true, _color_name(product.color_key)])


func _drop_or_deliver() -> void:
	var room := room_manager.current_room_node()
	if room == null:
		return
	if room.is_delivery():
		if room.color_key == _held.color_key:
			Ledger.deliver(_held.value)
			SoundManager.play("boop")
			_held.queue_free()
			_clear_held()
		# 颜色不符：保持持有，玩家自己换交货点（P1 不罚分）
		return
	# 非交货点房间：把产品放进当前房间
	room.add_product(_held, room.contents.to_local(get_global_mouse_position()))
	_clear_held()


func _clear_held() -> void:
	_held = null
	EventBus.push_event("hand_changed", [false, ""])


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
