extends Node

@onready var continue_button: Button = %continue_button
@onready var new_game_button: Button = %new_game_button
@onready var options_button: Button = %options_button
@onready var quit_button: Button = %quit_button

@onready var main_menu_panel: PanelWithTheme = %main_menu_panel
@onready var options_panel: PanelContainer = %options_panel

func _ready() -> void:
	options_button.pressed.connect(show_sub_panel.bind(options_panel))
	options_panel.done.connect(show_sub_panel.bind(main_menu_panel))


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
