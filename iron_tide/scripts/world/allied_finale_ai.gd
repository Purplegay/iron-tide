extends RefCounted
## Selected ALL07SMD raids and factory teams, not general skirmish AI.
const Data = preload("res://data/ra2/allied_finale_ai.json")
const Rooms := ["YuriCountry", "Yuri2", "Yuri3"]
const Landings := [106,107,106,107]
const Delays := [75.0,75.0,90.0,90.0,90.0]
# ALL07SMD Send_Hover*_Home → return team's first ScriptType waypoint.
const INFANTRY_RETURN := [520,522,532,532]
const ARMOR_RETURN := [528,530,520,534,536]
const RETURN_TRIGGER := {"08D5D5FC":"0bdca03c","08D686CC":"0464d1bc","08D680EC":"0b7a95fc","08D6945C":"0b2bd0fc","08D57B5C":"096a485c","08D6BA4C":"0b7f91ac","08D6CB7C":"0b7fe1ac","08D6DC8C":"0b84b0fc","08D6D18C":"0b7f92fc"}
const NEXT_LOCAL := {"08D5D5FC":5,"08D686CC":6,"08D680EC":8,"08D6945C":22,"08D57B5C":11,"08D6BA4C":12,"08D6CB7C":13,"08D6DC8C":14}

static func fire_superweapons(world) -> void:
	# ALL07SMD YuriCountry IQ=5; rulesmd [IQ] SuperWeapons=4.
	# This is house AI, not a one-shot map trigger. Aim only at actionable contacts.
	for launcher in world.buildings:
		if launcher.building_id not in ["YAGNTC", "YAPPET"] or not world.AlliedFinale.cleanup_target(world, launcher, ["YuriCountry"]) or not launcher.sw_ready(): continue
		var mutate: bool = launcher.building_id == "YAGNTC"
		var fired := false
		for unit in world.units:
			if not world.actor_alive(unit) or unit.side != "ally" or unit.embarked_in != null or unit.is_air: continue
			if mutate:
				if not AlliedAbilities.infantry(unit) or unit.unit_id == "BRUTE": continue
			elif AlliedAbilities.flag(unit, "ImmuneToPsionics"):
				continue
			if world.actor_visible_to("enemy", unit) and launcher.fire_superweapon(unit.position):
				fired = true
				break
		if mutate or fired: continue
		for site in world.buildings:
			if world.actor_alive(site) and site.side == "ally" and world.actor_visible_to("enemy", site) and launcher.fire_superweapon(site.position): break

static func is_raid_row(id: String) -> bool:
	return Data.data.raids.any(func(row):return row.id==id) or Data.data.armor_raids.any(func(row):return row.id==id)

static func drive_raid(world,s: Dictionary,trigger: String,d) -> bool:
	for group in [Data.data.raids,Data.data.armor_raids]:
		for i in group.size():
			if group[i].id == trigger:
				if not raid(world,s,i,group==Data.data.armor_raids): return false
				for event in d.rows[trigger].events:
					if event[0]=="36" and int(event[2]) in NEXT_LOCAL.values(): d.set_local(int(event[2]),false)
				return true
	return false

static func prepare_raid_driver(world,s: Dictionary,d) -> void:
	if not s.get("raid_driver",false): return
	if not d.state.fired.has("0960d93c") and not d.state.enabled.has("0960d93c") and d.state.locals["0"]:
		d.enable("0960d93c")
	for u in world.units:
		if not world.actor_alive(u) or u.side!="enemy" or not u.special.has("allied_finale_raid") or not u.logistics.passengers.is_empty(): continue
		var order: Dictionary = u.special.allied_finale_raid
		var key: String = order.get("team","")
		if not order.get("driver_next_committed",false) and NEXT_LOCAL.has(key):
			order.driver_next_committed=true
			d.set_local(NEXT_LOCAL[key],true)
	if s.has("armor_active_team") and not world.units.any(func(u):return world.actor_alive(u) and u.side=="enemy" and u.special.get("allied_finale_raid",{}).get("team","")==s.armor_active_team):
		# Preserve the explicit lost-transport fallback without faking a return event.
		if NEXT_LOCAL.has(s.armor_active_team): d.set_local(NEXT_LOCAL[s.armor_active_team],true)
		if s.get("armor_outcome","")=="in_transit": s.armor_outcome="lost"

const RETURN_LOCAL := {"0bdca03c":2,"0464d1bc":3,"0b7a95fc":7,"0b2bd0fc":9,"096a485c":16,"0b7f91ac":18,"0b7fe1ac":19,"0b84b0fc":20,"0b7f92fc":21}

static func queue_returns(world, d) -> void:
	for u in world.units:
		if not world.actor_alive(u) or u.side!="enemy" or not u.special.has("allied_finale_raid") or not u.logistics.passengers.is_empty(): continue
		var order: Dictionary = u.special.allied_finale_raid
		var id: String = RETURN_TRIGGER.get(order.get("team",""),"")
		if not id.is_empty() and not order.get("return_dispatched",false) and d.enable(id):
			d.set_local(RETURN_LOCAL[id],true)
			order.wait_for_return_action=true

static func dispatch_return(world, trigger: String) -> bool:
	if not RETURN_LOCAL.has(trigger): return false
	for u in world.units:
		if not world.actor_alive(u) or u.side!="enemy" or not u.special.has("allied_finale_raid"): continue
		var r: Dictionary = u.special.allied_finale_raid
		if RETURN_TRIGGER.get(r.get("team",""),"")!=trigger or not r.get("wait_for_return_action",false): continue
		r.erase("wait_for_return_action")
		r.return_dispatched=true
	return true

static func waypoint(world, id: int) -> Vector2:
	var p: Array = world.NativeMaps.data(world.map_layout()).waypoints[str(id)]
	return Vector2(p[0],p[1])*55.0

static func room_ids(world, room: String) -> Array:
	var ids := []
	for b in world.buildings:
		if world.actor_alive(b) and not b.under_construction and b.side=="enemy" and b.special.get("allied_finale_room")==room:
			ids.append(b.building_id)
	return ids

static func target(world, tierra: bool) -> Vector2:
	if tierra:
		for b in world.buildings:
			if world.actor_alive(b) and b.side=="ally" and b.special.get("allied_finale_room")=="Special" and b.building_id=="NACNST":
				return b.position
		return waypoint(world,106)
	var best := Vector2.INF
	var insertion := waypoint(world,26)
	for b in world.buildings:
		if not world.actor_alive(b) or b.side!="ally" or not b.is_hq: continue
		if not best.is_finite() or insertion.distance_squared_to(b.position)<insertion.distance_squared_to(best): best=b.position
	return best if best.is_finite() else insertion

static func raid(world, s: Dictionary, index: int, armored := false) -> bool:
	var row: Dictionary = (Data.data.armor_raids if armored else Data.data.raids)[index]
	var wp := 0
	for ch in str(row.team.entry): wp = wp*26 + ch.unicode_at(0)-64
	var entry := waypoint(world,wp-1)
	# TZ is a separate overland team, not another loaded hovercraft.
	if not armored and not row.team.units.any(func(item): return item[0]=="YHVR"):
		for item in row.team.units:
			for i in int(item[1]):
				var start: Vector2 = world.path_service.nearest_reachable(entry+Vector2(i*24,0),entry,false,5)
				var u = world.spawn_unit(str(item[0]),"enemy",start)
				if u==null: continue
				u.special.allied_finale_room =row.team.house
				u.refresh_house_color()
				u.special.finale_land_raid=row.team.id
				u.order_move(waypoint(world,521))
				u.queue_waypoint(waypoint(world,106),null,true)
				u.queue_waypoint(target(world,true),null,true)
		s.raid_index=index+1
		return true
	# The first two retail entrances are outside the imported playable mask.
	var start := Vector2.INF
	var dist := INF
	for step in world.NativeMaps.data(world.map_layout()).cells:
		if int(step[2])!=9: continue
		var p := Vector2(float(step[0])+0.5,float(step[1])+0.5)*55.0
		var d := p.distance_squared_to(entry)
		if d<dist:
			start=p
			dist=d
	if not start.is_finite(): return false
	var boat = world.spawn_unit("YHVR","enemy",start)
	if boat==null: return false
	boat.special.allied_finale_room = row.team.house
	boat.refresh_house_color()
	var beach := waypoint(world, (106 if index % 2 == 0 else 107) if armored else Landings[index])
	var approach: Vector2 = world.path_service.nearest_reachable(beach,start,false,6,true)
	if not approach.is_finite(): approach = beach
	boat.special.allied_finale_raid = {"beach":approach, "return":start, "team":row.team.id,
		"return_wp":(ARMOR_RETURN if armored else INFANTRY_RETURN)[index]}
	if armored:
		boat.special.allied_finale_raid.armor_stage = index
		boat.special.allied_finale_raid.unload_committed = false
		s.armor_active_team = row.team.id
		s.armor_outcome = "in_transit"
	for entry_row in row.team.units:
		if entry_row[0]=="YHVR": continue
		for i in int(entry_row[1]):
			var u = world.spawn_unit(str(entry_row[0]),"enemy",start)
			if u==null: continue
			u.special.allied_finale_room = row.team.house
			u.refresh_house_color()
			u.special.allied_finale_raid_member = true
			if armored and index == 0: u.special.allied_finale_confed = true
			u.set_stowed(boat)
			boat.logistics.passengers.append(u)
	boat.order_move(approach)
	s["armor_raid_index" if armored else "raid_index"] = index+1
	if armored and index == 0: s.confed_clear_clock = 0.0
	return true

static func armor_schedule(world, s: Dictionary, owned: Array, elapsed: float) -> void:
	# 046336EC is BuildingExists and latches locals 1/10; SBarracks_Built latches 0.
	if "NAHAND" in owned: s.raid_barracks_seen = true
	if "NAWEAP" in owned: s.raid_factory_seen = true
	if not s.get("raid_factory_seen",false): return
	# Old previews saved the ordinal, but not the unload interlock. Do not replay
	# already spawned waves. If their boat still exists, it owns the interlock.
	if not s.has("armor_unloaded"):
		var previous := int(s.get("armor_raid_index",0))-1
		s.armor_unloaded = previous < 0 or not world.units.any(func(u):
			return world.actor_alive(u) and u.special.get("allied_finale_raid",{}).get("team", "") == Data.data.armor_raids[mini(previous,4)].team.id and not u.logistics.passengers.is_empty())
	if s.has("confed_clear_clock"):
		s.confed_clear_clock=float(s.confed_clear_clock)+elapsed
		if s.confed_clear_clock>=10.0 and not world.units.any(func(u):
			return world.actor_alive(u) and u.side=="enemy" and u.special.get("allied_finale_confed",false)):
			s.erase("confed_clear_clock")
	if not s.armor_unloaded and s.has("armor_active_team") and not world.units.any(func(u):
		return world.actor_alive(u) and u.side=="enemy" and u.special.get("allied_finale_raid",{}).get("team","")==s.armor_active_team):
		# The imported runtime can't run a script on a removed transport. Release
		# progression separately from the retail unload latch; never order a return.
		s.armor_outcome="lost"
		s.armor_unloaded=true
	var index := int(s.get("armor_raid_index",0)) % Data.data.armor_raids.size()
	s.armor_raid_clock = float(s.get("armor_raid_clock",0.0))+elapsed
	if not s.get("raid_barracks_seen",false) or not s.armor_unloaded or (index==0 and s.has("confed_clear_clock")): return
	if s.armor_raid_clock >= 90.0 and raid(world,s,index,true):
		s.armor_raid_clock=0.0
		s.armor_unloaded=false

static func tick(world, s: Dictionary, delta: float, candidate_pool: Array = []) -> void:
	if world.paused or world.ended or s.phase < 1: return
	s.ai_poll = float(s.get("ai_poll",0.0))+delta
	if s.ai_poll < 0.5: return
	var elapsed := float(s.ai_poll)
	s.ai_poll=0.0
	var owned: Array = world.owned_building_ids()
	var index := int(s.get("raid_index",0))
	if not s.get("raid_driver",false): armor_schedule(world,s,owned,elapsed)
	if not s.get("raid_driver",false) and not s.get("raid_factory_seen",false) and index < Data.data.raids.size() and "NAHAND" in owned:
		s.raid_clock = float(s.get("raid_clock",0.0))+elapsed
		if s.raid_clock >= Delays[index] and raid(world,s,index): s.raid_clock=0.0
	for u in world.units:
		if not world.actor_alive(u) or u.side!="enemy": continue
		if u.special.has("finale_engineer_rush") and u.embarked_in==null: engineer_rush(world,u)
		if u.special.has("allied_finale_raid"):
			var r: Dictionary = u.special.allied_finale_raid
			if u.logistics.passengers.is_empty():
				if not r.get("unload_committed",false) and (r.has("armor_stage") or Data.data.armor_raids.any(func(row):return row.team.id == r.get("team",""))):
					r.unload_committed=true
					if r.get("team","")==s.get("armor_active_team",r.get("team","")):
						s.armor_unloaded=true
						s.armor_outcome="unloaded"
				if r.get("wait_for_return_action",false) or (r.has("return_wp") and RETURN_TRIGGER.has(r.get("team","")) and not r.get("return_dispatched",false) and not s.script.get("fired",{}).has(RETURN_TRIGGER[r.team])): continue
				if r.has("return_wp") and not r.get("return_resolved",false):
					var desired := waypoint(world,int(r.return_wp))
					var exit: Vector2 = world.path_service.nearest_reachable(desired,u.position,true,24)
					if exit.is_finite() and exit.distance_to(desired)<24.0*55.0 and world.in_water_world(exit): r["return"]=exit
					r.return_resolved=true
					u.order_move(r["return"])
				if u.position.distance_to(r["return"]) < 60.0: u.queue_free()
				elif not u.has_move_order: u.order_move(r["return"])
			elif u.position.distance_to(r.beach)<220.0 and u.logistics.hover_can_unload_at(u.position):
				if not u.logistics.unloading: u.logistics.request_unload()
			elif u.logistics.unloading or not u.has_move_order or u.position.distance_to(r.beach)<220.0:
				var alternate := Vector2.INF
				for radius in [55.0,110.0,165.0,220.0]:
					for step in 12:
						var point: Vector2 = r.beach + Vector2.from_angle(TAU*step/12.0)*radius
						if not u._domain_ok(point) or not u.logistics.hover_can_unload_at(point): continue
						var route: PackedVector2Array = world.path_for_unit(u,point)
						if route.is_empty() or route[-1].distance_to(point)>42.0: continue
						alternate=point
						u.order_move(point,false,null,route)
						break
					if alternate.is_finite(): break
				if not alternate.is_finite() and not u.has_move_order and not u.logistics.unloading: u.order_move(r.beach)
		elif u.special.has("allied_finale_raid_member") and u.embarked_in==null:
			u.special.erase("allied_finale_raid_member")
			u.order_move(target(world,true),true)
	var due: Dictionary = s.get_or_add("ai_due",{})
	var jobs: Dictionary = s.get_or_add("ai_jobs",{})
	var difficulty := clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)
	for room in Rooms:
		if room=="Yuri3":
			var third: Dictionary = s.get("third_house",{})
			if not third.get("ai_enabled",false) or third.get("retired",false): continue
		elif not s.get("south_ai_enabled",false): continue
		if room=="Yuri2" and s.get("base_defense_driver",false) and not s.get("africa_hostile",false): continue
		var ids := room_ids(world,room)
		if "YAWEAP" not in ids and "YABRCK" not in ids:
			if jobs.has(room):
				for u in jobs[room].members:
					if world.actor_alive(u) and u.side=="enemy": u.order_move(target(world,false),true)
				jobs.erase(room)
			continue
		if not jobs.has(room):
			due[room]=maxf(0.0,float(due.get(room,[3500.0,2500.0,2000.0][difficulty]/15.0))-elapsed)
			if due[room] > 0.0: continue
			var choices := []
			var weights := PackedFloat32Array()
			# Isolated rule diagnostics can bound the candidate pool without bypassing eligibility.
			for rule in (Data.data.rules if candidate_pool.is_empty() else candidate_pool):
				if rule.room!=room or not rule.difficulty[difficulty]: continue
				# Third-house base teams are gated by their own factory, unlike threats
				# keyed to the player's Chronosphere/Iron Curtain. Preserve earlier rules.
				var count: int = ids.count(rule.related) if int(rule.condition)==1 else player_count(world,rule.related)
				if count<int(rule.count): continue
				if not rule.team.units.all(func(item):return room_can_supply(world,room,str(item[0]))): continue
				choices.append(rule)
				weights.append(float(rule.weight))
			if not choices.is_empty():
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([world.match_id,room,s.get("ai_selection",0)])
				s.ai_selection = int(s.get("ai_selection",0))+1
				var rule: Dictionary = choices[rng.rand_weighted(weights)]
				var remaining := []
				for item in rule.team.units:
					for i in int(item[1]): remaining.append(item[0])
				jobs[room]={"remaining":remaining,"members":[],"id":rule.id,"script":rule.team.script,"entry":rule.team.get("entry", "")}
			due[room]=[3500.0,2500.0,2000.0][difficulty]/15.0 if jobs.has(room) else 5.0
		if not jobs.has(room): continue
		var job: Dictionary = jobs[room]
		var busy := false
		for factory in world.buildings:
			if not world.actor_alive(factory) or factory.side!="enemy" or factory.special.get("allied_finale_room")!=room or factory.building_id not in ["YAWEAP","YABRCK"]: continue
			if factory.special.has("allied_finale_order"):
				if factory.production.has(factory.special.allied_finale_order): busy=true; continue
				factory.special.erase("allied_finale_order")
			if job.remaining.is_empty() or not factory.production.is_empty(): continue
			for i in job.remaining.size():
				var uid: String = job.remaining[i]
				if not factory.buildable.has(uid) or not factory.enqueue(uid): continue
				factory.special.allied_finale_order=uid
				job.remaining.remove_at(i)
				busy=true
				break
		if busy: continue
		if not job.remaining.is_empty() and job.members.is_empty():
			jobs.erase(room)
			continue
		if job.id=="13525d8c":
			for u in job.members:
				if world.actor_alive(u) and u.side=="enemy":
					u.special.finale_engineer_rush=job.script
			jobs.erase(room)
			continue
		# Script 11 changes mission; argument 11 is Area Guard. Use the
		# team waypoint as the post (with a reachable slot per member).
		if not job.script.is_empty() and int(job.script[0][0])==11 and int(job.script[0][1])==11:
			var entry_code: String = job.get("entry", "")
			if entry_code.is_empty():
				for rule in Data.data.rules:
					if rule.id==job.id: entry_code=rule.team.get("entry", ""); break
			var index_wp := 0
			for letter in entry_code: index_wp=index_wp*26+letter.unicode_at(0)-64
			if index_wp>0:
				var post := waypoint(world,index_wp-1)
				var reserved: Array[Vector2] = []
				for u in job.members:
					if not world.actor_alive(u) or u.side!="enemy": continue
					var slot := guard_slot(world,u,post,reserved)
					reserved.append(slot)
					u.order_guard()
					u.hold_position=false
					u.special.campaign_area_guard=slot
					if slot.distance_to(u.position)>30.0: u.order_move(slot,true)
				jobs.erase(room)
				continue
		var tierra: bool = job.script.any(func(row):return int(row[0])==3 and int(row[1])==106)
		for u in job.members:
			if not world.actor_alive(u) or u.side!="enemy": continue
			var legs := []
			for step in job.script:
				if int(step[0])==3: legs.append(waypoint(world,int(step[1])))
			if legs.is_empty(): u.order_move(target(world,tierra),true)
			else:
				u.order_move(legs.pop_front(),true)
				for point in legs: u.queue_waypoint(point,null,true)
				u.queue_waypoint(target(world,tierra),null,true)
		jobs.erase(room)

static func guard_slot(world,u,post: Vector2,reserved: Array[Vector2]) -> Vector2:
	# Distinct cells avoid asking every member to settle on the same point.
	for radius in [0.0,75.0,145.0]:
		for angle in (1 if radius==0.0 else 12):
			var desired: Vector2 = post+Vector2.from_angle(TAU*angle/12.0)*radius
			var slot: Vector2 = world.path_service.nearest_reachable(desired,u.position,false,4)
			if not slot.is_finite() or slot.distance_to(post)>8*55.0: continue
			if reserved.any(func(p):return p.distance_squared_to(slot)<48.0*48.0): continue
			return slot
	return u.position

# The engineer team keeps searching until an eligible building is known.
# It does not consume engineers in a generic attack-move.
static func engineer_rush(world,u) -> void:
	if u.special.has("action") or u.attack_ordered: return
	var script: Array = u.special.finale_engineer_rush
	var targets: Array = preload("res://data/ra2/retail_skirmish.json").data.buildings
	var pick = null
	for step in script:
		if int(step[0])!=46: continue
		var kind := str(targets[int(step[1])&65535])
		for b in world.buildings:
			if not world.actor_alive(b) or b.side!="ally" or b.building_id!=kind or not world.actor_visible_to("enemy",b): continue
			if pick==null or u.position.distance_squared_to(b.position)<u.position.distance_squared_to(pick.position): pick=b
		if pick!=null: break
	if pick==null:
		if not u.has_move_order: u.order_move(target(world,false), u.unit_id!="YENGINEER")
		return
	if u.unit_id=="YENGINEER":
		if not world.AlliedFinale.Orders.use(u,"allied_engineer",pick) and not u.has_move_order: u.order_move(pick.position)
	else:
		# Keep capturable structures intact while escorts clear nearby defenders.
		if not u.has_move_order: u.order_move(pick.position+Vector2(80,0),true)

static func room_can_supply(world, room: String, uid: String) -> bool:
	for b in world.buildings:
		if not world.actor_alive(b) or b.side!="enemy" or b.under_construction or b.special.get("allied_finale_room")!=room: continue
		if b.buildable.has(uid) and b.queue_block_reason(uid).is_empty(): return true
	return false

static func player_count(world,id: String) -> int:
	var n := 0
	for actor in world.units+world.buildings:
		if world.actor_alive(actor) and actor.side=="ally" and (actor.unit_id if actor is Unit else actor.building_id)==id: n+=1
	return n

static func produced(world,u,factory) -> void:
	var room: String = factory.special.get("allied_finale_room","")
	if room.is_empty() or u.side!="enemy": return
	u.special.allied_finale_room =room
	u.refresh_house_color()
	if factory.special.get("allied_finale_order")!=u.unit_id: return
	factory.special.erase("allied_finale_order")
	var job: Dictionary = world.allied_state.get("allied_finale",{}).get("ai_jobs",{}).get(room,{})
	if job.is_empty(): return
	u.order_stop()
	job.members.append(u)
