extends RefCounted
## Task teams share the retail driver; the map's sound-chain handoff still provides the armor clock origin.
const Driver = preload("res://scripts/world/allied_retail_script.gd")
const SEND := ["087c0e4c","087c0f3c","087c0d5c"]
const APOCS := ["05ee7c8c","05ee7b9c"]

static func delay(level: int) -> float:
	var id: String = SEND[clampi(level,0,2)]
	for row in Driver.DATA.data.yr_all01umd.triggers:
		if row.id==id: return float(row.events[0][2])
	return INF

static func spawn_team(world, driver, command: Dictionary) -> bool:
	var spawn: Dictionary = driver.resolve_spawn(command)
	if spawn.is_empty(): return false
	var t: Dictionary = spawn.team
	var room: String = "Soviet2House" if t.team.house=="Soviet2 Country" else str(t.team.house)
	var id: String = command.fields[2]
	var raw_point: Array = spawn.waypoint.uv
	var origin: Vector2 = Vector2(raw_point[0],raw_point[1])*world.AlliedFirst.Places.CELL
	# RM is outside the playable diamond. Keep the existing entry proxy for these two reinforcements.
	if t.team.waypoint=="RM": origin = world.AlliedFirst.wp(41)
	var rally: Vector2 = origin
	var step: PackedStringArray = str(t.script["0"]).split(",")
	if step[0]=="3": rally = world.AlliedFirst.wp(int(step[1]))
	var s: Dictionary = world.allied_state.allied_first
	var progress: Dictionary = s.get_or_add("armor_spawn_progress",{})
	var checkpoint := "%s:%s" % [command.trigger,command.token]
	var ordinal := 0
	for key in t.task_force:
		if not str(key).is_valid_int(): continue
		var member: PackedStringArray = str(t.task_force[key]).split(",")
		for i in int(member[0]):
			if ordinal < int(progress.get(checkpoint,0)):
				ordinal += 1
				continue
			var at := origin
			if command.opcode==7: at += Vector2((ordinal-1)*28,31 if id=="0925FDEC" else 0)
			var u = world.spawn_unit(member[1],"enemy",at)
			if u==null: return false
			u.special.allied_first_raid = true
			u.special.allied_first_team = id
			u.special.allied_first_room = room
			u.refresh_house_color()
			u.order_move(rally,true)
			ordinal += 1
			progress[checkpoint] = ordinal
	progress.erase(checkpoint)
	return true

static func tick_column(world,s: Dictionary,delta: float) -> void:
	var d = world.get_meta("first_column_driver",null) if world.has_meta("first_column_driver") else null
	var difficulty := clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)
	var id: String = SEND[difficulty]
	if d==null:
		d = Driver.new()
		if s.has("retail_armor"):
			if not d.restore(s.retail_armor): push_error("Invalid ALL01 armor snapshot"); return
		else:
			d.start(world.AlliedFirst.MAP,difficulty)
			d.state.enabled.clear()
			d.enable(id)
			d.state.time = maxf(0.0,delay(difficulty)-float(s.armor_left))
		d.rows.erase("0ac8355c") # The mission field driver owns the two-house destruction condition.
		world.set_meta("first_column_driver",d)
	s.retail_armor = d.state
	var cmd: Dictionary = d.advance(delta)
	while not cmd.is_empty():
		if cmd.opcode==7:
			if not spawn_team(world,d,cmd): push_error("Invalid ALL01 armor team"); return
		elif cmd.opcode==53 and cmd.fields[2]=="0AC8355C":
			s.armor_sent = true
			Events.emit_radar_ping(world.AlliedFirst.wp(41),"campaign_site")
			world.AlliedFirst.speech(world,"伊娃","敌军装甲部队正在接近。击退它们，给谭雅打开通路。")
		else: push_error("Unexpected ALL01 armor action"); return
		d.acknowledge(cmd.token)
		cmd = d.advance(0)
	s.armor_left = maxf(0.0,delay(difficulty)-float(d.state.time))
	s.retail_armor = d.state
