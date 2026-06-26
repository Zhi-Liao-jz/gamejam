class_name DeviceHighlighter
extends Node2D
## 玩家光标悬停高亮：每帧找"当前监控房间内、被光标命中"的设备，显示其选中框（SelectFrame）。
## 只在工作时段生效；切换房间 / 移开光标时自动取消上一个高亮。

var _room_manager: RoomManager = null
var _current: Node = null  # 当前高亮对象（BaseDevice 或 Product，都有 set_highlighted）


func _ready() -> void:
	_room_manager = get_tree().get_first_node_in_group("room_manager") as RoomManager


func _process(_delta: float) -> void:
	var target := _target_under_cursor()
	if target == _current:
		return
	if _current != null and is_instance_valid(_current):
		_current.call("set_highlighted", false)
	_current = target
	if _current != null:
		_current.call("set_highlighted", true)


## 当前监控房间里被光标命中的高亮对象：产品在前景优先，其次设备；没有则 null。
func _target_under_cursor() -> Node:
	if _room_manager == null or not Ledger.working_active:
		return null
	var pos := get_global_mouse_position()
	var room := _room_manager.current_room
	# 产品在最上层，优先高亮当前房间里光标命中的产品。
	var room_node := _room_manager.current_room_node()
	if room_node != null:
		var product := room_node.product_at(pos)
		if product != null:
			return product
	# 其次是房间里的设备。
	for node: Node in get_tree().get_nodes_in_group("devices"):
		var dev := node as BaseDevice
		if dev == null or dev.room_id != room:
			continue
		if not dev.has_method("global_rect"):
			continue
		var rect: Rect2 = dev.call("global_rect")
		if rect.has_point(pos) and _player_can_use(dev):
			return dev
	return null


func _player_can_use(device: BaseDevice) -> bool:
	if not device.can_player_interact:
		return false
	if not device.available_actions(BaseDevice.ACTOR_PLAYER).is_empty():
		return true
	match device.device_type:
		&"control_panel":
			var panel := device as ControlPanel
			return panel != null and panel.controls == &"delivery"
		&"heater", &"power":
			return true
		&"self_destruct":
			var self_destruct := device as SelfDestruct
			return (
				self_destruct != null
				and (self_destruct.is_attackable() or self_destruct.is_resettable())
			)
		_:
			return false
