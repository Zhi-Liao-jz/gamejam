class_name Heater
extends BaseDevice
## 加热台：可开关、可切过热。正常加工不会烧坏，过热加工完成后未取走会烧焦。
## 挂在 heater 房间下，处理 get_parent() 房间里的产品。

enum State { OFF, NORMAL_HEATING, NORMAL_DONE, OVERHEAT_HEATING, OVERHEAT_DONE, BURNED }

const ACTION_TURN_ON_NORMAL: StringName = &"turn_on_normal"
const ACTION_TURN_OFF: StringName = &"turn_off"
const ACTION_TURN_ON_OVERHEAT: StringName = &"turn_on_overheat"
const TINT := Color(0.95, 0.55, 0.12)
const OVERHEAT_TINT := Color(1.0, 0.25, 0.10)
const DONE_TINT := Color(0.40, 0.82, 0.42)
const BURNED_TINT := Color(0.12, 0.10, 0.09)
const SURFACE := Rect2(-200.0, -10.0, 400.0, 150.0)  # 加热面（房间局部坐标，铺在产品摆放区下方）
const CONTROL_SIZE := Vector2(120.0, 52.0)
const CONTROL_OFFSET := Vector2(-150.0, -95.0)

var state: State = State.OFF
var _room: Room = null


func _ready() -> void:
	# 默认 z0：画在房间地板(父 _draw)之上、产品(z1)之下，正好当"发热地面"
	_room = get_parent() as Room
	var owner_room_id := -1 if _room == null else _room.room_id
	setup_device(StringName("heater_%d" % owner_room_id), &"heater", owner_room_id)
	EventBus.subscribe("work_started", _on_work_started)
	queue_redraw()


func _process(delta: float) -> void:
	if _room == null or not Ledger.working_active:
		return
	_refresh_passive_state()
	if not Ledger.power_on:
		return  # 停电 → 加热台停摆，不推进加工 / 烧焦
	if not _is_heating():
		return
	for product: Product in _products_on_surface():
		var result := product.advance_heat(delta, _is_overheating())
		_handle_heat_result(result)
	_refresh_passive_state()


func available_actions(actor: StringName) -> Array[StringName]:
	var actions: Array[StringName] = []
	if not _is_unlocked() or not Ledger.working_active:
		return actions
	if actor != ACTOR_PLAYER and actor != ACTOR_MONKEY:
		return actions
	if not Ledger.power_on:
		return actions
	if state == State.OFF:
		actions.append(ACTION_TURN_ON_NORMAL)
		actions.append(ACTION_TURN_ON_OVERHEAT)
		return actions
	if _is_overheating():
		actions.append(ACTION_TURN_ON_NORMAL)
	else:
		actions.append(ACTION_TURN_ON_OVERHEAT)
	actions.append(ACTION_TURN_OFF)
	return actions


func device_state() -> StringName:
	if not Ledger.power_on:
		return &"offline"
	var result: StringName = &"off"
	match state:
		State.OFF:
			result = &"off"
		State.NORMAL_HEATING:
			result = &"normal_heating"
		State.NORMAL_DONE:
			result = &"normal_done"
		State.OVERHEAT_HEATING:
			result = &"overheat_heating"
		State.OVERHEAT_DONE:
			result = &"overheat_done"
		State.BURNED:
			result = &"burned"
	return result


func global_rect() -> Rect2:
	return Rect2(global_position + CONTROL_OFFSET - CONTROL_SIZE * 0.5, CONTROL_SIZE)


func next_player_action() -> StringName:
	if not _is_unlocked() or not Ledger.working_active or not Ledger.power_on:
		return &""
	match state:
		State.OFF:
			return ACTION_TURN_ON_NORMAL
		State.NORMAL_HEATING, State.NORMAL_DONE:
			return ACTION_TURN_ON_OVERHEAT
		State.OVERHEAT_HEATING, State.OVERHEAT_DONE, State.BURNED:
			return ACTION_TURN_OFF
		_:
			return &""


func can_install_shock_trap() -> bool:
	return Game.day >= 5 and super.can_install_shock_trap()


func _perform_action(action_id: StringName, _actor: StringName, _actor_node: Node) -> bool:
	match action_id:
		ACTION_TURN_ON_NORMAL:
			state = (
				_done_state_for_mode(false) if _has_processed_product() else State.NORMAL_HEATING
			)
		ACTION_TURN_ON_OVERHEAT:
			state = (
				_done_state_for_mode(true) if _has_processed_product() else State.OVERHEAT_HEATING
			)
		ACTION_TURN_OFF:
			state = State.OFF
		_:
			return false
	_refresh_passive_state()
	queue_redraw()
	return true


func _draw() -> void:
	var c := _state_color()
	draw_rect(SURFACE, c.darkened(0.25))
	draw_rect(SURFACE, c, false, 3.0)
	var control_rect := Rect2(CONTROL_OFFSET - CONTROL_SIZE * 0.5, CONTROL_SIZE)
	draw_rect(control_rect, c.darkened(0.45))
	draw_rect(control_rect, c.lightened(0.2), false, 2.0)
	draw_shock_trap_marker(CONTROL_OFFSET + Vector2(CONTROL_SIZE.x * 0.34, -CONTROL_SIZE.y * 0.28))


func _refresh_passive_state() -> void:
	var previous := state
	var has_burned := _has_burned_product()
	var has_processed := _has_processed_product()
	if has_burned:
		state = State.BURNED
	elif state == State.NORMAL_HEATING and has_processed:
		state = State.NORMAL_DONE
	elif state == State.OVERHEAT_HEATING and has_processed:
		state = State.OVERHEAT_DONE
	elif state == State.NORMAL_DONE and not has_processed:
		state = State.NORMAL_HEATING
	elif state == State.BURNED and has_processed:
		state = State.OVERHEAT_DONE
	elif (
		(state == State.OVERHEAT_DONE or state == State.BURNED)
		and not has_burned
		and not has_processed
	):
		state = State.OVERHEAT_HEATING
	if state != previous:
		queue_redraw()


func _handle_heat_result(result: StringName) -> void:
	match result:
		Product.HEAT_RESULT_PROCESSED:
			SoundManager.play("boop")
		Product.HEAT_RESULT_BURNED:
			SoundManager.play("alarm")


func _has_processed_product() -> bool:
	for product: Product in _products_on_surface():
		if product.requires_heat and product.is_processed and not product.is_damaged:
			return true
	return false


func _has_burned_product() -> bool:
	for product: Product in _products_on_surface():
		if product.requires_heat and product.is_damaged:
			return true
	return false


func _products_on_surface() -> Array[Product]:
	var result: Array[Product] = []
	if _room == null:
		return result
	for product: Product in _room.products():
		if SURFACE.has_point(to_local(product.global_position)):
			result.append(product)
	return result


func _is_heating() -> bool:
	return (
		state == State.NORMAL_HEATING
		or state == State.OVERHEAT_HEATING
		or state == State.OVERHEAT_DONE
	)


func _is_overheating() -> bool:
	return state == State.OVERHEAT_HEATING or state == State.OVERHEAT_DONE


func _is_unlocked() -> bool:
	return Game.day >= 4


func _done_state_for_mode(is_overheating: bool) -> State:
	return State.OVERHEAT_DONE if is_overheating else State.NORMAL_DONE


func _state_color() -> Color:
	if not Ledger.power_on:
		return Color(0.24, 0.24, 0.24)
	var color := TINT
	match state:
		State.OFF:
			color = Color(0.35, 0.35, 0.32)
		State.NORMAL_HEATING:
			color = TINT
		State.NORMAL_DONE:
			color = DONE_TINT
		State.OVERHEAT_HEATING, State.OVERHEAT_DONE:
			color = OVERHEAT_TINT
		State.BURNED:
			color = BURNED_TINT
	return color


func _on_work_started() -> void:
	state = State.OFF
	queue_redraw()
