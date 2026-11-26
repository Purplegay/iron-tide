extends RefCounted
const DreadFlight = preload("res://scripts/units/dread_missile.gd")

static func can_infest(target) -> bool:
	if not AlliedAbilities.alive(target) or not target is Unit: return false
	if target.is_naval or not target.ground_contact_eligible(): return false
	if AlliedAbilities.alive(target.special.get("parasite")): return false
	var raw := AlliedAbilities.source(target)
	return str(raw.get("Parasiteable", "yes")).to_lower() != "no" and GameData.ra2_verse("YR_SOV_Parasite", target.ra2_armor) > 0

static func contact(drone, host) -> void:
	if not can_infest(host): return
	if drone.special.get("progression_v2",{}).has("pounce_left") and not preload("res://scripts/units/expansion_2_drone.gd").legal(drone,host):return
	if AlliedAbilities.infantry(host):
		host.receive_hit(float(drone.weapon.damage), "melee", drone.bonuses, drone, "YR_SOV_Parasite")
		return
	drone.set_stowed(host)
	host.special.parasite = drone
	host.special.parasite_timer = 0.0
	preload("res://scripts/units/expansion_2_drone.gd").entered(drone,host)
	if host.special.has("leizhu"):preload("res://scripts/units/leizhu_defense.gd").entered(host,drone)

static func burrow_tick(host, delta: float) -> void:
	var drone = host.special.parasite
	drone.position = host.position
	host.special.parasite_timer -= delta
	if host.special.parasite_timer > 0: return
	var weapon: Dictionary = drone.weapon
	host.special.parasite_timer = preload("res://scripts/units/expansion_2_drone.gd").parasite_interval(drone,weapon.cooldown)
	var damage := CombatMath.full_damage(weapon, host.armor, drone.bonuses, null, host.ra2_armor, 0.0, host)
	var previous_hp:float=host.hp
	host.receive_hit(damage, "melee", drone.bonuses, drone, weapon.ra2_warhead)
	preload("res://scripts/units/expansion_2_drone.gd").parasite_hit(drone,host,previous_hp)

static func cleanse(host, from_repair := false) -> void:
	if from_repair:host.special.get("progression_v2",{}).erase("hunt_tears")
	var drone = host.special.get("parasite")
	if not AlliedAbilities.alive(drone): return
	host.special.erase("parasite")
	host.special.erase("parasite_timer")
	if from_repair and host._battle_world().actor_visible_to("ally", host):
		var point: Vector2 = host.art_center()
		preload("res://scripts/core/yr_death_fx.gd").destroyed(drone, point)
		Ra2Sfx.play_voice(drone.data, "die", point)
	AlliedAbilities.consume(drone)

static func release_drone(host) -> void:
	var drone = host.special.parasite
	host.special.erase("parasite")
	host.special.erase("parasite_timer")
	drone.set_stowed(null)
	drone.position = host.position
	drone.order_stop()

static func rack_cycle(unit) -> float:
	var prefix := "V3Rocket" if unit.unit_id == "V3" else "DMisl"
	var prep := DreadFlight.Native.general(prefix+"PauseFrames",0) + DreadFlight.Native.general(prefix+"TiltFrames",60)
	return prep / DreadFlight.TICKS + preload("res://scripts/units/expansion_2_dread.gd").reload_time(unit)

static func ready_racks(unit) -> int:
	var racks: Array = unit.special.get("missile_racks", [])
	if racks.is_empty(): return 2 if unit.unit_id == "DRED" else 1
	return racks.count(0.0)

static func tick_racks(unit, delta: float) -> void:
	var racks: Array = unit.special.get("missile_racks", [])
	if not racks.is_empty():
		for i in racks.size():
			var slot_key := "raising_missile_" + str(i)
			if unit.special.has("sonar_reload_lock") and delta<=0.0:continue
			var missile = unit.special.get(slot_key)
			if AlliedAbilities.alive(missile) and missile.special.flight.phase == "rack":
				racks[i] = maxf(preload("res://scripts/units/expansion_2_dread.gd").reload_time(unit), rack_cycle(unit) - float(missile.special.flight.elapsed))
				racks[i] = preload("res://scripts/units/expansion_2_armor.gd").rack_remaining(unit,missile,racks[i])
			else:
				unit.special.erase(slot_key)
				racks[i] = maxf(0.0, float(racks[i]) - delta)
		unit.special.launcher_rof = maxf(0.0, float(unit.special.launcher_rof) - delta)
		unit._cd_timer = maxf(unit.special.launcher_rof, racks.min())
	sync_rack(unit)

static func vacate_rack(missile) -> void:
	var flight: Dictionary = missile.special.get("flight", {})
	var launcher = flight.get("source")
	if not AlliedAbilities.alive(launcher): return
	var slot := int(flight.get("rack_slot",-1))
	var racks: Array = launcher.special.get("missile_racks", [])
	if slot < 0 or slot >= racks.size(): return
	var slot_key := "raising_missile_" + str(slot)
	if not is_same(launcher.special.get(slot_key), missile): return
	launcher.special.erase(slot_key)
	racks[slot] = preload("res://scripts/units/expansion_2_armor.gd").rack_remaining(launcher,missile,preload("res://scripts/units/expansion_2_dread.gd").reload_time(launcher))
	tick_racks(launcher, 0.0)

static func launch(unit, target) -> void:
	var dread: bool = unit.unit_id == "DRED"
	var racks: Array = unit.special.get("missile_racks", [0.0,0.0] if dread else [0.0])
	# Pre-slot battle saves can resume between the two shots of a Dreadnought burst.
	if dread and not unit.special.has("missile_racks") and unit._burst_left == 1 and unit._burst_target != null:
		racks[0] = maxf(0.0, unit._cd_timer)
	var slot := racks.find(0.0)
	if slot < 0: return
	var rail := 1.0 if slot == 0 else -1.0
	var point := DreadFlight.mount(unit, rail)
	var missile = _launch_missile(unit, target, unit.data.rocket, dread, point, rail)
	if missile == null: return
	missile.special.flight.rack_slot = slot
	unit.special["raising_missile_" + str(slot)] = missile
	unit.special.missile_racks = racks
	racks[slot] = rack_cycle(unit)
	if float(unit.special.get("launcher_rof",0.0)) <= 0.0:
		unit.special.launcher_rof = CombatMath.veteran_cooldown(unit.cooldown,unit.bonuses) * (1.0 - clampf(unit.buff_value("cooldown"),0,0.85))
	tick_racks(unit, 0.0)

static func _launch_missile(unit, target, cfg: Dictionary, dread: bool, point: Vector2, rail: float):
	var missile = unit._battle_world().spawn_unit("DMISL" if dread else "V3ROCKET", unit.side, point)
	if missile == null: return null
	var elite: bool = unit.veteran_level >= 2
	missile.hull_angle = unit.position.direction_to(target.position).angle()
	missile.logistics.air_lift = 1.0
	missile.special.flight = {"origin":missile.position, "aim":target.position, "elapsed":0.0, "source":unit,
		"windup":cfg.windup, "altitude":cfg.altitude, "duration":maxf(0.1, unit.position.distance_to(target.position) / float(cfg.speed)),
		"damage":cfg.elite_damage if elite else cfg.damage, "warhead":("YR_SOV_DMISLEWH" if elite else "YR_SOV_DMISLWH") if dread else ("YR_SOV_V3EWH" if elite else "YR_SOV_V3WH"),
		"bonus":unit.bonuses.duplicate(true), "force":ForceFire.active(unit, target)}

	if not dread and BattleRequest.has_unit_talent(unit.unit_id,"v3_cluster",unit.side):
		missile.special.flight.cluster_rank=MetaProgress.talent_rank(unit.unit_id,"v3_cluster",BattleRequest.combat_context.get("unit_talents",{}))
	if Effects.Looks.current(unit)=="reentry":missile.special.flight.weapon_look="reentry"
	preload("res://scripts/units/expansion_2_armor.gd").rocket_created(unit,missile,target)
	preload("res://scripts/units/expansion_2_tractor.gd").rocket_created(unit,missile)
	DreadFlight.prepare(missile, unit, rail)
	return missile

static func sync_rack(unit) -> void:
	var empty: bool = ready_racks(unit) == 0 if unit.special.has("missile_racks") else unit._cd_timer > 0
	var id: String = unit.unit_id + ("WO" if empty else "")
	var hull := RA2Art.art(id)
	if hull.is_empty() or unit._ra2.get("tex") == hull.tex: return
	unit._ra2 = hull
	unit._ra2_shd = RA2Art.art(id + "_shd")
	unit.queue_redraw()

static func fly(missile, delta: float) -> void:
	if not AlliedAbilities.alive(missile): return
	var state: Dictionary = missile.special.get("flight", {})
	if state.is_empty(): return
	if state.has("phase"):
		var was_raising: bool = state.phase == "rack"
		var arrived := DreadFlight.advance(missile,state,delta)
		if was_raising and state.phase != "rack":
			vacate_rack(missile)
			preload("res://scripts/units/expansion_2_armor.gd").departed(missile)
			preload("res://scripts/units/expansion_2_dread.gd").departed(missile)
		missile.queue_redraw()
		if not arrived: return
	else:
		state.elapsed += delta
		var raising := clampf(float(state.elapsed) / float(state.windup), 0, 1)
		var progress := clampf((float(state.elapsed) - float(state.windup)) / float(state.duration), 0, 1)
		missile.position = Vector2(state.origin).lerp(state.aim, progress)
		missile.logistics.air_lift = 1.0 + raising * (15.0 * (1.0 - progress) + float(state.altitude) * sin(progress * PI))
		missile.queue_redraw()
		if progress < 1.0: return
	var world = missile._battle_world()
	var owner = state.source if AlliedAbilities.alive(state.source) else missile
	preload("res://scripts/world/bridge_damage.gd").blast(world,missile.position,CombatMath.with_offense(float(state.damage),state.bonus),state.warhead,0.0,owner)
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(60)
	if state.get("cluster_rank",-1)>=0: Unit.PoolCards.cluster(missile,owner,state)
	var candidates := impact_candidates(world, missile.position, state.warhead)
	preload("res://scripts/world/battle_call_counters.gd").iterations(60, candidates.size())
	var affects_allies := not GameData.warhead_blocks_friendly_damage(state.warhead)
	for target in candidates:
		if target == missile or not AlliedAbilities.alive(target) or (target.side == missile.side and not affects_allies): continue
		if target is Unit and (target.embarked_in != null or target.is_air_target()): continue
		var distance: float = target.position.distance_to(missile.position)
		if not Ra2Damage.in_spread(distance, state.warhead): continue
		var raw_damage:=Ra2Damage.target_damage(state.damage,state.warhead,target,distance)
		var damage := CombatMath.with_offense(raw_damage, state.bonus)
		var packet:=CombatMath.FinalDamage.packet(state.bonus,raw_damage*float(state.bonus.get("veteran_attack",1.0)))
		if damage <= 0: continue
		if target is Unit:
			target.receive_hit(damage, "rocket", packet, owner, state.warhead, missile.position, state.damage)
		else:
			var hp_before:float=target.hp
			target.receive_hit(damage, "rocket", packet, owner, state.warhead)
			preload("res://scripts/units/expansion_2_armor.gd").rocket_hit(missile,target,hp_before-target.hp)
	if state.get("weapon_look")=="reentry":
		Effects.Looks.Signature.spawn(world.effects_root,missile.position,"meteor_dust")
	if not Ra2Fx.play_impact(Effects._host(), state.warhead, state.damage, missile.position):
		Effects.spawn_impact(missile.position, Color.ORANGE, 24)
	preload("res://scripts/units/expansion_2_tractor.gd").rocket_landed(missile)
	AlliedAbilities.consume(missile)

static func impact_candidates(world, point: Vector2, warhead: String) -> Array:
	var candidates: Array = world.neighborhood.nearby(point, Ra2Damage.cells(warhead) * Ra2Damage.PX_PER_CELL)
	# Dense/global blasts keep the old linear path; sorting is useful only for
	# a small local set. Array.find runs natively and retains exact world-list
	# order even when ownership reparents units or scripts reorder those lists.
	if candidates.size() * 4 >= world.units.size() + world.buildings.size():
		return world.units + world.buildings
	var ordered: Array = []
	for actor in candidates:
		var index: int = world.units.find(actor) if actor is Unit else world.buildings.find(actor)
		if index >= 0:
			ordered.append([index if actor is Unit else world.units.size() + index, actor])
	ordered.sort_custom(_impact_order)
	var result: Array = []
	for entry in ordered: result.append(entry[1])
	return result

static func _impact_order(a: Array, b: Array) -> bool:
	return a[0] < b[0]
