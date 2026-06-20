extends Node
## 选关界面：显示已解锁天数、通关状态和最高利润；点击天数进入对应关卡。

const MAIN_MENU_SCENE: String = "res://scenes/menu/main_menu.tscn"
const MAIN_GRID_SCENE: String = "res://scenes/main_grid.tscn"
const MAX_VISIBLE_DAYS: int = 7
const DAY_UNLOCK_TEXT: Dictionary[int, String] = {
	1: "产品出口、三色交货点、点击拿放、5 分钟计时",
	2: "猴子、控制面板",
	3: "中央自爆开关、玻璃罩",
	4: "加热台",
	5: "商店、电击陷阱、捕网（后续接入）",
	6: "发电机、接线盒、供电影响",
}

@onready var money_label: Label = %money_label
@onready var day_list: VBoxContainer = %day_list
@onready var shop_button: Button = %shop_button
@onready var back_button: Button = %back_button
@onready var shop_status: Label = %shop_status


func _ready() -> void:
	_build_day_buttons()
	shop_button.pressed.connect(_on_shop_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _build_day_buttons() -> void:
	money_label.text = "当前资金 $%d" % Game.money
	for child: Node in day_list.get_children():
		child.queue_free()
	var max_day := maxi(Game.highest_unlocked_day, 1)
	for day: int in range(1, min(max_day, MAX_VISIBLE_DAYS) + 1):
		var button := Button.new()
		button.text = _day_button_text(day)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_start_day.bind(day))
		day_list.add_child(button)
	if max_day > MAX_VISIBLE_DAYS:
		var more := Label.new()
		more.text = "后续天数将在正式关卡表接入后显示"
		day_list.add_child(more)


func _day_button_text(day: int) -> String:
	var cleared := "已通关" if Game.cleared_days.has(day) else "未通关"
	var best := int(Game.best_profit_by_day.get(day, 0))
	return "Day %d    %s    最高利润 $%d\n%s" % [day, cleared, best, _day_unlock_text(day)]


func _day_unlock_text(day: int) -> String:
	return DAY_UNLOCK_TEXT.get(day, "更多产品规则、更多猴子、更多设备")


func _start_day(day: int) -> void:
	Game.start_day(day)
	get_tree().change_scene_to_file(MAIN_GRID_SCENE)


func _on_shop_pressed() -> void:
	shop_status.text = "商店系统将在装备底座阶段接入"


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
