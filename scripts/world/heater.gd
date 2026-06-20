class_name Heater
extends BaseDevice
## 加热台（文档模块8 左下）：逐帧加热本房间内的生料产品，到点变熟、过头烧焦。
## 挂在 heater 房间下，处理 get_parent() 房间里的产品。
## P5：温控面板被猴子关掉 = 过热，加热/烧焦按 OVERHEAT_MULT 加速；玩家切过去重开面板恢复常温。

const ACTION_INSPECT: StringName = &"inspect"
const TINT := Color(0.95, 0.55, 0.12)
const OVERHEAT_TINT := Color(1.0, 0.25, 0.10)
const SURFACE := Rect2(-200.0, -10.0, 400.0, 150.0)  # 加热面（房间局部坐标，铺在产品摆放区下方）
const OVERHEAT_MULT := 2.5  # 面板被关（温控被搞）时的加热 / 烧焦倍率

var _room: Room = null
var _overheating: bool = false


func _ready() -> void:
	# 默认 z0：画在房间地板(父 _draw)之上、产品(z1)之下，正好当"发热地面"
	_room = get_parent() as Room
	var owner_room_id := -1 if _room == null else _room.room_id
	setup_device(StringName("heater_%d" % owner_room_id), &"heater", owner_room_id)


func _process(delta: float) -> void:
	if _room == null or not Ledger.working_active:
		return
	if not Ledger.power_on:
		return  # 停电 → 加热台停摆，不加热（P6）
	var over := not _room.panel_open()  # 面板关 = 温控被猴子搞 → 过热
	if over != _overheating:
		_overheating = over
		queue_redraw()
	var mult := OVERHEAT_MULT if over else 1.0
	for product: Product in _room.products():
		if product.advance_heat(delta * mult):
			if product.burned:
				SoundManager.play("alarm")  # 烧焦：报警提示
			elif product.heated:
				SoundManager.play("boop")  # 变熟：叮一声


func available_actions(_actor: StringName) -> Array[StringName]:
	return [ACTION_INSPECT]


func device_state() -> StringName:
	if not Ledger.power_on:
		return &"offline"
	return &"overheating" if _overheating else &"heating"


func _perform_action(action_id: StringName, _actor: StringName, _actor_node: Node) -> bool:
	return action_id == ACTION_INSPECT


func _draw() -> void:
	var c := OVERHEAT_TINT if _overheating else TINT
	draw_rect(SURFACE, c.darkened(0.25))
	draw_rect(SURFACE, c, false, 3.0)
