extends RefCounted
const Heroes=preload("res://scripts/expedition/heroes.gd")

const TOTAL := preload("res://scripts/expedition/campaign.gd").TOTAL
const BUFFS := {
	"firepower":{"name":"标准化弹药","desc":"全军攻击 +10%／级","group":"all","stat":"attack","value":0.10},
	"armor":{"name":"复合装甲","desc":"全军防御系数 +10%／级","group":"all","stat":"defense","value":0.10},
	"health":{"name":"加固结构","desc":"全军生命 +15%／级","group":"all","stat":"hp","value":0.15},
	"engines":{"name":"高效引擎","desc":"全军移动速度 +10%／级","group":"all","stat":"speed","value":0.10},
	"infantry_fire":{"name":"步兵精确射击","desc":"步兵攻击 +18%／级","group":"infantry","stat":"attack","value":0.18},
	"infantry_health":{"name":"步兵生存装备","desc":"步兵生命 +25%／级","group":"infantry","stat":"hp","value":0.25},
	"crossfire":{"name":"交叉火力","desc":"不同兵种在 4 秒内先后命中同目标，后一个命中 +10%／级；目标冷却 4 秒","group":"all","value":0.0,"core":true},
	"field_medic":{"name":"急救药箱","desc":"生命低于一半的部队每 5 秒额外恢复 2%／级","group":"all","value":0.0,"core":false},
	"vehicle_fire":{"name":"装甲穿击","desc":"载具攻击 +18%／级","group":"vehicle","stat":"attack","value":0.18},
	"vehicle_health":{"name":"模块化车体","desc":"载具生命 +25%／级","group":"vehicle","stat":"hp","value":0.25},
	"emergency_position":{"name":"应急阵地","desc":"部署后停稳 3 秒获得 5% 生命护盾／级，20 秒一次；部署减伤 +4%／级","group":"all","value":0.0,"core":true},
	"mobile_magazine":{"name":"机动弹仓","desc":"实际行驶三格后的下一次命中 +10%／级，8 秒一次","group":"all","value":0.0,"core":true},
	"breach_tools":{"name":"破障工具","desc":"对金色标记的任务目标伤害 +10%／级","group":"all","value":0.0,"core":false},
	"execution_plan":{"name":"收尾计划","desc":"对生命低于 35% 的目标伤害 +8%／级","group":"all","value":0.0,"core":false},
	"hunter_protocol":{"name":"猎杀协议","desc":"特种兵种对生命高于 90% 的目标首次命中 +15%／级","group":"all","value":0.0,"core":false},
	"last_stand":{"name":"绝境阵线","desc":"自身生命低于 40% 时攻击 +8%、额外减伤 +6%／级，减伤受 35% 总上限约束","group":"all","value":0.0,"core":true},
	"veterans":{"name":"老兵教官","desc":"击杀军衔经验 +50%／级","group":"all","value":0.50},
	"repair":{"name":"野战维修","desc":"载具、舰船脱离攻击与受伤 8 秒后，每秒恢复 1% 最大生命／级","group":"all","value":0.01},
	"medics":{"name":"随军医疗","desc":"步兵每 5 秒恢复 3% 最大生命／级","group":"infantry","value":0.03},
	"production":{"name":"流水线扩建","desc":"单位生产速度 +20%／级","group":"all","value":0.20},
	"deployment":{"name":"战略储备","desc":"每关额外部署资金 +2500／级","group":"all","value":2500.0},
	"supplies":{"name":"后勤协议","desc":"胜利额外获得 30 远征补给／级","group":"all","value":30.0},
	"salvage":{"name":"战损回收","desc":"每关前 5 辆损失的自有非临时载具，每辆补偿 8 补给／级，每关最多 30","group":"all","value":8.0},
	"logistics":{"name":"军需折扣","desc":"单位生产费用降低 8%／级","group":"all","value":0.08}
}
const CONDITIONS := [
	{"id":"funds","name":"当地军需","desc":"本关额外获得 3000 战场资金"},
	{"id":"medic","name":"医疗援助","desc":"本关全军每 5 秒恢复 2% 最大生命"},
	{"id":"factory","name":"工业支援","desc":"本关单位生产速度提高 20%"}
]
const MAP_LABELS := {"exp_plain":"钢铁平原","exp_fortress":"中央要塞","island_cross":"群岛制海","river_delta":"多桥河谷","lake_ring":"环湖争夺","canal_city":"运河城镇","twin_bays":"双湾半岛","ore_frontier":"内陆矿区"}

static func difficulty(stage:int) -> int:
	return preload("res://scripts/expedition/campaign.gd").difficulty(stage)

static func rng_for(run:Dictionary,salt:String) -> RandomNumberGenerator:
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash(str(run.seed)+":"+str(run.stage)+":"+salt)
	return rng

static func routes(run:Dictionary) -> Array:
	return preload("res://scripts/expedition/campaign.gd").routes(run)

static func roster(country:String) -> Array:
	var result:Array=[]
	var faction:=GameData.ra2_country_side(country)
	for id:String in GameData.faction_unit_catalog(faction,true):
		if id.begins_with("R3"):continue
		if not GameData.ra2_country_block_reason(id,GameData.ra2_country_id(country),false).is_empty():continue
		if str(GameData.get_unit(id).get("built_at","")).is_empty():continue
		result.append(id)
	return result

static func basic(country:String) -> Array:
	return ["E2","HTNK","HTK","FLAKT","SENGINEER","HARV","SMCV"] if GameData.ra2_country_side(country)=="soviet" else ["E1","MTNK","FV","ENGINEER","CMIN","AMCV"]

static func group(id:String) -> String:
	return GameData.unit_production_category(GameData.get_unit(id))

static func squad_size(id:String) -> int:
	var cost:=maxf(100,float(GameData.get_unit(id).get("cost",100)))
	return clampi(int(1600/cost),1,6)

static func dismissal_value(id:String) -> int:
	if not GameData.unit_index.has(id):return 0
	return floori(30.0/squad_size(id))

static func offer(run:Dictionary,kind:String,salt:String) -> Array:
	var rng:=rng_for(run,salt)
	var pool:Array=[]
	if kind=="buff":
		for id:String in BUFFS:
			if int(run.buffs.get(id,0))>=3:continue
			var category:String=BUFFS[id].group
			if category!="all" and not has_group(run,category):continue
			var strong:bool=salt=="victory_buff" and (int(run.stage)-1)%3==0
			pool.append({"kind":"buff","id":id,"levels":mini(2 if strong else 1,3-int(run.buffs.get(id,0)))})
	else:
		for id:String in run.catalog:
			if preload("res://scripts/expedition/army.gd").room(run,id)<=0:continue
			if group(id)=="naval" and int(run.stage)<6:continue
			if int(run.stage)<16 and id in run.licenses:continue
			pool.append({"kind":"unit","id":id})
	if pool.is_empty():pool.append({"kind":"supplies","id":"bonus","amount":100})
	var result:Array=[]
	while not pool.is_empty() and result.size()<3:
		var index:int=preload("res://scripts/expedition/market.gd").draw_index(pool,rng) if kind=="unit" else rng.randi_range(0,pool.size()-1)
		result.append(pool.pop_at(index))
	if kind=="unit" and salt=="victory_unit" and int(run.stage)>1:
		var heroes:=Heroes.available(run)
		var hero_rng:=rng_for(run,"victory_hero")
		if not heroes.is_empty() and hero_rng.randf()<Heroes.OFFER_CHANCE:
			var hero:Dictionary={"kind":"hero","id":heroes[hero_rng.randi_range(0,heroes.size()-1)]}
			if result.size()<3:result.append(hero)
			else:result[hero_rng.randi_range(0,result.size()-1)]=hero
	return result

static func has_group(run:Dictionary,category:String) -> bool:
	for id:String in run.licenses:
		if group(id)==category:return true
	return false

static func shop(run:Dictionary,refresh:int) -> Array:
	return preload("res://scripts/expedition/market.gd").shop(run,refresh)

static func name_of(item:Dictionary) -> String:
	var title:String=preload("res://scripts/expedition/market.gd").title(item)
	if not title.is_empty():return title
	match str(item.get("kind","")):
		"hero":return str(MetaProgress.Academy.HEROES[item.id])+" · 英雄加入"
		"buff":return str(BUFFS.get(item.id,{}).get("name",item.id))+(" · 强化 +2 级" if int(item.get("levels",1))==2 else "")
		"unit":return str(GameData.get_unit(item.id).get("name",item.id))+" · 许可与增援"
		"repair_kit":return "紧急维修包"
	return "远征补给"

static func description(item:Dictionary) -> String:
	var detail:String=preload("res://scripts/expedition/market.gd").description(item)
	if not detail.is_empty():return detail
	if item.kind=="hero":return "本轮获得 1 位英雄，无需局外解锁；可与已有英雄一同出战，同名不重复。阵亡后可花 60 补给救治，不解锁局外英雄。"
	if item.kind=="buff":return str(BUFFS[item.id].desc)+"；最高 3 级，本轮持续生效"
	if item.kind=="unit":return "最多加入 %d 个单位；受兵种、限造和本章人数限制，多余数量按遣散价折为补给。未持有时解锁本轮生产许可；继承攻防等级，重复招募不自动强化。"%squad_size(item.id)
	if item.kind=="repair_kit":return "战斗中主动使用，全军恢复 35% 最大生命；每包一次"
	if item.kind=="supplies":return ("原奖励已满员、满级或已拥有，改领补给。" if item.get("converted",false) else "")+"获得 %d 远征补给，可用于下一关商店、强化与整备；跨关保留。"%int(item.get("amount",100))
	if item.kind=="refresh_token":return "下一营地首件货架商品免费，可先刷新再买。免单不含服务，离营失效。另送 1 次免费刷新，可与商店首次免费刷新叠加，未用可保留。"
	if item.kind=="reinforce":return "为%s补充最多 %d 个普通单位，只补兵种及本章人数上限内的空缺，不提升攻防强化等级。"%[str(GameData.get_unit(item.id).get("name",item.id)),squad_size(item.id)]
	return "获得 100 远征补给"
