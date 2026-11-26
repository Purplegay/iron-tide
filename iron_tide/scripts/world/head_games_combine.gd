extends RefCounted

# Sov07md 69, 70 and 71 in the cropped battlefield's coordinates.
const MEET := Vector2(107.5,102.5)*55
const FORM := Vector2(103.5,103.5)*55
const VIA := Vector2(53.5,97.5)*55
const BETA := ["SHK","SHK","SHK","FLAKT","IVAN"]

static func casualty(world,slot:String) -> void:
	if not slot.begins_with("alpha"):return
	var state:Dictionary=world.allied_state
	var cycle:=int(state.get("combo_alpha_cycle",0))
	if not slot.begins_with("alpha%d/"%cycle):return
	state.get_or_add("combo_retry",{})[slot]=float(state.get("head_media_clock",0))+2.0

static func recruit(world, id: String, slot: String):
	var retry:Dictionary=world.allied_state.get("combo_retry",{})
	if retry.has(slot):
		if float(world.allied_state.get("head_media_clock",0))<float(retry[slot]):return null
		retry.erase(slot)
	var wing := 1 if id == "FV" else 0
	for u in world.units:
		if not world.actor_alive(u) or u.unit_id != id or u.side != "enemy": continue
		if u.special.get("combo_slot", "") == slot: return u
	var candidate = null
	for u in world.units:
		if not world.actor_alive(u) or u.unit_id != id or u.side != "enemy" or u.embarked_in != null: continue
		if u.special.get("head_games_wing", -1) != wing or u.special.has("combo_slot"): continue
		if candidate == null or u.position.distance_squared_to(MEET) < candidate.position.distance_squared_to(MEET): candidate = u
	if candidate != null:
		candidate.special.combo_slot = slot
		candidate.hold_position = false
		candidate.order_stop()
		return candidate
	var building_id := "GAWEAP" if wing == 1 else ("NAWEAP" if id == "HTK" else "NAHAND")
	for b in world.buildings:
		if world.actor_alive(b) and b.side == "enemy" and b.building_id == building_id and b.special.get("head_games_wing", -1) == wing:
			if not b.production.has(id): b.enqueue(id)
			break
	return null

static func approach(world, unit, goal: Vector2) -> bool:
	if unit.position.distance_to(goal) <= 64: return true
	if not unit.has_move_order or unit.move_target.distance_to(goal) > 16:
		unit.order_move(goal,false,null,world.path_for_unit(unit,goal))
	return false

static func tick(world, now: float, difficulty: int, owned: Array) -> void:
	var s: Dictionary = world.allied_state
	if s.has("combo_beta_sent"):
		var pending := false
		for u in world.units:
			if not world.actor_alive(u) or not u.special.has("combo_via"): continue
			if u.side == "enemy" and approach(world,u,VIA):
				var goal: Vector2 = world._player_target()
				u.order_move(goal,true,null,world.path_for_unit(u,goal))
			elif u.side == "enemy":
				pending = true
				continue
			u.special.erase("combo_via")
		if not pending: s.erase("combo_beta_sent")
	if s.has("head_games_freed_0") or s.has("head_games_freed_1"): return
	if not s.has("combo_alpha_due"):
		if not "NATECH" in owned and now < (450 if difficulty == 2 else 900): return
		s.combo_alpha_due = now + 240
		s.combo_beta_due = now + randi_range(50,150)*3 + 10
	for group in ["alpha","beta"]:
		if now < float(s["combo_"+group+"_due"]): continue
		advance(world, group, now, difficulty)

static func advance(world, group: String, now: float, difficulty: int) -> void:
	var s: Dictionary = world.allied_state
	var beta := group == "beta"
	var cycle := int(s.get("combo_"+group+"_cycle",0))
	var prefix := "%s%d/" % [group,cycle]
	var cars := []
	var truck = recruit(world,"HTK",prefix+"truck") if beta else null
	if beta and truck == null: return
	var total := 5 if beta else 2
	var ready := 0
	for i in total:
		if not beta and i == 1 and now < float(s.get("combo_second_due",INF)): break
		var slot := prefix+str(i)
		var car = recruit(world,"FV",slot+"car")
		var crew = recruit(world,BETA[i] if beta else "SHK",slot+"crew")
		if car == null or crew == null: continue
		var offset := Vector2.RIGHT.rotated(i*TAU/total)*72
		if crew.embarked_in != car:
			var parked := approach(world,car,MEET+offset)
			if beta and not truck.special.has("combo_delivered"):
				if crew.embarked_in == null and crew.logistics.boarding != truck: crew.logistics.request_board(truck)
				continue
			if crew.embarked_in != null: continue
			if parked:
				if crew.logistics.boarding != car: crew.logistics.request_board(car)
			else: approach(world,crew,MEET+offset)
			continue
		if not beta and i == 0 and not s.has("combo_second_due"):
			s.combo_second_due = now+17
			if not s.has("head_combo_voice"):
				s.head_combo_voice = true
				Events.emit_radar_ping(FORM,"campaign_discovery")
				if difficulty == 0: world.fog._reveal("ally",FORM,410,5.0)
				world.HeadGames.line(world,"xs7so01","索菲亚","尤里正让苏军步兵登上盟军的多功能步兵车。小心他们的联合攻势。")
		cars.append(car)
		if approach(world,car,FORM+offset): ready += 1
	if beta and not truck.special.has("combo_delivered") and truck.logistics.passengers.size() == total:
		if approach(world,truck,MEET):
			truck.special.combo_delivered = true
			truck.logistics.request_unload()
	if ready != total: return
	var goal: Vector2 = world._player_target()
	for car in cars:
		var path: PackedVector2Array = world.path_for_unit(car,VIA if beta else goal)
		if beta:
			car.special.combo_via = true
			car.order_move(VIA,false,null,path)
		else: car.order_move(goal,true,null,path)
	s["combo_"+group+"_cycle"] = cycle+1
	s["combo_"+group+"_due"] = now+(randi_range(50,150)*3+10 if beta else 240)
	if not beta: s.erase("combo_second_due")
	if beta:
		s.combo_beta_sent = true
		truck.special.erase("combo_slot")
		truck.special.erase("combo_delivered")
