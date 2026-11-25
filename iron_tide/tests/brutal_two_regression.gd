extends "res://tests/ground_control_regression.gd"

func exercise(mode:String) -> void:
	for country in ["美国","苏俄"]:
		BattleRequest.configure_skirmish(mode,{"map_size":2400,"difficulty":5,"enemy_country":country,"starting_funds":8000})
		screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
		prefix=mode+country+": "
		check(battle.skirmish_ai.difficulty==5 and battle.mission.subtitle.contains("凶残2"),prefix+"difficulty reaches battle")
		for pair in [["attack_bonus",1.3],["defense_bonus",1.3],["hp_bonus",1.4],["speed_bonus",1.2],["build_bonus",1.3],["deploy_bonus",.2],["income_bonus",1.0],["cap_bonus",1.0]]:
			check(is_equal_approx(BattleRequest.enemy_logistics()[pair[0]],pair[1]),prefix+str(pair[0]))
		check(is_equal_approx(battle.ai_build_factor("enemy"),1.95),prefix+"one production multiplier")
		check(is_equal_approx(battle.enemy_funds,battle.funds*7.2),prefix+"opening funds inherit brutal plus deploy level ten")
		for id in ["HTNK","E1","ORCA","SUB"]:
			var unit=battle.spawn_unit(id,"enemy",Vector2(1200,1200));activate(unit)
			check(is_equal_approx(unit.max_hp,unit.base_hp*1.4) and is_equal_approx(unit.move_speed,unit.base_speed*1.2),prefix+id+" body growth")
			check(is_equal_approx(unit.bonuses.attack_bonus,1.3*1.24) and is_equal_approx(unit.bonuses.defense_bonus,1.3*1.2) and is_equal_approx(unit.skill_power,1.0),prefix+id+" training eight; retired generic skill track stays inactive")
		var codec=BattleSaves.Snapshot.new();var saved:Dictionary=codec.capture(battle)
		codec.restore(battle,saved)
		check(battle.skirmish_ai.difficulty==5,prefix+"restored difficulty")
		var next=battle.spawn_unit("HTNK","enemy",Vector2(1300,1200))
		check(is_equal_approx(next.bonuses.attack_bonus,1.612) and is_equal_approx(next.max_hp,next.base_hp*1.4),prefix+"post-load reinforcement uses frozen growth")
		await finish()
	check(is_equal_approx(GameData.skirmish_logistics(4).attack_bonus,1.15) and is_equal_approx(GameData.skirmish_unit_upgrades(4).attack_bonus,1.09),mode+"brutal one unchanged")
	for i in 4:check(GameData.skirmish_logistics(i)==MatchRules.neutral_bonuses(),mode+"old difficulty unchanged "+str(i))
