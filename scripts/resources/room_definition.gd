class_name RoomDefinition
extends Resource
## 单个九宫格房间的静态配置。运行时状态仍由 Room 节点持有。

@export var room_id: int = 0
@export var grid_pos: Vector2i = Vector2i.ZERO
@export var role: StringName = &"empty"
@export var display_name: String = ""
@export var accent: Color = Color(0.5, 0.5, 0.5)
@export var color_key: StringName = &""
