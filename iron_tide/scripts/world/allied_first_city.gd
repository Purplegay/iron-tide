extends "res://scripts/world/allied_retail_script.gd"
## Original ALL01UMD city teams, objective reminder and ownership watchers.
const FLEET := "089d5a8c"
const TANYA_REMINDER := "046358ac"
const MOVIES := "0899832c"
# Zero-based BuildingTypes in the effective retail rules and this map's additions.
const TYPES := {"393":"CAPARK04","394":"CAPARK05","395":"CAPARK06","396":"CALA14","397":"CALA15","398":"CABUNK03","399":"CABUNK04","400":"CALUNR01","409":"CAPOWR08"}
var watches: Array = []
var tracked_types: Dictionary = {}
var offmap_owners: Dictionary = {}
var ownership: Dictionary = {}
var until_poll := 0.0

func _internal(action: Array) -> bool:
	if action[0]=="53" and action[2]=="08A6340C": return false
	return super._internal(action)

func initialize(s: Dictionary) -> bool:
	if s.has("retail_city"):
		if not restore(s.retail_city): return false
	else:
		if not start("yr_all01umd",clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)): return false
		state.enabled.clear()
		# A pre-city save may already contain the seven follow-up ships. Resume at their outgoing link.
		if s.get("followup_fleet_sent",false) and int(s.get("phase",0))==4: enable(MOVIES)
	for type in TYPES.values(): tracked_types[type] = true
	for row in preload("res://data/ra2/allied_first_field.json").data.structures:
		if not row[8] and int(row[3])>0 and tracked_types.has(row[2]):
			offmap_owners[str(row[1])+"/"+str(row[2])] = true
	for row in definition.triggers:
		if row.name.begins_with("PP") and ("_Is_" in row.name or "_Not_" in row.name):
			watches.append(row)
			if not state.fired.has(row.id): enable(row.id)
	s.retail_city = state
	return true

func poll_owners(world) -> void:
	ownership = offmap_owners.duplicate()
	for b in world.buildings:
		if not world.actor_alive(b) or not tracked_types.has(b.building_id): continue
		var room: String = b.special.get("allied_first_room","")
		if b.side=="ally" and room not in ["Alliance","British"]: room="Americans"
		elif room=="Americans" and b.side!="ally": room=""
		ownership[room+"/"+b.building_id] = true
	for row in watches:
		if state.fired.has(row.id) and world_condition(row,row.events[0]) and state.locals[row.events[1][2]]==(row.events[1][0]=="36"):
			state.fired.erase(row.id)
			enable(row.id)

func world_condition(row: Dictionary,event: Array) -> bool:
	var room: String = "PowerHouse" if row.house=="PowerHouse Country" else row.house
	return ownership.has(room+"/"+str(TYPES[event[2]]))==(event[0]=="32")

func run(world,s: Dictionary,delta: float) -> void:
	until_poll-=delta
	var poll := until_poll<=0.0
	if poll:
		until_poll = 0.25
		poll_owners(world)
	var reminder_enabled: bool = state.enabled.has(TANYA_REMINDER)
	if not poll and not state.enabled.has(FLEET) and not state.enabled.has(MOVIES) and not reminder_enabled and state.pending.is_empty():
		state.time = float(state.time)+maxf(0,delta)
		return
	if s.get("phase")==4 and not s.get("awaiting_tanya",true):
		var alive: bool = world.units.any(func(u):return world.actor_alive(u) and u.special.get("allied_first_tanya",false))
		set_local(4,not alive)
		if not alive: state.enabled.erase(TANYA_REMINDER)
	var gate := func(row: Dictionary):return poll if TYPES.has(row.events[0][2]) and row.events[0][0] in ["32","57"] else true
	var cmd := advance(delta,world_condition,gate)
	while not cmd.is_empty():
		match int(cmd.opcode):
			7,80:
				if cmd.trigger==FLEET:
					if not world.AlliedFirst.spawn_naval_group(world,FLEET,cmd.fields[2]): return
				elif not spawn_member(world,cmd):
					push_error("Failed ALL01 city team "+str(cmd.fields))
					return
			11:
				world.AlliedFirst.speech(world,"伊娃","任务目标：摧毁恶魔岛上的心灵控制器。")
				s.island_reminder_at = state.time
			53:
				if cmd.fields[2]!="08A6340C":
					push_error("Unexpected ALL01 city link "+str(cmd))
					return
				s.get_or_add("city_external_links",{})[cmd.fields[2].to_lower()] = true
			_:
				push_error("Unexpected ALL01 city action "+str(cmd))
				return
		acknowledge(cmd.token)
		cmd = advance(0.0,world_condition,gate)
	if s.has("island_reminder_at") and not state.locals["4"] and state.fired.has(TANYA_REMINDER):
		state.fired.erase(TANYA_REMINDER)
		state.enabled[TANYA_REMINDER] = s.island_reminder_at
	if poll and state.fired.has(MOVIES):
		for u in world.units.duplicate():
			if world.actor_alive(u) and u.special.has("all01_city_line"): step_member(world,u)

func spawn_member(world,cmd: Dictionary) -> bool:
	var spec := resolve_spawn(cmd)
	if spec.is_empty(): return false
	var group: Dictionary = spec.team
	var member := str(group.task_force["0"]).split(",")
	if member[0]!="1": return false
	var room: String = "Soviet2House" if group.team.house=="Soviet2 Country" else group.team.house
	var at: Vector2 = world.AlliedFirst.wp(int(spec.waypoint.id))
	var u = world.spawn_unit(member[1],world.AlliedFirst.side(room),at)
	if u==null: return false
	u.special.allied_first_room = room
	u.special.allied_first_team = cmd.fields[2]
	u.special.all01_city_spawn = int(spec.waypoint.id)
	u.special.all01_city_line = 0
	u.refresh_house_color()
	step_member(world,u)
	return true

func step_member(world,u) -> void:
	var script: Dictionary = definition.teams[str(u.special.allied_first_team).to_lower()].script
	var line := int(u.special.all01_city_line)
	var raw := str(script.get(str(line),""))
	if raw.is_empty():
		u.special.erase("all01_city_line")
		return
	var fields := raw.split(",")
	var arg := int(fields[1])
	match int(fields[0]):
		3:
			var dest: Vector2 = world.AlliedFirst.wp(arg)
			if not u.is_air and not world.AlliedFirst.Places.data(world.AlliedFirst.MAP).waypoints[fields[1]][2]:
				dest = world.path_service.nearest_reachable(dest,u.position)
			if u.position.distance_to(dest)<world.AlliedFirst.Places.CELL:
				u.special.all01_city_line=line+1
			elif not u.has_move_order or not u.move_target.is_equal_approx(dest): u.order_move(dest)
		5:
			if not u.special.has("all01_guard_until"):
				u.order_stop()
				u.hold_position=true
				u.special.all01_guard_until=float(state.time)+arg*6.0
			if float(state.time)>=float(u.special.all01_guard_until):
				u.special.erase("all01_guard_until")
				u.special.all01_city_line=line+1
		6: u.special.all01_city_line=arg-1
		19:
			if not u.has_move_order:
				var heading := Vector2.RIGHT.rotated(fmod(float(state.time)+float(u.special.all01_city_spawn),TAU))
				var dest: Vector2 = world.path_service.nearest_reachable(u.position+heading*world.AlliedFirst.Places.CELL*2.0,u.position)
				u.order_move(dest)
				u.special.all01_city_line=line+1
		42:
			var heading := Vector2.UP.rotated((arg+1)*PI/4.0)
			u.order_stop()
			u.hull_angle=heading.angle()
			u._face(u.position+heading)
			u.special.all01_city_line=line+1
		46:
			# 0x20040 selects the original GTGCAN building type.
			var target = null
			var chosen: Array = u.special.get("all01_gun_site",[])
			for b in world.buildings:
				if not world.actor_alive(b) or b.building_id!="GTGCAN" or b.side!="ally": continue
				if not chosen.is_empty() and not b.position.is_equal_approx(Vector2(chosen[0],chosen[1])): continue
				if target==null or u.position.distance_squared_to(b.position)<u.position.distance_squared_to(target.position): target=b
			if target==null:
				u.special.erase("all01_gun_site")
				u.special.all01_city_line=line+1
			else:
				u.special.all01_gun_site=[target.position.x,target.position.y]
				if not u.attack_ordered or u.attack_target!=target: u.order_target(target,true,false)
		59:
			var at: Vector2 = world.AlliedFirst.wp(arg)
			if u.special.get("all01_bomb_released",false):
				u.special.erase("all01_bomb_released")
				u.order_stop()
				u.special.all01_city_line=line+1
			elif not (u.attack_ordered and u.attack_target is ForceFirePoint and u.attack_target.position==at):
				var point := ForceFirePoint.new()
				point.global_position=at
				point.side="ally"
				u.order_target(point,true,false)
		37:
			world.AlliedFirst.Orders.consume(u)
			world.units.erase(u)
