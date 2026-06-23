extends Node
## 接线盒调参（autoload 名: WiringTuning）。每关随机连接点数量 / 迷惑点，由 F3 调试面板实时改。
## 仅影响手感，不进存档；正式版保留默认值即可。

## 每侧连接点数量下限。
var min_points: int = 3
## 每侧连接点数量上限。
var max_points: int = 5
## 是否允许出现"无需连接"的迷惑点（点数 > 3 时，有一半概率留 1 个不连）。
var allow_decoy: bool = true


## 为新的一关掷一个每侧连接点数量。
func roll_point_count() -> int:
	return randi_range(min_points, max_points)
