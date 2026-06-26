extends Node
## 检查自爆开关在可处理状态下会进入鼠标悬停高亮判定。

var _errors: Array[String] = []


func _ready() -> void:
	_run()
	if _errors.is_empty():
		print("self_destruct_highlight_smoke: OK")
		get_tree().quit(0)
		return
	for error: String in _errors:
		push_error(error)
	get_tree().quit(1)


func _run() -> void:
	var highlighter := DeviceHighlighter.new()
	var self_destruct := SelfDestruct.new()
	self_destruct.device_type = &"self_destruct"

	self_destruct.state = SelfDestruct.State.PROTECTED
	_require_can_highlight(highlighter, self_destruct, "受保护玻璃罩")

	self_destruct.state = SelfDestruct.State.EXPOSED
	_require_can_highlight(highlighter, self_destruct, "玻璃罩打开")

	self_destruct.state = SelfDestruct.State.ARMED
	_require_can_highlight(highlighter, self_destruct, "倒计时中")

	self_destruct.state = SelfDestruct.State.TRIGGERED
	_require_cannot_highlight(highlighter, self_destruct, "已引爆")

	highlighter.free()
	self_destruct.free()


func _require_can_highlight(
	highlighter: DeviceHighlighter,
	self_destruct: SelfDestruct,
	label: String,
) -> void:
	if not bool(highlighter.call("_player_can_use", self_destruct)):
		_errors.append("自爆开关状态应可高亮：%s" % label)


func _require_cannot_highlight(
	highlighter: DeviceHighlighter,
	self_destruct: SelfDestruct,
	label: String,
) -> void:
	if bool(highlighter.call("_player_can_use", self_destruct)):
		_errors.append("自爆开关状态不应可高亮：%s" % label)
