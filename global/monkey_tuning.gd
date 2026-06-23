extends Node
## 猴子行为调参（autoload 名: MonkeyTuning）。集中存放可实时调整的手感旋钮，
## 由调试面板（DebugMonkeyTuning）即时修改。仅影响手感，不进存档；正式版保留默认值即可。

## 房间内只剩"修复/还原"类动作时，猴子愿意去修的概率；其余情况转身离开。越低 = 越爱破坏少修。
var repair_chance: float = 0.3
## 刚作业过的设备，多少秒内不再下手——防止猴子绕一圈回来立刻把自己刚改的撤销。
var recent_device_lock: float = 3.0
## 得手后行为：true = 逃到边缘冷却（脉冲压力）；false = 直接换个房间继续（持续压力）。
var flee_after_action: bool = false


## 掷一次"是否愿意修复"。
func roll_repair() -> bool:
	return randf() < repair_chance
