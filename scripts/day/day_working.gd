extends BaseState
## 一天的"工作中"状态：亭内时推进抽烟进度，烟抽完进入结算。


func enter(_msg: Dictionary = {}) -> void:
	Game.reset_day()
	EventBus.push_event("hide_settlement")


func update(delta: float) -> void:
	if Game.player_in_booth:
		Game.smoke_progress += delta / Game.DAY_LENGTH
		if Game.smoke_progress >= 1.0:
			Game.smoke_progress = 1.0
			fsm.transition_to(&"Settlement")
