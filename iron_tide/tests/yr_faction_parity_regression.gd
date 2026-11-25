extends "res://tests/special_mechanics_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for id in ["DEST","V3","DRED","ZEP"]:
		arena(MatchRules.RA2)
		splash(id)
		await finish()
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		arena(mode)
		limits()
		await finish()
		arena(mode)
		radar_infiltration()
		await finish()
		for id in ["NARADR","GATECH","NATECH"]:
			arena(mode)
			shared_support(id)
			await finish()
	var file := FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failed":failed}))
	file.close()
	get_tree().quit(0 if failed==0 else 1)

func splash(id:String) -> void:
	var attacker=spawn(id,"ally",AIM)
	var point:=AIM+Vector2.RIGHT*620
	if id=="ZEP":
		attacker.logistics.air_lift=1.0
		point=AIM-Vector2.from_angle(attacker.hull_angle)*50.0*Ra2Damage.PX_PER_CELL/256.0
	var target=spawn("HTNK","enemy",point)
	var friend=spawn("HTNK","ally",point+Vector2.DOWN*9)
	var foe=spawn("HTNK","enemy",point+Vector2.UP*9)
	var aircraft=spawn("ZEP","ally",point)
	aircraft.logistics.air_lift=1.0
	attacker.attack_target=target
	attacker.attack_ordered=true
	attacker._fire_shot(target)
	if id in ["V3","DRED"]:
		for unit in battle.units:
			if not unit.special.has("flight"): continue
			for tick in 1350:
				if not battle.actor_alive(unit): break
				unit._physics_process(1.0/30.0)
			break
	else:
		for shot in battle.projectiles_root.get_children():
			if not shot is Projectile: continue
			for tick in 240:
				if shot.is_queued_for_deletion(): break
				shot._physics_process(1.0/30.0)
	check(foe.hp<foe.max_hp and is_equal_approx(friend.max_hp-friend.hp,foe.max_hp-foe.hp),id+" normal splash hits both sides equally")
	check(aircraft.hp==aircraft.max_hp,id+" ground impact excludes airborne friend")

func limits() -> void:
	for side in ["ally","enemy"]:
		var ready:Dictionary=battle.struct_ready if side=="ally" else battle.enemy_struct_ready
		var jobs:Array=battle.struct_queue if side=="ally" else battle.enemy_struct_queue
		for id in ["GAOREP","GACSPH","GAWEAT","NAINDP","NAIRON","NAMISL"]:
			check(battle.limit_reason(id,side).is_empty(),id+" available")
			jobs.append({"id":id})
			check(not battle.limit_reason(id,side).is_empty(),id+" in production reserves slot")
			jobs.clear()
			ready[id]=2 # Also exercise paid duplicate orders from older saves.
			check(not battle.limit_reason(id,side).is_empty(),id+" ready plans reserve slot")
			var first=battle.deliver_ready_structure(id,side,AIM)
			check(first!=null and int(ready[id])==1,id+" legal first placement")
			check(battle.deliver_ready_structure(id,side,AIM+Vector2.RIGHT*200)==null and ready[id]==1,id+" old duplicate is retained, not placed")
			check(not battle.structure_queue_block_reason(id,side).is_empty(),id+" standing structure reserves slot")
			first._die()
			check(battle.deliver_ready_structure(id,side,AIM)!=null,id+" replacement after destruction")

	add("GACNST", "enemy", AIM - Vector2.RIGHT * 300)
	battle.enemy_struct_ready["GAOREP"] = 2
	# Keep another building job pending to separate the refund from new orders.
	battle.enemy_struct_queue.append({"id":"GAPOWR"})
	var before: float = battle.enemy_funds
	battle.skirmish_ai._try_build()
	var expected: float = before + 2.0 * float(GameData.get_building("GAOREP").cost)
	check(not battle.enemy_struct_ready.has("GAOREP") and is_equal_approx(battle.enemy_funds, expected), "AI refunds duplicate paid plans")
	battle.skirmish_ai._try_build()
	check(is_equal_approx(battle.enemy_funds, expected), "AI refund cannot repeat")

func radar_infiltration() -> void:
	if battle.fog == null:
		battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
		battle.add_child(battle.fog)
		battle.fog.setup(battle)
	var remote := Vector2(2200, 2200)
	for id in ["GAAIRC", "NARADR"]:
		for victim in ["ally", "enemy"]:
			var thief := "enemy" if victim == "ally" else "ally"
			var radar = add(id, victim, AIM)
			radar._sw_charge = 11
			battle.fog.explored_cells[victim].fill(1)
			battle.fog.explored_cells[thief].fill(1)
			var infiltrator = spawn("SPY", thief, AIM + Vector2.RIGHT * 100)
			battle.fog.rebuild()
			check(AlliedAbilities.default_order(infiltrator, radar) == "allied_infiltrate", id + " ordinary spy order")
			AlliedAbilities.resolve_infiltration(infiltrator, radar)
			check(not battle.fog.is_explored_at(victim, remote) and battle.fog.is_explored_at(thief, remote), id + " reshrouds only victim")
			check(battle.fog.is_visible_at(victim, AIM) and radar._sw_charge == 11, id + " keeps current sight and support charge")

func shared_support(id:String) -> void:
	add("NANRCT","ally",AIM+Vector2.UP*400)
	add("NANRCT","enemy",AIM+Vector2.DOWN*400)
	var a=add(id,"ally",AIM)
	var b=add(id,"ally",AIM+Vector2.RIGHT*250)
	var enemy=add(id,"enemy",AIM+Vector2.RIGHT*500)
	a._tick_superweapon(21)
	b._tick_superweapon(21)
	check(a._sw_charge==21 and b._sw_charge==21 and enemy._sw_charge==0,id+" side advances only once")
	var loaded := Snapshot.new().capture(battle)
	Snapshot.new().restore(battle,loaded)
	battle.paused=false
	get_tree().paused=false
	var providers=battle.buildings.filter(func(x):return x.side=="ally" and x.building_id==id)
	a=providers[0]; b=providers[1]
	enemy=battle.buildings.filter(func(x):return x.side=="enemy" and x.building_id==id)[0]
	check(a._sw_charge==21 and b._sw_charge==21,id+" shared progress survives restore")
	a._tick_superweapon(a.sw_recharge())
	check(b.sw_ready() and b.fire_superweapon(a.position),id+" access charge from second provider")
	check(a._sw_charge==0 and b._sw_charge==0 and not a.fire_superweapon(a.position),id+" only one cast")
	battle.allied_state.erase("blackout_ally")
	battle.power_low=false
	a._tick_superweapon(11)
	enemy._tick_superweapon(35)
	AlliedAbilities.change_side(b,"enemy")
	check(is_equal_approx(b._sw_charge,35) and is_equal_approx(a._sw_charge,11),id+" captured facility joins new owner charge")
	enemy._die()
	check(is_equal_approx(b._sw_charge,35) and SupportSystems.charge_controller(b)==b,id+" second provider takes over after destruction")
