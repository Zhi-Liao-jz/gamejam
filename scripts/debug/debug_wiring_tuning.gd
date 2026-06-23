extends Node
## 调试面板（playtest 用，发行版自动禁用）：调接线盒每侧连接点数量范围。
## F3 显示 / 隐藏。改动写入 WiringTuning（autoload），下一关（work_started）生效。

const PANEL_POS := Vector2(900.0, 480.0)

var _panel: PanelContainer = null
var _min_label: Label = null
var _max_label: Label = null


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
	if key.keycode == KEY_F3:
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
	title.text = "🔌 接线盒调参 (F3 隐藏)"
	box.add_child(title)

	_min_label = Label.new()
	box.add_child(_make_row("最小点数", _min_label, _add_min.bind(-1), _add_min.bind(1)))
	_max_label = Label.new()
	box.add_child(_make_row("最大点数", _max_label, _add_max.bind(-1), _add_max.bind(1)))

	var decoy_button := CheckButton.new()
	decoy_button.text = "允许迷惑点"
	decoy_button.button_pressed = WiringTuning.allow_decoy
	decoy_button.toggled.connect(_on_decoy_toggled)
	box.add_child(decoy_button)

	var note := Label.new()
	note.text = "下一关生效"
	box.add_child(note)


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
	value_label.custom_minimum_size = Vector2(40.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	var plus := Button.new()
	plus.text = " + "
	plus.pressed.connect(on_plus)
	row.add_child(plus)
	return row


func _add_min(delta: int) -> void:
	WiringTuning.min_points = clampi(WiringTuning.min_points + delta, 2, WiringTuning.max_points)
	_refresh()


func _add_max(delta: int) -> void:
	WiringTuning.max_points = clampi(WiringTuning.max_points + delta, WiringTuning.min_points, 8)
	_refresh()


func _on_decoy_toggled(pressed: bool) -> void:
	WiringTuning.allow_decoy = pressed


func _refresh() -> void:
	_min_label.text = "%d" % WiringTuning.min_points
	_max_label.text = "%d" % WiringTuning.max_points
