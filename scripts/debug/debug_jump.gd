extends Node
## 调试工具（playtest 用，正式版删除本节点 + 脚本）：按 1-7 直接跳到对应天并重建当天内容。
## 重入 DayManager 的 Working 状态 → reset_day + work_started，让面板/猴子/设备按目标天数重建。

var _label: Label = null

@onready var _day_manager := get_node("../DayManager") as BaseStateMachine


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()  # 发行版自动禁用（双保险：编辑器/调试导出才生效）
		return
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(20.0, 560.0)
	_label.add_theme_font_size_override("font_size", 16)
	_label.text = "🔧 调试：[1-7] 跳到第 N 天"
	layer.add_child(_label)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_7:
		_jump_to_day(key.keycode - KEY_0)
		get_viewport().set_input_as_handled()


func _jump_to_day(day: int) -> void:
	Game.highest_unlocked_day = maxi(Game.highest_unlocked_day, day)
	Game.start_day(day)
	_day_manager.transition_to(&"Working")  # 重入工作阶段：reset + work_started 重建当天
	_label.text = "🔧 调试：已跳到第 %d 天" % day
