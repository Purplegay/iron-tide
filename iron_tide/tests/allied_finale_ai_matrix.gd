extends RefCounted
## Accelerated diagnostic on the actual ALL07 battle. Never inject an AI job.
const DT := 1.0/60.0

static func run(world,s: Dictionary,runner) -> void:
	var ai = world.AlliedFinale.AI
	var rules: Array = ai.Data.data.rules.duplicate()
	var autosave_count := 0
	for child in world.get_parent().get_children():
		if child.get_script()==preload("res://scripts/save/battle_autosave.gd"):
			child.set_process(false)
			autosave_count+=1
	runner.expect(autosave_count==1 and not preload("res://scripts/expedition/rules.gd").active(),"批量战场关闭自动保存，不在远征中")
	if autosave_count!=1: return
	for actor in world.units+world.buildings:
		if is_instance_valid(actor):
			actor.set_physics_process(false)
			actor.set_process(false)
	var prepared_third := OS.get_environment("IRON_TIDE_AI_MATRIX_THIRD_READY")=="1"
	if prepared_third:
		# Deliberately separate from the native opening: model the technology and
		# buildings after a base has been built, not proof it builds them itself.
		for item in [["YAWEAP",Vector2(550,6400)],["YAPOWR",Vector2(700,6500)],["YATECH",Vector2(850,6500)],["YABRCK",Vector2(1400,6100)],["NAPSIS",Vector2(1490,6400)]]:
			var b = world._place_building(item[0],"enemy",item[1],true)
			runner.expect(b!=null,"第三房设施夹具："+str(item[0]))
			if b==null: return
			b.special.allied_finale_room="Yuri3"
			b._buildup_play=-1.0
			b.set_process(false)
			b.set_physics_process(false)
	var filter := OS.get_environment("IRON_TIDE_AI_MATRIX_ID")
	for rule in rules:
		if filter!="" and not filter.split(",").has(rule.id): continue
		if prepared_third and rule.room!="Yuri3": continue
		var result: Dictionary = await trial(world,s,rule,runner)
		result.fixture="third_tech_ready" if prepared_third else "opening_factories"
		print("AI_MATRIX ",JSON.stringify(result))

static func single_poll(world,s: Dictionary,rule: Dictionary) -> void:
	# Scope only the competition pool to this ID; the selector still owns all conditions and the order.
	var ai = world.AlliedFinale.AI
	s.ai_due[rule.room]=0.0
	ai.tick(world,s,0.5,[rule])

static func point_near(world,origin: Vector2, min_distance: float, max_distance: float) -> Vector2:
	for distance in [max_distance,(min_distance+max_distance)*0.5,min_distance]:
		for i in 24:
			var point: Vector2 = origin+Vector2.from_angle(TAU*i/24.0)*distance
			var p: Vector2 = world.AlliedFinale.OpeningDrop.open_ground(world,point)
			if not p.is_finite(): continue
			var route: Vector2 = world.path_service.nearest_reachable(p,origin,false,4)
			if route.is_finite() and route.distance_to(p)<65: return p
	return Vector2.INF

static func trial(world,s: Dictionary,rule: Dictionary,runner) -> Dictionary:
	var old_actors: Array = world.units+world.buildings
	var ai = world.AlliedFinale.AI
	var room: String = rule.room
	var result := {"id":rule.id,"room":room,"condition":rule.related,"threshold":rule.count,"difficulty":rule.difficulty.find(1.0),"negative":"not_run","selected":false,"debit":0.0,"expected_cost":0.0,"debit_ok":false,"roster":false,"order":false,"moved":false,"action":"not_run","details":[]}
	var old_difficulty = BattleRequest.skirmish_config.get("difficulty",1)
	var bank: Dictionary = world.AlliedFinale.Branches.ensure_account(world)
	var old_bank: float = bank.funds
	var old_enemy: float = world.enemy_funds
	var old_ally: float = world.funds
	var hidden: Array = []
	var factories: Array = world.buildings.filter(func(b):return world.actor_alive(b) and b.side=="enemy" and b.special.get("allied_finale_room")==room and b.building_id in ["YAWEAP","YABRCK"])
	var anchor: Vector2 = factories[0].position if not factories.is_empty() else ai.waypoint(world,26)
	var side := "enemy" if int(rule.condition)==1 else "ally"
	for actor in old_actors:
		if not world.actor_alive(actor) or actor.side!=side: continue
		if side=="enemy" and actor.special.get("allied_finale_room")!=room: continue
		if (actor.unit_id if actor is Unit else actor.building_id)!=rule.related: continue
		hidden.append([actor,actor.hp])
		actor.hp=0
	# Test only the owning house; no other production gets time or money in the trial.
	s.ai_jobs={}
	s.ai_due={"YuriCountry":99999.0,"Yuri2":99999.0,"Yuri3":99999.0}
	s.south_ai_enabled=room!="Yuri3"
	bank.ai_enabled=room=="Yuri3"
	BattleRequest.skirmish_config.difficulty=result.difficulty
	world.enemy_funds=40000
	bank.funds=40000
	var owner: String = world.AlliedFinale.Branches.THIRD_ACCOUNT if room=="Yuri3" else "enemy"
	var before: float = world.funds_for(owner)
	var opposing_before: float = bank.funds if owner=="enemy" else world.enemy_funds
	var count := int(rule.count)
	var previous := maxi(0,count-1)
	var subject := str(rule.related)
	var supplied := 0
	for i in count+1:
		if i==previous and count>0:
			single_poll(world,s,rule)
			result.negative="blocked" if not s.ai_jobs.has(room) else "unexpected_order"
			result.details.append("negative_count:%s:job:%s"%[ai.room_ids(world,room).count(subject) if side=="enemy" else ai.player_count(world,subject),s.ai_jobs.get(room,{}).get("id","")])
		if i==count: break
		if side=="enemy" and i<hidden.size():
			hidden[i][0].hp=hidden[i][1]
			supplied+=1
			continue
		var p: Vector2 = anchor+Vector2(420+i*100,340)
		var object = null
		if not GameData.get_building(subject).is_empty(): object=world._place_building(subject,side,p,true)
		elif not GameData.get_unit(subject).is_empty(): object=world.spawn_unit(subject,side,p)
		if object==null: continue
		object.set_process(false)
		object.set_physics_process(false)
		if side=="enemy": object.special.allied_finale_room=room
		supplied+=1
	if count==0: result.negative="threshold_zero"
	if supplied!=count: result.details.append("threshold_fixture_missing:%s:%d/%d"%[subject,supplied,count])
	if supplied==count and not s.ai_jobs.has(room): single_poll(world,s,rule)
	var job: Dictionary = s.ai_jobs.get(room,{})
	result.selected=job.get("id")==rule.id
	result.details.append("positive_count:%s:job:%s"%[ai.room_ids(world,room).count(subject) if side=="enemy" else ai.player_count(world,subject),job.get("id","")])
	var expected := {}
	for item in rule.team.units:
		expected[item[0]]=int(item[1])
		result.expected_cost+=int(item[1])*world.production_price(GameData.get_unit(item[0]),"enemy")
	var produced: Array = []
	if result.selected:
		var goal := point_near(world,anchor,370,570)
		var target = world._place_building("GACNST","ally",goal,true) if goal.is_finite() else null
		if target!=null:
			target.set_physics_process(false)
			target.set_process(false)
		# Queue work is linear; action movement below always uses 1/60 s.
		for i in 160:
			for b in factories:
				if world.actor_alive(b): b._tick_unit_queues(2.0)
			ai.tick(world,s,0.5,[rule])
			if not s.ai_jobs.has(room): break
			if i%10==0:
				for u in world.units:
					if world.actor_alive(u) and u not in old_actors:
						u.set_process(false)
						u.set_physics_process(false)
				await runner.get_tree().process_frame
		var got := {}
		for u in world.units:
			if not world.actor_alive(u) or u in old_actors or u.side!="enemy" or u.special.get("allied_finale_room")!=room: continue
			u.set_process(false)
			u.set_physics_process(false)
			produced.append(u)
			got[u.unit_id]=int(got.get(u.unit_id,0))+1
		result.roster=got==expected
		result.details.append("out:"+JSON.stringify(got))
		result.debit=before-world.funds_for(owner)
		result.debit_ok=absf(result.debit-result.expected_cost)<0.05 and is_equal_approx(opposing_before,bank.funds if owner=="enemy" else world.enemy_funds)
		result.order=result.roster and not s.ai_jobs.has(room) and produced.all(func(u):return u.attack_move or u.attack_ordered or u.has_move_order or u.special.has("finale_engineer_rush") or u.special.has("campaign_area_guard"))
		if result.order and target!=null:
			if rule.id=="13525d8c": result.action="separate_cold_capture_test"
			elif rule.team.script[0][0]==11:
				var wp := 0
				for letter in str(rule.team.entry): wp=wp*26+letter.unicode_at(0)-64
				var post: Vector2 = ai.waypoint(world,wp-1)
				result.guard_assigned=produced.all(func(u):return u.special.has("campaign_area_guard") and u.special.campaign_area_guard.distance_to(post)<=8*55.0)
				for i in 5400:
					for u in produced:
						if world.actor_alive(u): u._physics_process(DT)
					if i%120==0: await runner.get_tree().process_frame
					if produced.all(func(u):return world.actor_alive(u) and u.special.has("campaign_area_guard") and u.position.distance_to(u.special.campaign_area_guard)<95.0):
						result.guard_arrived=true
						break
				result.action="guard_arrived" if result.guard_assigned and result.get("guard_arrived",false) else "guard_arrival_not_proven"
				result.details.append("post_distances:"+str(produced.map(func(u):return snappedf(u.position.distance_to(u.special.get("campaign_area_guard",post)),0.1) if world.actor_alive(u) else -1.0)))
				if result.action=="guard_arrived":
					var at := point_near(world,post,95,175)
					var intruder = world.spawn_unit("MTNK","ally",at) if at.is_finite() else null
					if intruder!=null:
						intruder.set_process(false)
						intruder.set_physics_process(false)
						world.fog._reveal("enemy",at,360,60.0)
						world.fog.rebuild()
						var initial: float = intruder.hp
						for i in 900:
							for u in produced:
								if world.actor_alive(u): u._physics_process(DT)
							if not world.actor_alive(intruder): break
							if intruder.hp<initial or intruder.side!="ally": break
						result.guard_response=not world.actor_alive(intruder) or intruder.hp<initial or intruder.side!="ally"
			else:
				# Give only the new team contact and physics time. Do not issue a replacement order.
				world.fog._reveal("enemy",target.position,700,1.0)
				world.fog.rebuild()
				var positions: Array = produced.map(func(u):return u.position)
				var hp: float = target.hp
				var steps := 3600 if OS.get_environment("IRON_TIDE_AI_MATRIX_EXTENDED")=="1" else 1050
				for i in steps:
					for j in produced.size():
						var u = produced[j]
						if world.actor_alive(u):
							u._physics_process(DT)
							if u.position.distance_to(positions[j])>65: result.moved=true
					if i%60==0: await runner.get_tree().process_frame
					if not is_instance_valid(target) or target.hp<hp and result.moved: break
				var damaged: bool = not is_instance_valid(target) or target.hp<hp
				result.action="fixture_damage" if damaged and result.moved else "no_damage_in_window"
				result.details.append("remaining_route:"+str(produced.map(func(u):return [u.has_move_order,u.order_queue.size(),snappedf(u.position.distance_to(goal),1.0)] if world.actor_alive(u) else [])))
	else:
		for item in rule.team.units:
			if ai.room_can_supply(world,room,item[0]): continue
			var why := []
			for b in factories:
				if b.buildable.has(item[0]): why.append(b.queue_block_reason(item[0]))
			result.details.append("cannot_supply:%s:%s"%[item[0],str(why)])
	for b in factories:
		if not world.actor_alive(b): continue
		while not b.production.is_empty(): b.cancel_queue()
		b.special.erase("allied_finale_order")
	for actor in world.units+world.buildings:
		if is_instance_valid(actor) and not actor in old_actors: actor.queue_free()
	for pair in hidden:
		if is_instance_valid(pair[0]): pair[0].hp=pair[1]
	world.enemy_funds=old_enemy
	world.funds=old_ally
	bank.funds=old_bank
	BattleRequest.skirmish_config.difficulty=old_difficulty
	s.ai_jobs={}
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	return result
