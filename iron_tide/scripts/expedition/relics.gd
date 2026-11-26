extends RefCounted

const COLORS := {"普通":"#D7DCE2","优质":"#80D7A6","稀有":"#75BEFF","史诗":"#C89AFF","传说":"#FFD166","典藏":"#FF8073"}
const ITEMS := {
	"reserve_credit":{"name":"前线拨款令","rarity":"稀有","family":"经营","min_stage":26,"max_level":5,"price":140,"icon":"coin","desc":"每级在每场战斗开始时增加 1000 战场资金，最多增加 5000。"},
	"field_procurement":{"name":"军需议价函","rarity":"稀有","family":"经营","min_stage":27,"max_level":4,"price":120,"icon":"receipt_stamp","desc":"每级让付费刷新商店少花 2 补给，最多少花 8。先算已有折扣，费用最低为零。"},
	"chrono_decree":{"name":"逆时密令","rarity":"典藏","family":"经营","price":0,"icon":"hourglass","desc":"每场一次，选择后续一个到场批次，与队首互换抵达时间。不复制单位，不改变跨关减时。"},
	"field_dispatch":{"name":"战地接驳令","rarity":"传说","drop_weight":0.15,"family":"经营","price":200,"icon":"heal","desc":"本关首次使用维修包后，选择一批待抵达援军，使其剩余等待减半。10 秒内未选择时，自动选择列表中的最后一批。"},
	"formation_warrant":{"name":"扩编委任状","family":"经营","min_stage":16,"price":180,"icon":"receipt_stamp","desc":"本轮出战编制增加 1 格，可多派 1 种兵种。与联合作战名册叠加，出战人数仍按本章上限计算。"},
	"joint_roster":{"name":"联合作战名册","family":"经营","min_stage":21,"price":220,"icon":"escort","desc":"本轮出战编制增加 1 格，可多派 1 种兵种。与扩编委任状叠加，出战人数仍按本章上限计算。"},
	"silent_radio":{"name":"静默电台","rarity":"传说","drop_weight":0.15,"family":"经营","price":200,"icon":"rad_growth","desc":"发动 RED ALERT 时，除原有总攻效果外，额外复制全部尚未抵达的普通军团，按原计划抵达。若原军团已到齐，则从发动时起按原间隔派出整份副本。副本仅限本关。"},
	"bridge_station":{"name":"桥头调度站","rarity":"传说","drop_weight":0.15,"family":"经营","price":200,"icon":"defense","desc":"本轮远征的桥头小屋和完好桥段无法被炸毁。已断的桥仍需工程师修复。"},
	"capture_manual":{"name":"据点协同手册","rarity":"优质","max_level":3,"family":"经营","price":100,"icon":"escort","desc":"多支部队共同推进远征主线或支线读条时缩短用时。每升一级，人数带来的减时上限提高 10 个百分点，一级至三级分别为 40%、50%、60%。每处 8 个友方地面单位即可达到上限。"},
	"signal_timer":{"name":"信物校时器","rarity":"稀有","max_level":5,"family":"经营","price":120,"icon":"hourglass","desc":"每级让所有信物的开场等待和使用后的冷却缩短 10%，最多减半。满级时，原本开场等 300 秒的信物只等 150 秒。"},
	"alert_array":{"name":"战区监听阵列","rarity":"史诗","drop_weight":0.4,"max_level":3,"family":"经营","price":140,"icon":"antiair","desc":"每层使充满警戒槽所需的警戒值降低 5%，三层共降低 15%。"},
	"chrono_anchor":{"max_level":3,"name":"超时空稳定锚","rarity":"传说","drop_weight":0.15,"family":"经营","price":200,"icon":"reload","desc":"军团超时空增援的跨局减时上限从 50% 逐层升至 60%／70%／80%。每局重新倒计时；上局推进的传送时间折半累积，军团人数损失按比例扣回减时收益。本局工厂自产单位不加入军团，也不计损失比例。"},
	"red_alert_warrant":{"name":"警戒授权","rarity":"传说","drop_weight":0.15,"family":"经营","price":160,"icon":"red_coordinates","desc":"每关开局获得半槽警戒值（50%）。若已储存一次总攻，则保留该次数。"},
	"bastion_heart":{"name":"不落要塞之心","family":"究极构筑","units":["E1","GGI"],"min_stage":16,"price":260,"icon":"guard","desc":"部署停稳 3 秒获得 15% 护盾，12 秒冷却。护盾实际吸收的伤害蓄为反击能量，最多最大生命的 40%；下次部署直击消耗能量，每吸收 1% 生命对应伤害 +3%，最高 +120%。固守 9 层时，满能量反击再补 10% 护盾。玩法：持盾承伤→蓄能重击→补盾守线。"},
	"grizzly_engine":{"name":"灰熊穿插引擎","family":"究极构筑","units":["MTNK"],"min_stage":16,"price":260,"icon":"vehicle","desc":"持续移动 2 秒装填 3 发追击弹，10 秒冷却，刷新不累加；每发直击 +25%，每 0.25 秒最多消耗一发。打完三发恢复 8% 生命，并刷新行军首击及灰熊竞速飞轮冷却；装甲 9 层另补满 3 发羁绊突击弹。玩法：穿插装填→三连击→接行军首击再突进。"},
	"rhino_siege":{"name":"犀牛饱和攻城炉","family":"究极构筑","units":["HTNK"],"min_stage":16,"price":260,"icon":"explosive","desc":"停稳 3 秒后，5 秒内累计 3 次有效直击开启 6 秒饱和射击：直击 +40%，并压制被命中单位，使其对我方直击伤害降低 20%、持续 4 秒。移动会中断射击窗口和蓄力；每 0.25 秒最多计一次。重炮 9 层每次开启窗口刷新纵深压制强击冷却。玩法：停车校射→持续压制→换阵地重新蓄力。"},
	"prism_matrix":{"name":"光棱共振矩阵","family":"究极构筑","units":["SREF"],"min_stage":16,"price":280,"icon":"hightech","desc":"光棱直击建立 6 秒共振标记；其他不同兵种的后续直击各提供一格能量，同兵种不重复供能。集齐 3 种后，下次光棱直击消耗能量、伤害 +120%。能量 9 层兑现时另留下 4 秒过载，使后续全军直击 +15%。玩法：光棱标记→混编集火充能→光棱主炮兑现。"},
	"sky_cycle":{"name":"天穹轮转机匣","family":"究极构筑","units":["ORCA","BEAG"],"min_stage":16,"price":260,"icon":"air","desc":"正常补满弹药装填 3 发直击 +35% 的突击弹，每 0.25 秒最多消耗一发，刷新不累加。第三发为目标留下 6 秒空袭航标，后续全军直击 +25%，同时自身获得 25% 护盾；航空 9 层再恢复 10% 生命。玩法：返航补弹→三连空袭→地面跟进集火。"},
	"zero_warrant":{"name":"零号行动许可","family":"究极构筑","units":["GHOST","TANY","BORIS"],"min_stage":16,"price":280,"icon":"dual_pistols","desc":"对生命低于 60% 的目标直击 +50%。击杀敌方单位后恢复 10% 生命、获得 15% 护盾，并装填持续 8 秒的一次突袭，使下一次直击不论目标血量都获得此 +50%（两条件不叠加）；击杀收益 1 秒冷却。配合特种 9 层击杀刷新处决与治疗，连续转火收割。"},
	"field_manual":{"name":"战地教范","family":"养成","price":40,"icon":"queue","desc":"每关可免费强化一个兵种一次，攻防各 +1 肉鸽等级，最高 5 级。全军共用一次，未用次数不累计。"},
	"sandbag_standard":{"name":"不退的沙袋旗","family":"单位专属","units":["E1"],"price":80,"icon":"rank","desc":"部署且停稳 3 秒后获得最大生命 12% 的护盾，每个单位冷却 15 秒。适合部署固守，并与护盾类藏品配合。"},
	"guardian_sight":{"name":"守卫者测距镜","family":"单位专属","units":["GGI"],"price":100,"icon":"sight","desc":"部署时对载具、舰船的直接命中伤害 +30%；每个单位每 6 秒首次满足条件的命中获得最大生命 8% 的护盾。"},
	"drive_flywheel":{"name":"灰熊竞速飞轮","family":"单位专属","units":["MTNK"],"price":100,"icon":"speed","desc":"持续移动 2 秒后，接下来 2 秒内首次直接命中伤害 +35%，并恢复最大生命 5%；每个单位冷却 6 秒。"},
	"rhino_drum":{"name":"犀牛连射弹鼓","family":"单位专属","units":["HTNK"],"price":120,"icon":"heavy","desc":"连续直接命中使本次及后续命中伤害每层 +8%，最高 5 层；5 秒未命中清空。每个单位每 0.25 秒最多计一次，范围命中不瞬间叠满。"},
	"tesla_coil":{"name":"磁暴三相线圈","family":"单位专属","units":["SHK","TTNK"],"price":120,"icon":"copper_coil","desc":"每第 3 次有效直接命中额外 +60% 伤害，并获得最大生命 5% 的护盾；每个单位每 0.25 秒最多计一次，5 秒未命中清空计数。"},
	"prism_lens":{"name":"光棱折射透镜","family":"单位专属","units":["SREF"],"price":140,"icon":"focus","desc":"直接命中给目标施加 4 秒折射标记；被标记目标后续受到我方非临时单位的直接命中伤害 +20%。重复标记只刷新持续时间。"},
	"rotor_workshop":{"name":"旋翼野战工坊","family":"单位专属","units":["SCHP"],"price":100,"icon":"build","desc":"部署且停稳 3 秒后，每 5 秒恢复最大生命 4%，并获得最大生命 6% 的护盾。收起部署时停止。"},
	"commando_dogtag":{"name":"无声行动铭牌","family":"单位专属","units":["GHOST","TANY","BORIS"],"price":120,"icon":"exclusive","desc":"对生命低于 35% 的目标直接命中伤害 +25%；击杀敌方单位后恢复最大生命 8%，每个单位冷却 3 秒。"},
	"shield_capacitor":{"name":"护盾放电匣","family":"组合","price":120,"icon":"electric","desc":"拥有远征护盾时，直接命中伤害 +20%，每个单位冷却 4 秒，不消耗护盾。可与羁绊及部署藏品提供的护盾配合。"},
	"redline_core":{"name":"红线应急核心","family":"组合","price":120,"icon":"heart","desc":"生命低于 40% 时减伤 +15%（仍受总减伤 35% 上限约束）；此时直接命中恢复最大生命 3%，每个单位冷却 5 秒。"},
	"barrage_counter":{"name":"火网校射计数器","family":"组合","tag":"artillery","price":140,"icon":"triple_charge","desc":"重炮火网标签单位每第 3 次有效直接命中额外 +35% 伤害；每个单位每 0.25 秒最多计一次，5 秒未命中清空计数。可与犀牛连射弹鼓组合。"},
	"sortie_seal":{"name":"归航整备印章","family":"组合","tag":"air","price":120,"icon":"air_rearm","desc":"航空单位正常补满弹药时恢复最大生命 10%，并使下一次直接命中伤害 +40%；强化首击不能累计，保持满弹不会重复触发。"},
	"supply_ledger":{"name":"前线补给账簿","family":"经营","price":60,"icon":"supply_crate","desc":"每次战斗胜利额外获得 25 补给；失败、撤退不触发。"},
	"reserve_bond":{"name":"战区储备债券","family":"经营","price":80,"icon":"coin","desc":"每次胜利按结算前持有补给的 10% 追加补给，向下取整，单关最多 40；本次胜利奖励不计入本金，失败、撤退不触发。"},
	"choice_compass":{"name":"岔路寻珍罗盘","family":"经营","price":160,"icon":"split","desc":"之后生成的战后常规奖励与每轮额外 Buff 奖励，各增加一个可选项：前期三选一变四选一，第 15 关胜利起四选一变五选一。每轮仍只领取一项，不重抽已展示的奖励。"},
	"bargain_map":{"name":"军需暗线地图","family":"经营","price":60,"icon":"tactics","desc":"军需商店付费刷新价格减半，向上取整；免费刷新保持免费。藏品持续本轮，刷新次数照常累计。"}
}

static func grade(id:String) -> String:
	var row:Dictionary=ITEMS.get(id,{})
	return str(row.get("rarity","史诗" if row.get("family")=="究极构筑" else "优质" if int(row.get("price",0))>=100 else "普通"))

static func tint(id:String) -> Color:
	return Color(COLORS[grade(id)])

static func owned(run:Dictionary,id:String) -> bool:
	return bool(run.get("relics",{}).get(id,false))

static func capture_rate(units:int, relic_level:int) -> float:
	if units<=0:return 0.0
	var strength:=log(float(mini(units,8)))/log(8.0)
	return 1.0/(1.0-strength*(0.30+0.10*clampi(relic_level,0,3)))

static func progress_rate(units:int) -> float:
	return capture_rate(units,level(Expedition.state,"capture_manual"))

static func level(run:Dictionary,id:String) -> int:
	if not owned(run,id):return 0
	return int(run.get("relic_levels",{}).get(id,3 if id=="chrono_anchor" else 1))

static func can_gain(run:Dictionary,id:String) -> bool:
	return ITEMS.has(id) and level(run,id)<int(ITEMS[id].get("max_level",1))

static func grant(run:Dictionary,id:String) -> void:
	if not can_gain(run,id):return
	var next:=level(run,id)+1
	run.get_or_add("relics",{})[id]=true
	run.get_or_add("relic_levels",{})[id]=next

static func applies(id:String,unit_id:String,tags:Array) -> bool:
	var row:Dictionary=ITEMS.get(id,{})
	if row.is_empty() or row.family in ["经营","养成"]:return false
	if row.has("units"):return unit_id in row.units
	return not row.has("tag") or row.tag in tags

static func description(id:String) -> String:
	var row:Dictionary=ITEMS.get(id,{})
	if row.is_empty():return "未知藏品"
	var scope:String="我方作战部队（不含临时单位和任务 NPC）" if row.family=="组合" else str(row.family)
	if row.has("units"):
		var names:PackedStringArray=[]
		for unit_id:String in row.units:names.append(str(GameData.get_unit(unit_id).get("name",unit_id)))
		scope="专属兵种："+"、".join(names)
	elif row.has("tag"):scope="重炮火网标签" if row.tag=="artillery" else "航空联队标签"
	var unlock:String="第 %d 关起进入获取池。\n"%int(row.min_stage) if row.has("min_stage") else ""
	var rarity:String=str(row.get("rarity",""))
	var rarity_text:=rarity+"藏品 · " if not rarity.is_empty() else ""
	return unlock+rarity_text+scope+"。"+str(row.desc)+"\n持有即生效，仅限本轮；每种限一件，独立收藏。战斗护盾取较高值，不叠加。"

static func extra_slots(run:Dictionary) -> int:
	return int(owned(run,"formation_warrant"))+int(owned(run,"joint_roster"))

static func reward_choices(run:Dictionary) -> int:
	return (4 if int(run.get("stage",1))>=16 else 3)+(1 if owned(run,"choice_compass") else 0)

static func victory_supplies(run:Dictionary) -> int:
	return (25 if owned(run,"supply_ledger") else 0)+(mini(40,int(int(run.supplies)/10)) if owned(run,"reserve_bond") else 0)

static func refresh_price(run:Dictionary,base:int) -> int:
	var discounted:=ceili(base*0.5) if owned(run,"bargain_map") else base
	return maxi(0,discounted-2*level(run,"field_procurement"))
