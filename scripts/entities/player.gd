extends CharacterBody2D
## 玩家：俯视角移动 + 与最近设备交互。Demo 用色块表示。

const SIZE := Vector2(32, 32)

@export var speed: float = 220.0
@export var interact_range: float = 70.0


func _ready() -> void:
	add_to_group("player")


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var d := _nearest_device()
		if d:
			d.repair()
	elif event.is_action_pressed("tamper_debug"):
		var d := _nearest_device()
		if d:
			d.tamper()


func _nearest_device() -> BaseDevice:
	var best: BaseDevice = null
	var best_dist := interact_range
	for node: Node in get_tree().get_nodes_in_group("devices"):
		var dev := node as BaseDevice
		if dev == null:
			continue
		var dist := global_position.distance_to(dev.global_position)
		if dist <= best_dist:
			best = dev
			best_dist = dist
	return best


func _draw() -> void:
	draw_rect(Rect2(-SIZE * 0.5, SIZE), Color(0.9, 0.8, 0.2))
