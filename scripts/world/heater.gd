class_name Heater
extends Node2D
## 加热台（P4 / 第4天，文档模块8 左下）：逐帧加热本房间内的生料产品，到点变熟、过头烧焦。
## 挂在 heater 房间下，处理 get_parent() 房间里的产品。P4 常开（猴子破坏/调温留第5天增量）。

const TINT := Color(0.95, 0.55, 0.12)
const SURFACE := Rect2(-200.0, -10.0, 400.0, 150.0)  # 加热面（房间局部坐标，铺在产品摆放区下方）

var _room: Room = null


func _ready() -> void:
	# 默认 z0：画在房间地板(父 _draw)之上、产品(z1)之下，正好当"发热地面"
	_room = get_parent() as Room


func _process(delta: float) -> void:
	if _room == null or not Ledger.working_active:
		return
	for product: Product in _room.products():
		if product.advance_heat(delta):
			if product.burned:
				SoundManager.play("alarm")  # 烧焦：报警提示
			elif product.heated:
				SoundManager.play("boop")  # 变熟：叮一声


func _draw() -> void:
	draw_rect(SURFACE, TINT.darkened(0.25))
	draw_rect(SURFACE, TINT, false, 3.0)
