class_name ProductExit
extends Node2D
## 产品出口：玩家或后续猴子点击出口按钮后，在"产品出口"房间生成随机颜色产品。
## 颜色取自当前交货点房间，保证每个产品都有对应交货点。

const MAX_WAITING := 4  # 出口房间内最多积压的产品数
const SLOT_PER_ROW := 4  # 摆放槽位每行数量
const SLOT_START_X := -180.0  # 出口房间内产品摆放起始 x（房间局部坐标）
const SLOT_SPACING := 90.0  # 槽位水平间距

@export var product_scene: PackedScene

@onready var room_manager := get_node("../RoomManager") as RoomManager


## 尝试生成一个产品。成功返回 true，失败由调用方决定是否给提示。
func try_spawn_product() -> bool:
	var exit_room := _available_exit_room()
	if exit_room == null:
		return false
	var waiting := exit_room.products().size()
	if waiting >= MAX_WAITING:
		return false
	var targets := room_manager.delivery_rooms()
	if targets.is_empty():
		return false
	var target: Room = targets[randi() % targets.size()]
	var raw := Game.day >= 4 and randf() < 0.4  # 第4天起约四成产品是生料，需先去加热台
	var product: Product = product_scene.instantiate()
	product.setup(
		target.color_key,
		target.accent,
		Ledger.roll_product_cost(),
		Ledger.roll_product_reward(),
		raw
	)
	exit_room.add_product(product, _slot_position(waiting))
	SoundManager.play("boop")
	return true


## 出口房间内第 index 个产品的摆放槽位（底部排布）。
func _slot_position(index: int) -> Vector2:
	var col := index % SLOT_PER_ROW
	return Vector2(SLOT_START_X + col * SLOT_SPACING, 90.0)


func _available_exit_room() -> Room:
	if not Ledger.working_active:
		return null
	if not Ledger.power_on:
		return null
	var exit_room := room_manager.find_room_by_role(&"product_exit")
	if exit_room == null or not exit_room.panel_open():
		return null
	return exit_room
