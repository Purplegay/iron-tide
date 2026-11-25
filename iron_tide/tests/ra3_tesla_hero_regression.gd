extends "res://tests/allied_abilities_regression.gd"
const Soviet=preload("res://scripts/units/ra3_soviet.gd")
const Model=preload("res://scripts/units/ra3_expansion_model.gd")

func aim(tank,target) -> void:
	tank.attack_target=target;tank.attack_ordered=true;tank.set_fire_stance("defend")
	tank.hull_angle=0.0;tank.turret_angle=0.0

func exercise_mode(mode:String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"苏俄")
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var tank=actor("R3TESLA","ally",Vector2(1500,1500))
	var victim=actor("R3APOC","enemy",tank.position+Vector2(70,0))
	check(tank.veterancy_status().required==6600.0 and tank._vet_need==6600.0,"new tank uses first promotion threshold for HUD and training")
	victim.receive_hit(999999,"tesla",{},tank,"RA3_EXPANSION")
	check(tank.veteran_level==0 and tank._vet_kills==2000.0,"one fresh Apocalypse kill awards exactly 2000")
	for current in 3:
		tank.credit_kill(6599-tank._vet_kills,"enemy")
		check(tank.veteran_level==current and tank.veterancy_status().current==6599,"one XP below promotion "+str(current+1))
		tank.credit_kill(1,"enemy")
		check(tank.veteran_level==current+1 and tank._vet_kills==0,"exact promotion "+str((current+1)*6600))
	var target=actor("MTNK","enemy",tank.position+Vector2(100,0))
	target.hp=10000;target.max_hp=10000
	aim(tank,target)
	var model=Model.new();model.actor=tank;tank.add_child(model);model._build();model.set_process(false);tank._ra3_model=model
	var coil=model.parts.FX_LIGHTNINGCHARGE
	model._sample(0);check(not coil.visible,"hero charge mesh is off at rest")
	check(not tank._try_fire_ready() and tank.special.has("tesla_charge_up"),"first trigger arms charge only")
	Soviet.tick(tank,0.10);model._sample(0.10)
	check(coil.visible and coil.material_override.get_shader_parameter("opacity")>0.2 and not tank._try_fire_ready() and target.hp==10000 and tank._muzzle==0,"coil charges before discharge or damage")
	tank.order_stop();check(not tank.special.has("tesla_charge_up"),"stop cancels windup immediately")
	aim(tank,target);tank._try_fire_ready();Soviet.tick(tank,0.08)
	var codec=preload("res://scripts/save/battle_snapshot.gd").new();var snap=codec.capture(battle);codec.restore(battle,snap)
	tank=battle.units.filter(func(u):return u.unit_id=="R3TESLA")[0]
	target=tank.attack_target
	check(tank.special.tesla_charge_up.target==target and is_equal_approx(tank.special.tesla_charge_up.age,0.08),"mid-charge save restores the same opponent and elapsed time")
	Soviet.tick(tank,0.11);check(not tank._try_fire_ready() and target.hp==10000,"no early discharge after reload")
	Soviet.tick(tank,0.01);check(tank._try_fire_ready() and target.hp<10000,"release occurs at 0.20 seconds")
	var hp:float=target.hp
	Soviet.tick(tank,0.17);check(tank._try_fire_ready() and target.hp<hp,"same-target second coil follows heroic burst interval")
	Soviet.tick(tank,1.50);tank._try_fire_ready()
	var next=actor("MTNK","enemy",tank.position+Vector2(90,0));aim(tank,next)
	Soviet.tick(tank,0.20)
	check(not tank._try_fire_ready() and tank.special.tesla_charge_up.target==next and tank.special.tesla_charge_up.age==0,"changed target must charge again")
	screen.free();await get_tree().process_frame
