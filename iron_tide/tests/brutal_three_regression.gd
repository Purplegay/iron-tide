extends "res://tests/ground_control_regression.gd"
const Rules = preload("res://scripts/world/brutal_three.gd")
const Pulse = preload("res://scripts/buildings/tesla_pulse.gd")
const Prefs = preload("res://scripts/ui/lobby_preferences.gd")

func exercise(mode: String) -> void:
	for country in ["美国", "苏俄"]:
		BattleRequest.configure_skirmish(mode,{"difficulty":6,"enemy_country":country,"map_size":3200,"starting_funds":12000,"fog_of_war":true})
		screen=load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode=Node.PROCESS_MODE_DISABLED
		battle=screen.battle
		var ai=battle.skirmish_ai
		var tag:=mode + " " + str(country) + " "
		check(ai.difficulty==6 and screen.hud.mode_label.text.contains("凶残3") and Prefs.normalize({"difficulty":6}).difficulty==6,tag+"difficulty reaches battle, HUD and preferences")
		check(GameData.AI_TRAINING[6]=={"logistics":50,"unit":37},tag+"actual new-scale ranks")
		var start_bank:float=battle.enemy_funds
		battle.credit_income("enemy",100,true,true)
		battle.credit_income("enemy",100,true)
		check(battle.enemy_funds-start_bank==1200,tag+"8x ore plus 4x ordinary income")
		start_bank=battle.funds
		battle.credit_income("ally",100,true,true)
		check(battle.funds-start_bank==100,tag+"player earns normal income")
		var yard=battle.buildings.filter(func(b):return b.is_hq and b.side=="enemy")[0]
		var initial:float=yard.max_hp*0.5
		check(is_equal_approx(yard.special.brutal_shield,initial),tag+"opening building shield")
		# Allow first fog sweep on maps that defer their initial visible cells.
		if battle.fog!=null: battle.fog._process(1.0)
		Rules.opening(ai)
		var walls_before:int=battle.wall_cells.size()
		check(walls_before>0,tag+"opening perimeter exists")
		Rules.opening(ai)
		check(battle.wall_cells.size()==walls_before,tag+"opening cannot grant twice")
		var approach:Vector2=field_position(yard.position,240.0)
		var attacker=battle.spawn_unit("MTNK","ally",approach)
		check(not battle.allied_state.has("brutal_alarm"),tag+"no prior alarm")
		battle.fog._reveal("ally",yard.position,200,5)
		var yard_hp:float=yard.hp
		yard.receive_hit(100,"bullet",{},attacker)
		check(yard.hp==yard_hp and yard.special.brutal_shield<initial,tag+"damage depletes shield before HP")
		check(battle.allied_state.has("brutal_alarm"),tag+"shield-only hit raises a defense alarm")
		var caption:="护盾受击"
		check(battle.effects_root.get_children().any(func(fx):return fx is Effects.FloatText and fx.text==caption and fx.position==yard.position),tag+"an intact shield reports the absorbed damage at the building")
		var remaining:float=yard.special.brutal_shield
		var enemy_tank=battle.spawn_unit("HTNK","enemy",yard.position+Vector2(600,0))
		var miner=battle.spawn_unit("HARV","enemy",yard.position+Vector2(0,300))
		check(enemy_tank.special.has("brutal_armor") and not miner.special.has("brutal_armor") and not attacker.special.has("brutal_armor"),tag+"tank buff scoped to AI tanks")
		var hp:float=enemy_tank.hp
		enemy_tank.receive_hit(110,"bullet",{},null)
		var reduced:float=hp-enemy_tank.hp
		enemy_tank.special.erase("brutal_armor")
		hp=enemy_tank.hp
		enemy_tank.receive_hit(110,"bullet",{},null)
		check(is_equal_approx(reduced,(hp-enemy_tank.hp)*0.9),tag+"final incoming damage x0.9")
		Rules.grant(enemy_tank)
		var tower=battle._place_building("ATESLA","enemy",yard.position+Vector2(160,360),true)
		check(is_equal_approx(Pulse.reload_duration(tower),(tower.cooldown-float(tower.data.get("fire_delay",0)))*0.8),tag+"final tower reload x0.8")
		if mode==MatchRules.EXTENDED:
			var packet:={ "damage_owner_side":"ally" }
			check(is_equal_approx(CombatMath.FinalDamage.apply(150,100,yard,packet,null),150),tag+"150% starts compression")
			var mid:=CombatMath.FinalDamage.apply(175,100,yard,packet,null)
			var huge:=CombatMath.FinalDamage.apply(1e15,100,yard,packet,null)
			check(mid>150 and mid<175 and huge>220 and huge<225,tag+"225% asymptote")
		var snapshotter=BattleSaves.Snapshot.new()
		var saved:Dictionary=snapshotter.capture(battle)
		snapshotter.restore(battle,saved)
		yard=battle.buildings.filter(func(b):return b.side=="enemy" and b.is_hq)[0]
		check(is_equal_approx(yard.special.brutal_shield,remaining) and battle.wall_cells.size()==walls_before,tag+"save retains shield and perimeter")
		var tank=battle.units.filter(func(u):return u.side=="enemy" and u.unit_id=="HTNK")[0]
		var alarm_point: Vector2 = battle.allied_state.brutal_alarm.point
		var origin: Vector2 = field_position(alarm_point, 600)
		check(origin.is_finite(),tag+"open connected rally area")
		tank.position=origin
		var fallback=battle.spawn_unit("E2","enemy",origin)
		Rules.tick(battle.skirmish_ai,2.1)
		check(tank.has_move_order and fallback.has_move_order and tank.move_target.distance_to(alarm_point)<170 and tank.move_target.distance_to(fallback.move_target)>30,tag+"mixed group returns from field in separate positions",[tank.has_move_order,fallback.has_move_order,tank.position,tank.move_target,fallback.move_target,alarm_point])
		check(tank.attack_move and fallback.attack_move,tag+"recall keeps weapons active")
		battle.allied_state.erase("brutal_alarm")
		tank.special.brutal_watch_pos=tank.position
		tank.special.brutal_stall=4.5
		Rules.tick(battle.skirmish_ai,2.0)
		check(tank.special.get("brutal_retry",0)>0 and not tank.order_queue.is_empty(),tag+"blocked march takes a detour with destination queued")
		# A real defender, within building range, orders its wall on the paid defense lane.
		var infantry=battle.spawn_unit("E1" if country=="美国" else "DESO","enemy",yard.position)
		infantry.set_deployed(true,false)
		var cost:float=GameData.get_building(Rules.wall_id(ai)).cost
		var cover:=Vector2.INF
		var current_ai=battle.skirmish_ai
		for ring in range(2,8):
			for step in 20:
				infantry.position = battle.snap_build_pos(yard.position+Vector2.RIGHT.rotated(TAU*step/20)*40*ring)
				if battle.path_service.is_blocked(infantry.position): continue
				cover = Rules.cover_point(current_ai)
				if cover.is_finite(): break
			if cover.is_finite(): break
		check(cover.is_finite(),tag+"cover candidate beside deployed infantry")
		var required:String="GAPILE" if country=="美国" else "NAHAND"
		if required not in battle.owned_building_ids("enemy"):battle._place_building(required,"enemy",origin+Vector2(240,0),true)
		battle.enemy_funds=100000
		var bank:float=battle.enemy_funds
		var wid:=Rules.wall_id(current_ai)
		Rules.request_cover(current_ai,battle.owned_building_ids("enemy"))
		check(battle.enemy_struct_queue.any(func(job):return job.id==wid),tag+"cover enters ordinary defense queue")
		battle._tick_structure_queue(120.0)
		check(int(battle.enemy_struct_ready.get(wid,0))==1 and is_equal_approx(bank-battle.enemy_funds,cost),tag+"cover paid for once")
		current_ai._try_build()
		check(not battle.enemy_struct_ready.has(wid) and battle.wall_cells.has(WallArt.cell_at(cover)),tag+"completed cover placed on chosen flank")
		var shield_left:float=yard.special.brutal_shield
		battle.fog._reveal("ally",yard.position,200,5)
		var original_hp:float=yard.hp
		yard.receive_hit((shield_left+20.0)*yard.bonuses.defense_bonus, "bullet", {}, null)
		check(yard.special.brutal_shield==0 and yard.hp<original_hp,tag+"shield overflow reaches HP")
		caption=Unit.TankHero.Shield.hit_caption(shield_left,original_hp-yard.hp,yard.side)
		check(battle.effects_root.get_children().any(func(fx):return fx is Effects.FloatText and fx.text==caption),tag+"overflow reports shield and actual HP loss together")
		await finish()

func field_position(center: Vector2, radius: float) -> Vector2:
	for step in 48:
		var p := center + Vector2.RIGHT.rotated(TAU * step / 48.0) * radius
		if battle.path_service.zone_at(p)>0 and (battle.path_service.zone_at(center)==0 or battle.path_service.same_zone(p, center)): return p
	return Vector2.INF
