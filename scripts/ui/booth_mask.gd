extends CanvasLayer
## 亭内视觉屏蔽：玩家在亭内时盖一层不透明遮罩，只留 HUD 和声音。
## 这是"摸鱼 vs 救火"核心张力的一半——亭内看不见外面，只能靠声音判断。
## 纯表现层，直接读 Game 全局状态（与 hud.gd 一致），不额外加事件。


func _ready() -> void:
	visible = Game.player_in_booth


func _process(_delta: float) -> void:
	if visible != Game.player_in_booth:
		visible = Game.player_in_booth
