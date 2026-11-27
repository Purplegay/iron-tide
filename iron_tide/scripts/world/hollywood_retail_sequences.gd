extends RefCounted

const DATA = preload("res://data/maps/hollywood_drivers.json").data
const CITY_SOUNDS = preload("res://data/ra2/allied_first_ambience.json").data

static func tick(w,s:Dictionary,dt:float) -> void:
	ambience(w,s,dt)
	closure_tick(w,s,dt)
	prisoners_tick(w,s,dt)
	latches(w,s,dt)
	if int(s.phase)==2:cleanup(w,s,dt)
	if int(s.phase)==1 or int(s.phase)==2:special_waves(w,s,dt)

# The retail tags are on the staged teams, not on every resident of the same type.
static func resident_click(w,s:Dictionary,point:Vector2) -> bool:
	var actor=w._pick_at(point,false)
	if s.get("briefing",false) or not w.actor_alive(actor) or not actor is Unit or actor.side!="neutral" or not w.actor_visible_to("ally",actor):return false
	if actor.special.get("hollywood_star")=="克林特" and not s.visited.has("克林特") and not s.get("retail_westwood_closed",{}).has("07A40B2C"):
		westwood_enable(s,"07A40B2C")
		return true
	return resident_voice(s,actor)

static func resident_voice(s:Dictionary,actor) -> bool:
	if s.get("briefing",false):return false
	for row in DATA.voices.values():
		if not row.teams.has(actor.special.get("hollywood_staged_team","")):continue
		var clocks:Dictionary=s.get_or_add("retail_resident_voice_left",{})
		if not clocks.has(row.next) and Ra2Sfx.play(row.cue,Vector2.INF,true):clocks[row.next]=float(row.delay)
		return true
	return false

static func voice_tick(s:Dictionary,dt:float) -> void:
	var clocks:Dictionary=s.get("retail_resident_voice_left",{})
	for id in clocks.keys():
		clocks[id]=float(clocks[id])-dt
		if clocks[id]<=0.0:clocks.erase(id)

static func westwood_enable(s:Dictionary,id:String) -> void:
	var row:Dictionary=DATA.westwood[id]
	var closed:Dictionary=s.get_or_add("retail_westwood_closed",{})
	for other in row.disable:closed[other]=true
	if not row.forced.is_empty() or row.enable.has("0916204C"):s.retail_westwood_pending=true

static func westwood_tick(w,s:Dictionary) -> void:
	if s.visited.has("克林特"):return
	var rows:Dictionary=DATA.westwood
	if live_site(w,"ally","GASPYSAT") and not s.get("retail_westwood_closed",{}).has("0926703C"):
		westwood_enable(s,"0926703C")
	if not s.get("retail_westwood_pending",false) and not s.get("retail_westwood_closed",{}).has("0464860C"):
		for u in w.units:
			if not w.actor_alive(u) or u.side!="ally" or u.embarked_in!=null:continue
			var tile:=Vector2i((u.position/55.0).floor())
			if rows["0464860C"].cells.any(func(c):return tile==Vector2i(206-int(c[1]),int(c[0])-12)):
				westwood_enable(s,"0464860C")
				break
	if not s.get("retail_westwood_pending",false) and not s.get("retail_westwood_closed",{}).has("09D2968C"):
		for u in w.units:
			if w.actor_alive(u) and u.special.get("hollywood_star")=="克林特" and w.fog.is_explored_at("ally",u.position):westwood_enable(s,"09D2968C");break
	if not s.get("retail_westwood_pending",false):return
	var reveal:Array=rows["0916204C"].reveal
	var point:Vector2=w.Hollywood.cell(int(reveal[0]),int(reveal[1]))
	var general:Dictionary=preload("res://scripts/core/yr_death_rules.gd").data().general
	w.fog._reveal("ally",point,float(general.revealtriggerradius)*55.0)
	for u in w.units:
		if w.actor_alive(u) and u.special.get("hollywood_star")=="克林特" and rows["0916204C"].flash:
			u.special.hollywood_actor_flash=120.0/BattleClock.RULE_TICKS_PER_SECOND
			break

static func prisoner_tag(actor,house:String,x:int,y:int) -> void:
	var id:String={"Germans":"095D099C","Neutral":"0958149C"}.get(house,"")
	if id.is_empty():return
	if DATA.prisoners[id].actors.any(func(a):return a[0]==actor.unit_id and int(a[1])==x and int(a[2])==y):
		actor.special.hollywood_prisoner_tag=id

static func prisoner_attacked(s:Dictionary,actor) -> void:
	var id:String=actor.special.get("hollywood_prisoner_tag","")
	if id!="095D099C" or s.has("retail_prisoner_jobs"):return
	var jobs:Dictionary={}
	for next in DATA.prisoners[id].enable:jobs[next]=float(DATA.prisoners[next].delay)
	s.retail_prisoner_jobs=jobs

static func prisoners_tick(w,s:Dictionary,dt:float) -> void:
	var jobs:Dictionary=s.get("retail_prisoner_jobs",{})
	for id in jobs.keys():
		jobs[id]=float(jobs[id])-dt
		if jobs[id]>0.0:continue
		jobs.erase(id)
		var row:Dictionary=DATA.prisoners[id]
		if id=="0958149C":
			for u in w.units:
				if w.actor_alive(u) and u.side=="neutral" and u.special.get("hollywood_prisoner_tag")==id:
					u.order_guard()
		elif id=="095D033C":
			var crew:Dictionary=row.team
			var escape:Vector2=w.Hollywood.cell(int(crew.at[0]),int(crew.at[1]))
			for member in crew.members:
				var count:=int(member[0])
				for u in w.units:
					if count<=0:break
					if not w.actor_alive(u) or u.side!="neutral" or u.unit_id!=member[1] or u.special.get("hollywood_prisoner_tag")!="0958149C" or u.special.has("hollywood_prisoner_team"):continue
					u.special.hollywood_prisoner_team=crew.id
					count-=1
					var raw:Vector2=u.position+(u.position-escape).normalized()*260.0
					var goal:Vector2=w.path_service.nearest_reachable(raw,u.position,false,8)
					if goal.is_finite():u.order_move(goal,false,null,w.path_for_unit(u,goal))

static func setup_closure_sites(w) -> void:
	var row:Dictionary=DATA.closure["0EB68F3C"]
	for site in row.sites:
		var tile:=Vector2i(int(site[1]),int(site[2]))
		var point:Vector2=w.Hollywood.retail_site_center(site[0],tile)
		if w.buildings.any(func(b):return w.actor_alive(b) and b.building_id==site[0] and b.position.is_equal_approx(point)):continue
		var b=w._place_building(site[0],"ally",point,true)
		if b!=null:
			b.special.hollywood_house="Americans"
			b.special.hollywood_retail_cell=tile
			b._buildup_play=-1.0

static func closure_tick(w,s:Dictionary,dt:float) -> void:
	var rows:Dictionary=DATA.closure
	var state:Dictionary=s.get_or_add("retail_closure",{})
	var level:=clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)
	for id in ["08D5E88C","08E7FF3C"]:
		if state.has(id):continue
		var row:Dictionary=rows[id]
		var house:String={6:"Arabs",8:"Russians"}[int(row.events[0][2])]
		if (w.buildings+w.units).any(func(a):return w.actor_alive(a) and a.special.get("hollywood_house")==house):continue
		state[id]=true
		# The target triggers have no retail tags on actors; never manufacture a conversion target.
		for next in row.enable:state[next]=true
	for id in ["10A9144C","0EB68F3C"]:
		var row:Dictionary=rows[id]
		if row.disabled or int(row.mask[level])==0 or state.has(id):continue
		var clocks:Dictionary=s.get_or_add("retail_closure_clocks",{})
		clocks[id]=float(clocks.get(id,0.0))+dt
		if float(clocks[id])<float(row.delay):continue
		clocks.erase(id)
		state[id]=true
		for site in row.sites:
			var point:Vector2=w.Hollywood.retail_site_center(site[0],Vector2i(int(site[1]),int(site[2])))
			for b in w.buildings.duplicate():
				if not w.actor_alive(b) or b.building_id!=site[0] or not b.position.is_equal_approx(point):continue
				var owner:String=b.side
				if row.actions.any(func(a):return a[0]=="14"):
					AlliedAbilities.change_side(b,"enemy")
					b.special.hollywood_house="British"
					owner="enemy"
				w.credit_side(owner,float(GameData.ra2_refund(int(b.data.get("cost",0))))+b.total_production_paid())
				b.retire_sold()
				w.buildings.erase(b)
				w._refresh_pathing()
				w._update_power()

static func assembled_team(w,s:Dictionary,rule:Array,members:Array) -> bool:
	if rule[0]!="0BA16EDC":return false
	var row:Dictionary=DATA.closure["0963AA4C"]
	var flag:=str(int(row.events[0][2]))
	if not rule[10].any(func(op):return int(op[0])==39 and str(int(op[1]))==flag):return false
	var flags:Dictionary=s.get_or_add("retail_lifecycle_flags",{})
	flags[flag]=true
	for u in members:
		u.special.hollywood_assembled_trigger=row.id
		u.special.hollywood_quarries=rule[10].filter(func(op):return int(op[0])==0).map(func(op):return int(op[1]))
		load("res://scripts/world/hollywood_bases.gd").attack_next_quarry(w,u)
	for clear in row.clear:flags.erase(str(int(clear)))
	return true

static func neutral_cheer(w,s:Dictionary) -> void:
	var row:Dictionary=DATA.closure["088F344C"]
	if row.actions.is_empty() or int(row.actions[0][0])!=113 or int(row.actions[0][2])!=12:return
	if float(s.get("final_win_elapsed",0.0))<float(row.delay) or s.get("retail_neutral_cheer",false):return
	s.retail_neutral_cheer=true
	for u in w.units:
		if not w.actor_alive(u) or u.side!="neutral" or not u._seq.has("Cheer") or u.has_move_order or u.attack_ordered or u.embarked_in!=null:continue
		u.special.cheer_elapsed=0.0
		u.queue_redraw()

static func live_site(w,side:String,id:String,house:String="") -> bool:
	return w.buildings.any(func(b):return w.actor_alive(b) and b.side==side and b.building_id==id and not b.under_construction and (house.is_empty() or b.special.get("hollywood_house")==house))

static func flags_from(row:Dictionary,flags:Dictionary) -> void:
	for f in row.set:flags[str(int(f))]=true
	for f in row.clear:flags.erase(str(int(f)))

static func latches(w,s:Dictionary,dt:float) -> void:
	var rows:Dictionary=DATA.lifecycle
	var flags:Dictionary=s.get_or_add("retail_lifecycle_flags",{})
	var radar:bool=w.Hollywood.radar_online(w)
	var previous:bool=s.get("retail_radar_for_lifecycle",false)
	s.retail_radar_for_lifecycle=radar
	for pair in [["GAAIRC","0C43BA4C","08D7DCCC","6"],["GASPYSAT","0C43CF3C","08D7D2BC","7"]]:
		var owned:=live_site(w,"ally",pair[0])
		if owned and not flags.has(pair[3]):flags_from(rows[pair[1]],flags)
		elif not owned and flags.has(pair[3]):flags_from(rows[pair[2]],flags)
	if radar:flags["8"]=true
	elif previous:flags.erase("8")
	if not live_site(w,"enemy","YABRCK","Yuri2"):flags_from(rows["095FE79C"],flags)
	var bases:bool=w.buildings.any(func(b):return w.actor_alive(b) and b.side=="enemy" and b.special.get("hollywood_house","") in ["YuriCountry","Yuri2"])
	if not bases:flags_from(rows["0CDDD74C"],flags)
	if not s.plants.has("3"):flags_from(rows["0C89504C"],flags)
	if not radar and s.get("retail_no_radar_hint",0.0)>=0.0 and s.phase==1:
		s.retail_no_radar_hint=float(s.get("retail_no_radar_hint",0.0))+dt
		if s.retail_no_radar_hint>=float(rows["0D18503C"].delay):
			Events.emit_message("任务目标：让四座尤里回收厂停运。")
			s.retail_no_radar_hint=-1.0
			if rows["0D18503C"].enable.has("088703CC"):s.retail_lax_hint=float(rows["088703CC"].delay)
	if live_site(w,"ally","CAAIRP") and DATA.extra["097988CC"].disable.has("097988CC"):
		s.retail_airport_taken=true
	if s.has("retail_lax_hint"):
		if radar or s.get("retail_airport_taken",false):s.erase("retail_lax_hint")
		else:
			s.retail_lax_hint=float(s.retail_lax_hint)-dt
			if s.retail_lax_hint<=0.0:
				s.erase("retail_lax_hint")
				Events.emit_message("占领洛杉矶国际机场，即可获得伞兵支援。")
	if not s.has("retail_yuri2_active"):
		s.retail_yuri2_active=rows["0921C8DC"].enable.has("0463917C")
		s.retail_yuri2_delay=float(rows["0BCF2BEC"].delay)
	if not s.get("retail_yuri2_ready",false):
		s.retail_yuri2_delay=float(s.retail_yuri2_delay)-dt
		if s.retail_yuri2_delay<=0.0:
			flags_from(rows["0BCF2BEC"],flags)
			s.retail_yuri2_ready=true

static func ambience(w,s:Dictionary,dt:float) -> void:
	s.retail_ambient_left=float(s.get("retail_ambient_left",1.0))-dt
	if s.retail_ambient_left>0.0:return
	s.retail_ambient_left=8.0
	var best:=1000.0
	var cue:=""
	var point:=Vector2.ZERO
	for row in DATA.ambience.values():
		if row.id=="0463917C" and not s.get("retail_yuri2_active",false):continue
		for event in row.points:
			var p:Vector2=w.Hollywood.cell(int(event[1]),int(event[2]))
			var d:float=p.distance_to(w.camera.position)
			if d<best and (GameData.has_ra2_sound(event[0]) or CITY_SOUNDS.has(event[0])):best=d;cue=event[0];point=p
	if cue.is_empty():return
	if GameData.has_ra2_sound(cue):Ra2Sfx.play(cue,point);return
	var rule:Dictionary=CITY_SOUNDS[cue]
	var player:=AudioStreamPlayer2D.new()
	player.stream=load("res://assets/ra2/sfx/"+str(rule.files.pick_random())+".wav")
	if player.stream==null:player.free();return
	player.volume_db=linear_to_db(maxf(float(rule.volume)*Ra2Sfx._master_linear,0.0001))
	player.max_distance=float(rule.range)*55.0
	player.pitch_scale=1.0+randf_range(rule.pitch.front(),rule.pitch.back())/100.0
	w.add_child(player)
	player.global_position=point
	player.finished.connect(player.queue_free)
	player.play()

static func special_waves(w,s:Dictionary,dt:float) -> void:
	if not s.get("retail_yuri2_ready",false) or s.get("withdrawals",{}).has("Yuri2") or s.get("retail_lifecycle_flags",{}).has("14"):return
	if s.get("retail_lifecycle_flags",{}).has("13"):
		s.erase("retail_special")
		return
	var rows:Dictionary=DATA.special
	if s.has("retail_special"):
		var old:String=s.retail_special.id
		var alt:String={"0B81A8BC":"045B063C","0B81D9DC":"0B94417C"}.get(old,"")
		if not alt.is_empty() and not w.units.any(func(u):return w.actor_alive(u) and u.side=="enemy" and rows[old].release.has(u.special.get("hollywood_special_team",""))):
			s.retail_special={"id":alt,"left":float(rows[alt].delay)}
	if not s.has("retail_special"):
		s.retail_special={"id":"045B1B5C","left":float(rows["045B1B5C"].delay)}
	var task:Dictionary=s.retail_special
	var row:Dictionary=rows[task.id]
	task.left=float(task.left)-dt
	if float(task.left)>0.0:return
	run_special(w,s,row)
	for id in row.enable:
		if not rows.has(id):continue
		task.id=id;task.left=float(rows[id].delay);return
	s.erase("retail_special")

static func run_special(w,s:Dictionary,row:Dictionary) -> void:
	var released:Array=s.get("retail_special_released",[]) if not row.spawn.is_empty() else []
	if not row.spawn.is_empty():s.erase("retail_special_released")
	released=released.filter(func(u):return w.actor_alive(u) and u.side=="enemy")
	for u in w.units:
		if not w.actor_alive(u) or u.side!="enemy" or not row.release.has(u.special.get("hollywood_special_team","")):continue
		u.special.erase("hollywood_special_team")
		released.append(u)
	if row.spawn.is_empty():s.retail_special_released=released
	for group in row.spawn:
		if group.at==null:continue
		var site:Vector2=w.Hollywood.cell(int(group.at[0]),int(group.at[1]))
		var n:=0
		for member in group.members:
			for _i in int(member[0]):
				var index:=released.find_custom(func(u):return u.unit_id==member[1])
				var u=released.pop_at(index) if index>=0 else w.Hollywood.spawn(w,member[1],"enemy",site+Vector2.RIGHT.rotated(n*2.4)*n*24.0)
				n+=1
				if u==null:continue
				u.special.hollywood_house="Yuri2"
				u.special.hollywood_special_team=group.id
				for step in group.route:u.queue_waypoint(w.Hollywood.cell(int(step[0]),int(step[1])),null,bool(step[2]))

static func cleanup(w,s:Dictionary,dt:float) -> void:
	var rows:Dictionary=DATA.cleanup
	if s.get("retail_cleanup_done",false):return
	if not s.has("retail_cleanup"):
		s.retail_cleanup={"id":"08FEB28C","left":float(rows["08FEB28C"].delay)}
	var task:Dictionary=s.retail_cleanup
	task.left=float(task.left)-dt
	if float(task.left)>0.0:return
	var row:Dictionary=rows[task.id]
	for u in w.units:
		if not w.actor_alive(u) or u.side!="neutral":continue
		if row.retire.has(u.special.get("hollywood_staged_team","")):
			u.special.erase("hollywood_staged_team")
			u.special.erase("hollywood_civilian")
			if not u.special.get("hollywood_rescued",false):s.rescued=int(s.rescued)+1
			u.special.hollywood_rescued=true
			u.display_name="获救的居民"
			u.order_stop(false)
		elif u.special.get("hollywood_rescued",false) and row.types.has(u.unit_id):
			u.special.hollywood_cleanup=true
			u.order_stop(false)
	for id in row.enable:
		if rows.has(id):task.id=id;task.left=float(rows[id].delay);return
	# Two adjacent retail rows have no action-53 edge. The shared release stage
	# runs the next cleanup slice, rather than re-enabling a disabled trigger.
	if row.id=="08FEA69C":
		var tail:Dictionary=rows["08FEDB2C"]
		task.id=tail.id
		task.left=float(tail.delay)
		return
	s.erase("retail_cleanup")
	s.retail_cleanup_done=true
