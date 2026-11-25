extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog!=null: battle.fog.free(); battle.fog=null
	var tank=actor("R3MIRAGE","ally",Vector2(1800,1800))
	# Independent SDK baselines: Barracks1000, Guardian480, Peacekeeper150.
	# Expected hits include the first shot; no regeneration or progression.
	for row in [["GAPILE",500.0,100.0,5],["MTNK",300.0,125.0,3],["E1",125.0,200.0*125.0/150.0,1],["R3MIRAGE",500.0,200.0,3]]:
		var target=make_target(row[0])
		tank._grant_veteran(0,false); tank.bonuses={}
		check(target.data.hp==row[1],row[0]+": baseline HP unchanged")
		check(is_equal_approx(CombatMath.full_damage(tank.weapon,target.armor,{},null,target.ra2_armor,0.0,target),row[2]),row[0]+": SDK-relative damage")
		var shots:=0
		while not target._dead and shots<10:
			tank._fire_shot(target); resolve_ra3_hits(); shots+=1
		check(shots==row[3] and target._dead,row[0]+": actual primary hits to kill match RA3 reference",shots)
		check(target.data.hp==row[1],row[0]+": combat never rewrites target config")
		remove_actor(target)
	var target=make_target("MTNK")
	tank._grant_veteran(0,false); tank.bonuses={}
	target.hp=90; target.max_hp=600
	check(is_equal_approx(CombatMath.full_damage(tank.weapon,target.armor,{},null,target.ra2_armor,0.0,target),125.0),"wounds and health upgrades never amplify incoming base damage")
	target.hp=600; target.bonuses={"defense_bonus":2.0,"veteran_defense":1.5}
	tank.bonuses={"attack_bonus":1.2}
	tank._fire_shot(target); resolve_ra3_hits()
	check(is_equal_approx(target.hp,550.0),"attacker progression and target defense each applied once")
	tank._grant_veteran(3,false); tank.bonuses={"veteran_attack":1.25}
	check(is_equal_approx(CombatMath.full_damage(tank._active_weapon(),target.armor,tank.bonuses,null,target.ra2_armor,0.0,target),195.3125),"heroic weapon250 and native firepower1.25 retained")
	target.bonuses={}; target.hp=300
	target.receive_hit(10.9,"bullet",{},null,"")
	check(target.hp==290.0,"ordinary Yuri damage still floors positive fractions")
	remove_actor(target)
	# Fractional cross-game scatter must not add a seventh hit through rounding.
	target=make_target("E1")
	var scatter={"damage":25.0,"ra2_warhead":"RA3_PRISM"}
	var damage:=CombatMath.full_damage(scatter,target.armor,{},null,target.ra2_armor,0.0,target)
	for i in 5: target.receive_hit(damage,"prism",{},null,"RA3_PRISM")
	check(not target._dead and target.hp>0,"five scatter hits leave reference infantry alive")
	target.receive_hit(damage,"prism",{},null,"RA3_PRISM")
	check(target._dead,"six scatter hits kill exactly, without integer truncation drift")
	remove_actor(target)
	target=make_target("FV")
	check(is_equal_approx(Ra3MirageDamage.raw_damage(tank.weapon,target),200.0*1.7*float(target.data.hp)/360.0),"IFV consumes SDK inherited PRISM vulnerability170 percent")
	remove_actor(target)
	screen.free(); Music.stop(); Ra2Sfx.stop_all()
	await get_tree().process_frame

func make_target(id: String):
	var target
	if id=="GAPILE":
		target=battle._place_building(id,"enemy",Vector2(1950,1800),true)
		target._buildup_play=-1.0; target.set_process(false)
	else:
		target=actor(id,"enemy",Vector2(1950,1800))
		target.set_process(false)
	target.bonuses={}; target.hp=float(target.data.hp); target.max_hp=target.hp
	return target
