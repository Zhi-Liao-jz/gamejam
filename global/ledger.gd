extends Node
## 2.0 九宫格玩法的当天账本（autoload 名: Ledger）：倒计时 / 利润 / 经济明细 / 工作阶段标记。
## 与 Game 分离——Game 持有跨天的 day/money/存档，本账本只管"当天工作"的瞬时经济。

var time_left: float = 300.0
var profit_today: int = 0
var combo_count: int = 0
var delivered_today: int = 0  # 当天已交货数量
var base_reward_today: int = 0
var product_cost_today: int = 0
var combo_tip_today: int = 0
var wrong_delivery_today: int = 0
var damaged_delivery_today: int = 0
var maintenance_cost_today: int = 0  # 当天累计维护费（发电机输出/温度过高扣，已计入 profit_today）
var working_active: bool = false  # 当前是否"工作中"阶段（产品出口 / 拿放据此启停）
var day_failed: bool = false  # 当天是否已失败（自爆引爆触发；DayManager 据此转 Failed）

# 每设备独立供电模型（阶段3）：通电 = 发电机输出在规格内 且 该设备未被接线盒切断（阶段4接入）。
var generator_powered: bool = true  # 发电机输出是否在规格内（由 Generator 每帧写入）
var wiring_cut: Dictionary = {}  # device_type(StringName) -> true：被接线盒短路/错接切断的设备

var _maintenance_accum: float = 0.0  # 维护费小数累加器（满 1 才扣 1 进 profit）


## 当天交货目标（难度曲线由 GameConfig.economy 配置）。
func quota_today() -> int:
	return GameConfig.economy().quota_for_day(Game.day)


## 是否达成当天交货目标。
func is_quota_met() -> bool:
	return delivered_today >= quota_today()


## 随机生成一个产品成本。
func roll_product_cost() -> int:
	var economy := GameConfig.economy()
	return randi_range(economy.min_product_cost, economy.max_product_cost)


## 随机生成一个产品基础收益。
func roll_product_reward() -> int:
	var economy := GameConfig.economy()
	return randi_range(economy.min_base_reward, economy.max_base_reward)


## 当前连击数对应的小费；成功交货后才增加连击。
func current_combo_tip() -> int:
	var economy := GameConfig.economy()
	return mini(combo_count * economy.combo_tip_step, economy.combo_tip_cap)


## 某设备当前是否通电：发电机正常 且 未被接线盒切断。供产品出口 / 加热台读取。
func is_device_powered(device_type: StringName) -> bool:
	return generator_powered and not wiring_cut.has(device_type)


## 实时扣维护费（发电机每帧按 fee*delta 调用）。小数累加，满 1 单位才进 profit 与明细。
func charge_maintenance(amount: float) -> void:
	if amount <= 0.0:
		return
	_maintenance_accum += amount
	var whole := int(_maintenance_accum)
	if whole > 0:
		_maintenance_accum -= float(whole)
		maintenance_cost_today += whole
		profit_today -= whole


## 产品生成时立即扣除成本（玩家或猴子按出口都调用）。返回本次利润变化（负数）。
func charge_product_cost(amount: int) -> int:
	product_cost_today += amount
	profit_today -= amount
	return -amount


## 记一次成功交货：成本已在生成时扣除，这里只 +基础收益 +连击小费。返回本次利润变化。
func deliver(product: Product) -> int:
	var tip := current_combo_tip()
	var delta := product.base_reward + tip
	delivered_today += 1
	base_reward_today += product.base_reward
	combo_tip_today += tip
	profit_today += delta
	combo_count += 1
	return delta


## 记一次错误交付：成本已在生成时扣过，这里只中断连击（不再额外扣成本）。返回本次利润变化（恒 0）。
func record_wrong_delivery(_product: Product, is_damaged: bool = false) -> int:
	combo_count = 0
	if is_damaged:
		damaged_delivery_today += 1
	else:
		wrong_delivery_today += 1
	return 0


## 当天结算面板使用的数据包。
func summary_data() -> Dictionary:
	return {
		"day": Game.day,
		"delivered": delivered_today,
		"quota": quota_today(),
		"profit": profit_today,
		"combo": combo_count,
		"base_reward": base_reward_today,
		"cost": product_cost_today,
		"tip": combo_tip_today,
		"wrong": wrong_delivery_today,
		"damaged": damaged_delivery_today,
		"maintenance": maintenance_cost_today,
	}


## 推进当天倒计时。返回当天是否到点结束。
func tick(delta: float) -> bool:
	if not working_active:
		return false
	time_left = maxf(0.0, time_left - delta)
	return time_left <= 0.0


## 进入新一天（或重试本日）前重置当天计数与失败标志。
func reset_day() -> void:
	time_left = GameConfig.economy().day_duration
	profit_today = 0
	combo_count = 0
	delivered_today = 0
	base_reward_today = 0
	product_cost_today = 0
	combo_tip_today = 0
	wrong_delivery_today = 0
	damaged_delivery_today = 0
	maintenance_cost_today = 0
	_maintenance_accum = 0.0
	day_failed = false
	generator_powered = true
	wiring_cut = {}


## 当天结算：今日利润入 Game 账、推进天数、落盘。
func settle_and_advance() -> void:
	Game.complete_day(Game.day, profit_today)
