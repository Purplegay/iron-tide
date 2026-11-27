extends RefCounted

# Unarmed residents from ALL02UMD. The mission also uses civilian art for armed film stars.
const RESIDENTS := ["CIV1","CIV2","CIV3","CIVBF","CIVBFM","CIVBTM","CIVSF","CIVSFM","CIVSTM"]

static func map_cell(x:int,y:int) -> Vector2:
	return (Vector2(206-y,x-12)+Vector2.ONE*0.5)*preload("res://scripts/world/native_maps.gd").CELL

static func populate(w) -> void:
	for row in GameData.hollywood_cast.placements:
		var id:String=row.id
		if id in ["CLNT","ARND","STLN"]: continue
		var p:=map_cell(row.x,row.y)
		var side: String = "neutral" if row.house == "Neutral" or id in RESIDENTS else "enemy"
		if GameData.hollywood_cast.buildings.has(id):
			var tile:=Vector2i(int(row.x),int(row.y))
			var center:Vector2=w.Hollywood.retail_site_center(id,tile)
			if not w.buildings.any(func(b):return w.actor_alive(b) and b.building_id==id and b.position.is_equal_approx(center)):
				var site=w._place_building(id,side,center,true)
				if site!=null:
					site.special.hollywood_retail_cell=tile
					site._buildup_play=-1.0
			continue
		var ground:Vector2=w.path_service.nearest_reachable(p,p,false,8)
		if not ground.is_finite(): continue
		var u=w.spawn_unit(id,side,ground)
		if u:
			u.order_stop(false)
			u.special.hollywood_house=row.house
			w.Hollywood.RetailSequences.prisoner_tag(u,row.house,int(row.x),int(row.y))
			var star:String=w.Hollywood.star_guard_label(id,int(row.x),int(row.y))
			if not star.is_empty():u.special.hollywood_star_guard=star
			u.hp=u.max_hp*float(row.hp)
			if side=="neutral": u.set_fire_stance("none")

static func assign_guards(w,difficulty:int) -> void:
	for b in w.buildings:
		if b.side!="enemy" or b.building_id not in ["NATBNK","YAGRND","YABRCK"]: continue
		var bunker:bool = b.building_id=="NATBNK"
		if bunker and difficulty==0: continue
		var nearest = null
		var best := INF
		for u in w.units:
			if u.side!="enemy" or u.unit_id!=("LTNK" if bunker else "INIT") or u.embarked_in!=null or u.special.has("hollywood_patrol"): continue
			var distance:float = u.position.distance_squared_to(b.position)
			if distance<best:
				nearest=u
				best=distance
		if nearest==null: continue
		if bunker: preload("res://scripts/units/civilian_orders.gd").enter(nearest,b)
		else: nearest.special.hollywood_patrol=b.position

# Keep historical indices 0..5 for saved in-progress teams.
const ASSAULTS = preload("res://data/maps/hollywood_retail_ai.json").data

const CONDITION_ROWS = preload("res://data/maps/hollywood_drivers.json").data.ai

static func threshold_passes(spec:Dictionary,count:float,difficulty:int) -> bool:
	if spec.is_empty() or not spec.enabled or int(spec.mask[difficulty])==0:return false
	var t:=float(spec.threshold)
	match int(spec.op):
		0:return count<t
		1:return count<=t
		2:return count==t
		3:return count>=t
		4:return count>t
		5:return count!=t
	return false

static func eligible(w,row:Array) -> bool:
	var difficulty:=clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)
	var spec:Dictionary=CONDITION_ROWS.get(row[0],{})
	if spec.is_empty() or not spec.enabled or int(spec.mask[difficulty])==0:return false
	var count:=0.0
	if int(spec.condition)==4:
		count=w.funds_for("ally") # Retail condition 4 queries the opponent's credits.
	else:
		for actor in w.units+w.buildings:
			if not w.actor_alive(actor):continue
			if int(spec.condition)==0 and actor.side!="ally":continue
			if int(spec.condition)==1 and (actor.side!="enemy" or actor.special.get("hollywood_house")!=row[1]):continue
			if (actor.unit_id if actor is Unit else actor.building_id)==spec.entity:count+=1
	return threshold_passes(spec,count,difficulty)

static func tick(w,s:Dictionary,elapsed:float) -> void:
	advance_retail_groups(w,s,elapsed)
	advance_retail_attacks(w,s)
	preload("res://scripts/world/slave_mining.gd").tick(w,elapsed)
	for b in w.buildings:
		if w.actor_alive(b) and b.building_id=="NAPSIS": sense(w,b)
	for house in ["YuriCountry","Yuri2"]:
		if s.get("withdrawals",{}).has(house):continue
		var orders:Dictionary=s.get_or_add("retail_order_"+house,{"wait":90.0})
		if orders.has("index"):
			advance(w,house,orders)
			continue
		orders.wait=float(orders.wait)-elapsed
		if orders.wait>0:continue
		var candidates:=[]
		var weights:=PackedFloat32Array()
		for i in ASSAULTS.size():
			var row:Array=ASSAULTS[i]
			if not selectable(w,house,row):continue
			candidates.append(i);weights.append(float(CONDITION_ROWS[row[0]].weight))
		if candidates.is_empty():orders.wait=2.0;continue
		var rng:=RandomNumberGenerator.new()
		rng.randomize()
		orders.index=candidates[rng.rand_weighted(weights)]
		orders.next=0
		orders.members=[]
		advance(w,house,orders)

static func selectable(w,house:String,row:Array) -> bool:
	return row[1]==house and eligible(w,row) and not row[5].is_empty() and row[5].all(func(id):return factory_for(w,house,id)!=null)

static func factory_for(w,house:String,id:String):
	for b in w.buildings:
		if w.actor_alive(b) and b.side=="enemy" and b.special.get("hollywood_house")==house and b.buildable.has(id):return b
	return null

static func advance(w,house:String,orders:Dictionary) -> void:
	var row:Array=ASSAULTS[int(orders.index)]
	if orders.has("factory"):
		var source=orders.factory
		if w.actor_alive(source) and source.side=="enemy" and source.production.has(orders.product):return
		orders.erase("factory")
	if int(orders.next)<row[5].size():
		var uid:String=row[5][int(orders.next)]
		var b=factory_for(w,house,uid)
		if b!=null:
			if b.is_operational() and b.production.is_empty() and b.enqueue(uid):
				orders.factory=b;orders.product=uid
				b.special.hollywood_retail_order=uid
			return
		# A lost production site must not strand a half-built formation forever.
		# Release surviving units and let the next selection recheck all factories.
	var members:Array=orders.members.filter(func(u):return w.actor_alive(u) and u.side=="enemy" and u.special.get("hollywood_house")==house)
	var scenario_assembled:=false
	if int(orders.next)==row[5].size() and members.size()==row[5].size():
		scenario_assembled=w.Hollywood.RetailSequences.assembled_team(w,w.allied_state.hollywood,row,members)
	if scenario_assembled:pass
	elif not members.is_empty() and int(orders.next)==row[5].size() and gathering(row):
		start_retail_group(w,w.allied_state.hollywood,row,members)
	else:
		for u in members:deploy_team_member(w,u,row)
	orders.clear();orders.wait=90.0

static func gathering(row:Array) -> bool:
	return row[10].any(func(cmd):return int(cmd[0]) in [53,54])

static func start_retail_group(w,s:Dictionary,row:Array,members:Array) -> void:
	var commands:Array=row[10].filter(func(cmd):return int(cmd[0]) in [3,16,53,54])
	s.get_or_add("retail_groups",[]).append({"row":row[0],"members":members,"commands":commands,"index":0,"move_left":0.0})
	advance_retail_groups(w,s,0.0)

static func advance_retail_groups(w,s:Dictionary,elapsed:float) -> void:
	var groups:Array=s.get("retail_groups",[])
	for group in groups.duplicate():
		var i:int=ASSAULTS.find_custom(func(r):return r[0]==group.row)
		if i<0:groups.erase(group);continue
		var row:Array=ASSAULTS[i]
		group.members=group.members.filter(func(u):return w.actor_alive(u) and u.side=="enemy" and u.special.get("hollywood_house")==row[1])
		if group.members.is_empty() or s.get("withdrawals",{}).has(row[1]):groups.erase(group);continue
		if group.has("goals"):
			group.move_left=float(group.move_left)-elapsed
			var pending:=false
			for u in group.members:
				var point:Vector2=u.special.get("hollywood_group_goal",u.position)
				if u.position.distance_to(point)<=80.0:continue
				pending=true
				if not u.has_move_order and group.move_left>0.0:u.order_move(point,false,null,w.path_for_unit(u,point))
			if pending and group.move_left>0.0:continue
			for u in group.members:u.special.erase("hollywood_group_goal")
			group.erase("goals")
			group.index=int(group.index)+1
		if int(group.index)>=group.commands.size():
			for u in group.members:
				var quarries:Array=retail_quarries(row)
				if quarries.is_empty():u.order_guard()
				else:
					u.special.hollywood_quarries=quarries
					attack_next_quarry(w,u)
			groups.erase(group);continue
		var cmd:Array=group.commands[int(group.index)]
		var op:=int(cmd[0])
		var center:Vector2=group.members[0].position
		if op in [3,16]:
			var coord:=int(GameData.hollywood_cast.waypoints.get(str(int(cmd[1])),0))
			if coord>0:center=map_cell(coord%1000,coord/1000)
		for j in group.members.size():
			var u=group.members[j]
			var desired:Vector2=center+Vector2.RIGHT.rotated(float(j)*2.4)*float(j)*22.0
			var piece:Vector2=w.path_service.nearest_reachable(desired,u.position,false,10)
			if piece.is_finite():
				u.special.hollywood_group_goal=piece
				u.order_move(piece,op==16,null,w.path_for_unit(u,piece))
		group.goals=true
		group.move_left=120.0

static func sense(w,b) -> void:
	var pips:Array=[]
	if b.is_operational() and not w.side_power_low(b.side):
		for u in w.units:
			if not w.actor_alive(u) or u.side=="neutral" or BattleRequest.friendly(u.side,b.side) or u.embarked_in!=null: continue
			var goal:Vector2
			if w.actor_alive(u.attack_target): goal=u.attack_target.position
			elif u.has_move_order: goal=u.move_target
			else: continue
			if goal.distance_to(b.position)<=15*55: pips.append([u.position,goal])
	if b.special.get("psychic_orders",[])!=pips:
		b.special.psychic_orders=pips
		b.queue_redraw()

static func dispatch(w,u,producer) -> void:
	if producer.side!="enemy":return
	u.special.hollywood_house=producer.special.get("hollywood_house","")
	if producer.special.get("hollywood_retail_order","")==u.unit_id:
		producer.special.erase("hollywood_retail_order")
		var orders:Dictionary=w.allied_state.hollywood.get("retail_order_"+str(u.special.hollywood_house),{})
		if orders.get("factory")==producer:
			orders.next=int(orders.next)+1
			orders.members.append(u)
			orders.erase("factory")
			return
	if not producer.special.has("hollywood_wave"):return
	var teams:Array=GameData.hollywood_cast.teams
	var team:Dictionary=teams[int(producer.special.hollywood_wave)%teams.size()]
	march(w,u,team.route)

static func deploy_team_member(w,u,row:Array) -> void:
	var commands:Array=row[10]
	if not commands.is_empty() and int(commands[0][0])==11:
		u.order_guard()
		# 11 assigns a mission; its parameter 11 is YR Area Guard, not a duration.
		if int(commands[0][1])==11:
			u.cancel_stance()
			u.special.campaign_area_guard=u.global_position
		return
	if not commands.is_empty() and int(commands[0][0]) in [62,64]:
		var site=null
		var best:=INF
		for b in w.buildings:
			if not w.actor_alive(b):continue
			if int(commands[0][0])==62 and (b.building_id!="YAPOWR" or b.special.get("hollywood_house")!=row[1]):continue
			if int(commands[0][0])==64 and b.side!="neutral":continue
			if not preload("res://scripts/units/civilian_orders.gd").can_enter(u,b):continue
			var distance:float=u.position.distance_squared_to(b.position)
			if distance<best:best=distance;site=b
		if site!=null and u.order_interaction("allied_garrison",site,false):return
		u.order_guard()
		return
	var route:Array=retail_route(row)
	var categories:Array=retail_quarries(row)
	if not categories.is_empty():u.special.hollywood_quarries=categories
	if route.is_empty():
		if categories.is_empty():march(w,u,row[6],true)
		else:attack_next_quarry(w,u)
		return
	u.clear_queue()
	var first:Array=route[0]
	var point:Vector2=first[0]
	u.order_move(point,first[1],null,w.path_for_unit(u,point))
	for i in range(1,route.size()):u.queue_waypoint(route[i][0],null,route[i][1])
	if categories.is_empty():u.queue_waypoint(w._player_target(),null,true)

static func retail_quarries(row:Array) -> Array:
	return row[10].filter(func(cmd):return int(cmd[0])==0).map(func(cmd):return int(cmd[1]))

static func quarry_matches(target,category:int) -> bool:
	match category:
		1:return true
		2:return target is Building
		3:return target is Unit and target.is_harvester
		4:return target is Unit and AlliedAbilities.infantry(target)
		5:return target is Unit and not target.is_air and not AlliedAbilities.infantry(target)
		6:return target is Building and not target.buildable.is_empty()
		7:return target is Building and (target.data.get("tags",[]).has("defense") or not target.data.get("weapon",{}).is_empty())
		9:return target is Building and target.power>0
	return false

static func attack_next_quarry(w,u) -> void:
	var categories:Array=u.special.hollywood_quarries
	while not categories.is_empty():
		var best=null
		var distance:=INF
		var obscured:=false
		for target in w.units+w.buildings:
			if not w.actor_alive(target) or target.side!="ally" or not quarry_matches(target,int(categories[0])):continue
			if target is Unit and target.embarked_in!=null:continue
			if not w.actor_visible_to(u.side,target):obscured=true;continue
			if not u.attack_domain_valid(target):continue
			var d:float=u.position.distance_squared_to(target.position)
			if d<distance:distance=d;best=target
		if best!=null:u.order_target(best,false,false);return
		if obscured:
			# Preserve the current quarry while approaching the usual mission rally point.
			var goal:Vector2=w._player_target()
			if u.position.distance_to(goal)>55.0:u.order_move(goal,true,null,w.path_for_unit(u,goal))
			return
		categories.pop_front()
	u.special.erase("hollywood_quarries")

static func advance_retail_attacks(w,s:Dictionary) -> void:
	for u in w.units:
		if not w.actor_alive(u) or not u.special.has("hollywood_quarries"):continue
		if u.side!="enemy" or s.get("withdrawals",{}).has(u.special.get("hollywood_house","")):
			u.special.erase("hollywood_quarries");continue
		if u.embarked_in!=null or u.has_move_order or not u.order_queue.is_empty():continue
		if u.attack_ordered and w.actor_alive(u.attack_target) and u.attack_target.side=="ally":continue
		attack_next_quarry(w,u)

static func retail_route(row:Array) -> Array:
	var route:Array=[]
	for cmd in row[10]:
		var op:=int(cmd[0])
		if op not in [3,16]:continue
		var coord:=int(GameData.hollywood_cast.waypoints.get(str(int(cmd[1])),0))
		if coord<=0:return []
		route.append([map_cell(coord%1000,coord/1000),op==16])
	return route

static func march(w,u,waypoints:Array,raw_coordinates:=false) -> void:
	var route:PackedVector2Array=[]
	for waypoint in waypoints:
		var coord:=int(waypoint) if raw_coordinates else int(GameData.hollywood_cast.waypoints.get(str(int(waypoint)),0))
		if coord>0:route.append(map_cell(coord%1000,coord/1000))
	route.append(w._player_target())
	u.order_move(route[0],true,null,w.path_for_unit(u,route[0]))
	for i in range(1,route.size()): u.queue_waypoint(route[i],null,true)
