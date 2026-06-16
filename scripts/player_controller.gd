extends CharacterBody2D
class_name PlayerController

@export var speed: float = 170.0

var inside_booth: bool = false
var _facing: Vector2 = Vector2.DOWN


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	collision.shape = shape
	add_child(collision)

	queue_redraw()


func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length() > 0.01:
		_facing = input_vector.normalized()

	velocity = input_vector * speed
	move_and_slide()
	queue_redraw()


func set_inside_booth(value: bool) -> void:
	inside_booth = value
	speed = 120.0 if inside_booth else 170.0
	queue_redraw()


func _draw() -> void:
	var coat_color := Color(0.22, 0.54, 0.66) if not inside_booth else Color(0.48, 0.62, 0.68)
	var skin_color := Color(0.88, 0.70, 0.50)
	var cap_color := Color(0.08, 0.12, 0.16)
	var badge_color := Color(0.95, 0.79, 0.28)

	draw_circle(Vector2.ZERO, 12.0, coat_color)
	draw_circle(Vector2(0.0, -7.0), 6.0, skin_color)
	draw_circle(Vector2(0.0, -11.0), 4.5, cap_color)
	draw_circle(Vector2(5.0, 1.0), 2.2, badge_color)
	draw_line(Vector2.ZERO, _facing * 15.0, Color(0.05, 0.07, 0.08), 2.0)
