extends "res://tests/allied_abilities_regression.gd"
## Real Unit/projectile consumers; expected numbers come from EA AttributeModifier.xml.
func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	GM.god_mode=false;GM.one_shot_kill=false
	var target=actor("R3FUTURE","enemy",Vector2(1800,1600))
	for id in ["R3MIRAGE","R3FUTURE","R3HARBINGER"]:
		var unit=actor(id,"ally",Vector2(1500,1600))
		var base_hp: float=unit.max_hp
		var base_range: float=unit.attack_range
		var base_sight: float=unit.sight
		var speed: float=unit.move_speed
		var hits: Array[float]=[]
		for rank in 4:
			unit._grant_veteran(rank,false)
			check(is_equal_approx(unit.max_hp,base_hp*(1.25 if rank>=2 else 1)),id+" rank %d health"%rank)
			check(is_equal_approx(unit.sight,base_sight*(1.25 if rank==3 else 1)),id+" rank %d shroud"%rank)
			check(is_equal_approx(unit.move_speed,speed),id+" rank %d no Yuri speed boost"%rank)
			target.hp=target.max_hp
			unit._fire_shot(target)
			for shot in battle.projectiles_root.get_children():
				if id=="R3MIRAGE":shot._physics_process(0.2)
				else:
					shot.target_point=target.position # Remove collider random scatter from the damage comparison.
					if id=="R3FUTURE":
						for i in 150:
							if shot.splinters.get("neutron_stage","node")=="node":break
							Ra3Expansion.tick_shot(shot,1.0/15.0)
					Ra3Expansion.tick_shot(shot,0.25 if id=="R3FUTURE" else 2.0)
			hits.append(target.max_hp-target.hp)
			for shot in battle.projectiles_root.get_children():shot.free()
		check(hits[0]>0 and is_equal_approx(hits[1],hits[0]*1.25),id+" veteran bonus reaches actual hit once",hits)
		check(is_equal_approx(hits[2],hits[1]),id+" elite keeps veteran damage",hits)
		check(is_equal_approx(hits[3],hits[0]*(1.5625 if id=="R3MIRAGE" else 1.25)),id+" heroic weapon plus inherited damage",hits)
		check(is_equal_approx(unit.attack_range,base_range*(1.5 if id=="R3MIRAGE" else 1.25)),id+" heroic range")
		var cycle: float=1.35 if id=="R3MIRAGE" else (2.5 if id=="R3FUTURE" else 2.0/1.2)
		check(is_equal_approx(unit.cooldown,cycle),id+" heroic firing interval",unit.cooldown)
		unit.hp=unit.max_hp-100
		unit.special.erase("ra3_heal_remaining");unit.special.erase("ra3_passive_heal_remaining")
		var before: float=unit.hp
		if id=="R3MIRAGE":Ra3Mirage.tick_heroic_heal(unit,1.0)
		else:Ra3Expansion.tick(unit,1.0)
		check(is_equal_approx(unit.hp-before,3.0 if id=="R3MIRAGE" else 5.0),id+" native heroic and independent passive healing")
		if id=="R3HARBINGER":
			Ra3Expansion.use(unit,Vector2.ZERO)
			check(is_equal_approx(unit.attack_range,562.5) and is_equal_approx(unit.cooldown,0.1/1.2),"heroic gun mode retains range and ROF")
			var front:Dictionary=preload("res://scripts/units/ra3_gunship_mounts.gd").states(unit).front
			front.used=9;front.remaining=0.4
			Ra3Expansion.use(unit,Vector2.ZERO);Ra3Expansion.tick(unit,0.1);Ra3Expansion.use(unit,Vector2.ZERO)
			check(unit.special.ra3_clip==9 and is_equal_approx(unit._cd_timer,0.3),"mode switch retains magazine and advances independent cooldown")
			front.used=0;front.remaining=0
			var old: float=target.hp
			unit._fire_shot(target)
			for shot in battle.projectiles_root.get_children():Ra3Expansion.tick_shot(shot,0.1);shot.free()
			check(is_equal_approx(old-target.hp,Ra3Expansion.raw_damage(6,"AUTO_CANNON",target)*1.25),"heroic autocannon actual damage")
			var codec=preload("res://scripts/save/battle_snapshot.gd").new()
			var snapshot=codec.capture(battle)
			check(not snapshot.is_empty(),"heroic gunship snapshot is serializable")
			codec.restore(battle,snapshot)
			unit=battle.units.filter(func(u):return u.unit_id=="R3HARBINGER")[0]
			check(unit.veteran_level==3 and is_equal_approx(unit.max_hp,6250) and is_equal_approx(unit.attack_range,562.5),"snapshot restores rank health and active weapon")
			before=unit.hp;Ra3Expansion.tick(unit,0.5)
			check(is_equal_approx(unit.hp-before,5.0),"snapshot resumes both heal clocks without restart")
			unit._grant_veteran(0,false);before=unit.hp
			Ra3Expansion.tick(unit,0.5)
			check(is_equal_approx(unit.hp-before,2.0),"recruit gunship retains passive heal but loses heroic heal")
		else:remove_actor(unit)
	screen.free();await get_tree().process_frame
