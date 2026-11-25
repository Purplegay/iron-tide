extends "res://tests/ground_control_regression.gd"

func exercise(mode: String) -> void:
	for country in ["美国","苏俄"]:
		BattleRequest.configure_skirmish(mode,{"map_size":2400,"difficulty":4,"enemy_country":country,"starting_funds":8000})
		screen=load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode=Node.PROCESS_MODE_DISABLED
		battle=screen.battle
		prefix=mode+country+": "
		var bonus:=BattleRequest.enemy_logistics()
		for pair in [["attack_bonus",1.15],["defense_bonus",1.15],["hp_bonus",1.2],["speed_bonus",1.1],["build_bonus",1.15],["deploy_bonus",0.1],["income_bonus",1.0],["cap_bonus",1.0]]:
			check(is_equal_approx(bonus[pair[0]],pair[1]),prefix+str(pair[0]),bonus)
		check(battle.skirmish_ai.difficulty==4 and battle.mission.subtitle.contains("凶残1"),prefix+"difficulty reaches real battle")
		check(is_equal_approx(battle.enemy_funds,battle.funds*6.6),prefix+"brutal funds plus level five deployment")
		check(is_equal_approx(battle.ai_build_factor("enemy"),1.725) and battle.ai_build_factor("ally")==1.0,prefix+"production multiplication exactly once")
		for uid in ["E1","HTNK","ORCA","SUB","CMIN","SMCV"]:
			var actor=battle.spawn_unit(uid,"enemy",Vector2(1200,1200))
			activate(actor)
			check(is_equal_approx(actor.max_hp,actor.base_hp*1.2),prefix+uid+" health",[actor.max_hp,actor.base_hp])
			check(is_equal_approx(actor.move_speed,actor.base_speed*1.1),prefix+uid+" movement",[actor.move_speed,actor.base_speed])
			check(is_equal_approx(actor.skill_power,1.0),prefix+uid+" retired skill training inactive")
			check(is_equal_approx(actor.bonuses.attack_bonus,1.15*1.09) and is_equal_approx(actor.bonuses.defense_bonus,1.15*1.075),prefix+uid+" combat multipliers")
		for building in battle.buildings:
			if building.side!="enemy":continue
			check(is_equal_approx(building.max_hp,float(building.data.hp)*1.2),prefix+building.building_id+" building health")
			check(is_equal_approx(building.bonuses.attack_bonus,1.15) and is_equal_approx(building.bonuses.defense_bonus,1.15),prefix+building.building_id+" building combat")
			check(building.build_speed==1.0,prefix+building.building_id+" no duplicate production boost")
		var bank:float=battle.enemy_funds
		battle.credit_income("enemy",100,true,true)
		battle.credit_income("enemy",100,true,false)
		check(is_equal_approx(battle.enemy_funds-bank,600),prefix+"ore fourfold and ordinary income twofold unchanged")
		# Snapshot actor values and frozen logistics survive without applying another boost.
		var before=battle.units.filter(func(u):return u.side=="enemy")[0]
		var hp_before:float=before.max_hp
		var attack_before:float=before.bonuses.attack_bonus
		var defense_before:float=before.bonuses.defense_bonus
		var skill_before:float=before.skill_power
		var id:String=before.unit_id
		var snapshot=BattleSaves.Snapshot.new().capture(battle)
		BattleSaves.Snapshot.new().restore(battle,snapshot)
		var restored=battle.units.filter(func(u):return u.side=="enemy" and u.unit_id==id)[0]
		check(is_equal_approx(restored.max_hp,hp_before) and battle.skirmish_ai.difficulty==4,prefix+"save restores boosted units once")

		check(is_equal_approx(restored.bonuses.attack_bonus,attack_before) and is_equal_approx(restored.bonuses.defense_bonus,defense_before) and is_equal_approx(restored.skill_power,skill_before),prefix+"saved unit training does not stack twice")
		var reinforcement=battle.spawn_unit("HTNK","enemy",Vector2(1200,1300))
		check(is_equal_approx(reinforcement.bonuses.attack_bonus,1.15*1.09) and is_equal_approx(reinforcement.skill_power,1.0),prefix+"new unit after restore keeps frozen training")
		check(BattleRequest.enemy_logistics()==bonus and is_equal_approx(battle.ai_build_factor("enemy"),1.725),prefix+"save retains frozen logistics")
		if mode==MatchRules.EXTENDED:
			# A test-only equipped card exercises the shared real cast path; production AI receives no extra cards.
			var ability:=Ability.new()
			ability.setup(GameData.get_skill("ap_focus_fire"))
			reinforcement.skills.append(ability)
			check(reinforcement.use_ability(reinforcement.skills.size()-1),prefix+"supported skill casts with training")
			check(is_equal_approx(reinforcement.buff_value("cooldown"),0.2) and is_equal_approx(ability.cd_left,20.0),prefix+"card effect and cooldown independent of native training")
		await finish()
	# Old difficulties and campaigns do not acquire the new logistics tier.
	for difficulty in 4:
		check(GameData.skirmish_logistics(difficulty)==MatchRules.neutral_bonuses(),mode+str(difficulty)+" original difficulty unchanged")
		check(GameData.skirmish_unit_upgrades(difficulty)=={"attack_bonus":1.0,"defense_bonus":1.0,"skill_bonus":1.0},mode+str(difficulty)+" original training unchanged")
	BattleRequest.reset()
	BattleRequest.freeze_combat_context()
	check(BattleRequest.enemy_logistics()==MatchRules.neutral_bonuses(),mode+" campaign unaffected")
	BattleRequest.combat_context.erase("enemy_logistics")
	check(BattleRequest.enemy_logistics()==MatchRules.neutral_bonuses(),mode+" legacy save defaults neutral")

	BattleRequest.combat_context.erase("enemy_unit_upgrades")
	check(BattleRequest.enemy_unit_upgrades()=={"attack_bonus":1.0,"defense_bonus":1.0,"skill_bonus":1.0},mode+" legacy save does not gain training")
