extends Node2D
## 按天数生成猴子（难度曲线）。极简：只负责"今天该有几只、不够就补"，
## 不接管猴子生命周期——每只猴自订阅 show/hide_settlement 自管显隐（规避签名不对称/首帧竞态）。

const PITCH_BY_INDEX := [1.0, 0.92, 1.08]  # 多猴音高错开防糊（对称偏移约 ±半音）
const SPAWN_X_STEP := 60.0  # 出生/逃跑点按序号沿 x 散开，靠 2D 音频 panning 辨方位

@export var monkey_scene: PackedScene


func _ready() -> void:
	EventBus.subscribe("hide_settlement", _spawn_to_target)
	# 初始生成：spawner 比 DayManager 后 ready，错过了开局那次 hide_settlement，这里补上第 1 天
	_spawn_to_target()


func _spawn_to_target() -> void:
	var want := Game.monkey_count_today()
	var have := get_tree().get_nodes_in_group("monkeys").size()
	for i in range(have, want):
		_spawn_one(i)


func _spawn_one(index: int) -> void:
	if monkey_scene == null:
		return
	var m: Monkey = monkey_scene.instantiate()
	m.audio_pitch_base = PITCH_BY_INDEX[index % PITCH_BY_INDEX.size()]
	m.exit_point.x += index * SPAWN_X_STEP  # 出生/逃跑点错开
	m.position = m.exit_point  # 显式设初始位置（新猴错过 _on_work，否则从默认点开局）
	add_child(m)
