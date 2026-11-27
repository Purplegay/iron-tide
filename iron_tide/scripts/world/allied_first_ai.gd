extends RefCounted
## ALL01 enables Confederation production through Build_Dom, then disables it on yard transfer.
const TABLE = preload("res://data/ra2/allied_first_ai.json")
const Flak = preload("res://scripts/world/allied_first_flak.gd")
const ROOM := "Confederation"
const ORDER := "all01_ai_order"

static func owned(world,actor) -> bool:
	return world.actor_alive(actor) and actor.side=="enemy" and actor.special.get("allied_first_room","")==ROOM

static func tick(world,s: Dictionary,delta: float) -> void:
	Flak.tick(world,s,delta)
	if not s.get("confederation_production",false): return
	var level := clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)
	var left := float(s.get("global_ai_left",0.0))-delta
	if left>0.0:
		s.global_ai_left = left
		return
	s.global_ai_left = float(TABLE.data.team_delays[level])/BattleClock.RULE_TICKS_PER_SECOND
	var choices := []
	var weights := PackedFloat32Array()
	for row in TABLE.data.rows:
		if not row.enabled or not row.difficulty[level] or row.tech>TABLE.data.rooms[ROOM].tech: continue
		var factory = Flak.factory_for(world,s,row) if row.has("threat") else miner_factory(world,row)
		if factory!=null:
			choices.append([row,factory])
			weights.append(float(row.weight))
	if choices.is_empty(): return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.get("all01_ai_seed",world.match_id.hash()))
	var picked: Array = choices[rng.rand_weighted(weights)]
	s.all01_ai_seed = rng.randi()
	var row: Dictionary = picked[0]
	var maker = picked[1]
	if not maker.enqueue(row.product): return
	maker.special[ORDER] = row.id
	if row.has("threat"): Flak.begin(s,maker,row)

static func miner_factory(world,row):
	var count := 0
	var active := 0
	for u in world.units:
		if not owned(world,u) or u.unit_id!=row.own_type: continue
		count+=1
		if u.special.get("allied_first_ai","")!=row.id or not u.special.has("allied_first_ai_leg"): continue
		var leg: Array = u.special.allied_first_ai_leg
		if u.has_move_order and u.move_target.is_equal_approx(Vector2(leg[0],leg[1])): active+=1
		else: u.special.erase("allied_first_ai_leg")
	if count>row.maximum or active>=row.team_max: return null
	var factory = null
	var refinery = null
	for b in world.buildings:
		if not owned(world,b): continue
		if b.special.get(ORDER,"")==row.id:
			if b.production.has(row.product): return null
			b.special.erase(ORDER)
		if not b.is_operational(): continue
		if b.building_id==row.target: refinery=b
		if b.building_id=="NAWEAP" and b.production.is_empty() and b.can_queue(row.product): factory=b
	return factory if refinery!=null else null

static func produced(world,u,b) -> void:
	var id: String = b.special.get(ORDER,"")
	if id.is_empty(): return
	for row in TABLE.data.rows:
		if id!=row.id or u.unit_id!=row.product: continue
		if row.has("threat"):
			Flak.produced(world,b,u,row)
			return
		b.special.erase(ORDER)
		if not owned(world,b): return
		u.special.allied_first_room = ROOM
		u.special.allied_first_team = row.team
		u.special.allied_first_ai = row.id
		u.refresh_house_color()
		for site in world.buildings:
			if owned(world,site) and site.building_id==row.target:
				var point: Vector2 = world.AlliedFirst.Orders.approach(u,site)
				u.order_move(point)
				u.special.allied_first_ai_leg = [u.move_target.x,u.move_target.y]
				return
