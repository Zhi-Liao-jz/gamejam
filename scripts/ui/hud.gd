extends CanvasLayer
## HUD：抽烟进度条、状态信息、结算面板。读 Game 取数据，订阅 EventBus 取事件。

@onready var smoke_bar: ProgressBar = $SmokeBar
@onready var status_label: Label = $StatusLabel
@onready var settlement: Panel = $SettlementPanel
@onready var settlement_label: Label = $SettlementPanel/Label


func _ready() -> void:
	settlement.visible = false
	EventBus.subscribe("show_settlement", _on_show_settlement)
	EventBus.subscribe("hide_settlement", _on_hide_settlement)


func _process(_delta: float) -> void:
	smoke_bar.value = Game.smoke_progress * 100.0
	var status := _build_status()
	if status != status_label.text:
		status_label.text = status


func _build_status() -> String:
	var loc := "亭内（摸鱼中）" if Game.player_in_booth else "亭外"
	var lines := PackedStringArray()
	lines.append("第 %d 天    存款 $%d" % [Game.day, Game.money])
	lines.append("位置：%s" % loc)
	lines.append("今日维修费 $%d   损失 $%d" % [Game.today_repair_cost, int(Game.today_loss)])
	for node: Node in get_tree().get_nodes_in_group("devices"):
		var dev := node as BaseDevice
		if dev:
			lines.append("%s：%s" % [dev.device_name, dev.state_text()])
	# 警报器：亭内黑屏时把"哪台出事 + 致命倒计时"显式列出来（未拥有则只能靠声音）
	if Game.has_equipment(Game.EQUIP_ALARM):
		for node: Node in get_tree().get_nodes_in_group("devices"):
			var dev := node as BaseDevice
			if dev and dev.state != BaseDevice.DeviceState.NORMAL:
				var warn := "⚠ %s · %s" % [dev.device_name, dev.state_text()]
				if dev.state == BaseDevice.DeviceState.SEVERE:
					warn += " 致命 %.1fs" % dev.severe_remaining()
				lines.append(warn)
	return "\n".join(lines)


func _on_show_settlement(data: Dictionary) -> void:
	settlement.visible = true
	var outcome: String = data.get("outcome", "win_day")
	var header := ""
	var footer := "[N] 进商店 → 下一天      [R] 重试当天"
	var rating_line := ""
	match outcome:
		"fail_fatal":
			header = "⚠ 设备彻底损坏 · 当天作废\n\n"
			footer = "[R] 重试当天"
		"fail_bankrupt":
			header = "⚠ 资不抵债 · 破产\n\n"
			footer = "[R] 重试当天"
		_:
			rating_line = "\n评价：%s" % data.get("rating", "")
	settlement_label.text = (
		header
		+ (
			"今日结算\n\n基础工资：$%d\n维修费：-$%d\n设备损失：-$%d\n--------------------\n当天收入：$%d%s\n\n%s"
			% [data["base"], data["repair"], data["loss"], data["wage"], rating_line, footer]
		)
	)


func _on_hide_settlement() -> void:
	settlement.visible = false
