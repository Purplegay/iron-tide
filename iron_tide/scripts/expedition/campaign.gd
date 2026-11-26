extends RefCounted
## Authored campaign progression. Battle tasks and public route information share these rows.
const TOTAL := 30
const CHAPTERS := ["前线接触", "工业战线", "异能危机", "机动决战", "纵深突破", "终极战区"]
const TITLES := ["前线前哨", "断敌补给", "车队护送", "风险路线", "钢铁关隘", "工业争夺", "桥头控制", "雷达突袭", "双线战区", "防空堡垒", "解救小队", "战区争夺", "特装实验场", "后勤危机", "磁暴核心", "闪击前线", "空地协同", "战略研究所", "高危猎场", "机动指挥军", "纵深备战", "复合战线", "突破封锁", "最后整备战", "钢铁壁垒", "终局备战", "空地围猎", "最后研究所", "决战前夜", "终极战区"]
const TASKS := ["capture", "supply", "escort", "assault", "boss", "control", "capture", "radar", "defend", "boss", "rescue", "control", "research", "escort", "boss", "supply", "annihilate", "research", "defend", "boss", "supply", "control", "capture", "defend", "boss", "supply", "annihilate", "research", "defend", "boss"]
const TASK_NAMES := {"capture":"占领前哨", "supply":"破坏补给", "escort":"护送车队", "assault":"击破指挥部", "annihilate":"摧毁全部敌方建筑", "boss":"章末决战", "control":"据点争夺", "radar":"雷达突袭", "defend":"坚守战线", "rescue":"解救小队", "research":"夺取研究所"}
const TASK_DESCRIPTIONS := {"capture":"占领前哨至 60 点。圈内友方地面部队越多，占领越快，每多一支的收益越小。8 支达到人数减时上限，基础为 30%，据点协同手册可提高至 60%。敌军进圈时暂停占领，已有进度保留。", "supply":"摧毁两座标记补给设施即可获胜，无需清理残兵。", "escort":"护送三辆任务车辆深入战区，至少两辆抵达远端终点；丢失两辆则失败。20 秒后开始超时空侵袭预警，落点提前 5 秒标记，敌军抵达后每 40 秒再次预警；暂停车队不会暂停敌袭。", "assault":"摧毁标记敌方指挥部即可获胜。", "annihilate":"清除所有敌对阵营的建筑，包括防御设施和围墙。无需消灭残余部队。",  "boss":"破坏外围节点开启指挥目标，按公开阶段推进。", "control":"分别控制三个据点，每处上限 60 点。圈内友方地面部队越多，占领越快，每多一支的收益越小。8 支达到人数减时上限，基础为 30%，据点协同手册可提高至 60%。敌军进圈时暂停占领，已得分不减少，合计 180 点获胜。", "radar":"摧毁标记雷达；六分钟内完成获得额外补给，超时援军增多。", "defend":"保护指挥所 6 分钟。可派地面部队抢修中继站、截获敌军电报。每处单兵需要 20 秒，多人更快；敌军进圈时暂停，已有进度保留。每完成一项，坚守时间缩短 45 秒。敌军每 45 秒派出一支增援编队。指挥所失守则失败。", "rescue":"控制两处关押点，每处单支部队需要 20 秒，多支可更快救出人质。", "research":"分别接管两座实验室，每处单支部队需要 45 秒，多支更快，进度保留；每座胜利额外获得 40 补给。"}
const NEW_MAPS := ["yr_unrepent", "yr_irvineca", "yr_monsterm", "yr_transylv", "yr_highexpr", "yr_moonpatr", "yr_hidvally", "yr_dunepatr", "yr_dryheat", "yr_groundze", "yr_fourcorners", "yr_tourofegypt", "yr_bayopigs", "yr_pacific", "yr_seaofiso", "yr_tsunami", "yr_potomac", "yr_amazon", "yr_lostlake", "yr_shrapnel", "yr_arena", "yr_oceansid", "yr_hills", "yr_valley", "yr_dustbowl", "yr_newhghts", "yr_hailmary", "yr_grinder"]
const TERRAIN := {
	"yr_bayopigs":"海岸",
	"yr_pacific":"海岸",
	"yr_tsunami":"海岸",
	"yr_oceansid":"海岸",
	"yr_isleland":"海岸",
	"yr_mojosprt":"海岸",
	"twin_bays":"海岸",
	"yr_amazon":"河桥",
	"yr_lostlake":"河桥",
	"yr_shrapnel":"河桥",
	"yr_potomac":"河桥",
	"yr_grinder":"河桥",
	"yr_riverram":"河桥",
	"yr_unrepent":"河桥",
	"river_delta":"河桥",
	"canal_city":"河桥",
	"yr_seaofiso":"湖区",
	"yr_valley":"湖区",
	"yr_crctbrd":"湖区",
	"lake_ring":"湖区",
	"yr_arena":"城区",
	"yr_hailmary":"城区",
	"yr_irvineca":"城区",
	"yr_transylv":"城区",
	"yr_groundze":"城区",
	"yr_newhghts":"高地",
	"yr_hills":"高地",
	"yr_monsterm":"高地",
	"yr_hidvally":"高地",
	"yr_moonpatr":"高地",
	"yr_dustbowl":"旷野",
	"yr_dunepatr":"旷野",
	"yr_dryheat":"旷野",
	"yr_highexpr":"旷野",
	"yr_fourcorners":"旷野",
	"yr_tourofegypt":"旷野",
	"ore_frontier":"旷野",
	"yr_ice_age":"冰原",
	"yr_deepfrze":"冰原"
}
const STARTS := {
	"yr_isleland":6,
	"yr_ice_age":6,
	"yr_crctbrd":4,
	"yr_deepfrze":4,
	"yr_riverram":2,
	"yr_mojosprt":4,
	"yr_unrepent":6,
	"yr_irvineca":8,
	"yr_monsterm":8,
	"yr_transylv":6,
	"yr_highexpr":6,
	"yr_moonpatr":4,
	"yr_hidvally":2,
	"yr_dunepatr":2,
	"yr_dryheat":4,
	"yr_groundze":4,
	"yr_fourcorners":4,
	"yr_tourofegypt":6,
	"yr_bayopigs":6,
	"yr_pacific":4,
	"yr_seaofiso":4,
	"yr_tsunami":4,
	"yr_potomac":6,
	"yr_amazon":4,
	"yr_lostlake":4,
	"yr_shrapnel":4,
	"yr_arena":4,
	"yr_oceansid":4,
	"yr_hills":4,
	"yr_valley":4,
	"yr_dustbowl":2,
	"yr_newhghts":2,
	"yr_hailmary":2,
	"yr_grinder":2
}
const NAVAL := ["coast","exp_plain","exp_fortress","canal_city","river_delta","twin_bays","yr_bayopigs","yr_isleland","yr_mojosprt","yr_tsunami","yr_lostlake","yr_valley","yr_oceansid","yr_grinder","yr_amazon","yr_shrapnel","yr_potomac","yr_riverram"]
const MAP_NAMES := {"yr_unrepent":"尤复 · 不屈战区", "yr_irvineca":"尤复 · 尔湾战区", "yr_monsterm":"尤复 · 巨兽战区", "yr_transylv":"尤复 · 古堡战区", "yr_highexpr":"尤复 · 高爆战区", "yr_moonpatr":"尤复 · 月面战区"}
const STARTERS := {
	"美国":[{"name":"阵地步兵", "units":{"E1":5,"GGI":4,"MTNK":2}}, {"name":"机动装甲", "units":{"MTNK":4,"FV":1,"E1":3}}, {"name":"精锐突击", "units":{"GHOST":2,"E1":4,"FV":2}}],
	"苏俄":[{"name":"钢铁突破", "units":{"HTNK":3,"HTK":2,"E2":3}}, {"name":"磁暴步兵", "units":{"E2":6,"SHK":5,"FLAKT":3}}, {"name":"协同破阵", "units":{"E2":2,"HTK":3,"SENGINEER":1,"HTNK":2}}]
}
const START_BUDGET := 4000
const OPTIONAL_SUPPLIES := 60

static func chapter(stage:int) -> int:
	return clampi((stage-1)/5,0,CHAPTERS.size()-1)

static func difficulty(stage:int) -> int:
	return 5 if stage in [26,27] else 6 if stage>=28 else chapter(stage)+1

const EXTRA_FUNDS := 1000

static func funds(stage:int) -> int:
	return [10000,12000,15000,18000,22000,26000][chapter(stage)]

static func victory_supplies(stage:int,elite:bool=false) -> int:
	var base:int=[180,220,260,300,340,380][chapter(stage)]
	return base+(200 if stage%5==0 else 100 if elite else 0)

static func slots(run:Dictionary) -> int:
	return 6+chapter(int(run.stage))+preload("res://scripts/expedition/relics.gd").extra_slots(run)

static func population(stage:int) -> int:
	return [24,32,40,48,60,72][chapter(stage)]

static func bonus_rounds(stage:int) -> int:
	# Reward pages use the upcoming stage, after the preceding victory.
	return 3 if stage>=26 else 2 if stage>=16 else 1

static func bonus_index(round_id:String) -> int:
	return {"buff":1,"buff_2":2,"buff_3":3}.get(round_id,0)

static func title(stage:int) -> String:
	return TITLES[clampi(stage-1,0,TOTAL-1)]

static func reversible(kind:String,stage:int) -> bool:
	return stage>=21 and kind in ["capture","control"]

static func task_name(kind:String,stage:int) -> String:
	if reversible(kind,stage):return "三线反夺" if kind=="control" else "前哨拉锯"
	return TASK_NAMES.get(kind,"主线任务")

static func task_description(kind:String,stage:int) -> String:
	if kind=="boss" and stage==TOTAL:return "摧毁两座供能节点，再派地面部队同时守住任意两个破盾区。累计 45 秒解除护盾，摧毁核心指挥部即可获胜。"
	if reversible(kind,stage):
		if kind=="control":return "圈内友方地面部队越多，占领越快，每多一支的收益越小。8 支达到人数减时上限，基础为 30%，据点协同手册可提高至 60%。敌军进圈每秒扣 1 点，满分据点也能被反抢。三处同时达到 60 点获胜。"
		return "控制前哨至 60 点获胜。圈内友方地面部队越多，占领越快，每多一支的收益越小。8 支达到人数减时上限，基础为 30%，据点协同手册可提高至 60%。敌军进圈每秒扣 1 点，无人驻守时保留进度。"
	return TASK_DESCRIPTIONS.get(kind,"")

static func task(stage:int) -> String:
	return TASKS[clampi(stage-1,0,TOTAL-1)]

static func opening_units(country:String) -> Array:
	var result:Array=[]
	for preset:Dictionary in STARTERS.get(country,[]):
		for id:String in preset.units:
			if not id in result:result.append(id)
	return result

static func opening_error(country:String,units:Dictionary) -> String:
	if not STARTERS.has(country) or units.is_empty():return "请先选择初始部队"
	var allowed:=opening_units(country)
	var spent:=0
	var kinds:=0
	for id in units:
		if not id is String or not id in allowed or not units[id] is int or units[id]<0 or units[id]>6:return "初始部队或数量无效"
		if int(units[id])>0:kinds+=1
		spent+=int(GameData.get_unit(id).get("cost",0))*int(units[id])
	if kinds==0 or kinds>4:return "请选择 1～4 种初始部队"
	return "部署点超过 4000" if spent>START_BUDGET else ""

static func map_name(id:String) -> String:
	if MAP_NAMES.has(id):return MAP_NAMES[id]
	var maps=preload("res://scripts/world/skirmish_maps.gd")
	var index:int=maps.IDS.find(id)
	return str(maps.NAMES[index]) if index>=0 else "中央要塞" if id=="exp_fortress" else "钢铁平原"

static func map_description(id:String) -> String:
	if preload("res://scripts/world/native_maps.gd").has(id):return "%s · %s"%[TERRAIN.get(id,"原版地形"),"可尝试部署舰队" if id in NAVAL else "内陆战区"]
	return str(preload("res://scripts/world/skirmish_maps.gd").MAPS.get(id,{}).get("desc",""))

const DEFENSE_GROUPS := [
	["DRON", "TTNK", "HTK"],
	["V3", "HTNK", "FLAKT"],
	["DESO", "TTNK", "DRON"],
	["APOC", "HTK", "SHK"],
	["ZEP", "HTK", "HTNK"],
]

static func defense_wave(stage:int, wave:int, elite:bool, tactic:String) -> Array[String]:
	var roster:Array[String]=[]
	var group:Array=DEFENSE_GROUPS[(wave-1+chapter(stage)) % DEFENSE_GROUPS.size()]
	var escorts:=["HTK","FLAKT","HTNK"]
	for i in 2+chapter(stage)+(2 if elite else 0):
		roster.append(group[i] if i<group.size() else escorts[(i-group.size())%escorts.size()])
	if tactic=="rapid_raiders":roster.append_array(["E2","E2"])
	if tactic=="armor_column":roster.append("HTNK")
	return roster

static func wave_units(stage:int,elite:bool,tactic:String,convoy_raid:=false) -> Array[String]:
	var roster:Array[String]=[]
	var count:=chapter(stage)+(2 if elite else 0)
	if convoy_raid:
		for i in 3+count:
			roster.append("E2" if stage<6 else ("HTNK" if i%3==0 else "SHK"))
		return roster
	var base:="HTNK" if stage>=6 else "E2"
	if stage==10:base="HTK"
	if stage==15:base="SHK"
	for i in 2+count:roster.append(base)
	if tactic=="rapid_raiders":roster.append_array(["E2","E2"])
	if tactic=="armor_column":roster.append("HTNK")
	return roster

static func wave_intel(stage:int,route:Dictionary) -> String:
	var counts:Dictionary={}
	for id in wave_units(stage,route.get("elite",false),route.get("elite_tactic",""),route.task=="escort"):
		counts[id]=int(counts.get(id,0))+1
	var parts:PackedStringArray=[]
	for id:String in counts:parts.append("%s ×%d"%[GameData.get_unit(id).name,counts[id]])
	return "黑匣子情报 · 首批任务敌军："+"、".join(parts)

static func hostile_houses(stage:int,index:int) -> int:
	if index==0 or stage<6 or stage>25 or stage%5==0:return 1
	return 3 if stage in [19,24] else 2

static func routes(run:Dictionary) -> Array:
	var stage:int=run.stage
	var used:Dictionary={}
	var last_task_terrain:=""
	for report:Dictionary in run.get("battle_reports",[]):
		if report.get("retreat",false):used[report.map]=true
	for row:Dictionary in run.history:
		used[row.map]=true
		if task(int(row.get("stage",0)))==task(stage):last_task_terrain=TERRAIN.get(row.map,"")
	var pool:Array=preload("res://scripts/world/native_maps.gd").IDS.duplicate()
	pool.append_array(["ore_frontier","lake_ring","river_delta","canal_city","twin_bays"])
	var navy:=false
	for unit:String in run.get("active_roster",[]):
		if GameData.unit_production_category(GameData.get_unit(unit))=="naval":navy=true
	var candidates:Array=[]
	for id:String in pool:
		if not used.has(id):candidates.append(id)
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash(str(run.seed)+":"+str(stage)+":campaign_routes")
	var result:Array=[]
	for index in (1 if stage==TOTAL else 2):
		var id: String="exp_fortress"
		if stage!=TOTAL:
			var support:=preload("res://scripts/expedition/field_operations.gd").allies_for(run,stage)
			var seats:=mini(4,1+hostile_houses(stage,index)+support.size())
			var choices:Array=[]
			var best:=-1
			for candidate:String in candidates:
				var terrain:String=TERRAIN[candidate]
				var score:=0
				if index==1 and terrain!=TERRAIN[result[0].map]:score+=16
				if navy and candidate in NAVAL:score+=8
				if int(STARTS.get(candidate,2))>=seats:score+=32
				if terrain!=last_task_terrain:score+=2
				if run.history.is_empty() or terrain!=TERRAIN.get(run.history.back().map,""):score+=1
				if score>best:
					best=score
					choices.clear()
				if score==best:choices.append(candidate)
			id=choices[rng.randi_range(0,choices.size()-1)]
			if index==0 and int(run.get("engineer_stage",0))==stage and run.get("engineer_map","") in candidates:
				id=run.engineer_map
			candidates.erase(id)
		var elite:bool=stage%5==4 and index==1
		var condition:Dictionary=load("res://scripts/expedition/catalog.gd").CONDITIONS[(stage+index)%3].duplicate()
		result.append({"map":id,"title":map_name(id),"condition":condition,"enemy":"美国" if (stage+index)%2==0 else "苏俄", "size":4800 if stage>=16 else 3200,"task":task(stage),"elite":elite,"chapter":chapter(stage),"objective":task_description(task(stage),stage)})
	for index in result.size():
		var route:Dictionary=result[index]
		if int(run.get("engineer_stage",0))==stage and route.map==run.get("engineer_map",""):
			route.bridge_support=true
		if stage<TOTAL-1 and not route.get("bridge_support",false):
			for bridge_map in ["river_delta","canal_city"]:
				if bridge_map!=route.map and not used.has(bridge_map):
					route.engineer_destination=bridge_map
					break
		var capacity:=mini(4,int(STARTS.get(route.map,2)))
		var supporters:=preload("res://scripts/expedition/field_operations.gd").allies_for(run,stage)
		var enemy_count:=mini(hostile_houses(stage,index),maxi(1,capacity-1-supporters.size()))
		if supporters.size()>0 and capacity<enemy_count+2:supporters=[]
		route.enemy_count=enemy_count
		route.support_contacts=supporters
		route.size=maxi(int(route.size),4800) if capacity>=4 else int(route.size)
		route.front_bonus=(enemy_count-1)*60
		if route.get("elite",false):route.elite_tactic=preload("res://scripts/expedition/elite_tactics.gd").select_for(stage,int(run.seed))
	return result
