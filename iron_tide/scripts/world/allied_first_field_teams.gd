extends RefCounted
const Civil=preload("res://scripts/units/civilian_orders.gd")

static func form(world,s: Dictionary,d,cmd: Dictionary) -> bool:
	var spawn: Dictionary=d.resolve_spawn(cmd)
	if spawn.is_empty(): return false
	var group: Dictionary=spawn.team
	var team: String=cmd.fields[2]
	var room: String=group.team.house
	var point: Vector2=world.AlliedFirst.wp(int(spawn.waypoint.id))
	var tags={"allied_first_room":room,"allied_first_team":team,"field_spawn_wp":spawn.waypoint.id}
	if group.team.get("droppod","no")=="yes":
		var type := str(group.task_force["0"]).split(",")
		var entry: Vector2=world.AlliedFirst.wp(d.wp_code(group.team.transportwaypoint))
		if not preload("res://scripts/world/american_paradrop.gd").launch_story(world,point,type[1],int(type[0]),entry,tags): return false
		s.engineer_drop_pending=true
		return true
	var progress: Dictionary=s.get_or_add("field_formation",{})
	var key: String=str(cmd.trigger)+"/"+str(cmd.token)
	var index:=0
	for slot in group.task_force:
		if not str(slot).is_valid_int(): continue
		var member:=str(group.task_force[slot]).split(",")
		for i in int(member[0]):
			index+=1
			if index<=int(progress.get(key,0)): continue
			var offset:=Vector2((index-1)%3,(index-1)/3)*20.0
			var u=world.spawn_unit(member[1],world.AlliedFirst.side(room),point+offset)
			if u==null: return false
			u.special.merge(tags,true)
			u.special.field_script_line=0
			u.refresh_house_color()
			var rank:=int(group.team.get("veteranlevel",1))-1
			if rank>0: u._grant_veteran(rank,false)
			if member[1]=="TANY":
				u.special.allied_first_tanya=true
				s.awaiting_tanya=false
				world.select_unit(u,false)
				world._emit_selection()
			if member[1]=="CARRIER": u.special.allied_first_carrier=true
			step(world,d,u)
			progress[key]=index
	if team=="08071C8C":
		s.carrier_waves=int(s.get("carrier_waves",0))+1
		s.carriers=true
		if s.carrier_waves==1: world.AlliedFirst.speech(world,"伊娃","谭雅已阵亡。航母正赶往恶魔岛附近。")
	progress.erase(key)
	return true

static func step(world,d,u) -> void:
	var script: Dictionary=d.definition.teams[str(u.special.allied_first_team).to_lower()].script
	var line:=int(u.special.field_script_line)
	var raw:=str(script.get(str(line),""))
	if raw.is_empty():
		u.special.erase("field_script_line")
		return
	var fields:=raw.split(",")
	var arg:=int(fields[1])
	match int(fields[0]):
		3:
			var dest: Vector2=world.AlliedFirst.wp(arg)
			if u.side=="ally" and u.special.get("field_order_issued",false) and (u.attack_ordered or (u.has_move_order and u.move_target.distance_to(dest)>world.AlliedFirst.Places.CELL)):
				u.special.erase("field_script_line")
				return
			if u.position.distance_to(dest)<world.AlliedFirst.Places.CELL: u.special.field_script_line=line+1
			elif not u.has_move_order:
				u.order_move(dest)
				u.special.field_order_issued=true
		5:
			if not u.special.has("field_guard_until"):
				u.order_stop()
				u.hold_position=true
				u.special.field_guard_until=float(d.state.time)+arg*6.0
			if float(d.state.time)>=float(u.special.field_guard_until):
				u.special.erase("field_guard_until")
				u.special.field_script_line=line+1
		6: u.special.field_script_line=arg-1
		11:
			if arg==11:
				u.order_stop()
				u.hold_position=true
				u.special.field_script_line=line+1
		64:
			if u.embarked_in!=null:
				if u.embarked_in is Building and u.embarked_in.special.get("allied_first_room","")=="Neutral":
					u.embarked_in.special.allied_first_room=u.special.allied_first_room
					u.embarked_in.refresh_house_color()
				u.special.erase("field_script_line")
				return
			if u.special.get("action","")=="allied_garrison": return
			var target=null
			for b in world.buildings:
				if not world.actor_alive(b) or not Civil.can_enter(u,b): continue
				if target==null or u.position.distance_squared_to(b.position)<u.position.distance_squared_to(target.position): target=b
			if target!=null: world.AlliedFirst.Orders.use(u,"allied_garrison",target)
