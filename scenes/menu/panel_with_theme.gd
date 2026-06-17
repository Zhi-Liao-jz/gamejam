class_name PanelWithTheme
extends PanelContainer


static var last_focused_control
var ui_select_button
var ui_cancel_button
var ui_select_button_text
var ui_cancel_button_text
signal ui_selected
signal ui_cancelled


func _ready() -> void :
	PanelWithTheme.apply_theme(self)
	visibility_changed.connect(on_visibility_changed)


static func apply_theme(node):
	for child in node.get_children():
		apply_theme(child)
	if node is Button:
		if node.name != "quit_button":
			if not node.pressed.is_connected(SoundManager.play.bind("boop")):
				node.pressed.connect(SoundManager.play.bind("boop"))
	if node is TabContainer:
		node.tab_clicked.connect( func(_x): SoundManager.play.bind("boop"))
	if node.focus_mode != FOCUS_NONE and not node.mouse_entered.is_connected(control_mouse_entered):
		node.mouse_entered.connect(control_mouse_entered.bind(node))
		node.mouse_exited.connect(control_mouse_exited.bind(node))


static func control_mouse_entered(control: Control):
	if control.is_visible_in_tree():
		control.grab_focus()


static func control_mouse_exited(control: Control):
	if control.has_focus():
		control.release_focus()
		last_focused_control = control


func on_visibility_changed():
	if is_visible_in_tree():
		if ui_select_button:
			ui_select_button.text = tr(ui_select_button_text)
		if ui_cancel_button:
			ui_cancel_button.text = tr(ui_cancel_button_text)


func show_focus():
	if not get_viewport().gui_get_focus_owner():
		if is_instance_valid(last_focused_control) and last_focused_control.is_visible_in_tree():
			last_focused_control.grab_focus()
			last_focused_control = null
		else:
			get_focus_first_child(get_tree().get_root())


func get_focus_first_child(node = null, arr: = []):
	if not node:
		node = self
	arr.push_back(node)
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and child.focus_mode != FOCUS_NONE:
			child.grab_focus()
			return true
		if get_focus_first_child(child, arr):
			return true
	return false


func _input(event):
	if is_visible_in_tree():
		if event.is_action_pressed("ui_select") and is_instance_valid(ui_select_button):
			ui_select_button.pressed.emit()
		if event.is_action_pressed("ui_cancel") and is_instance_valid(ui_cancel_button):
			ui_cancel_button.pressed.emit()
			get_viewport().set_input_as_handled()
