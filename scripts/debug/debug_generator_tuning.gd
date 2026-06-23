extends Node
## 调试面板（playtest 用，发行版自动禁用）：实时调发电机数值旋钮。
## F2 显示 / 隐藏。所有改动写入 GeneratorTuning（autoload），即时生效、不进存档。

const STEP_LOAD := 5.0  # 基础负载每次 ±5
const STEP_LOAD_PER_DAY := 1.0  # 负载/天每次 ±1
const STEP_TOL := 1.0  # 容差每次 ±1
const STEP_TEMP := 5.0  # 温度上限每次 ±5
const STEP_FEE := 0.5  # 维护费每次 ±0.5
const PANEL_POS := Vector2(900.0, 260.0)

var _panel: PanelContainer = null
var _load_label: Label = null
var _load_per_day_label: Label = null
var _tol_label: Label = null
var _temp_label: Label = null
var _fee_label: Label = null


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()  # 发行版自动禁用
		return
	_build_ui()
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F2:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)

	_panel = PanelContainer.new()
	_panel.position = PANEL_POS
	layer.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "⚡ 发电机调参 (F2 隐藏)"
	box.add_child(title)

	_load_label = Label.new()
	box.add_child(
		_make_row("基础负载", _load_label, _add_load.bind(-STEP_LOAD), _add_load.bind(STEP_LOAD))
	)
	_load_per_day_label = Label.new()
	box.add_child(
		_make_row(
			"负载/天",
			_load_per_day_label,
			_add_load_per_day.bind(-STEP_LOAD_PER_DAY),
			_add_load_per_day.bind(STEP_LOAD_PER_DAY)
		)
	)
	_tol_label = Label.new()
	box.add_child(_make_row("容差", _tol_label, _add_tol.bind(-STEP_TOL), _add_tol.bind(STEP_TOL)))
	_temp_label = Label.new()
	box.add_child(
		_make_row("温度上限", _temp_label, _add_temp.bind(-STEP_TEMP), _add_temp.bind(STEP_TEMP))
	)
	_fee_label = Label.new()
	box.add_child(_make_row("维护费/秒", _fee_label, _add_fee.bind(-STEP_FEE), _add_fee.bind(STEP_FEE)))


## 一行："名称 [-] 值 [+]"。on_minus / on_plus 为点击回调。
func _make_row(
	title: String, value_label: Label, on_minus: Callable, on_plus: Callable
) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size = Vector2(96.0, 0.0)
	row.add_child(name_label)
	var minus := Button.new()
	minus.text = " - "
	minus.pressed.connect(on_minus)
	row.add_child(minus)
	value_label.custom_minimum_size = Vector2(56.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	var plus := Button.new()
	plus.text = " + "
	plus.pressed.connect(on_plus)
	row.add_child(plus)
	return row


func _add_load(delta: float) -> void:
	GeneratorTuning.base_load = clampf(GeneratorTuning.base_load + delta, 0.0, 500.0)
	_refresh()


func _add_load_per_day(delta: float) -> void:
	GeneratorTuning.load_per_day = clampf(GeneratorTuning.load_per_day + delta, 0.0, 100.0)
	_refresh()


func _add_tol(delta: float) -> void:
	GeneratorTuning.tolerance = clampf(GeneratorTuning.tolerance + delta, 0.0, 100.0)
	_refresh()


func _add_temp(delta: float) -> void:
	GeneratorTuning.temp_safe_max = clampf(GeneratorTuning.temp_safe_max + delta, 0.0, 1000.0)
	_refresh()


func _add_fee(delta: float) -> void:
	GeneratorTuning.overload_fee = clampf(GeneratorTuning.overload_fee + delta, 0.0, 100.0)
	GeneratorTuning.overheat_fee = GeneratorTuning.overload_fee
	_refresh()


func _refresh() -> void:
	_load_label.text = "%.0f" % GeneratorTuning.base_load
	_load_per_day_label.text = "%.0f" % GeneratorTuning.load_per_day
	_tol_label.text = "%.0f" % GeneratorTuning.tolerance
	_temp_label.text = "%.0f" % GeneratorTuning.temp_safe_max
	_fee_label.text = "%.1f" % GeneratorTuning.overload_fee
