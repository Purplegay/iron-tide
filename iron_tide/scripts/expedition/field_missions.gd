extends RefCounted
## State and actor tags survive battle snapshots. Positions are world coordinates.
const BASIC_NAMES:={"contact":"救援联络人","cache":"回收遗留军需","intel":"截获前线情报"}
const Assign=preload("res://scripts/expedition/field_assignments.gd")
static var NAMES:=names()
static func names() -> Dictionary:
	var result:=CORE.duplicate()
	for k:String in Assign.BOOK:result[k]=Assign.BOOK[k][0]
	return result
const CORE:={"radio":"失真的呼救","box":"黑匣子接力","fuel":"油罐车 · 一车两用","divert":"借敌之手","engineer":"断桥工兵","bridge":"抢修侧桥"}
const CALLS:=["白桦","云雀"]
const REACH:=150.0
const REPAIR_RADIUS:=410.0
const BOX_HALF_WIDTH:=14.0
var world
var _box_holder

static func candidate(seed_value:int,stage:int,route:Dictionary,cycle:int=0) -> String:
	var kinds:Array=["radio","box","fuel",""]
	if route.get("task","")=="rescue":kinds.erase("radio")
	if route.get("task","")=="escort":kinds.erase("fuel");kinds.erase("box")
	if stage>=30:kinds.erase("box")
	if int(route.get("enemy_count",1))>1:kinds.append("divert")
	if route.has("engineer_destination"):kinds.append("engineer")
	var roll:=hash("%d/%d/%s"%[seed_value,stage,route.get("map","")])
	var original:String=kinds[posmod(roll,kinds.size())]
	if original in ["radio","engineer"] or cycle<=0:return original
	for cargo: String in ["box", "fuel"]:
		if cargo in kinds:kinds.append_array([cargo, cargo])
	kinds.append_array(Assign.pool(clampi(cycle,1,5)))
	var field_roll := hash("%d/%d/%s/field" % [seed_value, stage, route.get("map","")])
	return kinds[posmod(field_roll,kinds.size())]

func prepare(field,o:Dictionary,kind:String,seed_value:int) -> bool:
	if not NAMES.has(kind):return false
	var sites:Array=field.occupied_points()
	var origin:Vector2=world.allied_state.expedition_task.origin
	var axis:Vector2=origin.direction_to(world.enemy_base_center)
	var flank:=axis.orthogonal()
	if kind=="fuel":
		var rendezvous:Vector2=Vector2.INF
		for direction:Vector2 in [flank,-flank,-axis,axis]:
			var point:Vector2=field.find_site(origin+direction*760.0,sites,true)
			if point.is_finite() and point.distance_to(origin)<=1200.0:
				rendezvous=point
				break
		if not rendezvous.is_finite():return false
		o.position=rendezvous
	sites.append(o.position)
	var points:Array[Vector2]=[]
	if Assign.BOOK.has(kind):
		o.kind=kind;o.phase="open";o.reward=0
		if kind=="courier":o.station=origin
		if kind in ["relay_pair","survey","shuttle"]:
			var p:Vector2=field.find_site(o.position+flank*850,sites)
			if not p.is_finite():return false
			o.station=p
		return true
	var count:int={"radio":2,"box":0,"fuel":1,"divert":2,"engineer":0}[kind]
	for i in count:
		var desired:Vector2=o.position+flank*(850.0 if i==0 else -850.0)+axis*320.0
		var p:Vector2=field.find_site(desired,sites)
		if not p.is_finite():return false
		sites.append(p);points.append(p)
	o.kind=kind;o.phase="open";o.reward=0
	match kind:
		"engineer":
			var engineer=spawn("SENGINEER" if world.roster_faction()=="soviet" else "ENGINEER","ally",o.position)
			if engineer==null:return false
			engineer.special.expedition_mission_unit=true
			engineer.special.field_engineer=o.id
			engineer.special.expedition_objective_name="受困的桥梁工兵"
			engineer.order_stop();engineer.hold_position=true
			o.destination=Expedition.state.route.engineer_destination
		"radio":
			o.stations=points;o.real=posmod(hash("%s:%s:radio"%[seed_value,o.position]),2)
			o.listened=false;o.ambushed=false
		"box":
			o.cargo=o.position;o.depot=origin;o.pulse=0.0
		"fuel":
			o.station=points[0]
			var truck=spawn("TRUCKA" if GameData.unit_index.has("TRUCKA") else "HTK","ally",o.position)
			if truck==null:return false
			if truck.position.distance_to(origin)>1200.0 or not field.safe_rescue_spawn(truck.position):
				truck.queue_free()
				return false
			o.position=truck.position
			truck.special.field_tanker=o.id;truck.special.expedition_mission_unit=true
			truck.special.expedition_objective_name="支线油罐车"
			truck.order_stop();truck.hold_position=true
			var placed:=false
			for n in 8:
				var center:Vector2=world.snap_build_pos(o.station+Vector2.RIGHT.rotated(TAU*n/8)*265.0)
				if not world.build_spot_ok(center,GameData.get_building("CAOUTP"),true,"neutral",world).ok:continue
				var site=world._place_building("CAOUTP","neutral",center,true)
				if site==null:continue
				site.special.field_outpost=o.id;o.outpost=center;placed=true;break
			if not placed:truck.queue_free();return false
		"divert":
			o.relay=points[0];o.rally=points[1];o.truck_at=o.position
			var convoy:Array=[]
			for id in ["HTK","E2","HTNK"]:
				var u=spawn(id,"enemy",o.position+flank*65.0*convoy.size())
				if u==null:
					for created in convoy:created.queue_free()
					return false
				u.special.field_convoy=o.id
				u.special.field_lead=convoy.is_empty()
				if convoy.is_empty():u.special.expedition_objective_name="敌方通讯车"
				u.order_stop();u.hold_position=true
				convoy.append(u)
	return true

func deploy_bridge(data:Dictionary) -> void:
	for hut in world.buildings:
		if not world.actor_alive(hut) or hut.building_id!="CABHUT" or not hut.special.has("bridge_span") or hut.special.get("bridge_repaired",true):continue
		var worker=spawn("SENGINEER" if world.roster_faction()=="soviet" else "ENGINEER","ally",world.player_start()+Vector2(120,80))
		if worker==null:continue
		worker.special.expedition_objective_name="回援的桥梁工兵"
		worker.special.expedition_mission_unit=true
		AlliedAbilities.use(worker,"allied_bridge",hut)
		hut.special.field_bridge=true
		data.objectives.append({"id":"field_bridge","kind":"bridge","position":hut.position,"phase":"open","done":false,"failed":false,"reward":0})
		return

func spawn(id:String,side:String,at:Vector2):
	var origin:Vector2=world.allied_state.expedition_task.origin
	var point:Vector2=world.path_service.nearest_reachable(at,origin,false,6)
	if not point.is_finite() or point.distance_to(at)>210:return null
	return world.spawn_unit(id,side,point)

func near(a:Vector2,b:Vector2) -> bool:
	return a.distance_squared_to(b)<=REACH*REACH

func operable(u) -> bool:
	return world.actor_alive(u) and u.side=="ally" and not u.is_air and not u.is_naval and u.embarked_in==null and not u.special.has("expedition_mission_unit") and not u.special.has("expansion_temporary")

func visitor(point:Vector2):
	for u in world.units:
		if operable(u) and near(u.position,point):return u
	return null

func tagged(key:String,id:String):
	for u in world.units:
		if world.actor_alive(u) and u.special.get(key,"")==id:return u
	return null

func finish(o:Dictionary,text:String,failed:=false) -> void:
	o.done=not failed;o.failed=failed;o.result=text
	Events.emit_message(NAMES[o.kind]+" · "+text,UiKit.COL_SIDE_MISSION)

func tick(o:Dictionary,data:Dictionary,seconds:float) -> void:
	if o.done:
		if o.kind=="fuel" and o.phase=="station":
			var site=outpost(o) if o.has("outpost") else null
			if site!=null:site._repair_active=false
			if o.has("outpost") and (site==null or site.side!="ally"):return
			for u in world.units:
				if operable(u) and u.position.distance_to(o.get("outpost",o.station))<=REPAIR_RADIUS and u.hp<u.max_hp and GameData.unit_production_category(u.data)=="vehicle":
					u.heal(u.max_hp*0.025*seconds)
					if site!=null:site._repair_active=true
		return
	if o.failed:return
	if Assign.BOOK.has(o.kind):Assign.update(self,o,data,seconds);return
	match o.kind:
		"engineer":
			var worker=tagged("field_engineer",o.id)
			if worker==null or worker.side!="ally":finish(o,"工兵已失联",true)
			else:
				o.position=worker.position
				if visitor(o.position)!=null:
					worker.queue_free()
					data.engineer_map=o.destination
					finish(o,"工兵已撤出，胜利后揭示下一关侧桥")
		"bridge":
			for hut in world.buildings:
				if world.actor_alive(hut) and hut.special.get("field_bridge",false):
					if hut.special.get("bridge_repaired",false):finish(o,"侧桥已开放，地面部队可通行")
					return
			finish(o,"维修小屋已损失",true)
		"radio":radio(o)
		"box":black_box(o,data,seconds)
		"fuel":fuel(o)
		"divert":divert(o,data)

func radio(o:Dictionary) -> void:
	if not o.listened and visitor(o.position)!=null:
		o.listened=true
		Events.emit_message("监听记录：今日识别码「%s」。"%CALLS[o.real],UiKit.COL_SIDE_MISSION)
	for i in 2:
		if (o.ambushed and i!=o.real) or visitor(o.stations[i])==null:continue
		var rescued:bool=i==o.real
		if not rescued:o.ambushed=true
		var arrived:=0
		for n in 3:
			var at:Vector2=o.stations[i]+Vector2.RIGHT.rotated(TAU*n/3.0)*(60 if rescued else 185)
			var id:="E1" if rescued and Expedition.state.get("country","美国")=="美国" else "E2"
			var u=spawn(id,"ally" if rescued else "enemy",at)
			if u==null:continue
			arrived+=1
			if not rescued:u.order_move(o.stations[i],true)
		if rescued:
			if arrived>0:finish(o,"%d 名失联步兵加入本场指挥"%arrived)
		else:Events.emit_message("电台暴露：是假信号！另一座电台仍在呼救。",UiKit.COL_SIDE_MISSION)
		return

func drop_box(o:Dictionary,u) -> void:
	u.special.erase("field_box")
	_box_holder=null
	var origin:Vector2=world.allied_state.expedition_task.origin
	var p:Vector2=world.path_service.nearest_reachable(u.position,origin,false,24)
	o.cargo=p if p.is_finite() else u.position
	o.phase="open"

func box_holder(id:String):
	if not is_instance_valid(_box_holder) or not world.actor_alive(_box_holder) or _box_holder.special.get("field_box","")!=id:
		_box_holder=tagged("field_box",id)
	return _box_holder

func try_pick_box(o:Dictionary) -> void:
	if o.phase!="open" or o.done or o.failed:return
	var closest=null
	var best:=INF
	var candidates:Array=world.neighborhood.nearby(o.cargo,BOX_HALF_WIDTH+world.neighborhood.max_unit_radius,true) if world.units.size()>=96 else world.units
	for u in candidates:
		if not operable(u) or u.special.has("field_box_dropped"):continue
		var d:float=u.position.distance_squared_to(o.cargo)
		if d<=pow(BOX_HALF_WIDTH+u.radius,2) and d<best:
			closest=u
			best=d
	if closest==null:return
	for u in world.units:
		if world.actor_alive(u):u.special.erase("field_box_dropped")
	_box_holder=closest
	closest.special.field_box=o.id
	o.phase="carry";o.cargo=closest.position;o.pulse=0.0
	Events.emit_message("%s 已拾取黑匣子，送回蓝色交付点。" % closest.display_name,UiKit.COL_SIDE_MISSION)

func black_box(o:Dictionary,data:Dictionary,seconds:float) -> void:
	if o.phase=="carry":
		var carrier=box_holder(o.id)
		if carrier==null:o.phase="open";return
		if not operable(carrier):
			drop_box(o,carrier);return
		o.cargo=carrier.position
		if near(carrier.position,o.depot):
			carrier.special.erase("field_box")
			_box_holder=null
			data.wave_intel=true
			data.kits=int(data.get("kits",0))+1
			finish(o,"黑匣子已送达；胜利后带回 1 个维修包并揭示下一关首波敌军")
			return
		o.pulse=float(o.pulse)-seconds
		if o.pulse<=0:
			o.pulse=5.0
			if is_instance_valid(world.fog):
				for side:String in BattleRequest.house_teams:
					if not BattleRequest.friendly("ally",side):world.fog._reveal(side,carrier.position,200.0,1.5)
		return
	for u in world.units:
		if world.actor_alive(u) and u.special.has("field_box_dropped") and u.position.distance_to(o.cargo)>BOX_HALF_WIDTH+u.radius:u.special.erase("field_box_dropped")
	try_pick_box(o)

func outpost(o:Dictionary):
	for site in world.buildings:
		if world.actor_alive(site) and site.special.get("field_outpost","")==o.id:return site
	return null

func powered_outpost(o:Dictionary) -> bool:
	var site=outpost(o)
	return site!=null and site.side=="ally"

func fuel(o:Dictionary) -> void:
	var truck=tagged("field_tanker",o.id)
	if truck==null or truck.side!="ally":
		finish(o,"油罐车已损失",true);return
	o.truck_at=truck.position
	if o.phase=="open" and visitor(truck.position)!=null:
		o.phase="choice"
		Events.emit_message("已接应油罐车，请在车旁选择护送或拆车。",UiKit.COL_SIDE_MISSION)
	if o.has("outpost") and outpost(o)==null:
		if o.phase=="drive":o.phase="choice";truck.order_stop()
		o.site_lost=true
	if o.phase=="drive" and near(truck.position,o.station):
		if o.has("outpost"):
			var site=outpost(o)
			AlliedAbilities.change_side(site,"ally")
			arm_outpost(site)
		truck.queue_free();o.phase="station"
		finish(o,"维修站已开启，附近己方地面载具持续恢复")

static func arm_outpost(site) -> void:
	site.weapon=GameData.get_building("NASAM").weapon.duplicate(true)
	site.attack_range=float(site.weapon.range);site.cooldown=float(site.weapon.cooldown)

func release_convoy(o:Dictionary) -> void:
	for u in world.units:
		if not world.actor_alive(u) or u.special.get("field_convoy","")!=o.id:continue
		u.special.erase("field_convoy");u.special.erase("field_lead")
		u.hold_position=false;u.order_stop()
		if BattleRequest.is_house(u.side) and not BattleRequest.friendly("ally",u.side):
			u.fire_stance="free";u.order_move(world.player_start(),true)

func divert(o:Dictionary,data:Dictionary) -> void:
	var lead=null
	for u in world.units:
		if world.actor_alive(u) and u.special.get("field_convoy","")==o.id and u.special.get("field_lead",false):lead=u;break
	if lead==null or BattleRequest.friendly("ally",lead.side):
		release_convoy(o)
		if o.phase=="withdraw":finish(o,"车队调离途中失去通讯车")
		else:
			data.supplies=int(data.supplies)+45
			finish(o,"通讯车已被排除，胜利 +45 补给")
		return
	o.truck_at=lead.position
	if o.phase=="open" and visitor(o.relay)!=null:
		o.phase="withdraw"
		Events.emit_message("假撤退令已发出。车队正在调离，侧翼出现空当。",UiKit.COL_SIDE_MISSION)
	if o.phase!="withdraw":return
	if near(lead.position,o.rally):
		release_convoy(o);finish(o,"车队已在集结点重整并重新参战");return
	for u in world.units:
		if world.actor_alive(u) and u.special.get("field_convoy","")==o.id and (not u.has_move_order or u.move_target.distance_to(o.rally)>120):
			u.hold_position=false;u.fire_stance="none";u.order_move(o.rally,false)

func actions(o:Dictionary) -> Array:
	if not NAMES.has(o.kind) or o.done or o.get("failed",false):return []
	if o.kind=="box" and o.phase=="carry":return ["放下黑匣子"]
	if o.kind=="fuel" and o.phase=="choice":return ["拆车换维修包"] if o.get("site_lost",false) else ["派车进站","拆车换维修包"]
	return []

func act(o:Dictionary,data:Dictionary,action:String) -> void:
	if action not in actions(o):return
	if o.kind=="box":
		var carrier=tagged("field_box",o.id)
		if carrier!=null:
			drop_box(o,carrier);carrier.special.field_box_dropped=true
			Events.emit_message("黑匣子已放下。可由其他部队接手，原携带者离开标记后也可返回拾取。",UiKit.COL_SIDE_MISSION)
	elif o.kind=="fuel":
		var truck=tagged("field_tanker",o.id)
		if truck==null or truck.side!="ally":return
		if action=="派车进站":
			o.phase="drive";truck.hold_position=false;truck.order_move(o.station)
		else:
			truck.queue_free();data.kits=int(data.get("kits",0))+1
			finish(o,"已拆车；胜利后带回 1 个维修包")

func hint(o:Dictionary) -> String:
	if o.done or o.failed:return o.get("result","已结束")
	if Assign.BOOK.has(o.kind):return Assign.hint(o)
	match o.kind:
		"engineer":return "派地面部队接应桥梁工兵"
		"bridge":return "选中工程师，右键进入侧桥维修小屋"
		"radio":
			if o.listened:return "前往「%s」电台接应步兵"%CALLS[o.real]
			return "前往另一座电台" if o.ambushed else "监听识别码，或直接前往电台"
		"box":
			var holder=box_holder(o.id) if o.phase=="carry" else null
			return "%s 携带中 · 送回交付点"%holder.display_name if holder!=null else "让地面部队碰触闪框箱子"
		"fuel":return "前哨站已损失，可拆车带回维修包" if o.get("site_lost",false) else {"open":"派地面部队接应油罐车","choice":"车旁选择护送或拆车","drive":"护送油罐车抵达停靠点"}[o.phase]
		"divert":return "车队调离中，趁机推进" if o.phase=="withdraw" else "摧毁通讯车领补给，或接管中继台调走车队"
	return ""

func marker(o:Dictionary,suffix:String,point:Vector2,text:String) -> Dictionary:
	return {"key":o.id+suffix,"position":point,"title":text,"optional":true,"status":"done" if o.done else "locked" if o.failed else "active"}

func marks(o:Dictionary) -> Array:
	var result:Array=[]
	if Assign.BOOK.has(o.kind):
		if not o.done and not o.failed and (o.kind=="triage" or o.get("use_backup",false)):
			var elapsed:=float(o.get("service_time",0))
			var cap:=6 if o.kind=="triage" else 12
			var step:=str(Assign.BACKUP.get(o.kind,"伤员即治 · 满血体检"))
			var m:=marker(o,"",o.position,"%s · %s %d/%d秒"%[NAMES[o.kind],step,int(elapsed),cap]);m.meter=elapsed/cap
			return [m]
		if not o.done and not o.failed and o.kind=="handoff":return [marker(o,"",o.position,"双人交班 · "+Assign.hint(o))]
		if not o.done and not o.failed and o.kind=="relay_pair":
			for second:bool in [false,true]:
				var m:=marker(o,"_second" if second else "",o.station if second else o.position,("B 台 · " if second else "A 台 · ")+Assign.relay_hint(o,second))
				m.staffed=o.get("relay_b" if second else "relay_a",false);m.meter=float(o.progress)/5.0;result.append(m)
			return result
		if o.done or o.failed:return [marker(o,"",o.position,NAMES[o.kind]+" · "+hint(o))]
		var second:bool=(o.kind=="survey" and o.phase=="second") or (o.kind=="courier" and o.phase=="return") or (o.kind=="shuttle" and o.phase=="open" and int(o.get("on_site",0))>0)
		var active:=marker(o,"_second" if second else "",o.station if second else o.position,NAMES[o.kind]+" · "+Assign.hint(o))
		if o.kind=="quiet" or (o.kind=="survey" and second):active.meter=float(o.progress)/(8.0 if o.kind=="quiet" else 6.0)
		if o.kind=="muster":active.meter=float(o.get("on_site",0))/3.0
		return [active]
	if o.done or o.failed:
		var end:Vector2=o.position
		if o.kind=="box":end=o.depot
		if o.kind=="radio":end=o.stations[o.real]
		if o.kind=="fuel":end=o.get("outpost",o.station) if o.phase=="station" else o.get("truck_at",end)
		if o.kind=="divert":end=o.get("truck_at",end)
		return [marker(o,"",end,NAMES[o.kind]+" · "+hint(o))]
	match o.kind:
		"engineer","bridge":result.append(marker(o,"",o.position,"受困工兵 · 派地面部队接走" if o.kind=="engineer" else "侧桥小屋 · 工程师右键进入修桥"))
		"radio":
			if not o.listened:result.append(marker(o,"_listen",o.position,"监听车 · 查询识别码"))
			for i in 2:
				if i!=o.real and o.ambushed:continue
				var station_name:="呼救电台 · "+str(CALLS[i])
				if o.listened:station_name+=(" · 到此接应" if i==o.real else " · 假信号，绕开")
				else:station_name+=(" · 到此接应" if o.ambushed else " · 未核实")
				result.append(marker(o,str(i),o.stations[i],station_name))
		"box":
			if o.phase=="carry":result.append(marker(o,"_depot",o.depot,"交付点 · 让携带者到此"))
			var holder=box_holder(o.id) if o.phase=="carry" else null
			result.append(marker(o,"",holder.position if holder!=null else o.cargo,("%s · 携带黑匣子"%holder.display_name) if holder!=null else "黑匣子 · 拾取"))
		"fuel":
			result.append(marker(o,"",o.get("truck_at",o.position),"支线油罐车"))
			if not o.get("site_lost",false):result.append(marker(o,"_station",o.station,"前哨站停靠点 · 护送到此启用"))
		"divert":
			result.append(marker(o,"",o.get("truck_at",o.position),"通讯车 · 摧毁领补给" if o.phase=="open" else "车队调离中 · 趁机推进"))
			if o.phase=="open":result.append(marker(o,"_relay",o.relay,"中继台 · 发假撤退令"))
			else:result.append(marker(o,"_end",o.rally,"车队集结点"))
	return result
