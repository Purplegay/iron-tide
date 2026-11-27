extends "res://scripts/world/allied_retail_script.gd"
## ALL01UMD power / time-machine adapter. The camera and the final timer run in parallel.
const Transition = preload("res://scripts/world/allied_first_transition.gd")
const CANNON_TAGS := {"08d5f24c":"08a9aacc","08d5de6c":"08a9a9ec","08d5db4c":"08a9a90c","08d5d82c":"08a9a82c"}
const REBUILD_CANNONS := ["08d5d50c","08d5d1ec","08d5bd9c","08d5ba7c"]
const CONNECTOR := "07a8917c"
const CENTER := "0835813c"
const GONE := "0930139c"
const EVICT := "089ae11c"
const REBUILD := "0930470c"
const ARRIVAL := "05e9106c"
const KIROV := "0790df3c"
const ONLINE := "0691357c"
const RADAR := "0be0b26c"
const OBJECTIVE := "09515b9c"
const START_TIMER := "0a8e573c"
const MOVIE := "0a8ea21c"
const CAMERA := "0c6f847c"
const DONE := "0a8e0e9c"
const BOOM := "08a3e03c"
const LATE_LOSS := "08707a2c"

var field_rows_active := false

func _internal(action: Array) -> bool:
	if action[0] in ["53","54"] and definition.field_rows.has(str(action[2]).to_lower()):
		if action[2]!="0993F7BC" or not field_rows_active: return false
	return super._internal(action)

func initialize(world, s: Dictionary) -> bool:
	field_rows_active=s.get("map_field_rows",false)
	Transition.bind_sites(world)
	if s.has("retail_power_sequence"):
		if not restore(s.retail_power_sequence): return false
		upgrade_transition(world,s)
		return true
	if not start("yr_all01umd",clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)): return false
	state.enabled.clear()
	enable(BOOM)
	enable(LATE_LOSS)
	if s.get("machine_failure_left",-1.0)>=0 and world.AlliedFirst.site(world,"CATIME01")==null:
		state.fired[BOOM] = true # The legacy loss notification already played.
	if s.phase in [1,2]:
		for row in definition.triggers:
			if row.name.begins_with("Player_Has_Plant"): enable(row.id)
		if s.get("power_sequence_new",false) and not s.get("map_assault_rows",false): enable("06cbe3fc")
		if not s.get("map_assault_rows",false): enable(ONLINE) # open_orders is the current camera/control handoff.
		if not s.has("power_sequence_new"): state.time = 5.0
	if s.phase==2 and s.has("charge"):
		# Previous saves already dispatched the engineer, transferred radar and announced power.
		state.enabled.clear()
		enable(BOOM)
		enable(LATE_LOSS)
		set_local(47,true)
		set_local(49,true)
		state.fired[ONLINE] = true
		state.fired[RADAR] = true
		state.fired[OBJECTIVE] = true
		var total := duration()
		var left := maxf(0.0,float(s.charge))
		s.power_legacy_wait = maxf(0.0,left-total)
		var elapsed := maxf(0.0,total-left)
		state.time = elapsed
		var movie_at := delay(START_TIMER)
		var fork_at := movie_at+delay(MOVIE)
		for entry in [[START_TIMER,0.0],[MOVIE,movie_at],[CAMERA,fork_at],[DONE,fork_at]]:
			var id: String = entry[0]
			var at: float = entry[1]
			if elapsed < at: continue
			if elapsed >= at+delay(id) and id!=DONE: state.fired[id] = true
			else: state.enabled[id] = at
		s.power_camera_lock = state.fired.has(CAMERA)
	upgrade_transition(world,s)
	return true

func upgrade_transition(world,s: Dictionary) -> void:
	if not s.get("cannon_rows_ready",false) and not s.get("crossing_swapped",false):
		for id in CANNON_TAGS:
			enable(id)
			if not world.buildings.any(func(b):return world.actor_alive(b) and b.special.get("allied_first_tag","")==CANNON_TAGS[id]):
				s.get_or_add("fallen_cannon_tags",{})[CANNON_TAGS[id]] = true
		s.cannon_rows_ready = true
	if s.get("bridge_house_restored",false) and not s.get("retail_bridge_rows",false):
		if not s.get("bridge_connector_fallen",false): enable(CONNECTOR)
		enable(CENTER)
		s.retail_bridge_rows = true
		for id in [CONNECTOR,CENTER]: s.get("power_external_links",{}).erase(id)
	if s.get("power_external_links",{}).get(KIROV,false):
		enable(KIROV)
		s.power_external_links.erase(KIROV)
	if s.get("transition_rows_ready",false): return
	s.transition_rows_ready = true
	if s.phase<=2 or (s.phase==3 and not s.get("crossing_swapped",false)):
		enable(GONE)
		if not s.get("original_reactor_registered",false) and world.AlliedFirst.site(world,"NANRCT")==null:
			s.retail_reactor_destroyed = true # Legacy pre-warp save lacks a death latch.
		s.original_reactor_registered = true
	if s.phase==3:
		if s.get("crossing_swapped",false):
			# Old midpoint already committed the room changes, evacuation and rebuild.
			enable(ARRIVAL)
			s.transition_swap_clock = state.time - maxf(0.0,float(s.crossing_time)-world.TimeShift.CROSSING_DURATION*0.5)
		else:
			enable(EVICT)
			enable(REBUILD)
		var links: Dictionary = s.get("power_external_links",{})
		links.erase(EVICT)
		links.erase(REBUILD)
		s.power_external_links = links

func delay(id: String) -> float:
	return float(rows[id].events[0][2])

func duration() -> float:
	return delay(START_TIMER)+delay(MOVIE)+delay(DONE)

func step(world, s: Dictionary, delta: float) -> void:
	for id in s.get("assault_power_links",{}): enable(id)
	s.erase("assault_power_links")
	if s.get("power_movie_pending",false): return
	var mission = world.AlliedFirst
	var machine = mission.site(world,"CATIME01")
	var present: bool = int(s.phase)<=2
	var past: bool = s.get("crossing_swapped",false) or int(s.phase)>=4
	var viable: bool = present and machine!=null and machine.side=="ally"
	var ready: bool = viable and mission.grid_ready(world)
	set_local(3,past)
	if past and not s.get("awaiting_tanya",true): state.enabled.erase(LATE_LOSS)
	var query := func(row: Dictionary,event: Array) -> bool:
		match int(event[0]):
			32:
				var plant = mission.site(world,"CAPOWR%02d" % (int(event[2])-401))
				return plant!=null and plant.side=="ally"
			58: return ready
			48:
				if CANNON_TAGS.has(row.id): return s.get("fallen_cannon_tags",{}).has(CANNON_TAGS[row.id])
				if row.id==GONE: return s.get("retail_reactor_destroyed",false)
				return s.get("machine_death_era",-1)==(1 if row.id==LATE_LOSS else 0)
			61:
				if row.id in [CONNECTOR,CENTER]: return mission.site(world,event[3])==null
				return event[3] in ["TANY","APOC"] and not world.units.any(func(u):return world.actor_alive(u) and u.unit_id==event[3])
		return false
	var remaining := maxf(0.0,delta)
	if present and (not viable or (s.phase==2 and not ready)): remaining = 0.0
	if s.get("power_legacy_wait",0.0)>0:
		var held := minf(remaining,s.power_legacy_wait)
		s.power_legacy_wait -= held
		remaining -= held
	var power_at_start: bool = state.fired.has(ONLINE)
	var advance_by := 0.0
	while true:
		var command := advance(advance_by,query)
		if s.get("map_closing_rows",false) and int(s.phase)==3 and advance_by>0.0:
			var closing=mission.closing_driver(world,s)
			if closing!=null: closing.run(world,s,advance_by)
			if command.is_empty(): command=advance(0.0,query)
		if not s.get("map_closing_rows",false) and s.has("transition_swap_clock") and not s.get("apocs_sent",true) and float(state.time)-float(s.transition_swap_clock)>=1.0:
			for id in mission.Armor.APOCS: enable(id)
			s.apocs_sent = true
			if command.is_empty(): command = advance(0.0,query)
		while not command.is_empty():
			if not execute(world,s,machine,command):
				push_error("ALL01UMD unsupported power action: "+str(command))
				return
			acknowledge(command.token)
			command = advance(0.0,query)
		if s.has("power_reminder_at") and not state.fired.has(CAMERA) and present and state.fired.has("06cbe3fc"):
			state.fired.erase("06cbe3fc")
			state.enabled["06cbe3fc"] = s.power_reminder_at
		if state.fired.has(ONLINE) and not power_at_start:
			power_at_start = true
			s.power_online_at = state.time
		if remaining<=0.0 or (present and int(s.phase)>=3) or world.ended or s.get("power_movie_pending",false): break
		advance_by = remaining
		if s.has("transition_swap_clock") and not s.get("apocs_sent",true):
			var until_create := 1.0+float(s.transition_swap_clock)-float(state.time)
			if until_create>0: advance_by=minf(advance_by,until_create)
		for id in state.enabled:
			if state.fired.has(id): continue
			for event in rows[id].events:
				if event[0]!="13": continue
				var until_due := float(state.enabled[id])+float(event[2])-float(state.time)
				if until_due>0.0: advance_by = minf(advance_by,until_due)
		remaining = maxf(0.0,remaining-advance_by)
	if s.phase==2 and s.has("charge"):
		s.charge = maxf(0.0,duration()-(float(state.time)-float(s.get("power_online_at",0.0))))+float(s.get("power_legacy_wait",0.0))
	s.retail_power_sequence = state

func execute(world,s: Dictionary,machine,cmd: Dictionary) -> bool:
	var mission = world.AlliedFirst
	var arg: String = cmd.fields[2]
	match int(cmd.opcode):
		7:
			if arg!="0DC53EFC": return false
			mission.dispatch_reactor_engineer(world,s)
		63:
			Transition.damage_at_waypoint(world,int(arg))
			if cmd.trigger==CONNECTOR: s.bridge_connector_fallen = true
		80: return mission.Armor.spawn_team(world,self,cmd)
		14:
			var radar = mission.site(world,"GASPYSAT")
			if radar!=null:
				if radar.side!="ally": mission.Orders.change_side(radar,"ally")
				radar.special.allied_first_radar_online = true
		16:
			if world.fog!=null:
				world.fog.explored_cells.ally.fill(1)
				world.fog.rebuild()
			mission.begin_charge(world,s,machine,duration())
		19: Ra2Sfx.play(arg)
		11:
			if cmd.trigger=="06cbe3fc":
				mission.speech(world,"伊娃","任务目标：占领发电厂，为时光机恢复供电。")
				s.power_reminder_at = state.time
			else: mission.speech(world,"伊娃","目标一完成：时光机已恢复供电。")
		117:
			if int(arg)!=3: return false
			s.power_movie_pending = true
			mission.resume_media(world)
		46:
			s.power_camera_lock = true
			world.cancel_pointer_gestures()
		48:
			if cmd.trigger!=CAMERA or cmd.fields[7]!="BF": return false
			world.center_on(mission.wp(57))
		47: s.power_camera_lock = false
		127: mission.begin_crossing(world,s,machine)
		139: world.hud.minimap.clear_radar_events()
		68: mission.speech(world,"伊娃","时光机已被摧毁，无法改变历史。")
		2:
			if cmd.trigger!=LATE_LOSS: return false
			s.failure_trigger = LATE_LOSS.to_upper()
			world.end_battle(false)
		111: Transition.evict(world,rows[cmd.trigger].tags)
		119,120,121,122:
			Transition.remove_room_assets(world,definition.houses[arg],int(cmd.opcode))
		125: return Transition.rebuild(world,resolve_spawn(cmd))
		130:
			if definition.houses[arg]!="BridgeHouse": return false
			mission.restore_bridge_house(world,s)
		100:
			if cmd.trigger!=ARRIVAL or arg!="4": return false
			s.past_clip = "A01_P03E"
			s.past_report = true
			if s.phase==4: mission.resume_media.call_deferred(world)
		53,54:
			if cmd.opcode==53 and arg.to_lower()=="085159ec":
				# The existing past-world adapter owns Fix_Buildings and its downstream setup.
				if not s.get("crossing_swapped",false):
					if not s.get("map_closing_rows",false):
						for id in REBUILD_CANNONS: enable(id)
					mission.enter_past(world,s)
					s.retail_bridge_rows = true
					set_local(3,true)
					s.transition_swap_clock = state.time
					if s.get("map_closing_rows",false):
						var closing=mission.closing_driver(world,s)
						closing.enable(closing.FIX)
						closing.run(world,s,0.0)
				return true
			var links: Dictionary = s.get("power_external_links",{})
			links[arg.to_lower()] = cmd.opcode==53
			s.power_external_links = links
		_: return false
	return true
