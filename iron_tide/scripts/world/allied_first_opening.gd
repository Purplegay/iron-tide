extends "res://scripts/world/allied_retail_script.gd"
## ALL01 opening teams. One saved trigger clock, one script cursor per field actor.
const CAMERA := "0a81253c"
const BAIT := "0ab41d9c"
const REACTOR := "087857cc"

func initialize(s: Dictionary,level: int) -> bool:
	if s.has("retail_opening"): return restore(s.retail_opening)
	if not start("yr_all01umd",level): return false
	state.enabled.clear()
	for row in definition.triggers:
		if row.name.begins_with("Deploy_") or row.name=="Start_CityP" or (row.name.begins_with("Start_") and row.name.ends_with("_Patrol")) or row.id==REACTOR:
			enable(row.id)
	# The port hands off the original Ping3_to_GGI pair when the briefing releases control.
	if not s.get("map_assault_rows",false):
		enable(CAMERA)
		enable(BAIT)
	return true

func run(world,s: Dictionary,delta: float) -> void:
	var remaining := maxf(delta,0.0)
	while not state.enabled.is_empty() or not state.pending.is_empty() or s.has("ggi_attack_at"):
		var cmd := advance(0.0)
		while not cmd.is_empty():
			match int(cmd.opcode):
				4,7:
					if not form(world,cmd): return
				48: world.center_on(world.AlliedFirst.wp(int(definition.waypoints[cmd.fields[7]].id)))
				21:
					world.AlliedFirst.speech(world,"伊娃","这是重装大兵。部署后可用导弹打击装甲和飞机。","cevau75")
					Events.emit_radar_ping(world.AlliedFirst.wp(13),"campaign_site")
					s.ggi_intro_shown = true
					s.erase("ggi_intro_left")
				53:
					if cmd.fields[2]!="0A81491C": return
					if s.get("map_assault_rows",false): s.assault_ggi_ready=true
					else: s.ggi_attack_at = float(state.time)+5.0
				63: world.AlliedFirst.PowerSequence.Transition.damage_at_waypoint(world,int(cmd.fields[2]))
				_:
					push_error("Unhandled ALL01 opening action: "+str(cmd))
					return
			acknowledge(cmd.token)
			cmd = advance(0.0)
		if s.has("ggi_attack_at") and float(state.time)+0.000000001>=float(s.ggi_attack_at):
			s.erase("ggi_attack_at")
			world.AlliedFirst.send_opening_attack(world,s)
		if remaining<=0: break
		var step := remaining
		for id in state.enabled:
			var due := float(state.enabled[id])+float(rows[id].events[0][2])-float(state.time)
			if due>0.000000001: step=minf(step,due)
		state.time = float(state.time)+step
		remaining = maxf(remaining-step,0.0)
	s.retail_opening = state
	s.patrol_poll = float(s.get("patrol_poll",0.0))-delta
	if s.patrol_poll<=0:
		s.patrol_poll = 0.35
		for u in world.units:
			if world.actor_alive(u) and u.special.has("all01_patrol_step"): move_member(world,u)

func form(world,cmd: Dictionary) -> bool:
	var spec := resolve_spawn(cmd)
	if spec.is_empty(): return false
	var group: Dictionary = spec.team
	var team: String = cmd.fields[2]
	var room: String = group.team.house
	var origin: Vector2 = world.AlliedFirst.wp(int(spec.waypoint.id))
	var force: PackedStringArray = str(group.task_force["0"]).split(",")
	var needed := int(force[0])
	var actors := []
	if cmd.opcode==4:
		for u in world.units:
			if world.actor_alive(u) and u.unit_id==force[1] and u.special.get("allied_first_room","")==room and u.special.has("allied_first_index") and not u.special.has("allied_first_team") and u.embarked_in==null:
				actors.append(u)
		actors.sort_custom(func(a,b):return a.position.distance_squared_to(origin)<b.position.distance_squared_to(origin))
		actors = actors.slice(0,needed)
	else:
		for u in world.units:
			if world.actor_alive(u) and u.special.get("allied_first_team","")==team: actors.append(u)
		while actors.size()<needed:
			var u = world.spawn_unit(force[1],world.AlliedFirst.side(room),origin)
			if u==null: return false
			u.special.allied_first_team = team
			u.special.allied_first_room = room
			u.refresh_house_color()
			actors.append(u)
	for u in actors:
		u.special.allied_first_team = team
		var first: PackedStringArray = str(group.script["0"]).split(",")
		if int(first[0])==9:
			u.set_deployed(true,false)
		else:
			u.hold_position = false
			u.special.all01_patrol_step = 0
			move_member(world,u)
	return true

func move_member(world,u) -> void:
	var script: Dictionary = definition.teams[str(u.special.allied_first_team).to_lower()].script
	var cursor := int(u.special.all01_patrol_step)
	var raw: String = script.get(str(cursor),"")
	if raw.is_empty():
		u.special.erase("all01_patrol_step")
		return
	var fields := raw.split(",")
	var op := int(fields[0])
	if op==6:
		u.special.all01_patrol_step = int(fields[1])-1
		return
	var dest: Vector2 = world.AlliedFirst.wp(int(fields[1]))
	# The original map's city routes include a waypoint just beyond the playable edge.
	if not world.AlliedFirst.Places.data(world.AlliedFirst.MAP).waypoints[fields[1]][2]:
		dest = world.path_service.nearest_reachable(dest,u.position)
	if u.position.distance_to(dest)<world.AlliedFirst.Places.CELL:
		u.special.all01_patrol_step = cursor+1
	elif not u.has_move_order or not u.move_target.is_equal_approx(dest):
		if op==16 and world.actor_alive(u.attack_target) and u.position.distance_to(u.attack_target.position)<=u.attack_range: return
		u.order_move(dest,op==16)
