extends "res://scripts/world/allied_retail_script.gd"
const Teams=preload("res://scripts/world/allied_first_assault_teams.gd")
const POINTING:="087f198c"
const HOME:=["0b7d6aac","08a2318c","0b1612ec"]
# The radar brief already ran before this clock starts. Keep the camera and tutorial
# actions but do not replay the speech or leave the field locked through retail pauses.
const POST_BRIEF_DELAYS := {"0b0246cc":0.0,"0885de3c":0.0,"0b025f3c":0.0,"08a8fbcc":0.0,"08a868ec":0.0,"0a81491c":1.0,"0a81149c":1.0,"068f215c":0.0,"089627fc":0.0}
const TANK_TARGET:="CATIME" # BuildingTypes[314] after duplicate names are coalesced.
var poll_left:=0.0
var house_units: Dictionary={}
var house_buildings: Dictionary={}
var crossed:=false

func initialize(s: Dictionary,level: int) -> bool:
	if s.has("retail_assault"):
		if not restore(s.retail_assault): return false
	elif not start("yr_all01umd_assault",level): return false
	s.retail_assault=state
	return true

static func code(value: String) -> int:
	var n:=0
	for c in value: n=n*26+c.unicode_at(0)-64
	return n-1

func link(id: String,on: bool) -> void:
	if not on:
		state.enabled.erase(id)
		return
	# These rows explicitly disable themselves and the original wave cycle enables them again.
	if id!=state.active and (rows[id].actions.any(func(a):return a[0]=="54" and str(a[2]).to_lower()==id) or id in HOME):
		state.fired.erase(id)
	enable(id)

func _internal(a: Array) -> bool:
	if a[0] in ["53","54"] and rows.has(str(a[2]).to_lower()):
		link(str(a[2]).to_lower(),a[0]=="53")
		return true
	return super._internal(a)

func sample(w) -> void:
	house_units.clear()
	house_buildings.clear()
	crossed=false
	var line:=int(definition.harrier_cell)%1000
	for u in w.units:
		if not w.actor_alive(u): continue
		var room: String=u.special.get("allied_first_room","")
		if room.is_empty() and u.special.has("para_story_tags"): room=u.special.para_story_tags.get("allied_first_room","")
		house_units[room]=true
		if room!="Alliance" or not state.enabled.has("0611babc"): continue
		var x:=18+floori(u.position.y/w.AlliedFirst.Places.CELL)
		var last:=int(u.special.get("assault_last_x",x))
		if last!=x and mini(last,x)<=line and maxi(last,x)>=line: crossed=true
		u.special.assault_last_x=x
	for b in w.buildings:
		if not w.actor_alive(b): continue
		house_buildings[b.special.get("allied_first_room","")]=true

func condition(_row: Dictionary,e: Array) -> bool:
	if e[0]=="26": return crossed
	var room: String=definition.houses.get(e[2],"")
	return e[0] in ["9","11"] and not house_units.has(room) and (e[0]=="9" or not house_buildings.has(room))

func run(w,s: Dictionary,delta: float,opening) -> void:
	var left:=maxf(0.0,delta)
	poll_left-=left
	var poll:=poll_left<=0.0 or delta==0.0
	if poll:
		poll_left=0.2
		sample(w)
	set_local(3,s.get("crossing_swapped",false) or int(s.phase)>=4)
	set_local(47,int(s.phase)>=2)
	for key in ["power_external_links","plant_external_links","assault_links"]:
		var incoming: Dictionary=s.get(key,{})
		for id in incoming.keys():
			if rows.has(id):
				if not (id=="0b0246cc" and state.fired.has(id)): link(id,incoming[id])
				incoming.erase(id)
	if opening!=null: opening.run(w,s,0.0)
	while true:
		if s.erase("assault_ggi_ready"): link("0a81491c",true)
		for i in HOME.size():
			if state.locals[str(i)] and not state.enabled.has(HOME[i]) and not state.locals["3"]: link(HOME[i],true)
		var delays := POST_BRIEF_DELAYS if s.get("assault_radio_delivered",false) else {}
		var cmd:=advance(0.0,condition,Callable(),delays)
		while not cmd.is_empty():
			if not apply(w,s,cmd,opening):
				push_error("ALL01 assault action failed "+str(cmd))
				return
			acknowledge(cmd.token)
			cmd=advance(0.0,condition,Callable(),delays)
		if s.erase("assault_point_again") and not state.fired.has("087f124c"):
			state.fired.erase(POINTING)
			enable(POINTING)
		if left<=0.0000001: break
		var step:=left
		for id in state.enabled:
			for ev in rows[id].events:
				if ev[0] not in ["13","47"]: continue
				var due:=float(delays.get(id,ev[2]) if ev[0]=="13" else ev[2])-float(state.time)
				if ev[0]=="13": due+=float(state.enabled[id])
				if due>0.0000001: step=minf(step,due)
		if opening!=null:
			for id in opening.state.enabled:
				var due:=float(opening.state.enabled[id])+float(opening.rows[id].events[0][2])-float(opening.state.time)
				if due>0.0000001: step=minf(step,due)
			opening.run(w,s,step)
		state.time=float(state.time)+step
		left-=step
	if poll:
		for u in w.units.duplicate():
			if not w.actor_alive(u): continue
			if u.special.has("assault_line"):
				var owner=self if definition.teams.has(str(u.special.allied_first_team).to_lower()) else w.AlliedFirst.closing_driver(w,s)
				Teams.step(w,owner,u)
			if u.special.has("assault_flash_until"):
				var until:=float(u.special.assault_flash_until)
				u.self_modulate=Color.WHITE*(1.6 if until>float(state.time) and int(state.time*8)%2==0 else 1.0)
				if until<=float(state.time): u.special.erase("assault_flash_until")

func apply(w,s: Dictionary,cmd: Dictionary,opening) -> bool:
	var arg:=str(cmd.fields[2])
	var wp:=code(str(cmd.fields[7]))
	var m=w.AlliedFirst
	match int(cmd.opcode):
		4,7,80:
			if not Teams.form(w,s,self,cmd): return false
			sample(w)
		5:
			for u in w.units:
				if w.actor_alive(u) and u.special.get("allied_first_team","")==arg: u.special.erase("allied_first_team")
		19: Ra2Sfx.play(arg)
		21:
			if arg=="A01_p01":
				if not s.get("assault_radio_delivered",false): m.speech(w,"伊娃","指挥官，请占领发电厂，为时光机供电。","a01_p01")
			else: Ra2Sfx.play_player_eva(w,arg,0)
		41:
			if not Ra2Fx.play_transient(w,m.wp(wp),"ARRWW"): return false
			s.assault_point_again=true
		46:
			s.assault_input_locked=true
			w.cancel_pointer_gestures()
		47: s.assault_input_locked=false
		48,112: w.center_on(m.wp(wp))
		53,54:
			var id:=arg.to_lower()
			match id:
				"0a81253c","0ab41d9c":
					if opening!=null: opening.enable(id)
				"0691357c","06cbe3fc":
					s.get_or_add("assault_power_links",{})[id]=true
				"097d15dc": m.field_driver(w,s).enable(id)
				"08b4d3bc","089d668c": s.get_or_add("assault_plant_links",{})[id]=true
				_: return false
		55: Events.emit_radar_ping(m.wp(wp),"campaign_site")
		100:
			# The opening film host already delivered A01_P01E before handing the field to this clock.
			if not s.get("assault_radio_delivered",false): return false
		119:
			for actor in (w.units+w.buildings).duplicate():
				if w.actor_alive(actor) and actor.special.get("allied_first_room","")==definition.houses[arg]: actor.receive_hit(actor.max_hp*100,"explosive")
		131:
			var owner: String="PowerHouse" if cmd.house=="PowerHouse Country" else cmd.house
			for b in w.buildings:
				if w.actor_alive(b) and b.building_id==arg and b.special.get("allied_first_room","")==owner and b.side==m.side(owner): b.special.campaign_flash_left=float(cmd.fields[7])/BattleClock.RULE_TICKS_PER_SECOND
		137: s.assault_base_wp=int(arg)
		_: return false
	return true
