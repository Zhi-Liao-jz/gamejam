extends Control
## 2.0 监控 HUD：顶部信息条（天数/存款/交货进度/手持）+ 九宫格小地图（当前房间高亮）+ 当天结算面板。

const MINIMAP_CELL := Vector2(54.0, 40.0)
const MINIMAP_GAP := 6.0
const MINIMAP_ORIGIN := Vector2(20.0, 100.0)  # 小地图左上角（信息条下方）

var _current_room: int = RoomManager.START_ROOM
var _held_text: String = "空手"
var _closed_panels: Dictionary = {}  # room_id -> true：当前被关闭的面板（小地图红框警告）

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
	_refresh_info()


func _process(_delta: float) -> void:
	_refresh_info()
	queue_redraw()  # 猴子位置 / 面板警告每帧轻量重绘（小地图仅 9 格，开销可忽略）


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


func _refresh_info() -> void:
	var room_name := String(RoomManager.LAYOUT[_current_room]["name"])
	var monkeys := get_tree().get_nodes_in_group("grid_monkeys").size()
	var warn := ""
	if not _closed_panels.is_empty() or monkeys > 0:
		warn = "\n⚠ 关闭面板 %d    猴子 %d" % [_closed_panels.size(), monkeys]
	info_label.text = (
		(
			"第 %d 天    存款 $%d\n交货 %d / %d    今日收入 $%d\n监控中：%s    手持：%s\n"
			+ "[WASD] 切监控    [左键] 拿放 / 重开面板 / 赶猴%s"
		)
		% [
			Game.day,
			Game.money,
			Ledger.delivered_today,
			Ledger.quota_today(),
			Ledger.income_today,
			room_name,
			_held_text,
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


func _on_day_summary(data: Dictionary) -> void:
	summary_panel.visible = true
	summary_label.text = (
		"第 %d 天 完成！\n\n交货 %d / %d\n今日收入 $%d\n\n[N] 进入下一天"
		% [data["day"], data["delivered"], data["quota"], data["income"]]
	)


func _on_hide_day_summary() -> void:
	summary_panel.visible = false
