extends Node
## GM 状态与命令中枢。供 admin/ 下的 GM 控制台调用，也可被战斗控制器查询。
## 战斗控制器需要 connect 到本单例的信号（见 scripts/world/battle.gd）。

var enabled: bool = false
var god_mode: bool = false          # 我方无敌
var one_shot_kill: bool = false     # 我方一击必杀
var infinite_funds: bool = false
var infinite_power: bool = false      # 电力无限（产电补足耗电，不触发低电）
const FAST_BUILD_SECONDS := 0.05
var no_build_time: bool = false
var unlock_production_tech: bool = true # 当前调试阶段：解锁矿场制造科技，不跳过正常生产前置/费用。
var fast_forward: float = 1.0       # 相对正常60逻辑帧的对局倍速；通过BattleClock应用
var auto_win: bool = false

# 由战斗控制器注册的回调 { name: Callable }
var _hooks: Dictionary = {}

func register_hook(name: String, cb: Callable) -> void:
	_hooks[name] = cb

func unregister_hook(name: String) -> void:
	_hooks.erase(name)

func call_hook(name: String, args: Array = []) -> Variant:
	if _hooks.has(name) and _hooks[name].is_valid():
		return _hooks[name].callv(args)
	return null

func set_flag(flag: String, value) -> void:
	if not (flag in self):
		Events.gm_notice.emit("未知 GM 标志：" + flag)
		return
	set(flag, value)
	Events.gm_flags_changed.emit()
	Events.gm_notice.emit("GM." + flag + " = " + str(value))

func toggle_flag(flag: String) -> bool:
	if flag in self and typeof(get(flag)) == TYPE_BOOL:
		set_flag(flag, not get(flag))
		return (get(flag) == true)
	return false

# ------------------------------------------------------------------ 命令

## 调试授予本局科技；不改变下局默认状态或矿车调试开关。
func cmd_unlock_structure_queue() -> String:
	if not _hooks.has("unlock_structure_queue") or not _hooks["unlock_structure_queue"].is_valid():
		return "请先进入对局"
	if call_hook("unlock_structure_queue") == true:
		return "本局已解锁科技：建筑预约"
	return "请先进入对局"

## 给局内战斗加钱
func cmd_add_funds(amount: float) -> String:
	call_hook("add_funds", [amount])
	return "已注入资金 +%d" % int(amount)

## 秒杀全场敌人
func cmd_kill_all_enemies() -> String:
	var n = call_hook("kill_all_enemies", [])
	return "清场：消灭敌方单位 %s" % str(n)

## 立即结束当前波次倒计时
func cmd_skip_wave() -> String:
	call_hook("skip_wave", [])
	return "已跳过当前波次倒计时"

## 刷一批单位到指定位置
func cmd_spawn(unit_id: String, count: int, side: String = "enemy") -> String:
	return cmd_unit_tools({"action":"spawn","id":unit_id,"count":count,"side":side})

func has_battle_tools() -> bool:
	return _hooks.has("unit_tools") and _hooks.unit_tools.is_valid()

func cmd_unit_tools(request: Dictionary) -> String:
	if not has_battle_tools():return "请先进入对局或点击进入单位测试场"
	return str(call_hook("unit_tools",[request]))

## 一键获胜
func cmd_force_win() -> String:
	call_hook("force_end", [true])
	return "已强制结算为胜利"

## 一键失败
func cmd_force_lose() -> String:
	call_hook("force_end", [false])
	return "已强制结算为失败"

# ------------------------------------------------------------------ 局外 GM

func cmd_grant_currency(cur: String, amount: float) -> String:
	var previous := MetaProgress.balance(cur)
	MetaProgress.currency[cur] = previous + amount
	if not MetaProgress.save():
		MetaProgress.currency[cur] = previous
		return "发放失败，请检查存档。"
	Events.meta_changed.emit()
	return "已发放 %s ×%d，余额 %d" % [MetaProgress.currency_name(cur), int(amount), int(MetaProgress.balance(cur))]

func cmd_grant_all_tiers() -> String:
	return "已升至最高档位" if MetaProgress.grant_final_tier() else "升档失败，请检查存档。"

func cmd_max_upgrades() -> String:
	for u in MetaProgress.upgrades():
		var uid := str(u.get("id", ""))
		MetaProgress.upgrade_levels[uid] = int(u.get("max_level", 0))
	MetaProgress.save()
	Events.meta_changed.emit()
	return "已将全部后勤升级拉满"

func cmd_unlock_all_skills() -> String:
	var n := 0
	for s in GameData.skills:
		if MetaProgress.unlock_skill(str(s.get("id", ""))):
			n += 1
	return "已解锁全部技能（新增 %d 个）" % n

func cmd_reset_skills() -> String:
	MetaProgress.unlocked_skills.clear()
	MetaProgress.save()
	Events.meta_changed.emit()
	return "已清空抽取得到的技能（只保留通用技能）"

func cmd_complete_hero_contracts() -> String:
	var result:=preload("res://scripts/admin/gm_hero_contracts.gd").complete(MetaProgress)
	if not result.ok: return str(result.error)
	return "已获得并完成全部 %d 个英雄契约，已解锁 %d 张专属技能（新增 %d 张）。"%[result.contracts,result.rewards,result.added]

func cmd_unlock_all_heroes() -> String:
	var result:=preload("res://scripts/admin/gm_heroes.gd").unlock_all(MetaProgress)
	if not result.ok:return str(result.error)
	return "已解锁全部 %d 名英雄（新增 %d 名）。开新局后按各自规则出场；天赋等级与专属卡契约独立。"%[result.total,result.added]

func cmd_set_idle_hours(hours: float) -> String:
	# 直接把 last_tick 往前推，模拟挂机了 N 小时
	MetaProgress.idle["last_tick_unix"] = float(Time.get_unix_time_from_system()) - hours * 3600.0
	MetaProgress.save()
	Events.meta_changed.emit()
	return "已模拟挂机 %.1f 小时（去驻防界面即可领取）" % hours

func cmd_reset_meta() -> String:
	MetaProgress.reset_save()
	return "已重置局外存档"

func cmd_reload_data() -> String:
	GameData.reload()
	return "已热重载 data/ 下的全部配置"
