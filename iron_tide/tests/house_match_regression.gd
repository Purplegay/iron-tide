extends "res://tests/base_recovery_regression.gd"

const Snapshot = preload("res://scripts/save/battle_snapshot.gd")
const Houses = preload("res://scripts/rules/skirmish_houses.gd")
func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	alliance_rewards()
	await lobby_roster()
	for teams in [[1,2,1,2],[1,2,3,4]]:
		var rows := []
		for i in teams.size(): rows.append({"country":"美国" if i%2==0 else "苏俄","team":teams[i],"seat":i})
		for i in 4:
			rows[i].spawn=[2,3,0,1][i]
			if i>0:rows[i].difficulty=[0,6,0,2][i]
		BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"houses":rows,"country":"美国","enemy_country":"苏俄","map_layout":"yr_crctbrd","starting_funds":12000,"difficulty":2,"fog_of_war":true})
		screen = load("res://scenes/battle.tscn").instantiate()
		add_child(screen)
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		battle = screen.battle
		battle.paused = false
		get_tree().paused = false
		for b in battle.buildings: b._buildup_play = -1.0
		battle._update_power()
		var expected_min:int=2 if teams[2]==teams[0] else 0
		check(BattleRequest.victory_difficulty()==expected_min,"Victory uses the weakest hostile computer")
		check(battle.funds_for("enemy")>battle.funds_for("ai2"),"Owner difficulty controls starting capital")
		check(BattleRequest.enemy_logistics("enemy")==GameData.skirmish_logistics(6) and BattleRequest.enemy_unit_upgrades("ai2")==GameData.skirmish_unit_upgrades(0),"Each side freezes its own growth")
		var homes: Array = []
		for i in 4:
			var side := Houses.id(i)
			var bases: Array = battle.buildings.filter(func(b):return b.side==side and b.building_id in ["GACNST","NACNST"])
			check(bases.size()==1,side+" owns its own factory base")
			if bases.size()!=1: continue
			if i>0:check(bases[0].special.has("brutal_shield")==(i==1),"Only brutal 3 buildings get shield")
			homes.append(bases[0].position)
			check(bases[0].position.distance_to(Houses.starts("yr_crctbrd")[rows[i].spawn])<100,side+" starts at chosen map pin")
			check(battle.fog.is_visible_at("ally",bases[0].position)==(teams[i]==1),side+" team vision")
			check(bases[0].is_in_group(BattleRequest.foes_group("ally"))==(teams[i]!=1),side+" player diplomacy")
		check(homes.size()==4 and homes[0]!=homes[2] and homes[1]!=homes[3],"four unique spawns")
		check(battle.ai_build_factor("enemy")>battle.ai_build_factor("ai2"),"House production rates follow their own difficulty")
		var before: float = battle.funds_for("enemy")
		var extra: float = battle.funds_for("ai2")
		battle.spend_side("ai2",500)
		check(battle.funds_for("enemy")==before and battle.funds_for("ai2")==extra-500,"independent treasuries")
		for child in battle.get_children():
			if child.get_script()==preload("res://scripts/world/house_ai.gd"): step_house(child,30)
		for side in ["enemy","ai2","ai3"]:
			check(battle.buildings.any(func(b):return b.side==side and not b.production.is_empty()),side+" starts own production")
		var other_treasury:float=battle.funds_for("ai2")
		var payer: float = battle.funds_for("ai3")
		var starting_units: int = battle.units.size()
		var producer = battle.buildings.filter(func(b):return b.side=="ai3" and not b.production.is_empty())[0]
		var production_id: String = producer.production[0]
		producer._process(120.0)
		check(battle.units.size()>starting_units and battle.units[-1].side=="ai3" and battle.units[-1].unit_id==production_id,"AI production delivers its own unit")
		check(battle.funds_for("ai3")<payer and battle.funds_for("ai2")==other_treasury,"production charges only its producer's treasury")
		var shot = battle.spawn_unit("MTNK","ai2",Vector2(1200,1200))
		var other = battle.spawn_unit("HTNK","ai3",Vector2(1220,1200))
		var friend = battle.spawn_unit("MTNK","ally",Vector2(1210,1200))
		battle.fog.rebuild()
		check(shot.attack_domain_valid(other) and shot.attack_domain_valid(friend)==(teams[0]!=teams[2]),"AI distinguishes hostile AI and player's group")
		shot.order_target(other,false,false)
		var hp: float = other.hp
		for step in 180:
			shot._physics_process(1.0/60)
			for projectile in battle.projectiles_root.get_children():
				if projectile is Projectile and not projectile.is_queued_for_deletion(): projectile._physics_process(1.0/60)
			if other.hp < hp: break
		check(other.hp < hp,"AI tank damages a hostile AI tank")
		var wave: Array = []
		for i in 3:
			wave.append(battle.spawn_unit("MTNK","ai2",shot.position+Vector2(120*i,200)))
		var wave_state: Dictionary = battle.allied_state.house_ai.ai2
		wave_state.attack_dispatch = {"units":wave.duplicate(),"goal":other.position}
		for ai in battle.get_children():
			if ai.get_script()==preload("res://scripts/world/house_ai.gd") and ai.house_id=="ai2":
				ai.dispatch_attacker(wave_state)
		check(wave_state.attack_dispatch.units.size()==2 and (wave.back().has_move_order or wave.back().attack_ordered),"one wave member receives its order per dispatch")
		var snapshot := Snapshot.new().capture(battle)
		var err := BattleSaves.validate(snapshot)
		check(err.is_empty(),"four-house snapshot validates",err)
		if err.is_empty():
			var write:=BattleSaves.save_slot(battle,BattleSaves.SLOTS[0])
			check(write.ok,"Mixed roster writes to a save slot",write.message)
			if write.ok:
				BattleRequest.reset()
				var loaded:=BattleSaves.prepare_load(BattleSaves.SLOTS[0])
				BattleRequest.refresh_houses()
				check(loaded.ok and BattleRequest.house_spawn(0)==2 and BattleRequest.house_difficulty("ai2")==0 and BattleRequest.victory_difficulty()==expected_min,"Reloaded mixed roster keeps positions, difficulty and reward tier")
				BattleSaves.pending={}
			Snapshot.new().restore(battle,snapshot)
			check(battle.funds_for("ai2")==other_treasury,"treasury survives restoration")
			wave_state=battle.allied_state.house_ai.ai2
			check(wave_state.attack_dispatch.units.size()==2 and wave_state.attack_dispatch.units.all(func(u):return battle.actor_alive(u) and u.side=="ai2"),"pending attackers are restored as live units")
			for ai in battle.get_children():
				if ai.get_script()==preload("res://scripts/world/house_ai.gd") and ai.house_id=="ai2":
					ai.dispatch_attacker(wave_state)
					ai.dispatch_attacker(wave_state)
			check(not wave_state.has("attack_dispatch"),"restored wave finishes")
		if teams[0] == teams[2]:
			for actor in battle.units+battle.buildings:
				if actor.side == "ally": actor.hp = 0
			battle._check_end()
			check(not battle.ended,"surviving AI ally keeps team in the match")
			for actor in battle.units+battle.buildings:
				if actor.side in ["enemy","ai3"]: actor.hp = 0
			battle._check_end()
			check(battle.ended,"eliminating opposing team ends match")
			check(screen.result_overlay.find_children("*","Label",true,false).any(func(label):return "胜利收益 100%" in label.text),"Actual battle settlement shows compensation from opening teams")
		await finish()
	await brutal_tech_progression(MatchRules.EXTENDED,3)
	await brutal_tech_progression(MatchRules.RA2,6)
	await check_house_air_defense()
	await population_limit()
	await allied_ai_operations()
	await check_aircraft_return()
	await swapped_duel()
	await mobile_bases()
	await hero_scouting()
	var result := FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks":checks,"failed":failed}))
	result.close()
	get_tree().quit(0 if failed==0 else 1)


func alliance_rewards() -> void:
	var rows := [{"team":1}, {"team":2,"difficulty":3}, {"team":1,"difficulty":3}]
	var adjustment := Houses.victory_reward(rows,1)
	check(adjustment.percent==90,"One ally of equal difficulty discounts the reward")
	rows[1].difficulty=4
	adjustment=Houses.victory_reward(rows,1)
	check(adjustment.gap==1 and adjustment.percent==95,"One higher enemy tier partially restores the reward")
	rows.append({"team":3,"difficulty":6})
	rows.append({"team":1,"difficulty":0})
	check(Houses.victory_reward(rows,1).percent==85,"Use weakest enemy and strongest ally even across hostile teams")
	rows[1].difficulty=6
	check(Houses.victory_reward(rows,1).percent==95,"Two allies and three tiers of compensation")
	for i in 2: rows.append({"team":1,"difficulty":6})
	check(Houses.victory_reward(rows,1).percent==70,"Alliance penalty is capped with four allies")
	rows=[{"team":1},{"team":2,"difficulty":6},{"team":1,"difficulty":0}]
	check(Houses.victory_reward(rows,1).percent==100,"Compensation cannot exceed the unallied reward")
	rows[2].team=3
	check(Houses.victory_reward(rows,1).is_empty(),"Solo and free-for-all keep the full reward")
	check(Houses.victory_reward([{"team":1},{"team":2},{"team":1}],3).percent==90,"Older saved rosters use the match difficulty")
	var result := {"match_id":"alliance-reward-test","win":true,"kills":4,"waves":0,"alliance_reward":adjustment}
	var credits:float=MetaProgress.balance("credits")
	var cores:float=MetaProgress.balance("cores")
	var reward:=MetaProgress.apply_battle_result(result)
	var cfg:Dictionary=GameData.meta_config.idle.settlement
	check(reward.credits==roundf((cfg.win_credits+4*cfg.per_kill_credits)*0.95) and reward.cores==roundf(cfg.win_cores*0.95),"Both currencies scale once after kills are counted")
	check(MetaProgress.balance("credits")==credits+reward.credits and MetaProgress.balance("cores")==cores+reward.cores,"Displayed rewards equal deposited amounts")
	check(MetaProgress.apply_battle_result(result).get("already_settled",false) and MetaProgress.balance("credits")==credits+reward.credits,"Repeated settlement cannot pay twice")

func choose(picker: OptionButton, index: int) -> void:
	picker.select(index)
	picker.item_selected.emit(index)

func lobby_roster() -> void:
	await get_tree().process_frame
	var lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	choose(lobby._layout_opt,lobby.Preferences.OPTIONS.map_layout.find("yr_crctbrd"))
	var markers: PackedVector2Array = lobby._map_preview.pin_positions.duplicate()
	choose(lobby._funds_opt,(lobby._funds_opt.selected+1)%3)
	check(markers.size()==4 and lobby._map_preview.pins.size()==4 and lobby._map_preview.pin_positions==markers,"same-map refresh preserves all selectable spawn markers")
	for id in ["yr_ice_age","coast","yr_crctbrd"]:
		choose(lobby._layout_opt,lobby.Preferences.OPTIONS.map_layout.find(id))
		check(lobby._map_preview.pins.size()==lobby.Houses.capacity(id),"switching maps restores correct spawn button count: "+id)
	check(lobby._map_preview.pin_positions==markers,"custom map does not overwrite native cached coordinates")
	var grid: GridContainer = lobby._team_grid
	check(grid.is_visible_in_tree() and grid.get_child_count()==30,"four seats and colour pickers visible inline on Circuit Board")
	choose(grid.get_child(6+2*6),0)
	choose(grid.get_child(6+3*6),0)
	choose(grid.get_child(6+2*6+3),0)
	choose(grid.get_child(6+3*6+1),5)
	choose(grid.get_child(6+1*6+4),2)
	choose(grid.get_child(6+2*6+4),6)
	choose(grid.get_child(6+2*6+5),0)
	check(lobby._team_rows[2].spawn==0 and lobby._team_rows[0].spawn==2,"Selecting occupied dropdown position swaps the two starting positions")
	check(lobby._team_rows[2].difficulty==6 and lobby._team_rows[1].difficulty==2,"Swapping positions preserves independent difficulties")
	choose(lobby._mode_opt,1)
	check(lobby._victory_reward_label.visible and lobby._victory_reward_label.text=="胜利收益 90%","Lobby previews the allied victory multiplier")
	choose(lobby._mode_opt,0)
	check(not lobby._victory_reward_label.visible,"Classic mode has no currency preview")
	choose(lobby._mode_opt,1)
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("lobby.png"))
	lobby.free()
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	check(lobby._team_rows.size()==4 and lobby._team_rows[2].team==1 and lobby._team_rows[3].country=="苏俄","lobby reopens on saved roster")
	check(lobby._team_rows[2].difficulty==6 and lobby._team_rows[2].spawn==0 and lobby._team_rows[0].spawn==2,"Saved map remembers difficulty and position")
	grid = lobby._team_grid
	for i in 4: choose(grid.get_child(6+i*6+3),0)
	check(lobby._start_button.disabled,"allied-only lineup cannot launch")
	choose(lobby._layout_opt,lobby.Preferences.OPTIONS.map_layout.find("yr_riverram"))
	check(grid.get_child_count()==18 and not lobby._start_button.disabled,"two-player map restores its own valid roster")
	lobby.free()

func brutal_tech_progression(mode:String,level:int) -> void:
	var rows := [{"country":"美国","team":1},{"country":"美国","team":2,"difficulty":level},{"country":"苏俄","team":3,"difficulty":level}]
	BattleRequest.configure_skirmish(mode,{"houses":rows,"country":"美国","enemy_country":"美国","map_layout":"yr_crctbrd","starting_funds":4000,"difficulty":level,"fog_of_war":true})
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	battle.paused=false
	get_tree().paused=false
	var rebuilt := {}
	for tick in 240:
		for ai in battle.get_children():
			if ai.get_script()==preload("res://scripts/world/house_ai.gd"): step_house(ai,2.0)
		for b in battle.buildings.duplicate():
			if battle.actor_alive(b): b._process(2.0)
		battle._update_power()
		if battle.fog!=null: battle.fog.rebuild()
		for pair in [["enemy","GAAIRC","GATECH","SREF"],["ai2","NARADR","NATECH","APOC"]]:
			var side:String=pair[0]
			var ids:Array=battle.owned_building_ids(side)
			if rebuilt.get(side,0)==0 and pair[2] in ids and battle.units.any(func(u):return battle.actor_alive(u) and u.side==side and u.unit_id==pair[3]):
				check(pair[1] in ids,side+" own radar and lab unlock a delivered T3 tank")
				for b in battle.buildings.duplicate():
					if b.side==side and b.building_id in [pair[1],pair[2]]: b.receive_hit(1000000)
				var remaining:Array=battle.owned_building_ids(side)
				check(pair[1] not in remaining and pair[2] not in remaining,side+" tech structures were actually destroyed")
				rebuilt[side]=1
			elif rebuilt.get(side,0)==1 and pair[1] in ids and pair[2] in ids: rebuilt[side]=2
		if rebuilt.get("enemy")==2 and rebuilt.get("ai2")==2:break
	for side in ["enemy","ai2"]:
		check(rebuilt.get(side,0)==2,side+" brutal builds T3 and replaces destroyed radar",battle.owned_building_ids(side))
	check_factory_expansion(mode)
	await finish()

func check_factory_expansion(mode: String) -> void:
	var parallel := {}
	var delivered := {}
	# Fund expansion separately from the preceding recovery scenario. Combat is
	# frozen in this fixture, so remove completed troops to keep the exits clear.
	for side in ["enemy","ai2"]: battle.credit_side(side,50000,true)
	for step in 160:
		for u in battle.units.duplicate():
			if u.side!="ally" and not u.is_harvester:
				battle.units.erase(u)
				u.free()
		for ai in battle.get_children():
			if ai.get_script()==preload("res://scripts/world/house_ai.gd"): step_house(ai,2.0)
		var active_lines := {}
		for line in battle.buildings.duplicate():
			if not battle.actor_alive(line):continue
			var product: String = line.production[0] if not line.production.is_empty() else ""
			var before: int = battle.units.size()
			if line.is_operational() and not product.is_empty():
				active_lines[line.building_id]=int(active_lines.get(line.building_id,0))+1
			line._process(2.0)
			if battle.units.size()>before and not product.is_empty() and battle.units[-1].unit_id==product:
				delivered[line.get_instance_id()]=true
		for side in ["enemy","ai2"]:
			if active_lines.get(battle.roster_id("GAWEAP",side),0)==3 and active_lines.get(battle.roster_id("GAPILE",side),0)==3:
				parallel[side]=true
		battle._update_power()
		if battle.fog!=null:battle.fog.rebuild()
		var completed:int=battle.buildings.filter(func(b):return delivered.has(b.get_instance_id()) and b.building_id in ["GAWEAP","NAWEAP","GAPILE","NAHAND"]).size()
		if parallel.size()==2 and completed==12:break
	for side in ["enemy","ai2"]:
		var owned:Array=battle.owned_building_ids(side)
		check(parallel.has(side),side+" fills three independent infantry and three vehicle lines",owned)
		for id in ["GAWEAP","GAPILE"]:
			var bid:String=battle.roster_id(id,side)
			var producing:int=battle.buildings.filter(func(b):return b.side==side and b.building_id==bid and delivered.has(b.get_instance_id())).size()
			check(owned.count(bid)==3 and producing==3,side+" every completed line delivers troops: "+bid, [mode,battle.funds_for(side),battle.buildings.filter(func(b):return b.side==side and b.building_id==bid).map(func(b):return [b.production,b.exit_blocked,b.position,delivered.has(b.get_instance_id())])])
		var speed:float=battle.factory_speed_factor(side,"APOC" if side=="ai2" else "SREF")
		check(speed>1.0 if mode==MatchRules.RA2 else speed==1.0,side+" production follows selected mode")

func check_aircraft_return() -> void:
	var rows := [{"country":"苏俄","team":1},{"country":"美国","team":2},{"country":"韩国","team":3}]
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"houses":rows,"map_layout":"yr_crctbrd","fog_of_war":false})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	battle.paused = false
	get_tree().paused = false
	for ai in battle.get_children():
		if ai.get_script() != preload("res://scripts/world/house_ai.gd"): continue
		var field = battle._place_building("GAAIRC",ai.house_id,ai.base_center + Vector2(230,150),true)
		field._buildup_play = -1
		var power = battle._place_building("GAPOWR",ai.house_id,ai.base_center + Vector2(250,-140),true)
		power._buildup_play = -1
		battle._update_power()
		var plane = battle.spawn_unit("ORCA" if ai.house_id=="enemy" else "BEAG",ai.house_id,field.position,field)
		plane.process_mode = Node.PROCESS_MODE_ALWAYS
		plane.set_physics_process(false)
		await get_tree().physics_frame
		var pad: int = plane.logistics.dock_slot
		var destination: Vector2 = plane.logistics.dock_destination()
		var target = battle.spawn_unit("HTNK","ally",destination + Vector2(400,80))
		plane.order_target(target,false,false)
		for tick in 1600:
			plane._physics_process(1.0/60.0)
			if plane.logistics.ammo == 0 and plane.logistics.air_state == "returning": break
		check(plane.logistics.ammo == 0 and plane.position.distance_to(destination)>8.0,ai.house_id+" aircraft fires its last volley away from base")
		var wave := {"attack_dispatch":{"units":[plane],"goal":ai.base_center}}
		ai.dispatch_attacker(wave)
		check(plane.logistics.air_state=="returning" and plane.logistics.ammo==0 and not plane.has_move_order and not plane.attack_ordered,ai.house_id+" empty jet ignores pending ground wave")
		# Older saves could carry a ground waypoint into the return leg.
		plane.order_queue.append({"point":ai.base_center})
		var rearmed_on_pad := false
		for tick in 2600:
			plane._physics_process(1.0/60.0)
			if plane.logistics.air_state=="rearming" and plane.position.distance_to(destination)<1.0:
				rearmed_on_pad = true
			if plane.logistics.air_state=="parked": break
		check(rearmed_on_pad and plane.logistics.air_state=="parked" and plane.logistics.ammo==plane.logistics.ammo_max and plane.logistics.dock_slot==pad and plane.order_queue.is_empty() and not plane.has_move_order,ai.house_id+" empty jet lands, reloads and keeps its pad")
		plane.order_move(ai.base_center)
		plane.position = destination + Vector2(120,20)
		plane.logistics.air_lift = 0.0
		plane._physics_process(1.0/60.0)
		check(plane.logistics.air_state=="returning" and not plane.has_move_order,ai.house_id+" loaded legacy ground march becomes a return order")
		var residents: Array = []
		for index in 3: residents.append(battle.spawn_unit("ORCA",ai.house_id,field.position,field))
		var waiting = battle.spawn_unit("ORCA",ai.house_id,destination+Vector2(420,0))
		waiting.process_mode = Node.PROCESS_MODE_ALWAYS
		waiting.set_physics_process(false)
		waiting.logistics.ammo = 0
		for tick in 180: waiting._physics_process(1.0/60.0)
		check(not is_instance_valid(waiting.logistics.home) and waiting.logistics.air_state=="returning" and waiting.logistics.air_lift>0.95 and waiting.logistics.ammo==0,ai.house_id+" full airport keeps orphan airborne without ammo")
		var resident = residents.pop_back()
		var vacant: int = resident.logistics.dock_slot
		battle.units.erase(resident)
		resident.free()
		for tick in 70: waiting._physics_process(1.0/60.0)
		check(waiting.logistics.home==field and waiting.logistics.dock_slot==vacant,ai.house_id+" orphan picks up the newly vacant pad")
		field.receive_hit(1000000.0)
		check(not battle.actor_alive(waiting) and not battle.actor_alive(plane),ai.house_id+" destruction removes the jets assigned to this airport")
	await finish()

func check_house_air_defense() -> void:
	var rows:=[{"country":"苏俄","team":1},{"country":"美国","team":2,"difficulty":3},{"country":"苏俄","team":2,"difficulty":3}]
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"houses":rows,"country":"苏俄","enemy_country":"美国","map_layout":"yr_crctbrd","starting_funds":12000,"fog_of_war":true})
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	battle.paused=false
	get_tree().paused=false
	for ai in battle.get_children():
		if ai.get_script()!=preload("res://scripts/world/house_ai.gd"):continue
		var owner:String=ai.house_id
		var id:="NASAM" if owner=="enemy" else "NAFLAK"
		var starting_funds:float=battle.funds_for(owner)
		step_house(ai,2)
		var sites:Array=battle.buildings.filter(func(b):return b.side==owner and b.building_id==id)
		check(sites.size()==1 and sites[0].under_construction,owner+" builds baseline AA before seeing aircraft")
		if sites.is_empty():continue
		var gun=sites[0]
		gun._process(100)
		gun._process(10)
		battle._update_power()
		check(gun.is_operational() and battle.funds_for(owner)<starting_funds,owner+" completes and pays for AA")
		var pos:Vector2=gun.position+Vector2(70,0)
		var friendly=battle.spawn_unit("ZEP",owner,pos)
		friendly.logistics.air_lift=1.0
		var foe=battle.spawn_unit("ZEP","ally",Vector2.ZERO)
		foe.logistics.air_lift=1.0
		battle.fog.rebuild()
		var policy=preload("res://scripts/world/skirmish_tactics.gd")
		check(policy.air_defense_order(battle,owner,3,battle.owned_building_ids(owner)).is_empty(),owner+" friendly or unseen aircraft do not raise quota")
		var early:Array=[battle.roster_id("GACNST",owner),battle.roster_id("GAPILE",owner)]
		check(policy.air_defense_order(battle,owner,3,early).is_empty(),owner+" early economy waits while hostile aircraft remain hidden")
		foe.position=pos
		battle.fog.rebuild()
		check(policy.air_defense_order(battle,owner,3,early)==id,owner+" visible bomber prompts emergency AA before war factory")
		step_house(ai,2)
		sites=battle.buildings.filter(func(b):return b.side==owner and b.building_id==id and not b._dead)
		check(sites.size()==2,owner+" starts a second AA when it sees an enemy airship")
		var extra=battle.spawn_unit("ZEP","ally",pos+Vector2(5,0))
		extra.logistics.air_lift=1.0
		battle.fog.rebuild()
		var owned:Array=battle.owned_building_ids(owner)
		for n in range(1,6):
			check(policy.air_defense_order(battle,owner,0,owned)==id,owner+" two Kirovs demand six towers even at easy "+str(n))
			owned.append(id)
		check(policy.air_defense_order(battle,owner,3,owned).is_empty(),owner+" two Kirovs stop emergency building at six towers")
		var army_lines:Array=battle.buildings.filter(func(b):return b.side==owner and b.building_id in ["GAWEAP","NAWEAP","GAPILE","NAHAND"])
		var radar: String = "GAAIRC" if owner=="enemy" else "NARADR"
		if not battle.owned_building_ids(owner).has(radar):
			battle._place_building(radar,owner,pos+Vector2(150,0),true)
		battle._place_building(battle.roster_id("GAPOWR",owner),owner,pos+Vector2(0,250),true)
		battle._update_power()
		battle.credit_side(owner,20000)
		for line in army_lines:
			line._buildup_play=-1
			while not line.production.is_empty():line.cancel_at(0)
		ai.train_army(army_lines,battle.units.filter(func(u):return u.side==owner),{"cost":200000})
		for line in army_lines:
			var expected:String={"GAWEAP":"FV","NAWEAP":"HTK","GAPILE":"JUMPJET","NAHAND":"FLAKT"}[line.building_id]
			check(line.production==[expected],owner+" emergency purchase ahead of tech savings "+expected,line.production)
		check(army_lines.size()>=2,owner+" war factory and barracks tested")
		battle.units.erase(extra)
		extra.free()
		var hp:float=foe.hp
		for frame in 240:
			gun._process(1.0/60)
			for projectile in battle.projectiles_root.get_children():
				if projectile is Projectile and not projectile.is_queued_for_deletion():projectile._physics_process(1.0/60)
			if foe.hp<hp: break
		check(foe.hp<hp,owner+" completed AA hits enemy airship",foe.hp)
		gun.receive_hit(1000000)
		if sites.size()==2:
			sites[1]._process(100)
			sites[1]._process(10)
		step_house(ai,2)
		check(battle.buildings.filter(func(b):return battle.actor_alive(b) and b.side==owner and b.building_id==id).size()==2,owner+" replaces destroyed AA under air threat")
		for site in battle.buildings:
			if battle.actor_alive(site) and site.side==owner and site.building_id==id and site.under_construction:
				site._process(100)
				site._process(10)
		battle._update_power()
		step_house(ai,2)
		check(battle.buildings.filter(func(b):return battle.actor_alive(b) and b.side==owner and b.building_id==id).size()==3,owner+" starts third AA site against a surviving Kirov")
		foe.free()
		friendly.free()
		battle.units=battle.units.filter(func(u):return is_instance_valid(u))
	await finish()

func swapped_duel() -> void:
	var rows:=[{"team":1,"country":"美国","spawn":1},{"team":2,"country":"苏俄","spawn":0,"difficulty":3}]
	BattleRequest.configure_skirmish(MatchRules.RA2,{"houses":rows,"country":"美国","enemy_country":"苏俄","map_layout":"coast","opening":"mcv"})
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	var starts:=Houses.starts("coast",battle.map_size)
	for i in 2:
		var owner:=Houses.id(i)
		var vehicles:Array=battle.units.filter(func(u):return u.side==owner and not u.deploy_building_id().is_empty())
		check(vehicles.size()==1 and vehicles[0].position.distance_to(starts[1-i])<40,owner+" MCV follows swapped duel start")
	check(battle.skirmish_ai.difficulty==3,"Duel AI uses seat difficulty")
	await finish()
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"difficulty":4,"map_layout":"coast"})
	check(BattleRequest.house_spawn(0)==0 and BattleRequest.house_spawn(1)==1 and BattleRequest.victory_difficulty()==4,"Legacy duel keeps original starts and global difficulty")

func mobile_bases() -> void:
	var rows := [{"team":1,"country":"美国"},{"team":2,"country":"苏俄"},{"team":1,"country":"英国"}]
	BattleRequest.configure_skirmish(MatchRules.RA2,{"houses":rows,"country":"美国","enemy_country":"苏俄","map_layout":"yr_crctbrd","opening":"mcv"})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	get_tree().paused = false
	for child in battle.get_children():
		if child.get_script()==preload("res://scripts/world/house_ai.gd"): step_house(child,30.0)
	for side in ["enemy","ai2"]:
		check(battle.buildings.any(func(b):return b.side==side and b.building_id in ["NACNST","GACNST"]),side+" deploys its own MCV")
	var before: float = battle.funds_for("ai2")
	for site in battle.buildings: site._buildup_play = -1.0
	for child in battle.get_children():
		if child.get_script()==preload("res://scripts/world/house_ai.gd") and child.house_id=="ai2": step_house(child,3.0)
	var plants: Array = battle.buildings.filter(func(b):return b.side=="ai2" and b.building_id=="GAPOWR")
	check(plants.size()==1 and battle.funds_for("ai2")==before,"MCV economy begins construction without double charging")
	if not plants.is_empty():
		plants[0]._process(120.0)
		check(not plants[0].under_construction and is_equal_approx(before-battle.funds_for("ai2"),plants[0].build_cost),"completed power plant charges its owner once")
	await finish()

func hero_scouting() -> void:
	const Hero = preload("res://scripts/units/tank_hero.gd")
	var rows := [{"team":1,"country":"美国"},{"team":2,"country":"美国"},{"team":3,"country":"虫群巢穴"},{"team":2,"country":"苏俄"}]
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"houses":rows,"country":"美国","enemy_country":"美国","map_layout":"yr_crctbrd","fog_of_war":true})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	battle = screen.battle
	var homes := Houses.starts("yr_crctbrd")
	var packed_base = battle.spawn_unit("AMCV","enemy",homes[1]+Vector2(800,0))
	for b in battle.buildings:
		if b.side=="enemy" and b.building_id=="GACNST": b.hp=0
	var hive = battle.buildings.filter(func(b):return b.building_id=="swarm_hive")[0]
	var yard = battle.buildings.filter(func(b):return b.side=="ai3" and b.building_id=="NACNST")[0]
	var ally = battle.spawn_unit("MTNK","ally",homes[0])
	var targets: Array = [packed_base,hive,yard]
	for reborn in [false,true]:
		Hero.scout(ally,battle,reborn)
		for target in targets:
			var index: int = battle.fog._index(target.position)
			var remaining: float = battle.fog.sight_until.ally.get(index,0.0)-battle.fog.sight_clock
			check(battle.allied_state.hero_scout_marks.get(target.position)==(10.0 if reborn else 5.0),"minimap marks actual scout site "+target.side)
			check(is_equal_approx(remaining,10.0 if reborn else 5.0),"simultaneous hero reveal "+target.side+" reborn="+str(reborn), remaining)
	# The two enemy houses sharing a team scout our base and the hive together.
	var own_marks:Dictionary=battle.allied_state.hero_scout_marks.duplicate()
	battle.fog.sight_until.ai3.clear()
	Hero.scout(packed_base,battle)
	check(battle.allied_state.hero_scout_marks==own_marks,"Enemy reconnaissance never inserts player minimap marks")
	for target in [ally,hive]:
		check(battle.fog.sight_until.ai3.has(battle.fog._index(target.position)),"allied observer shares hero reveal at "+target.side)
	check(not battle.fog.sight_until.ai3.has(battle.fog._index(yard.position)),"allied HQ receives no enemy scout mark")
	packed_base.hp = 0
	battle.fog.sight_until.ally.clear()
	Hero.scout(ally,battle)
	var industrial_sites: Array = battle.buildings.filter(func(b):return b.side=="enemy" and battle.actor_alive(b) and not b.data.get("tags",[]).has("defense") and not b.data.get("tags",[]).has("civilian"))
	check(industrial_sites.any(func(b):return battle.fog.sight_until.ally.has(battle.fog._index(b.position))),"house without yard or MCV still reveals a surviving base building")
	battle.fog.sight_clock += 11
	battle.fog.rebuild()
	check(not battle.fog.is_visible_at("ally",hive.position) and battle.fog.is_explored_at("ally",hive.position),"enemy base returns to explored fog after reveal expires")
	Hero.tick_scout_marks(battle,3.0)
	var expected:Dictionary=battle.allied_state.hero_scout_marks.duplicate()
	var codec:=Snapshot.new()
	var saved:=codec.capture(battle)
	check(BattleSaves.validate(saved).is_empty(),"Recon markers validate in a battle save")
	codec.restore(battle,saved)
	check(battle.allied_state.hero_scout_marks==expected,"Loading keeps only remaining radar time")
	Hero.tick_scout_marks(battle,8)
	check(not battle.allied_state.has("hero_scout_marks"),"Scout markers expire without following the units")
	battle.paused=false
	get_tree().paused=false
	var hive_ai=battle.house_controllers.ai2
	var hive_wallet:float=battle.funds_for("ai3")
	var types:Dictionary={}
	for tick in 18:
		step_house(hive_ai,6.0)
	for actor in battle.units:
		if battle.actor_alive(actor) and actor.side=="ai2": types[actor.unit_id]=true
	check(hive_ai.swarm and types.size()>=2 and hive_ai.ai_state.has("hatch_rng"),"multi-house hive purchases a mixed roster with saved hatching state",types.keys())
	check(battle.funds_for("ai3")==hive_wallet,"swarm hatching never charges a different AI house")

	await finish()

# The player's allied computer makes decisions about a third house using its own
# treasury, aircraft and technicians. Player-owned assets must never receive orders.
func allied_ai_operations() -> void:
	var rows := [{"country":"美国","team":1},{"country":"苏俄","team":2,"difficulty":2},{"country":"美国","team":1,"difficulty":3}]
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"houses":rows,"map_layout":"yr_crctbrd","starting_funds":12000,"fog_of_war":false})
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle=screen.battle
	battle.paused=false
	get_tree().paused=false
	var ai=battle.house_controllers.ai2
	var pos:Vector2=ai.base_center
	var depot=battle._place_building("GADEPT","ai2",pos+Vector2(110,110),true)
	var lab=battle._place_building("NATECH","enemy",pos+Vector2(1250,0),true)
	var panel = screen.hud._enemy_alerts
	Ra2Sfx._eva_last.clear()
	var weather=battle._place_building("GAWEAT","ai2",pos+Vector2(0,300),true,true)
	check(Ra2Sfx._eva_last.has("EVA_WEATHERDEVICEREADY") and screen.hud._logs.back().node.text.contains("友方天气控制器"),"allied construction announces correct side and EVA")
	var power=battle._place_building("NANRCT","ai2",pos+Vector2(0,480),true)
	for site in [depot,lab,weather,power]: site._buildup_play=-1
	battle._update_power()
	var spy=battle.spawn_unit("SPY","ai2",pos)
	var other_spy=battle.spawn_unit("SPY","ally",pos)
	var tank=battle.spawn_unit("MTNK","ai2",pos+Vector2(180,0))
	tank.hp=tank.max_hp*0.2
	var hostile=battle.spawn_unit("HTNK","enemy",lab.position+Vector2(0,60))
	var friendly=battle.spawn_unit("MTNK","ally",pos)
	var ops=preload("res://scripts/world/skirmish_operations.gd")
	var targets:Array=ops.targets(ai)
	check(targets.has(hostile) and not targets.has(friendly) and not targets.has(other_spy),"allied AI sees enemy house as hostile and player as friendly")
	check(ai.objective()==ai.homes.enemy,"allied AI fallback points at enemy start")
	var player_funds:float=battle.funds
	var opponent_funds:float=battle.enemy_funds
	weather._sw_charge=weather.sw_recharge()-61.0
	panel.refresh()
	check(panel.friendly_timers.visible and panel.friendly_timers.text.contains("闪电风暴") and not panel.friendly_timers.text.contains("就绪"),"ally charging is visible outside combat log")
	weather._sw_charge=weather.sw_recharge()
	panel.refresh()
	check(panel.friendly_timers.text.contains("就绪"),"allied storm indicates readiness")
	var enemy_notices := []
	battle.enemy_superweapon_launched.connect(func(label): enemy_notices.append(label))
	var allied_notices := []
	battle.friendly_storm_launched.connect(func(label): allied_notices.append(label))
	for cycle in 3:
		step_house(ai,2)
		if ai.ai_state.has("ai_neutral_oil"): break
	check(spy.special.get("action")=="allied_infiltrate" and spy.special.get("target")==lab,"allied AI orders own spy to enemy lab")
	check(tank.repairing and tank.repair_depot==depot,"allied AI orders own tank to its repair depot")
	check(weather._sw_charge==0 and LightningStorm.storms(battle).size()==1,"allied AI uses charged weather against visible enemy cluster")
	check(allied_notices == ["友方"] and enemy_notices.is_empty() and panel.friendly_launches.is_visible_in_tree() and panel.friendly_launches.text.contains("友方已发动闪电风暴") and panel.friendly_timers.text.contains("发动中"),"real allied AI launch has its own banner")
	var impact: Vector2 = LightningStorm.storms(battle)[0].target
	check(screen.hud.minimap._pings.any(func(p):return p.kind=="friendly_support" and p.pos==impact) and Ra2Sfx._eva_last.has("EVA_LIGHTNINGSTORMCREATED"),"ally target ping and commander storm voice")
	check(not weather.fire_superweapon(impact) and allied_notices.size()==1,"failed repeat does not repeat friendly announcement")
	panel.friendly_deadlines["友方"] = 0
	panel.refresh()
	check(not panel.friendly_launches.visible and panel.friendly_timers.visible,"friendly notice expires separately from timer")
	check(not other_spy.special.has("action") and not friendly.attack_ordered and battle.funds==player_funds and battle.enemy_funds==opponent_funds,"allied AI leaves player orders and other treasuries alone")
	check(ai.ai_state.has("ai_neutral_oil") and not battle.ai_decisions("enemy").has("ai_neutral_oil"),"oil scouting and mission memory belong to the acting house")
	var yard=battle._place_building("GAYARD","ai2",Vector2(117.5,48.5)*55.0,true)
	yard._buildup_play=-1
	var basin: Dictionary = ai.Operations.naval_basin(yard)
	check(basin.zone > 0 and basin.interval == 4,"Circuit Board low bridges restrict the allied yard to a small river")
	ai.Operations.train_navy(ai,0,true)
	check(yard.production.is_empty(),"allied computer leaves priority funds for land on Circuit Board")
	ai.Operations.train_navy(ai,0)
	check(not yard.production.is_empty() and yard.production[0] in yard.buildable,"ally uses its own shipyard to buy a legal ship")
	var boat_funds:float=battle.funds
	var enemy_funds:float=battle.enemy_funds
	var factory=battle.buildings.filter(func(b):return b.side=="ai2" and b.building_id=="GAWEAP")[0]
	while not factory.production.is_empty(): factory.cancel_at(0)
	factory._buildup_play=-1
	for b in battle.buildings:
		if b.side=="ai2" and b.is_hq: b.hp=0
	step_house(ai,2)
	check(factory.production.has("AMCV") and battle.funds==boat_funds and battle.enemy_funds==enemy_funds,"allied AI replaces its lost construction yard through its own war factory")

	var troops := []
	while battle.ai_living_count("ai2")<32:
		var unit=battle.spawn_unit("MTNK","ai2",ai.rally+Vector2(troops.size()*12,0))
		if unit==null: break
		unit.order_stop()
		troops.append(unit)
	var state:Dictionary=ai.ai_state
	ai._army=troops.duplicate()
	state.army=ai._army
	state.attack=0.0
	state.defending=false
	state.erase("attack_dispatch")
	ai._form_wave(state)
	check(ai.Campaign.guards(ai)==10 and state.has("attack_dispatch"),"real allied 32-unit offensive retains ten home guards")
	if state.has("attack_dispatch"):
		check(not state.attack_dispatch.units.is_empty() and state.attack_dispatch.slots.size()==state.attack_dispatch.units.size(),"remaining outgoing orders retain one formation slot each")
		var remaining: int=state.attack_dispatch.units.size()
		var codec:=Snapshot.new()
		var saved:Dictionary=codec.capture(battle)
		check(BattleSaves.validate(saved).is_empty(),"new allied wave and its formation slots serialize")
		codec.restore(battle,saved)
		var restored=ai.ai_state
		ai.dispatch_attacker(restored)
		check(restored.attack_dispatch.units.size()==remaining-1 and restored.attack_dispatch.slots.size()==remaining-1,"restored allied offensive resumes at its next formation slot")

	await finish()

func population_limit() -> void:
	var rows := [{"country":"美国","team":1},{"country":"美国","team":2,"difficulty":2},{"country":"美国","team":1,"difficulty":2}]
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"houses":rows,"map_layout":"yr_crctbrd","starting_funds":12000,"fog_of_war":false})
	screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	battle=screen.battle
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle.paused=false
	get_tree().paused=false
	var lines:Array=battle.buildings.filter(func(b):return b.side=="enemy" and b.building_id=="GAPILE")
	var first=lines[0]
	var second=battle._place_building("GAPILE","enemy",first.position+Vector2(280,0),true)
	for line in [first,second]: line._buildup_play=-1
	var point:Vector2=battle.house_controllers.enemy.base_center+Vector2(450,350)
	var carrier=battle.spawn_unit("SHAD","enemy",point)
	var troops:Array=battle.units.filter(func(u):return u.side=="enemy" and battle.actor_alive(u))
	while troops.size()<63:
		var soldier=battle.spawn_unit("E1","enemy",point)
		if soldier==null: break
		troops.append(soldier)
	troops[-1].set_stowed(carrier)
	check(troops.size()==63 and first.enqueue("E1"),"63 living, including passenger, allow one reserved order")
	check(not second.can_queue("E1") and second.enqueue_many("E1",3)==0,"parallel factories share the final reserved slot")
	check(battle.spawn_unit("CMIN","enemy",point)==null,"free miner cannot consume another factory's reserved slot")
	check(battle.spawn_unit("HTNK","ai2",point)!=null and battle.spawn_unit("MTNK","ally",point)!=null,"AI ally and player remain independently available")
	first._process(120)
	check(first.production.is_empty() and battle.ai_population_full("enemy",false),"reserved order delivers unit 64")
	var captured=battle.spawn_unit("E1","ally",point)
	AlliedAbilities.change_side(captured,"enemy") # Exercise an existing over-limit force.
	second.production.append("E1")
	second.progress=0.3
	var price:float=battle.production_price(GameData.get_unit("E1"),"enemy")
	var paid:float=price*second.progress*second.build_speed/GameData.ra2_build_time(GameData.get_unit("E1"))
	second.production_paid=paid
	second.special.unit_price=price
	var snapshot:=Snapshot.new()
	var record:Dictionary=snapshot.capture(battle)
	check(BattleSaves.validate(record).is_empty(),"over-limit house saves with original units and paid queue")
	var location:Vector2=second.position
	snapshot.restore(battle,record)
	battle.paused=false
	get_tree().paused=false
	second=battle.buildings.filter(func(b):return b.side=="enemy" and b.building_id=="GAPILE" and b.position==location)[0]
	troops=battle.units.filter(func(u):return battle.actor_alive(u) and u.side=="enemy" and u.unit_id=="E1" and u.embarked_in==null)
	check(battle.units.filter(func(u):return battle.actor_alive(u) and u.side=="enemy").size()==65,"loading preserves all 65 existing units")
	var funds:float=battle.funds_for("enemy")
	second._process(120)
	check(second.production==["E1"] and is_equal_approx(second.progress,0.3) and is_equal_approx(second.production_paid,paid) and battle.funds_for("enemy")==funds,"old paid queue waits intact at cap")
	troops[-1].receive_hit(100000)
	second._process(120)
	check(second.production==["E1"] and is_equal_approx(second.progress,0.3),"64 remaining still holds production")
	troops[-2].receive_hit(100000)
	second._process(120)
	check(second.production.is_empty() and battle.ai_population_full("enemy",false),"vacancy releases queued unit once")
	check(battle.spawn_unit("ZEP","enemy",point)==null and battle.spawn_unit("V3ROCKET","enemy",point)!=null,"64 blocks further aircraft but permits missile firing")
	await finish()

func step_house(ai: Node, seconds: float) -> void:
	# Each synchronous fixture step advances simulated time; give it a fresh
	# render-frame decision budget. Same-frame contention is tested separately.
	ai.battle.ai_strategy_budget.frame = -1
	ai._process(seconds)
