extends PanelWithTheme
signal done()

@onready var tabs: TabContainer = %tabs

@onready var cancel_button: Button = %cancel_button
@onready var ok_button: Button = %ok_button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ui_select_button = ok_button
	ui_cancel_button = cancel_button
	ui_select_button_text = "确认"
	ui_cancel_button_text = "取消"
	
	ok_button.pressed.connect(apply_config)
	cancel_button.pressed.connect(trigger_done)
	
	pass # Replace with function body.



func show_panel():
	show()
	tabs.get_tab_bar().grab_focus()

func apply_config():
	trigger_done()

func trigger_done():
	hide()
	done.emit()
