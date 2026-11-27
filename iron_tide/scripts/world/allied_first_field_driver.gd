extends "res://scripts/world/allied_retail_script.gd"
const Teams=preload("res://scripts/world/allied_first_field_teams.gd")
const PEOPLE := "08a6340c"
const KILL_SOUNDS := "04c23c0c"
const APOCS := "0ac8355c"
const ENTER := "0ac85f3c"
const DEATH := "089b82bc"
const ENGINEERS := "08e568dc"
const ARRIVED := "090ab04c"
const CARRIERS := "089b1ccc"
const PING := "0898812c"
const FLEET_LOST := "0792b79c"
var ambience=preload("res://scripts/world/allied_first_ambience.gd").new()
var cell_rows := {}
var entered := {}
var poll_left := 0.0

func initialize(s: Dictionary,level: int) -> bool:
	var saved: bool=s.has("retail_field")
	if saved:
		if not restore(s.retail_field): return false
	elif not start("yr_all01umd",level): return false
	else: state.enabled.clear()
	for id in rows.keys():
		if not definition.field_rows.has(id) or id=="0993f7bc": rows.erase(id)
	# Only scan this adapter's rows on each simulation step. Keep the shared source immutable.
	definition=definition.duplicate(false)
	definition.triggers=rows.values()
	for id in definition.field_cells:
		for cell in definition.field_cells[id]:
			cell_rows.get_or_add(int(cell),[]).append(id)
	if not saved:
		var past: bool=s.get("crossing_swapped",false) or int(s.phase)>=4
		if not past:
			for row in rows.values():
				if not row.disabled: enable(row.id)
			if not s.get("map_assault_rows",false): enable("097d15dc")
			if s.get("hospital_found",false): state.enabled.erase("0462b74c")
		else:
			if s.get("past_harbor_sent",false): enable("04c2263c")
			if s.get("followup_fleet_sent",false) and s.get("retail_city",{}).get("fired",{}).has("06a1d17c"): enable(PEOPLE)
			if not s.get("awaiting_tanya",true):
				if s.get("carriers",false):
					if s.has("carrier_follow_left"): enable(CARRIERS)
					elif s.has("carrier_ping_left"): enable(PING)
					else: enable(FLEET_LOST)
				else: enable(DEATH)
	s.retail_field=state
	return true

static func wp_code(value: String) -> int:
	var n:=0
	for c in value: n=n*26+c.unicode_at(0)-64
	return n-1

func _internal(action: Array) -> bool:
	if action[0]=="54" and str(action[2]).to_lower() in ["09610f3c","0d39599c","0973096c"]: state.fired.erase(str(action[2]).to_lower())
	if action[0]=="53" and str(action[2]).to_lower() in [ENGINEERS,ARRIVED,CARRIERS,PING,FLEET_LOST]:
		state.fired.erase(str(action[2]).to_lower())
	return super._internal(action)

func sample(world,s: Dictionary) -> void:
	entered.clear()
	for u in world.units:
		if not world.actor_alive(u) or u.side!="ally" or u.embarked_in!=null: continue
		if u.special.get("allied_first_room","Americans")!="Americans": continue
		var uv:=Vector2i(u.position/world.AlliedFirst.Places.CELL)
		var packed: int=(157-uv.x)*1000+18+uv.y
		for id in cell_rows.get(packed,[]):
			if id!="0462b74c" or not u.is_air: entered[id]=true
	if s.get("engineer_drop_pending",false):
		if world.units.any(func(u):return world.actor_alive(u) and u.special.get("allied_first_team","")=="0908B07C" and not u.special.has("para_height")):
			set_local(54,true)

func ready(world,s: Dictionary,row: Dictionary,event: Array) -> bool:
	match int(event[0]):
		1,59: return entered.has(row.id)
		28: return not s.get("hospital_found",false)
		6: return s.get("field_machine_hit",false)
		30: return world.side_power_low("ally")
		48:
			for b in world.buildings:
				if world.actor_alive(b) and b.special.get("allied_first_tag","")=="08e569cc" and b.side=="ally" and not b.special.has("infiltrated"): return false
			return true
		11:
			if not s.get("armor_sent",false): return false
			var room: String=definition.houses[event[2]]
			for a in world.units+world.buildings:
				if world.actor_alive(a) and a.special.get("allied_first_room","")==room: return false
			return true
		61:
			if event[3]=="CASANF10": return world.AlliedFirst.site(world,event[3])==null
			for u in world.units:
				if not world.actor_alive(u) or u.side!="ally": continue
				if u.unit_id==event[3] or (event[3]=="ENGINEER" and u.special.get("para_infantry","")=="ENGINEER" and int(u.special.get("para_left",0))>0): return false
			return true
	return false

func run(world,s: Dictionary,delta: float) -> void:
	var remaining:=maxf(0.0,delta)
	var past: bool=s.get("crossing_swapped",false) or int(s.phase)>=4
	set_local(3,past)
	for id in s.get("power_external_links",{}).keys():
		if not rows.has(id): continue
		if s.power_external_links[id]: enable(id)
		else: state.enabled.erase(id)
		s.power_external_links.erase(id)
	if s.get("city_external_links",{}).erase(PEOPLE): enable(PEOPLE)
	if s.get("armor_sent",false) and s.get("awaiting_tanya",false) and not state.fired.has(APOCS): enable(APOCS)
	poll_left-=remaining
	var poll: bool=poll_left<=0.0 or delta==0.0
	if poll: sample(world,s)
	var predicate:=func(row: Dictionary,event: Array):return ready(world,s,row,event)
	while true:
		var cmd:=advance(0.0,predicate)
		while not cmd.is_empty():
			if not apply(world,s,cmd):
				push_error("ALL01 field action failed "+str(cmd))
				return
			acknowledge(cmd.token)
			cmd=advance(0.0,predicate)
		for id in ["09610f3c","0d39599c","0973096c"]:
			if not s.get("field_arrow_clocks",{}).has(id): continue
			if state.fired.erase(id):
				state.enabled[id]=s.field_arrow_clocks[id]
		if remaining<=0.0: break
		var step:=remaining
		for id in state.enabled:
			for ev in rows[id].events:
				if ev[0]!="13": continue
				var due:=float(state.enabled[id])+float(ev[2])-float(state.time)
				if due>0.000001: step=minf(step,due)
		state.time=float(state.time)+step
		remaining=maxf(0.0,remaining-step)
	if state.enabled.has(ENTER): s.tanya_left=maxf(0.0,float(rows[ENTER].events[0][2])+float(state.enabled[ENTER])-float(state.time))
	if state.enabled.has(CARRIERS): s.carrier_follow_left=maxf(0.0,1.0+float(state.enabled[CARRIERS])-float(state.time))
	else: s.erase("carrier_follow_left")
	if s.has("field_base_camera_at") and float(state.time)>=float(s.field_base_camera_at):
		world.center_on(world.AlliedFirst.wp(14))
		s.erase("field_base_camera_at")
	if poll:
		poll_left=0.2
		for u in world.units.duplicate():
			if not world.actor_alive(u): continue
			if u.special.has("field_script_line"): Teams.step(world,self,u)
			if u.special.has("field_flash_until"):
				var left:=float(u.special.field_flash_until)-float(state.time)
				u.self_modulate=Color.WHITE*(1.6 if left>0.0 and int(left*8)%2==0 else 1.0)
				if left<=0: u.special.erase("field_flash_until")
		ambience.tick(world,s,maxf(delta,0.2))

func apply(world,s: Dictionary,cmd: Dictionary) -> bool:
	var op:=int(cmd.opcode)
	var arg:=str(cmd.fields[2])
	var wp:=wp_code(str(cmd.fields[7]))
	var mission=world.AlliedFirst
	match op:
		7,80:
			if cmd.trigger=="04c24a8c": return mission.spawn_naval_group(world,cmd.trigger,arg)
			return Teams.form(world,s,self,cmd)
		99: return ambience.add(s,arg,wp)
		116: ambience.stop_at(s,wp)
		17:
			if world.fog!=null:
				world.fog._reveal("ally",mission.wp(wp),mission.Places.CELL*9.0,world.fog.FIRE_REVEAL_SECONDS)
				world.fog.rebuild()
		19:
			if not Ra2Sfx.play(arg):
				if arg!="WarningAlarm": return false
				var alarm:=AudioStreamPlayer.new()
				alarm.stream=preload("res://assets/ra2/sfx/uwarning.wav")
				alarm.volume_db=linear_to_db(maxf(0.0001,Ra2Sfx._master_linear))
				world.add_child(alarm)
				alarm.finished.connect(alarm.queue_free)
				alarm.play()
		21:
			match arg:
				"Unit_Eva_GatCannon": mission.speech(world,"伊娃","发现盖特机炮。","cevau61")
				"Mis_xA1_TanyaSwimHint": mission.tanya_brief(world)
				"Mis_xA1_EvaProtectTimeMach": mission.speech(world,"伊娃","时光机正遭到攻击，保护它！","xa1ev06")
				"Unit_Eva_TechHospital":
					mission.speech(world,"伊娃","发现科技医院，派工程师占领可治疗己方步兵。")
					Ra2Sfx.play_hollywood_line("cevau92")
				"EVA_ReinforcementsHaveArrived":
					Ra2Sfx.play_player_eva(world,arg,0)
					if cmd.trigger==ARRIVED: s.erase("engineer_drop_pending")
				_: return false
		28: s.hospital_found=true
		32:
			for b in world.buildings.duplicate():
				if world.actor_alive(b) and b.special.get("allied_first_tag","")=="08a0080c": b.receive_hit(b.max_hp*100,"explosive")
		41:
			if not Ra2Fx.play_transient(world,mission.wp(wp),"ARRWW"): return false
			s.get_or_add("field_arrow_clocks",{})[cmd.trigger]=state.time
		46:
			s.power_camera_lock=true
			world.cancel_pointer_gestures()
		47: s.power_camera_lock=false
		48: world.center_on(mission.wp(wp))
		53,54: return handoff(world,s,arg.to_lower(),op==53)
		55: Events.emit_radar_ping(mission.wp(wp),"campaign_site")
		63: mission.PowerSequence.Transition.damage_at_waypoint(world,int(arg))
		104:
			for u in world.units:
				if world.actor_alive(u) and u.special.get("allied_first_team","")==arg:
					u.special.field_flash_until=float(state.time)+float(cmd.fields[7])/BattleClock.RULE_TICKS_PER_SECOND
		131:
			for b in world.buildings:
				if world.actor_alive(b) and b.building_id==arg: b.special.campaign_flash_left=float(cmd.fields[7])/BattleClock.RULE_TICKS_PER_SECOND
		10:
			Music.set_battle_stage("disadvantage")
		_: return false
	return true

func handoff(world,s: Dictionary,id: String,on: bool) -> bool:
	match id:
		"06a4918c":
			if s.get("map_closing_rows",false):
				var closing=world.AlliedFirst.closing_driver(world,s)
				closing.enable(id)
				closing.run(world,s,0.0)
				s.past_harbor_sent=true
			else: enable(KILL_SOUNDS)
		"0b0246cc":
			# The formal opening already presents this briefing via A01_P01E.
			if s.get("map_assault_rows",false): s.get_or_add("assault_links",{})[id]=on
			else: s.field_base_camera_at=float(state.time)+17.0
		"046358ac":
			var city=world.AlliedFirst.city_driver(world,s)
			if on: city.enable(id)
			else: city.state.enabled.erase(id)
		"08707a2c":
			if world.has_meta("allied_first_power_sequence"): world.get_meta("allied_first_power_sequence").state.enabled.erase(id)
		"0951879c","087c0e4c","087c0f3c","087c0d5c":
			# Sale and armor use their existing midpoint clocks. The original sound-chain links
			# can arrive after the sale was acknowledged; keep this handoff idempotent.
			if id=="0951879c" and on and s.has("past_controller_site"):
				world.AlliedFirst.tick_dominator_driver(world,s,null,0.0)
			s.get_or_add("field_past_links",{})[id]=on
		_: return false
	return true
