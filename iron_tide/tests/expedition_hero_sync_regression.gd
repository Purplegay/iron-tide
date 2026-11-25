extends "res://tests/expedition_regression.gd"
const Heroes=preload("res://scripts/expedition/heroes.gd")
const P=preload("res://scripts/units/peregrine.gd")
const PC=preload("res://scripts/units/peregrine_cards.gd")
const Hunt=preload("res://scripts/units/peregrine_hunt_order.gd")
const Service=preload("res://scripts/units/peregrine_service.gd")
const L=preload("res://scripts/units/leizhu.gd")
const LC=preload("res://scripts/units/leizhu_cards.gd")
const Shields=preload("res://scripts/ui/shield_readout.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for id:String in MetaProgress.Academy.HEROES:
		var country:="美国" if GameData.get_unit(id).faction=="allied" else "苏俄"
		check(not Expedition.start(country,id,719),"locked opening hero rejected: "+id)
	for id:String in MetaProgress.Academy.HEROES:await opening(id)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)

func actors(id:String) -> Array:
	return battle.units.filter(func(u):return AlliedAbilities.alive(u) and u.special.get("academy_hero","")==id)

func opening(id:String) -> void:
	MetaProgress.reset_save()
	MetaProgress.academy.hero_builds={id:MetaProgress.Academy.hero_requirement(id)}
	MetaProgress.academy.hero_training={id:{"firepower":3,"health":4}}
	MetaProgress.academy.hero_escort_ranks={id:2};MetaProgress.academy.hero_survival_ranks={id:5}
	var cards:Array=[PC.ACTIVE,PC.PASSIVE] if id=="ORCA" else [LC.ACTIVE,LC.PASSIVE] if id=="TTNK" else []
	if not cards.is_empty():
		MetaProgress.unlocked_skills.assign(cards);MetaProgress.academy.levels={cards[0]:3,cards[1]:3}
		MetaProgress.academy.hero_loadouts={id:{"active":[cards[0]],"passive":cards[1]}}
	var country:="美国" if GameData.get_unit(id).faction=="allied" else "苏俄"
	var foreign:="苏俄" if country=="美国" else "美国"
	check(id in Expedition.heroes(country) and id not in Expedition.heroes(foreign),"opening selector respects unlock and faction: "+id)
	var menu=load("res://scenes/expedition.tscn").instantiate();menu.show_new=true;menu.country_value=country;add_child(menu)
	var selected:=false
	for option in menu.find_children("*","OptionButton",true,false):
		for index in option.item_count:
			if option.get_item_metadata(index)==id:option.select(index);option.item_selected.emit(index);selected=menu.hero_value==id
	check(selected,"real opening dropdown lists and selects unlocked hero: "+id)
	menu.free()
	check(not Expedition.start(foreign,id,719),"foreign opening hero rejected: "+id)
	check(Expedition.start(country,id,719) and Expedition.choose(0),"real first-stage opening accepts unlocked hero: "+id)
	check(Heroes.owned(Expedition.state)==[id] and id not in Heroes.available(Expedition.state),"selected hero consumes one slot and cannot be recruited twice: "+id)
	var later:=Expedition.state.duplicate(true);later.stage=5
	check(Heroes.available(later).size()==3,"stage-five recruitment retains other three same-faction heroes: "+id)
	var frozen:Dictionary=Expedition.state.frozen.duplicate(true)
	MetaProgress.academy.hero_training={};MetaProgress.academy.hero_escort_ranks={};MetaProgress.academy.hero_survival_ranks={};MetaProgress.academy.hero_loadouts={};MetaProgress.academy.levels={}
	check(Expedition.load_run() and Expedition.state.frozen==frozen and Expedition.launch(0),"disk reload preserves expedition's chosen training and equipment: "+id)
	if not instantiate_battle():await finish();return
	var found:=actors(id)
	check(found.size()==1 and found[0].side=="ally","first-stage runtime deploys exactly one player hero: "+id)
	if found.size()!=1:await finish();return
	var hero=found[0]
	check(hero.special.hero_command_rank==2 and hero.special.hero_survival_rank==5,"hero talent ranks use frozen profile: "+id)
	check(BattleRequest.combat_context.hero_training[id]=={"firepower":3,"health":4},"hero training remains frozen after permanent profile changes: "+id)
	if not cards.is_empty():
		check(UnitSkillLayout.find(hero,cards[0])>=0 and hero.passive.get("id")==cards[1] and BattleRequest.combat_context.card_ranks[cards[0]]==3,"independent hero W/passive and ranks survive expedition freeze: "+id)
	if id=="ORCA":await peregrine(hero)
	if id=="TTNK":await leizhu(hero)
	hero=actors(id)[0]
	var hp:float=hero.hp;var maximum:float=hero.max_hp
	check(Expedition.checkpoint(battle),"real expedition checkpoint writes hero state: "+id)
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"real expedition checkpoint reads hero state: "+id)
	if not instantiate_battle():await finish();return
	found=actors(id)
	check(found.size()==1 and is_equal_approx(found[0].hp,hp) and is_equal_approx(found[0].max_hp,maximum),"checkpoint preserves exact hero health without duplicate or heal: "+id)
	if id=="ORCA" and found.size()==1:
		check(found[0].special.has("hero_wreck") and found[0].logistics.air_lift==0,"checkpoint retains landed crash state")
		P.tick(found[0],180)
		check(not found[0].special.has("hero_wreck") and is_equal_approx(found[0].max_hp,maximum/10) and found[0].logistics.ammo==0,"restored expedition hero revives with normal health and empty ammo")
	if id in ["TANY","BORIS","ORCA","TTNK"] and found.size()==1:
		found[0]._die(null,true)
		check(Expedition.retreat(battle) and id in Heroes.wounded(Expedition.state),"fallen opening hero enters normal expedition injury flow: "+id)
		await finish()
		var supplies:int=Expedition.state.supplies
		check(Expedition.load_run() and Expedition.rescue_hero(id) and Expedition.state.supplies==supplies-60,"opening hero rescue costs sixty supplies once: "+id)
		check(not Expedition.rescue_hero(id) and Expedition.launch(0),"rescued opening hero advances to next stage: "+id)
		if not instantiate_battle():await finish();return
		check(actors(id).size()==1 and actors(id)[0].special.hero_survival_rank==5,"next-stage rescue retains one trained opening hero: "+id)
	await finish()

func clear_area(hero) -> Vector2:
	# Find legal terrain on the real generated route; only reveal this test's targets.
	if battle.fog!=null:
		for side in battle.fog.visible_cells:battle.fog.visible_cells[side].fill(1)
	for x in range(500,battle.map_size-950,110):
		for y in range(500,battle.map_size-500,110):
			var at:=Vector2(x,y)
			if not Service.ground_clear(hero,at):continue
			var clear:=true
			for offset in [Vector2(120,0),Vector2(850,0),Vector2(120,-90),Vector2(210,60),Vector2(30,60)]:
				if not Service.ground_clear(hero,at+offset):clear=false;break
			if clear:hero.position=at;return at
	check(false,"real expedition map has legal test area")
	return hero.position

func victim(at:Vector2):
	var unit=battle.spawn_unit("HTNK","enemy",at);unit.hp=100000;unit.max_hp=100000
	return unit

func peregrine(hero) -> void:
	var start:=clear_area(hero)
	check(battle.buildings.any(func(b):return b.side=="ally" and b.building_id in ["GAAIRC","AMRADR"]),"opening Peregrine provisions a real airport at stage one")
	var target=victim(start+Vector2(850,0));var ab=hero.ability_at(UnitSkillLayout.find(hero,PC.ACTIVE))
	hero.process_mode=Node.PROCESS_MODE_ALWAYS;hero.set_process(false);hero.set_physics_process(false)
	check(Hunt.request(hero,ab,target) and hero.special.has(Hunt.KEY),"expedition W accepts enemy beyond primary range")
	for frame in 1800:
		hero._physics_process(1.0/60)
		if battle.allied_state.has(PC.EVENTS):break
		if frame%30==0:await get_tree().physics_frame
	check(battle.allied_state.has(PC.EVENTS) and hero.position.distance_to(start)>100 and ab.cd_left>0,"expedition hero actually approaches and launches W")
	hero.position=start;hero.order_stop();hero.passive={};hero.special[P.KEY].erase("rearm_shield")
	var normal:float=hero.max_hp
	hero.receive_hit(normal*100,"shell",{},target)
	check(hero.special.has("hero_wreck") and hero.hp==normal*10 and hero.max_hp==normal*10,"expedition crash grants tenfold durability immediately")
	hero.receive_hit(17,"shell",{},target);var damaged:float=hero.hp
	P.tick(hero,1)
	check(damaged<normal*10 and hero.hp==damaged and hero.logistics.air_lift==0,"expedition descent takes damage and landing does not heal")

func leizhu(hero) -> void:
	var start:=clear_area(hero);var center:=start+Vector2(120,0);var target=victim(center)
	var weapon:Dictionary=hero._weapon_for_target(null).duplicate(true);weapon.damage*=.35
	var expected:float=Ra2Damage.quantize(CombatMath.full_damage(weapon,target.armor,hero.bonuses,null,target.ra2_armor,0,target)/float(target.bonuses.get("defense_bonus",1)))
	check(hero.use_ability(UnitSkillLayout.find(hero,LC.ACTIVE),center),"expedition LeiZhu W casts on real terrain")
	LC.world_tick(battle,.5)
	check(is_equal_approx(100000-target.hp,expected),"expedition rank-three W uses buffed 70-percent-per-second damage",[100000-target.hp,expected])
	L.tick(hero,9)
	check(Shields.amount(hero)>0,"expedition hero shield reports numeric remaining capacity")
	var nearby=victim(start+Vector2(-60,0))
	hero.process_mode=Node.PROCESS_MODE_ALWAYS;hero.set_process(false);hero.set_physics_process(false);hero.order_target(target,false,false)
	for frame in 1800:
		hero._physics_process(1.0/60)
		if hero.special[L.KEY].has("arc_flash"):break
		if frame%30==0:await get_tree().physics_frame
	check(hero.special[L.KEY].has("arc_flash") and nearby.hp<100000,"expedition real primary attacks trigger passive area discharge")
