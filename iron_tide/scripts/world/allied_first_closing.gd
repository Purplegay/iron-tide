extends "res://scripts/world/allied_retail_script.gd"
const Teams=preload("res://scripts/world/allied_first_assault_teams.gd")
const FIX:="085159ec"
const CLEAN:="06a4918c"
const CREATE:="067dd9fc"
const SPYSAT:="061ff03c"
const BACK:="07a89e6c"
var poll_left:=0.0

func initialize(s: Dictionary,level: int) -> bool:
	if s.has("retail_closing"):
		if not restore(s.retail_closing): return false
	elif not start("yr_all01umd_closing",level): return false
	s.retail_closing=state
	return true

static func code(value: String) -> int:
	return preload("res://scripts/world/allied_first_field_driver.gd").wp_code(value)

func attached(w,id: String) -> Array:
	var ids: Array=definition.attached[id]
	if ids.is_empty(): return []
	return w.buildings.filter(func(b):return w.actor_alive(b) and b.special.get("allied_first_index","") in ids)

func condition(w,row: Dictionary,event: Array) -> bool:
	match int(event[0]):
		48: return not definition.attached[row.id].is_empty() and attached(w,row.id).is_empty()
		33: return w.actor_alive(w.selected_building) and w.selected_building in attached(w,row.id)
		30: return w.side_power_low("ally")
	return false

func run(w,s: Dictionary,delta: float) -> void:
	var left:=maxf(0,delta)
	poll_left-=left
	var poll:=poll_left<=0 or delta==0.0
	if poll: poll_left=0.2
	var query:=func(row: Dictionary,e: Array):return poll and condition(w,row,e)
	while true:
		var cmd:=advance(0.0,query)
		while not cmd.is_empty():
			if not apply(w,s,cmd):
				push_error("ALL01 closing action "+str(cmd))
				return
			acknowledge(cmd.token)
			cmd=advance(0.0,query)
		if left<=0.0000001: break
		var step:=left
		for id in state.enabled:
			for ev in rows[id].events:
				if ev[0]!="13": continue
				var due:=float(state.enabled[id])+float(ev[2])-float(state.time)
				if due>0.0000001: step=minf(step,due)
		state.time=float(state.time)+step
		left-=step

func reveal_zone(w,wp: int) -> void:
	var fog=w.fog
	if fog==null: return
	var p: Vector2=w.AlliedFirst.wp(wp)
	var nav=w.path_service
	var water: bool=w.in_water_world(p)
	var zone: int=nav.zone_at(p,water)
	if zone<=0:
		# A building foundation can cover the waypoint. Sample adjacent original terrain.
		for dir in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			zone=nav.zone_at(p+dir*w.AlliedFirst.Places.CELL,water)
			if zone>0: break
	if zone<=0: return
	var explored: PackedByteArray=fog.explored_cells.ally
	for y in fog.width:
		for x in fog.width:
			var pos: Vector2=(Vector2(x,y)+Vector2.ONE*0.5)*fog.CELL
			if nav.zone_at(pos,water)==zone: explored[y*fog.width+x]=1
	fog.explored_cells.ally=explored
	fog.rebuild()

func restore_house(w,room: String) -> void:
	var mission=w.AlliedFirst
	var existing: Dictionary={}
	var rebuilt: Dictionary={}
	for b in w.buildings:
		if w.actor_alive(b) and b.special.has("allied_first_index"): existing[b.special.allied_first_index]=b
	for row in mission.Field.data.structures:
		if row[1]!=room or not row[8] or int(row[3])<=0: continue
		var b=existing.get(row[0])
		if b==null:
			var data: Dictionary=GameData.get_building(row[2])
			if data.is_empty(): continue
			var size:=str(data.get("foundation","1x1")).split("x")
			var at: Vector2=(Vector2(row[4],row[5])+Vector2(1-int(size[1]),int(size[0])-1)*0.5)*mission.Places.CELL
			for candidate in w.buildings:
				if w.actor_alive(candidate) and candidate.building_id==row[2] and candidate.position.is_equal_approx(at): b=candidate; break
			if b==null: b=w._place_building(row[2],mission.side(room),at,true)
			if b==null: continue
			rebuilt[b.position]=b.building_id
			b.special.allied_first_index=row[0]
			b.special.allied_first_tag=str(row[7]).to_lower()
			b.special.allied_first_room=room
			b.refresh_house_color()
		if b.side==mission.side(room):
			b.hp=b.max_hp
			b.queue_redraw()
	var rubble: Array=w.allied_state.get("building_rubble",[])
	var previous_count:=rubble.size()
	for i in range(rubble.size()-1,-1,-1):
		if rebuilt.get(rubble[i].point)==rubble[i].id: rubble.remove_at(i)
	if rubble.size()!=previous_count: preload("res://scripts/buildings/building_rubble.gd").restore(w)
	w.invalidate_building_membership()
	w._refresh_pathing()
	w._update_power()

func apply(w,s: Dictionary,cmd: Dictionary) -> bool:
	var m=w.AlliedFirst
	var arg:=str(cmd.fields[2])
	var wp:=code(str(cmd.fields[7]))
	match int(cmd.opcode):
		4: return Teams.form(w,s,self,cmd)
		7,80:
			if not m.spawn_naval_group(w,cmd.trigger,arg): return false
			if cmd.trigger==FIX: s.past_defenses_restored=true
		14:
			var room: String=definition.houses[arg]
			for b in attached(w,cmd.trigger):
				m.Orders.change_side(b,m.side(room))
				b.special.allied_first_room=room
				b.refresh_house_color()
		17:
			if w.fog!=null:
				w.fog._reveal("ally",m.wp(wp),m.Places.CELL*9.0,w.fog.FIRE_REVEAL_SECONDS)
				w.fog.rebuild()
		18: reveal_zone(w,int(arg))
		21: m.speech(w,"伊娃","这是尤里的心灵控制器。","cevau70")
		24: s.closing_timer_stopped=true
		32:
			for b in attached(w,cmd.trigger): b.receive_hit(b.max_hp*100,"explosive")
		51:
			if w.fog!=null: w.fog.reset_exploration("ally")
		53:
			var id:=arg.to_lower()
			if id in m.Armor.APOCS or id in m.PowerSequence.REBUILD_CANNONS:
				var power=w.get_meta("allied_first_power_sequence")
				power.enable(id)
				if id==m.Armor.APOCS.back(): s.apocs_sent=true
			elif id==m.field_driver(w,s).KILL_SOUNDS:
				m.field_driver(w,s).enable(id)
			elif id==m.city_driver(w,s).FLEET:
				m.city_driver(w,s).enable(id)
				s.followup_fleet_sent=true
			else: return false
		63: m.PowerSequence.Transition.damage_at_waypoint(w,int(arg))
		118:
			var layer=w.get_node_or_null("__decals")
			if layer!=null: layer.clear_all()
			s.closing_smudges_cleared=true
			m.sync_smudges(w,s)
		125: return m.PowerSequence.Transition.rebuild(w,resolve_spawn(cmd))
		129:
			if arg!="7": return false
			for b in w.buildings:
				if w.actor_alive(b) and b.special.get("allied_first_room","")==cmd.house and b.sw_type()=="PsychicDominator":
					b._sw_charge=b.sw_recharge()*float(cmd.fields[7])/100.0
		130: restore_house(w,definition.houses[arg])
		_: return false
	return true
