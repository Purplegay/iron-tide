extends RefCounted
## Camp-only calculations; no per-unit combat polling.
const Army=preload("res://scripts/expedition/army.gd")
const Catalog=preload("res://scripts/expedition/catalog.gd")
const Plan=preload("res://scripts/expedition/reinforcement_plan.gd")

static func time_text(seconds:float) -> String:
	var total:=maxi(0,ceili(seconds))
	return "%02d:%02d"%[total/60,total%60]

static func audience(run:Dictionary,item:Dictionary) -> String:
	var kind:=str(item.get("kind",""))
	if kind not in ["buff","trait_buff","relic"]:return ""
	var names:Dictionary={}
	var total:=0
	for unit:Dictionary in Plan.build(run):
		var id:=str(unit.id)
		var tags:=Army.tags(id,run)
		var applies:=true
		if kind=="trait_buff":applies=item.id=="support" or item.id in tags
		elif kind=="buff":
			var group:=str(Catalog.BUFFS.get(item.id,{}).get("group","all"))
			applies=group=="all" or group==Catalog.group(id)
			if item.id=="repair":applies=Catalog.group(id) in ["vehicle","naval"]
		elif kind=="relic":applies=preload("res://scripts/expedition/relics.gd").applies(item.id,id,tags)
		if not applies:continue
		total+=1;names[id]=int(names.get(id,0))+1
	var text:PackedStringArray=[]
	for id:String in names:text.append(Army.training_name(id)+" ×"+str(names[id]))
	var result:="当前出战军团：%d 个受益（含待到达英雄）"%total
	result+="\n"+("、".join(text) if total>0 else "暂无对应部队；后续招募适用单位后生效")
	if kind=="buff" and item.id in ["production","deployment","supplies","salvage","logistics"]:
		result="后勤效果："+str(Catalog.BUFFS[item.id].desc)+"\n作用于本关生产或战后经济，不按军团人数计算"
	if kind=="buff":
		var spec:Dictionary=Catalog.BUFFS.get(item.id,{})
		if spec.has("stat"):
			var current_level:=int(run.get("buffs",{}).get(item.id,0))
			var next_level:=mini(3,current_level+int(item.get("levels",1)))
			var value:=float(spec.get("value",0))
			var stat_name:String={"attack":"攻击","defense":"防御系数","hp":"生命","speed":"移速"}.get(str(spec.stat),str(spec.stat))
			result+="\n本装备%s加成：+%d%% → +%d%%"%[stat_name,roundi(current_level*value*100),roundi(next_level*value*100)]
			if spec.stat=="speed":result+="（最终移速仍受规则上限约束）"
	if kind=="trait_buff":
		var before:=int(run.get("trait_buffs",{}).get(item.id,0))
		var after:=mini(9,before+int(item.get("levels",1)))
		for threshold:int in [3,6,9]:
			if before<threshold and after>=threshold:
				result+="\n★ 解锁 %d 层机制：%s"%[threshold,Army.Progress.OPENINGS[item.id] if threshold==3 else Army.TRAITS[item.id].desc[3 if threshold==6 else 4]]
	return result

static func arrival_rows(run:Dictionary) -> Array:
	var grouped:Dictionary={}
	for entry:Dictionary in Plan.build(run):
		var key:=Plan.key(entry)
		if grouped.has(key):grouped[key].count+=1;continue
		var hero:=str(entry.get("hero",""))
		var base:=Plan.unit_cost(entry.id)*0.3
		grouped[key]={"id":entry.id,"hero":hero,"variant":str(entry.get("variant","")),"count":1,"base":base,"discount":base-float(entry.due),"due":float(entry.due)}
	return grouped.values()

static func arrival_text(run:Dictionary) -> String:
	var rows:=arrival_rows(run)
	if rows.is_empty():return "暂无待部署军团"
	var lines:PackedStringArray=[]
	lines.append("首批 %s · 全军到齐 %s（部署受阻时顺延）"%[time_text(rows[0].due),time_text(rows[-1].due)])
	for row:Dictionary in rows:
		var name:=Army.training_name(row.id) if str(row.hero).is_empty() else MetaProgress.Academy.hero_label(row.hero)
		lines.append("%s%s ×%d · %s\n  基础 %s − 超时空 %s"%[name," · 特装" if not row.variant.is_empty() else "",row.count,time_text(row.due),time_text(row.base),time_text(row.discount)])
	return "\n".join(lines)

static func snapshot(run:Dictionary,world,win:bool) -> Dictionary:
	var allied:Dictionary=world.allied_state
	var losses:Dictionary=allied.get("expedition_legion_deaths",{})
	var pending:Array=allied.get("expedition_reinforcement_plan",[])
	var alive:=0
	for unit in world.units:
		if world.actor_alive(unit) and unit.side=="ally" and unit.special.get(Plan.MEMBER,false):alive+=1
	var lost:=0
	for value in losses.values():lost+=int(value)
	var seconds:=float(allied.get("expedition_task",{}).get("elapsed",allied.get("expedition_reinforcement_clock",0.0)))
	var reason:="目标完成" if win else "任务失败"
	if not win:
		if not world.has_base_assets("ally"):reason="基地设施全部失守"
		elif allied.get("expedition_task",{}).get("kind","") in ["escort","defend","rescue"]:reason="保护或救援目标未完成"
	var report := {"stage":int(run.stage),"map":str(run.get("route",{}).get("map","")),"win":win,"seconds":seconds,"alive":alive,"pending":pending.size(),"lost":lost,"losses":losses.duplicate(),"hero_deaths":allied.get("expedition_hero_deaths",[]).duplicate(),"reason":reason,"supplies_before":int(run.supplies),"first_hero_arrival":allied.get("expedition_first_hero_arrival",-1.0)}
	report.kills = world.kills
	var met: Array = allied.get("expedition_field_ops", {}).get("met_contacts", [])
	if not met.is_empty():report.met_contacts = met.duplicate()
	if allied.has("expedition_tally"): report.tally = allied.expedition_tally.duplicate(true)
	return report

static func headline(report:Dictionary) -> String:
	var tally:Dictionary=report.get("tally",{})
	var dead:=0
	for count in tally.get("losses",{}).values(): dead+=int(count)
	return "%s　用时 %s　敌军击毁 %s　己方损失 %s　采矿收入 %s" % ["撤离" if report.get("retreat",false) else ("胜利" if report.win else "失败"),time_text(report.seconds),str(report.get("kills","—")),str(dead) if tally.has("losses") else "—",str(roundi(tally.ore)) if tally.has("ore") else "—"]

static func reward_losses(run:Dictionary) -> String:
	var reports:Array=run.get("battle_reports",[])
	if reports.is_empty():return ""
	var last:Dictionary=reports.back()
	if not last.get("win",false) or int(last.stage)!=int(run.stage)-1:return ""
	var losses:Dictionary=last.get("losses",{})
	var total:=0
	var highest:=""
	for id:String in losses:
		total+=int(losses[id])
		if int(losses[id])>int(losses.get(highest,0)):highest=id
	var wounded:=PackedStringArray()
	for id:String in last.get("hero_deaths",[]):
		if id in run.get("wounded_heroes",[]):wounded.append(MetaProgress.Academy.HEROES.get(id,id))
	if not wounded.is_empty():return "上场战损　%s 待救治 · 军团阵亡 %d"%["、".join(wounded),total]
	if highest.is_empty():return "上场战损　军团零阵亡"
	return "上场战损　%s ×%d%s"%[Army.training_name(highest),losses[highest]," · 合计 %d"%total if total>int(losses[highest]) else ""]

static func review_text(report:Dictionary) -> String:
	if report.is_empty():return "这份旧战报没有留下战损记录。"
	var lines:PackedStringArray=[headline(report),str(report.get("reason","")),"军团在场存活 %d · 未抵达 %d · 真实阵亡 %d"%[report.get("alive",0),report.get("pending",0),report.get("lost",0)]]
	var tally:Dictionary=report.get("tally",{})
	var fallen:Dictionary=tally.get("losses",{})
	for id:String in fallen: lines.append("己方战损：%s ×%d"%[Army.training_name(id),fallen[id]])
	var scorers:Dictionary=tally.get("scorers",{})
	var best:=0
	for count in scorers.values(): best=maxi(best,int(count))
	var top:PackedStringArray=[]
	for id:String in scorers:
		if int(scorers[id])==best: top.append(Army.training_name(id))
	if best>0: lines.append("击毁最多兵种：%s（%d）"%["、".join(top),best])
	for id:String in report.get("losses",{}):lines.append("损失：%s ×%d"%[Army.training_name(id),report.losses[id]])
	for id in report.get("hero_deaths",[]):lines.append("英雄阵亡："+str(MetaProgress.Academy.HEROES.get(id,id)))
	var hero_time:=float(report.get("first_hero_arrival",-1))
	if hero_time>=0:lines.append("首位英雄到场："+time_text(hero_time))
	if report.has("school_loot"):lines.append("收藏品入库："+str(report.school_loot))
	if report.has("school_page"):lines.append("驻防基地 · 百合子手记开放第 %d 章"%int(report.school_page))
	for id: String in report.get("field_heroes", []):
		lines.append("%s 加入本轮远征。%s" % [preload("res://scripts/expedition/hero_field_stories.gd").name_of(id), preload("res://scripts/expedition/hero_field_stories.gd").BOOK[id].reply])
	for id: String in report.get("driver_portrait_rewards", []):
		lines.append("%s的驾驶员头像已解锁，可在「英雄养成」或「支线百科 → 英雄故事」切换。" % MetaProgress.Academy.HEROES[id])
	if report.has("hero_reunion"):lines.append(report.hero_reunion)
	for mark: Dictionary in report.get("hero_chronicles", []):
		var stories = preload("res://scripts/expedition/hero_field_stories.gd")
		var chapter: Dictionary = stories.chapter_for(mark)
		lines.append("%s的同行故事《%s》已收入支线百科。\n%s" % [stories.name_of(mark.hero), chapter.title, chapter.text])
	if report.has("reward_breakdown"):
		var amounts:PackedStringArray=[]
		for key:String in report.reward_breakdown:amounts.append("%s +%d"%[key,report.reward_breakdown[key]])
		lines.append("胜利补给："+" · ".join(amounts))
	if int(report.get("labs_secured",0))>0:lines.append("接管实验室：%d 座"%int(report.labs_secured))
	if report.get("wave_intel",false):lines.append("带回黑匣子 · 下一关路线开放首波敌军情报")
	if report.has("engineer_map"):lines.append("救出桥梁工兵 · 下一关可前往"+preload("res://scripts/expedition/campaign.gd").map_name(report.engineer_map)+"抢修侧桥")
	if int(report.get("field_kits",0))>0:lines.append("支线回收 · 维修包 +%d"%report.field_kits)
	for contact:Dictionary in report.get("field_contacts",[]):lines.append("救援联络员：%s · 约定第 %d 关参战"%[contact.name,contact.stage])
	for unit_id:String in report.get("training_permits",[]):
		var unit:=GameData.get_unit(unit_id)
		var facility:String={"GAPILE":"兵营","NAHAND":"兵营","GAWEAP":"战车工厂","NAWEAP":"战车工厂","GAAIRC":"空指部"}.get(unit.built_at,"生产设施")
		lines.append("获赠本轮生产许可：%s · 己方%s生产，需雷达设施"%[unit.name,facility])
	if report.has("auto_sale"):lines.append("战后自动出售 %d 个 · 返还 %d 补给"%[report.auto_sale.count,report.auto_sale.supplies])
	return "\n".join(lines)

static func economy_text(run:Dictionary) -> String:
	var ledger:Dictionary=run.get("supply_ledger",{})
	var lines:PackedStringArray=["补给流水（从本次更新后开始记录）"]
	for key:String in ledger:lines.append("%s：收入 %d / 支出 %d"%[key,ledger[key].get("in",0),ledger[key].get("out",0)])
	if ledger.is_empty():lines.append("暂无新交易")
	var reports:Array=run.get("battle_reports",[])
	if not reports.is_empty():
		var losses:=0;var pending:=0;var seconds:=0.0
		for report:Dictionary in reports:losses+=int(report.lost);pending+=int(report.pending);seconds+=float(report.seconds)
		lines.append("已记录 %d 场 · 平均用时 %s · 累计军团阵亡 %d · 战末未抵达累计 %d"%[reports.size(),time_text(seconds/reports.size()),losses,pending])
	return "\n".join(lines)
