class_name TextureVisual
extends Node2D
## 通用贴图视觉节点：在 Inspector 中配置默认贴图和状态贴图，逻辑脚本只负责传入状态。

@export var default_texture: Texture2D:
	set(value):
		default_texture = value
		_apply_current_state()
@export var state_textures: Dictionary[StringName, Texture2D] = {}:
	set(value):
		state_textures = value
		_apply_current_state()

var _current_state: StringName = &""

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_apply_current_state()


func has_texture() -> bool:
	return default_texture != null or not state_textures.is_empty()


func apply_state(state: StringName) -> void:
	_current_state = state
	_apply_current_state()


func _apply_current_state() -> void:
	if not is_node_ready():
		return
	var texture: Texture2D = state_textures.get(_current_state, default_texture)
	sprite.texture = texture
	visible = texture != null
