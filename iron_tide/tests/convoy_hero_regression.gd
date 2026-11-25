extends "res://tests/commando_hero_regression.gd"
const Convoy=preload("res://scripts/units/convoy_heroes.gd")
const Reinforcement=preload("res://scripts/rules/hero_reinforcements.gd")

func board(side:String):
	var car=battle.spawn_unit("FV",side,Vector2(900,900))
	var soldier=battle.spawn_unit("E1",side,car.position)
	check(soldier.logistics.request_board(car),"ordinary infantry accepts boarding")
	soldier.logistics.tick(.1)
	check(soldier.embarked_in==car,"passenger occupies real vehicle")
	return car

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	boot("TANY")
	var first=board("ally")
	check(first.special.get("academy_hero")=="FV","first seated infantry promotes this IFV")
	check(A.hero_build_count(MetaProgress,"FV")==1,"permanent unlock awarded once")
	var second=board("ally")
	check(not second.special.has("academy_hero"),"second ordinary IFV remains ordinary")
	first._die()
	check(not board("ally").special.has("academy_hero"),"death does not release quota")
	var other=board("enemy")
	check(other.special.get("academy_hero")=="FV","enemy has independent quota")
	var snapshotter=BattleSaves.Snapshot.new()
	var snapshot:Dictionary=snapshotter.capture(battle)
	check(snapshotter.error.is_empty(),"capture used quota")
	snapshotter.restore(battle,snapshot)
	check(snapshotter.error.is_empty(),"restore used quota")
	check(not board("ally").special.has("academy_hero"),"loading after death preserves quota")
	var harv=battle.spawn_unit("HARV","ally",Vector2(850,900))
	var fac=battle._place_building("NAWEAP","ally",Vector2(1450,1250),true)
	fac._buildup_play=-1
	Reinforcement.produced(battle,fac,harv)
	check(not harv.special.has("academy_hero"),"locked miner remains ordinary")
	var ore:=ResourceNode.new()
	ore.position=harv.position;battle.add_child(ore)
	harv.resource_node=ore
	harv._collect_native_bale(.1,true)
	check(A.hero_build_count(MetaProgress,"HARV")==0,"mining before attacking cannot unlock")
	var target=battle.spawn_unit("MTNK","enemy",harv.position+Vector2(50,0))
	target.receive_hit(25,"bullet",{},harv,"RA3_PRISM")
	check(harv.special.has("convoy_miner_hit"),"ordinary miner marks its own damaging attack")
	harv.special.erase("ore_bale_wait");harv._collect_native_bale(.1,true)
	check(A.hero_build_count(MetaProgress,"HARV")==1,"same miner collects positive ore and unlocks")
	var later=battle.spawn_unit("HARV","ally",Vector2(860,900))
	Reinforcement.produced(battle,fac,later)
	check(not later.special.has("academy_hero"),"eligibility starts next match")
	await finish()
	for id in Convoy.IDs:
		var cards:Array=Convoy.Cards.C.cards()[id]
		for card in cards:MetaProgress.unlocked_skills.append(card)
		check(Loadouts.equip(MetaProgress,id,"active",cards[0]),"equip hero W "+id)
		check(Loadouts.equip(MetaProgress,id,"passive",cards[1]),"equip hero passive "+id)
	MetaProgress.academy.hero_escort_ranks={"FV":5,"HARV":4}
	MetaProgress.academy.hero_survival_ranks={"FV":2,"HARV":3}
	boot("BORIS")
	var car=board("ally")
	check(car.special.get("academy_hero")=="FV","new match gets its own slot")
	barracks("TANY")
	var choices:=Convoy.Cards.options(car)
	var engineer:="SENGINEER" if "SENGINEER" in choices else "ENGINEER"
	check(engineer in choices and "TANY" not in choices,"picker filters available ordinary infantry",choices)
	var crew_index:=UnitSkillLayout.find(car,Convoy.Cards.CREW)
	check(crew_index>=0,"manual W equipped in battle")
	var original=car.logistics.passengers[0]
	if crew_index>=0 and engineer in choices:
		check(Convoy.Cards.choose(car,car.ability_at(crew_index),engineer),"manual engineer selection boards")
		check(AlliedAbilities.is_repair_ifv(car) and car.ability_at(crew_index).cd_left>0,"new passenger changes actual turret and starts CD")
		check(original.embarked_in==null and original.buff_value("convoy_invulnerable")>0,"physical passenger exits with invulnerability")
		var injured=battle.spawn_unit("MTNK","ally",car.position+Vector2(40,0))
		injured.hp=injured.max_hp*.2
		for i in 3:injured.heal(4,car)
		check(car.special.convoy.has("projection_cd"),"same repair mode creates projection after three actual repairs")
	check(is_equal_approx(Convoy.absorb(car,100,other) if is_instance_valid(other) else Convoy.absorb(car,100,battle.spawn_unit("E2","enemy",Vector2(1600,1400))),10),"guard protects triggering hit")

	fac=battle._place_building("NAWEAP","ally",Vector2(1450,1250),true);fac._buildup_play=-1
	var refinery=battle._place_building("NAREFN","ally",Vector2(1750,1450),true);refinery._buildup_play=-1
	harv=produce(fac,"HARV")
	if harv==null:get_tree().quit(1);return
	harv.position=Vector2(850,900)
	check(harv.special.get("academy_hero")=="HARV","first paid completion promotes miner")
	check_miner_alert_and_selection(harv)
	var original_hold:float=harv.special.convoy.base_hold
	check(is_equal_approx(harv.cargo_cap,2*original_hold),"double hold based on original stock")
	var notices: Array[String]=[]
	var observe:=func(message:String,_tint:Color):
		if message.contains("W 可打出热锭"):notices.append(message)
	Events.battle_message.connect(observe)
	harv.cargo=original_hold*.25-1
	harv.resource_node=ResourceNode.new()
	battle.add_child(harv.resource_node)
	harv._collect_native_bale(.1,true)
	harv.special.erase("ore_bale_wait")
	harv._collect_native_bale(.1,true)
	check(notices.size()==1,"crossing one quarter original hold notifies once even with double hold")
	Convoy.spend(harv,harv.cargo)
	harv._collect_cargo(original_hold*.25)
	check(notices.size()==2,"crossing threshold after expenditure notifies again")
	Events.battle_message.disconnect(observe)
	harv.cargo=harv.cargo_cap
	harv._process_harvester(4)
	check(harv.harvest_state=="idle" and is_equal_approx(harv.cargo,2*original_hold),"full hero miner stays idle")
	var armored=battle.spawn_unit("MTNK","enemy",harv.position+Vector2(160,0))
	var slot:=UnitSkillLayout.find(harv,Convoy.Cards.PRESS)
	check(slot>=0 and harv.ability_info(slot).name.contains("热锭"),"loaded W preview")
	if slot>=0:
		var start_pos:Vector2=harv.position
		armored.position=start_pos+Vector2(480,0)
		battle.select_unit(harv,false)
		check(battle.request_ability(slot)==-1,"W button arms path preview")
		battle.confirm_cast(armored.position)
		check(harv.special.has(Convoy.Cards.APPROACH) and harv.has_move_order and harv.ability_at(slot).ready(),"click beyond range queues a reachable firing position")
		harv.order_stop(false)
		check(not harv.special.has(Convoy.Cards.APPROACH) and harv.cargo==harv.cargo_cap and harv.ability_at(slot).ready(),"stop cancels approach without spending")
		harv.attack_target=armored
		var second_vehicle=battle.spawn_unit("MTNK","enemy",start_pos+Vector2(355,0))
		check(Convoy.Cards.automatic(harv,harv.ability_at(slot)) and harv.special.has(Convoy.Cards.APPROACH),"Auto W can approach a hot shot through two enemy vehicles")
		armored.side="ally"
		Convoy.Cards.tick(harv,.1)
		check(not harv.has_move_order and not harv.special.has(Convoy.Cards.APPROACH) and harv.ability_at(slot).ready(),"invalidated target cancels without cooldown")
		armored.side="enemy"
		second_vehicle.position=start_pos+Vector2(0,420)
		check(harv.use_ability(slot,armored.position),"can reissue distant target")
		armored.position+=Vector2(0,60)
		Convoy.Cards.tick(harv,.42)
		check(harv.special.get(Convoy.Cards.APPROACH,{}).get("aim")==armored.position,"approach follows moving target")
		harv.process_mode=Node.PROCESS_MODE_ALWAYS
		for step in 600:
			await get_tree().physics_frame
			if harv.special.convoy.has("press"):break
		harv.process_mode=Node.PROCESS_MODE_INHERIT
		check(harv.position.distance_to(start_pos)>50 and harv.position.distance_to(armored.position)<=Convoy.Cards.PRESS_RANGE and harv.special.convoy.has("press"),"normal vehicle movement enters W range before windup")
		check(harv.ability_at(slot).ready() and harv.cargo==harv.cargo_cap,"approach and windup spend no ore or cooldown")
		var before_far_hit:float=armored.hp
		Convoy.Cards.tick(harv,.61)
		if battle.allied_state.has("convoy_slugs"):Convoy.Cards.slugs_tick(battle,1.0)
		check(armored.hp<before_far_hit and harv.ability_at(slot).cd_left>0 and is_equal_approx(harv.cargo,original_hold*1.75),"out-of-range order releases and hits once after arriving")
		if battle.allied_state.has("convoy_roads"):Convoy.Cards.roads_tick(battle,5.1)
		harv.ability_at(slot).cd_left=0
		harv.cargo=harv.cargo_cap
		armored.hp=armored.max_hp
		harv.position=start_pos
		armored.position=start_pos+Vector2(160,0)
		check(harv.use_ability(slot,armored.position),"target starts real W")
		check(is_equal_approx(harv.cargo,2*original_hold),"windup has no upfront cost")
		Convoy.Cards.tick(harv,.61)
		check(is_equal_approx(harv.cargo,1.75*original_hold),"release spends exactly one quarter original hold")
		check(battle.allied_state.has("convoy_roads"),"hot projectile places road")
		if battle.allied_state.has("convoy_roads"):
			Convoy.Cards.roads_tick(battle,4.9)
			check(battle.allied_state.has("convoy_roads"),"road lasts until five seconds")
			Convoy.Cards.roads_tick(battle,.11)
			check(not battle.allied_state.has("convoy_roads"),"road expires and opens route")
		if battle.allied_state.has("convoy_slugs"):
			var before:float=armored.hp
			Convoy.Cards.slugs_tick(battle,.65)
			check(armored.hp<before,"projectile direct damage during flight")
	harv.special.hero_survival_rank=3
	for i in 21:
		var enemy=battle.spawn_unit("E2","enemy",Vector2(900,1100))
		enemy._die(harv)
		check(int(harv.special.convoy.volume)==mini(500,120+20*i),"volume after kill "+str(i+1))
	harv._die()
	later=produce(fac,"HARV")
	if later==null:get_tree().quit(1);return
	check(not later.special.has("academy_hero"),"second paid completion after death stays ordinary")
	await finish()
	var meta=load("res://scripts/screens/meta_screen.gd").new();add_child(meta)
	for id in Convoy.IDs:
		var page=meta.heroes
		page.selected=id;page.refresh()
		page._try_skin(true)
		var art=page.preview.actor.hero_art
		check(art!=null,"gallery equips model "+id)
		if art!=null:
			var expected_poses:=6 if id=="FV" else 9
			var sheet:=Rect2(Vector2.ZERO,Vector2(art.atlas.get_size()))
			var valid:bool=art.table.poses.size()==expected_poses and art.table.frames.size()==32*expected_poses
			if valid:
				for pose in expected_poses:
					for face in 32:
						var tile:Rect2=art.tile_rect(pose,face)
						valid=valid and tile.has_area() and sheet.encloses(tile)
			check(valid,"all pose and direction rectangles fit atlas "+id)
			check(art.table.mounts.size()==32 and art.view_bounds().has_area(),"gallery bounds and turret mounts "+id)
		page._try_skin(false)
		check(page.preview.actor.hero_art==null,"gallery restores stock vehicle "+id)
		var demo=page.talent_demo
		for line in 2:
			demo.talent.select(line);demo.talent.item_selected.emit(line)
			check(demo.levels.item_count==6,"six talent ranks "+id)
			for rank in 6:
				demo.levels.select(rank);demo.levels.item_selected.emit(rank)
				check(demo.caption.text.contains(Convoy.Talents.TRAITS[id][line][rank]),"matching rank preview "+id+str(line)+str(rank))
		for card in Convoy.Cards.C.cards()[id]:
			page.find_child("Demo_"+card,true,false).pressed.emit()
			var gallery=meta.get_node_or_null("FactionCardDemos")
			check(gallery!=null,"open contract reward card demo "+card)
			if gallery!=null:
				for rank in 4:
					gallery.levels.select(rank);gallery.levels.item_selected.emit(rank)
					gallery.stage._process(.2)
					check(gallery.stage.card==card and gallery.stage.preview_rank==rank and gallery.stage.elapsed>0,"play and switch card rank "+card+str(rank))
				meta.remove_child(gallery);gallery.free()
	meta.queue_free()
	await get_tree().process_frame
	for id in Convoy.IDs:await expedition_case(id)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("CONVOY_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func check_miner_alert_and_selection(hero) -> void:
	var ordinary=battle.spawn_unit("HARV","ally",Vector2(400,500))
	var enemy=battle.spawn_unit("MTNK","enemy",Vector2(400,700))
	var key:=InputEventKey.new()
	key.keycode=KEY_F2
	key.physical_keycode=KEY_F2
	key.pressed=true
	battle._window_focused=true
	battle.paused=false
	get_tree().paused=false
	screen.hud._input(key)
	check(battle.selected_units.has(hero) and not battle.selected_units.has(ordinary),"F2 selects the promoted miner and skips the ordinary armed miner",{"world_input":battle.world_input_enabled(),"armed":not hero.weapon.is_empty(),"combatant":hero.is_in_group("combatants"),"excluded":hero.excluded_from_army_selection,"selection_size":battle.selected_units.size()})
	hero.excluded_from_army_selection=true
	screen.hud._input(key)
	check(not battle.selected_units.has(hero),"manual F2 exclusion applies to the hero")
	hero.excluded_from_army_selection=false
	var alert:="EVA_OREMINERUNDERATTACK"
	Ra2Sfx._eva_last.erase(alert)
	var pings:Array[Vector2]=[]
	var observe:=func(point:Vector2,kind:String):
		if kind=="attack":pings.append(point)
	Events.radar_ping.connect(observe)
	var before:float=hero.hp
	hero.receive_hit(20,"bullet",{},enemy)
	check(hero.hp<before and hero.position in pings and not Ra2Sfx._eva_last.has(alert),"hero takes damage and pings radar without requesting the EVA alert")
	ordinary.receive_hit(20,"bullet",{},enemy)
	check(Ra2Sfx._eva_last.has(alert),"ordinary miner hit immediately afterwards still triggers the alert")
	Events.radar_ping.disconnect(observe)

