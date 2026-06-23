extends Node
## 调试面板（playtest 用，发行版自动禁用）：调加热台激光几何。
## F4 显示 / 隐藏。改动写入 HeaterTuning（autoload），即时生效。

const STEP_GAP := 2.0  # LaserGap 每次 ±2
const STEP_FACTOR := 0.1  # 反射镜倍数每次 ±0.1
const PANEL_POS := Vector2(900.0, 600.0)

var _panel: PanelContainer = null
var _gap_label: Label = null
var _factor_label: Label = null


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_build_ui()
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F4:
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
	title.text = "🔥 加热台调参 (F4 隐藏)"
	box.add_child(title)

	_gap_label = Label.new()
	box.add_child(
		_make_row("LaserGap", _gap_label, _add_gap.bind(-STEP_GAP), _add_gap.bind(STEP_GAP))
	)
	_factor_label = Label.new()
	box.add_child(
		_make_row(
			"反射镜倍数", _factor_label, _add_factor.bind(-STEP_FACTOR), _add_factor.bind(STEP_FACTOR)
		)
	)


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
	value_label.custom_minimum_size = Vector2(48.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	var plus := Button.new()
	plus.text = " + "
	plus.pressed.connect(on_plus)
	row.add_child(plus)
	return row


func _add_gap(delta: float) -> void:
	HeaterTuning.laser_gap = clampf(HeaterTuning.laser_gap + delta, 10.0, 60.0)
	_refresh()


func _add_factor(delta: float) -> void:
	HeaterTuning.mirror_factor = clampf(HeaterTuning.mirror_factor + delta, 0.5, 3.0)
	_refresh()


func _refresh() -> void:
	_gap_label.text = "%.0f" % HeaterTuning.laser_gap
	_factor_label.text = "%.1f" % HeaterTuning.mirror_factor
