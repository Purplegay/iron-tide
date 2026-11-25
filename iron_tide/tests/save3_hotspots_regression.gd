extends "res://tests/base_recovery_regression.gd"
const Assembly=preload("res://scripts/world/skirmish_assembly.gd")
const Support=preload("res://scripts/units/tesla_support.gd")
const Civilian=preload("res://scripts/units/civilian_orders.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		for b in battle.buildings:b.free()
		battle.buildings.clear()
		battle._refresh_pathing()
		await get_tree().physics_frame
		exercise_guard()
		exercise_passengers()
		exercise_healing()
		exercise_garrison()
		await exercise_charge()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("SAVE3 HOTSPOTS checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func exercise_guard() -> void:
	var guard=battle.spawn_unit("E2","enemy",Vector2(600,600))
	var mover=battle.spawn_unit("HTNK","enemy",Vector2(520,600))
	guard.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	mover.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	guard.order_guard()
	guard.special.ai_campaign_role="guard"
	var ai={"rally":Vector2(650,650),"battle":battle}
	check(Assembly.needs_new_slot(ai,guard),prefix+"legacy idle guard without assembly slot must be parked")
	guard.special.ai_assembly_point=guard.position
	guard.special.ai_assembly_epoch=battle.path_service.epoch
	check(not Assembly.needs_new_slot(ai,guard),prefix+"unchanged valid parking slot does not replan")
	check(mover._local_traffic.request_yield(mover,guard,Vector2.RIGHT),prefix+"computer guard can yield a blocked lane")
	check(guard.hold_position and guard.special.ai_campaign_role=="guard",prefix+"yield preserves guard role and stance")
	guard.side="ally"
	guard._local_traffic.reset()
	check(not mover._local_traffic.request_yield(mover,guard,Vector2.RIGHT),prefix+"player hold is never overridden")
	guard.side="enemy"
	guard._deployed=true
	check(not mover._local_traffic.request_yield(mover,guard,Vector2.RIGHT),prefix+"deployed defense never yields")

func exercise_passengers() -> void:
	var carrier=battle.spawn_unit("BFRT","ally",Vector2(1200,1600))
	var passenger=battle.spawn_unit("GGI","ally",Vector2(1200,1600))
	passenger.set_stowed(carrier)
	carrier.logistics.passengers.append(passenger)
	var ground=battle.spawn_unit("HTNK","enemy",Vector2(1300,1600))
	var air=battle.spawn_unit("JUMPJET","enemy",Vector2(1300,1600))
	air.logistics.air_lift=1.0
	for elite in [0,2]:
		passenger.veteran_level=elite
		var bound:=OpenTopped.search_bound(carrier)
		check(is_finite(bound) and bound>=OpenTopped.command_range(carrier,ground) and bound>=OpenTopped.command_range(carrier,air),prefix+"bounded BFRT acquisition covers ground and air",[elite,bound])
		var source:Dictionary=passenger.deployed_weapon()
		var damage:float=source.damage
		var range_before:float=source.range
		for i in 4:passenger._weapon_for_target(air)
		check(source.damage==damage and source.range==range_before,prefix+"passenger adapters never mutate native weapon")
	var rifle=battle.spawn_unit("E1","ally",carrier.position)
	rifle.set_stowed(carrier)
	carrier.logistics.passengers.append(rifle)
	carrier.attack_ordered=true
	carrier.fire_stance="guard"
	carrier.attack_target=air
	rifle._cd_timer=100
	rifle._think_timer=0.2
	OpenTopped.tick(rifle,0.01)
	check(is_equal_approx(rifle._think_timer,Unit.TARGET_REFRESH),prefix+"new carrier target immediately triggers acquisition")
	OpenTopped.tick(rifle,0.01)
	check(is_equal_approx(rifle._think_timer,Unit.TARGET_REFRESH-0.01),prefix+"unhittable carrier air target does not rescan every tick")
	carrier.attack_target=ground
	OpenTopped.tick(rifle,0.01)
	check(rifle.attack_target==ground,prefix+"changing to ground target redirects passenger immediately")
	carrier._process_combat(0.01)
	check(OpenTopped.command_range(carrier,ground)>0.0,prefix+"combined pursuit range includes live ground weapons")
	check(OpenTopped.command_range(carrier,air)>0.0,prefix+"combined pursuit range includes antiair passenger")
	carrier.logistics.passengers.erase(passenger)
	check(OpenTopped.command_range(carrier,air)==0.0,prefix+"removing antiair passenger immediately invalidates air pursuit")
	carrier.logistics.passengers.append(passenger)
	passenger.side="enemy"
	check(OpenTopped.command_range(carrier,air)==0.0,prefix+"captured passenger cannot supply former carrier air range")
	passenger.side="ally"

func exercise_healing() -> void:
	var indicator=preload("res://scripts/ui/healing_indicator.gd")
	var unit=battle.spawn_unit("MTNK","ally",Vector2(1500,1500))
	check(indicator.alpha(unit)==0.0,prefix+"unit without healing pulse draws no badge")
	unit.hp-=20.0
	unit.heal(5.0)
	check(indicator.alpha(unit)>0.0,prefix+"real healing still enables badge")
	indicator.tick(unit,indicator.DURATION+0.1)
	check(indicator.alpha(unit)==0.0,prefix+"expired pulse returns to zero-cost badge path")
	unit.heal(5.0)
	unit.hide()
	check(indicator.alpha(unit)==0.0,prefix+"hidden healed unit never exposes badge")
	unit.show()

func exercise_garrison() -> void:
	var bunker=battle._place_building("NABNKR","ally",Vector2(350,1600),true)
	bunker._buildup_play=-1
	var rifle=battle.spawn_unit("E2","ally",bunker.position)
	rifle.set_stowed(bunker)
	bunker.special.occupants=[rifle]
	rifle.fire_stance="guard"
	rifle._think_timer=0.0
	Civilian.tick(rifle,0.01)
	var timer:float=rifle._think_timer
	Civilian.tick(rifle,0.01)
	check(timer>0.0 and is_equal_approx(rifle._think_timer,timer-0.01),prefix+"idle garrison waits between acquisition scans")
	var target=battle.spawn_unit("E2","enemy",bunker.position+Vector2(80,0))
	bunker.attack_target=target
	rifle._cd_timer=0
	Civilian.tick(rifle,0.01)
	check(rifle.attack_target==target and rifle._cd_timer>0,prefix+"manual garrison attack bypasses acquisition wait")

func exercise_charge() -> void:
	# Exact relative footprints from the supplied upper Soviet base.
	var center:=Vector2(1600,1000)
	var coil=battle._place_building("TESLA","enemy",center,true)
	for pair in [["NAPOWR",Vector2(40,40)],["NABNKR",Vector2(0,-80)],["NAWEAP",Vector2(160,0)],["NAINDP",Vector2(120,-160)]]:
		var b=battle._place_building(pair[0],"enemy",center+pair[1],true)
		b._buildup_play=-1
	coil._buildup_play=-1
	var trooper=battle.spawn_unit("SHK","enemy",center+Vector2(85.173,-107.882))
	# The parent scene is deliberately paused; keep real physics bodies in space.
	for actor in battle.units+ battle.buildings:
		actor.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	AlliedAbilities.use(trooper,"tesla_charge",coil)
	trooper.set_agent_path(PackedVector2Array([trooper.position,center+Vector2(77.5,-112.5)]))
	battle._refresh_pathing()
	await get_tree().physics_frame
	var elapsed:=0.0
	while elapsed<40.0 and trooper.position.distance_to(center)>trooper.data.charge_weapon.range:
		Support.tick(trooper,coil,1.0/60.0)
		trooper._anim+=1.0/60.0
		elapsed+=1.0/60.0
		await get_tree().physics_frame
	check(trooper.position.distance_to(center)<=trooper.data.charge_weapon.range,prefix+"charger leaves partial route and reaches actual charge range",[trooper.position,elapsed])
	trooper._cd_timer=0
	Support.tick(trooper,coil,1.0/60.0)
	check(Support.count(coil)==1,prefix+"arrived charger actually powers coil")
	# A completely enclosed assignment is released, without releasing player commands.
	trooper.position=Vector2(2100,2100)
	trooper.special.action="tesla_charge"
	trooper.special.target=coil
	trooper.special.tesla_approach={"coil":coil,"epoch":battle.path_service.epoch,"cursor":0,"retry":10.0,"point":Vector2.INF,"watch":7.99,"anchor":trooper.position}
	Support.approach(trooper,coil,0.02)
	check(not trooper.special.has("action") and not Support.accepts(trooper,coil),prefix+"unreachable AI charge releases recruitment and backs off")
	trooper._anim+=21
	check(Support.accepts(trooper,coil),prefix+"unreachable charge can retry later")
	trooper.side="ally"
	coil.side="ally"
	trooper.special.action="tesla_charge"
	trooper.special.target=coil
	trooper.special.tesla_approach={"coil":coil,"epoch":battle.path_service.epoch,"cursor":0,"retry":10.0,"point":Vector2.INF,"watch":7.99,"anchor":trooper.position}
	Support.approach(trooper,coil,0.02)
	check(trooper.special.get("action")=="tesla_charge",prefix+"player charging order retained when temporarily blocked")
