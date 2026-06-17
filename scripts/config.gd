class_name Config
extends Resource

@export var master_volume: = 1.0
@export var sound_effects_volume: = 0.5
@export var music_volume: = 0.5

const DEFAULT_PATH: = "user://config.tres"
const DEFAULT_ICON_PATH: = "user://config_icon.tres"

static var config: = Config.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

static func initialize(tree: SceneTree):
	var new_config = Config.load_from_file()
	new_config.apply(tree)

static func load_from_file(path: = DEFAULT_PATH):
	var new_config
	if FileAccess.file_exists(path):
		new_config = load(path)
	if not new_config:
		return Config.new()
	return new_config

func apply(tree: SceneTree):
	config = self
	SoundManager.volume_effects(linear_to_db(sound_effects_volume * master_volume))
	#Sound.volume_music(linear_to_db(music_volume * master_volume))
