extends Node
## 发电机弹出面板（阶段3）：点击右下房间发电机时打开，显示燃料热值 / 温度 / 输出 / 负载 / 警报，
## 提供 开关 / 清空燃料 / 长按添加燃料 / 燃烧速率滑块 / 涡轮功率滑块。
## 面板打开时游戏照常运行（猴子可同时改参数，面板实时反映）；ESC 或切换房间或点关闭都会收起。
## UI 全在代码里搭建（与 pause_menu / debug 一致），场景里只挂一个空 Node。

var _layer: CanvasLayer = null
var _root: Control = null
var _info_label: Label = null
var _switch_button: Button = null
var _burn_slider: HSlider = null
var _turbine_slider: HSlider = null
var _burn_dragging: bool = false
var _turbine_dragging: bool = false


func _ready() -> void:
	_build_ui()
	_root.visible = false
	EventBus.subscribe("open_generator_panel", _open)
	EventBus.subscribe("room_changed", _on_room_changed)
	EventBus.subscribe("work_started", _close)


func _process(_delta: float) -> void:
	if not _root.visible:
		return
	var gen := _generator()
	if gen == null:
		_close()
		return
	_refresh(gen)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()


## 当前发电机（右下房间，group "power"）。
func _generator() -> Generator:
	return get_tree().get_first_node_in_group("power") as Generator


func _open(_payload: Variant = null) -> void:
	var gen := _generator()
	if gen == null:
		return
	_root.visible = true
	_burn_slider.set_value_no_signal(gen.burn_rate)
	_turbine_slider.set_value_no_signal(gen.turbine_power)
	_refresh(gen)


func _close(_payload: Variant = null) -> void:
	if not _root.visible:
		return
	var gen := _generator()
	if gen != null:
		gen.set_adding_fuel(false)  # 关面板时务必松开"加燃料"
	_root.visible = false


func _on_room_changed(_room_id: int, _room_name: String) -> void:
	_close()


func _refresh(gen: Generator) -> void:
	_switch_button.text = "开关：%s" % ("开" if gen.switch_on else "关")
	if not _burn_dragging:
		_burn_slider.set_value_no_signal(gen.burn_rate)
	if not _turbine_dragging:
		_turbine_slider.set_value_no_signal(gen.turbine_power)
	_info_label.text = (
		(
			"燃料热值：%.0f / %.0f\n"
			+ "开关状态：%s\n"
			+ "温度：%.1f（安全 %.0f~%.0f）\n"
			+ "电量输出：%.1f\n"
			+ "负载：%.0f（容差 ±%.0f）\n"
			+ "输出效率：%d%%\n"
			+ "警报：%s"
		)
		% [
			gen.fuel_heat,
			GeneratorTuning.max_fuel_heat,
			"开" if gen.switch_on else "关",
			gen.temperature(),
			GeneratorTuning.temp_safe_min,
			GeneratorTuning.temp_safe_max,
			gen.power_output(),
			gen.current_load(),
			GeneratorTuning.tolerance,
			roundi(gen.efficiency() * 100.0),
			_alarm_text(gen.alarms()),
		]
	)


func _alarm_text(alarms: Array[StringName]) -> String:
	if alarms.is_empty():
		return "正常"
	var parts: Array[String] = []
	for a: StringName in alarms:
		match a:
			&"output_high":
				parts.append("输出过高")
			&"output_low":
				parts.append("输出过低")
			&"temp_high":
				parts.append("温度过高")
			&"temp_low":
				parts.append("温度过低")
	return "  ".join(parts)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4  # HUD(2)/调试(3) 之上，暂停菜单(5) 之下
	add_child(_layer)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child_to_layer(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # 吞掉面板外的点击，避免误操作游戏
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(360.0, 0.0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "⚡ 发电机"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	_info_label = Label.new()
	box.add_child(_info_label)

	_switch_button = Button.new()
	_switch_button.pressed.connect(_on_switch_pressed)
	box.add_child(_switch_button)

	var fuel_row := HBoxContainer.new()
	fuel_row.add_theme_constant_override("separation", 10)
	box.add_child(fuel_row)
	var clear_button := Button.new()
	clear_button.text = "清空燃料"
	clear_button.pressed.connect(_on_clear_pressed)
	fuel_row.add_child(clear_button)
	var add_button := Button.new()
	add_button.text = "添加燃料（长按）"
	add_button.button_down.connect(_on_add_down)
	add_button.button_up.connect(_on_add_up)
	fuel_row.add_child(add_button)

	box.add_child(_make_label("燃烧速率"))
	_burn_slider = _make_slider()
	_burn_slider.value_changed.connect(_on_burn_changed)
	_burn_slider.drag_started.connect(func() -> void: _burn_dragging = true)
	_burn_slider.drag_ended.connect(func(_c: bool) -> void: _burn_dragging = false)
	box.add_child(_burn_slider)

	box.add_child(_make_label("涡轮功率"))
	_turbine_slider = _make_slider()
	_turbine_slider.value_changed.connect(_on_turbine_changed)
	_turbine_slider.drag_started.connect(func() -> void: _turbine_dragging = true)
	_turbine_slider.drag_ended.connect(func(_c: bool) -> void: _turbine_dragging = false)
	box.add_child(_turbine_slider)

	var close_button := Button.new()
	close_button.text = "关闭（ESC）"
	close_button.pressed.connect(_close)
	box.add_child(close_button)


## 把控件加到 CanvasLayer（CanvasLayer 不是 Control，需直接 add_child）。
func add_child_to_layer(node: Node) -> void:
	_layer.add_child(node)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _make_slider() -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(0.0, 24.0)
	return slider


func _on_switch_pressed() -> void:
	var gen := _generator()
	if gen != null:
		gen.toggle_switch()


func _on_clear_pressed() -> void:
	var gen := _generator()
	if gen != null:
		gen.clear_fuel()


func _on_add_down() -> void:
	var gen := _generator()
	if gen != null:
		gen.set_adding_fuel(true)


func _on_add_up() -> void:
	var gen := _generator()
	if gen != null:
		gen.set_adding_fuel(false)


func _on_burn_changed(value: float) -> void:
	var gen := _generator()
	if gen != null:
		gen.set_burn_rate(value)


func _on_turbine_changed(value: float) -> void:
	var gen := _generator()
	if gen != null:
		gen.set_turbine_power(value)
