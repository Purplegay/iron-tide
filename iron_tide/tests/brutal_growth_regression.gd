extends "res://tests/ground_control_regression.gd"
const Academy=preload("res://scripts/rules/academy.gd")

func exercise(mode:String) -> void:
	for raw in [1.0,1.6,2.0,3.12,5.0,10.0,100.0]:
		var value:=CombatMath.compress_growth(raw,3.5)
		check(is_equal_approx(value,raw) if raw<=2 else value>2 and value<3.5 and value<raw,"curve bounds "+str(raw))
	check(is_equal_approx(CombatMath.compress_growth(3.12,3.5),2.53704749),"20-level combination retains about 254%",CombatMath.compress_growth(3.12,3.5))
	var previous:=2.0
	for i in range(1,100):
		var value:=CombatMath.compress_growth(2.0+i*.1,3.5)
		check(value>previous,"growth remains monotonic "+str(i));previous=value
	for difficulty in [4,5]:
		BattleRequest.configure_skirmish(mode,{"map_size":2400,"difficulty":difficulty,"starting_funds":8000})
		screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
		var active:bool=mode==MatchRules.EXTENDED and difficulty==5
		# Legacy v0.25.81 snapshots retain their source-growth curve, without a second final limiter.
		BattleRequest.combat_context.erase("hero_training_scale") # Legacy save, before per-rank growth was reduced.
		BattleRequest.combat_context.erase("final_damage_cap")
		BattleRequest.combat_context.growth_attack_cap=3.5 if active else 0.0
		check(is_equal_approx(BattleRequest.growth_attack_cap(),3.5 if active else 0.0),mode+str(difficulty)+" rule scope")
		BattleRequest.combat_context.bonuses.attack_bonus=1.95
		BattleRequest.combat_context.loadouts={}
		BattleRequest.combat_context.hero_loadouts={}
		for id in ["E1","E2","MTNK","HTNK","R3MIRAGE","R3FUTURE","R3APOC","DEST","ORCA"]:
			if not GameData.unit_index.has(id):continue
			BattleRequest.combat_context.unit_bonus[id]={"attack_bonus":1.6,"defense_bonus":1.0,"skill_bonus":1.0}
			BattleRequest.combat_context.loadouts[id]={"active":[],"passive":""}
			var u=battle.spawn_unit(id,"ally",Vector2(1100,1000));activate(u)
			var raw:=3.12 if mode==MatchRules.EXTENDED else 1.95
			var expected:=CombatMath.compress_growth(raw,3.5) if active else raw
			check(is_equal_approx(u._base_atk,expected),mode+str(difficulty)+id+" attack assembled once",u._base_atk)
			var plain:Dictionary=u.bonuses.duplicate();plain.attack_bonus=1.0
			for armor in ["none","heavy","concrete"]:
				var base:=CombatMath.full_damage(u.weapon,armor,plain,null,armor)
				check(is_equal_approx(CombatMath.full_damage(u.weapon,armor,u.bonuses,null,armor),base*expected),id+armor+" weapon verses preserved")
			u.add_buff("attack",5,0.5,"regression")
			check(is_equal_approx(u.bonuses.attack_bonus,expected*1.5),id+" temporary skill remains outside curve",u.bonuses.attack_bonus)
			if id in Academy.HEROES and mode==MatchRules.EXTENDED:
				MetaProgress.academy.get_or_add("hero_builds",{})[id]=100
				battle.allied_state.get_or_add("named_heroes",{}).erase(id)
				BattleRequest.combat_context.hero_training[id]={"firepower":150,"health":0}
				Academy.promote(MetaProgress,battle,id,u)
				var hero_expected:=CombatMath.compress_growth(12.48,3.5) if active else 12.48
				check(is_equal_approx(u._base_atk,hero_expected),id+" hero training aggregates before compression",u._base_atk)
				check(is_equal_approx(u.bonuses.attack_bonus,hero_expected*1.5),id+" hero retains temporary skill")
				check(is_equal_approx(CombatMath.with_offense(100,u.bonuses),100*hero_expected*1.5*float(u.bonuses.get("veteran_attack",1))),id+" elite factor remains separate")
		if mode==MatchRules.EXTENDED:
			BattleRequest.combat_context.loadouts.E1={"active":[],"passive":"ps_hollow_point"}
			var equipped=battle.spawn_unit("E1","ally",Vector2(1400,1200));activate(equipped)
			var growth:=CombatMath.compress_growth(3.12,3.5) if active else 3.12
			var factor:=1.0+float(equipped.passive.value)*Unit.Training.card_scale(equipped)
			check(is_equal_approx(equipped._base_atk,growth*factor),"passive damage not absorbed into shield",equipped._base_atk)
			battle.allied_state.get_or_add("named_heroes",{}).erase("E1")
			Academy.promote(MetaProgress,battle,"E1",equipped)
			check(equipped.passive.is_empty() and is_equal_approx(equipped._base_atk,CombatMath.compress_growth(12.48,3.5) if active else 12.48),"promotion removes normal passive without losing growth metadata")
		var building=battle._place_building("TESLA","ally",Vector2(1500,1400),true)
		check(is_equal_approx(building.bonuses.attack_bonus,1.95),"building below threshold unchanged")
		BattleRequest.combat_context.bonuses.attack_bonus=5.0
		var strong=battle._place_building("ATESLA","ally",Vector2(1800,1400),true)
		check(is_equal_approx(strong.bonuses.attack_bonus,CombatMath.compress_growth(5.0,3.5) if active else 5.0),"building higher growth compressed")
		var enemy=battle.spawn_unit("HTNK","enemy",Vector2(1800,1600))
		check(not enemy.bonuses.has("growth_attack_cap"),"enemy difficulty growth not compressed")
		var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
		check(codec.error.is_empty(),"shield snapshot captures")
		var expected_values:Array=[]
		for u in battle.units:expected_values.append(u.bonuses.duplicate(true))
		BattleRequest.skirmish_config.difficulty=0
		BattleRequest.combat_context=snapshot.context.combat_context.duplicate(true)
		codec.restore(battle,snapshot)
		check(codec.error.is_empty(),"shield snapshot restores")
		for i in battle.units.size():check(battle.units[i].bonuses==expected_values[i],"restore does not recompress "+str(i))
		var next=battle.spawn_unit("HTNK","ally",Vector2(1900,1700))
		var next_raw:=8.0 if mode==MatchRules.EXTENDED else 5.0
		check(is_equal_approx(next._base_atk,CombatMath.compress_growth(next_raw,3.5) if active else next_raw),"reinforcement uses saved rule despite changed menu difficulty")
		BattleRequest.combat_context.erase("growth_attack_cap")
		var legacy=battle.spawn_unit("HTNK","ally",Vector2(2000,1700))
		check(is_equal_approx(legacy._base_atk,next_raw),"old context missing shield retains old damage")
		await finish()
