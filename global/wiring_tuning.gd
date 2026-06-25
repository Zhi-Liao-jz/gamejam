extends Node
## 接线盒调参（autoload 名: WiringTuning）。每关随机连接点数量 / 迷惑点，由 F3 调试面板实时改。
## 当前作为 GameConfig.wiring 的兼容代理。

## 每侧连接点数量下限。
var min_points: int:
	get:
		return GameConfig.wiring().min_points
	set(value):
		GameConfig.wiring().min_points = value
## 每侧连接点数量上限。
var max_points: int:
	get:
		return GameConfig.wiring().max_points
	set(value):
		GameConfig.wiring().max_points = value
## 是否允许出现"无需连接"的迷惑点（点数 > 3 时，有一半概率留 1 个不连）。
var allow_decoy: bool:
	get:
		return GameConfig.wiring().allow_decoy
	set(value):
		GameConfig.wiring().allow_decoy = value


## 为新的一关掷一个每侧连接点数量。
func roll_point_count() -> int:
	return GameConfig.wiring().roll_point_count()
