extends Node
## 2.0 九宫格玩法的当天账本（autoload 名: Ledger）：倒计时 / 利润 / 交货 / 工作阶段标记。
## 与 Game 分离——Game 持有跨天的 day/money/存档，本账本只管"当天工作"的瞬时经济。

const PRODUCT_VALUE: int = 20  # 单个产品交货收入
const DAY_DURATION: float = 300.0  # 正式版每天固定 5 分钟
const BASE_QUOTA: int = 5  # 第 1 天的交货目标
const QUOTA_PER_DAY: int = 2  # 之后每天目标递增

var time_left: float = DAY_DURATION
var profit_today: int = 0
var combo_count: int = 0
var delivered_today: int = 0  # 当天已交货数量
var working_active: bool = false  # 当前是否"工作中"阶段（产品出口 / 拿放据此启停）
var day_failed: bool = false  # 当天是否已失败（自爆引爆触发；DayManager 据此转 Failed）
var power_on: bool = true  # 供电是否正常（发电机被切断则 false；产品出口/加热台据此停摆）


## 当天交货目标（难度曲线：每天 +QUOTA_PER_DAY）。
func quota_today() -> int:
	return BASE_QUOTA + (Game.day - 1) * QUOTA_PER_DAY


## 是否达成当天交货目标。
func is_quota_met() -> bool:
	return delivered_today >= quota_today()


## 记一次成功交货（累加数量与收入；收入结算时入账）。
func deliver(value: int) -> void:
	delivered_today += 1
	profit_today += value
	combo_count += 1


## 推进当天倒计时。返回当天是否到点结束。
func tick(delta: float) -> bool:
	if not working_active:
		return false
	time_left = maxf(0.0, time_left - delta)
	return time_left <= 0.0


## 进入新一天（或重试本日）前重置当天计数与失败标志。
func reset_day() -> void:
	time_left = DAY_DURATION
	profit_today = 0
	combo_count = 0
	delivered_today = 0
	day_failed = false
	power_on = true


## 当天结算：今日利润入 Game 账、推进天数、落盘。
func settle_and_advance() -> void:
	Game.complete_day(Game.day, profit_today)
