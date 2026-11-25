extends "res://tests/allied_abilities_regression.gd"
const Bridges = preload("res://scripts/world/bridge_damage.gd")

func exercise_mode(mode: String) -> void:
	BattleRequest.configure_skirmish(mode,{"map_layout":"yr_isleland","fog_of_war":false,"starting_funds":20000})
	screen=load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	if battle.fog!=null: battle.fog.free(); battle.fog=null
	for unit in battle.units: unit.free()
	battle.units.clear()
	for hut in battle.buildings:
		if hut.building_id!="CABHUT" or not hut.special.has("bridge_span"): continue
		hut.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		var parts: Array=Bridges.sections(battle,hut.special.bridge_span)
		var center: Rect2=parts[parts.size()/2]
		battle.camera.position=hut.position
		battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
		for uid in ["ENGINEER","SENGINEER"]:
			for skill in [false,true]:
				var label: String=mode+"/"+uid+"/skill="+str(skill)+"/"+str(hut.position)+": "
				Bridges.hit(battle,center.get_center(),Bridges.strength())
				var spawn: Vector2=battle.path_service.nearest_reachable(hut.position,hut.position,false,6)
				var engineer=actor(uid,"ally",spawn)
				battle.select_unit(engineer,false)
				await get_tree().physics_frame
				await get_tree().process_frame
				var point: Vector2=hut.art_center()
				check(battle.support_order_target(point)==hut,label+"actual hut pixels pick repair target")
				if skill:
					battle.cast_slot=UnitSkillLayout.find(engineer,"allied_engineer")
					check(battle.cast_slot>=0,label+"engineer exposes engineering skill")
					check(battle.command_cursor.resolve(point)=="repair",label+"engineering skill shows repair cursor")
					var motion:=InputEventMouseMotion.new()
					motion.position=battle.get_global_transform_with_canvas()*point
					stage.push_input(motion,true)
					battle.confirm_cast()
				else:
					check(battle.command_cursor.resolve(point)=="repair",label+"right click shows repair cursor")
					battle._issue_order(point)
				check(engineer.special.get("action")=="allied_bridge" and engineer.special.get("target")==hut,label+"player entry dispatches bridge repair")
				for frame in 600:
					if not battle.actor_alive(engineer): break
					engineer._physics_process(1.0/60.0)
					if frame%30==0: await get_tree().physics_frame
				check(not battle.actor_alive(engineer) and Bridges.health(battle,center)==Bridges.strength(),label+"real entry consumes engineer and restores bridge",str(engineer.position) if is_instance_valid(engineer) else "consumed")
				check(not battle.path_service.broken_bridge_decks.has(center) and not battle.ground.broken_bridges.has(center),label+"navigation and bridge drawing restored")
				if is_instance_valid(engineer): remove_actor(engineer)
				# Keep later cases independent after a failed assertion.
				preload("res://scripts/world/civilian_sites.gd").repair(hut)
	screen.free(); Ra2Sfx.stop_all(); Music.stop()
	await get_tree().process_frame
