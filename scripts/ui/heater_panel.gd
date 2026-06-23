extends Node
## 加热台弹出面板（阶段5）：点击加热台控制区打开。总开关 + 3 个反射镜垂直滑块 + 激光路径可视化。
## 面板打开时游戏照常运行（猴子可同时乱调，面板实时反映）；ESC 或切换房间关闭。

var _layer: CanvasLayer = null
var _root: Control = null
var _view: HeaterLaserView = null
var _switch_button: Button = null
var _status_label: Label = null
var _sliders: Array[VSlider] = []
var _dragging: Array[bool] = [false, false, false]


func _ready() -> void:
	_build_ui()
	_root.visible = false
	EventBus.subscribe("open_heater_panel", _open)
	EventBus.subscribe("room_changed", _on_room_changed)
	EventBus.subscribe("work_started", _close)


func _process(_delta: float) -> void:
	if not _root.visible:
		return
	var heater := _heater()
	if heater == null:
		_close()
		return
	_switch_button.text = "总开关：%s" % ("开" if heater.switch_on else "关")
	for j: int in heater.PLATE_COUNT:
		if not _dragging[j]:
			_sliders[j].set_value_no_signal(heater.mirror_heights[j])
	_status_label.text = _status_text(heater)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()


func _heater() -> Heater:
	return get_tree().get_first_node_in_group("heater") as Heater


func _open(_payload: Variant = null) -> void:
	var heater := _heater()
	if heater == null:
		return
	_view.heater = heater
	for j: int in heater.PLATE_COUNT:
		_sliders[j].set_value_no_signal(heater.mirror_heights[j])
	_root.visible = true


func _close(_payload: Variant = null) -> void:
	_root.visible = false


func _on_room_changed(_room_id: int, _room_name: String) -> void:
	_close()


func _status_text(heater: Heater) -> String:
	if heater.is_offline():
		return "状态：停电（先恢复供电）"
	if not heater.switch_on:
		return "状态：总开关关闭"
	var counts := heater.plate_counts()
	var parts: Array[String] = []
	for j: int in heater.PLATE_COUNT:
		var s := "不加热"
		if counts[j] >= 2:
			s = "过热"
		elif counts[j] >= 1:
			s = "正常"
		parts.append("盘%d:%s" % [j + 1, s])
	return "状态：" + "  ".join(parts)


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
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(420.0, 0.0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "🔥 加热台 · 激光"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "开总开关后调反射镜：每盘 1 道激光=正常(10s)，2 道=过热(5s，熟后3s烧焦)。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	_switch_button = Button.new()
	_switch_button.pressed.connect(_on_switch_pressed)
	box.add_child(_switch_button)

	_view = HeaterLaserView.new()
	_view.custom_minimum_size = Vector2(400.0, 220.0)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_view)

	var sliders_row := HBoxContainer.new()
	sliders_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sliders_row.add_theme_constant_override("separation", 60)
	box.add_child(sliders_row)
	for j: int in 3:
		sliders_row.add_child(_make_slider_column(j))

	_status_label = Label.new()
	box.add_child(_status_label)

	var close_button := Button.new()
	close_button.text = "关闭（ESC）"
	close_button.pressed.connect(_close)
	box.add_child(close_button)


func _make_slider_column(index: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := Label.new()
	label.text = "镜%d" % (index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	var slider := VSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(0.0, 120.0)
	slider.value_changed.connect(_on_mirror_changed.bind(index))
	slider.drag_started.connect(func() -> void: _dragging[index] = true)
	slider.drag_ended.connect(func(_c: bool) -> void: _dragging[index] = false)
	col.add_child(slider)
	_sliders.append(slider)
	return col


func _on_switch_pressed() -> void:
	var heater := _heater()
	if heater != null:
		heater.toggle_switch()


func _on_mirror_changed(value: float, index: int) -> void:
	var heater := _heater()
	if heater != null:
		heater.set_mirror(index, value)
