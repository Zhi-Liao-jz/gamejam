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
	5: "商店、电击陷阱、捕网",
	6: "发电机、接线盒、供电影响",
}
const SHOP_EQUIPMENT: Array[int] = [Game.EQUIPMENT_SHOCK_TRAP, Game.EQUIPMENT_NET]

var _showing_shop: bool = false  # false=日期列表，true=商店；shop_button 在两者间切换

@onready var money_label: Label = %money_label
@onready var day_list: VBoxContainer = %day_list
@onready var shop_button: Button = %shop_button
@onready var back_button: Button = %back_button
@onready var shop_status: Label = %shop_status


func _ready() -> void:
	shop_button.pressed.connect(_on_shop_toggle)
	back_button.pressed.connect(_on_back_pressed)
	_refresh_view()


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


func _build_shop_items() -> void:
	money_label.text = "当前资金 $%d" % Game.money
	for child: Node in day_list.get_children():
		child.queue_free()
	for equipment_id: int in SHOP_EQUIPMENT:
		var button := Button.new()
		button.text = _shop_button_text(equipment_id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = (
			Game.has_equipment(equipment_id) or Game.money < Game.equipment_price(equipment_id)
		)
		button.pressed.connect(_buy_equipment.bind(equipment_id))
		day_list.add_child(button)


func _day_button_text(day: int) -> String:
	var cleared := "已通关" if Game.cleared_days.has(day) else "未通关"
	var best := int(Game.best_profit_by_day.get(day, 0))
	return "Day %d    %s    最高利润 $%d\n%s" % [day, cleared, best, _day_unlock_text(day)]


func _day_unlock_text(day: int) -> String:
	return DAY_UNLOCK_TEXT.get(day, "更多产品规则、更多猴子、更多设备")


func _shop_button_text(equipment_id: int) -> String:
	var owned := (
		"已拥有" if Game.has_equipment(equipment_id) else "$%d" % Game.equipment_price(equipment_id)
	)
	return (
		"%s    %s\n%s"
		% [
			Game.equipment_name(equipment_id),
			owned,
			Game.equipment_description(equipment_id),
		]
	)


func _start_day(day: int) -> void:
	Game.start_day(day)
	get_tree().change_scene_to_file(MAIN_GRID_SCENE)


## 在"日期列表"和"商店"之间切换当前视图，并同步 shop_button 文案。
func _refresh_view() -> void:
	if _showing_shop:
		_build_shop_items()
		shop_button.text = "返回选关"
	else:
		_build_day_buttons()
		shop_button.text = "商店"


func _on_shop_toggle() -> void:
	_showing_shop = not _showing_shop
	shop_status.text = "商店：购买结果会立即保存" if _showing_shop else ""
	_refresh_view()


func _buy_equipment(equipment_id: int) -> void:
	if Game.buy_equipment(equipment_id):
		shop_status.text = "已购买 %s" % Game.equipment_name(equipment_id)
	else:
		shop_status.text = "资金不足或已拥有"
	_build_shop_items()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
