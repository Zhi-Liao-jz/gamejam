class_name GameplayConfig
extends Resource
## 根玩法配置。只引用静态可调数据，不保存运行时状态。

@export var economy: EconomyConfig
@export var product: ProductConfig
@export var monkey: MonkeyConfig
@export var generator: GeneratorConfig
@export var heater: HeaterConfig
@export var wiring: WiringConfig
@export var self_destruct: SelfDestructConfig
@export var equipment: EquipmentCatalog
