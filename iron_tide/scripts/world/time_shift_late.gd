extends RefCounted
const ROWS = preload("res://data/maps/time_shift_fleet.json").data.late
const BRIDGE_IDS := {90:"CASANF09",91:"CASANF10",92:"CASANF11",93:"CASANF04",94:"CASANF12",95:"CASANF13",96:"CASANF14"}
const DETECT := ["0441418C","0441409C","04415F3C","04415E4C","04415D5C"]
const GUARDIAN := ["09198F3C","09198B9C","09198D6C","0919965C","09199BCC","0919948C","0919982C","091999FC","09199D9C"]

static func schedule(s:Dictionary,id:String) -> void:
	var due:Dictionary=s.get_or_add("s01_late_due",{})
	if not due.has(id):due[id]={"time":float(s.elapsed)+float(ROWS[id].delay),"phase":int(s.phase)}

static func tick(w,s:Dictionary) -> void:
	var due:Dictionary=s.get("s01_late_due",{})
	for id in due.keys():
		var job:Dictionary=due[id]
		if int(job.phase)!=int(s.phase):due.erase(id);continue
		if float(s.elapsed)<float(job.time):continue
		due.erase(id)
		apply(w,s,id)
	if s.phase in [1,2] and not s.has("s01_guardian_closed") and not s.has("s01_guardian_seen"):
		for id in GUARDIAN:
			var p:Vector2=w.TimeShift.wp(int(ROWS[id].camera))
			if not w.units.any(func(u):return w.actor_alive(u) and u.unit_id=="GGI" and u.side=="enemy" and u.position.distance_to(p)<260.0 and w.actor_visible_to("ally",u)):continue
			s.s01_guardian_seen=id
			apply(w,s,id)
			if not due.has("091992BC"):schedule(s,"091992BC")
			break

static func acquire_machine(w,s:Dictionary) -> void:
	if not s.has("s01_machine_takeover_due"):
		if not ROWS["094A4E1C"].enable.has("0DECD98C"):return
		s.s01_machine_takeover_due=float(s.elapsed)+float(ROWS["0DECD98C"].delay)
		return
	if float(s.elapsed)<float(s.s01_machine_takeover_due):return
	s.erase("s01_machine_takeover_due")
	AlliedAbilities.change_side(s.machine,"ally")
	s.phase=2
	w.TimeShift.announce_radar_objectives(w)
	s.power_elapsed=0.0
	s.engineer_initial_sent=false
	if ROWS["094A4E1C"].enable.has("07EF7AEC"):schedule(s,"07EF7AEC")

static func start_island_objective(s:Dictionary,level:int) -> void:
	var event:Dictionary=ROWS["0439F31C" if s.get("boris_lost",false) else "0443FBCC"]
	if event.enable.has("0443F8AC"):schedule(s,"0443F8AC")
	elif event.enable.has("0443F6DC"):schedule(s,"0443F6DC")
	s.s01_island_difficulty=clampi(level,0,2)

static func apply(w,s:Dictionary,id:String) -> void:
	var row:Dictionary=ROWS[id]
	if not str(row.cue).is_empty():
		if id=="07EF7AEC":w.TimeShift.voice(w,row.cue)
		else:w.TimeShift.Story.once(w,row.cue)
	if row.camera!=null:w.center_on(w.TimeShift.wp(int(row.camera)))
	for wp in row.ping:Events.emit_radar_ping(w.TimeShift.wp(int(wp)),"campaign_discovery")
	for wp in row.reveal:w.fog._reveal("ally",w.TimeShift.wp(int(wp)),180.0,3.0)
	var text:String={"MISSION:Obj2Comp":"目标完成：已夺取时光机。","MISSION:Sov1Obj4":"任务目标：找到并接管苏军基地。","MISSION:Sov1Obj6":"继续搜索苏军基地，建立进攻阵地。","MISSION:Sov1Obj7":"任务目标：摧毁恶魔岛上的心灵控制器。","MISSION:TranHint":"让鲍里斯搭乘两栖运输艇前往恶魔岛。","MISSION:RexyFrnd":"获救的霸王龙加入了你的部队。"}.get(row.text,"")
	if not text.is_empty():Events.emit_message(text)
	if id=="091992BC":s.s01_guardian_closed=row.disable.duplicate()
	if id=="0443F6DC":
		var selected:String=["07A255BC","043EC4DC","07A256AC"][int(s.get("s01_island_difficulty",1))]
		if row.enable.has(selected):schedule(s,selected)
	else:
		for next in row.enable:
			if ROWS.has(next):schedule(s,next)

static func bridge(w,s:Dictionary,parts:Dictionary) -> void:
	if not s.has("bridge_return"):
		s.bridge_return=true
		s.bridge_damage_left=float(ROWS["07A5F24C"].delay)
	if s.has("bridge_damage_left"):
		s.bridge_damage_left=float(s.bridge_damage_left)-float(s.get("s01_bridge_elapsed",0.4))
		if float(s.bridge_damage_left)<=0.0:
			s.erase("bridge_damage_left")
			for id in ROWS["07A5F24C"].enable:
				for slot in ROWS[id].hit:
					var part=parts.get(BRIDGE_IDS.get(int(slot),""))
					if w.actor_alive(part):part.receive_hit(100000 if id=="0441436C" else part.max_hp*0.25)
	if s.get("bridge_fallen",false):return
	for id in DETECT:
		if parts.has(ROWS[id].target):continue
		if not s.has("bridge_collapse_plan"):
			s.bridge_collapse_plan={"id":id,"left":float(ROWS[ROWS[id].enable[0]].delay)}
			return
		var plan:Dictionary=s.bridge_collapse_plan
		plan.left=float(plan.left)-float(s.get("s01_bridge_elapsed",0.4))
		if plan.left>0.0:return
		for branch in ROWS[plan.id].enable:
			for slot in ROWS[branch].hit:
				var part=parts.get(BRIDGE_IDS.get(int(slot),""))
				if w.actor_alive(part):part.receive_hit(100000)
		s.bridge_fallen=true
		s.erase("bridge_collapse_plan")
		w.TimeShift.Cleanup.apply(w,s,"044149EC")
		w.TimeShift.Cleanup.phase_apply(w,s,"078C97EC")
		Events.emit_message("金门大桥的桥段接连坍塌。")
		return

static func return_city(w) -> void:
	for spec in ROWS["0B63FB2C"].buildings:
		var p:Vector2=w.TimeShift.wp(int(spec[1]))
		# The defensive guns already exist in the return-era setup; avoid duplicates.
		if not w.buildings.any(func(b):return w.actor_alive(b) and b.building_id==spec[0] and b.position.distance_to(p)<110.0):w.TimeShift.place(w,spec[0],"enemy",p)
	for spec in ROWS["0B63F5EC"].buildings:
		w.TimeShift.place(w,spec[0],"neutral",w.TimeShift.wp(int(spec[1])))
	for id in ["0905A37C","0905A54C","0905A89C","0905B51C","090D21BC"]:
		if not ROWS["0B63FB2C"].enable.has(id):continue
		for group in ROWS[id].teams:
			var site:Vector2=w.TimeShift.wp(int(group.at))
			var index:=0
			for row in group.members:
				for _i in int(row[0]):
					var u=w.spawn_unit(row[1],"enemy" if id=="090D21BC" else "neutral",site+Vector2(index*20,0))
					index+=1
					if u==null:continue
					u.special.s01_return_trigger=id
					if u.side=="neutral":u.set_fire_stance("none")
					for wp in group.route:u.queue_waypoint(w.TimeShift.wp(int(wp)))
