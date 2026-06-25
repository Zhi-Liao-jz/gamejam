extends BaseState
## 被捕网控制：猴子停留一段时间，不能移动或操作设备，到时恢复随机游荡。

var monkey: GridMonkey
var _remaining: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	monkey = fsm.get_parent() as GridMonkey
	_remaining = float(msg.get("duration", _default_duration()))
	monkey.is_captured = true
	monkey.target_room = -1
	monkey.clear_current_action()
	monkey.stop_audio()
	monkey.set_visual_state(&"captured")


func physics_update(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		fsm.transition_to(&"GridSneaking")


func exit() -> void:
	if monkey == null:
		return
	monkey.is_captured = false
	monkey.set_visual_state(&"normal")


func _default_duration() -> float:
	return Game.equipment_effect_duration(Game.EQUIPMENT_NET)
