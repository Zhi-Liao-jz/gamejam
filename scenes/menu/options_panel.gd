extends PanelWithTheme
signal done()

@onready var tabs: TabContainer = %tabs
@onready var graphics: MarginContainer = %graphics_
@onready var audio: MarginContainer = %audio_

@onready var cancel_button: Button = %cancel_button
@onready var ok_button: Button = %ok_button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	graphics.name="显示"
	audio.name="声音"
	
	ui_select_button = ok_button
	ui_cancel_button = cancel_button
	ui_select_button_text = "确认"
	ui_cancel_button_text = "取消"
	
	visibility_changed.connect(update_from_config)
	
	ok_button.pressed.connect(apply_config)
	cancel_button.pressed.connect(trigger_done)
	
	super()



func show_panel():
	show()
	tabs.get_tab_bar().grab_focus()

func update_from_config():
	if visible:
		pass

func apply_config():
	trigger_done()

func trigger_done():
	hide()
	done.emit()
