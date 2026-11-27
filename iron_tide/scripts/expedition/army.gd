extends RefCounted
const Campaign=preload("res://scripts/expedition/campaign.gd")
const Training=preload("res://scripts/rules/skill_training.gd")
const Growth=preload("res://scripts/expedition/growth.gd")
const Talents=preload("res://scripts/expedition/talents.gd")
const Progress=preload("res://scripts/expedition/trait_progression.gd")
const TRAITS := {
	"siege_team":{"name":"围攻小队","min_stage":28,"steps":[1,2,3,6,9],"icon":"sight","desc":["直击 +2%","直击 +4%","连续直击同一目标时额外造成 10% 伤害。","连续命中同一目标三次，恢复 6% 最大生命，命中次数重新累计。","第三次命中还会压制目标单位 4 秒，使其对我方的直击伤害降低 20%。"]},
	"pursuit":{"name":"接力突袭","min_stage":26,"steps":[1,2,3,6,9],"icon":"focus","desc":["直击 +2%","直击 +4%","换目标直击额外造成 15% 伤害。","换目标时另获得 8% 最大生命护盾，每 6 秒一次。","换目标后，4 秒内再次命中同一目标追加 35% 伤害一次。"]},
	"infantry":{"name":"步兵军团","steps":[1,2,3,6,9],"icon":"escort","desc":["生命 +10%","生命 +20%；战地接力恢复","生命 +30%；战后额外恢复 15%","战地医疗：步兵每 5 秒恢复 2% 生命","不屈军团：保留低于 40% 生命受击得 15% 护盾（20 秒冷却）；本羁绊医疗的溢出治疗累积为护盾，最高 20% 生命"]},
	"vehicle":{"name":"钢铁装甲","steps":[1,2,3,6,9],"icon":"guard","desc":["生命 +10%","生命 +20%；行驶减伤 10%","生命 +30%；行驶减伤 15%，首次交战护盾","驻车整备：装甲停稳 4 秒获得 10% 生命护盾，冷却 20 秒","装甲突击：持续行驶 2 秒后命中 +20%（6 秒冷却）；驻车整备另装填 3 发突击弹，行驶时每发直击再 +15%，每 0.25 秒最多消耗一发"]},
	"air":{"name":"航空联队","steps":[1,2,3,6,9],"icon":"air","desc":["生命 +10%","生命 +20%；非交战飞行移速 +10%","生命 +25%；补弹后首击 +20%","返航维护：航空单位正常补满弹药时恢复 15% 生命","连续出击：正常补满弹药获得 20% 护盾和 3 发直击 +20% 的强化弹；每 0.25 秒最多消耗一发，重补弹只刷新不累计"]},
	"naval":{"name":"海上舰队","steps":[1,2,3,6,9],"icon":"naval","desc":["生命 +10%","生命 +20%；脱战每秒恢复 0.5%","生命 +25%；脱战每秒恢复 1%","战斗抢修：海军交战中也每秒恢复 0.5% 生命","隔舱反攻：低于 50% 生命受击获得 20% 护盾（30 秒冷却）；持有远征护盾时直击 +20% 并回血 2%，冷却 4 秒"]},
	"fortify":{"name":"固守阵线","steps":[1,2,3,6,9],"icon":"guard","desc":["停稳减伤 8%","停稳减伤 12%，攻击 +10%","停稳减伤 15%，攻击 +15%","阵地屏障：固守单位停稳 3 秒获得 10% 生命护盾，冷却 20 秒","阵地反击：停稳 5 秒命中 +40%（8 秒冷却）；持盾受击每秒最多积累 1 次、最多 3 次，蓄满后下次阵地强击再 +60% 并清空"]},
	"mobile":{"name":"机动突击","steps":[1,2,3,6,9],"icon":"speed","desc":["移动速度 +8%","移动速度 +12%，行军后首击 +15%","移动速度 +15%，行军后首击 +25%","战术补给：行军首击触发时恢复 5% 生命","游击闭环：持续移动 2 秒得 15% 护盾（20 秒冷却）；行军首击所需距离从三格降至两格，冷却从 8 秒降至 4 秒"]},
	"support":{"name":"战地支援","steps":[1,2,3,6,9],"icon":"heal","desc":["战后额外恢复 10%","战后额外恢复 15%，整备 -15%","战后额外恢复 20%，整备 -25%，免费补员一次","全军医疗：我方作战部队（不含临时单位和任务 NPC）每 5 秒恢复 2% 生命","战地动员：低于 50% 生命受击得 10% 护盾（30 秒冷却）；每次羁绊医疗后生命达到 90% 的单位，直击 +15%，持续 5 秒"]},
	"energy":{"name":"能量协同","steps":[1,2,3,6,9],"icon":"spark","desc":["能量直击 +8%","能量直击 +12%，异编制协同 +15%","能量直击 +15%，异编制协同 +25%","充能护盾：能量兵种直击获得 8% 生命护盾，冷却 6 秒","协同过载：不同兵种协同触发时额外 +40%（4 秒冷却），并使目标随后 4 秒受到全军直击额外 +15%，重复触发只刷新"]},
	"artillery":{"name":"重炮火网","steps":[1,2,3,6,9],"icon":"explosive","desc":["炮击 +8%","炮击 +12%，标定炮击 +20%","炮击 +15%，标定炮击 +30%","开幕轰击：对生命高于 75% 的目标炮击额外 +20%","纵深压制：标记满 2 秒后命中额外 +50%（10 秒冷却），被命中敌方单位接下来 4 秒对我方的直接伤害降低 20%"]},
	"special":{"name":"特种行动","steps":[1,2,3,6,9],"icon":"sight","desc":["特种单位生命 +10%","生命 +15%，目标设施伤害 +20%","生命 +20%，目标设施伤害 +30%，交互加速","破袭补给：命中任务目标或生命低于 35% 的敌人，恢复 5% 生命，冷却 6 秒","连锁终结：对生命低于 35% 目标直击 +40%（4 秒冷却）；击杀敌方单位后刷新终结与破袭治疗冷却"]}
}
const ROLES := {
	"fortify":["E1","GGI","SREF","SCHP","V3","DRED","CLEG","R3TESLA"],
	"mobile":["E2","MTNK","HTNK","MGTK","APOC","R3APOC","R3REAPER","R3MIRAGE","DLPH","SUB"],
	"support":["FV","HTK","AEGIS","LCRF","SAPC","SHAD","ENGINEER","SENGINEER","FLAKT"]
}
const SCHOOLS := {
	"siege_team":["E1","E2","GGI","HTNK","MTNK","SHK","SREF","V3","DRED","BEAG"],
	"pursuit":["E1","E2","MTNK","HTNK","FV","HTK","DEST","ORCA"],
	"energy":["SHK","TTNK","SREF","R3MIRAGE","R3TESLA","R3FUTURE"],
	"artillery":["V3","DRED","SCHP","HTNK","APOC","R3APOC","CARRIER","DEST"],
	"special":["GHOST","TANY","BORIS","CLEG","IVAN","CIVAN","DESO"]
}

static func initialize(run:Dictionary,opening:Dictionary) -> void:
	run.trait_buffs={}
	run.unit_growth={}
	run.relics={}
	run.free_upgrade_stage=0
	run.native_talents={}
	run.specializations={}
	run.special_squads=[]
	run.active_roster=[]
	run.tracked_traits=["vehicle","support"]
	run.shop_misses=0
	run.event={}
	run.event_history=[]
	run.repair_coupon=false
	for id:String in opening:
		if int(opening[id])<=0:continue
		run.active_roster.append(id)

static func tags(id:String,_run:Dictionary={}) -> Array:
	var result:Array=[]
	var group:String=GameData.unit_production_category(GameData.get_unit(id))
	if group in ["infantry","vehicle","air","naval"] and id not in ["ENGINEER","SENGINEER","CMIN","HARV","AMCV","SMCV"]:result.append(group)
	for key:String in ROLES:
		if id in ROLES[key]:result.append(key)
	for key:String in SCHOOLS:
		if id in SCHOOLS[key]:result.append(key)
	return result

static func trait_audience(key:String,run:Dictionary) -> String:
	var scope:String={"infantry":"作战步兵（不含工程师）","vehicle":"作战载具（不含矿车、基地车）","air":"航空单位","naval":"海军单位","support":"我方作战部队（不含临时单位和任务 NPC）"}.get(key,"")
	if scope.is_empty():
		var names:PackedStringArray=[]
		for id:String in ROLES.get(key,SCHOOLS.get(key,[])):names.append(training_name(id))
		scope="、".join(names)
	var owned:Array=run.get("licenses",[]).duplicate()
	for id:String in available(run)+run.get("heroes",[]):
		if id not in owned:owned.append(id)
	var beneficiaries:PackedStringArray=[]
	for id:String in owned:
		if key=="support" or key in tags(id):beneficiaries.append(training_name(id))
	return "作用对象："+scope+"\n本轮受益兵种："+("、".join(beneficiaries) if not beneficiaries.is_empty() else "暂无；招募对应兵种后自动生效")

static func available(run:Dictionary) -> Array:
	var result:Array=[]
	for row:Dictionary in run.get("survivors",[])+run.get("reinforcements",[])+run.get("special_squads",[]):
		if not str(row.get("hero","")).is_empty():continue
		if int(row.get("count",1))>0 and row.id not in result:result.append(row.id)
	return result

static func counts(run:Dictionary) -> Dictionary:
	return run.get("trait_buffs",{}).duplicate()

static func trait_detail(key:String,count:int) -> String:
	var detail:=Progress.summary(key,count)
	if count>=2:
		match key:
			"infantry":detail+="；战地接力恢复"+("；战后额外恢复 15%" if count>=3 else "")
			"vehicle":
				if count>=3:detail+="；首次受击护盾 10%"
			"air":detail+="；非交战飞行移速 +10%"+("；补弹后首击 +20%" if count>=3 else "")
			"naval":detail+="；脱战每秒恢复 "+("1%" if count>=3 else "0.5%")
			"support":
				if count>=3:detail+="；每关免费补员一次"
			"energy":detail+="；异编制协同 +"+("25%" if count>=3 else "15%")
			"artillery":detail+="；标定炮击 +"+("30%" if count>=3 else "20%")
			"special":
				if count>=3:detail+="；任务交互速度 +20%"
	if count>=3:detail+="\n3 层追加："+str(Progress.OPENINGS[key])
	if count>=6:detail+="\n6 层追加："+str(TRAITS[key].desc[3])
	if count>=9:detail+="\n9 层追加："+str(TRAITS[key].desc[4])
	return detail

static func trait_level(key:String,count:int) -> int:
	var level:=0
	for threshold:int in TRAITS[key].steps:
		if count>=threshold:level+=1
	return level

static func levels(run:Dictionary) -> Dictionary:
	var result:Dictionary={}
	var tally:=counts(run)
	for key:String in TRAITS:result[key]=trait_level(key,int(tally.get(key,0)))
	return result

static func native_id(id:String) -> String:
	return Training.talent_id(id)

static func native_rank(run:Dictionary,id:String) -> int:
	return Talents.minimum(run,id)

static func native_name(id:String) -> String:
	return str(MetaProgress.talent_options(id).get(native_id(id),{}).get("name","无自带天赋"))

static func training_name(id:String) -> String:
	return str(GameData.get_unit(id).get("name",id))

static func license_unit(run:Dictionary,id:String) -> void:
	if id not in run.catalog:run.catalog.append(id)
	if id not in run.licenses:run.licenses.append(id)

static func add_unit(run:Dictionary,id:String,count:int) -> void:
	license_unit(run,id)
	run.reinforcements.append({"id":id,"count":count})
	auto_field(run,id)

static func auto_field(run:Dictionary,id:String) -> void:
	if id in run.active_roster or run.active_roster.size()>=Campaign.slots(run):return
	if int(deployment(run).remaining)>0:run.active_roster.append(id)

static func promote_native(run:Dictionary,id:String,rank:int) -> void:
	Talents.grant(run,{"id":id,"rank":rank})

static func apply_context(run:Dictionary,context:Dictionary) -> void:
	Growth.apply_context(run,context)
	context.expedition.relics=run.get("relics",{}).duplicate()
	context.expedition.traits=levels(run)
	context.expedition.trait_buffs=counts(run)
	context.expedition.specializations=run.specializations.duplicate(true)
	context.expedition.active_roster=run.active_roster.duplicate()
	context.expedition.native_talents=run.native_talents.duplicate()
	Talents.apply(run,context)

static func native_effect_rank(actor) -> int:
	var id:=native_id(actor.unit_id)
	if id.is_empty():return -1
	var rows:Dictionary=BattleRequest.combat_context.get("unit_talents",{}).get(actor.unit_id,{})
	var base:int=rows.get(id,-1) if actor.side=="ally" else -1
	return base if actor.side=="ally" else -1

static func roster_error(run:Dictionary) -> String:
	if run.active_roster.is_empty():return "至少选择一种出战编制"
	if run.active_roster.size()>Campaign.slots(run):return "出战编制超过本章上限"
	var present:=available(run)
	var seen:Array=[]
	for id in run.active_roster:
		if id in seen or id not in present:return "出战编制缺少部队，请先补员"
		seen.append(id)
	return ""

static func limit(id:String) -> int:
	var capacity:=8 if GameData.unit_production_category(GameData.get_unit(id))=="infantry" else 4
	var build_limit:=int(preload("res://scripts/core/yr_death_rules.gd").type_data(id).get("buildlimit",-1))
	return mini(capacity,build_limit) if build_limit>0 else capacity

static func inventory(run:Dictionary) -> Array:
	var result:Array=run.get("survivors",[]).duplicate(true)
	for squad:Dictionary in run.get("reinforcements",[]):
		for n in int(squad.count):result.append({"id":squad.id,"hp":1.0,"rank":0,"xp":0.0,"hero":"","variant":""})
	for squad:Dictionary in run.get("special_squads",[]):
		var present:=0
		for row:Dictionary in result:
			if row.get("variant","")==squad.token:present+=1
		for n in maxi(0,int(squad.count)-present):result.append({"id":squad.id,"hp":1.0,"rank":0,"xp":0.0,"hero":"","variant":squad.token})
	return result

static func quantity(run:Dictionary,id:String) -> int:
	var count:=0
	for row:Dictionary in inventory(run):
		if row.id==id and str(row.get("hero","")).is_empty():count+=1
	return count

# Unfilled places for this type, counting both deployed troops and reserves.
static func room(run:Dictionary,id:String) -> int:
	return maxi(0,limit(id)-quantity(run,id))

static func deployment(run:Dictionary) -> Dictionary:
	var rows:=inventory(run)
	var owned:Dictionary={}
	for row:Dictionary in rows:
		if str(row.get("hero","")).is_empty():owned[row.id]=int(owned.get(row.id,0))+1
	var selected:Dictionary={}
	var remaining:=Campaign.population(int(run.stage))
	for id:String in run.get("active_roster",[]):
		var maximum:=mini(int(owned.get(id,0)),limit(id))
		var count:=clampi(int(run.get("deployment_counts",{}).get(id,maximum)),0,mini(maximum,remaining))
		selected[id]=count
		remaining-=count
	var pending:=selected.duplicate()
	var field:Array=[]
	var reserve:Array=[]
	for row:Dictionary in rows:
		if not str(row.get("hero","")).is_empty():field.append(row)
		elif int(pending.get(row.id,0))>0:
			field.append(row)
			pending[row.id]-=1
		else:reserve.append(row)
	return {"field":field,"reserve":reserve,"counts":selected,"owned":owned,"remaining":remaining}

static func synchronize(run:Dictionary) -> void:
	for squad:Dictionary in run.special_squads:
		var count:=0
		for row:Dictionary in run.survivors:
			if row.get("variant","")==squad.token:count+=1
		squad.count=count
	var present:=available(run)
	var active:Array=[]
	for id:String in run.active_roster:
		if id in present:active.append(id)
	run.active_roster=active

static func disabled_native(run:Dictionary,id:String) -> bool:
	return run.get("disabled_native",{}).has(id) and not run.native_talents.has(id)

static func valid(run:Dictionary) -> bool:
	if not Talents.valid(run):return false
	if not Growth.valid(run):return false
	var stacks:Variant=run.get("trait_buffs",{})
	if not stacks is Dictionary:return false
	for key in stacks:
		if not TRAITS.has(key) or not stacks[key] is int or stacks[key]<0 or stacks[key]>9:return false
	for key in ["native_talents","specializations"]:
		if not run.get(key) is Dictionary:return false
	for key in ["special_squads","active_roster","tracked_traits","history"]:
		if not run.get(key) is Array:return false
	if run.active_roster.size()>Campaign.slots(run) or run.tracked_traits.size()>2:return false
	for id in run.native_talents:
		if native_id(id).is_empty() or int(run.native_talents[id])<0 or int(run.native_talents[id])>3:return false
	for id in run.specializations:
		if id not in ["E1","GGI","DESO","SCHP"] or run.specializations[id] not in ["a","b"] or native_rank(run,id)<3:return false
	var tokens:Array=[]
	for squad in run.special_squads:
		if not squad is Dictionary:return false
		for field in ["id","token","tier","native_rank","count"]:
			if not squad.has(field):return false
		if not GameData.unit_index.has(squad.id) or int(squad.tier) not in [1,2,3] or int(squad.count)<0 or int(squad.count)>8 or squad.token in tokens:return false
		tokens.append(squad.token)
	for row in run.survivors:
		if not row is Dictionary or not GameData.unit_index.has(row.get("id","")) or not is_finite(float(row.get("hp",0))) or float(row.get("hp",0))<=0 or float(row.hp)>1:return false
		if not str(row.get("variant","")).is_empty() and row.variant not in tokens:return false
	for row in run.reinforcements:
		if not row is Dictionary or not GameData.unit_index.has(row.get("id","")) or int(row.get("count",0))<=0:return false
	return true
