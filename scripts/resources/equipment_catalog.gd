class_name EquipmentCatalog
extends Resource
## 长期装备目录配置。运行时拥有数量仍由 Game 和 Savegame 管理。

@export var items: Array[EquipmentDefinition] = []
@export var hud_equipment_ids: Array[int] = [1, 2]


func has_equipment(equipment_id: int) -> bool:
	return find_equipment(equipment_id) != null


func find_equipment(equipment_id: int) -> EquipmentDefinition:
	for item: EquipmentDefinition in items:
		if item != null and item.id == equipment_id:
			return item
	return null


func equipment_data(equipment_id: int) -> Dictionary:
	var item := find_equipment(equipment_id)
	if item == null:
		return {}
	return item.to_dictionary()
