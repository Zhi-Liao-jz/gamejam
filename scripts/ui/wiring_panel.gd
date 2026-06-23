extends Node
## 接线盒弹出面板（阶段4）：点击右下房间接线盒时打开，拖拽连线修复/改线。
## 面板打开时游戏照常运行（猴子可同时改线，面板实时反映）；ESC 或切换房间关闭。
## 正确连接方式不在此面板标注，需按 Tab 看手册截图对照（符合需求：面板不直接标"这根线错了"）。

var _layer: CanvasLayer = null
var _root: Control = null
var _view: WiringView = null
var _status_label: Label = null


func _ready() -> void:
	_build_ui()
	_root.visible = false
	EventBus.subscribe("open_wiring_panel", _open)
	EventBus.subscribe("room_changed", _on_room_changed)
	EventBus.subscribe("work_started", _close)


func _process(_delta: float) -> void:
	if not _root.visible:
		return
	var box := _wiring_box()
	if box == null:
		_close()
		return
	_status_label.text = "状态：%s" % ("正常" if box.is_correct() else "⚠ 故障（对照手册 Tab）")


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()


func _wiring_box() -> WiringBox:
	return get_tree().get_first_node_in_group("wiring") as WiringBox


func _open(_payload: Variant = null) -> void:
	var box := _wiring_box()
	if box == null:
		return
	_view.box = box
	_root.visible = true


func _close(_payload: Variant = null) -> void:
	_root.visible = false


func _on_room_changed(_room_id: int, _room_name: String) -> void:
	_close()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(420.0, 0.0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "🔌 接线盒"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "拖拽：点→对侧点=连接，点→空白=断开。正确接法见手册(Tab)。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	_view = WiringView.new()
	_view.custom_minimum_size = Vector2(380.0, 240.0)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(_view)

	_status_label = Label.new()
	box.add_child(_status_label)

	var close_button := Button.new()
	close_button.text = "关闭（ESC）"
	close_button.pressed.connect(_close)
	box.add_child(close_button)
