extends "res://tests/tanya_talents_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for scenario in ["owner_dead","owner_house_lost","restore_house_lost","other_house_lost"]:
		await chain_lifecycle(scenario)
		await field_lifecycle(scenario)
	await late_burning_landing()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("HERO_EFFECT_LIFECYCLE_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func chain_lifecycle(scenario:String) -> void:
	var hero=setup_talents(5,0)
	BattleRequest.house_teams={"ally":1,"enemy":2,"ai2":1}
	battle.mission.victory_condition="short"
	var ally_base=battle._place_building("NAPOWR","ai2",Vector2(1900,1900),true)
	ally_base._buildup_play=-1
	var primary=battle._place_building("NAPOWR","enemy",Vector2(1400,1100),true)
	var secondary=battle._place_building("NAPOWR","enemy",Vector2(1500,1100),true)
	primary.special.c4_left=.01;primary.special.c4_owner=hero
	AlliedAbilities.tick_actor(primary,.02)
	check(secondary.special.get("c4_secondary",false) and secondary.special.get("c4_left")==4.,"real original C4 creates chained charge "+scenario)
	check(hero.special[C.KEY].chain_used==1 and hero.special[C.KEY].chain_cd==60,"successful chain spends use and cooldown "+scenario)
	var before:float=secondary.hp
	if scenario=="owner_dead":
		hero._die()
		battle._check_end()
		check(not battle.house_defeated("ally") and not battle.ended,"hero death alone leaves owner house active")
	else:
		var lost:="ai2" if scenario=="other_house_lost" else "ally"
		for building in battle.buildings:
			if building.side==lost:building.hp=0
		for unit in battle.units:
			if unit.side==lost and not unit.deploy_building_id().is_empty():unit.hp=0
		battle._check_end()
		check(battle.house_defeated(lost) and not battle.ended,"real house elimination leaves surviving teams playing "+scenario)
		if lost=="ally":check(not AlliedAbilities.alive(hero),"elimination removes original hero while enemy-attached charge remains to validate")
	if scenario=="restore_house_lost":
		var codec=BattleSaves.Snapshot.new()
		var snapshot:Dictionary=codec.capture(battle)
		var path:=output_dir.path_join("chain-after-defeat.bin")
		var file=FileAccess.open(path,FileAccess.WRITE);file.store_var(snapshot,false);file.close()
		file=FileAccess.open(path,FileAccess.READ);snapshot=file.get_var(false);file.close()
		codec.restore(battle,snapshot)
		for building in battle.buildings:
			if building.position.is_equal_approx(Vector2(1500,1100)):secondary=building
		check(codec.error.is_empty() and battle.house_defeated("ally") and secondary.special.get("c4_side")=="ally","disk snapshot keeps fixed chain owner side and defeated house")
	AlliedAbilities.tick_actor(secondary,.01)
	if scenario in ["owner_house_lost","restore_house_lost"]:
		check(secondary.hp==before and not secondary._dead and not secondary.special.has("c4_left"),"defeated owner cancels chain before countdown damage "+scenario)
		check(not secondary.special.has("c4_owner") and not secondary.special.has("c4_secondary") and not secondary.special.has("c4_side"),"cancel clears all chain identity and countdown keys "+scenario)
		AlliedAbilities.tick_actor(secondary,5.)
		check(secondary.hp==before and not secondary._dead,"cancelled chain never detonates later "+scenario)
	else:
		check(secondary.special.has("c4_left"),"hero death or different house defeat does not cancel valid chain "+scenario)
		AlliedAbilities.tick_actor(secondary,4.)
		check(secondary._dead,"valid chain still detonates after owner death or other house loss "+scenario)
	await finish()

func field_lifecycle(scenario:String) -> void:
	const Air=preload("res://scripts/units/expansion_2_aircraft.gd")
	const Inf=preload("res://scripts/units/expansion_2_infantry.gd")
	const Cal=preload("res://scripts/units/expansion_2_calibration.gd")
	const Pull=preload("res://scripts/units/expansion_2_tractor.gd")
	const Seal=preload("res://scripts/units/expansion_2_overload.gd")
	var owner=setup_talents(0,0)
	BattleRequest.house_teams={"ally":1,"enemy":2,"ai2":1}
	battle.mission.victory_condition="short"
	battle._place_building("NAPOWR","ai2",Vector2(1900,1900),true)
	var target=robust_enemy("HTNK",Vector2(1400,1100))
	var aircraft=robust_enemy("JUMPJET",Vector2(1500,1300))
	check(aircraft.is_air_target(),"lifecycle fixture includes actual air-domain target "+scenario)
	# Pending-effect fixtures isolate lifecycle after normal creation, covered by each native-shot suite.
	var weapon:Dictionary={"damage":100.,"attack_type":"explosive"}
	var bonus:Dictionary={"expansion_extra":true,"damage_owner_side":"ally","reference_weapon":weapon.duplicate(true)}
	battle.allied_state[Air.FIELDS]=[{"owner":owner,"side":"ally","point":target.position,"age":0.,"next":.5,"weapon":weapon,"bonus":bonus}]
	battle.allied_state[Inf.SHARDS]=[{"owner":owner,"side":"ally","target":aircraft,"point":aircraft.position,"visual":aircraft.position,"left":.8,"weapon":weapon,"bonus":bonus}]
	battle.allied_state[Cal.ZONES]=[{"owner":owner,"side":"ally","point":target.position,"left":4.,"damage":.2}]
	var payload:Dictionary={"owner":owner,"side":"ally","radius":110.,"weapon":weapon,"bonus":bonus}
	Pull.landed(battle,target.position+Vector2(20,0),payload)
	target.special[Seal.KEY]={"owner":owner,"side":"ally","target_side":"enemy","left":7.,"cooldown":0.,"remaining":3,"weapon":weapon,"bonus":bonus}
	battle.allied_state[Seal.TARGETS]=[target];Seal.fired(target)
	check(battle.allied_state.get(Seal.EVENTS,[]).size()==1,"ordinary-fire callback queues one pending overload event "+scenario)
	if scenario=="owner_dead":owner._die()
	else:
		var lost:="ai2" if scenario=="other_house_lost" else "ally"
		for building in battle.buildings:
			if building.side==lost:building.hp=0
	battle._check_end()
	var cancelled:=scenario in ["owner_house_lost","restore_house_lost"]
	check(battle.house_defeated("ally")==cancelled and not battle.ended,"field fixture uses live house elimination and surviving teammate "+scenario)
	if scenario=="restore_house_lost":
		var codec=BattleSaves.Snapshot.new();var saved:Dictionary=codec.capture(battle)
		var path:=output_dir.path_join("fields-after-defeat.bin")
		var file=FileAccess.open(path,FileAccess.WRITE);file.store_var(saved,false);file.close()
		file=FileAccess.open(path,FileAccess.READ);saved=file.get_var(false);file.close();codec.restore(battle,saved)
		for unit in battle.units:
			if unit.unit_id=="HTNK" and unit.side=="enemy":target=unit
			if unit.unit_id=="JUMPJET" and unit.side=="enemy":aircraft=unit
		check(codec.error.is_empty() and battle.allied_state.get(Air.FIELDS,[]).size()==1,"disk snapshot retains pending field for cancellation audit")
	target.process_mode=Node.PROCESS_MODE_ALWAYS;target.set_process(false);target.set_physics_process(false)
	await get_tree().physics_frame
	var hp:float=target.hp;var air_hp:float=aircraft.hp;var point:Vector2=target.position
	Air.world_tick(battle,.5)
	check((target.hp==hp)==cancelled and battle.allied_state.has(Air.FIELDS)!=cancelled,"burning field stops only after owning house defeat "+scenario)
	Inf.world_tick(battle,.8)
	check((aircraft.hp==air_hp)==cancelled and not battle.allied_state.has(Inf.SHARDS),"attached shard cancels on defeat but survives caster death "+scenario)
	check(is_equal_approx(Cal.bonus_at(battle,"ally",target),0. if cancelled else .2),"calibration lookup cannot use defeated-owner zone before cleanup "+scenario)
	Cal.world_tick(battle,.01)
	check(battle.allied_state.has(Cal.ZONES)!=cancelled,"calibration region removed only for defeated owner "+scenario)
	hp=target.hp
	Pull.world_tick(battle,2.1)
	check((target.hp==hp)==cancelled and not battle.allied_state.has(Pull.FIELDS),"tractor stops pull and burst on defeat "+scenario)
	if cancelled:check(target.position==point,"defeated tractor performs no displacement before cancellation "+scenario)
	hp=target.hp
	check(Seal.valid(target,target.special.get(Seal.KEY,{}))!=cancelled,"overload ceases to be valid immediately on owner defeat "+scenario)
	Seal.world_tick(battle,.1)
	check((target.hp==hp)==cancelled and not battle.allied_state.has(Seal.EVENTS),"queued overload cannot damage after house defeat "+scenario)
	check(target.special.has(Seal.KEY)!=cancelled and battle.allied_state.has(Seal.TARGETS)!=cancelled,"overload mark and tracking list cleared together "+scenario)
	if cancelled:
		Pull.landed(battle,point,payload)
		check(not battle.allied_state.has(Pull.FIELDS),"late native missile landing cannot recreate defeated-owner tractor field")
	await finish()

func late_burning_landing() -> void:
	const Air=preload("res://scripts/units/expansion_2_aircraft.gd")
	var owner=setup_talents(0,0)
	var target=robust_enemy("HTNK",Vector2(1400,1100))
	var shot:=Projectile.new()
	shot.setup(owner.position,target,{"damage":100.,"speed":500.,"attack_type":"missile"},1.,{"expansion_burning":.3},"ally",owner)
	shot.splinters.burning_create=true
	battle.projectiles_root.add_child(shot)
	BattleRequest.house_teams={"ally":1,"enemy":2,"ai2":1}
	battle._place_building("NAPOWR","ai2",Vector2(1900,1900),true)
	for building in battle.buildings:
		if building.side=="ally":building.hp=0
	battle._check_end()
	check(battle.house_defeated("ally") and is_instance_valid(owner),"late-impact fixture retains owner object during actual elimination callback frame")
	Air.finish(shot)
	check(not battle.allied_state.has(Air.FIELDS) and not shot.splinters.has("burning_create"),"pending native projectile callback cannot recreate burning after owner-house defeat")
	shot.queue_free()
	await finish()
