extends RefCounted

static func eligible(unit, target) -> bool:
	if target is ForceFirePoint: return false
	if target.special.get("expedition_protected",false): return false
	if unit.unit_id == "VIRUS": return AlliedAbilities.infantry(target)
	if unit.unit_id == "TELE": return target is Building or target is Unit and not target.is_air and not AlliedAbilities.infantry(target)
	if unit.unit_id == "CAOS": return target is Unit and not target.is_air and not AlliedAbilities.flag(target,"ImmuneToPsionics")
	return true

static func shot(unit, target, gun: Dictionary) -> bool:
	var world = unit._battle_world()
	match gun.get("name", ""):
		"MagneticBeam":
			if target is Unit and eligible(unit,target):
				target.special.magnet_seconds = 1.5
				target.special.magnet_source = unit
				Effects.spawn_beam(unit.position,target.position,Color.MAGENTA,"laser",2.5,0.7)
			return true
		"ChaosAttack":
			for victim in world.units.duplicate():
				if not world.actor_alive(victim) or victim.side != target.side or not eligible(unit,victim): continue
				if victim.position.distance_to(target.position)>110: continue
				for other in world.units:
					if world.actor_alive(other) and other!=victim and victim.side==other.side and other.position.distance_to(victim.position)<450:
						victim.order_target(other,true,false)
						victim.special.chaos_seconds = 5.0
						break
			return true
		"DiskDrain":
			unit._disc_trace("drain.begin", target)
			if target.power>0: world.allied_state["blackout_"+target.side] = 4.0
			elif target.is_refinery():
				var amount := minf(50.0,world.funds_for(target.side))
				if world.spend_side(target.side,amount): world.credit_side(unit.side,amount)
			Effects.spawn_beam(unit._disc_center(), target.art_center(), Color.VIOLET, "laser", 3.0, 0.8, "", null, false, false, false, unit.global_position, target.global_position)
			unit._disc_trace("drain.created", target)
			return true
		"Virusgun":
			if target is Unit: target.special.virus_shooter = unit
	return false

static func tick(unit, delta: float) -> void:
	if unit.special.has("chaos_seconds"):
		unit.special.chaos_seconds -= delta
		if unit.special.chaos_seconds<=0:
			unit.special.erase("chaos_seconds")
			unit.order_stop()
	if unit.special.has("magnet_seconds"):
		var owner = unit.special.get("magnet_source")
		unit.special.magnet_seconds -= delta
		if not AlliedAbilities.alive(owner) or unit.special.magnet_seconds<=0:
			unit.special.erase("magnet_source")
			unit.special.erase("magnet_seconds")
		else:
			var world = unit._battle_world()
			var dest: Vector2 = unit.position.move_toward(owner.position,90*delta)
			if not world.path_service.is_blocked(dest): unit.position = dest
			unit._stun_timer = maxf(unit._stun_timer,delta*2)
	if unit.special.has("mind_links"):
		var links: Array = unit.special.mind_links.filter(func(t):return AlliedAbilities.alive(t) and t.special.get("controller")==unit)
		unit.special.mind_links = links
		if links.size()>3: unit.receive_hit(12.0*(links.size()-3)*delta,"bullet")

static func virus_death(unit, killer) -> void:
	if not AlliedAbilities.alive(killer) or killer != unit.special.get("virus_shooter"): return
	var world = unit._battle_world()
	for victim in world.units.duplicate():
		if victim != unit and world.actor_alive(victim) and AlliedAbilities.infantry(victim) and victim.position.distance_to(unit.position)<=75:
			victim.receive_hit(20,"bullet",{},killer)

static func tower(tower_building, delta: float) -> void:
	if tower_building.battle.paused or not tower_building.is_operational(): return
	var state: Dictionary = tower_building.special
	state.tower_reload = float(state.get("tower_reload",0.0))-delta
	if state.tower_reload > 0: return
	state.tower_reload = 1.0
	var links: Array = state.get("tower_links",[]).filter(func(t):return AlliedAbilities.alive(t) and t.special.get("controller")==tower_building)
	state.tower_links = links
	if links.size()>=3: return
	for unit in tower_building.battle.units:
		if not AlliedAbilities.alive(unit) or unit.is_air or unit.embarked_in!=null or unit.side=="neutral" or BattleRequest.friendly(unit.side,tower_building.side): continue
		if AlliedAbilities.flag(unit,"ImmuneToPsionics") or unit.special.has("controller") or unit.position.distance_to(tower_building.position)>385: continue
		links.append(unit)
		AlliedAbilities.apply_mind_control(tower_building, unit)
		break
