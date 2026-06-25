extends SceneTree
## 检查默认玩法配置资源能被 Godot 加载，并包含关键分类配置。

const CONFIG_PATH := "res://params/gameplay/default_game_config.tres"

var _errors: Array[String] = []


func _initialize() -> void:
	_run()
	if _errors.is_empty():
		print("game_config_smoke: OK")
		quit(0)
		return
	for error: String in _errors:
		push_error(error)
	quit(1)


func _run() -> void:
	if not ResourceLoader.exists(CONFIG_PATH):
		_errors.append("缺少默认玩法配置：%s" % CONFIG_PATH)
		return
	var resource := ResourceLoader.load(CONFIG_PATH)
	if resource == null:
		_errors.append("默认玩法配置无法加载：%s" % CONFIG_PATH)
		return
	_require_resource(resource, "economy")
	_require_resource(resource, "product")
	_require_resource(resource, "monkey")
	_require_resource(resource, "generator")
	_require_resource(resource, "heater")
	_require_resource(resource, "wiring")
	_require_resource(resource, "self_destruct")
	_require_resource(resource, "equipment")
	_require_float(resource.get("economy").get("day_duration"), 300.0, "economy.day_duration")
	_require_float(resource.get("generator").get("base_load"), 30.0, "generator.base_load")
	_require_float(resource.get("monkey").get("repair_chance"), 0.3, "monkey.repair_chance")
	_require_float(resource.get("monkey").get("base_tamper_delay"), 2.0, "monkey.base_tamper_delay")
	_require_float(resource.get("monkey").get("wander_pause_min"), 0.6, "monkey.wander_pause_min")
	_require_float(resource.get("monkey").get("wander_pause_max"), 1.8, "monkey.wander_pause_max")
	_run_tuning_proxy_checks()


func _require_resource(resource: Resource, property: StringName) -> void:
	var value: Variant = resource.get(property)
	if value == null or not value is Resource:
		_errors.append("配置字段不是 Resource：%s" % property)


func _require_float(value: Variant, expected: float, label: String) -> void:
	if not value is float:
		_errors.append("配置字段不是 float：%s" % label)
		return
	if not is_equal_approx(float(value), expected):
		_errors.append("配置字段默认值不正确：%s = %.2f" % [label, float(value)])


func _run_tuning_proxy_checks() -> void:
	var game_config := root.get_node_or_null("GameConfig")
	var generator_tuning := root.get_node_or_null("GeneratorTuning")
	var monkey_tuning := root.get_node_or_null("MonkeyTuning")
	var heater_tuning := root.get_node_or_null("HeaterTuning")
	var wiring_tuning := root.get_node_or_null("WiringTuning")
	if (
		game_config == null
		or generator_tuning == null
		or monkey_tuning == null
		or heater_tuning == null
		or wiring_tuning == null
	):
		_errors.append("缺少 GameConfig 或旧 Tuning Autoload")
		return
	var generator: Resource = game_config.call("generator")
	var monkey: Resource = game_config.call("monkey")
	var heater: Resource = game_config.call("heater")
	var wiring: Resource = game_config.call("wiring")
	var old_load := float(generator.get("base_load"))
	var old_repair_chance := float(monkey.get("repair_chance"))
	var old_laser_gap := float(heater.get("laser_gap"))
	var old_min_points := int(wiring.get("min_points"))
	generator_tuning.set("base_load", 42.0)
	monkey_tuning.set("repair_chance", 0.7)
	heater_tuning.set("laser_gap", 30.0)
	wiring_tuning.set("min_points", 4)
	_require_float(generator.get("base_load"), 42.0, "GeneratorTuning.base_load")
	_require_float(monkey.get("repair_chance"), 0.7, "MonkeyTuning.repair_chance")
	_require_float(heater.get("laser_gap"), 30.0, "HeaterTuning.laser_gap")
	if int(wiring.get("min_points")) != 4:
		_errors.append("WiringTuning.min_points 未写入 GameConfig")
	generator_tuning.set("base_load", old_load)
	monkey_tuning.set("repair_chance", old_repair_chance)
	heater_tuning.set("laser_gap", old_laser_gap)
	wiring_tuning.set("min_points", old_min_points)
