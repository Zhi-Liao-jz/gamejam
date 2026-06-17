extends Node

@onready var play_button: Button = %play_button
@onready var options_button: Button = %options_button
@onready var quit_button: Button = %quit_button

@onready var main_menu_panel: PanelWithTheme = %main_menu_panel
@onready var options_panel: PanelContainer = %options_panel

func _ready() -> void:
	play_button.pressed.connect(play)
	
	options_button.pressed.connect(show_sub_panel.bind(options_panel))
	options_panel.done.connect(show_sub_panel.bind(main_menu_panel))
	
	quit_button.pressed.connect(quit)

func play() -> void:
	pass
func show_sub_panel(panel):
	for p in [main_menu_panel,options_panel]:
		if p == panel:
			if p == main_menu_panel:
				main_menu_panel.show()
			else:
				main_menu_panel.show_focus()
				p.show_panel()
		else:
			p.hide()
		

func quit():
	get_tree().quit()
