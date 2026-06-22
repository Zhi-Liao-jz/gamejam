extends CanvasLayer
## 游戏内暂停菜单：按 ESC 暂停全局并弹出 继续 / 返回选关 / 返回主菜单。
## UI 在代码里搭建（与 debug_jump 一致），场景里只需挂一个空 CanvasLayer。
## 暂停用 get_tree().paused：DayManager 计时、猴子、加热台等场景节点全部冻结，本菜单设为
## PROCESS_MODE_ALWAYS 故仍能响应；切场景前务必先解除暂停。

const DAY_SELECT_SCENE := "res://scenes/menu/day_select.tscn"
const MAIN_MENU_SCENE := "res://scenes/menu/main_menu.tscn"

var _root: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时本菜单仍要响应
	layer = 5  # 盖在 HUD（layer 2）与调试层（layer 3）之上
	_build_ui()
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if _root.visible:
		_resume()
	else:
		_open()


func _open() -> void:
	_root.visible = true
	get_tree().paused = true


func _resume() -> void:
	_root.visible = false
	get_tree().paused = false


## 取消暂停并切到目标场景（务必先解除暂停，否则新场景会带着 paused 进入）。
func _go_to(scene_path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_add_button(box, "继续", _resume)
	_add_button(box, "返回选关", _go_to.bind(DAY_SELECT_SCENE))
	_add_button(box, "返回主菜单", _go_to.bind(MAIN_MENU_SCENE))


func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220.0, 40.0)
	button.pressed.connect(callback)
	parent.add_child(button)
