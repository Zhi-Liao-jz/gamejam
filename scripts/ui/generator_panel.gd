extends Control
## 发电机控制台（灰盒，代码构建 UI）。玩家调 燃烧/涡轮/燃料/开关，让"电量输出"匹配"负载"。
## 不暂停世界——开面板时烟仍在烧、猴子仍在跑，这正是"边修边被偷"的核心张力。

var _gen: Generator = null
var _adding := false

var _readout: Label
var _lamp: Label
var _diag: Label
var _fuel_bar: ProgressBar
var _burn: HSlider
var _turbine: HSlider
var _switch: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	EventBus.subscribe("open_generator_panel", _on_open)
	# 进结算/新一天时强制关闭，避免面板盖在结算界面上或带入新一天
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
	title.text = "发电机控制台    [E / Esc 关闭]"
	vbox.add_child(title)

	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 30)
	vbox.add_child(_readout)

	_lamp = Label.new()
	_lamp.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_lamp)

	_diag = Label.new()
	vbox.add_child(_diag)

	vbox.add_child(_make_label("燃料热值"))
	_fuel_bar = ProgressBar.new()
	_fuel_bar.min_value = 0.0
	_fuel_bar.max_value = Generator.FUEL_MAX
	_fuel_bar.custom_minimum_size = Vector2(380, 18)
	vbox.add_child(_fuel_bar)

	vbox.add_child(_make_label("燃烧速率"))
	_burn = _make_slider()
	_burn.value_changed.connect(_on_burn)
	vbox.add_child(_burn)

	vbox.add_child(_make_label("涡轮功率"))
	_turbine = _make_slider()
	_turbine.value_changed.connect(_on_turbine)
	vbox.add_child(_turbine)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	vbox.add_child(btns)

	_switch = Button.new()
	_switch.pressed.connect(_on_switch)
	btns.add_child(_switch)

	var clear_btn := Button.new()
	clear_btn.text = "清空燃料"
	clear_btn.pressed.connect(_on_clear)
	btns.add_child(clear_btn)

	var add_btn := Button.new()
	add_btn.text = "长按加燃料"
	add_btn.button_down.connect(_on_add_down)
	add_btn.button_up.connect(_on_add_up)
	btns.add_child(add_btn)


func _make_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _make_slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(380, 20)
	return s


func _process(delta: float) -> void:
	if not visible or _gen == null:
		return
	if _adding:
		var v := _gen.fuel_heat + Generator.FUEL_REFILL_PER_SEC * delta
		_gen.fuel_heat = minf(Generator.FUEL_MAX, v)
		_gen.sync_state()
	_refresh()


func _refresh() -> void:
	var mm := _gen.mismatch()
	_readout.text = "电量输出  %d        负载  %d" % [roundi(_gen.output()), roundi(_gen.load)]
	if mm < Generator.TOLERANCE:
		_lamp.text = "● 匹配 ✓"
		_lamp.modulate = Color(0.35, 0.9, 0.35)
	else:
		_lamp.text = "● 失配  Δ=%d" % roundi(mm)
		_lamp.modulate = Color(0.95, 0.4, 0.35)
	_diag.text = (
		"温度 %d    效率 %d%%    %s"
		% [roundi(_gen.temp()), roundi(_gen.eff() * 100.0), "运行中" if _gen.on else "已关机"]
	)
	_fuel_bar.value = _gen.fuel_heat
	_switch.text = "开机中" if _gen.on else "已关机"
	# 回写滑块（同步猴子扰动 / 长按加燃料造成的成员变化），不触发 value_changed 回环
	_burn.set_value_no_signal(_gen.burn_rate)
	_turbine.set_value_no_signal(_gen.turbine)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _on_open(gen: Generator) -> void:
	_gen = gen
	_burn.set_value_no_signal(gen.burn_rate)
	_turbine.set_value_no_signal(gen.turbine)
	visible = true
	_refresh()


func _close() -> void:
	visible = false
	_adding = false


## 结算/新一天事件触发的强制关闭（show_settlement 带 data、hide_settlement 无参，用可选参数兼容）
func _on_force_close(_data = null) -> void:
	if visible:
		_close()


func _on_burn(v: float) -> void:
	if _gen:
		_gen.burn_rate = v
		_gen.sync_state()


func _on_turbine(v: float) -> void:
	if _gen:
		_gen.turbine = v
		_gen.sync_state()


func _on_switch() -> void:
	if _gen:
		_gen.on = not _gen.on
		_gen.sync_state()


func _on_clear() -> void:
	if _gen:
		_gen.fuel_heat = 0.0
		_gen.sync_state()


func _on_add_down() -> void:
	_adding = true


func _on_add_up() -> void:
	_adding = false
