extends RefCounted

# Sov07md 69, 70 and 71 in the cropped battlefield's coordinates.
const MEET := Vector2(107.5,102.5)*55
const FORM := Vector2(103.5,103.5)*55
const VIA := Vector2(53.5,97.5)*55
const COMBO = preload("res://data/maps/head_games_drivers.json").data.combo
const RETRY := [["0DB2278C","0DB1203C"],["0DB5507C","0DB5195C"]]
const RESTART := ["0952AC5C","0954B2BC"]
const BETA := ["SHK","SHK","SHK","FLAKT","IVAN"]

# Retail 01/02: separate arrival latches (7/8 or 11/12) and combined latch (9/10).
static func pair_state(state:Dictionary,index:int) -> Dictionary:
	return state.get_or_add("combo_pairs",{}).get_or_add(str(index),{})

static func casualty(world,unit) -> void:
	var slot:String=unit.special.get("combo_slot", "")
	var state:Dictionary=world.allied_state
	if unit.side!="enemy" or state.has("head_games_freed_0") or state.has("head_games_freed_1"): return
	var cycle:=int(state.get("combo_alpha_cycle",0))
	if not slot.begins_with("alpha%d/"%cycle):return
	var index:=int(slot.get_slice("/",1).left(1))
	var pair:=pair_state(state,index)
	var prefix:=slot.trim_suffix("car") if slot.ends_with("car") else slot.trim_suffix("crew")
	if pair.get("merged",false):
		# Clear both roles before a dying transport can also destroy its passenger.
		for u in world.units:
			if is_instance_valid(u) and str(u.special.get("combo_slot", "")).begins_with(prefix):
				u.special.erase("combo_slot")
				if world.actor_alive(u) and u.embarked_in==null: u.order_stop()
		for flag in COMBO[RESTART[index]].flags:state.get_or_add("combo_flags",{}).erase(str(int(flag)))
		pair.clear()
		return
	var member:="car" if slot.ends_with("car") else "crew"
	if pair.get(member+"_arrived",false):
		pair[member+"_closed"]=true
	else:
		var row:Dictionary=COMBO[RETRY[index][0 if member=="car" else 1]]
		if not row.enable.is_empty():state.get_or_add("combo_retry",{})[slot]=float(state.get("head_media_clock",0))+float(COMBO[row.enable[0]].delay)

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
		if u.special.get("head_games_wing", -1) != wing or u.special.has("combo_slot") or u.special.has("combo_attack_active"): continue
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
				if now<float(u.special.get("combo_attack_due",0.0)):
					pending=true
					continue
				u.special.erase("combo_attack_due")
				var goal: Vector2 = world._player_target()
				u.order_move(goal,true,null,world.path_for_unit(u,goal))
			elif u.side == "enemy":
				pending = true
				continue
			u.special.erase("combo_via")
		if not pending: s.erase("combo_beta_sent")
	if s.has("head_games_freed_0") or s.has("head_games_freed_1"):
		if not s.get("combo_closed",false):
			s.combo_closed=true
			s.erase("combo_retry")
			for u in world.units:
				if not world.actor_alive(u) or not u.special.has("combo_slot"): continue
				u.special.erase("combo_slot")
		return
	if not s.has("combo_alpha_due"):
		var start:Dictionary=COMBO["07BA277C" if difficulty==2 else "07BA238C"]
		if "NATECH" in owned:start=COMBO["07BA16AC"]
		elif now<float(start.delay):return
		if not start.enable.has("06B0394C") or not start.enable.has("06B032DC") or not start.enable.has("094920FC"):return
		s.combo_alpha_due=now+maxf(float(COMBO["06B0394C"].delay),float(COMBO["06B032DC"].delay))
		s.combo_beta_due=now+beta_wait()
	for group in ["alpha","beta"]:
		if now < float(s["combo_"+group+"_due"]): continue
		advance(world, group, now, difficulty)

static func beta_wait() -> float:
	return floorf(float(COMBO["094920FC"].delay)*randi_range(50,150)/100.0)+maxf(float(COMBO["09490F3C"].delay),float(COMBO["0949246C"].delay))

static func advance_alpha(world, now:float, difficulty:int) -> void:
	var s:Dictionary=world.allied_state
	if s.has("combo_alpha_restart") and now>=float(s.combo_alpha_restart):
		s.erase("combo_alpha_restart")
		var reset:Dictionary=COMBO["06A7E97C"]
		for flag in reset.flags:s.get_or_add("combo_flags",{}).erase(str(int(flag)))
		if reset.enable.has("06B0394C") and reset.enable.has("06B032DC"):
			for u in world.units:
				if not world.actor_alive(u) or not str(u.special.get("combo_slot","")).begins_with("alpha%d/"%int(s.get("combo_alpha_cycle",0))):continue
				u.special.erase("combo_slot")
				u.special.combo_attack_active=true
			s.combo_alpha_cycle=int(s.get("combo_alpha_cycle",0))+1
			s.erase("combo_pairs")
			s.erase("combo_second_due")
			s.combo_alpha_due=now+maxf(float(COMBO["06B0394C"].delay),float(COMBO["06B032DC"].delay))
			return
	var cycle:=int(s.get("combo_alpha_cycle",0))
	for index in 2:
		if index==1 and now<float(s.get("combo_second_due",INF)): continue
		var pair:=pair_state(s,index)
		if pair.get("sent",false) or pair.get("car_closed",false) or pair.get("crew_closed",false): continue
		var prefix:="alpha%d/%d"%[cycle,index]
		var car=recruit(world,"FV",prefix+"car")
		var crew=recruit(world,"SHK",prefix+"crew")
		var offset:=Vector2(72 if index==0 else -72,0)
		if not pair.get("car_arrived",false) and car!=null and approach(world,car,MEET+offset): pair.car_arrived=true
		if not pair.get("crew_arrived",false) and crew!=null and (car!=null and crew.embarked_in==car or crew.embarked_in==null and approach(world,crew,MEET+offset)): pair.crew_arrived=true
		if car==null or crew==null or not pair.get("car_arrived",false) or not pair.get("crew_arrived",false): continue
		if crew.embarked_in!=car:
			if crew.embarked_in==null and crew.logistics.boarding!=car: crew.logistics.request_board(car)
			continue
		var arrived:Dictionary=COMBO["06B01CCC" if index==0 else "0BF1DC9C"]
		var boarded:Dictionary=COMBO["06B0190C" if index==0 else "0BF1D64C"]
		if not arrived.enable.has(boarded.id):continue
		if not pair.has("merge_due"):pair.merge_due=now+float(boarded.delay)
		pair.merged=true
		if index==0 and not s.has("combo_second_due") and boarded.enable.has("09554A8C"):
			s.combo_second_due=float(pair.merge_due)+float(COMBO["09554A8C"].delay)+maxf(float(COMBO["0BF1B7BC"].delay),float(COMBO["0BF1DF3C"].delay))
		if now<float(pair.merge_due): continue
		var alert:Dictionary=COMBO["06B5903C" if difficulty==0 else "0BA1D7AC"]
		if index==0 and arrived.enable.has(alert.id) and now>=float(pair.merge_due)-float(boarded.delay)+float(alert.delay) and not s.has("head_combo_voice"):
			s.head_combo_voice=true
			world.HeadGames.line(world,"xs7so01","索菲亚","尤里正让苏军步兵登上盟军的多功能步兵车。小心他们的联合攻势。")
			if difficulty==0: world.fog._reveal("ally",FORM,410,5.0)
			Events.emit_radar_ping(FORM,"campaign_discovery")
			# CSF MISSION:ComboWarn01/02: a warning followed by the instruction to prepare.
			Events.emit_message("警告：尤里开始混用手中的各阵营科技。")
			Events.emit_message("做好准备，迎击他们的联合攻势。")
		if not approach(world,car,FORM+offset): continue
		s.get_or_add("combo_flags",{})[str(9+index)]=true
		if index==1 and COMBO["06A7EEDC"].enable.has("06A7E97C") and pair_state(s,0).get("sent",false):
			s.combo_alpha_restart=now+float(COMBO["06A7E97C"].delay)
		var goal:Vector2=world._player_target()
		car.order_move(goal,true,null,world.path_for_unit(car,goal))
		pair.sent=true

static func advance(world, group: String, now: float, difficulty: int) -> void:
	if group=="alpha":
		advance_alpha(world,now,difficulty)
		return
	var s: Dictionary = world.allied_state
	var cycle:=int(s.get("combo_beta_cycle",0))
	var prefix:="beta%d/"%cycle
	var cars:=[]
	var truck=recruit(world,"HTK",prefix+"truck")
	if truck==null: return
	var ready:=0
	for i in BETA.size():
		var slot:=prefix+str(i)
		var car=recruit(world,"FV",slot+"car")
		var crew=recruit(world,BETA[i],slot+"crew")
		if car==null or crew==null: continue
		var offset:=Vector2.RIGHT.rotated(i*TAU/BETA.size())*72
		if crew.embarked_in!=car:
			var parked:=approach(world,car,MEET+offset)
			if not truck.special.has("combo_delivered"):
				if crew.embarked_in==null and crew.logistics.boarding!=truck: crew.logistics.request_board(truck)
				continue
			if crew.embarked_in!=null: continue
			if parked:
				if crew.logistics.boarding!=car: crew.logistics.request_board(car)
			else: approach(world,crew,MEET+offset)
			continue
		cars.append(car)
		if approach(world,car,FORM+offset): ready+=1
	if not truck.special.has("combo_delivered") and truck.logistics.passengers.size()==BETA.size():
		if approach(world,truck,MEET) and COMBO["094907FC"].enable.has("0949024C"):
			if not truck.special.has("combo_unload_due"):truck.special.combo_unload_due=now+float(COMBO["0949024C"].delay)
			if now<float(truck.special.combo_unload_due):return
			truck.special.combo_delivered=true
			truck.logistics.request_unload()
	if ready!=BETA.size() or not COMBO["09493B1C"].enable.has("0949370C"):return
	for car in cars:
		car.special.combo_via=true
		car.special.combo_attack_due=now+float(COMBO["0949370C"].delay)
		car.order_move(VIA,false,null,world.path_for_unit(car,VIA))
	s.combo_beta_cycle=cycle+1
	s.combo_beta_due=now+beta_wait()
	s.combo_beta_sent=true
	truck.special.erase("combo_slot")
	truck.special.erase("combo_delivered")
	truck.special.erase("combo_unload_due")
