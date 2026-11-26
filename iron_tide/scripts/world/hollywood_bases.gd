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
			if not w.buildings.any(func(b):return b.building_id==id and b.position.distance_to(p)<100): w._place_building(id,side,p,true)
			continue
		var ground:Vector2=w.path_service.nearest_reachable(p,p,false,8)
		if not ground.is_finite(): continue
		var u=w.spawn_unit(id,side,ground)
		if u:
			u.order_stop(false)
			u.special.hollywood_house=row.house
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

static func tick(w,s:Dictionary,elapsed:float) -> void:
	preload("res://scripts/world/slave_mining.gd").tick(w,elapsed)
	for b in w.buildings:
		if w.actor_alive(b) and b.building_id=="NAPSIS": sense(w,b)
	for house in ["YuriCountry","Yuri2"]:
		var orders:Dictionary=s.get_or_add("order_"+house,{"wait":90.0,"wave":0,"sent":0})
		orders.wait-=elapsed
		if orders.wait>0: continue
		var team:Dictionary=GameData.hollywood_cast.teams[int(orders.wave)%GameData.hollywood_cast.teams.size()]
		var uid:String=team.units[int(orders.sent)]
		for b in w.buildings:
			if not w.actor_alive(b) or b.side!="enemy" or b.special.get("hollywood_house")!=house or not b.is_operational() or not b.production.is_empty(): continue
			if not b.data.get("builds",[]).has(uid): continue
			if b.enqueue(uid):
				b.special.hollywood_wave=orders.wave
				orders.sent+=1
				if orders.sent==team.units.size():
					orders.sent=0
					orders.wave+=1
					orders.wait=90.0
			break
		orders.wait=maxf(orders.wait,2.0)

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
	if producer.side != "enemy" or not producer.special.has("hollywood_wave"):return
	var teams:Array=GameData.hollywood_cast.teams
	var team:Dictionary=teams[int(producer.special.hollywood_wave)%teams.size()]
	var route:PackedVector2Array=[]
	for waypoint in team.route:
		var coord:=int(GameData.hollywood_cast.waypoints[str(int(waypoint))])
		route.append(map_cell(coord%1000,coord/1000))
	route.append(w._player_target())
	u.special.hollywood_house=producer.special.hollywood_house
	u.order_move(route[0],true,null,w.path_for_unit(u,route[0]))
	for i in range(1,route.size()): u.queue_waypoint(route[i],null,true)
