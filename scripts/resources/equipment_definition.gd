class_name EquipmentDefinition
extends Resource
## 单个长期装备配置。id 必须稳定，因为存档保存的是装备 id。

@export var id: int = 0
@export var key: StringName = &""
@export var display_name: String = ""
@export var price: int = 0
@export var max_count: int = 0
@export var refill_interval: float = 0.0
@export var effect_duration: float = 0.0
@export_multiline var description: String = ""


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"key": key,
		"name": display_name,
		"price": price,
		"max_count": max_count,
		"refill_interval": refill_interval,
		"effect_duration": effect_duration,
		"description": description,
	}
