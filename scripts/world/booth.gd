extends Area2D
## 保安亭：玩家进入后才推进抽烟进度。Demo 用半透明色块表示。


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		Game.player_in_booth = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		Game.player_in_booth = false


func _draw() -> void:
	draw_rect(Rect2(-80, -60, 160, 120), Color(0.2, 0.4, 0.6, 0.5))
