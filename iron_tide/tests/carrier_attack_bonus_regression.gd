extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	MetaProgress.reset_save()
	GM.god_mode = false
	GM.one_shot_kill = false
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for id in ["CARRIER", "DEST"]:
			exercise_bonus(mode,id)
			await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("CARRIER_ATTACK_BONUS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func find_actor(id: String, side: String):
	for actor in battle.units:
		if actor.unit_id == id and actor.side == side: return actor
	return null

func launch(ship, target):
	ship.order_target(target,false,false)
	ship.logistics.tick_squadron(0.0)
	var plane = ship.logistics.squadron[0].unit
	check(is_instance_valid(plane),prefix+"real squadron launch")
	return plane

func prepare_shot(plane,target) -> void:
	plane.position = target.position - Vector2(30,0)
	plane.logistics.air_lift = 1.0
	plane.logistics.air_state = "flying"
	plane.logistics.ammo = plane.logistics.ammo_max
	plane.attack_target = target
	plane.attack_ordered = true
	plane.hull_angle = 0.0
	plane.turret_angle = 0.0
	plane.aim_dir = Vector2.RIGHT
	plane._cd_timer = 0.0

func fire_packet(plane,target):
	prepare_shot(plane,target)
	var holder = plane._pick_projectile_parent()
	var before: int = holder.get_child_count()
	check(plane._try_fire_ready(),prefix+"real aircraft weapon fires")
	if holder.get_child_count() <= before:
		check(false,prefix+"weapon creates projectile")
		return null
	var shot = holder.get_child(-1)
	shot.set_physics_process(false)
	return shot

func resolve_packet(shot,target,expected: float,label: String) -> void:
	if shot == null: return
	var prior: float = target.hp
	for tick in 900:
		if shot.is_queued_for_deletion(): break
		shot._physics_process(1.0/60.0)
	check(shot.is_queued_for_deletion(),prefix+label+" projectile reaches impact")
	check(is_equal_approx(prior-target.hp,expected),prefix+label+" actual health damage",[prior-target.hp,expected])
	shot.free()

func exercise_bonus(mode: String,id: String) -> void:
	start(mode)
	prefix = mode+" "+id+": "
	if battle.fog != null:
		battle.fog.free()
		battle.fog = null
	battle.water_rects = [Rect2(1200,1200,1000,1000)]
	battle.path_service.set_water(battle.water_rects)
	battle._refresh_pathing()
	# Exercise the real per-unit growth lookup, not just a synthetic plane multiplier.
	var growth := 1.0
	if mode == MatchRules.EXTENDED:
		BattleRequest.combat_context.bonuses.attack_bonus = 2.0
		BattleRequest.combat_context.unit_bonus[id] = {"attack_bonus":3.0}
		growth = 6.0
	var ship = battle.spawn_unit(id,"ally",Vector2(1600,1450))
	var target_id := "MTNK" if id == "CARRIER" else "SUB"
	var target = battle.spawn_unit(target_id,"enemy",Vector2(1600,1650))
	target.order_stop()
	target.bonuses = {}
	target.hp = 100000.0
	target.max_hp = target.hp
	var base_damage := 40.0 if id == "CARRIER" else 50.0
	check(is_equal_approx(ship.bonuses.attack_bonus,growth),prefix+"mother ship receives configured growth")
	var plane = launch(ship,target)
	if plane == null: return
	var aircraft_base: float = plane._base_atk
	resolve_packet(fire_packet(plane,target),target,base_damage*growth,"mother ship growth applied once")
	ship.add_buff("attack",60.0,1.0,"test ship attack")
	resolve_packet(fire_packet(plane,target),target,base_damage*growth*2.0,"live ship buff while aircraft airborne")
	plane.add_buff("attack",60.0,0.5,"test aircraft attack")
	resolve_packet(fire_packet(plane,target),target,base_damage*growth*3.0,"aircraft local buff preserved")
	var packet = fire_packet(plane,target)
	ship.clear_buff("attack")
	plane.clear_buff("attack")
	resolve_packet(packet,target,base_damage*growth*3.0,"in-flight bomb retains firing-time bonuses")
	resolve_packet(fire_packet(plane,target),target,base_damage*growth,"expired buffs do not stick")
	check(is_equal_approx(plane._base_atk,aircraft_base),prefix+"firing never overwrites aircraft growth")
	ship.logistics.recover(plane)
	ship.logistics.tick_squadron(11.0)
	check(ship.logistics.squadron[0].unit == plane and plane.embarked_in == null,prefix+"same aircraft relaunches after reload")
	resolve_packet(fire_packet(plane,target),target,base_damage*growth,"second sortie does not compound growth")
	var codec = preload("res://scripts/save/battle_snapshot.gd").new()
	codec.restore(battle,codec.capture(battle))
	ship = find_actor(id,"ally")
	target = find_actor(target_id,"enemy")
	plane = ship.logistics.squadron[0].unit
	check(plane.logistics.carrier_owner == ship,prefix+"snapshot restores mother ship reference")
	resolve_packet(fire_packet(plane,target),target,base_damage*growth,"restored aircraft inherits growth")
	plane.hp = 0.0
	plane._die()
	ship.logistics.tick_squadron(float(ship.logistics.source.SpawnRegenRate)/15.0+0.1)
	plane = ship.logistics.squadron[0].unit
	check(is_instance_valid(plane),prefix+"destroyed aircraft is replaced")
	if plane != null:
		resolve_packet(fire_packet(plane,target),target,base_damage*growth,"replacement aircraft inherits growth")
