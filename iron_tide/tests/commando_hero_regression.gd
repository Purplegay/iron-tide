extends "res://tests/base_recovery_regression.gd"
const A=preload("res://scripts/rules/academy.gd")
const C=preload("res://scripts/units/expansion_2_commandos.gd")
const Loadouts=preload("res://scripts/rules/hero_loadouts.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for id in C.IDS:await production(id)
	await combat_and_save()
	for id in C.IDS:await skin_shots(id)
	await menus()
	for id in C.IDS:await expedition_case(id)
	await expedition_hero_permit()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("COMMANDO_HERO_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func boot(id:String,mode:=MatchRules.EXTENDED) -> void:
	BattleRequest.configure_skirmish(mode,{"country":"美国" if id=="TANY" else "苏俄","map_size":2400,"starting_funds":100000,"fog_of_war":false})
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	for group in ["obstacles","resource_nodes"]:
		for node in get_tree().get_nodes_in_group(group):node.free()
	for unit in battle.units:unit.free()
	battle.units.clear();battle.water_rects.clear();battle.path_service.water_rects.clear();battle._refresh_pathing()
	for building in battle.buildings:building._buildup_play=-1.0
	GM.god_mode=false;GM.one_shot_kill=false;GM.infinite_funds=false;GM.infinite_power=false

func barracks(id:String):
	var factory=battle._place_building("GAPILE" if id=="TANY" else "NAHAND","ally",Vector2(1400,1300),true)
	var radar=battle._place_building("GAAIRC" if id=="TANY" else "NARADR","ally",Vector2(1700,1300),true)
	var tech=battle._place_building("GATECH" if id=="TANY" else "NATECH","ally",Vector2(1700,1600),true)
	for building in [factory,radar,tech]:building._buildup_play=-1.0
	return factory

func produce(factory,id:String):
	var before:Array=battle.units.duplicate()
	var queued:bool=factory.enqueue(id)
	check(queued,"real production accepts "+id,factory.queue_block_reason(id))
	if not queued:return null
	for step in 1800:
		if factory.production.is_empty():break
		factory._process(.1)
	var added:Array=battle.units.filter(func(unit):return not before.has(unit))
	check(added.size()==1,"exactly one paid commando, no legacy escorts "+id,added.size())
	return added[0] if added.size()>0 else null

func production(id:String) -> void:
	MetaProgress.academy.hero_builds={id:4}
	boot(id)
	var factory=barracks(id)
	var fifth=produce(factory,id)
	if fifth==null:await finish();return
	check(A.hero_build_count(MetaProgress,id)==5 and not fifth.special.has("academy_hero"),"fifth production unlocks next match only "+id)
	A.built(MetaProgress,battle,id,fifth,factory)
	check(A.hero_build_count(MetaProgress,id)==5,"replayed completion does not count twice "+id)
	fifth._die()
	var sixth=produce(factory,id)
	check(sixth!=null and not sixth.special.has("academy_hero"),"further production in unlocking match stays ordinary "+id)
	MetaProgress.save();MetaProgress.load_save()
	check(A.hero_build_count(MetaProgress,id)==6,"unlock persists "+id)
	await finish()
	boot(id)
	factory=barracks(id)
	var hero=produce(factory,id)
	if hero==null:await finish();return
	check(hero.special.get("academy_hero")==id and hero.veteran_level==2,"next match first paid unit is elite hero "+id)
	check(hero.special.has(C.KEY) and A.survival_rank(hero)==-1,"new baseline does not inherit old lethal protection "+id)
	var ordinary=battle.spawn_unit(id,"ally",Vector2(1250,1000))
	ordinary._grant_veteran(2,false)
	check(is_equal_approx(hero.attack_range,ordinary.attack_range),"no old hero weapon range bonus "+id)
	check(is_equal_approx(hero.sight-ordinary.sight,55.0 if id=="BORIS" else 0.0),"only Boris receives sight bonus "+id)
	C.install(hero)
	check(is_equal_approx(hero.sight-ordinary.sight,55.0 if id=="BORIS" else 0.0),"reinitialization cannot double sight "+id)
	A.promote(MetaProgress,battle,id,ordinary)
	check(not ordinary.special.has("academy_hero"),"gift/direct spawn does not replace already deployed hero "+id)
	hero._die()
	A.promote(MetaProgress,battle,id,ordinary)
	check(not ordinary.special.has("academy_hero"),"death does not reset deployment quota "+id)
	await finish()
	boot(id,MatchRules.RA2)
	var classic=battle.spawn_unit(id,"ally",Vector2(1000,1000))
	A.promote(MetaProgress,battle,id,classic)
	check(not classic.special.has("academy_hero"),"classic excludes new hero "+id)
	await finish()

func skin_shots(id:String) -> void:
	MetaProgress.academy.hero_builds={id:5}
	boot(id)
	var actor=battle.spawn_unit(id,"ally",Vector2(1000,1000))
	A.promote(MetaProgress,battle,id,actor)
	var losses:Array=[]
	var style:=Unit.CommandoFx.LASER if id=="TANY" else Unit.CommandoFx.SODA
	for dressed in [false,true]:
		actor.special.hero_skin=dressed
		var target=battle.spawn_unit("E2","enemy",Vector2(1090,1000))
		target.max_hp=10000;target.hp=10000
		actor.attack_target=target
		var effects_before:Array=battle.effects_root.get_children()
		actor._fire_shot(target,true)
		for p in battle.projectiles_root.get_children():
			if p is Projectile and not p.is_queued_for_deletion():p._physics_process(0.5)
		var trails:=0
		var hits:=0
		for fx in battle.effects_root.get_children():
			if fx not in effects_before and fx.get_script()==Unit.CommandoFx and fx.style==style:
				if fx.burst:hits+=1
				else:trails+=1
		check(trails==int(dressed) and hits==int(dressed),"primary produces exactly its equipped tracer and hit "+id+str(dressed),[trails,hits,actor._active_weapon().get("ra2_weapon_id")])
		losses.append(10000-target.hp)
	check(losses[0]>0 and is_equal_approx(losses[0],losses[1]),"skin leaves actual primary damage unchanged "+id,losses)
	check(Unit.CommandoFx.primary_style(actor,{"ra2_weapon_id":"Sapper" if id=="TANY" else "Flare"}).is_empty(),"special weapon retains its own effect "+id)
	await finish()

func combat_and_save() -> void:
	MetaProgress.academy.hero_builds={"TANY":5,"BORIS":5}
	MetaProgress.academy.hero_training={"TANY":{"firepower":4,"health":3}}
	MetaProgress.unlocked_skills.assign(["ap_smoke","ap_focus_fire","ps_hollow_point"])
	MetaProgress.set_unit_skill("TANY","active",0,"ap_smoke")
	MetaProgress.set_unit_skill("TANY","passive",0,"ps_hollow_point")
	check(Loadouts.equip(MetaProgress,"TANY","active","ap_focus_fire"),"Tanya independent W equip")
	check(Loadouts.equip(MetaProgress,"TANY","passive",""),"Tanya independent empty passive")
	boot("TANY")
	var tanya=battle.spawn_unit("TANY","ally",Vector2(900,1000))
	var boris=battle.spawn_unit("BORIS","ally",Vector2(1200,1000))
	var ordinary=battle.spawn_unit("TANY","ally",Vector2(1000,1000))
	A.promote(MetaProgress,battle,"TANY",tanya);A.promote(MetaProgress,battle,"BORIS",boris)
	for actor in [tanya,boris]:
		var description:=preload("res://scripts/ui/battle_effect_details.gd").describe(actor)
		check(description.contains(C.TITLES[actor.unit_id][0]) and description.contains(C.TITLES[actor.unit_id][1]) and not description.contains("随行护卫"),"battle detail uses new hero traits "+actor.unit_id)
	check(UnitSkillLayout.find(tanya,"ap_focus_fire")>=0 and UnitSkillLayout.find(ordinary,"ap_smoke")>=0 and tanya.passive.is_empty(),"actual independent loadout consumption")
	check(is_equal_approx(tanya._base_max_hp,ordinary._base_max_hp*1.0225),"hero health training applied once")
	Loadouts.equip(MetaProgress,"TANY","active","")
	check(BattleRequest.hero_loadout("TANY").active[0]=="ap_focus_fire","mid-match equipment changes do not alter frozen loadout")
	var enemy=battle.spawn_unit("E2","enemy",Vector2(1500,1000))
	tanya.max_hp=1000;tanya.hp=1000;tanya._base_max_hp=1000;tanya._base_def=1;tanya.bonuses.defense_bonus=1
	var incoming_scale:=1.0/CombatMath.with_defense(1.0,tanya.bonuses)
	tanya.receive_hit(200*incoming_scale,"bullet",{},enemy,"RA3_PRISM")
	check(is_equal_approx(tanya.hp,800) and is_equal_approx(tanya.special[C.KEY].get("shield",{}).get("hp",0),100),"live hit loses health before emergency shield",tanya.hp)
	tanya.receive_hit(50*incoming_scale,"bullet",{},enemy,"RA3_PRISM")
	check(is_equal_approx(tanya.hp,800) and is_equal_approx(tanya.special[C.KEY].shield.hp,50),"next hit consumes shield before health")
	C.tick(tanya,3.0)
	check(not tanya.special[C.KEY].has("shield") and is_equal_approx(tanya.special[C.KEY].escape_cd,27.0),"shield expires without resetting interval")
	C.injured(tanya,enemy,200)
	check(not tanya.special[C.KEY].has("shield"),"interval prevents repeat shield")
	C.tick(tanya,27.0)
	C.injured(tanya,tanya,200);C.injured(tanya,enemy,149.9)
	check(not tanya.special[C.KEY].has("shield"),"self damage and below threshold cannot trigger")
	tanya.hp=0;C.injured(tanya,enemy,500)
	check(not tanya.special[C.KEY].has("shield"),"fatal hit cannot resurrect Tanya")
	tanya.hp=800;C.injured(tanya,enemy,150)
	check(tanya.special[C.KEY].has("shield"),"exact threshold triggers")
	C.c4_started(tanya)
	check(is_equal_approx(C.defend(tanya,100,"bullet",{},enemy),85),"C4 installation ordinary defense")
	check(is_equal_approx(C.defend(tanya,100,"fire",{},enemy),85),"C4 guard also covers ordinary flame damage")
	check(C.defend(tanya,100,"crush",{},enemy)==100 and C.defend(tanya,100,"bullet",{"expansion_extra":true},enemy)==100,"C4 guard excludes crush and scripted extras")
	C.tick(tanya,1);C.c4_started(tanya)
	check(is_equal_approx(tanya.special[C.KEY].c4_guard,1) and is_equal_approx(tanya.special[C.KEY].c4_cd,11),"cancel/restart cannot refresh C4 guard")
	C.tick(boris,1.99)
	check(C.defend(boris,100,"bullet",{},enemy)==100,"radio needs full stationary delay")
	C.tick(boris,.01)
	check(is_equal_approx(C.defend(boris,100,"bullet",{},enemy),85),"radio arms at two seconds")
	check(C.defend(boris,100,"explosion",{},enemy)==100,"radio excludes area explosions")
	boris.position+=Vector2(.05,0);C.tick(boris,.1)
	check(is_equal_approx(C.defend(boris,100,"bullet",{},enemy),85),"radio moving grace starts")
	check(boris.special[C.KEY].stationary==0,"even subpixel movement resets stationary timer")
	var shot:=Projectile.new();shot.target=tanya
	check(C.defend(boris,100,"shell",{},shot)==100,"radio does not protect collateral projectile impact")
	shot.free()
	var codec=BattleSaves.Snapshot.new()
	var snapshot:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"new hero state captures")
	var previous_sight:float=boris.sight
	codec.restore(battle,snapshot)
	check(codec.error.is_empty(),"new hero state restores")
	for unit in battle.units:
		if unit.special.get("academy_hero")=="TANY":tanya=unit
		if unit.special.get("academy_hero")=="BORIS":boris=unit
	check(is_equal_approx(tanya.special[C.KEY].shield.left,2) and is_equal_approx(tanya.special[C.KEY].escape_cd,29) and is_equal_approx(tanya.special[C.KEY].c4_guard,1),"restore retains partial durations, no refill")
	check(is_equal_approx(boris.sight,previous_sight) and is_equal_approx(boris.special[C.KEY].radio_grace,.5),"restore retains sight and moving grace")
	check(BattleRequest.combat_context.commando_hero_unlocked.TANY and BattleRequest.combat_context.commando_hero_unlocked.BORIS,"battle snapshot retains opening unlock eligibility")
	var extra=battle.spawn_unit("TANY","ally",Vector2(1000,1200))
	A.promote(MetaProgress,battle,"TANY",extra)
	check(not extra.special.has("academy_hero"),"restored deployment marker prevents another hero")
	boris.position+=Vector2(10,0);C.tick(boris,.5)
	check(C.defend(boris,100,"bullet",{},null)==100 and not boris.special[C.KEY].has("radio_grace"),"moving grace expires")
	check(not C.entries(tanya).is_empty(),"live statuses expose shield and cooldown")
	await finish()
	await native_c4()

func native_c4() -> void:
	boot("TANY")
	var target=battle._place_building("NAPOWR","enemy",Vector2(1400,1400),true)
	target._buildup_play=-1.0
	var tanya=battle.spawn_unit("TANY","ally",Vector2(1240,1400))
	tanya.process_mode=Node.PROCESS_MODE_ALWAYS
	tanya.set_process(false);tanya.set_physics_process(false)
	await get_tree().physics_frame
	A.promote(MetaProgress,battle,"TANY",tanya)
	check(CommandoCombat.begin_c4(tanya,target),"real native C4 order accepted")
	for step in 600:
		tanya._physics_process(1.0/60.0)
		if tanya.special[C.KEY].has("c4_guard"):break
	check(tanya.special[C.KEY].has("c4_guard") and tanya.special.get("c4_stage","") in ["enter","exit"],"real installation starts guard only upon reaching building")
	AlliedAbilities.cancel(tanya)
	check(tanya.special[C.KEY].has("c4_cd"),"native cancellation retains consumed interval")
	await finish()

func menus() -> void:
	MetaProgress.academy.hero_builds={"TANY":5,"BORIS":5}
	var page=load("res://scripts/ui/hero_progression.gd").new();add_child(page)
	for id in C.IDS:
		page.selected=id;page.refresh()
		check(page.progress_label.text.contains("下一局") and page.escort_detail.text.contains("Lv.0"),"honest unlock and baseline UI "+id)
		check(page.trial.visible and page.outfit.visible and not page.outfit.disabled,"unlocked commando offers try-on and equip "+id)
		var before:Dictionary=MetaProgress.currency.duplicate(true)
		page.trial.button_pressed=true
		check(page.preview.actor.special.hero_skin and not MetaProgress.academy.get("hero_skin",{}).get(id,false),"try-on is preview only "+id)
		check(page._purchase("skin") and MetaProgress.currency==before,"equip is free "+id)
		MetaProgress.load_save()
		check(MetaProgress.academy.hero_skin[id] and page._purchase("skin") and not MetaProgress.academy.hero_skin[id],"equipped skin persists and can be removed "+id)
		if id=="BORIS":check(A.hero_talent_cost("survival",0,id)==40,"implemented Boris defense has its normal first-level quote")
		MetaProgress.currency.credits=100000
		var old_rank:=A.training_rank(MetaProgress.academy.get("hero_training",{}),id,"health")
		check(A.purchase(MetaProgress,"health",id) and MetaProgress.balance("credits")==100000-A.hero_training_cost(old_rank),"new hero training uses existing exact price "+id)
		MetaProgress.save();MetaProgress.load_save()
		check(A.training_rank(MetaProgress.academy.hero_training,id,"health")==old_rank+1,"new hero training persists "+id)
		for index in 2:
			page.talent_demo.talent.select(index);page.talent_demo._select_talent()
			check(page.talent_demo.levels.item_count==6 and page.talent_demo.caption.text.begins_with("Lv.0"),"demonstration exposes implemented trait levels "+id+str(index))
	page.free()
	const EH=preload("res://scripts/expedition/heroes.gd")
	check("TANY" not in EH.available({"country":"美国","stage":4}) and "TANY" in EH.available({"country":"美国","stage":5}),"Tanya recruitment starts at stage five")
	check("BORIS" not in EH.available({"country":"苏俄","stage":4}) and "BORIS" in EH.available({"country":"苏俄","stage":5}),"Boris recruitment starts at stage five")

func expedition_hero_permit() -> void:
	MetaProgress.reset_save()
	for injured in [false,true]:
		check(Expedition.start("美国","",901) and Expedition.choose(0),"prepare hero-only roster")
		var run:Dictionary=Expedition.state.duplicate(true)
		run.stage=5
		Expedition.Heroes.recruit(run,"TANY")
		if injured:run.wounded_heroes=["TANY"]
		check(Expedition.commit(run) and Expedition.launch(0),"launch without ordinary commando license")
		check("TANY" not in Expedition.state.licenses and ("TANY" in BattleRequest.combat_context.expedition.licenses)==(not injured),"only deployable hero grants stage-local training permit")
		if injured:continue
		screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
		screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
		var runtime=screen.expedition_runtime
		check(runtime.ensure_structure("GAPILE",true) and battle.buildings.back().enqueue("TANY"),"actual barracks trains with only recruited Tanya")
		await finish()

func expedition_case(id:String) -> void:
	MetaProgress.reset_save()
	var country:="美国" if id in ["TANY","FV"] else "苏俄"
	var equipped:=id=="TANY"
	if equipped:
		MetaProgress.academy.hero_builds={id:5}
		check(A.purchase(MetaProgress,"skin",id),"equip Tanya before departure")
	else:check(not A.purchase(MetaProgress,"skin",id),"locked Boris skin cannot equip")
	check(Expedition.start(country,"",901) and Expedition.choose(0),"prepare real expedition "+id)
	# Deterministic stage-five recruitment fixture; all deployment/save paths stay native.
	var prepared:Dictionary=Expedition.state.duplicate(true)
	prepared.stage=5
	Expedition.Army.add_unit(prepared,id,1)
	check(Expedition.Army.room(prepared,id)==0,"one ordinary chrono slot "+id)
	check(preload("res://scripts/expedition/heroes.gd").recruit(prepared,id) and Expedition.commit(prepared),"recruit locked commando in expedition "+id)
	check(Expedition.launch(0),"launch real expedition with commando "+id)
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	check(screen.expedition_runtime.error.is_empty(),"expedition runtime deployment succeeds "+id,screen.expedition_runtime.error)
	var runtime=screen.expedition_runtime
	var producer_id:String=GameData.get_unit(id).built_at
	check(runtime.ensure_structure(producer_id,true),"place training barracks on legal terrain "+id)
	var factory=battle.buildings.back()
	battle.funds=100000
	if id=="TANY":check(factory.enqueue(id),"paid order queued before reinforcements "+id)
	for row:Dictionary in runtime.reinforcement_plan.duplicate():
		if str(row.get("hero",""))==id:
			runtime.tick(maxf(1,float(row.due)-runtime.reinforcement_clock+.01))
			break
	var heroes:Array=battle.units.filter(func(unit):return unit.special.get("academy_hero")==id)
	check(heroes.size()==1 and heroes[0].special.has("convoy" if id in ["FV","HARV"] else C.KEY),"exactly one recruited hero with baseline traits "+id)
	check(A.hero_build_count(MetaProgress,id)==(5 if equipped else 0),"recruiting leaves permanent hero unlock untouched "+id)
	if heroes.size()!=1:await finish();return
	check(heroes[0].display_name.begins_with("☆") and heroes[0].special.hero_skin==equipped,"hero identity independent of skin "+id)
	var ordinary=battle.units.filter(func(u):return u.unit_id==id and u.special.get("expedition_legion_member",false) and not u.special.has("academy_hero"))
	check(ordinary.size()==1,"ordinary chrono copy arrives alongside named hero "+id)
	if id=="BORIS":check(factory.enqueue(id),"paid order accepted after both arrivals "+id)
	check(runtime.ensure_structure(producer_id,true),"place second independent barracks "+id)
	var second=battle.buildings.back()
	check(not second.enqueue(id),"another barracks cannot duplicate queued order "+id)
	for step in 1800:
		if factory.production.is_empty():break
		factory._process(.1)
	var local=battle.units.filter(func(u):return u.unit_id==id and not u.special.get("expedition_legion_member",false) and u.side=="ally")
	check(local.size()==1 and not local[0].special.has("academy_hero") and not local[0].display_name.contains("☆"),"third copy is ordinary barracks product "+id,{"local":local.size(),"queue":factory.production.duplicate(),"exit_blocked":factory.exit_blocked,"limit":battle.hero_limit_reason(id,"ally",false)})
	check(not second.enqueue(id),"fourth copy rejected "+id)
	check(Expedition.collect(battle,false).filter(func(r):return r.id==id).size()==2,"only two expedition copies carry forward "+id)
	heroes[0].hp=heroes[0].max_hp*.5
	check(Expedition.checkpoint(battle),"commando expedition checkpoint persists "+id)
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"reload commando expedition from disk "+id)
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	heroes=battle.units.filter(func(unit):return unit.special.get("academy_hero")==id)
	check(heroes.size()==1 and is_equal_approx(heroes[0].hp/heroes[0].max_hp,.5),"expedition reload neither duplicates nor heals hero "+id)
	var restored=battle.units.filter(func(u):return u.unit_id==id and u.side=="ally")
	check(restored.size()==3 and heroes.size()==1 and heroes[0].special.hero_skin==equipped,"all three identities survive disk restore "+id)
	check(not battle.hero_limit_reason(id,"ally").is_empty(),"restored barracks slot still occupied "+id)
	if id=="BORIS":
		heroes[0]._die()
		check(not battle.hero_limit_reason(id,"ally").is_empty(),"named hero death does not free living barracks copy "+id)
	for u in restored:
		if not u.special.get("expedition_legion_member",false):u._die()
	check(battle.hero_limit_reason(id,"ally").is_empty(),"barracks death releases only its own slot "+id)
	await finish()
