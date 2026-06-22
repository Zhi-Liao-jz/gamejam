extends Control
## 2.0 监控 HUD：顶部信息条（天数/存款/交货进度/手持）+ 九宫格小地图（当前房间高亮）+ 当天结算面板。

const MINIMAP_CELL := Vector2(54.0, 40.0)
const MINIMAP_GAP := 6.0
const MINIMAP_ORIGIN := Vector2(20.0, 100.0)  # 小地图左上角（信息条下方）
const HUD_EQUIPMENT: Array[int] = [Game.EQUIPMENT_SHOCK_TRAP, Game.EQUIPMENT_NET]
const TRAP_TOAST_DURATION := 2.5  # 电击陷阱触发提示 / 小地图闪烁持续秒数

var _current_room: int = RoomManager.START_ROOM
var _held_text: String = "空手"
var _closed_panels: Dictionary = {}  # room_id -> true：当前被关闭的面板（小地图红框警告）
var _sd_state: int = SelfDestruct.State.PROTECTED  # 中央自爆状态（每帧轮询自分组）
var _sd_remaining: float = 0.0
var _sd_room: int = -1
var _heater_state: int = Heater.State.OFF
var _heater_room: int = -1
var _power_outage: bool = false  # 是否停电
var _power_room: int = -1  # 发电机房间 id
var _power_fault_text: String = ""
var _trap_toast_left: float = 0.0  # 电击陷阱触发提示剩余显示时间
var _trap_flash_room: int = -1  # 触发陷阱的房间 id（小地图黄框闪烁）

@onready var info_label: Label = $InfoLabel
@onready var summary_panel: Panel = $SummaryPanel
@onready var summary_label: Label = $SummaryPanel/Label


func _ready() -> void:
	summary_panel.visible = false
	EventBus.subscribe("room_changed", _on_room_changed)
	EventBus.subscribe("hand_changed", _on_hand_changed)
	EventBus.subscribe("day_summary", _on_day_summary)
	EventBus.subscribe("hide_day_summary", _on_hide_day_summary)
	EventBus.subscribe("panel_changed", _on_panel_changed)
	EventBus.subscribe("day_failed", _on_day_failed)
	EventBus.subscribe("shock_trap_triggered", _on_shock_trap_triggered)
	for i: int in RoomManager.LAYOUT.size():
		if RoomManager.LAYOUT[i]["role"] == &"heater":
			_heater_room = i
	_refresh_info()


func _process(delta: float) -> void:
	if _trap_toast_left > 0.0:
		_trap_toast_left = maxf(0.0, _trap_toast_left - delta)
	_poll_self_destruct()
	_poll_heater()
	_poll_power()
	_refresh_info()
	queue_redraw()  # 猴子位置 / 面板 / 自爆警告每帧轻量重绘（小地图仅 9 格，开销可忽略）


func _draw() -> void:
	var monkey_rooms := _monkey_room_set()
	for i: int in RoomManager.LAYOUT.size():
		var data: Dictionary = RoomManager.LAYOUT[i]
		var grid: Vector2i = data["grid"]
		var top_left := (
			MINIMAP_ORIGIN
			+ Vector2(
				grid.x * (MINIMAP_CELL.x + MINIMAP_GAP), grid.y * (MINIMAP_CELL.y + MINIMAP_GAP)
			)
		)
		var rect := Rect2(top_left, MINIMAP_CELL)
		var color: Color = data["color"]
		var is_current := i == _current_room
		draw_rect(rect, color if is_current else color.darkened(0.45))
		if is_current:
			draw_rect(rect, Color.WHITE, false, 3.0)
		else:
			draw_rect(rect, color.darkened(0.1), false, 1.0)
		if _closed_panels.has(i):
			draw_rect(rect, Color(0.95, 0.30, 0.20), false, 4.0)  # 面板关闭：红框警告
		if i == _sd_room and _sd_state != SelfDestruct.State.PROTECTED:
			draw_rect(rect, Color(1.0, 0.10, 0.10), false, 5.0)  # 自爆罩被开 / 倒计时：粗红框
		if i == _power_room and _power_outage:
			draw_rect(rect, Color(0.95, 0.35, 0.10), false, 5.0)  # 停电：橙红粗框
		if i == _heater_room and _heater_state == Heater.State.BURNED:
			draw_rect(rect, Color(0.10, 0.10, 0.10), false, 5.0)  # 产品烧坏：黑框
		if i == _trap_flash_room and _trap_toast_left > 0.0:
			draw_rect(rect, Color(1.0, 0.95, 0.20), false, 5.0)  # 电击陷阱触发：黄框
		if monkey_rooms.has(i):
			draw_circle(top_left + MINIMAP_CELL - Vector2(11.0, 11.0), 5.0, Color(0.62, 0.40, 0.20))


## 当前各房间是否有猴子（小地图棕点）；每帧从分组实时取。
func _monkey_room_set() -> Dictionary:
	var rooms := {}
	for node: Node in get_tree().get_nodes_in_group("grid_monkeys"):
		var monkey := node as GridMonkey
		if monkey:
			rooms[monkey.current_room] = true
	return rooms


## 轮询中央自爆开关状态（供 HUD 倒计时 + 小地图警告）。
func _poll_self_destruct() -> void:
	var sd := get_tree().get_first_node_in_group("self_destruct") as SelfDestruct
	if sd != null:
		_sd_state = sd.state
		_sd_remaining = sd.remaining()
		_sd_room = sd.room_id
	else:
		_sd_state = SelfDestruct.State.PROTECTED
		_sd_room = -1


## 轮询加热台状态（供 HUD 过热 / 烧坏提示）。
func _poll_heater() -> void:
	for node: Node in get_tree().get_nodes_in_group("devices"):
		var heater := node as Heater
		if heater == null:
			continue
		_heater_state = heater.state
		_heater_room = heater.room_id
		return
	_heater_state = Heater.State.OFF


## 轮询发电机状态（供 HUD 停电提示 + 小地图警告）。
func _poll_power() -> void:
	var pw := get_tree().get_first_node_in_group("power") as PowerBox
	if pw != null:
		_power_outage = pw.is_outage()
		_power_room = pw.room_id
		_power_fault_text = pw.fault_text()
	else:
		_power_outage = false
		_power_room = -1
		_power_fault_text = ""


func _refresh_info() -> void:
	var room_name := String(RoomManager.LAYOUT[_current_room]["name"])
	var monkeys := get_tree().get_nodes_in_group("grid_monkeys").size()
	var warn := ""
	if not _closed_panels.is_empty() or monkeys > 0:
		warn += "\n⚠ 关闭面板 %d    猴子 %d" % [_closed_panels.size(), monkeys]
	if _sd_state == SelfDestruct.State.ARMED:
		warn += "\n💥 自爆倒计时 %.1f 秒！切到中央取消" % _sd_remaining
	elif _sd_state == SelfDestruct.State.EXPOSED:
		warn += "\n⚠ 中央玻璃罩被打开！切到中央关上"
	if (
		_heater_state == Heater.State.OVERHEAT_HEATING
		or _heater_state == Heater.State.OVERHEAT_DONE
	):
		warn += "\n🔥 加热台过热！及时取走产品或关停"
	elif _heater_state == Heater.State.BURNED:
		warn += "\n🔥 加热台产品烧坏！"
	if _power_outage:
		warn += "\n⚡ %s！产品出口 / 加热台停摆，切到右下修复" % _power_fault_text
	if _trap_toast_left > 0.0:
		warn += "\n⚡ 电击陷阱触发！%s 的猴子被打断逃跑" % _trap_flash_room_name()
	info_label.text = (
		(
			"第 %d 天    剩余 %s    存款 $%d\n今日利润 $%d    交货 %d / %d    连击 %d    小费 $%d\n监控中：%s    手持：%s\n"
			+ "装备：%s\n"
			+ "[WASD] 切监控    [左键] 拿放 / 出口出货 / 重开面板 / 赶猴%s"
		)
		% [
			Game.day,
			_format_time(Ledger.time_left),
			Game.money,
			Ledger.profit_today,
			Ledger.delivered_today,
			Ledger.quota_today(),
			Ledger.combo_count,
			Ledger.current_combo_tip(),
			room_name,
			_held_text,
			_equipment_text(),
			warn,
		]
	)


func _on_room_changed(room_id: int, _room_name: String) -> void:
	_current_room = room_id
	queue_redraw()


func _on_hand_changed(is_holding: bool, color_name: String) -> void:
	_held_text = color_name if is_holding else "空手"


func _on_panel_changed(room_id: int, is_open: bool) -> void:
	if is_open:
		_closed_panels.erase(room_id)
	else:
		_closed_panels[room_id] = true


func _on_shock_trap_triggered(room_id: int) -> void:
	_trap_toast_left = TRAP_TOAST_DURATION
	_trap_flash_room = room_id


func _on_day_summary(data: Dictionary) -> void:
	summary_panel.visible = true
	summary_label.text = (
		(
			"✅ 第 %d 天 达标通关！\n\n"
			+ "交货 %d / %d\n"
			+ "当前连击 %d\n"
			+ "基础收益 +$%d\n"
			+ "连击小费 +$%d\n"
			+ "产品成本 -$%d\n"
			+ "误交 %d    损坏 %d\n"
			+ "今日利润 $%d\n\n"
			+ "[N] 进入下一天"
		)
		% [
			data["day"],
			data["delivered"],
			data["quota"],
			data["combo"],
			data["base_reward"],
			data["tip"],
			data["cost"],
			data["wrong"],
			data["damaged"],
			data["profit"],
		]
	)


func _on_hide_day_summary() -> void:
	summary_panel.visible = false


func _on_day_failed(data: Dictionary) -> void:
	summary_panel.visible = true
	var reason := String(data.get("reason", "self_destruct"))
	var reason_text := "未达成今日交货目标" if reason == "quota" else "自爆未能阻止"
	summary_label.text = (
		"💥 第 %d 天 失败！\n\n%s\n交货 %d / %d\n\n[N] 重试本日"
		% [data["day"], reason_text, data["delivered"], data["quota"]]
	)


func _trap_flash_room_name() -> String:
	if _trap_flash_room < 0 or _trap_flash_room >= RoomManager.LAYOUT.size():
		return ""
	return String(RoomManager.LAYOUT[_trap_flash_room]["name"])


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(ceil(seconds)))
	var minutes := total / 60
	var secs := total % 60
	return "%02d:%02d" % [minutes, secs]


func _equipment_text() -> String:
	var parts: Array[String] = []
	parts.append("当前 %s" % _selected_equipment_text())
	for equipment_id: int in HUD_EQUIPMENT:
		if not Game.has_equipment(equipment_id):
			parts.append("%s 未拥有" % Game.equipment_name(equipment_id))
			continue
		var usable_tag := "可用" if Game.equipment_count(equipment_id) > 0 else "用尽"
		var equipment_status := (
			"%s %d/%d %s 补给 %s"
			% [
				Game.equipment_name(equipment_id),
				Game.equipment_count(equipment_id),
				Game.equipment_max_count(equipment_id),
				usable_tag,
				_format_time(Game.equipment_refill_remaining(equipment_id)),
			]
		)
		parts.append(equipment_status)
	return "    ".join(parts)


func _selected_equipment_text() -> String:
	match Game.selected_equipment:
		Game.EQUIPMENT_SHOCK_TRAP:
			return "电击陷阱(Z)"
		Game.EQUIPMENT_NET:
			return "捕网(X)"
		_:
			return "未选(Z/X)"
