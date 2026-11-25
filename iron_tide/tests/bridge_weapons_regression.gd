extends "res://tests/ground_control_regression.gd"
const Bridges = preload("res://scripts/world/bridge_damage.gd")
const Native = preload("res://scripts/world/native_maps.gd")
const Rockets = preload("res://scripts/units/soviet_advanced.gd")
const Death = preload("res://scripts/core/yr_death_combat.gd")
var deck: Rect2
var victim

func exercise(mode: String) -> void:
	for layout in ["yr_crctbrd","river_delta"]:
		prefix = mode+"/"+layout+": "
		BattleRequest.configure_skirmish(mode,{"map_layout":layout,"opening":"mcv","fog_of_war":false})
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		deck = Native.data(layout).bridge_decks[0] if Native.has(layout) else battle.allied_state.repaired_bridges[0]
		guarded_bridge()
		victim = spawn_actor("MTNK","ally",deck.get_center())
		victim.max_hp = 1000000; victim.hp = victim.max_hp
		for id in ["MTNK","FV","ORCA","HORNET"]: projectile_case(id)
		instant_case()
		air_case(false)
		air_case(true)
		for id in ["V3","DRED"]:
			for elite in [false,true]: rocket_case(id,elite,false)
		rocket_case("V3",false,true)
		splash_cases()
		superweapon_cases()
		await finish()

func guarded_bridge() -> void:
	var sections:=Bridges.sections(battle,deck)
	var section:Rect2=sections[sections.size()/2]
	var center:=section.get_center()
	Bridges.hit(battle,center,100.0)
	var health_before:Dictionary=battle.allied_state[Bridges.KEY].duplicate()
	check(Bridges.health(battle,section)==Bridges.strength()-100.0,prefix+"unprotected bridge takes damage")
	battle.allied_state.expedition_bridge_guard=true
	var damage:=Bridges.strength()*2.0
	Bridges.hit(battle,center,damage)
	Bridges.blast(battle,center,damage,"",150.0)
	Bridges.blast(battle,center,damage,"NUKE")
	Bridges.damage_section(battle,section,damage)
	check(battle.allied_state[Bridges.KEY]==health_before and battle.path_service.bridge_at(center).has_area(),prefix+"guard preserves every affected bridge section and the crossing")
	battle.allied_state.erase("expedition_bridge_guard")
	reset_bridge()

func spawn_actor(id: String, side: String, point: Vector2):
	var actor = battle.spawn_unit(id,"ally",point)
	if side != "ally": AlliedAbilities.change_side(actor,side)
	activate(actor)
	return actor

func reset_bridge() -> void:
	Bridges.reset_health(battle,deck)

func loss() -> float:
	return Bridges.strength()-Bridges.health(battle,Bridges.section_at(battle,deck.get_center()))

func projectile_case(id: String) -> void:
	reset_bridge()
	var shooter = spawn_actor(id,"enemy",deck.get_center()+Vector2(-100,0))
	shooter.set_fire_stance("aggressive")
	if shooter.is_air: shooter.order_target(victim,false,false)
	else: shooter._refresh_target()
	check(shooter.attack_target is Unit or shooter.attack_target is Building,prefix+id+" AI selects actor, never bridge")
	check(not ForceFire.active(shooter,shooter.attack_target),prefix+id+" attack uses normal actor order")
	shooter.attack_target = victim
	shooter._fire_shot(victim)
	var found := false
	for shot in battle.projectiles_root.get_children():
		if not shot is Projectile or shot.shooter()!=shooter: continue
		found = true
		shot._explode()
		var damage := loss()
		check(damage>0.0,prefix+id+" ordinary AI shot damages bridge below ground target",damage)
		shot._explode()
		check(is_equal_approx(loss(),damage),prefix+id+" impact cannot damage bridge twice")
	check(found,prefix+id+" normal weapon created projectile")
	AlliedAbilities.consume(shooter)

func instant_case() -> void:
	reset_bridge()
	var shooter = spawn_actor("SHK","enemy",deck.get_center()+Vector2(-100,0))
	shooter.attack_target = victim
	shooter._fire_shot(victim)
	check(loss()>0.0,prefix+"AI instantaneous weapon damages bridge under target")
	var bridge_damage := loss()
	AlliedAbilities.consume(shooter)
	reset_bridge()
	var original_armor: String = victim.ra2_armor
	victim.ra2_armor = "none"
	shooter = spawn_actor("SHK","enemy",deck.get_center()+Vector2(-100,0))
	shooter.attack_target = victim
	shooter._fire_shot(victim)
	check(is_equal_approx(loss(),bridge_damage),prefix+"bridge damage does not inherit victim armor")
	victim.ra2_armor = original_armor
	AlliedAbilities.consume(shooter)

func air_case(remove_target: bool) -> void:
	reset_bridge()
	var air = spawn_actor("ZEP","ally",deck.get_center())
	var shooter = spawn_actor("FV","enemy",deck.get_center()+Vector2(-100,0))
	shooter.attack_target = air
	shooter._fire_shot(air)
	var found := false
	if remove_target: AlliedAbilities.consume(air)
	for shot in battle.projectiles_root.get_children():
		if not shot is Projectile or shot.shooter()!=shooter: continue
		found = true
		shot._explode()
	check(found and is_zero_approx(loss()),prefix+"air interception cannot damage bridge, removed target="+str(remove_target),loss())
	if not remove_target: AlliedAbilities.consume(air)
	AlliedAbilities.consume(shooter)

func rocket_case(id: String, elite: bool, intercept: bool) -> void:
	reset_bridge()
	var launcher = spawn_actor(id,"enemy",deck.get_center()+Vector2(-550,0))
	launcher.veteran_level = 2 if elite else 0
	launcher.attack_target = victim
	launcher._fire_shot(victim)
	var missile = null
	for actor in battle.units:
		if actor.special.get("flight",{}).get("source") == launcher: missile = actor; break
	check(missile!=null,prefix+id+" launches real missile elite="+str(elite))
	if missile==null: return
	missile.set_physics_process(false)
	var expected: float = float(launcher.data.rocket.elite_damage if elite else launcher.data.rocket.damage)
	expected = minf(Bridges.strength(),CombatMath.with_offense(expected,missile.special.flight.bonus))
	if intercept: AlliedAbilities.consume(missile)
	for tick in 3600:
		Rockets.fly(missile,1.0/60.0)
		if missile._dead: break
	check(missile._dead,prefix+id+" flight reaches terminal state")
	check(is_equal_approx(loss(),0.0 if intercept else expected),prefix+id+" landing bridge damage elite="+str(elite)+" intercepted="+str(intercept),[loss(),expected])
	var damage := loss()
	Rockets.fly(missile,1.0)
	check(is_equal_approx(loss(),damage),prefix+id+" consumed missile cannot detonate twice")
	AlliedAbilities.consume(launcher)

func splash_cases() -> void:
	var point := Vector2(deck.get_center().x,deck.position.y-20.0)
	var target := ForceFirePoint.new(); target.global_position = point
	var weapon: Dictionary = GameData.get_unit("FV").weapon.duplicate(true)
	weapon.damage = 100.0; weapon.ra2_warhead = "YR_SOV_V3WH"
	for side in ["ally","enemy","ai2"]:
		reset_bridge()
		var shot := Projectile.new()
		shot.setup(point,target,weapon,100.0,{},side)
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		battle.projectiles_root.add_child(shot)
		shot._explode()
		var expected := 100.0*Ra2Damage.distance_factor(20.0,weapon.ra2_warhead)
		check(is_equal_approx(loss(),expected),prefix+side+" adjacent explosion applies falloff once per section",[loss(),expected])
	reset_bridge()
	Bridges.blast(battle,Vector2(deck.get_center().x,deck.position.y-1000),100.0,weapon.ra2_warhead)
	check(is_zero_approx(loss()),prefix+"out of blast radius preserves bridge")
	# No live units are required for an explosion to damage terrain.
	AlliedAbilities.consume(victim)
	reset_bridge()
	Death.queue_blast(battle,deck.get_center(),"enemy",200.0,"YR_SOV_V3WH")
	check(is_equal_approx(loss(),200.0),prefix+"independent explosion damages empty bridge once")

func superweapon_cases() -> void:
	reset_bridge()
	preload("res://scripts/buildings/support_systems.gd").storm_damage_at(battle,{"warhead":"IonWH","damage":250.0},deck.get_center())
	check(is_equal_approx(loss(),250.0),prefix+"lightning strike damages bridge")
	reset_bridge()
	var payload: Dictionary = preload("res://scripts/core/yr_death_rules.gd").data().weapons.NUKEPAYLOAD
	battle.allied_state.soviet_nukes = [{"left":0.0,"point":deck.get_center(),"side":"enemy","damage_scale":1.0}]
	preload("res://scripts/units/soviet_specials.gd").tick_world(battle,0.01)
	check(is_equal_approx(loss(),minf(Bridges.strength(),float(payload.damage))),prefix+"AI nuclear missile detonates through actual world queue",loss())
	for round_index in range(1,ceili(Bridges.strength()/float(payload.damage))):
		battle.allied_state.soviet_nukes = [{"left":0.0,"point":deck.get_center(),"side":"enemy","damage_scale":1.0}]
		preload("res://scripts/units/soviet_specials.gd").tick_world(battle,0.01)
	check(Bridges.health(battle,Bridges.section_at(battle,deck.get_center()))==0.0 and not battle.path_service.bridge_at(deck.get_center()).has_area(),prefix+"successive AI nuclear missiles destroy bridge and close crossing")
