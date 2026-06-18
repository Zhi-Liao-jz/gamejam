extends Control
## 2.0 监控 HUD：顶部信息条 + 九宫格小地图（当前监控房间高亮）。
## 非当前房间后续在小地图上显示警告点 / 声音提示；P0 先只做"当前高亮 + 房间名"。

const MINIMAP_CELL := Vector2(54.0, 40.0)
const MINIMAP_GAP := 6.0
const MINIMAP_ORIGIN := Vector2(20.0, 78.0)  # 小地图左上角（信息条下方）

var _current_room: int = RoomManager.START_ROOM

@onready var info_label: Label = $InfoLabel


func _ready() -> void:
	EventBus.subscribe("room_changed", _on_room_changed)
	_refresh_info()


func _draw() -> void:
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


func _refresh_info() -> void:
	var room_name := String(RoomManager.LAYOUT[_current_room]["name"])
	info_label.text = (
		"第 %d 天    存款 $%d\n监控中：%s\n[WASD] 切换监控房间" % [Game.day, Game.money, room_name]
	)


func _on_room_changed(room_id: int, _room_name: String) -> void:
	_current_room = room_id
	_refresh_info()
	queue_redraw()
