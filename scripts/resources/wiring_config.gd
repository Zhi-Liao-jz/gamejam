class_name WiringConfig
extends Resource
## 接线盒随机规则与受影响设备配置。

@export var min_points: int = 3
@export var max_points: int = 5
@export var allow_decoy: bool = true
@export_range(0.0, 1.0) var decoy_chance: float = 0.5
@export var affected_devices: Array[StringName] = [&"product_exit", &"heater"]
@export var shock_trap_unlock_day: int = 6


func roll_point_count() -> int:
	return randi_range(min_points, max_points)


func should_leave_decoy(count: int) -> bool:
	return allow_decoy and count > 3 and randf() < decoy_chance
