class_name Savegame
extends Resource
## 存档 schema（已锁定）。⚠ 不可逆：一旦有玩家存档，字段名/类型不可改、
## 装备 id（equipments）不可重排或复用，否则毁档或静默错位。加字段请配合 save_version 迁移。

const DEFAULT_PATH := "user://savegames"
const SAVE_VERSION := 2  # 当前存档格式版本号；落盘时显式写入（见 save_to_file）

static var current: Savegame = null

# save_version 默认 0 = "未写版本号的旧档"（哨兵）。落盘时被设为 SAVE_VERSION，故必非默认、必入盘；
# 加载得 0 即说明是早期档可据此迁移。绝不靠"字段缺失回落默认值"判版本（ResourceSaver 会省略默认值）。
@export var save_version: int = 0
@export var character_name: String
@export var is_demo := -1
@export var money := 0
@export var last_time_played := 0
@export var playtime := 0.0
@export var equipments: Array[int] = []
@export var now_day: int = 1
@export var selected_day: int = 1
@export var highest_unlocked_day: int = 1
@export var cleared_days: Array[int] = []
@export var best_profit_by_day: Dictionary = {}


static func inti_save():
	if not DirAccess.dir_exists_absolute(DEFAULT_PATH):
		DirAccess.make_dir_absolute(DEFAULT_PATH)
	var path := DEFAULT_PATH + "/wakuwaku.tres"
	if ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path, "Savegame", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is Savegame:
			(loaded as Savegame).activate()  # 读到完好存档：只设 current，不写盘
			return
		# 文件存在但读取失败 = 疑似损坏 / 被占用：绝不覆盖原档，改名备份后中止（current 留 null）
		push_error("存档读取失败，疑似损坏，已备份并中止以避免覆盖：" + path)
		var stamp := str(int(Time.get_unix_time_from_system()))
		DirAccess.copy_absolute(path, path + ".corrupt." + stamp)
		return
	# 仅"文件确实不存在"才建新档并落盘建立文件
	var fresh := Savegame.new()
	fresh.activate()
	fresh.save_to_file()


## 把本档设为当前档（纯内存，不写盘，避免纯启动读取也触盘放大毁档窗口）。
func activate():
	last_time_played = int(Time.get_unix_time_from_system())
	current = self


func end_level(level_playtime: float):
	playtime += level_playtime
	save_to_file()


func get_file_path() -> String:
	return DEFAULT_PATH + "/wakuwaku.tres"


## 原子写：先写临时文件再重命名覆盖，杜绝写盘中断留下半截损坏文件。
## 临时文件须用 .tres 扩展名——ResourceSaver 靠扩展名判格式，.tmp 会报 ERR_FILE_UNRECOGNIZED。
func save_to_file():
	save_version = SAVE_VERSION  # 显式写版本号（≠默认 0 → 必被序列化入盘）
	var final_path := get_file_path()
	var tmp := final_path.get_basename() + ".tmp.tres"
	var err := ResourceSaver.save(self, tmp)
	if err == OK:
		DirAccess.rename_absolute(tmp, final_path)
	else:
		push_error("存档写入失败: " + str(err))


func delete():
	DirAccess.remove_absolute(get_file_path())
