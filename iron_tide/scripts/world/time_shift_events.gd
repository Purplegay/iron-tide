extends RefCounted

const BRIDGE := ["CASANF09","CASANF10","CASANF11","CASANF04","CASANF12","CASANF13","CASANF14"]
const LINES := {
 "csof016":"正在建立战场控制，请稍候。", "csof038":"增援部队已抵达。", "csof120":"战场控制已上线。", "csof124":"任务目标已完成。", "csof125":"警报：发现心灵控制器。",
 "xs1so21":"这是恶魔岛。回到过去后，我们要摧毁岛上的装置。现在先夺取盟军的时光机。", "xs1so14":"先消灭盟军舰队和岸防巨炮，运输艇才能靠岸。", "xs1so01":"干得好，指挥官。带领部队夺取这里的时光机。", "xs1so02":"有了时光机，我们就能回到过去，摧毁心灵控制器。", "xs1so03":"祝你好运，长官。", "xs1so04":"这个时代的恶魔岛防守太严了。先夺取时光机，再回到他们构筑防线之前发动攻击。", "xs1so05":"停火，长官！我们还需要这些发电厂启动时光机。", "xs1so06":"时光机没有电力。占领附近的发电厂，我们正在空投工程师支援。", "xs1so07":"电力足够了，开始时空转移。", "xs1so08":"尤里快要凑够电力了。阻止他，尽快赶到时光机。", "xs1so09":"太多发电厂被摧毁了，我们必须中止任务。", "xs1so11":"时光机充能完毕。准备好，指挥官，我们要出发了。", "xs1so12":"根据记录，这个时代附近有一座苏军基地。找到它，接过指挥权。", "xs1so13":"我们已接管这座基地。集结部队，摧毁心灵控制器。", "xs1so15":"时光机被摧毁了，我们的任务失败了。", "xs1so16":"不！我们竟然又失去了鲍里斯。今天是祖国黑暗的一天。", "xs1so17":"将军同志，鲍里斯阵亡了。我们不能让他的牺牲白费。", "xs1so18":"住手，将军同志！我们还得靠这台时光机完成任务。", "xs1so20":"消灭时光机周围的所有防御设施，我们就能接管它了。", "xs1so22":"鲍里斯同志，很高兴再见到你。", "xs1so23":"没有，当然没有。只是看到你平安无事，我很高兴。", "xs1so24":"回到过去之后，我们得找到鲍里斯，改变他的命运。", "xs1so25":"尤里的工程师也在抢占发电厂。电力一旦充足，他就会启动心灵控制器。",
 "xs1bo01":"鲍里斯报到。", "xs1bo02":"我离开过吗，索菲亚同志？", "xs1bo03":"我可不打算游过去。给我从船坞调一艘两栖运输艇来。", "csofu75":"盟军的重装大兵配备了反坦克武器。让军犬去对付他们。", "csofu82":"这位是鲍里斯，将军同志。他装备精良，有权呼叫空袭，是苏维埃人民的英雄。", "csofu92":"占领战地医院，可以让前线步兵得到救治。", "csofu93":"机械维修厂能够持续修理我们的车辆。"
}

static func dialogue(world,event:String) -> void:
	var file:String=world.TimeShift.ASSETS.data.voices.get(event,"")
	if file.is_empty():return
	var speaker:="鲍里斯" if file.begins_with("xs1bo") else "战场指挥系统" if file.begins_with("csof0") or file=="csof120" or file=="csof124" or file=="csof125" else "索菲亚"
	var text:String=LINES.get(file,"")
	if not text.is_empty():world.hud.show_field_transmission(speaker,text,"")
	Ra2Sfx.play_time_shift_line(file)

static func once(world,event:String) -> void:
	var s:Dictionary=world.allied_state.time_shift
	if not s.has(event):
		s[event]=true
		dialogue(world,event)

const FLEET = preload("res://data/maps/time_shift_fleet.json").data

static func fleet_notices(world,s:Dictionary) -> void:
	var notices:Dictionary=s.get("fleet_notices",{})
	for group in FLEET.groups.size():
		var key:=str(group) # Existing saves use stable group indices.
		if not notices.has(key) or float(s.elapsed)<float(notices[key]):continue
		notices.erase(key)
		var spec:Dictionary=FLEET.groups[group]
		for slot in spec.flash:
			Events.emit_radar_ping(world.TimeShift.wp(int(slot)),"campaign_discovery")
		if not str(spec.cue).is_empty():dialogue(world,spec.cue)

static func fleet_disarm(s:Dictionary) -> void:
	# The original disables loss/replacement triggers, not notices already armed.
	s.erase("fleet_due")
	s.erase("fleet_rearm")
	var notices:Dictionary=s.get("fleet_notices",{})
	for key in notices: notices[key]=float(notices[key])-float(s.elapsed)
	s.fleet_disarmed=true

static func fleet_reinforcements(world,s:Dictionary) -> void:
	var active:Dictionary={}
	var untagged:Array=[]
	for u in world.units:
		if not world.actor_alive(u) or u.side!="ally": continue
		if u.special.has("time_shift_fleet_slot"): active[int(u.special.time_shift_fleet_slot)]=u
		elif u.unit_id in ["DRED","SUB","SQD","HYD"]: untagged.append(u)
	# Old saves do not identify ships. Match survivors to the nearest named station once.
	if not s.get("fleet_slots_initialized",false):
		for u in untagged:
			var slot:=-1
			var distance:=INF
			for row in FLEET.fleet:
				if row.type!=u.unit_id or active.has(int(row.slot)): continue
				var d:float=u.position.distance_squared_to(world.TimeShift.wp(int(row.slot)))
				if d<distance: slot=int(row.slot);distance=d
			if slot>=0: u.special.time_shift_fleet_slot=slot;active[slot]=u
		s.fleet_slots_initialized=true
	var due:Dictionary=s.get_or_add("fleet_due",{})
	var notices:Dictionary=s.get_or_add("fleet_notices",{})
	var rearm:Dictionary=s.get_or_add("fleet_rearm",{})
	var now:float=s.elapsed
	for group in FLEET.groups.size():
		var key:=str(group)
		var spec:Dictionary=FLEET.groups[group]
		if now<float(rearm.get(key,0.0)) or spec.ships.any(func(ship): return active.has(int(ship.slot))): continue
		if not due.has(key): due[key]=now+float(spec.delay)
		if now<float(due[key]): continue
		var ships:Array=[]
		for row in spec.ships:
			var goal:Vector2=world.TimeShift.wp(int(row.slot))
			var ingress:Vector2=world.TimeShift.wp(int(row.ingress))
			var start:Vector2=world.path_service.nearest_reachable(goal.move_toward(ingress,150),goal,true,8)
			if not start.is_finite(): break
			ships.append([row,goal,start])
		if ships.size()!=spec.ships.size(): continue
		for ship in ships:
			var unit=world.spawn_unit(ship[0].type,"ally",ship[2])
			unit.special.time_shift_fleet_slot=int(ship[0].slot)
			unit.order_move(ship[1],false,null,world.path_for_unit(unit,ship[1]))
		due.erase(key)
		rearm[key]=now+float(spec.rearm)
		if not notices.has(key):notices[key]=now+float(spec.notice_delay)

static func queue_media(s:Dictionary,id:String,delay_override:float=-1.0) -> void:
	var tasks:Dictionary=s.get_or_add("retail_media_due",{})
	if tasks.has(id):return
	var row:Dictionary=FLEET.media[id]
	tasks[id]={"due":float(s.elapsed)+(float(row.delay) if delay_override<0 else delay_override),"phase":int(s.phase)}

static func media_tick(world,s:Dictionary) -> void:
	var tasks:Dictionary=s.get("retail_media_due",{})
	for id in tasks.keys():
		var task:Dictionary=tasks[id]
		if int(task.phase)!=int(s.phase):
			tasks.erase(id)
			if id in ["05BF366C","05BF4E3C"]:s.erase("retail_shop_armed")
			continue
		if float(s.elapsed)<float(task.due):continue
		tasks.erase(id)
		var row:Dictionary=FLEET.media[id]
		if not str(row.cue).is_empty():once(world,row.cue)
		if row.camera!=null:world.center_on(world.TimeShift.wp(int(row.camera)))
		if row.slot!=null:Events.emit_radar_ping(world.TimeShift.wp(int(row.slot)),"campaign_discovery")
		if row.text=="MISSION:Sov1Obj2":Events.emit_message("任务目标：夺取盟军的时光机。")
		elif row.text=="MISSION:Sov1Obj2a":Events.emit_message("任务目标：摧毁时光机周围的防御设施。")
		for next in row.enable:
			if FLEET.media.has(next):queue_media(s,next)
			elif FLEET.encounter.has(next):world.TimeShift.Staging.queue(s,next)
		if id in ["05BF366C","05BF4E3C"]:
			for b in world.buildings:
				if world.actor_alive(b) and b.building_id=="CAMACH":b.special.campaign_flash_left=float(row.frames)/BattleClock.RULE_TICKS_PER_SECOND

const Late = preload("res://scripts/world/time_shift_late.gd")

static func props(world,s:Dictionary) -> void:
	Late.tick(world,s)
	media_tick(world,s)
	ambience(world,s)
	for b in world.buildings:
		if not world.actor_alive(b):continue
		if b.building_id in ["CAMACH","CATHOSP"] and world.actor_visible_to("ally",b):facility_notice(world,s,b)
		if s.phase==4 and b.building_id=="YAPPPT" and world.actor_visible_to("ally",b):once(world,"Mis_xS1_BorisWantsBoat")
		if s.phase in [1,2] and world.actor_visible_to("ally",b):
			if b.building_id=="YAPPET":world.TimeShift.Cleanup.apply(world,s,"0439013C")
			if b.special.get("time_shift_tag")=="Destroy_Time Defenses" and not s.has("Mis_xS1_ZofiaTimeDefenses"):
				once(world,"Mis_xS1_ZofiaTimeDefenses")
				if s.phase==1:
					queue_media(s,"043E7EDC")
					world.TimeShift.Staging.run(world,s,"094A51CC")
	if s.phase in [1,2,3,4]:
		var boris=world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="BORIS" and u.side=="ally")
		if boris.is_empty() and s.get("boris_seen",false):Late.apply(world,s,"095714FC" if s.phase==4 else "06B627BC")
		elif not boris.is_empty():s.boris_seen=true
		for unit in world.units:
			if not world.actor_alive(unit):continue
			if unit.special.has("shift_debut") and unit.embarked_in==null:
				unit.special.erase("shift_debut")
				queue_media(s,"0D17FAAC")
				media_tick(world,s) # Boarding/debark fact has already arrived.
			if unit.special.get("shift_rexy",false) and unit.side=="neutral" and world.actor_visible_to("ally",unit):
				if not s.has("rexy_help"):
					s.rexy_help=true
					Late.apply(world,s,"097DFABC")
					Events.emit_message("霸王龙被困住了。摧毁围栏，给它打开出路。")
				var fences=world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id=="CAFNCP" and b.position.distance_to(unit.position)<170)
				if fences.size()<3:
					AlliedAbilities.change_side(unit,"ally")
					Late.apply(world,s,"0954F76C")
	if s.has("boris_intro_due") and float(s.elapsed)>=float(s.boris_intro_due):
		s.erase("boris_intro_due")
		once(world,"Unit_Sofia_Boris")
	if s.phase==4 and not s.get("base_found",false):
		for u in world.units:
			if not world.actor_alive(u) or u.side!="ally" or u.embarked_in!=null:continue
			var cell:=Vector2i((u.position/55).floor())
			if world.TimeShift.FIELD.data.base_contact.any(func(v):return Vector2i(v[0],v[1])==cell):
				s.base_found=true
				for b in world.buildings:
					if world.actor_alive(b) and b.special.get("shift_base",false):AlliedAbilities.change_side(b,"ally")
				var ref=world.buildings.filter(func(b):return world.actor_alive(b) and b.building_id=="NAREFN" and b.side=="ally")
				if not ref.is_empty():world.spawn_unit("HARV","ally",world.TimeShift.wp(140),ref[0])
				world.TimeShift.announce_radar_objectives(world)
				world.TimeShift.Staging.run(world,s,"0962D87C")
				if FLEET.boatLoss.enable:s.s01_boat_loss_armed=true
				world.TimeShift.Cleanup.queue(s,"07EF508C")
				world.TimeShift.Cleanup.queue(s,"0439C2DC")
				Late.start_island_objective(s,int(BattleRequest.skirmish_config.get("difficulty",1)))
				break

# 07837A2C and 05BF366C/05BF4E3C: announcements include a position and a flash.
static func facility_notice(world,s:Dictionary,b) -> void:
	var hospital:bool=b.building_id=="CATHOSP"
	var row:Dictionary=FLEET.media["07837A2C"]
	if not hospital:
		if s.has("retail_shop_armed") or s.has("Unit_Sofia_TechMachShop"):return
		s.retail_shop_armed=true
		var detector:Dictionary=FLEET.media["05BF375C" if b.side=="ally" else "05BF392C"]
		for next in detector.enable:queue_media(s,next)
		return
	var cue:String=row.cue
	if s.has(cue):return
	once(world,cue)
	var point:Vector2=world.TimeShift.wp(int(row.camera))
	if hospital:
		var general:Dictionary=preload("res://scripts/core/yr_death_rules.gd").data().general
		world.fog._reveal("ally",point,float(general.revealtriggerradius)*55.0)
	b.special.campaign_flash_left=float(row.frames)/BattleClock.RULE_TICKS_PER_SECOND
	Events.emit_radar_ping(point,"campaign_discovery")

static func return_city(world) -> void:
	Late.return_city(world)

static func ambience(world,s:Dictionary) -> void:
	if s.elapsed<float(s.get("ambient_due",0)):return
	s.ambient_due=s.elapsed+8.0
	var camera:Vector2=world.camera.position
	var nearest:Array=[]
	var distance:=1000.0
	for trigger in FLEET.ambience.values():
		if bool(trigger.jurassic)!=(s.phase==3):continue
		for row in trigger.points:
			var d:float=world.TimeShift.wp(int(row[1])).distance_to(camera)
			if d<distance:distance=d;nearest=row
	if not nearest.is_empty():Ra2Sfx.play(nearest[0],world.TimeShift.wp(nearest[1]))

# 0962D87C enables 0442182C, and 04421A8C rearms it after the primary team is lost.
static func mixed_attack(world,s:Dictionary,delta:float) -> void:
	if not s.get("base_found",false) or not world.actor_alive(s.get("dominator")):return
	var raid:Dictionary=s.get_or_add("island_mixed_attack",{})
	if raid.is_empty():
		raid.primary_left=float(randi_range(10,30))
		raid.follow_queue=[]
	var follow:Array=raid.get_or_add("follow_queue",[])
	for i in range(follow.size()-1,-1,-1):
		follow[i]=maxf(0.0,float(follow[i])-delta)
		if follow[i]==0.0 and spawn_mixed_team(world,false).size()==5:follow.remove_at(i)
	if raid.has("primary"):
		if raid.primary.any(func(u):return world.actor_alive(u) and u.side=="enemy"):return
		raid.erase("primary")
		raid.primary_left=float(randi_range(10,30))
		return
	raid.primary_left=maxf(0.0,float(raid.primary_left)-delta)
	if raid.primary_left>0:return
	var members:=spawn_mixed_team(world,true)
	if members.size()!=5:return
	raid.primary=members
	follow.append(float(randi_range(20,60)))

static func spawn_mixed_team(world,primary:bool) -> Array:
	var origin:Vector2=world.TimeShift.wp(138)
	var goal:Vector2=world._player_target()
	var members:=[]
	for id in ["LTNK","LTNK","INIT","INIT","INIT"]:
		var seed:=origin+Vector2(40*(members.size()%3),40*(members.size()/3))
		var point:Vector2=world.path_service.nearest_reachable(seed,origin,false,8)
		var u=world.spawn_unit(id,"enemy",point)
		if u==null:
			for other in members:AlliedAbilities.consume(other)
			return []
		members.append(u)
		u.special.shift_mixed_primary=primary
		var via:Vector2=world.TimeShift.wp(459) if primary else goal
		u.special.shift_mixed_stage=0 if primary else 1
		u.order_move(via,true,null,world.path_for_unit(u,via))
	return members

# 05D695EC: waypoint 459 -> defenses -> any. 09350DBC: type 9
# (NAPOWR; packed selector 131081) -> infantry -> any.
const GLOBAL_BUILDING_TYPES := {0:"GAPOWR",1:"GAREFN",2:"GACNST",3:"GAPILE",9:"NAPOWR",11:"NAHAND",15:"NAREFN",23:"GAYARD",25:"NACNST",56:"CAMACH",61:"NAYARD",64:"GTGCAN",69:"CATHOSP",70:"CAAIRP",71:"CAOILD"}

static func mixed_target(world,u,category:int,building_index:=-1):
	var best=null
	var distance:=INF
	for target in world.units+world.buildings:
		if not world.actor_alive(target) or target.side!="ally" or not u.attack_domain_valid(target):continue
		if building_index>=0 and not (target is Building and target.building_id==GLOBAL_BUILDING_TYPES.get(building_index,"")):continue
		if category==9 and not (target is Building and target.power>0):continue
		if category==5 and not (target is Unit and target.is_harvester):continue
		if category==6 and not (target is Unit and not AlliedAbilities.infantry(target)):continue
		if category==2 and not (target is Building):continue
		if category==7 and not (target is Building and (target.data.get("tags",[]).has("defense") or not target.data.get("weapon",{}).is_empty())):continue
		if category==4 and not (target is Unit and AlliedAbilities.infantry(target)):continue
		var d:float=u.position.distance_squared_to(target.position)
		if d<distance:best=target;distance=d
	return best

static func mixed_orders(world) -> void:
	for u in world.units:
		if not world.actor_alive(u) or not u.special.has("shift_mixed_stage"):continue
		if u.side!="enemy":u.special.erase("shift_mixed_stage");continue
		var stage:int=u.special.shift_mixed_stage
		if stage==0:
			var via:Vector2=world.TimeShift.wp(459)
			if u.position.distance_to(via)>75.0:
				if not u.has_move_order:u.order_move(via,true,null,world.path_for_unit(u,via))
				continue
			stage=1
		if u.attack_ordered and world.actor_alive(u.attack_target) and u.attack_target.side=="ally":continue
		var primary:bool=u.special.shift_mixed_primary
		var categories:Array=[7,1] if primary else [-1,4,1]
		while stage<=categories.size():
			var target=mixed_target(world,u,categories[stage-1],9 if not primary and stage==1 else -1)
			if target!=null:
				u.order_target(target,false,false)
				break
			stage+=1
		u.special.shift_mixed_stage=mini(stage,categories.size())

# 095A818C/095AB25C/095B6DBC: reach first waypoint, then loop between the pair.
# 05C9AA4C: the INIT team walks 145 -> 143 and stays on area guard.
static func start_island_route(world,u,waypoints:Array,loop:bool) -> void:
	var route:=PackedVector2Array()
	for waypoint in waypoints:
		var p:Vector2=world.TimeShift.wp(int(waypoint))
		route.append(world.path_service.nearest_reachable(p,u.position,false,8))
	if route.is_empty():return
	u.special.shift_island_route=route
	u.special.shift_island_index=0
	u.special.shift_island_loop=loop
	u.order_move(route[0],true,null,world.path_for_unit(u,route[0]))

static func island_patrols(world) -> void:
	for u in world.units:
		if not world.actor_alive(u) or not u.special.has("shift_island_route"):continue
		if u.side!="enemy":
			u.special.erase("shift_island_route")
			continue
		var route:PackedVector2Array=u.special.shift_island_route
		var index:int=u.special.shift_island_index
		if u.position.distance_to(route[index])<55.0:
			index+=1
			if index==route.size():
				if u.special.shift_island_loop:index=0
				else:
					u.special.erase("shift_island_route")
					u.order_guard()
					continue
			u.special.shift_island_index=index
		if not u.has_move_order or u.move_target.distance_to(route[index])>1.0:
			u.order_move(route[index],true,null,world.path_for_unit(u,route[index]))

# 0442B86C / 0442F31C: the final-era engineer enters the reactor at waypoint 101.
static func reactor_repair(world) -> void:
	var reactor=null
	for b in world.buildings:
		if world.actor_alive(b) and b.side=="enemy" and b.special.get("shift_reactor_repair_target",false) and b.hp<b.max_hp:
			reactor=b
			break
	if reactor==null:return
	for u in world.units:
		if not world.actor_alive(u) or u.side!="enemy" or not u.special.get("shift_reactor_fixer",false):continue
		if not u.special.has("action"):u.order_interaction("allied_engineer",reactor,false)
		return

static func bridge(world,s:Dictionary) -> void:
	var parts:Dictionary={}
	for b in world.buildings:
		if world.actor_alive(b) and b.building_id in BRIDGE:parts[b.building_id]=b
	Late.bridge(world,s,parts)

static func raid(world,row:Dictionary) -> void:
	var w=world.TimeShift
	var start:Vector2=w.wp(row.start)
	var shore:Vector2=w.wp(row.route.back())
	var entry: Vector2 = world.path_service.nearest_reachable(start,shore,false,24,true)
	# The retail entry waypoint lies outside the playable era. Projection must
	# reserve separate hull-sized slots or all three transports overlap there.
	var spawn: Vector2 = Vector2.INF
	for ring in 7:
		for slot in 16:
			var candidate: Vector2 = entry + Vector2.RIGHT.rotated(TAU * slot / 16.0) * ring * 100.0
			if world.path_service.is_blocked(candidate,false,true) or not world.in_water_world(candidate):continue
			if world.units.any(func(u):return world.actor_alive(u) and u.unit_id=="YHVR" and u.position.distance_squared_to(candidate)<90.0*90.0):continue
			spawn=candidate
			break
		if spawn.is_finite():break
	if not spawn.is_finite():return
	var boat=world.spawn_unit("YHVR","enemy",spawn)
	if boat==null:return
	boat.order_stop()
	boat.special.time_shift_native_house="Arabs"
	boat.special.shift_raid=shore
	var plant=null
	var distance:=INF
	for b in world.buildings:
		if not world.actor_alive(b) or b.building_id.length()!=7 or not b.building_id.begins_with("GAPOWR"):continue
		var d:float=b.position.distance_squared_to(w.wp(row.target))
		if d<distance:distance=d;plant=b
	for id in row.cargo:
		for i in int(row.cargo[id]):
			var unit=world.spawn_unit(id,"enemy",boat.position)
			if unit==null:continue
			unit.order_stop();unit.set_stowed(boat);boat.logistics.passengers.append(unit)
			unit.special.time_shift_native_house="Arabs"
			unit.special.shift_plant=plant
	var goal:Vector2=world.path_service.nearest_reachable(shore,boat.position,false,12,true)
	boat.special.shift_raid=goal
	var lane:Dictionary=FLEET.transportReturns.get("%s|%s"%[row.group,int(row.route.back())],{})
	if not lane.is_empty():boat.special.shift_return_lane=lane
	# The third retail route approaches from waypoint 459; a direct shortcut
	# through the city road intersects parked civilian vehicles.
	if int(row.route.back())==130:
		var via: Vector2 = world.path_service.nearest_reachable(w.wp(459),boat.position,false,12,true)
		boat.special.shift_raid_via=via
		boat.order_move(via,false,null,world.path_for_unit(boat,via))
	else:
		boat.order_move(goal,false,null,world.path_for_unit(boat,goal))

static func grid_attack_warning(world,b) -> void:
	var s:Dictionary=world.allied_state.time_shift
	if int(s.phase)!=2 or s.has("grid_full_at"):return
	var rules:Dictionary=FLEET.grid.attackWarnings
	var row:Dictionary={}
	if b==s.get("machine"):row=rules.machine
	elif FLEET.grid.plants.has(b.building_id):row=rules.plant
	if row.is_empty():return
	var key:="grid_attacked_"+str(row.id)
	if s.has(key):return
	s[key]=true
	dialogue(world,row.cue)
	if row.text=="MISSION:WarnStct":
		Events.emit_message("停止攻击时光机。" if b==s.get("machine") else "停止攻击发电厂；时光机需要这些电力。")

# Persist the small retail loss latch independently of the physical building objects.
static func power_losses(s:Dictionary,live:Dictionary) -> bool:
	var grid:Dictionary=FLEET.grid
	var state:Dictionary=s.get_or_add("grid_loss",{"seen":{},"enabled":{},"flags":{}})
	for plant in grid.plants:
		if live.has(plant) or state.seen.has(plant):continue
		state.seen[plant]=true
		for id in grid.plants[plant].enable:state.enabled[id]=true
		# Each destroyed plant advances a single tier; the two branches of that
		# tier may run together, but a newly enabled tier waits for another plant.
		var chosen:Dictionary={}
		for rule in grid.loss:
			if int(rule.op)!=37 or not state.enabled.has(rule.id):continue
			var key:=str(int(rule.flag))
			if not state.flags.get(key,false) and (chosen.is_empty() or int(rule.flag)<int(chosen.flag)):chosen=rule
		if chosen.is_empty():continue
		state.flags[str(int(chosen.flag))]=true
		for rule in grid.loss:
			if int(rule.flag)!=int(chosen.flag) or int(rule.op)!=36:continue
			for id in rule.disable:state.enabled.erase(id)
			for id in chosen.disable:state.enabled.erase(id)
			for id in chosen.enable:state.enabled[id]=true
			for id in rule.enable:state.enabled[id]=true
			state.enabled.erase(rule.id)
	return state.enabled.has("06B6156C")

static func boat_loss(world,s:Dictionary) -> bool:
	if not s.get("s01_boat_loss_armed",s.get("base_found",false)) or int(s.phase)!=4:return false
	var row:Dictionary=FLEET.boatLoss
	var transport:String=row.transport
	if world.units.any(func(u):return world.actor_alive(u) and u.unit_id==transport):return false
	var recovery:Array=row.recovery
	if world.buildings.any(func(b):return world.actor_alive(b) and b.side=="ally" and recovery.has(b.building_id)):return false
	s.s01_boat_loss_armed=false
	Events.emit_message("运输艇已损失，且没有建造厂或船坞可以补充运输艇。")
	s.loss_left=float(row.delay)
	return true

# The current contest models Arab power through four captured mission plants.
static func dominator_power_alarm(world,s:Dictionary,mission_plants:int) -> void:
	var row:Dictionary=FLEET.powerAlarm
	if mission_plants<4 or s.get("s01_power_alarm_played",false) or s.get("s01_closed_triggers",{}).has(row.id):return
	s.s01_power_alarm_played=true
	Ra2Sfx.play(row.sound)
	if row.text=="MISSION:DomArmed":Events.emit_message("警报：尤里的心灵控制器已启动。")
	dialogue(world,row.cue)

static func tech_power_warning(world,s:Dictionary,owned:Dictionary) -> void:
	var grid:Dictionary=FLEET.grid
	var elapsed:=float(s.power_elapsed)
	if s.has("grid_warning_due"):
		if elapsed>=float(s.grid_warning_due):
			s.erase("grid_warning_due")
			if not s.get(grid.warning.cue,false):
				s[grid.warning.cue]=true
				dialogue(world,grid.warning.cue)
		return
	# The current battle groups Arab and Yuri ownership; retain the established three-plant gate.
	var plant_count:int=owned.size()-int(owned.has("GAPOWR"))
	if plant_count<3 or s.get(grid.warning.cue,false):return
	var disabled:Dictionary=s.get_or_add("grid_tech_disabled",{})
	var legacy:Dictionary=world.TimeShift.Cleanup.RULES["0951972C"]
	if owned.has("GAPOWR") and not disabled.has(legacy.id) and legacy.enable.has(grid.warning.id):
		s.grid_warning_due=elapsed+float(grid.warning.delay)
		for id in grid.techDisable.disable:disabled[id]=true
		return
	for plant in owned:
		if not grid.tech.has(plant):continue
		var row:Dictionary=grid.tech[plant]
		if disabled.has(row.id) or not row.enable.has(grid.warning.id):continue
		s.grid_warning_due=elapsed+float(grid.warning.delay)
		if row.enable.has(grid.techDisable.id):
			for id in grid.techDisable.disable:disabled[id]=true
		break

static func engineer_reinforcements(world, s: Dictionary, drop_point: Vector2) -> void:
	var elapsed := float(s.power_elapsed)
	var drop = preload("res://scripts/world/american_paradrop.gd")
	var rules:Dictionary=FLEET.engineer
	engineer_notices(world,s,elapsed)
	# A phase-2 save from before this flag was added already ordered the first wave.
	if not s.get("engineer_initial_sent", true):
		# Retail: Sell_Time Defenses (3 s) enables Reinforce_10 Engineers (25 s).
		if elapsed >= engineer_order_time(world,rules) and drop.launch_story(world, drop_point, "SENGINEER", int(rules.initial.count)):
			s.engineer_initial_sent = true
			s.engineer_arrival_due=elapsed+float(rules.arrival.delay)
		return
	for u in world.units:
		if not world.actor_alive(u) or u.side != "ally": continue
		# Unit records also preserve the payload and parachute state in saves.
		if u.unit_id == "SENGINEER" or (u.special.get("para_infantry") == "SENGINEER" and int(u.special.get("para_left", 0)) > 0):
			s.erase("engineer_rescue_due")
			return
	# Detect_Engineers Dead enables the six-engineer wave after 3 seconds.
	if not s.has("engineer_rescue_due"):
		s.engineer_rescue_due = elapsed + float(rules.rescue.delay)
	elif elapsed >= float(s.engineer_rescue_due) and drop.launch_story(world, drop_point, "SENGINEER", int(rules.rescue.count)):
		s.erase("engineer_rescue_due")
		s.engineer_rescue_arrival_due=elapsed+float(rules.rescueArrival.delay)

static func engineer_order_time(world,rules:Dictionary) -> float:
	var sale:Dictionary=world.TimeShift.Cleanup.RULES["096012AC"]
	return float(sale.delay)+float(rules.initial.delay) if sale.enable.has(rules.initial.id) else INF

static func engineer_notices(world,s:Dictionary,elapsed:float) -> void:
	var rules:Dictionary=FLEET.engineer
	if elapsed>=float(FLEET.power[0].delay)+float(rules.powerHint.delay) and not s.get("engineer_power_hint",false):
		s.engineer_power_hint=true
		engineer_notice(world,rules.powerHint)
	for key in ["engineer_arrival_due","engineer_rescue_arrival_due","engineer_hint_due"]:
		if not s.has(key) or elapsed<float(s[key]):continue
		s.erase(key)
		if key=="engineer_arrival_due":
			engineer_notice(world,rules.arrival)
			s.engineer_hint_due=elapsed+float(rules.hint.delay)
		elif key=="engineer_rescue_arrival_due":engineer_notice(world,rules.rescueArrival)
		else:engineer_notice(world,rules.hint)

static func engineer_notice(world,rule:Dictionary) -> void:
	var text:String={"MISSION:MoreEngn":"工程师增援已抵达。","MISSION:HintPowr":"让工程师占领发电厂，为时光机供电。","MISSION:Sov1Obj3":"任务目标：占领发电厂，为时光机供电。"}.get(rule.text,"")
	if not text.is_empty():Events.emit_message(text)
	if not str(rule.cue).is_empty():dialogue(world,rule.cue)
	for slot in rule.flash:Events.emit_radar_ping(world.TimeShift.wp(int(slot)),"campaign_discovery")

static func advance_raid_return(world,u,elapsed:float) -> void:
	var lane:Dictionary=u.special.shift_return_lane
	if u.special.has("shift_return_unloading"):
		if not u.logistics.passengers.is_empty():return
		u.special.erase("shift_return_unloading")
		if lane.id=="06A67A6C":
			u.special.shift_grand_waiting=true
			return
		if lane.flag==36:world.allied_state.time_shift.s01_gas_capture_unloaded=true
		u.special.shift_return_reset=elapsed+float(lane.delay)
		u.special.shift_return_step=0
		order_return_leg(world,u,int(lane.route[0]))
		return
	if u.special.get("shift_grand_waiting",false):
		var state:Dictionary=world.allied_state.time_shift
		if state.get("s01_closed_triggers",{}).has(lane.id) or not state.get("s01_gas_capture_unloaded",false):return
		u.special.erase("shift_grand_waiting")
		u.special.shift_return_reset=elapsed+float(lane.delay)
		u.special.shift_return_step=0
		state.s01_grand_unloaded=true
		order_return_leg(world,u,int(lane.route[0]))
		return
	if u.special.has("shift_return_reset") and elapsed>=float(u.special.shift_return_reset):
		u.special.erase("shift_return_reset")
		if lane.reset=="0C122E5C":world.allied_state.time_shift.erase("s01_grand_unloaded")
		elif lane.clear_flag==36:world.allied_state.time_shift.erase("s01_gas_capture_unloaded")
	if not u.special.has("shift_return_step") or u.has_move_order:return
	var current:=int(u.special.shift_return_step)
	var goal:Vector2=u.special.get("shift_return_goal",Vector2.INF)
	if not goal.is_finite() or u.position.distance_to(goal)>80.0:
		order_return_leg(world,u,int(lane.route[current]));return
	if current+1>=lane.route.size():
		if not u.special.has("shift_return_reset"):AlliedAbilities.consume(u)
		return
	u.special.shift_return_step=current+1
	order_return_leg(world,u,int(lane.route[current+1]))

static func order_return_leg(world,u,waypoint:int) -> void:
	var goal:Vector2=world.path_service.nearest_reachable(world.TimeShift.wp(waypoint),u.position,false,24,true)
	if not goal.is_finite():return
	u.special.shift_return_goal=goal
	u.order_move(goal,false,null,world.path_for_unit(u,goal))

static func power_contest(world,s:Dictionary) -> void:
	var index:=int(s.get("raid_index",0))
	var elapsed:=float(s.get("power_elapsed",0.0))
	var level:=clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)
	if index>=4 and int(s.get("raid_repeat_base",0))==0:
		var loop:Dictionary=world.TimeShift.Staging.ROWS["06A6663C"]
		if loop.enable.has("043DF33C") and not s.has("raid_repeat_due"):s.raid_repeat_due=elapsed+float(loop.delay)
		if elapsed>=float(s.get("raid_repeat_due",INF)):
			s.raid_repeat_base=int(elapsed)-65
			s.raid_index=0
			index=0
	var deadline:=float(s.get("raid_repeat_base",0))
	for step in FLEET.power:
		if int(step.difficulty[level])==0:break
		deadline+=float(step.delay)
		if elapsed<deadline:break
		if not str(step.cue).is_empty():once(world,step.cue)
		if str(step.group).is_empty():continue
		if index!=FLEET.power.find(step)-2:continue
		for row in world.TimeShift.FIELD.data.raids:
			if row.group==step.group:raid(world,row)
		s.raid_index=index+1
		if step.ping!=null:
			s.get_or_add("power_raid_pings",[]).append({"due":elapsed+float(step.ping.delay),"slot":step.ping.slot})
		break
	var pings:Array=s.get("power_raid_pings",[])
	while not pings.is_empty() and elapsed>=float(pings[0].due):
		Events.emit_radar_ping(world.TimeShift.wp(int(pings[0].slot)),"campaign_discovery")
		pings.pop_front()
	for u in world.units:
		if not world.actor_alive(u):continue
		if u.special.has("shift_raid_via") and u.position.distance_to(u.special.shift_raid_via)<80:
			u.special.erase("shift_raid_via")
			var shore: Vector2 = u.special.shift_raid
			u.order_move(shore,false,null,world.path_for_unit(u,shore))
		if u.special.has("shift_raid") and not u.special.has("shift_raid_via") and u.position.distance_to(u.special.shift_raid)<80:
			u.special.erase("shift_raid")
			if u.logistics.request_unload() and u.special.has("shift_return_lane"):u.special.shift_return_unloading=true
		if u.special.has("shift_return_lane"):advance_raid_return(world,u,elapsed)
		if u.embarked_in!=null or not u.special.has("shift_plant"):continue
		var b=u.special.shift_plant
		if not world.actor_alive(b):u.special.erase("shift_plant");continue
		if u.unit_id=="INIT" and not u.special.get("shift_assault_sent",false):
			u.special.shift_assault_sent=true
			if b.side=="ally":u.order_target(b,false,false)
			else:
				var point:Vector2=world.path_service.nearest_reachable(b.position,u.position,false,8)
				u.order_move(point,true,null,world.path_for_unit(u,point))
		if u.unit_id=="YENGINEER" and not u.special.has("action"):
			if b.side=="enemy":
				# The mission tracks two owners on the same combat side.
				if b.special.get("yuri_power", false): continue
				var door:=AlliedAbilities.approach(u,b)
				if u.position.distance_to(door)<u.radius+28:
					b.special.yuri_power=true;b.refresh_house_color();AlliedAbilities.consume(u)
				elif not u.has_move_order:u.order_move(door,false,null,world.path_for_unit(u,door))
			else:
				u.order_interaction("allied_engineer", b, false)
		elif u.unit_id=="INIT" and not u.has_move_order:
			if u.position.distance_to(b.position)>260:
				var destination:=AlliedAbilities.approach(u,b)
				u.order_move(destination,true,null,world.path_for_unit(u,destination))
			else:u.order_guard()
