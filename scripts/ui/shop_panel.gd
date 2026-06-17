extends Control
## 装备商店（灰盒，代码构建 UI）。逛店买装备花 money。
## 仿 generator_panel，但【不】订阅 settlement 事件——由 day_shop 经 open_shop/close_shop 自管显隐，
## 否则会被"进下一天"时的 hide_settlement 强制关掉。

var _rows: Array[Dictionary] = []  # 每行: {id, button}
var _money_label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	EventBus.subscribe("open_shop", _on_open)
	EventBus.subscribe("close_shop", _on_close)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)

	var panel := PanelContainer.new()
	panel.add_child(margin)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(480, 0)
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "装备商店    [N / Enter 进入下一天]"
	vbox.add_child(title)

	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_money_label)

	for id: int in Game.EQUIPMENT:
		var info: Dictionary = Game.EQUIPMENT[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vbox.add_child(row)
		var label := Label.new()
		label.custom_minimum_size = Vector2(360, 0)
		label.text = "%s  $%d\n%s" % [info["name"], info["price"], info["desc"]]
		row.add_child(label)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110, 0)
		btn.pressed.connect(_on_buy.bind(id))
		row.add_child(btn)
		_rows.append({"id": id, "button": btn})


func _on_open(_data = null) -> void:
	visible = true
	_refresh()


func _on_close(_data = null) -> void:
	visible = false


func _on_buy(id: int) -> void:
	Game.buy_equipment(id)
	_refresh()


func _refresh() -> void:
	_money_label.text = "存款 $%d" % Game.money
	for row in _rows:
		var id: int = row["id"]
		var btn: Button = row["button"]
		var price := int(Game.EQUIPMENT[id]["price"])
		if Game.has_equipment(id):
			btn.text = "已拥有"
			btn.disabled = true
		elif Game.money < price:
			btn.text = "$%d 钱不够" % price
			btn.disabled = true
		else:
			btn.text = "购买 $%d" % price
			btn.disabled = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# 仅消费防穿透到 player；转场/关店由 day_shop.update 独占
	if event.is_action_pressed("next_day") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
