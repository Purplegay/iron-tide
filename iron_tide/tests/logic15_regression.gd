extends "res://tests/ground_control_regression.gd"

class ShotCounter extends Unit:
	var fired := 0
	var kill_after := -1
	func _fire_shot(victim, _first_in_volley := false) -> void:
		fired += 1
		if fired == kill_after: victim.hp = 0.0

func exercise(mode: String) -> void:
	var prior_hz := Engine.physics_ticks_per_second
	var prior_limit := Engine.max_physics_steps_per_frame
	start(mode)
	check(Engine.physics_ticks_per_second == 15 and Engine.max_physics_steps_per_frame == 64, prefix+"fixed wall cadence with sixty-four-step battle limit overriding the default eight")
	BattleClock.set_speed(4.0)
	check(Engine.time_scale==3.0 and GM.fast_forward==3.0,prefix+"all clock callers enforce the 3x speed cap")
	for speed in [1.0,2.0,3.0]:
		BattleClock.set_speed(speed)
		check(is_equal_approx(Engine.time_scale / Engine.physics_ticks_per_second, speed / 15.0), prefix+"game step scales without lowering requested speed")
	for speed in [1.0,2.0,3.0]:
		BattleClock.set_speed(speed)
		for burst in [1,2,4]:
			for reload_time in [0.05,0.15,0.45,1.0]:
				await compare_fire(burst,reload_time)
		await compare_fire(4,0.15,0.5)
	if mode == MatchRules.EXTENDED:
		for speed in [1.0,2.0,3.0]:
			BattleClock.set_speed(speed)
			await check_mounts()
	await check_projectiles()
	await check_motion()
	var building: Building = battle._place_building("GAWEAP","ally",Vector2(1800,1400),true)
	var layers: Array = building._ra2_anim
	var kinds: Dictionary = building._anim_kinds().duplicate()
	building._ra2_anim = []
	check(building._anim_kinds().is_empty(),prefix+"empty animation replacement invalidates topology cache")
	building._ra2_anim = layers
	check(building._anim_kinds()==kinds,prefix+"restored animation topology matches source")
	await finish()
	check(Engine.physics_ticks_per_second==prior_hz and Engine.max_physics_steps_per_frame==prior_limit,prefix+"leaving battle restores engine scheduling")

func counter(point: Vector2, burst: int, reload_time: float) -> ShotCounter:
	var actor := ShotCounter.new()
	var data: Dictionary = GameData.get_unit("MTNK").duplicate(true)
	data.weapon.burst = burst
	data.weapon.burst_delay = 0.05
	data.weapon.cooldown = reload_time
	actor.setup(data,"ally",point)
	actor._combat_world = battle
	battle.add_child(actor)
	battle.units.append(actor)
	actor.set_physics_process(false)
	actor.cooldown = reload_time
	actor._cd_timer = 0.1
	actor.fire_stance = "free"
	actor.attack_ordered = true
	return actor

func compare_fire(burst: int, reload_time: float, clock_rate: float = 1.0) -> void:
	var fine_delta := Engine.time_scale / 60.0
	var coarse_delta := Engine.time_scale / 15.0
	var point := Vector2(1100,1100)
	var foe: Unit = battle.spawn_unit("MTNK","enemy",point+Vector2(80,0))
	var fine := counter(point,burst,reload_time)
	var coarse := counter(point,burst,reload_time)
	for actor in [fine,coarse]:
		actor.attack_target=foe
		actor.aim_dir=Vector2.RIGHT
		actor.hull_angle=0
		actor.turret_angle=0
	for i in 30:
		for tick in 4:
			var previous := fine._cd_timer
			fine._cd_timer -= fine_delta * clock_rate
			fine._advance_firing(fine_delta,previous,foe,clock_rate)
		var previous := coarse._cd_timer
		coarse._cd_timer -= coarse_delta * clock_rate
		coarse._advance_firing(coarse_delta,previous,foe,clock_rate)
		check(fine.fired==coarse.fired and fine._burst_left==coarse._burst_left and is_equal_approx(fine._cd_timer,coarse._cd_timer),prefix+str(Engine.time_scale)+"x coarse firing matches four short steps burst="+str(burst)+" reload="+str(reload_time)+" tick="+str(i),[fine.fired,coarse.fired,fine._cd_timer,coarse._cd_timer])
	check(fine.fired>0,prefix+"fixture actually fires")
	coarse._cancel_burst()
	coarse._cd_timer=-50.0
	var count := coarse.fired
	coarse._advance_firing(0.2,-50.0,foe)
	check(coarse.fired-count>=1 and coarse.fired-count<=ceili(0.2 / fine_delta),prefix+"idle time cannot bank shots from previous frames")
	coarse._cancel_burst()
	coarse._cd_timer=0.05
	coarse.kill_after=coarse.fired+1
	coarse._advance_firing(0.2,0.05,foe)
	check(coarse.fired==coarse.kill_after,prefix+"short events revalidate dead target")
	for actor in [fine,coarse,foe]:
		battle.units.erase(actor)
		actor.free()
	await get_tree().process_frame

func check_projectiles() -> void:
	var target: Unit = battle.spawn_unit("MTNK","enemy",Vector2(1300,1000))
	for kind in ["straight","homing","arc"]:
		var shots: Array[Projectile] = []
		for i in 2:
			var shot := Projectile.new()
			shot.setup(Vector2(1000,1000),target,GameData.get_unit("MTNK").weapon,1,{},"ally")
			shot.ra2_inviso=false
			shot.ra2_homing=kind=="homing"
			shot.ra2_rot_deg=30
			shot.ra2_arcing=kind=="arc"
			shot._heading=Vector2.DOWN
			shot.speed=120
			shot._arc_from=Vector2(1000,1000)
			shot._arc_to=target.position
			shot._arc_dur=2.0
			battle.projectiles_root.add_child(shot)
			shot.set_physics_process(false)
			shots.append(shot)
		for tick in 4: shots[0]._physics_process(0.05)
		shots[1]._physics_process(0.2)
		check(shots[0].position.is_equal_approx(shots[1].position) and shots[0]._heading.is_equal_approx(shots[1]._heading) and is_equal_approx(shots[0].life,shots[1].life),prefix+kind+" coarse projectile preserves short integration")
		for shot in shots: shot.free()
	battle.units.erase(target)
	target.free()
	await get_tree().process_frame

func check_motion() -> void:
	for building in battle.buildings: building.free()
	battle.buildings.clear()
	battle._refresh_pathing()
	var unit: Unit = battle.spawn_unit("MTNK","ally",Vector2(1000,1500))
	activate(unit)
	unit.order_move(Vector2(1400,1500))
	unit.set_physics_process(true)
	for tick in 150:
		await get_tree().physics_frame
		if not unit.has_move_order: break
	check(unit.position.distance_to(unit.move_target)<=unit.ARRIVE_EPS+4 and not unit.has_move_order,prefix+"actual 15 Hz/3x movement arrives without overshoot",[unit.position,unit.move_target])
	unit.set_physics_process(false)

func mount_state(actor: Unit) -> Array:
	var group := "ra3_mounts" if actor.unit_id == Ra3Expansion.HARBINGER else "soviet_mounts"
	var field := "remaining" if group == "ra3_mounts" else "left"
	var result := []
	for key in actor.special.get(group, {}):
		var state: Dictionary = actor.special[group][key]
		result.append([key,state.used,roundi(float(state[field])*100000)])
	return result

func check_mounts() -> void:
	for id in ["R3REAPER","R3TESLA",Ra3Expansion.HARBINGER]:
		var foe: Unit = battle.spawn_unit("MTNK","enemy",Vector2(1645 if id == Ra3Expansion.HARBINGER else 1320,1200))
		foe.hp=1000000;foe.max_hp=1000000
		var actors: Array[Unit] = []
		for i in 2:
			var gun: Unit = battle.spawn_unit(id,"ally",Vector2(1200,1200))
			gun.order_guard();gun.attack_target=foe;gun.attack_ordered=true
			gun.hull_angle=0;gun.turret_angle=0;gun.aim_dir=Vector2.RIGHT
			gun._think_timer=10000.0
			gun.process_mode=Node.PROCESS_MODE_ALWAYS
			gun.set_process(false)
			gun.set_physics_process(false)
			if id == Ra3Expansion.HARBINGER:
				gun.special.ra3_gun_mode=true
				Ra3Expansion.apply_veterancy(gun,false)
				gun.logistics.air_lift=1.0
				preload("res://scripts/units/ra3_gunship_mounts.gd").tick(gun,10.0)
			check(gun._try_fire_ready(),prefix+id+" independent mount fixture fires before comparison",[gun._weapon_target_valid(foe),gun._weapon_aligned(foe),gun.logistics.can_start_volley(),gun.attack_range,gun.weapon.get("min_range"),gun.special.get("ra3_mounts")])
			actors.append(gun)
		for tick in 10:
			for step in 4: advance_mount_only(actors[0],Engine.time_scale / 60.0)
			advance_mount_only(actors[1],Engine.time_scale / 15.0)
			check(mount_state(actors[0])==mount_state(actors[1]),prefix+id+" independent mounts preserve salvos at 15 Hz "+str(tick),[mount_state(actors[0]),mount_state(actors[1])])
		for gun in actors:
			battle.units.erase(gun);gun.free()
		battle.units.erase(foe);foe.free()
		for shot in battle.projectiles_root.get_children(): shot.free()
		await get_tree().process_frame

func advance_mount_only(gun: Unit, delta: float) -> void:
	gun._fire_clock_snapshot = preload("res://scripts/units/weapon_step_clock.gd").capture(gun) if delta > Engine.time_scale / 60.0 + 0.000001 else {}
	if gun.unit_id == Ra3Expansion.HARBINGER:
		preload("res://scripts/units/ra3_gunship_mounts.gd").tick(gun,delta)
	else:
		preload("res://scripts/units/ra3_soviet.gd").tick(gun,delta)
	var previous := gun._cd_timer
	if gun.unit_id != Ra3Expansion.HARBINGER: gun._cd_timer-=delta
	gun._advance_firing(delta,previous,gun.attack_target)
