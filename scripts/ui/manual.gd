extends Node
## 手册（阶段4）：按 Tab 打开 / 关闭，打开时暂停游戏（倒计时 / 猴子 / 加工 / 维护费全部冻结）。
## 当前只含一页：接线盒正确连接的"真实面板截图"——用 SubViewport 渲染只读 WiringView 再取其纹理，
## 每关开局（work_started）按本关正确连接重渲一次并冻结，之后玩家/猴子改线都不影响这张参考图。

const VIEW_SIZE := Vector2i(380, 240)

var _layer: CanvasLayer = null
var _root: Control = null
var _subviewport: SubViewport = null
var _preview_view: WiringView = null
var _texture_rect: TextureRect = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时仍要响应 Tab
	_build_ui()
	_root.visible = false
	EventBus.subscribe("work_started", _on_work_started)
	_refresh_preview()  # 初始渲染一次（场景就绪时接线盒已存在）


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_TAB:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if _root.visible:
		_close()
	else:
		_open()


func _open() -> void:
	_refresh_preview()
	_root.visible = true
	get_tree().paused = true


func _close() -> void:
	_root.visible = false
	get_tree().paused = false


func _on_work_started() -> void:
	_refresh_preview()


## 用本关接线盒的"正确连接"重渲 SubViewport 并冻结（UPDATE_ONCE）。
func _refresh_preview() -> void:
	var box := get_tree().get_first_node_in_group("wiring") as WiringBox
	if box == null:
		return
	_preview_view.box = null  # 只读模式
	_preview_view.ro_count = box.point_count
	_preview_view.ro_connections = box.correct.duplicate()
	_preview_view.queue_redraw()
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 6  # 盖在暂停菜单(5) 之上
	add_child(_layer)

	_subviewport = SubViewport.new()
	_subviewport.size = VIEW_SIZE
	_subviewport.transparent_bg = true
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_layer.add_child(_subviewport)
	_preview_view = WiringView.new()
	_preview_view.size = Vector2(VIEW_SIZE)
	_subviewport.add_child(_preview_view)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "📖 手册 · 接线盒参考图"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	_texture_rect = TextureRect.new()
	_texture_rect.texture = _subviewport.get_texture()
	_texture_rect.custom_minimum_size = Vector2(VIEW_SIZE)
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(_texture_rect)

	var caption := Label.new()
	caption.text = "本关正确接线（按此还原接线盒面板）"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(caption)

	var hint := Label.new()
	hint.text = "再按 Tab 关闭"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
