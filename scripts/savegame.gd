class_name Savegame
extends Resource

@export var character_name: String
@export var is_demo: = -1
@export var money: = 0
@export var last_time_played: = 0
@export var playtime: = 0.0
@export var equipments: Array[int] = []
@export var now_day:int = 1

static var current: Savegame = null

const DEFAULT_PATH: = "user://savegames"


func end_level(level_playtime: float):
	playtime += level_playtime
	save_to_file()

func load():
	last_time_played = int(Time.get_unix_time_from_system())
	save_to_file()
	current = self

func get_file_path():
	return DEFAULT_PATH + "/" + "wakuwaku" + ".tres"
	
func save_to_file():
	ResourceSaver.save(self, get_file_path())

func delete():
	DirAccess.remove_absolute(get_file_path())
