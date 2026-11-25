extends RefCounted
## The unit's ordinary order owns its assignment. Both actor references survive snapshots.
static func accepts(unit, coil) -> bool:
	if BattleRequest.is_ai_house(unit.side) and unit.special.get("tesla_unreachable")==coil \
			and unit._anim<float(unit.special.get("tesla_retry_after",0.0)):return false
	return not unit.special.get("soviet_mode",false) and unit.data.has("charge_weapon") and coil is Building and coil.data.has("charged_weapon") \
		and unit.side == coil.side and unit.embarked_in == null and not coil.under_construction \
		and coil._buildup_play < 0 and not AlliedAbilities.frozen(coil)

static func nearby(unit):
	var world = unit._battle_world()
	if world == null: return null
	var best = null
	var radius: float = unit.data.charge_weapon.range
	for coil in world.buildings:
		if not world.actor_alive(coil) or not accepts(unit, coil): continue
		var distance: float = unit.position.distance_to(coil.position)
		if distance <= radius:
			best = coil
			radius = distance
	return best

static func tick(unit, coil, delta: float) -> void:
	var bolt: Dictionary = unit.data.charge_weapon
	if unit.position.distance_to(coil.position) > float(bolt.range):
		approach(unit,coil,delta)
		unit._face_if_moving()
		unit._move_water_safe()
		return
	unit.special.erase("tesla_approach")
	unit.has_move_order = false
	unit.velocity = Vector2.ZERO
	unit._face(coil.position)
	if unit._cd_timer > 0: return
	unit._cd_timer = float(bolt.cooldown)
	var chargers: Array = coil.special.get("tesla_chargers", [])
	if not chargers.has(unit): chargers.append(unit)
	coil.special.tesla_chargers = chargers
	if unit.unit_id=="R3TESLA":
		unit.special.ra3_barrel=(int(unit.special.get("tesla_link_barrel",-1))+1)%2
		unit.special.tesla_link_barrel=unit.special.ra3_barrel
		preload("res://scripts/units/ra3_tank_beam.gd").spawn(unit,coil,false,true)
	else:
		var spec := GameData.ra2_beam_spec(bolt.ra2_weapon_id)
		Effects.spawn_beam(unit._weapon_muzzle(), tip(coil), spec.color, spec.kind, spec.thickness, spec.duration)
	Ra2Sfx.play_weapon(bolt, unit.position)
	unit._fire_anim_time = 0.0
	unit.queue_redraw()

## A footprint ray may end behind another building, and A* can return a
## partial route outside charge range. Reserve a reachable point on the ring
## instead. Bounded retries keep an enclosed coil from creating a path storm.
static func approach(unit,coil,delta:float) -> void:
	var world=unit._battle_world()
	if world==null:return
	var state:Dictionary=unit.special.get("tesla_approach",{})
	if state.get("coil")!=coil or state.get("epoch",-1)!=world.path_service.epoch:
		state={"coil":coil,"epoch":world.path_service.epoch,"cursor":0,"retry":0.0,"point":Vector2.INF,"watch":0.0,"anchor":unit.position}
	unit.special.tesla_approach=state
	state.watch=float(state.get("watch",0.0))+delta
	if state.watch>=8.0:
		if unit.position.distance_squared_to(state.get("anchor",unit.position))<64.0 and BattleRequest.is_ai_house(unit.side):
			# An enclosed/unreachable charger must rejoin the army instead of
			# remaining excluded from campaign recruitment forever.
			unit.order_stop()
			unit.special.erase("tesla_approach")
			unit.special.tesla_unreachable=coil
			unit.special.tesla_retry_after=unit._anim+20.0
			return
		state.watch=0.0
		state.anchor=unit.position
	state.retry=float(state.retry)-delta
	var point:Vector2=state.point
	if point.is_finite() and state.retry<=0.0:
		if unit.position.distance_squared_to(state.get("last",unit.position))<16.0:
			state.point=Vector2.INF
			point=Vector2.INF
		else:
			state.last=unit.position
			state.retry=1.5
	if not point.is_finite() and state.retry<=0.0:
		state.retry=0.6
		var reach:float=float(unit.data.charge_weapon.range)-Unit.ARRIVE_EPS-4.0
		var heading:Vector2=coil.position.direction_to(unit.position)
		if heading.is_zero_approx():heading=Vector2.RIGHT
		var probes:=0
		for _i in 16:
			var index:int=int(state.cursor)%16
			state.cursor=int(state.cursor)+1
			var candidate:Vector2=coil.position+heading.rotated(TAU*index/16.0)*reach
			if not world.path_service.passages.clear(world.path_service,candidate,candidate,unit.radius+1.0,[]):continue
			var occupied:=false
			for other in world.neighborhood.nearby(candidate,unit.radius*2.0+24.0):
				if not other is Unit or other==unit or not world.actor_alive(other) or other.embarked_in!=null:continue
				var slot:Vector2=other.special.get("tesla_approach",{}).get("point",other.position)
				if candidate.distance_to(slot)<unit.radius+other.radius+12.0:
					occupied=true
					break
			if occupied:continue
			probes+=1
			var path:PackedVector2Array=world.path_for_unit(unit,candidate)
			# Coarse grid padding can reject a physically clear charging position.
			# Complete that last segment only after a full swept-circle proof.
			if path.size()>=2 and path[-1].distance_to(candidate)>Unit.ARRIVE_EPS \
					and world.path_service.passages.clear(world.path_service,path[-1],candidate,unit.radius+1.0,[]):
				path.append(candidate)
			if path.size()>=2 and path[-1].distance_to(candidate)<=Unit.ARRIVE_EPS:
				unit.set_agent_path(path)
				unit.move_target=candidate
				unit.has_move_order=true
				state.point=candidate
				state.last=unit.position
				state.retry=1.5
				point=candidate
				break
			if probes>=2:break
	if point.is_finite():unit._go_to(point,delta,4.0)
	else:unit.velocity=Vector2.ZERO

static func count(coil) -> int:
	var chargers: Array = coil.special.get("tesla_chargers", [])
	for i in range(chargers.size()-1, -1, -1):
		var u = chargers[i]
		if not AlliedAbilities.alive(u) or u.side != coil.side or u.embarked_in != null or AlliedAbilities.frozen(u) \
				or u._stun_timer > 0 or u.special.get("action") != "tesla_charge" or u.special.get("target") != coil \
				or u.position.distance_to(coil.position) > float(u.data.charge_weapon.range):
			chargers.remove_at(i)
	return chargers.size()

static func update_weapon(coil) -> void:
	var needed := 3 if coil.battle.side_power_low(coil.side) else 1
	var armed: Dictionary = coil.data.charged_weapon if count(coil) >= needed else coil.data.weapon
	coil.weapon = armed
	coil.attack_range = float(armed.range)
	coil.cooldown = float(armed.cooldown)

static func tip(coil) -> Vector2:
	# Centre of the discharge sphere on the NATSLA 160x126 canvas, including its firing overlay.
	if coil.building_id == "TESLA" and not coil._ra2.is_empty():
		var frame := RA2Art.draw_rect(coil._ra2, coil.radius, [coil._body_damage_frame()])
		if frame.has_area():
			return coil.global_position + RA2Art.art_dir(frame.position + Vector2(79.5, 13.0))
	var height := float(coil.data.fire_flh[2]) * Ra2Damage.PX_PER_CELL / 256.0
	return coil.global_position + RA2Art.art_dir(Vector2.UP * height)

static func ready_to_fire(coil, delta: float) -> bool:
	var pending: Dictionary = coil.special.get("coil_windup", {})
	if pending.get("target") != coil.attack_target:
		coil.special.coil_windup = {"target":coil.attack_target, "left":float(coil.data.fire_delay)}
		coil.play_special(coil.data.fire_delay)
		Ra2Sfx.play("YR_SOV_TeslaCoilPowerUp", coil.position)
		return false
	pending.left -= delta
	if pending.left > 0.000001: return false
	coil.special.erase("coil_windup")
	return true
