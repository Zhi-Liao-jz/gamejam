class_name ProductExit
extends BaseDevice
## 产品出口：玩家或后续猴子点击出口按钮后，在"产品出口"房间生成随机颜色产品。
## 颜色取自当前交货点房间，保证每个产品都有对应交货点。

const ACTION_SPAWN: StringName = &"spawn_product"
const EXIT_HIT_SIZE := Vector2(64.0, 51.0)
const EXIT_LOCAL := Vector2(0.0, -86.0)

@export var product_scene: PackedScene
@export var owner_room_id: int = 3

@onready var room_manager := get_node("../RoomManager") as RoomManager
@onready var visual: TextureVisual = $Visual
@onready var _exit_select_frame: Sprite2D = $SelectFrame


func _ready() -> void:
	setup_device(&"product_exit", &"product_exit", owner_room_id)
	_sync_visual_position()
	call_deferred("_sync_visual_position")
	_update_visual()
	queue_redraw()


func available_actions(actor: StringName) -> Array[StringName]:
	var exit_room := _exit_room()
	if actor == ACTOR_PLAYER and exit_room != null and not exit_room.panel_open():
		return [ACTION_SPAWN]
	if not _can_spawn_product():
		return []
	return [ACTION_SPAWN]


func device_state() -> StringName:
	var exit_room := _available_exit_room()
	if exit_room == null:
		if not Ledger.is_device_powered(&"product_exit"):
			return &"offline"
		return &"disabled"
	if exit_room.products().size() >= GameConfig.product().max_waiting:
		return &"blocked"
	return &"ready"


func global_rect() -> Rect2:
	var room := room_manager.find_room_by_role(&"product_exit")
	if room == null:
		return Rect2()
	return Rect2(room.global_position + EXIT_LOCAL - EXIT_HIT_SIZE * 0.5, EXIT_HIT_SIZE)


## 尝试生成一个产品。成功返回 true，失败由调用方决定是否给提示。
func try_spawn_product() -> bool:
	return start_action(ACTION_SPAWN, ACTOR_PLAYER, null)


func _perform_action(action_id: StringName, actor: StringName, _actor_node: Node) -> bool:
	if action_id != ACTION_SPAWN:
		return false
	var exit_room := _exit_room()
	if (
		actor == ACTOR_PLAYER
		and exit_room != null
		and exit_room.has_panel()
		and not exit_room.panel_open()
	):
		return exit_room.control_panel.start_action(
			ControlPanel.ACTION_OPEN, BaseDevice.ACTOR_PLAYER, self
		)
	return _spawn_product()


func _can_spawn_product() -> bool:
	var exit_room := _available_exit_room()
	if exit_room == null:
		return false
	var waiting := exit_room.products().size()
	if waiting >= GameConfig.product().max_waiting:
		return false
	var targets := room_manager.delivery_rooms()
	if targets.is_empty():
		return false
	return true


func _spawn_product() -> bool:
	var exit_room := _available_exit_room()
	if exit_room == null:
		return false
	var waiting := exit_room.products().size()
	if waiting >= GameConfig.product().max_waiting:
		return false
	var targets := room_manager.delivery_rooms()
	if targets.is_empty():
		return false
	var target: Room = targets[randi() % targets.size()]
	var raw := GameConfig.product().should_spawn_raw(Game.day)
	var product: Product = product_scene.instantiate()
	product.setup(
		target.color_key,
		target.accent,
		Ledger.roll_product_cost(),
		Ledger.roll_product_reward(),
		raw
	)
	exit_room.add_product(product, _slot_position(waiting))
	Ledger.charge_product_cost(product.cost)  # 生成即扣成本（玩家或猴子按出口都扣）
	_spawn_cost_float(product.cost)
	SoundManager.play("boop")
	_update_visual()
	return true


## 在出口按钮处弹出 "-N 成本" 上浮提示（仅玩家正监控本房间时可见）。
func _spawn_cost_float(amount: int) -> void:
	var float_text := FloatingText.new()
	add_child(float_text)
	float_text.global_position = global_rect().get_center()
	float_text.setup("-%d 成本" % amount)


## 出口房间内第 index 个产品的摆放槽位（底部排布）。
func _slot_position(index: int) -> Vector2:
	var product_config := GameConfig.product()
	var col := index % product_config.slot_per_row
	return Vector2(product_config.slot_start_x + col * product_config.slot_spacing, 90.0)


func _available_exit_room() -> Room:
	if not Ledger.working_active:
		return null
	if not Ledger.is_device_powered(&"product_exit"):
		return null
	var exit_room := _exit_room()
	if exit_room == null or not exit_room.panel_open():
		return null
	return exit_room


func _exit_room() -> Room:
	return room_manager.find_room_by_role(&"product_exit")


func _draw() -> void:
	var room := room_manager.find_room_by_role(&"product_exit")
	if room == null:
		return
	var target_pos := to_local(room.global_position + EXIT_LOCAL)
	var marker_pos := target_pos + Vector2(EXIT_HIT_SIZE.x * 0.34, -EXIT_HIT_SIZE.y * 0.28)
	draw_shock_trap_marker(marker_pos)


func _update_visual() -> void:
	if visual != null:
		visual.apply_state(device_state())
	_sync_visual_position()


func _sync_visual_position() -> void:
	var room := room_manager.find_room_by_role(&"product_exit")
	if room == null:
		return
	var target := room.global_position + EXIT_LOCAL
	if visual != null:
		visual.global_position = target
	if _exit_select_frame != null:
		_exit_select_frame.global_position = target


func _has_visual_texture() -> bool:
	return visual != null and visual.has_texture()
