extends Control
## 接线盒控制台（灰盒，代码构建 UI）。点左端子再点右端子改一根线，把连线接回正确组合。
## 不暂停世界——开面板时烟仍在烧、猴子仍在跑。仿 generator_panel.gd。

const LEFT_NAMES := ["A", "B", "C", "D"]

var _jbox: JunctionBox = null
var _picked_left := -1

var _lamp: Label
var _countdown: Label
var _wires_label: Label
var _left_btns: Array[Button] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	EventBus.subscribe("open_junction_panel", _on_open)
	# 进结算/新一天时强制关闭
	EventBus.subscribe("show_settlement", _on_force_close)
	EventBus.subscribe("hide_settlement", _on_force_close)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)

	var panel := PanelContainer.new()
	panel.add_child(margin)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(420, 0)
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "接线盒    [E / Esc 关闭]    点左端子→再点右端子改一根线"
	vbox.add_child(title)

	_lamp = Label.new()
	_lamp.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_lamp)

	_countdown = Label.new()
	_countdown.add_theme_font_size_override("font_size", 18)
	_countdown.modulate = Color(0.95, 0.4, 0.35)
	vbox.add_child(_countdown)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)
	for i in JunctionBox.N:
		var lb := Button.new()
		lb.text = "左 " + LEFT_NAMES[i]
		lb.pressed.connect(_on_left.bind(i))
		grid.add_child(lb)
		_left_btns.append(lb)
		var rb := Button.new()
		rb.text = "右 " + str(i)
		rb.pressed.connect(_on_right.bind(i))
		grid.add_child(rb)

	_wires_label = Label.new()
	vbox.add_child(_wires_label)

	var reset := Button.new()
	reset.text = "复位连线"
	reset.pressed.connect(_on_reset)
	vbox.add_child(reset)


func _process(_delta: float) -> void:
	if not visible or _jbox == null:
		return
	_refresh()


func _refresh() -> void:
	var wrong := _jbox.wrong_count()
	if _jbox.is_short():
		_lamp.text = "● 短路！两根线接到同一处"
		_lamp.modulate = Color(0.95, 0.4, 0.35)
	elif wrong == 0:
		_lamp.text = "● 全部接通 ✓"
		_lamp.modulate = Color(0.35, 0.9, 0.35)
	else:
		_lamp.text = "● 错接 %d 根" % wrong
		_lamp.modulate = Color(0.95, 0.4, 0.35)

	if _jbox.state == BaseDevice.DeviceState.SEVERE:
		_countdown.text = "⚠ 严重故障  致命倒计时 %.1f s" % _jbox.severe_remaining()
		_countdown.visible = true
	else:
		_countdown.visible = false

	var parts := PackedStringArray()
	for i in JunctionBox.N:
		var mark := "✓" if _jbox.wiring[i] == JunctionBox.TARGET[i] else "✗"
		parts.append("%s→%d%s" % [LEFT_NAMES[i], _jbox.wiring[i], mark])
	_wires_label.text = "当前连线：  " + "    ".join(parts)

	for i in _left_btns.size():
		_left_btns[i].modulate = Color(1, 1, 0.4) if i == _picked_left else Color(1, 1, 1)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _on_open(box: JunctionBox) -> void:
	_jbox = box
	_picked_left = -1
	visible = true
	_refresh()


func _close() -> void:
	visible = false
	_picked_left = -1


func _on_force_close(_data = null) -> void:
	if visible:
		_close()


func _on_left(i: int) -> void:
	_picked_left = i
	_refresh()


func _on_right(j: int) -> void:
	if _jbox == null or _picked_left < 0:
		return
	_jbox.wiring[_picked_left] = j
	_jbox.sync_state()
	_picked_left = -1
	_refresh()


func _on_reset() -> void:
	if _jbox == null:
		return
	_jbox.wiring = JunctionBox.TARGET.duplicate()
	_jbox.sync_state()
	_picked_left = -1
	_refresh()
