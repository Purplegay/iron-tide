extends RefCounted
const Native = preload("res://scripts/world/native_maps.gd")
const BRIEFING_SIGHT := 7.0 * Native.CELL
const Film = preload("res://scripts/ui/hollywood_film.gd")
const CASH_CRATE := preload("res://assets/maps/yr/field_crate.png")
const ID := "yr_hollywood"
const TIMERS = preload("res://data/maps/campaign_timer_drivers.json").data.all02
const RETAIL_DRIVERS = preload("res://data/maps/hollywood_drivers.json").data
const RetailSequences = preload("res://scripts/world/hollywood_retail_sequences.gd")
const ResidentQueue = preload("res://scripts/world/hollywood_queue.gd")
const FACTORIES := [Vector2i(104,127),Vector2i(128,78),Vector2i(193,102),Vector2i(151,69)]
# ALL02UMD action 108 (Money), in FACTORIES order: CO, CN, CL, CM.
const CASH_WAYPOINTS := [Vector2i(105,128),Vector2i(129,79),Vector2i(194,103),Vector2i(153,71)]
const CASH_REWARD := 5000 # Retail rulesmd.ini [CrateRules]; no ALL02UMD override.
const VISITS := [["克林特",157,123,"xa2ev05","CLNT"],["阿诺",107,131,"xa2ar01","ARND"],["史泰龙",156,74,"xa2sl01","STLN"]]
# ALL02UMD Find_Hospital / Find_MachineShop: discover the tagged building,
# reveal waypoint 201 / 202 and announce once (locals 13 / 12).
const FACILITY_DISCOVERIES := [["CATHOSP","医院",67,130,"cevau92"],["CAMACH","机械维修厂",172,92,"cevau93"]]

static func cell(x:int,y:int) -> Vector2:
	return (Vector2(206-y,x-12)+Vector2.ONE*0.5)*Native.CELL

# Structures stores a foundation corner, not a player placement candidate.
const MAP_DATA = preload("res://data/maps/yr_all02umd.json")

static func retail_site_center(id:String,tile:Vector2i) -> Vector2:
	var source:Dictionary=MAP_DATA.data.site_types.get(id,{})
	var dimensions:=str(source.get("foundation","1x1")).to_lower().split("x")
	var center:=cell(tile.x,tile.y)
	if dimensions.size()==2:
		center+=Vector2(1-int(dimensions[1]),int(dimensions[0])-1)*Native.CELL*0.5
	return center

static func grinder_center(tile:Vector2i) -> Vector2:
	return retail_site_center("YAGRND",tile)

static func configure_facility(site) -> void:
	if site.building_id == "CAMACH":
		site.display_name = "机械维修厂"
		site.data.name = site.display_name
		site.data.unsellable = true
		return
	if site.building_id not in ["CALA05", "CATHOSP"] or site.battle.mission.get("id") != ID: return
	var airport:bool = site.building_id == "CALA05"
	site.display_name = "洛杉矶国际机场" if airport else "科技医院"
	site.data.name = site.display_name
	site.data.capturable = true
	site.data.unsellable = true
	if airport:
		site.data.base_normal = true
		site.data.erase("garrison_slots")
		site.data.erase("garrison_weapons")
		site.superweapon = {"type":"ParaDrop", "ui_name":"机场伞兵援助", "recharge_seconds":240, "count":6, "infantry":"E1"}

static func hospital_heal(site, delta:float) -> void:
	if site.side == "neutral" or not site.is_operational() or site.battle.paused or site.battle.ended or site.get_tree().paused: return
	var rules:Dictionary = preload("res://scripts/core/yr_death_rules.gd").data().general
	var period := float(rules.selfhealinfantryframes) / BattleClock.RULE_TICKS_PER_SECOND
	var elapsed := float(site.special.get("hospital_elapsed", 0.0)) + delta
	var pulses := floori(elapsed / period)
	site.special.hospital_elapsed = elapsed - pulses * period
	if pulses == 0: return
	for u in site.battle.units:
		if site.battle.actor_alive(u) and u.side == site.side and AlliedAbilities.infantry(u) and u.hp < u.max_hp:
			u.heal(float(rules.selfhealinfantryamount) * pulses)

static func transmit(w,clip:String,who:String) -> void:
	w.hud.show_field_transmission(who,preload("res://scripts/world/hollywood_dialogue.gd").LINES[clip],"")
	if clip != "": Ra2Sfx.play_hollywood_line(clip)

static func place(w,id:String,tile:Vector2i,house:String):
	var b=w._place_building(id,"enemy",retail_site_center(id,tile),true)
	if b:
		b.special.hollywood_house=house
		b.special.hollywood_retail_cell=tile
		b._buildup_play=-1.0
	return b

static func spawn(w,id:String,side:String,p:Vector2):
	var ground:Vector2=w.path_service.nearest_reachable(p,p,false,8)
	return w.spawn_unit(id,side,ground) if ground.is_finite() else null

static func move(w,u,p:Vector2) -> void:
	var route:PackedVector2Array=w.path_for_unit(u,p)
	u.order_move(p,false,null,route)

static func setup(w) -> void:
	var s := {"remaining":4,"phase":1,"poll":0.,"briefing":true,"intro":0.,"shot":0,"rescued":0,"lost":0,"plants":{},"crates":[],"visited":{},"crowd":5.,"patrol":12.,"reinforced":false,"cheer":4.,"taunted":false}
	w.allied_state.hollywood=s
	for i in FACTORIES.size():
		var tile:Vector2i=FACTORIES[i]
		var b=place(w,"YAGRND",tile,"Yuri3")
		if b:
			b.special.hollywood_plant=str(i)
			b.display_name="部队回收厂（%d号）" % (i+1)
			s.plants[str(i)]=b.position
	var bases:Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/hollywood_sites.json"))
	for row in bases:
		var site=place(w,row[0],Vector2i(int(row[1]),int(row[2])),row[3])
		var star:=star_guard_label(str(row[0]),int(row[1]),int(row[2]))
		if site!=null and not star.is_empty():site.special.hollywood_star_guard=star
	place_retail_walls(w)
	RetailSequences.setup_closure_sites(w)
	var bases_script = preload("res://scripts/world/hollywood_bases.gd")
	bases_script.populate(w)
	bases_script.assign_guards(w,int(BattleRequest.skirmish_config.get("difficulty",1)))
	for row in VISITS:
		if str(row[4])=="": continue
		var at:=Vector2i(int(row[1]),int(row[2]))
		if row[0]=="克林特":
			var crew:Dictionary=RETAIL_DRIVERS.batch16["0916B4CC"].crews[0]
			at=Vector2i(int(crew.at[0]),int(crew.at[1]))
		var hero=spawn(w,row[4],"neutral",cell(at.x,at.y))
		if hero:
			hero.special.hollywood_star=row[0]
			hero.display_name=row[0]
			hero.fire_stance="none"
	s.star_guards_bound=true
	bind_retail_sources(w,s)
	var shot:Dictionary=RETAIL_DRIVERS.extra["0B97536C"]
	w.center_on(cell(int(shot.at[0]),int(shot.at[1])))
	if shot.enable.has("0930F29C"):Film.show_clip(w,"A02_F00E",func(): transmit(w,"xa2ev01","伊娃"))

# ALL02UMD OverlayPack: walls are map obstacles, not base objectives.
static func place_retail_walls(w) -> void:
	for row in preload("res://data/maps/hollywood_wall_overlays.json").data:
		var id:String=row[2]
		var point:=(Vector2(row[0],row[1])+Vector2.ONE*0.5)*Native.CELL
		var wall=w._place_building(id,"enemy" if id=="GAFWLL" else "neutral",point,true)
		if wall==null:continue
		wall._buildup_play=-1.0
		wall.special.native_wall_pitch=55
		wall.special.hollywood_retail_wall=true

# ALL02UMD event 6 on the units/sites carrying these two Tags.
const STAR_GUARDS := {
	"阿诺":[["INIT",106,132],["INIT",107,132],["INIT",109,131],["INIT",109,132],["INIT",105,131]],
	"史泰龙":[["LTNK",158,81],["LTNK",161,79],["YABRCK",157,77],["YAPOWR",159,74],["YAPOWR",164,78]],
}

static func star_guard_label(id:String,x:int,y:int) -> String:
	for star in STAR_GUARDS:
		if STAR_GUARDS[star].has([id,x,y]):return star
	return ""

static func star_guard_attacked(w,actor) -> void:
	var star:String=actor.special.get("hollywood_star_guard","")
	if star.is_empty() or actor.side!="enemy":return
	var id:String={"阿诺":"0ABA8C5C","史泰龙":"08E32CFC"}.get(star,"")
	if id.is_empty():return
	var spec:Dictionary=RETAIL_DRIVERS.batch16[id]
	if not spec.enable.is_empty():w.allied_state.hollywood.get_or_add("star_awakened",{})[star]=spec.enable[0]

static func grinder_attacked(w,actor) -> void:
	var id:String={"0":"07F7DACC","2":"0464E91C"}.get(actor.special.get("hollywood_plant",""),"")
	if id.is_empty():return
	var s:Dictionary=w.allied_state.hollywood
	var fired:Dictionary=s.get_or_add("retail_grinder_attacked",{})
	if fired.has(id):return
	fired[id]=true
	var row:Dictionary=RETAIL_DRIVERS.extra[id]
	if not row.enable.is_empty():s.get_or_add("star_awakened",{})["阿诺" if id=="07F7DACC" else "史泰龙"]=row.enable[0]

static func start_patrols(w) -> void:
	w.allied_state.hollywood.patrols_started = true
	var level:=clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)
	for id in ["093C2ADC","092C9D5C","0B0F83EC","04EF835C"]:
		var row:Dictionary=RETAIL_DRIVERS.batch16[id]
		if int(row.mask[level])!=0:spawn_retail_guard_crews(w,row)
	for u in w.units:
		if not w.actor_alive(u) or u.side != "enemy" or u.embarked_in != null or not u.special.has("hollywood_patrol"): continue
		var anchor:Vector2 = u.special.hollywood_patrol
		var outward:Vector2 = anchor.direction_to(u.position)
		var end:Vector2 = w.path_service.nearest_reachable(u.position + outward * 220, u.position)
		if end.distance_to(u.position) > u.ARRIVE_EPS: u.order_patrol(end)
	spawn_retail_guard_crews(w,RETAIL_DRIVERS.extra["0D0983FC"],"teams")
	spawn_retail_guard_crews(w,RETAIL_DRIVERS.batch16["06C3CCCC"])
	spawn_retail_guard_crews(w,RETAIL_DRIVERS.batch16["0B8E13AC"])

static func spawn_retail_guard_crews(w,row:Dictionary,field:String="crews") -> void:
	var garrison=preload("res://scripts/units/civilian_orders.gd")
	for crew in row[field]:
		if crew.at==null:continue
		var entry:=cell(int(crew.at[0]),int(crew.at[1]))
		var n:=0
		for member in crew.members:
			for i in int(member[0]):
				var u=spawn(w,member[1],"enemy",entry+Vector2.RIGHT.rotated(n*2.4)*n*24.0)
				n+=1
				if u==null:continue
				u.special.hollywood_house="YuriCountry"
				u.special.hollywood_guard_trigger=row.id
				if int(crew.get("enter",0))!=0:
					var best=null
					var nearest:=INF
					var type:String={61:"NATBNK",62:"YAPOWR",63:"NABNKR"}.get(int(crew.enter),"")
					for b in w.buildings:
						if not w.actor_alive(b) or b.side!="enemy" or b.building_id!=type or not garrison.can_enter(u,b):continue
						var d:float=u.position.distance_squared_to(b.position)
						if d<nearest:nearest=d;best=b
					if best!=null and u.order_interaction("allied_garrison",best,false):continue
				if row.id=="06C3CCCC" and u.unit_id=="LTNK" and not crew.route.is_empty():
					u.special.hollywood_studio_patrol=true
					var leg:Array=crew.route[0]
					u.order_patrol(cell(int(leg[0]),int(leg[1])))
				else:
					for leg in crew.route:u.queue_waypoint(cell(int(leg[0]),int(leg[1])),null,bool(leg[2]))

# ALL02UMD scripted reinforcements are independent of paid factory AI.
static func difficulty_attacks(w,s:Dictionary,elapsed:float) -> void:
	var level:=clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)
	var waves:Dictionary=RETAIL_DRIVERS.waves
	if not s.has("retail_wave_id"):
		var first:=""
		var lead:=0.0
		if level==2:
			if not w.buildings.any(func(b):return w.actor_alive(b) and b.side=="ally" and not b.under_construction and b.building_id==RETAIL_DRIVERS.gate.type):return
			first=RETAIL_DRIVERS.gate.hard
		else:
			if not s.visited.has("克林特"):return
			var intro:Dictionary=RETAIL_DRIVERS.intro["045E609C"]
			var warm:Dictionary=RETAIL_DRIVERS.intro[RETAIL_DRIVERS.warmup]
			if not intro.enable.has(warm.id):return
			lead=float(intro.delay)+float(warm.delay)
			for id in warm.enable:
				if waves.has(id) and int(waves[id].mask[level])!=0:first=id;break
		if first.is_empty():return
		var old_index:=clampi(int(s.get("attack_index",0)),0,5)
		for i in old_index:first=waves[first].next
		s.erase("attack_index")
		s.retail_wave_id=first
		s.attack_left=float(s.get("attack_left",lead+float(waves[first].delay)))
		return
	var spec:Dictionary=waves.get(s.retail_wave_id,{})
	if spec.is_empty() or int(spec.mask[level])==0:return
	s.attack_left=maxf(0.0,float(s.attack_left)-elapsed)
	if s.attack_left>0.0:return
	# Local 62 remains approximated by the existing satellite ownership gate.
	if int(spec.blockedTypeIndex)==62 and w.buildings.any(func(b):return w.actor_alive(b) and b.side=="ally" and b.building_id=="GASPYSAT"):return
	spawn_retail_wave(w,spec)
	s.retail_wave_id=spec.next
	s.attack_left=float(waves[spec.next].delay)

static func spawn_retail_wave(w,spec:Dictionary) -> void:
	var team:Dictionary=spec.team
	var point:=cell(int(team.at[0]),int(team.at[1]))
	var n:=0
	for row in team.members:
		for _i in int(row[0]):
			var u=spawn(w,row[1],"enemy",point+Vector2.RIGHT.rotated(n*2.4)*(n*24))
			n+=1
			if u==null:continue
			u.special.hollywood_house="Yuri2"
			u.special.hollywood_wave_trigger=spec.id
			for leg in team.route:u.queue_waypoint(cell(int(leg[0]),int(leg[1])),null,bool(leg[2]))
			u.queue_waypoint(w._player_target(),null,true)

static func intro(w,s:Dictionary,dt:float) -> void:
	var resume_clip: String = s.get("resume_briefing_clip", "")
	if not resume_clip.is_empty():
		s.erase("resume_briefing_clip")
		match resume_clip:
			"A02_F00E": Film.show_clip(w, resume_clip, func(): transmit(w,"xa2ev01","伊娃"))
			"A02_P01E": Film.show_clip(w, resume_clip)
			"A02_P02E": Film.show_clip(w, resume_clip, func(): transmit(w,"xa2ev02","伊娃"))
		return
	s.intro+=dt
	if s.has("retail_pointer_left"):
		s.retail_pointer_left=float(s.retail_pointer_left)-dt
		if s.retail_pointer_left<=0.0:
			s.erase("retail_pointer_left")
			w.hud.minimap.clear_objective_flashes()
	if s.intro>=float(RETAIL_DRIVERS.extra["0B975C7C"].delay) and not s.get("retail_lax_revealed",false):
		s.retail_lax_revealed=true
		for p in RETAIL_DRIVERS.extra["0B975C7C"].reveal:w.fog._reveal("ally",cell(int(p[0]),int(p[1])),180.0,3.0)
	if s.shot == 0 and not s.get("airport_report",false) and not w.has_node("HollywoodFilm"):
		s.airport_report = true
		if RETAIL_DRIVERS.briefing["0930F29C"].enable.has("0895FDFC") and RETAIL_DRIVERS.extra["0895FDFC"].enable.has("093093FC"):
			Film.show_clip(w,"A02_P01E",func():
				var row:Dictionary=RETAIL_DRIVERS.briefing["093093FC"]
				if row.enable.has("099AEA1C"):
					var at:Array=RETAIL_DRIVERS.briefing["099AEA1C"].at
					Events.emit_radar_ping(cell(int(at[0]),int(at[1])),"campaign_site")
				if row.enable.has("099AFF3C"):s.retail_pointer_left=float(RETAIL_DRIVERS.briefing["099AFF3C"].delay))
	if s.shot==0 and s.intro>=7 and not w.has_node("HollywoodFilm"):
		s.shot=1
		flash_buildings(w,"YAGRND",int(RETAIL_DRIVERS.briefing["0930C5CC"].frames))
		center_briefing(w,s)
		if RETAIL_DRIVERS.extra["0930CDEC"].enable.has("0930C5CC") and RETAIL_DRIVERS.briefing["0930C5CC"].enable.has("0932705C"):
			Film.show_clip(w,"A02_P02E",func(): transmit(w,"xa2ev02","伊娃"))
		for team in RETAIL_DRIVERS.extra["0462733C"].teams:
			if team.at==null:continue
			for member in team.members:
				var citizen=spawn(w,member[1],"neutral",cell(int(team.at[0]),int(team.at[1])))
				if citizen!=null:citizen.set_fire_stance("none")
		crowd(w,s)
	if s.shot==1 and w.has_node("HollywoodFilm"):return
	if s.shot==1 and s.intro>=12:
		s.shot=3
		if RETAIL_DRIVERS.briefing["091B6F3C"].enable.has("088509DC"):transmit(w,"cevau54","伊娃")
	if s.shot in [1,3] and s.intro>=15:
		s.shot=2
		s.briefing=false
		s.retail_yuri2_active=RETAIL_DRIVERS.briefing["043842DC"].enable.has("0921C8DC") and RETAIL_DRIVERS.extra["0921C8DC"].enable.has("0463917C")
		s.retail_yuri2_delay=float(RETAIL_DRIVERS.lifecycle["0BCF2BEC"].delay)
		start_patrols(w)
		var ret:Array=RETAIL_DRIVERS.briefing["04384E4C"].at
		if RETAIL_DRIVERS.briefing["04384E4C"].enable.has("043842DC"):w.center_on(cell(int(ret[0]),int(ret[1])))
		var home:Vector2=w.player_start()
		var mcv=spawn(w,RETAIL_DRIVERS.batch16["096947BC"].crews[0].members[0][1],"ally",home)
		# Keep the current player deployment area; use the retail infantry team counts.
		var infantry:Array=RETAIL_DRIVERS.batch16["0967DE9C"].crews
		for i in infantry.size():
			for member in infantry[i].members:
				for _n in int(member[0]):spawn(w,member[1],"ally",home+Vector2.RIGHT.rotated(i*TAU/infantry.size())*155.)
		var support:Array=RETAIL_DRIVERS.batch16["096947BC"].crews
		for i in range(1,support.size()):
			for member in support[i].members:
				for _n in int(member[0]):spawn(w,member[1],"ally",home+Vector2.RIGHT.rotated(i*TAU/support.size())*235.)
		for i in 2: spawn(w,"MTNK","ally",home+Vector2(180,i*120))
		w.fog.rebuild()
		for p in RETAIL_DRIVERS.extra["0CDDB12C"].reveal:w.fog._reveal("ally",cell(int(p[0]),int(p[1])),180.0,3.0)
		w.center_on(home)
		if mcv: w.select_unit(mcv,false); w._emit_selection()
		Ra2Sfx.play_player_eva(w,"EVA_BattlefieldControlOnline")
		w.hud.show_field_transmission("伊娃","战场控制系统已上线。","")
		Events.emit_message("机场车队已抵达。选中基地车，按 J 展开。派工程师占领洛杉矶国际机场，即可获得伞兵援助。")

static func crowd(w,s:Dictionary) -> void:
	var streets := {"0":cell(109,124),"1":cell(136,79),"2":cell(201,105)}
	for plant in w.buildings:
		if not w.actor_alive(plant): continue
		var key:String=plant.special.get("hollywood_plant","")
		if key not in ResidentQueue.ROUTES or not s.plants.has(key): continue
		if s.visited.has("克林特") and key in ["0","1"]:continue
		var points:=ResidentQueue.slots(w,plant,streets[key])
		if points.is_empty(): continue
		var count:int=w.units.filter(func(u):return w.actor_alive(u) and u.special.get("hollywood_civilian")==key).size()
		for i in range(count,ResidentQueue.LENGTH):
			var u=spawn(w,["CIV1","CIV2","CIV3"][(int(key)+i)%3],"neutral",points[i+1])
			if u:
				u.special.hollywood_civilian=key
				u.display_name="被控制的居民"
				u.fire_stance="none"
				move(w,u,points[i])

static func bind_retail_sources(w,s:Dictionary) -> void:
	if s.has("retail_sources"):return
	var sources:Dictionary={}
	for id in RETAIL_DRIVERS.sources:
		var row:Dictionary=RETAIL_DRIVERS.sources[id]
		var point:=retail_site_center(row.type,Vector2i(int(row.at[0]),int(row.at[1])))
		var actor=null
		for b in w.buildings:
			if w.actor_alive(b) and b.building_id==row.type and b.position.distance_to(point)<1.0:actor=b;break
		if actor!=null:sources[id]=actor
	s.retail_sources=sources

static func staged_residents(w,s:Dictionary,elapsed:float,plants:Dictionary) -> void:
	var jobs:Dictionary=s.get_or_add("retail_staged_residents",{})
	if not s.get("retail_staged_started",false):
		s.retail_staged_started=true
		for id in RETAIL_DRIVERS.openRoots:
			var spec:Dictionary=RETAIL_DRIVERS.staged[id]
			jobs[spec.plant]={"id":id,"left":float(spec.delay)}
	for key in jobs.keys():
		var plant=plants.get(key)
		if plant==null or not s.plants.has(key):jobs.erase(key);continue
		var job:Dictionary=jobs[key]
		job.left=float(job.left)-elapsed
		if float(job.left)>0.0:continue
		var row:Dictionary=RETAIL_DRIVERS.staged[job.id]
		var p:=cell(int(row.team.at[0]),int(row.team.at[1]))
		var line:Array=ResidentQueue.slots(w,plant,p)
		if line.is_empty():line=ResidentQueue.slots(w,plant,plant.position+Vector2(400,0))
		if line.is_empty():continue
		var from:Vector2=w.path_service.nearest_reachable(p,line.back(),false,24)
		if not from.is_finite():continue
		var actor=w.spawn_unit(str(row.team.members[0][1]),"neutral",from)
		if actor==null:continue
		actor.special.hollywood_civilian=key
		actor.special.hollywood_staged_trigger=row.id
		actor.special.hollywood_staged_team=row.team.id
		actor.display_name="被控制的居民"
		actor.set_fire_stance("none")
		move(w,actor,line.back())
		if str(row.next).is_empty():jobs.erase(key)
		else:jobs[key]={"id":row.next,"left":float(RETAIL_DRIVERS.staged[row.next].delay)}

static func retail_residents(w,s:Dictionary,elapsed:float) -> void:
	if not s.visited.has("克林特"):return
	var clocks:Dictionary=s.get_or_add("retail_resident_routes",{})
	var plants:Dictionary={}
	for b in w.buildings:
		if w.actor_alive(b) and b.side=="enemy" and b.special.has("hollywood_plant") and not b.special.get("hollywood_infiltrated",false):plants[b.special.hollywood_plant]=b
	bind_retail_sources(w,s)
	staged_residents(w,s,elapsed,plants)
	for spec in RETAIL_DRIVERS.residents.values():
		if s.retail_sources.has(spec.id) and not w.actor_alive(s.retail_sources[spec.id]):
			clocks.erase(spec.id)
			continue
		var plant=plants.get(spec.plant)
		if plant==null or not s.plants.has(spec.plant):
			clocks.erase(spec.id)
			continue
		var state:Dictionary=clocks.get_or_add(spec.id,{"left":0.0})
		state.left=float(state.left)-elapsed
		var resident=state.get("actor")
		if w.actor_alive(resident):
			if float(state.left)>0.0 or resident.special.has("hollywood_resident_change"):continue
			if not resident.special.has("hollywood_civilian"):continue
			# The original resets the paired route after its arrival flag and random wait.
			# Never remove a resident that has not reached the factory's waiting line.
			var points:Array=plant.special.get("civilian_queue_slots",[])
			if points.is_empty() or not points.any(func(p):return resident.position.distance_to(p)<25.0):continue
			resident.special.hollywood_resident_change=spec.change
			state.left=float(spec.wait) # Leave an opportunity for other ready routes at this factory.
			continue
		if float(state.left)>0.0:continue
		var street:=cell(int(spec.walker.at[0]),int(spec.walker.at[1]))
		var queue:Array=ResidentQueue.slots(w,plant,street)
		if queue.is_empty():queue=ResidentQueue.slots(w,plant,plant.position+Vector2(400,0))
		if queue.is_empty():continue
		var live:int=w.units.filter(func(u):return w.actor_alive(u) and u.special.get("hollywood_civilian")==spec.plant).size()
		if live>=ResidentQueue.LENGTH:continue
		var source:Vector2=w.path_service.nearest_reachable(street,queue.back(),false,24)
		if not source.is_finite():continue
		var u=w.spawn_unit(str(spec.walker.members[0][1]),"neutral",source)
		if u==null:continue
		u.special.hollywood_civilian=spec.plant
		u.special.hollywood_resident_trigger=spec.id
		u.display_name="被控制的居民"
		u.set_fire_stance("none")
		move(w,u,queue.back())
		state.actor=u
		state.left=floorf(float(spec.wait)*float(randi_range(50,150))/100.0)

static func retail_goal_hints(w,s:Dictionary,elapsed:float) -> void:
	var hints:Dictionary=RETAIL_DRIVERS.hints
	var jobs:Dictionary=s.get_or_add("retail_goal_hints",{})
	var radar:=radar_online(w)
	if radar!=s.get("retail_hint_radar",false):
		s.retail_hint_radar=radar
		if radar:
			for id in hints["0D20AA9C"].enable:
				if hints.has(id) and float(hints[id].delay)>0.0:jobs[id]=float(hints[id].delay)
		else:
			for id in hints["0D1FE81C"].disable:jobs.erase(id)
	for id in jobs.keys():
		if int(s.phase)!=1:jobs.erase(id);continue
		jobs[id]=float(jobs[id])-elapsed
		if float(jobs[id])>0.0:continue
		jobs.erase(id)
		var row:Dictionary=hints[id]
		if row.at!=null:
			# The project lists the last two sites in reverse retail trigger order.
			var key:String={2:"0",3:"1",4:"3",5:"2"}.get(int(row.flag),"")
			if s.plants.has(key):Events.emit_radar_ping(cell(int(row.at[0]),int(row.at[1])),"campaign_site")
		if row.text=="MISSION:Grinders":Events.emit_message("任务目标：让四座尤里回收厂停运。")

static func proximity(units:Array,p:Vector2,radius:float) -> bool:
	return units.any(func(u):return u.position.distance_squared_to(p)<radius*radius)

# ALL02UMD Find_Dino uses the perimeter CellTags, event 59 (entered or overflown).
static func discover_dinosaur(w, s:Dictionary) -> void:
	if s.get("rexy_triggered", false): return
	for scout in w.get_tree().get_nodes_in_group("allies"):
		if not scout is Unit or scout.side != "ally" or not w.actor_alive(scout) or scout.embarked_in != null: continue
		var tile := Vector2i((scout.position / Native.CELL).floor())
		var x := tile.y + 12
		var y := 206 - tile.x
		if not ((x in [128,144] and y >= 125 and y <= 138) or (y in [125,138] and x >= 128 and x <= 144)): continue
		s.rexy_triggered = true
		s.visited["恐龙片场"] = true
		transmit(w,"xa2ev04","伊娃")
		var rules:Dictionary = preload("res://scripts/core/yr_death_rules.gd").data().general
		w.fog._reveal("ally", cell(140,134), float(rules.revealtriggerradius) * Native.CELL)
		for rex in w.units:
			if not w.actor_alive(rex) or rex.unit_id != "DNOA" or rex.side != "neutral" or rex.special.get("hollywood_house") != "Neutral": continue
			# Rexy_Script changes ownership to house 0, then assigns mission 11.
			AlliedAbilities.change_side(rex,"ally")
			rex.set_fire_stance("free")
			rex.special.rexy_guard_origin = rex.position
			Events.emit_message("片场的霸王龙已加入你的部队。")
			break
		return

static func discover(w,s:Dictionary,allies:Array) -> void:
	for row in VISITS:
		var place_name:String=row[0]
		var p:=cell(row[1],row[2])
		if place_name in STAR_GUARDS and s.get("star_guards_bound",false):
			if not s.get("star_awakened",{}).has(place_name):continue
			var conversion:String={"阿诺":"0ABAE7BC","史泰龙":"065C3EDC"}[place_name]
			var armed=s.star_awakened[place_name]
			if armed is String and armed!=conversion:continue
		elif not (place_name=="克林特" and s.get("retail_westwood_pending",false)) and not proximity(allies,p,320):continue
		if not s.visited.has(place_name):
			s.visited[place_name]=true
			if place_name=="克林特":
				s.clint_report_left=float(RETAIL_DRIVERS.westwood["05D9EE6C"].delay)
				s.erase("retail_westwood_pending")
				s.get_or_add("retail_lifecycle_flags",{})["64"]=true
			if place_name=="阿诺":
				var ping:Array=RETAIL_DRIVERS.batch16["0ABAE7BC"].ping
				Events.emit_radar_ping(cell(int(ping[0]),int(ping[1])),"campaign_discovery")
			var text: String="已找到%s。" % place_name
			for u in w.units:
				if w.actor_alive(u) and u.special.get("hollywood_star")==place_name:
					AlliedAbilities.change_side(u,"ally")
					u.special.studio_rescued=true
					u.set_fire_stance("free")
					if place_name in STAR_GUARDS:
						Events.emit_radar_ping(u.position,"campaign_discovery")
						u.special.hollywood_actor_flash=120.0/BattleClock.RULE_TICKS_PER_SECOND
						if place_name=="史泰龙":
							for point in [cell(157,78),cell(159,74)]:
								var victim=null
								var best:=115.0
								for b in w.buildings:
									if not w.actor_alive(b) or b.side!="enemy" or b.special.get("hollywood_star_guard")!=place_name:continue
									var d:float=b.position.distance_to(point)
									if d<best:best=d;victim=b
								if victim!=null:u.order_target(victim,false,true)
							var exit:=cell(156,73)
							if u.attack_ordered or u.has_move_order:u.queue_waypoint(exit)
							else:move(w,u,exit)
					text="%s已经加入你的部队。" % place_name
			Events.emit_message(text)
			transmit(w,row[3],place_name if row[3] in ["xa2ar01","xa2sl01"] else "伊娃")

static func discover_facilities(w,s:Dictionary) -> void:
	for row in FACILITY_DISCOVERIES:
		var label:String=row[1]
		if s.visited.has(label): continue
		for site in w.buildings:
			if not w.actor_alive(site) or site.building_id!=row[0] or not w.actor_visible_to("ally",site): continue
			s.visited[label]=true
			var point:=cell(row[2],row[3])
			var general:Dictionary=preload("res://scripts/core/yr_death_rules.gd").data().general
			w.fog._reveal("ally",point,float(general.revealtriggerradius)*Native.CELL)
			site.special.campaign_flash_left=40.0/BattleClock.RULE_TICKS_PER_SECOND
			Events.emit_radar_ping(point,"campaign_discovery")
			Events.emit_message("发现科技医院。派工程师占领后，己方步兵会自动恢复生命。" if row[0]=="CATHOSP" else "发现机械维修厂。派工程师占领后，己方车辆会自动恢复耐久。")
			transmit(w,row[4],"伊娃")
			break

static func plants_tick(w,s:Dictionary,allies:Array,elapsed:float) -> void:
	if s.has("yuri_leave_left"):
		s.yuri_leave_left=float(s.yuri_leave_left)-elapsed
		if s.yuri_leave_left<=0:
			s.erase("yuri_leave_left")
			s.yuri_leave_played=true
			transmit(w,"xs3yu05","尤里")
	var active:Dictionary={}
	for b in w.buildings:
		if w.actor_alive(b) and b.side=="enemy" and b.special.has("hollywood_plant") and not b.special.get("hollywood_infiltrated",false):active[b.special.hollywood_plant]=b
	for key in s.plants.keys():
		if active.has(key):continue
		var waypoint:Vector2i=CASH_WAYPOINTS[int(key)]
		var point:=cell(waypoint.x,waypoint.y)
		s.crates.append(point)
		var tile:=crate_tile(point)
		for unit in allies:
			if crate_collector(unit) and crate_tile(unit.position)==tile:
				unit.special.hollywood_crate_underfoot=tile
		s.plants.erase(key)
		# All four Grinder*_Gone triggers enable the same one-second taunt.
		if not s.get("yuri_leave_played",false) and not s.has("yuri_leave_left"):
			# An old save already played the line immediately on the first plant.
			if not s.plants.has("0") and key!="0":s.yuri_leave_played=true
			else:s.yuri_leave_left=1.0
		if key in ["0","2"]:transmit(w,"xa2gg01","重装大兵")
		Events.emit_message("%d号回收厂已停运。让地面部队走到旁边的资金箱上，领取 %d 资金。" % [int(key)+1,CASH_REWARD])
	var lines:Dictionary={}
	for u in w.units.duplicate():
		if not w.actor_alive(u) or not u.special.has("hollywood_civilian"):continue
		var key:String=u.special.hollywood_civilian
		if not s.plants.has(key):
			u.special.erase("hollywood_civilian")
			u.special.hollywood_rescued=true
			u.display_name="获救的居民"
			u.order_stop(false)
			s.rescued+=1
		else:
			lines.get_or_add(key,[]).append(u)
	for key in lines:
		ResidentQueue.advance(w,active[key],lines[key],elapsed)
	s.remaining=s.plants.size()

static func crate_tile(p:Vector2) -> Vector2i:
	return Vector2i((p/Native.CELL).floor())

static func crate_collector(u) -> bool:
	return not u.is_air and not u.is_naval and u.embarked_in==null and not u.special.has("hollywood_on_deck")

# Pickup is positional, so do not sample it at the half-second mission polling rate.
static func collect_cash_crates(w,s:Dictionary) -> void:
	if s.crates.is_empty():return
	for unit in w.units:
		if not w.actor_alive(unit) or unit.side!="ally" or not crate_collector(unit):continue
		var tile:=crate_tile(unit.position)
		if unit.special.get("hollywood_crate_underfoot")==tile:continue
		unit.special.erase("hollywood_crate_underfoot")
		for p in s.crates:
			if crate_tile(p)!=tile:continue
			s.crates.erase(p)
			Ra2Fx.play(w.effects_root, p, "MONEY")
			w.add_funds(CASH_REWARD)
			Events.emit_message("已回收 %d 资金。" % CASH_REWARD)
			break
		if s.crates.is_empty():return

static func radar_online(w) -> bool:
	return w.allied_state.get("hollywood",{}).get("radar",false)

static func update_radar(w,s:Dictionary,elapsed:=0.0) -> void:
	var online:bool=w.buildings.any(func(b):return w.actor_alive(b) and b.side=="ally" and b.building_id in ["GAAIRC","AMRADR","GASPYSAT","NARADR"] and b.is_operational() and not w.side_power_low("ally"))
	if online != radar_online(w):
		s.radar=online
		s.radar_ping_left=0.0
		Events.emit_message("雷达已上线，黄色标记指示仍在运转的回收厂。" if online else "雷达离线。恢复供电或重建空指部。")
		w.hud.minimap.queue_redraw()
	if online and s.remaining>0:
		s.radar_ping_left=float(s.get("radar_ping_left",0.0))-elapsed
		if s.radar_ping_left<=0:
			w.hud.minimap.clear_objective_flashes()
			for point in s.plants.values(): Events.emit_radar_ping(point,"campaign_site")
			s.radar_ping_left=120.0

static func briefing_point(s:Dictionary) -> Vector2:
	var row:Dictionary=RETAIL_DRIVERS.briefing["093093FC" if s.shot==0 else "0930C5CC"]
	return cell(int(row.at[0]),int(row.at[1]))

static func center_briefing(w,s:Dictionary) -> void:
	w.fog.rebuild()
	w.center_on(briefing_point(s))

static func markers(w, radar := true) -> Array:
	var s: Dictionary = w.allied_state.hollywood
	var result := []
	var online := radar_online(w)
	if w.ended or s.phase == 3 or (radar and not online): return result
	for b in w.buildings:
		if not w.actor_alive(b) or b.side != "enemy": continue
		var p: Vector2 = b.position
		var key: String = b.special.get("hollywood_plant", "")
		if s.phase == 1 and s.plants.has(key) and not b.special.get("hollywood_infiltrated", false):
			if online or w.position_explored_by("ally", p):
				result.append({"position":p,"actor":b,"status":"active","title":"部队回收厂","color":Color.GOLD,"roof_gap":18.0})
		elif s.phase == 2 and w.position_explored_by("ally", p) and b.special.get("hollywood_house") in ["YuriCountry","Yuri2"]:
			result.append({"position":p,"actor":b,"status":"active","title":"摧毁" + b.display_name,"color":Color.TOMATO,"roof_gap":18.0})
	for p in s.get("crates", []):
		if radar or w.position_explored_by("ally", p):
			result.append({"position":p,"status":"active","title":"资金箱","color":Color.LIME_GREEN,"optional":true})
	return result

static func flash_buildings(w,id:String,frames:int) -> void:
	for b in w.buildings:
		if not w.actor_alive(b) or b.building_id!=id:continue
		if id=="YAGRND" and not b.special.has("hollywood_plant"):continue
		b.special.campaign_flash_left=float(frames)/BattleClock.RULE_TICKS_PER_SECOND

static func draw_supplies(w) -> void:
	var s:Dictionary=w.allied_state.hollywood
	if s.briefing and s.shot==0:
		var arrow:=RA2Art.fx("ARRWW")
		if not arrow.is_empty():
			var frame:=int(float(s.intro)*7.5)%int(arrow.count)
			var src:=RA2Art.fx_rect(arrow,frame)
			var size:=src.size*1.5
			w.hp_overlay.draw_texture_rect_region(arrow.tex,Rect2(Iso.dir(cell(113,177))-size/2,size),src)
	for p in w.allied_state.hollywood.get("crates",[]):
		if not w.position_visible_to("ally",p):continue
		var pos:=Iso.dir(p)
		var size := CASH_CRATE.get_size()
		var top_left := pos - Vector2(size.x * 0.5, size.y - 10.0)
		w.hp_overlay.draw_texture(CASH_CRATE, top_left)
		w.hp_overlay.draw_string(ThemeDB.fallback_font,Vector2(pos.x - 25, top_left.y - 4),"资金箱")

# ALL02UMD 094D821C: an existing player-owned NADEPT, not a construction site.
static func repair_depot_taunt(w,s:Dictionary) -> void:
	if s.get("taunted",false):return
	for b in w.buildings:
		if not w.actor_alive(b) or b.side!="ally" or b.building_id!="NADEPT" or b.under_construction:continue
		s.taunted=true
		transmit(w,"xa2yu01","尤里")
		return

# 05D9EE6C: 15 rule seconds from Clint's discovery, not from mission start.
static func clint_report(w,s:Dictionary,elapsed:float) -> void:
	if not s.has("clint_report_left"):return
	s.clint_report_left=maxf(0.0,float(s.clint_report_left)-elapsed)
	if s.clint_report_left>0.0 or w.has_node("HollywoodFilm"):return
	# Keep pending until the callback so a snapshot taken during the short clip can resume it.
	Film.show_clip(w,"A02_P03E",func():s.erase("clint_report_left"))

# ALL02 09635F3C / 0CEBD51C: house-scoped loss conditions, sale then hunt.
static func enemy_site_lost(w,b) -> void:
	if b.side!="enemy" or b.special.get("hollywood_house")!="YuriCountry":return
	var s:Dictionary=w.allied_state.get("hollywood",{})
	s.main_structures_destroyed=int(s.get("main_structures_destroyed",0))+1

static func fire_sale(w,s:Dictionary,house:String,delay:float) -> void:
	s.get_or_add("withdrawals",{})[house]={"left":delay,"hunting":false}
	s.erase("retail_order_"+house)
	for b in w.buildings.duplicate():
		if not w.actor_alive(b) or b.side!="enemy" or b.special.get("hollywood_house")!=house:continue
		if b.data.get("unsellable",false) or GameData._ra2_flag(GameData.ra2_source_buildings.get(b.building_id,{}).get("extra",{}).get("Unsellable",false)):continue
		w.credit_side("enemy",float(GameData.ra2_refund(int(b.data.get("cost",0))))+b.total_production_paid())
		b.retire_sold()
		w.buildings.erase(b)
	w._refresh_pathing()
	w._update_power()

static func withdrawals_tick(w,s:Dictionary,elapsed:float) -> void:
	var states:Dictionary=s.get_or_add("withdrawals",{})
	for house in states:
		var row:Dictionary=states[house]
		if row.hunting:continue
		row.left=maxf(0.0,float(row.left)-elapsed)
		if row.left>0.0:continue
		row.hunting=true
		hunt_house(w,house)
	if not s.visited.has("克林特"):return
	for house in ["YuriCountry","Yuri2"]:
		if states.has(house):continue
		var types:Array=["YAPOWR","YABRCK"] if house=="Yuri2" else ["CASTRT05","YAPOWR","YABRCK","NAINDP"]
		if w.buildings.any(func(b):return w.actor_alive(b) and b.side=="enemy" and b.special.get("hollywood_house")==house and b.building_id in types):continue
		if house=="Yuri2" and s.remaining!=0:continue
		if house=="YuriCountry" and int(s.get("main_structures_destroyed",0))<24:continue
		if house=="Yuri2":hunt_house(w,house) # 09635F3C also requests Hunt immediately.
		fire_sale(w,s,house,5.0 if house=="Yuri2" else 6.0)

static func hunt_house(w,house:String) -> void:
	for u in w.units:
		if not w.actor_alive(u) or u.side!="enemy" or u.special.get("hollywood_house")!=house or u.embarked_in!=null or u.is_harvester:continue
		u.special.erase("campaign_area_guard")
		u.order_guard()
		var goal:Vector2=w._player_target()
		u.order_move(goal,true,null,w.path_for_unit(u,goal))

# Win_Check enables both timers concurrently (3 and 10 seconds, not 3+10).
static func finish_timeline(w,s:Dictionary,dt:float) -> void:
	if not s.has("final_win_elapsed"):
		# A legacy save in phase 3 already played the celebration.
		s.cheer=maxf(0.0,float(s.cheer)-dt)
		if s.cheer<=0.0:w.end_battle(true)
		return
	s.final_win_elapsed=float(s.final_win_elapsed)+dt
	if s.final_win_elapsed>=3.0 and not s.get("final_cheer_sent",false):
		s.final_cheer_sent=true
		for resident in w.units:
			if w.actor_alive(resident) and (resident.side=="ally" or resident.special.get("hollywood_rescued",false)) and resident._seq.has("Cheer"):
				resident.special.cheer_elapsed=0.0
				resident.queue_redraw()
		Events.emit_message("洛杉矶已解放！获救的居民正在街头欢呼。")
	RetailSequences.neutral_cheer(w,s)
	if s.final_win_elapsed>=10.0:w.end_battle(true)

# 0CDDC84C enables 094D906C; persistent HUD phase remains separate from the radio delay.
static func new_mission_notice(w,s:Dictionary,elapsed:float) -> void:
	if s.has("new_mission_notice_left"):
		var left:=float(s.new_mission_notice_left)-elapsed
		if left>0.0:s.new_mission_notice_left=left;return
		s.erase("new_mission_notice_left")
		s.new_mission_repeat_left=float(TIMERS[TIMERS["094d906c"].enable[0]].seconds)
		Ra2Sfx.play_player_eva(w,"EVA_NewMissionObjective")
		Events.emit_message("新任务目标：摧毁尤里剩余的基地建筑。")
		elapsed=-left
	if s.has("new_mission_repeat_left"):
		s.new_mission_repeat_left=maxf(0.0,float(s.new_mission_repeat_left)-elapsed)
		if s.new_mission_repeat_left>0.0:return
		s.erase("new_mission_repeat_left")
		Events.emit_message("任务目标：摧毁尤里剩余的基地建筑。") # 04627BCC

# 0618F5CC -> 07AC738C; TeamType 07F0E85C / ScriptType 07F0E5EC.
static func fortress_tick(w,s:Dictionary,elapsed:float) -> void:
	var destination:=cell(170,132) # CR / 95
	if s.has("fortress_report_left"):
		s.fortress_report_left=maxf(0.0,float(s.fortress_report_left)-elapsed)
		if s.fortress_report_left<=0.0:
			s.erase("fortress_report_left")
			s.fortress_report_sent=true
			Events.emit_radar_ping(destination,"campaign_discovery")
			Ra2Sfx.play_player_eva(w,"EVA_ReinforcementsHaveArrived")
			w.hud.show_field_transmission("伊娃","增援部队已抵达。","")
	if s.reinforced or float(s.get("fortress_elapsed",0.0))<float(TIMERS["0618f5cc"].seconds):return
	if not w.buildings.any(func(b):return w.actor_alive(b) and b.side=="ally" and b.building_id=="GATECH" and not b.under_construction):return
	var fortress=spawn(w,"BFRT","ally",cell(180,142)) # KE / 290
	if fortress==null:return
	s.reinforced=true
	for id in ["GGI","GGI","GGI","E1","E1"]:
		var passenger=spawn(w,id,"ally",fortress.position)
		if passenger and passenger.logistics.request_board(fortress):passenger.logistics.tick(0)
	move(w,fortress,destination)
	s.fortress_report_left=float(TIMERS[TIMERS["0618f5cc"].enable[0]].seconds)
	s.cameo_left=120.0/BattleClock.RULE_TICKS_PER_SECOND
	w.hud.select_prod_tab("vehicle")
	transmit(w,"cevau71","伊娃")

static func tick(w,dt:float) -> void:
	var s:Dictionary=w.allied_state.hollywood
	if not s.has("plants"):return
	if s.get("cameo_left",0.)>0: s.cameo_left=maxf(0.,s.cameo_left-dt)
	if s.briefing:intro(w,s,dt);return
	if s.phase==3:
		RetailSequences.cleanup(w,s,dt)
		finish_timeline(w,s,dt)
		return
	RetailSequences.voice_tick(s,dt)
	collect_cash_crates(w,s)
	discover_dinosaur(w,s)
	s.poll-=dt
	if s.poll>0:return
	var elapsed:=0.5-float(s.poll)
	s.poll=.5
	difficulty_attacks(w,s,elapsed)
	if not s.get("patrols_started",false): start_patrols(w)
	var allies:Array=w.units.filter(func(u):return w.actor_alive(u) and u.side=="ally" and not u.is_air and u.embarked_in==null)
	if allies.is_empty() and not w.units.any(func(u):return w.actor_alive(u) and u.side=="ally") and not w.buildings.any(func(b):return w.actor_alive(b) and b.side=="ally"):
		s.retail_loss_left=float(s.get("retail_loss_left",RETAIL_DRIVERS.lifecycle["0460D72C"].delay))-elapsed
		if s.retail_loss_left<=0.0:w.end_battle(false)
		return
	s.erase("retail_loss_left")
	preload("res://scripts/world/hollywood_bases.gd").tick(w,s,elapsed)
	plants_tick(w,s,allies,elapsed)
	retail_residents(w,s,elapsed)
	withdrawals_tick(w,s,elapsed)
	update_radar(w,s,elapsed)
	RetailSequences.tick(w,s,elapsed)
	retail_goal_hints(w,s,elapsed)
	new_mission_notice(w,s,elapsed)
	clint_report(w,s,elapsed)
	for u in w.units:
		if w.actor_alive(u) and u.special.has("hollywood_actor_flash"):
			var left:=float(u.special.hollywood_actor_flash)-elapsed
			if left<=0:u.special.erase("hollywood_actor_flash");u.self_modulate=Color.WHITE
			else:
				u.special.hollywood_actor_flash=left
				u.self_modulate=Color(1.35,1.35,1.35) if int(left*4.0)%2==0 else Color.WHITE
	RetailSequences.westwood_tick(w,s)
	discover(w,s,allies)
	discover_facilities(w,s)
	s.crowd-=elapsed
	if s.crowd<=0:s.crowd=5.;crowd(w,s)
	preload("res://scripts/world/hollywood_bridge_fixers.gd").tick(w,s,elapsed)
	repair_depot_taunt(w,s)
	s.fortress_elapsed=float(s.get("fortress_elapsed",0))+elapsed
	fortress_tick(w,s,elapsed)
	if s.remaining==0 and s.phase==1:
		s.phase=2
		s.new_mission_notice_left=float(TIMERS["094d906c"].seconds)
		w.hud.minimap.clear_objective_flashes()
		transmit(w,"xa2ev06","伊娃")
		Events.emit_message("回收厂已全部停运。摧毁尤里两处基地的剩余建筑。")
	elif s.phase==2 and s.get("retail_lifecycle_flags",{}).has("0") and not s.get("withdrawals",{}).values().any(func(row):return not row.hunting):
		s.phase=3
		s.final_win_elapsed=0.0
