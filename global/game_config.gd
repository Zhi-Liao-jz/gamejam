extends Node
## 玩法配置入口（autoload 名: GameConfig）。负责加载默认 .tres 并提供安全访问。

const DEFAULT_CONFIG := preload("res://params/gameplay/default_game_config.tres")

var config: GameplayConfig


func _ready() -> void:
	_ensure_config()


func economy() -> EconomyConfig:
	_ensure_config()
	return config.economy


func product() -> ProductConfig:
	_ensure_config()
	return config.product


func monkey() -> MonkeyConfig:
	_ensure_config()
	return config.monkey


func generator() -> GeneratorConfig:
	_ensure_config()
	return config.generator


func heater() -> HeaterConfig:
	_ensure_config()
	return config.heater


func wiring() -> WiringConfig:
	_ensure_config()
	return config.wiring


func self_destruct() -> SelfDestructConfig:
	_ensure_config()
	return config.self_destruct


func equipment() -> EquipmentCatalog:
	_ensure_config()
	return config.equipment


func _ensure_config() -> void:
	if config != null:
		return
	config = DEFAULT_CONFIG
	_ensure_children()


func _ensure_children() -> void:
	if config.economy == null:
		config.economy = EconomyConfig.new()
	if config.product == null:
		config.product = ProductConfig.new()
	if config.monkey == null:
		config.monkey = MonkeyConfig.new()
	if config.generator == null:
		config.generator = GeneratorConfig.new()
	if config.heater == null:
		config.heater = HeaterConfig.new()
	if config.wiring == null:
		config.wiring = WiringConfig.new()
	if config.self_destruct == null:
		config.self_destruct = SelfDestructConfig.new()
	if config.equipment == null:
		config.equipment = EquipmentCatalog.new()
