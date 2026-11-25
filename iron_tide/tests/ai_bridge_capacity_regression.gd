extends "res://tests/ground_control_regression.gd"
const Repair=preload("res://scripts/world/ai_bridge_repair.gd")
const Support=preload("res://scripts/world/ai_emergency_engineer.gd")
const Bridges=preload("res://scripts/world/bridge_damage.gd")
const Native=preload("res://scripts/world/native_maps.gd")
func exercise(mode:String) -> void:
	for faction in ["allied","soviet"]:
		BattleSaves.pending={}
		get_tree().paused=false
		prefix=mode+"/"+faction+": "
		BattleRequest.configure_skirmish(mode,{"map_layout":"yr_isleland","enemy_base":faction,"fog_of_war":false,"starting_funds":20000})
		screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
		for unit in battle.units:unit.free()
		battle.units.clear();battle.invalidate_ai_population()
		var ai=battle.skirmish_ai
		var hut=battle.buildings.filter(func(b):return b.building_id=="CABHUT")[0]
		var id:String="SENGINEER" if faction=="soviet" else "ENGINEER"
		var bid:String=battle.roster_id("GAPILE","enemy")
		var point:Vector2=Native.find_base_site(battle,hut.position+Vector2(260,-200),bid)
		var line=Building.new();line.setup(GameData.get_building(bid),"enemy",point,battle,true);battle.add_child(line);battle.buildings.append(line);line._buildup_play=-1.0
		battle._update_power();battle._refresh_pathing()
		var parts:Array=Bridges.sections(battle,hut.special.bridge_span)
		var missing:Rect2=parts[parts.size()/2]
		Bridges.hit(battle,missing.get_center(),Bridges.strength())
		for i in 64:
			var unit=battle.spawn_unit("MTNK","enemy",Vector2(1000+i%8*60,1000+i/8*60))
			check(unit!=null,prefix+"ordinary army fills exactly 64")
			if unit!=null:unit.set_physics_process(false);unit.set_process(false)
		check(battle.ai_population_full("enemy") and battle.ai_living_count("enemy")==64,prefix+"ordinary capacity remains 64")
		Repair.tick(ai);Repair.tick(ai)
		var ticket:Dictionary=ai.ai_state.get(Support.KEY,{})
		check(not ticket.is_empty(),prefix+"full army reserves one bridge engineer",[ai.funds,ai.house_id,ai.enemy_base,hut.special,line.position,ProductionExit.origin(line,GameData.get_unit(id)),line.queue_block_reason(id),Repair.reachable(battle,ProductionExit.origin(line,GameData.get_unit(id)),hut),BattleRequest.house_teams])
		if ticket.is_empty():await finish();continue
		line=ticket.producer
		check(line.production.count(id)==1 and not line.enqueue(id),prefix+"repeated request cannot duplicate reserved worker")
		check(battle.spawn_unit(id,"enemy",point)==null and battle.spawn_unit("MTNK","enemy",point)==null,prefix+"ordinary spawn cannot bypass population cap")
		check(line.cancel_at(line.production.find(id)) and not ai.ai_state.has(Support.KEY),prefix+"queue cancellation releases reservation")
		Repair.tick(ai)
		var saved:=BattleSaves.save_slot(battle,"slot1")
		check(saved.ok,prefix+"pending paid repair reservation saves")
		if saved.ok:
			check(BattleSaves.prepare_load("slot1").ok,prefix+"reservation save validates")
			await finish()
			screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle;ai=battle.skirmish_ai
			battle.paused=false
			get_tree().paused=false
			ticket=ai.ai_state.get(Support.KEY,{})
			check(not ticket.is_empty() and battle.actor_alive(ticket.get("producer")) and battle.actor_alive(ticket.get("target")),prefix+"cold load restores producer and bridge references")
			if ticket.is_empty():await finish();continue
			line=ticket.producer;hut=ticket.target
		var before:float=battle.funds_for("enemy")
		var cost:float=battle.production_price(GameData.get_unit(id),"enemy")
		line._tick_unit_queues(180.0)
		var worker=ai.ai_state.get(Support.KEY,{}).get("worker")
		check(battle.actor_alive(worker) and battle.ai_living_count("enemy")==65,prefix+"normal paid production completes one extra worker")
		check(is_equal_approx(before-battle.funds_for("enemy"),cost),prefix+"repair worker pays full normal price",[before-battle.funds_for("enemy"),cost])
		check(line.production.is_empty() and not line.enqueue(id) and battle.spawn_unit("MTNK","enemy",point)==null,prefix+"65th worker cannot unlock more production")
		if battle.actor_alive(worker):
			activate(worker)
			worker.special.erase("production_exit")
			battle.ai_dispatch.frame=-1
			battle.ai_dispatch._begin(battle)
			battle.ai_dispatch.limit=10000
			Repair.tick(ai)
			battle.ai_dispatch.pump(battle)
			check(worker.special.get("action")=="allied_bridge",prefix+"extra worker receives real bridge interaction")
			var loaded:=BattleSaves.save_slot(battle,"slot2")
			check(loaded.ok and BattleSaves.prepare_load("slot2").ok,prefix+"active worker reservation can be saved")
			await finish()
			screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle;ai=battle.skirmish_ai
			battle.paused=false;get_tree().paused=false
			ticket=ai.ai_state.get(Support.KEY,{})
			worker=ticket.get("worker");line=ticket.get("producer");hut=ticket.get("target")
			check(battle.actor_alive(worker) and battle.ai_living_count("enemy")==65 and not line.enqueue(id),prefix+"active cold load restores one worker and rejects a second")
			worker.process_mode=Node.PROCESS_MODE_ALWAYS;worker.set_process(false);worker.set_physics_process(false)
			# Consume through the normal bridge repair action, with a deterministic
			# arrival position. Full walking is covered by the real quick-save run.
			worker.position=AlliedAbilities.approach(worker,hut)
			await get_tree().physics_frame
			for tick in 120:
				if not battle.actor_alive(worker):break
				AlliedAbilities.tick_action(worker,1.0/30.0)
				if tick%30==0:await get_tree().process_frame
			battle.invalidate_ai_population()
			check(hut.special.bridge_repaired,prefix+"normal engineer action repairs the crossing")
			Support.clean(battle,"enemy")
			check(battle.ai_living_count("enemy")==64 and not ai.ai_state.has(Support.KEY),prefix+"consumed engineer returns to 64 and releases reservation")
			Bridges.hit(battle,missing.get_center(),Bridges.strength())
			check(Support.enqueue(battle,line,id,hut),prefix+"new bridge damage permits another paid replacement")
			line.side="ally"
			Support.clean(battle,"enemy")
			check(not ai.ai_state.has(Support.KEY) and not Support.permits(battle,"enemy",id,line,false),prefix+"captured producer loses old house exception")
			line.side="enemy";line.cancel_at(0)
			check(Support.enqueue(battle,line,id,hut),prefix+"cancellation after capture permits replacement")
			line._tick_unit_queues(180.0)
			worker=ai.ai_state.get(Support.KEY,{}).get("worker")
			check(battle.actor_alive(worker),prefix+"replacement completes")
			worker._dead=true;worker.hp=0.0;battle.invalidate_ai_population()
			Support.clean(battle,"enemy")
			check(not ai.ai_state.has(Support.KEY) and battle.ai_living_count("enemy")==64,prefix+"dead worker releases exception")
		# Clear the pending load request created only for validation above.
		BattleSaves.pending={}
		await finish()
