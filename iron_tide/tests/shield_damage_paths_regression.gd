extends "res://tests/tank_hero_regression.gd"
const Shield=preload("res://scripts/units/tank_hero_shield.gd")

func load_shield(unit) -> void:
	unit.hp=unit.max_hp
	unit._hp_flash=0
	unit.special[Shield.KEY]={"hp":unit.max_hp*0.5,"left":120.0,"charge":0.0,"point":unit.global_position}

func impact(unit,shooter,weapon:Dictionary) -> void:
	if shooter.unit_id in ["V3","DRED"]:
		var missile=Unit.SovietWeapons._launch_missile(shooter,unit,shooter.data.rocket,shooter.unit_id=="DRED",shooter.position,1.0)
		missile.set_physics_process(false)
		for i in 900:
			if missile._dead:break
			Unit.SovietWeapons.fly(missile,0.1)
		check(missile._dead,"native missile reaches detonation "+shooter.unit_id)
		return
	var damage:=CombatMath.full_damage(weapon,unit.armor,shooter.bonuses,null,unit.ra2_armor,0.0,unit)
	var shot:=Projectile.new()
	shot.setup(shooter.global_position,unit,weapon,damage,shooter.bonuses,"enemy",shooter)
	# Resolve at the contact point, including a bomber's ground impact.
	shot.target_point=unit.global_position
	battle.add_child(shot);shot.set_physics_process(false);shot._explode()

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	MetaProgress.reset_save();start(MatchRules.EXTENDED)
	GM.god_mode=false;GM.one_shot_kill=false
	for hero_id in Hero.IDS:
		var unit=hero(hero_id,0,0,Vector2(1100,1100))
		unit.max_hp=1000000;unit.hp=unit.max_hp
		for shooter_id in ["E1","MTNK","HTNK","APOC","FV","SREF","DEST","DRED","V3","ZEP","SHK","DESO","R3APOC","R3TESLA","R3FUTURE"]:
			var shooter=battle.spawn_unit(shooter_id,"enemy",Vector2(1350,1100))
			shooter.set_physics_process(false)
			var weapon:Dictionary=shooter._active_weapon().duplicate(true)
			load_shield(unit)
			var hp:float=unit.hp;var shield:float=Shield.amount(unit)
			impact(unit,shooter,weapon)
			var absorbed:float=shield-Shield.amount(unit)
			check(is_equal_approx(unit.hp,hp) and absorbed>0,hero_id+" projectile shield protects health from "+shooter_id,absorbed)
			Shield.clear(unit);impact(unit,shooter,weapon)
			check(is_equal_approx(hp-unit.hp,absorbed),hero_id+" shield debit equals control health damage "+shooter_id,[absorbed,hp-unit.hp])
			battle.units.erase(shooter);shooter.free()
		for kind in ["bullet","shell","missile","explosion","laser","tesla","radiation","sonic","crush"]:
			for warhead in ["","RA3_PRISM","RA3_EXPANSION","RadSite","YR_SOV_Parasite"]:
				load_shield(unit);var hp:float=unit.hp
				unit.receive_hit(25.75,kind,{},null,warhead)
				var debit:float=unit.max_hp*0.5-Shield.amount(unit)
				check(unit.hp==hp and debit>0,hero_id+" common receiver blocks "+kind+warhead)
				check(unit._hp_flash==0 and unit.get_meta(Shield.LAST_HIT).health_damage==0,hero_id+" blocked hit has shield-only feedback "+kind+warhead)
		load_shield(unit)
		unit.special[Shield.KEY].hp=5
		var prior:float=unit.hp
		unit.receive_hit(100,"shell")
		var hit:Dictionary=unit.get_meta(Shield.LAST_HIT)
		check(hit.absorbed==5 and hit.health_damage>0 and is_equal_approx(prior-unit.hp,hit.health_damage),hero_id+" overflow feedback matches actual shield and health loss")
		check(unit._hp_flash==1 and Shield.hit_caption(hit.absorbed,hit.health_damage).contains("生命"),hero_id+" overflow still flashes health and reports both values")
		check(Shield.describe(unit).contains("最近一次护盾受击"),hero_id+" details exposes actual last absorption")
		battle.units.erase(unit);unit.free()
	await get_tree().process_frame
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
