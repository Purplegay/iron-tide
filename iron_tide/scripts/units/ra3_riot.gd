extends RefCounted
## EA BeamSpecialAbilityUpdate and LaserSweepWeapon; see RA3_RIOT_AUDIT.md.
static var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_riot_rules.json"))
static var balance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_gameplay_balance.json")).future_riot

static func seconds(value) -> float:
	return float(str(value).trim_suffix("s"))

static func range_limit() -> float:
	return float(rules.beam.StartAbilityRange)*float(rules.adapter.distance_scale)

static func duration() -> float:
	return seconds(rules.beam.BeamDuration)

static func cooldown() -> float:
	return seconds(rules.power.ReloadTime)

static func request(actor, point: Vector2) -> bool:
	var world=actor._battle_world()
	if not point.is_finite() or world==null or point.x<0 or point.y<0 or point.x>=world.map_size or point.y>=world.map_size:return false
	if actor.position.distance_to(point)<=range_limit():return begin(actor,point)
	# Use existing terrain pathfinding. A snapped/partial path must still end
	# within StartAbilityRange; never consume recharge for an invalid approach.
	var candidates: Array[Vector2]=[]
	var toward: Vector2=point.direction_to(actor.position)
	for i in 16:candidates.append(point+toward.rotated(i*TAU/16.0)*(range_limit()-24.0))
	candidates.sort_custom(func(a,b):return actor.position.distance_squared_to(a)<actor.position.distance_squared_to(b))
	for goal in candidates:
		var path: PackedVector2Array=actor._path_for(goal)
		if path.size()<2 or path[-1].distance_to(point)>range_limit():continue
		var aim_time:=float(actor.special.get("ra3_aim_time",0.0))
		actor.order_move(path[-1],false,null,path)
		actor.special.ra3_riot_approach=point
		actor.special.ra3_riot_best=actor.position.distance_to(point)
		actor.special.ra3_riot_stuck=0.0
		actor.special.ra3_aim_time=aim_time
		return true
	Events.emit_message("暴乱光束：无法接近到施放范围，未消耗冷却",Color(1,0.7,0.4))
	return false

static func cancel_approach(actor) -> void:
	for key in ["ra3_riot_approach","ra3_riot_best","ra3_riot_stuck"]:actor.special.erase(key)

static func approach_tick(actor, delta: float) -> void:
	if not actor.special.has("ra3_riot_approach"):return
	if AlliedAbilities.frozen(actor) or actor._stun_timer>0.0:return
	var point: Vector2=actor.special.ra3_riot_approach
	var distance: float=actor.position.distance_to(point)
	actor.special.ra3_aim_time=float(actor.special.get("ra3_aim_time",0.0))+delta
	if distance<=range_limit():begin(actor,point);return
	if distance<float(actor.special.ra3_riot_best)-4.0:
		actor.special.ra3_riot_best=distance;actor.special.ra3_riot_stuck=0.0
	else:actor.special.ra3_riot_stuck=float(actor.special.ra3_riot_stuck)+delta
	if not actor.has_move_order or float(actor.special.ra3_riot_stuck)>=5.0:
		actor.order_stop()
		Events.emit_message("暴乱光束：接近失败，未消耗冷却",Color(1,0.7,0.4))

static func begin(actor, point: Vector2) -> bool:
	if actor.position.distance_to(point)>range_limit():return false
	var aim_time:=float(actor.special.get("ra3_aim_time",0.0))
	actor.order_stop()
	actor.special.ra3_riot_point=point;actor.special.ra3_riot_time=0.0
	actor.special.ra3_riot_cd=cooldown() / Unit.Training.timing_scale(actor);actor.special.ra3_riot_fired=false
	actor.special.ra3_riot_unpack=maxf(seconds(rules.beam.UnpackTime),seconds(rules.beam.MinimumUnpackTimeAfterSpecialPowerInitiation)-aim_time)
	actor.special.erase("ra3_pre_target");actor.special.erase("ra3_pre_left")
	actor.special.reveal=actor.special.ra3_riot_unpack+duration()
	if actor.side=="ally":Ra2Sfx.play_voice(actor.data,"attack_beam",actor.position)
	return true

static func endpoints(shot, at: float) -> Array[Vector2]:
	var forward: Vector2=shot.splinters.origin.direction_to(shot.target_point)
	var half_sweep:=float(rules.beam.SweepDistance)*0.5*float(rules.adapter.distance_scale)
	# Retail 0x7e0ea0 halves SweepDistance; 0x7e13db moves BOTH beams from
	# near to far. 0x772170 linearly interpolates the two crisscross records.
	var phase:=clampf(at/duration(),0,1)*2.0-1.0
	var center: Vector2=shot.target_point+forward*half_sweep*phase
	var offset:=Vector2(forward.y,-forward.x)*half_sweep*phase
	return [center+offset,center-offset]

static func eligible(shot, target) -> bool:
	if not AlliedAbilities.alive(target) or target is ForceFirePoint or target.side==shot.owner_side:return false
	if target is Unit and (target.is_air_target() or target.embarked_in!=null or target.special.get("submerged",false)):return false
	return true

static func point_distance(target, point: Vector2) -> float:
	if target is Building:
		var polygon: PackedVector2Array=target.footprint_poly()
		var local: Vector2=point-target.position
		if Geometry2D.is_point_in_polygon(local,polygon):return 0.0
		var distance:=INF
		for i in polygon.size():distance=minf(distance,local.distance_to(Geometry2D.get_closest_point_to_segment(local,polygon[i],polygon[(i+1)%polygon.size()])))
		return distance
	return maxf(0.0,target.position.distance_to(point)-target.radius)

static func line_distance(target, start: Vector2, end: Vector2) -> float:
	if target is Building:
		var polygon: PackedVector2Array=target.footprint_poly()
		var a: Vector2=start-target.position;var b: Vector2=end-target.position
		if Geometry2D.is_point_in_polygon(a,polygon) or Geometry2D.is_point_in_polygon(b,polygon):return 0.0
		var distance:=minf(point_distance(target,start),point_distance(target,end))
		for i in polygon.size():
			var c:=polygon[i];var d:=polygon[(i+1)%polygon.size()]
			if Geometry2D.segment_intersects_segment(a,b,c,d)!=null:return 0.0
			distance=minf(distance,c.distance_to(Geometry2D.get_closest_point_to_segment(c,a,b)))
		return distance
	return maxf(0.0,target.position.distance_to(Geometry2D.get_closest_point_to_segment(target.position,start,end))-target.radius)

static func damage(shot, target, nugget: Dictionary) -> void:
	var scalar:=1.0 if AlliedAbilities.infantry(target) else float(nugget.non_infantry_scalar)
	# User-requested IronTide balance, separate from the native XML export.
	# Both line and delayed endpoint damage take this once, before armor/HP mapping.
	if target is Building:scalar*=float(balance.structure_damage_multiplier)
	Ra3Expansion.hit(shot,target,float(nugget.Damage)*scalar,str(nugget.DamageType))

static func tick_shot(shot, world) -> void:
	var state: Dictionary=shot.splinters
	var hz:=float(rules.adapter.continuous_damage_hz)
	var old_hz:=float(state.get("riot_hz",30.0 if state.has("riot_next") else hz))
	if not is_equal_approx(old_hz,hz):
		# Preserve time already consumed by legacy 30Hz cursors, without replay.
		for key in ["riot_next","riot_tip"]:
			if state.has(key):state[key]=ceili(float(state[key])*hz/old_hz)
	state.riot_hz=hz
	var interval:=seconds(rules.beam.DamageInterval)
	if interval<=0.0:interval=1.0/float(rules.adapter.continuous_damage_hz)
	var line: Dictionary=rules.nuggets.LineDamageNugget
	var tip: Dictionary=rules.nuggets.DamageNugget
	var delay:=seconds(tip.DelayTimeSeconds)
	# Separate fire and delayed-hit cursors are serializable and catch up without
	# dropping pulses at low FPS. Old saves begin at their current beam age.
	var previous: float=state.get("riot_previous",0.0)
	var next_fire:=int(state.get("riot_next",ceili(previous/interval)))
	var next_tip:=int(state.get("riot_tip",ceili(maxf(0,previous-delay)/interval)))
	var count:=ceili(duration()/interval-0.00001)
	if state.has("riot_stop_count"):count=mini(count,int(state.riot_stop_count))
	while next_fire<count or next_tip<count:
		var fire_time:=next_fire*interval if next_fire<count else INF
		var tip_time:=next_tip*interval+delay if next_tip<count else INF
		if minf(fire_time,tip_time)>float(state.age)+0.000001:break
		var is_tip:=tip_time<=fire_time
		var sample_time:=next_tip*interval if is_tip else fire_time
		for end in endpoints(shot,sample_time):
			for target in world.units+world.buildings:
				if not eligible(shot,target):continue
				var distance:=point_distance(target,end) if is_tip else line_distance(target,state.origin,end)
				var reach:=float(tip.Radius) if is_tip else float(line.LineWidth)*0.5
				if distance<=reach*float(rules.adapter.distance_scale):damage(shot,target,tip if is_tip else line)
		if is_tip:next_tip+=1
		else:next_fire+=1
	state.riot_next=next_fire;state.riot_tip=next_tip;state.riot_previous=state.age
	if next_fire>=count and next_tip>=count and (state.get("riot_stopped",false) or float(state.age)>=duration()):shot.queue_free()
