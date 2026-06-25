class_name MonkeyConfig
extends Resource
## 猴子数量、行为偏好与难度曲线配置。

@export var first_monkey_day: int = 2
@export var max_monkeys: int = 3
@export var base_speed: float = 200.0
@export var speed_per_day: float = 0.06
@export var flee_speed_multiplier: float = 1.5
@export var base_tamper_delay: float = 2.0
@export var tamper_delay_reduce_per_day: float = 0.2
@export var min_tamper_delay: float = 0.8
@export var wander_pause_min: float = 0.6
@export var wander_pause_max: float = 1.8
@export var base_cooldown: float = 4.0
@export var cooldown_reduce_per_day: float = 0.5
@export var min_cooldown: float = 2.0
@export_range(0.0, 1.0) var repair_chance: float = 0.3
@export var recent_device_lock: float = 3.0
@export var flee_after_action: bool = false
@export var spawn_rooms: Array[int] = [0, 2, 8, 6]
@export var pitch_by_index: Array[float] = [1.0, 0.92, 1.08]
@export var self_destruct_unlock_day: int = 3
@export var heater_unlock_day: int = 5
@export var power_unlock_day: int = 6


func count_for_day(day: int) -> int:
	if day < first_monkey_day:
		return 0
	return clampi(day - first_monkey_day + 1, 1, max_monkeys)


func roll_repair() -> bool:
	return randf() < repair_chance
