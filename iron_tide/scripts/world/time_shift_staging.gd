extends RefCounted
const DATA = preload("res://data/maps/time_shift_fleet.json").data
const ROWS = DATA.staging
const TEXT := {"MISSION:Sov1Obj1":"任务目标：消灭港口舰队和岸防。","MISSION:Sov1Obj2":"任务目标：夺取盟军的时光机。","MISSION:ObjCompleteSov04md":"目标完成：苏军基地已接管。","MISSION:HintDom":"摧毁恶魔岛上的心灵控制器。","MISSION:YGotPowr":"尤里已经获得足够电力。"}

static func queue(s:Dictionary,id:String) -> void:
	var jobs:Dictionary=s.get_or_add("s01_staging_jobs",{})
	if not jobs.has(id):jobs[id]={"phase":s.phase,"due":float(s.elapsed)+float((DATA.encounter[id] if DATA.encounter.has(id) else ROWS[id]).delay)}

static func tick(w,s:Dictionary) -> void:
	for unit in w.units.duplicate():
		if w.actor_alive(unit) and unit.special.has("s01_flyby") and (s.phase!=0 or (not unit.has_move_order and unit.order_queue.is_empty())):AlliedAbilities.consume(unit)
	var jobs:Dictionary=s.get("s01_staging_jobs",{})
	for id in jobs.keys():
		var job:Dictionary=jobs[id]
		if job.phase!=s.phase:jobs.erase(id);continue
		if s.elapsed<job.due:continue
		jobs.erase(id)
		run(w,s,id)

static func run(w,s:Dictionary,id:String,follow:=true) -> void:
	if DATA.encounter.has(id):
		assign_encounter(w,s,DATA.encounter[id])
		return
	var r:Dictionary=ROWS[id]
	var jobs:Dictionary=s.get_or_add("s01_staging_jobs",{})
	for target in r.disable:jobs.erase(target)
	if w.fog!=null:
		for wp in r.reveal:w.fog._reveal("ally",w.TimeShift.wp(int(wp)),180.0,3.0)
	if r.camera!=null:w.center_on(w.TimeShift.wp(int(r.camera)))
	for wp in r.pings:Events.emit_radar_ping(w.TimeShift.wp(int(wp)),"campaign_site")
	if not str(r.cue).is_empty() and w.TimeShift.ASSETS.data.voices.has(r.cue):w.TimeShift.Story.once(w,r.cue)
	if not str(r.sound).is_empty() and GameData.has_ra2_sound(r.sound):Ra2Sfx.play(r.sound)
	if TEXT.has(r.text):Events.emit_message(TEXT[r.text])
	for fly in r.fly:
		for member in fly.members:
			for _i in int(member[0]):
				var unit=w.spawn_unit(member[1],"enemy",w.TimeShift.wp(int(fly.at)))
				if unit==null:continue
				unit.set_fire_stance("none")
				unit.special.s01_flyby=true
				for wp in fly.route:unit.queue_waypoint(w.TimeShift.wp(int(wp)))
	if id=="0D9BA16C" or id=="094A989C":w.hud.minimap.clear_objective_flashes()
	for next in r.enable:
		if next in ["0E626A2C","05BF138C","0961762C","06B5FB2C"]:w.TimeShift.Cleanup.queue(s,next)
		if next in ["096879AC","07F2978C","0937687C"]:w.TimeShift.Cleanup.queue_phase(s,next)
	if id=="0C4A628C" or id=="0C57BA6C" or id=="07FA53DC":
		var disabled:Dictionary=s.get_or_add("s01_closed_triggers",{})
		for target in r.disable:disabled[target]=true
		stop_retired(s,disabled)
	if id=="0951A4BC" and not r.move.is_empty():w.center_on(w.TimeShift.wp(int(r.move[0])))
	if id in ["07EF43CC","0962D87C"] and s.get("base_found",false):queue(s,"0970A22C")
	if follow:
		for next in r.enable:
			if ROWS.has(next) or DATA.encounter.has(next):queue(s,next)

static func assign_encounter(w,s:Dictionary,row:Dictionary) -> void:
	var fired:Dictionary=s.get_or_add("s01_encounters",{})
	if fired.has(row.id):return
	fired[row.id]=true
	for member in row.members:
		var count:=int(member[0])
		for u in w.units:
			if count<=0:break
			if not w.actor_alive(u) or u.unit_id!=str(member[1]):continue
			if row.house=="Americans" and (u.side!="enemy" or u.special.get("time_shift_native_house","Americans" if u.special.get("time_shift_tag")=="SP2.1_Destroy_AlliedDef" else "")!=row.house):continue
			if row.house=="Russians" and u.side!="ally":continue
			count-=1
			u.special.s01_encounter=row.id
			var command:Array=row.commands[0]
			var raw:Vector2=w.TimeShift.wp(int(command[1]))
			if row.id=="0D17008C" and u.embarked_in!=null:continue # Landing transport still owns the unload order.
			var goal:Vector2=w.path_service.nearest_reachable(raw,u.position,u.is_naval,14)
			if goal.is_finite():u.order_move(goal,int(command[0])==1,null,w.path_for_unit(u,goal))

static func stop_retired(s:Dictionary,disabled:Dictionary) -> void:
	for pair in [["043DF33C","power_raid_pings"],["0DD0203C","engineer_rescue_due"],["09FF490C","engineer_rescue_arrival_due"],["082C44AC","landing_backup"],["082C467C","landing_backup"]]:
		if disabled.has(pair[0]):s.erase(pair[1])
	var tasks:Dictionary=s.get("retail_media_due",{})
	for id in tasks.keys():
		if disabled.has(id):tasks.erase(id)

static func opening(w,s:Dictionary) -> void:
	for id in ["094D21AC","09533A5C","0C331D8C","088BEB4C"]:run(w,s,id,false)
	queue(s,"094B2A9C")
	queue(s,"088966DC")
	queue(s,"0BBEFE3C")

static func crossing(w,s:Dictionary,era:int) -> void:
	if era==1:
		run(w,s,"0951740C",false)
		run(w,s,"0BDE287C",false)
	else:
		run(w,s,"0BDC985C",false)
		var root:Dictionary=ROWS["0BDCDD0C"]
		if ROWS["0BDC985C"].enable.has(root.id) and root.enable.has("0C46AB3C"):
			s.s01_grid_transfer_left=float(root.delay)+float(DATA.phaseLinks["0C46AB3C"].delay)
		if root.enable.has("0937049C"):
			var stage:Dictionary=ROWS["0937049C"]
			s.s01_return_setup=stage.enable.has("0439097C")
			s.s01_return_camera=stage.enable.has("0BDCD47C")
			s.s01_return_reveal=stage.enable.has("044286FC")

static func after_crossing(w,s:Dictionary,era:int) -> void:
	if era==1:
		run(w,s,"0951A4BC",false)
		run(w,s,"0952ED0C",false)
		queue(s,"0999579C")
		queue(s,"0C4A628C")
	else:
		if s.get("s01_return_camera",true):run(w,s,"0BDCD47C",false)
		if s.get("s01_return_reveal",true):run(w,s,"044286FC")
