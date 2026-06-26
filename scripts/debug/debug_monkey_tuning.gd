extends Node
## 调试面板（playtest 用，正式版删除本节点 + 脚本）：实时调猴子行为旋钮。
## F1 显示 / 隐藏。所有改动写入 MonkeyTuning（autoload），即时生效、不进存档。

const STEP_CHANCE := 0.1  # 修复概率每次 ±10%
const STEP_LOCK := 1.0  # 作业冷却每次 ±1s
const PANEL_POS := Vector2(655.0, 12.0)

var _panel: PanelContainer = null
var _chance_label: Label = null
var _lock_label: Label = null


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
	if key.keycode == KEY_F1:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)

	_panel = PanelContainer.new()
	_panel.position = PANEL_POS
	_panel.theme = _compact_theme()
	layer.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "🐒 猴子调参 (F1 隐藏)"
	box.add_child(title)

	_chance_label = Label.new()
	box.add_child(
		_make_row(
			"修复概率", _chance_label, _add_chance.bind(-STEP_CHANCE), _add_chance.bind(STEP_CHANCE)
		)
	)

	_lock_label = Label.new()
	box.add_child(
		_make_row("作业冷却", _lock_label, _add_lock.bind(-STEP_LOCK), _add_lock.bind(STEP_LOCK))
	)

	var flee_button := CheckButton.new()
	flee_button.text = "得手后逃跑（关=换房间）"
	flee_button.button_pressed = MonkeyTuning.flee_after_action
	flee_button.toggled.connect(_on_flee_toggled)
	box.add_child(flee_button)


## 紧凑小字号主题：覆盖项目自定义大字体，避免调试面板撑高重叠。
func _compact_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 14
	return t


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
	value_label.custom_minimum_size = Vector2(48.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	var plus := Button.new()
	plus.text = " + "
	plus.pressed.connect(on_plus)
	row.add_child(plus)
	return row


func _add_chance(delta: float) -> void:
	MonkeyTuning.repair_chance = clampf(MonkeyTuning.repair_chance + delta, 0.0, 1.0)
	_refresh()


func _add_lock(delta: float) -> void:
	MonkeyTuning.recent_device_lock = clampf(MonkeyTuning.recent_device_lock + delta, 0.0, 30.0)
	_refresh()


func _on_flee_toggled(pressed: bool) -> void:
	MonkeyTuning.flee_after_action = pressed


func _refresh() -> void:
	_chance_label.text = "%d%%" % roundi(MonkeyTuning.repair_chance * 100.0)
	_lock_label.text = "%.0fs" % MonkeyTuning.recent_device_lock
