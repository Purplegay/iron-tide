extends RefCounted
## Narrow adapters for the retail endgame, naval response and tagged oil sites.
const Orders = preload("res://scripts/units/allied_abilities.gd")
const MAIN := "YuriCountry"
const SECOND := "Yuri2"
const THIRD := "Yuri3"
const FRANCE := "French"
const THIRD_ACCOUNT := "allied_finale_yuri3"
const THIRD_DATA = preload("res://data/ra2/allied_finale_third_house.json")

static func ensure_account(world) -> Dictionary:
	var s: Dictionary = world.allied_state.allied_finale
	if not s.has("third_house"):
		s.third_house={"funds":float(THIRD_DATA.data.starting_funds),"build_enabled":false,"ai_enabled":false}
	return s.third_house

static func enable_third(world, action: int) -> void:
	var account := ensure_account(world)
	if account.get("retired",false): return
	account["build_enabled" if action==3 else "ai_enabled"]=true

static func third_build(world) -> void:
	var account := ensure_account(world)
	if not account.build_enabled or account.get("retired",false): return
	if world.buildings.any(func(b):return belongs(world,b,THIRD) and b.under_construction): return
	for node in THIRD_DATA.data.nodes:
		if not node.inside: continue
		var at := Vector2(node.uv[0],node.uv[1])*55.0
		var def := GameData.get_building(node.id)
		var dims := str(def.get("foundation","1x1")).split("x")
		if dims.size()==2: at += Vector2(1-int(dims[1]), int(dims[0])-1)*27.5
		if world.buildings.any(func(b):return belongs(world,b,THIRD) and b.building_id==node.id and b.position.distance_to(at)<25.0): continue
		if account.funds<float(def.get("cost",0)): return
		# Original third yard is outside LocalSize. Allow only its authored nodes
		# past adjacency; preserve ordinary terrain, resource and footprint checks.
		if not world.build_spot_ok(at,def,true,"enemy",null,true).ok: continue
		var b = world._place_building(node.id,"enemy",at,false,false,true)
		if b==null: return
		b.special.allied_finale_room=THIRD
		b.refresh_house_color()
		return

static func transfer_tagged_third_base(world) -> void:
	var account := ensure_account(world)
	account.retired=true
	account.build_enabled=false
	account.ai_enabled=false
	# Action 14 is object-scoped: 08cba40c tags only the off-map base structures.
	# 08cba88c has no target tag, so never transfer an entire submarine fleet.
	for actor in world.buildings:
		if not belongs(world,actor,THIRD) or not actor.special.get("finale_yuri3_yard_tag",false): continue
		actor.special.allied_finale_room=FRANCE
		Orders.change_side(actor,"neutral",false)
	Orders.refresh_after_side_changes(world)

static func room(number: String) -> String:
	return str({"9":MAIN,"14":SECOND,"15":THIRD}.get(number,""))

static func actor_room(actor) -> String:
	return str(actor.special.get("allied_finale_room", ""))

static func belongs(world, actor, house: String) -> bool:
	return world.actor_alive(actor) and actor.side=="enemy" and actor_room(actor)==house

static func oil(world, wp: int):
	var center: Vector2 = world.AlliedFinale.AI.waypoint(world,wp)
	for b in world.buildings:
		if world.actor_alive(b) and b.building_id=="CAOILD" and b.position.distance_to(center)<110.0: return b
	return null

static func oil_found(world, wp: int) -> bool:
	var site = oil(world,wp)
	return site!=null and (site.side=="ally" or world.position_explored_by("ally",site.position) or world.actor_visible_to("ally",site))

static func oil_orders(world) -> void:
	for u in world.units:
		if not belongs(world,u,THIRD) or not u.special.has("finale_oil_wp") or u.special.has("action"): continue
		var site = oil(world,int(u.special.finale_oil_wp))
		if site==null or site.side=="enemy":
			u.special.erase("finale_oil_wp")
			u.order_guard()
		else: Orders.use(u,"allied_engineer",site)

static func dispatch(world, command: Dictionary, driver) -> bool:
	var id := str(command.fields[2]).to_upper()
	if id=="08E9634C":
		# Create Team uses existing aircraft; do not conjure two new saucers.
		var count := 0
		for u in world.units:
			if not belongs(world,u,MAIN) or u.unit_id!="DISK" or u.special.has("finale_taunt_team") or u.embarked_in!=null: continue
			u.special.finale_taunt_team=true
			hunt_unit(world,u)
			count+=1
			if count==2: break
		return true
	var spawn: Dictionary = driver.resolve_spawn(command)
	if spawn.is_empty(): return false
	var at := Vector2(spawn.waypoint.uv[0],spawn.waypoint.uv[1])*55.0
	if command.trigger in ["0960ee5c","04f32afc","090ad17c"]:
		return opening_defense(world,command,spawn,at)
	if id=="07AB65CC":
		# Action 4 recruits an existing Boomer, not a free reinforcement.
		var boat = null
		for u in world.units:
			if not belongs(world,u,THIRD) or u.unit_id!="BSUB": continue
			if boat==null or u.position.distance_squared_to(at)<boat.position.distance_squared_to(at): boat=u
		if boat!=null:
			boat.special.finale_naval_response=true
			hunt_unit(world,boat)
		return true
	if id in ["092F5EFC","092F59DC"]:
		var wp := 43 if id=="092F5EFC" else 44
		var site = oil(world,wp)
		if site==null or site.side=="enemy": return true
		var u = world.spawn_unit("ENGINEER","enemy",at)
		if u==null: return false
		u.special.allied_finale_room =THIRD
		u.refresh_house_color()
		u.special.finale_oil_wp=wp
		Orders.use(u,"allied_engineer",site)
		if world.actor_visible_to("ally",site): Events.emit_radar_ping(site.position,"alert")
		return true
	return false

# Action 4 forms a team from the field; action 7 brings in new units.
static func opening_defense(world,command: Dictionary,spawn: Dictionary,at: Vector2) -> bool:
	var house: String = MAIN if command.house=="YuriCountry" else SECOND
	var team_id := str(command.fields[2]).to_upper()
	var script: Dictionary = spawn.team.script
	var key := 0
	var recruited := []
	while spawn.team.task_force.has(str(key)):
		var item: PackedStringArray = str(spawn.team.task_force[str(key)]).split(",")
		for i in int(item[0]):
			var u = null
			if int(command.opcode)==4:
				for candidate in world.units:
					if not belongs(world,candidate,house) or candidate.unit_id!=item[1] or candidate.embarked_in!=null or candidate.special.has("finale_defense_team"): continue
					if u==null or candidate.position.distance_squared_to(at)<u.position.distance_squared_to(at): u=candidate
			else:
				var point: Vector2 = world.AlliedFinale.OpeningDrop.open_ground(world,at)
				if point.is_finite(): u=world.spawn_unit(item[1],"enemy",point)
				if u!=null:
					u.special.allied_finale_room=house
					u.refresh_house_color()
			if u==null: continue # No substitute units from another house or factory.
			u.special.finale_defense_team=team_id
			recruited.append(u)
		key+=1
	for u in recruited:
		if str(script.get("0","")).begins_with("62,"):
			u.special.finale_reactor_anchor=at
			if not assign_reactor(world,u): u.order_guard()
			continue
		var legs: Array[Vector2] = []
		for i in script.size():
			var fields: PackedStringArray = str(script.get(str(i),"")).split(",")
			if fields[0]=="3": legs.append(world.AlliedFinale.AI.waypoint(world,int(fields[1])))
		if legs.is_empty():
			u.order_guard()
			u.special.campaign_area_guard=at
			var post: Vector2 = world.path_service.nearest_reachable(at,u.position,false,5)
			if post.is_finite() and u.position.distance_to(post)>95.0: u.order_move(post,true)
		else:
			u.special.erase("campaign_area_guard")
			u.order_move(legs.pop_front(),true)
			for point in legs: u.queue_waypoint(point,null,true)
			# Script jumps to its second instruction; once at the last leg,
			# renew the original 41→40→39 patrol in the battle adapter.
			var repeat: Array[int] = []
			var step_count := 0
			while script.has(str(step_count)): step_count+=1
			var jump: PackedStringArray = str(script.get(str(step_count-1),"")).split(",")
			if jump[0]=="6":
				for i in range(int(jump[1]),step_count-1):
					var step: PackedStringArray = str(script.get(str(i),"")).split(",")
					if step[0]=="3": repeat.append(int(step[1]))
			if not repeat.is_empty(): u.special.finale_prism_patrol=repeat
	return true

static func assign_reactor(world,u) -> bool:
	var best = null
	var anchor: Vector2 = u.special.finale_reactor_anchor
	for site in world.buildings:
		if not belongs(world,site,actor_room(u)) or site.building_id!="YAPOWR" or not Orders.can_order(u,site,"allied_garrison"): continue
		var en_route: int = world.units.filter(func(v):return world.actor_alive(v) and v.special.get("action")=="allied_garrison" and v.special.get("target")==site).size()
		if en_route+site.special.get("occupants",[]).size()>=int(site.data.garrison_slots): continue
		if best==null or anchor.distance_squared_to(site.position)<anchor.distance_squared_to(best.position): best=site
	return best!=null and Orders.use(u,"allied_garrison",best)

static func defense_orders(world) -> void:
	for u in world.units:
		if not world.actor_alive(u) or u.side!="enemy" or u.embarked_in!=null or not u.special.has("finale_prism_patrol") or u.has_move_order or u.attack_ordered: continue
		var steps: Array = u.special.finale_prism_patrol
		u.order_move(world.AlliedFinale.AI.waypoint(world,int(steps[0])),true)
		for i in range(1,steps.size()): u.queue_waypoint(world.AlliedFinale.AI.waypoint(world,int(steps[i])),null,true)

static func hunt_unit(world,u) -> void:
	u.special.erase("campaign_area_guard")
	u.set_fire_stance("free")
	var goal: Vector2 = world.AlliedFinale.AI.target(world,false)
	if u.is_naval:
		var water := Vector2.INF
		var distance := INF
		for b in world.buildings:
			if not world.actor_alive(b) or b.side!="ally" or b.building_id not in ["GAYARD","NAYARD"]: continue
			var p: Vector2 = world.path_service.nearest_reachable(b.position,u.position,true,12)
			if p.distance_squared_to(u.position)<distance:
				water=p
				distance=p.distance_squared_to(u.position)
		if not water.is_finite(): water=world.path_service.nearest_reachable(goal,u.position,true,30)
		goal=water
	u.order_move(goal,true)

static func hunt(world,house: String) -> void:
	for u in world.units:
		if belongs(world,u,house) and u.embarked_in==null: hunt_unit(world,u)

static func fire_sale(world, house: String) -> void:
	var sold := false
	for b in world.buildings.duplicate():
		if not belongs(world,b,house) or b.building_id=="CAOILD" or b.data.get("unsellable",false): continue
		var refund: float = GameData.ra2_refund(int(b.data.get("cost",0))) + b.total_production_paid()
		b.retire_sold()
		world.buildings.erase(b)
		world.rally_points.erase(b.get_instance_id())
		world.credit_side("enemy",refund)
		sold=true
	if sold:
		world.invalidate_building_membership()
		world._refresh_pathing()
		world._update_power()
