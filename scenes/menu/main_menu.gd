extends Node

@onready var play_button: Button = %play_button
@onready var options_button: Button = %options_button
@onready var quit_button: Button = %quit_button

@onready var main_menu_panel: PanelWithTheme = %main_menu_panel
@onready var options_panel: PanelContainer = %options_panel


func _ready() -> void:
	_add_new_game_button()
	play_button.pressed.connect(play)

	options_button.pressed.connect(show_sub_panel.bind(options_panel))
	options_panel.done.connect(show_sub_panel.bind(main_menu_panel))

	quit_button.pressed.connect(quit)


## 代码插入"新游戏"按钮（放在"继续游戏"上方），避免手改非标准格式的 .tscn。
func _add_new_game_button() -> void:
	var btn := Button.new()
	btn.text = "新游戏"
	var box := play_button.get_parent()
	box.add_child(btn)
	box.move_child(btn, play_button.get_index())  # 移到"继续游戏"之前
	btn.pressed.connect(new_game)
	PanelWithTheme.apply_theme(btn)  # 套点击音/焦点，与其它按钮一致


func play() -> void:
	# Game(autoload)已在启动时 load_from_save，主场景直接从存档进度开局（继续游戏）
	get_tree().change_scene_to_file("res://scenes/main_grid.tscn")


func new_game() -> void:
	Game.reset_new_game()  # 删档、状态归零、从第 1 天开
	get_tree().change_scene_to_file("res://scenes/main_grid.tscn")


func show_sub_panel(panel):
	for p in [main_menu_panel, options_panel]:
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
