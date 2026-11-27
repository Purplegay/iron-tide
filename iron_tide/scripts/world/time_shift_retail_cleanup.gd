extends RefCounted
const DATA = preload("res://data/maps/time_shift_fleet.json").data
const RULES = DATA.batch18
const PHASE_LINKS = DATA.phaseLinks

const GRID_TRANSFER = PHASE_LINKS["0C46AB3C"]

# Only the six retail foundations carry this linked Tag. Keeping them out of
# the actor list while in the Jurassic also keeps their power out of that era.
static func archive_grid_plant(w,b) -> bool:
	var cell:Array=GRID_TRANSFER.sites.get(b.building_id,[])
	if cell.is_empty() or b.special.get("time_shift_tag")!=GRID_TRANSFER.sourceTag:return false
	var center:Vector2=w.TimeShift.site_center(b.data,Vector2(cell[0],cell[1])*55.0)
	if not b.position.is_equal_approx(center):return false
	var saved:Dictionary=w.allied_state.time_shift.get_or_add("s01_grid_archive",{})
	saved[b.building_id]={"side":b.side,"hp":b.hp,"repairing":b.repairing,"house":b.special.get("time_shift_native_house","Alliance"),"captured":b.special.get("has_been_captured",false),"yuri_power":b.special.get("yuri_power",false)}
	return true

static func restore_grid_plants(w) -> void:
	var s:Dictionary=w.allied_state.time_shift
	var saved:Dictionary=s.get("s01_grid_archive",{})
	for id in saved:
		var cell:Array=GRID_TRANSFER.sites[id]
		var row:Dictionary=saved[id]
		var b=w.TimeShift.place(w,id,row.side,Vector2(cell[0],cell[1])*55.0,GRID_TRANSFER.sourceTag)
		if b==null:continue
		b.hp=row.hp
		b.repairing=row.repairing
		b.special.time_shift_native_house=row.house
		b.special.has_been_captured=row.captured
		b.special.yuri_power=row.yuri_power
		b.special.s01_grid_transfer_target=true
		b.refresh_house_color()
	s.erase("s01_grid_archive")

static func advance_grid_transfer(w,s:Dictionary,delta:float) -> void:
	if not s.has("s01_grid_transfer_left"):return
	s.s01_grid_transfer_left=float(s.s01_grid_transfer_left)-delta
	if s.s01_grid_transfer_left>0.000001:return
	s.erase("s01_grid_transfer_left")
	var changed:=false
	for b in w.buildings:
		if not w.actor_alive(b) or not b.special.erase("s01_grid_transfer_target"):continue
		b.special.time_shift_native_house=GRID_TRANSFER.house
		b.special.erase("yuri_power")
		AlliedAbilities.change_side(b,"enemy",false)
		b.refresh_house_color()
		changed=true
	if changed:AlliedAbilities.refresh_after_side_changes(w)

static func landing_team(w,slot:Dictionary,key:String) -> void:
	var id:="087D15EC"
	if slot.get("replacement",false):id="082B933C" if key=="55" else "082B950C"
	elif key!="55":return
	var row:Dictionary=PHASE_LINKS[id]
	for crew in row.teams:
		for member in crew.members:
			var count:=int(member[0])
			for u in slot.get("members",[]):
				if count<=0:break
				if not w.actor_alive(u) or u.side!="ally" or u.embarked_in!=null or u.unit_id!=member[1]:continue
				count-=1
				u.special.s01_retail_landing_team=id
				# Retail's assignment/flash must not cancel a player's post-unload order.
				if id!="087D15EC":Events.emit_radar_ping(u.position,"campaign_discovery")
				elif not u.has_move_order and not u.attack_ordered and u.order_queue.is_empty():u.order_guard()

static func queue_phase(s:Dictionary,id:String) -> void:
	var jobs:Dictionary=s.get_or_add("s01_phase_links",{})
	if not jobs.has(id):jobs[id]={"phase":s.phase,"at":float(s.elapsed)+float(PHASE_LINKS[id].delay)}

static func phase_tick(w,s:Dictionary) -> void:
	var jobs:Dictionary=s.get("s01_phase_links",{})
	for id in jobs.keys():
		var job:Dictionary=jobs[id]
		if job.phase!=s.phase:jobs.erase(id);continue
		if float(s.elapsed)<float(job.at):continue
		if id=="07F2978C" and not s.get("s01_opening_squid2_lost",false):continue
		jobs.erase(id)
		phase_apply(w,s,id)

static func phase_apply(w,s:Dictionary,id:String) -> void:
	var row:Dictionary=PHASE_LINKS[id]
	match id:
		"096879AC":
			# House 6's old-era troops do not cross. Keep third-party houses and the player intact.
			for u in w.units.duplicate():
				if w.actor_alive(u) and u.side=="enemy" and u.special.get("time_shift_native_house")=="Arabs":AlliedAbilities.consume(u)
		"09601D2C":
			var old_machine=s.get("machine")
			if w.actor_alive(old_machine) and old_machine.building_id=="CATIME01":
				# The linked retail tag identifies the outgoing machine; the incoming CATIME02 stays playable.
				old_machine.special.time_shift_native_house="Soviet2House"
				AlliedAbilities.change_side(old_machine,"neutral")
			s.s01_first_machine_returned=true
		"0CAAF7DC":
			var machine=s.get("machine")
			if w.actor_alive(machine) and row.targets.has(machine.building_id):
				machine.special.time_shift_native_house="Soviet2House"
				AlliedAbilities.change_side(machine,"ally")
		"07F2978C":
			s.s01_return_friendship_check=true
			# Any surviving American actors after the era replacement are noncombatants here.
			for a in w.units+w.buildings:
				if w.actor_alive(a) and a.side=="enemy" and a.special.get("time_shift_native_house")=="Americans":AlliedAbilities.change_side(a,"neutral")
		"0937687C":
			for cell in row.pings:
				var point:=Vector2(190-int(cell[1])+0.5,int(cell[0])-10+0.5)*55.0
				w.fog.reshroud_at("ally",point,165.0)
		"078C97EC":
			# This root has no retail actor references; only carry its timed successor.
			pass
		"079BB93C":
			for b in w.buildings:
				if not w.actor_alive(b) or not row.targets.has(b.building_id):continue
				b.special.time_shift_native_house="Neutral"
				if b.side!="neutral":AlliedAbilities.change_side(b,"neutral")
		"097651DC":
			if w.units.any(func(u):return w.actor_alive(u) and u.side=="ally" and u.unit_id=="BORIS"):
				var jobs:Dictionary=s.get("s01_cleanup_jobs",{})
				jobs.erase("0439F14C")
				s.s01_boris_replacement_disabled=true
	for next in row.enable:
		if PHASE_LINKS.has(next):queue_phase(s,next)

static func queue(s:Dictionary,id:String) -> void:
	var jobs:Dictionary=s.get_or_add("s01_cleanup_jobs",{})
	if not jobs.has(id):jobs[id]={"phase":s.phase,"at":float(s.elapsed)+float(RULES[id].delay)}

static func tick(w,s:Dictionary) -> void:
	var jobs:Dictionary=s.get("s01_cleanup_jobs",{})
	for id in jobs.keys():
		var job:Dictionary=jobs[id]
		if job.phase!=s.phase:jobs.erase(id);continue
		if float(s.elapsed)<float(job.at):continue
		jobs.erase(id)
		apply(w,s,id)

static func apply(w,s:Dictionary,id:String) -> void:
	var r:Dictionary=RULES[id]
	if r.camera!=null:w.center_on(w.TimeShift.wp(int(r.camera)))
	if not str(r.cue).is_empty():
		if id=="07EF508C":w.TimeShift.voice(w,r.cue)
		else:w.TimeShift.Story.once(w,r.cue)
	match id:
		"0E626A2C":
			for b in w.buildings:
				if w.actor_alive(b) and b.special.get("time_shift_tag")=="SP3.5a_Evict Occupiers":preload("res://scripts/units/civilian_orders.gd").evacuate(b)
		"06B5FB2C","06B5F54C","0C55D39C":
			var type:String={"06B5FB2C":"CATHOSP","06B5F54C":"CAMACH","0C55D39C":"NADEPT"}[id]
			for b in w.buildings:
				if w.actor_alive(b) and b.building_id==type and b.side=="ally":AlliedAbilities.change_side(b,"neutral")
		"0961762C":
			for b in w.buildings.duplicate():
				if w.actor_alive(b) and b.building_id=="YAPPET" and b.side=="enemy":b._die(null,true)
		"05BF138C":
			if w.actor_alive(s.get("machine")):AlliedAbilities.change_side(s.machine,"ally")
		"0439F14C":
			if s.get("s01_boris_replacement_disabled",false):return
			if not w.units.any(func(u):return w.actor_alive(u) and u.side=="ally" and u.unit_id=="BORIS"):
				var t:Dictionary=r.teams[0]
				if w.spawn_unit(t.members[0][1],"ally",w.TimeShift.wp(int(t.at)))!=null:apply(w,s,"0439CF3C")
		"07EF508C":Events.emit_message("目标完成：已接管苏军基地。")
		"04415AFC":
			for b in w.buildings:
				if w.actor_alive(b) and b.building_id in ["CASANF11","CASANF04","CASANF12","CASANF13","CASANF14"]:preload("res://scripts/units/civilian_orders.gd").evacuate(b)
		"05DB7F3C":
			var boat=s.get("s01_flak_boat")
			if w.actor_alive(boat) and boat.logistics.passengers.is_empty():
				var target:Vector2=w.TimeShift.wp(23)
				boat.order_move(target,false,null,w.path_for_unit(boat,target))
	for next in r.enable:
		if RULES.has(next):queue(s,next)
		elif id=="0439CF3C" and w.TimeShift.Story.FLEET.media.has(next):w.TimeShift.Story.queue_media(s,next)
