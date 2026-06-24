class_name RoomLayoutResource
extends Resource
## 九宫格房间布局配置。用于把房间名称、用途、颜色和位置从 RoomManager 中拆出来。

@export var grid_cols: int = 3
@export var grid_rows: int = 3
@export var cell_gap: Vector2 = Vector2(160.0, 160.0)
@export var start_room: int = 4
@export var panel_local: Vector2 = Vector2(150.0, -95.0)
@export var rooms: Array[RoomDefinition] = []


func room_count() -> int:
	return rooms.size()


func room_at(room_id: int) -> RoomDefinition:
	if room_id < 0 or room_id >= rooms.size():
		return null
	return rooms[room_id]


func room_name(room_id: int) -> String:
	var definition := room_at(room_id)
	if definition == null:
		return ""
	return definition.display_name


func room_id_at(grid_pos: Vector2i) -> int:
	for i: int in rooms.size():
		var definition := rooms[i]
		if definition != null and definition.grid_pos == grid_pos:
			return i
	return -1
