extends RefCounted
const Relics=preload("res://scripts/expedition/relics.gd")

# name, first cycle, instructions. Additional kinds use the same field slot.
const BOOK:={
"muster":["点名集合",1,"三支己方地面单位同时进入集合区"],
"courier":["往返签收",1,"先到邮站，再回到己方起点取得回执，最后返回邮站"],
"survey":["轮测水位",2,"按标记先后抵达两个测点，在第二点连续驻留六秒"],
"relay_pair":["两岸通话",2,"两组地面部队同时占据两个电台五秒"],
"triage":["流动诊所",2,"伤员到场立即治疗；满血地面单位可驻留六秒完成体检"],
"mixed":["步坦会合",3,"步兵和地面载具同时到场，完成联合点验"],
"quiet":["静默监听",3,"派地面部队在监听圈内连续录音，单支需要八秒，多支更快"],
"evac":["清空作业面",3,"进入作业区放置信标，然后让己方地面部队全部撤出圈外"],
"handoff":["双人交班",4,"首支单位到场后离开，再由另一支地面单位接班"],
"fieldshop":["移动工棚",4,"把工程师和地面载具带到同一工棚，领取维修包"],
"shuttle":["分队接力",5,"一支单位留守第一站，另一支往返第二站后回到第一站"]}

static func slots(arrival:int) -> Array:
	return [0, 1] if arrival > 0 else [1]

static func pool(n:int) -> Array:
	var result:=[]
	for k:String in BOOK:
		if int(BOOK[k][1]) in [n,maxi(1,n-1)]:result.append(k)
	return result

const BACKUP:={"muster":"代办点名","mixed":"核对编组名册","fieldshop":"清点备用零件","handoff":"代签交班记录","relay_pair":"启用备用电台","shuttle":"接通备用线路"}

static func hint(o:Dictionary) -> String:
	if o.get("use_backup",false) or o.kind=="triage":
		var action:String="满血体检" if o.kind=="triage" else BACKUP.get(o.kind,"")
		var seconds:=6 if o.kind=="triage" else 12
		var lead:="伤员立即治疗；" if o.kind=="triage" else "编制不足；"
		return "%s派一队到任务起点%s · %d/%d秒"%[lead,action,int(o.get("service_time",0)),seconds]
	if o.kind=="handoff":return {"open":"首班入圈签到","leave":"首班已签到 · 请撤出","second":"换另一队入圈接班"}.get(o.phase,"首班入圈签到")
	if o.kind=="relay_pair":return "A 台：%s　B 台：%s"%[relay_hint(o,false),relay_hint(o,true)]
	match o.kind:
		"muster":return "入圈集合 · %d/3 队"%int(o.get("on_site",0))
		"mixed","fieldshop":
			var need:=PackedStringArray()
			if not o.get("specialist",false):need.append("工程师" if o.kind=="fieldshop" else "步兵")
			if not o.get("has_car",false):need.append("地面载具")
			return "派%s入圈"%"和".join(need) if not need.is_empty() else "已会合"
		"courier":return {"open":"到邮站领取信件","return":"回己方起点取回执","deliver":"返回邮站交回执"}[o.phase]
		"survey":return "到第一测点登记" if o.phase=="open" else "第二测点驻留 %d/6秒"%int(o.progress)
		"quiet":return "监听进度 %d/8秒"%int(o.progress)
		"evac":return "全员撤出作业圈" if o.phase=="armed" else "入圈放置信标"
		"shuttle":return "接力队返回第一站" if o.phase=="relay" else "留一队守第一站 · 另一队到第二站" if int(o.get("on_site",0))>0 else "派一队留守第一站"
	return BOOK[o.kind][2]

static func relay_hint(o:Dictionary,second:bool) -> String:
	if o.get("relay_a",false) and o.get("relay_b",false):return "保持通信 %d/5秒"%int(o.progress)
	return "已就位 · 留守" if o.get("relay_b" if second else "relay_a",false) else "缺一队 · 派兵到此"

static func update(m,o:Dictionary,data:Dictionary,dt:float) -> void:
	if o.get("done",false) or o.get("failed",false):return
	var total:=0
	var has_inf:=false
	var has_vehicle:=false
	var has_engineer:=false
	var at:Array=[]
	var other:Array=[]
	var infantry:=false
	var vehicle:=false
	var engineer:=false
	for u in m.world.units:
		if not m.operable(u):continue
		total+=1
		var category:=str(GameData.unit_production_category(u.data)) if o.kind in ["mixed","fieldshop"] else ""
		var is_engineer:bool=u.unit_id in ["ENGINEER","SENGINEER"]
		has_inf=has_inf or category=="infantry"
		has_vehicle=has_vehicle or category=="vehicle"
		has_engineer=has_engineer or is_engineer
		if m.near(u.position,o.get("station",o.position)):other.append(u)
		if not m.near(u.position,o.position):continue
		at.append(u)
		infantry=infantry or category=="infantry"
		vehicle=vehicle or category=="vehicle"
		engineer=engineer or u.unit_id in ["ENGINEER","SENGINEER"]
	var short:bool=(o.kind=="muster" and total<3) or (o.kind in ["relay_pair","shuttle","handoff"] and total<2) or (o.kind=="mixed" and not (has_inf and has_vehicle)) or (o.kind=="fieldshop" and not (has_engineer and has_vehicle))
	if short and total>0:o.use_backup=true
	var ok:=false
	o.on_site=at.size()
	if o.kind in ["mixed","fieldshop"]:
		o.specialist=engineer if o.kind=="fieldshop" else infantry;o.has_car=vehicle
	if o.kind=="relay_pair":
		o.relay_a=not at.is_empty();o.relay_b=not other.is_empty()
	match o.kind:
		"muster":ok=at.size()>=3
		"mixed":ok=infantry and vehicle
		"fieldshop":ok=engineer and vehicle
		"quiet","relay_pair":
			var crews:=at.size() if o.kind=="quiet" else mini(at.size(),other.size())
			o.progress=float(o.progress)+dt*Relics.progress_rate(crews) if crews>0 else 0.0
			ok=o.progress>=(8.0 if o.kind=="quiet" else 5.0)
		"survey":
			if not at.is_empty():o.phase="second"
			if o.phase=="second":o.progress=float(o.progress)+dt*Relics.progress_rate(other.size()) if not other.is_empty() else 0.0
			ok=o.progress>=6.0
		"triage":
			for u in at:
				if u.hp<u.max_hp:u.heal(u.max_hp*0.3);ok=true;break
		"courier":
			if o.phase=="open" and not at.is_empty():o.phase="return"
			elif o.phase=="return" and not other.is_empty():o.phase="deliver"
			elif o.phase=="deliver":ok=not at.is_empty()
		"evac":
			if not at.is_empty():o.phase="armed"
			ok=o.phase=="armed" and at.is_empty()
		"handoff":
			if o.phase=="open" and not at.is_empty():at[0].special.field_shift=o.id;o.phase="leave"
			elif o.phase=="leave" and at.is_empty():o.phase="second"
			elif o.phase=="second":
				for u in at:
					if u.special.get("field_shift","")!=o.id:ok=true
		"shuttle":
			if at.is_empty():
				if o.phase=="relay":
					for u in m.world.units:
						if m.operable(u):u.special.erase("field_shuttle")
				o.phase="open"
			else:
				for u in other:u.special.field_shuttle=o.id;o.phase="relay"
				for u in at:
					if u.special.get("field_shuttle","")==o.id:ok=true
	if not ok and (o.kind=="triage" or o.get("use_backup",false)):
		o.service_time=float(o.get("service_time",0))+dt*Relics.progress_rate(at.size()) if not at.is_empty() else 0.0
		ok=o.service_time>=(6.0 if o.kind=="triage" else 12.0)
	if not ok:return
	if o.kind=="fieldshop":data.kits=int(data.get("kits",0))+1
	else:data.supplies=int(data.get("supplies",0))+35
	m.finish(o,"胜利后带回 1 个维修包" if o.kind=="fieldshop" else "任务完成，胜利后 +35 补给")
