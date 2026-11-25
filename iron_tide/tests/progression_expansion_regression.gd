extends "res://tests/base_recovery_regression.gd"
const X=preload("res://scripts/units/progression_expansion.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const A=preload("res://scripts/rules/academy.gd")
const Counts=preload("res://scripts/world/production_counts.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	var pack:Dictionary=GameData.raw_docs["progression_expansion.json"]
	check(pack.skills.size()==18,"18 cards installed")
	for card in pack.skills:
		check(GameData.get_skill(card.id).id==card.id,"registered "+card.id)
		for rank in 4:check(not A.skill_description(card,rank).contains("{"),"rank description "+card.id+str(rank))
	for id in GameData.meta_config.unit_talents:check(GameData.meta_config.unit_talents[id].size()<=2,"maximum two talents "+id)
	MetaProgress.academy.card_shards=500*X.Contracts.cards().size()
	for id in X.Contracts.cards():check(X.Contracts.purchase(MetaProgress,id),"redeem "+id)
	check(MetaProgress.academy.card_shards==0 and not X.Contracts.purchase(MetaProgress,"MTNK"),"redemption charge and no duplicate")
	for rank in 4:await exercise(rank)
	await preload("res://tests/watch_posts_cases.gd").run(self)
	await preload("res://tests/north_twin_cases.gd").run(self)
	await preload("res://tests/mirror_fork_cases.gd").run(self)
	await preload("res://tests/dive_momentum_cases.gd").run(self)
	await preload("res://tests/lost_missile_demo_cases.gd").run(self)
	await enhanced_sonic()
	await remaining_mechanics()
	await battlefield()
	await contracts()
	var panel:=preload("res://scripts/ui/expansion_contract_panel.gd").new();add_child(panel)
	for id in X.Contracts.cards():panel.refresh(id);check(panel.visible and panel.get_child_count()==1,"contract UI "+id)
	panel.free()
	await interfaces()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	print("PROGRESSION checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func card(unit,id:String):
	var ab:=Ability.new();ab.setup(GameData.get_skill(id),R.rank(unit,id));unit.skills.append(ab)
	return ab

func exercise(rank:int) -> void:
	start(MatchRules.EXTENDED)
	for c in GameData.raw_docs["progression_expansion.json"].skills:BattleRequest.combat_context.card_ranks[c.id]=rank
	for id in GameData.raw_docs["progression_expansion.json"].unit_talents:
		for talent in GameData.raw_docs["progression_expansion.json"].unit_talents[id]:BattleRequest.combat_context.unit_talents[id]={talent:rank}
	var hero=battle.spawn_unit("E1","ally",Vector2(900,900));hero.special.academy_hero="E1";hero.passive=GameData.get_skill("ps_watch_succession")
	var ab=card(hero,"ap_watch_posts")
	check(X.cast(hero,ab,Vector2.INF),"watch cast rank "+str(rank))
	var posts:Array=R.state(hero).posts
	check(posts.size()==3 and posts[0].move_speed==0,"three fixed posts")
	var old:Vector2=hero.position;hero.position+=Vector2(800,0)
	check(X.Heroes.temporary_tick(posts[0],.1),"distance dissolves sentry")
	hero.position=old;ab.cd_left=0;X.cast(hero,ab,Vector2.INF)
	hero.hp=0;check(X.before_death(hero,null),"succession intercepts lethal")
	hero.receive_hit(99999,"shell")
	check(hero.hp==1 and R.state(hero).has("succession"),"pending succession is not damaged by further area hits")
	var selected=R.state(hero).succession.chosen
	R.dissolve(selected);X.Heroes.tick(hero,.1)
	check(R.state(hero).has("succession") and R.state(hero).succession.chosen!=selected,"dead candidate picks another")
	X.Heroes.tick(hero,2.1)
	check(not R.state(hero).has("succession") and is_equal_approx(hero.hp,hero.max_hp*R.value(hero,"ps_watch_succession","hp")),"revives at rank health")
	var north=battle.spawn_unit("MTNK","ally",Vector2(1100,1100));north.special.academy_hero="MTNK"
	var twin_ab=card(north,"ap_north_twin")
	check(X.cast(north,twin_ab,Vector2.INF),"twin summon")
	for i in 4:
		R.state(north).erase("swap_cd")
		check(X.cast(north,twin_ab,Vector2.INF),"unlimited twin swap "+str(i))
	check(twin_ab.cd_left>0 and R.state(north).has("swap_cd"),"summon and exchange independent cooldowns")
	var victim=battle.spawn_unit("MTNK","enemy",Vector2(1300,1100));victim.hp=10000;victim.max_hp=10000
	north.passive=GameData.get_skill("ps_north_echo")
	X.damaged(victim,north,10,{})
	check(R.state(north).get("echoes",[]).size()==1,"standing hit queues yesterday shot")
	X.damaged(victim,north,10,{"expansion_extra":true})
	check(R.state(north).echoes.size()==1,"echo cannot recursively record")
	var tracer=card(north,"ap_tracer_mark");X.cast(north,tracer,Vector2.INF)
	X.impact(victim,north,100,{})
	check(R.state(victim).mark.charges==3,"mark initiating hit does not consume charge")
	var amplified:=X.impact(victim,north,100,{})
	check(is_equal_approx(amplified,100*(1+R.value(north,tracer.id,"damage"))) and R.state(victim).mark.charges==2,"mark bonus and one charge")
	var htk=battle.spawn_unit("HTK","ally",Vector2(1100,1350));var bonus:={"attack_bonus":1.0}
	X.shot(htk,victim,bonus)
	check(is_equal_approx(bonus.attack_bonus,1+R.talent(htk,"empty_firepower","damage")),"empty flak damage")
	htk.logistics.passengers.append(hero);bonus={"attack_bonus":1.0};X.shot(htk,victim,bonus)
	check(bonus.attack_bonus==1.0,"occupied flak loses damage")
	htk.logistics.passengers.clear()
	var mirage=battle.spawn_unit("MGTK","ally",Vector2(1500,1300))
	R.state(mirage).heat_armed=true;X.Talents.hit(mirage,victim,false)
	for i in 3:check(is_equal_approx(X.modify_reload(mirage,10),10*(1-R.talent(mirage,"mirage_afterheat","reload"))),"afterheat reload "+str(i))
	check(is_equal_approx(X.modify_reload(mirage,10),10),"afterheat exactly three reloads")
	var sonar=battle.spawn_unit("DLPH","ally",Vector2(1500,1500))
	for i in 3:
		bonus={"attack_bonus":1.0};X.shot(sonar,victim,bonus)
		check(bonus.has("expansion_sonic")== (i==2),"third actual sonic emission "+str(i))
	var carrier=battle.spawn_unit("CARRIER","ally",Vector2(1600,1600));var plane=battle.spawn_unit("HORNET","ally",Vector2(1700,1600));plane.logistics.carrier_owner=carrier
	X.Talents.injured(plane,victim,1)
	check(R.state(plane).has("afterburn") and is_equal_approx(X.speed(plane),1+R.talent(carrier,"sortie_afterburn","speed")),"first hit afterburn speed")
	X.Cards.recover(carrier,plane)
	check(not R.state(plane).has("afterburn"),"docking clears sortie buff")
	check(not hero.buff_entries().is_empty(),"buff status text")
	var duplicate=R.state(north).twin
	X.before_death(north,victim)
	check(duplicate.is_queued_for_deletion(),"north death removes twin before original revival")
	await finish()

func contracts() -> void:
	start(MatchRules.EXTENDED)
	var north=battle.spawn_unit("MTNK","ally",Vector2(1100,1100));north.special.academy_hero="MTNK"
	north.max_hp=1000;north.hp=500;north.heal(100,north,true)
	north.max_hp=2000;north.heal(200,north,true)
	north.heal(100)
	check(is_equal_approx(X.Contracts.progress(battle,"MTNK").second,20),"skill heal normalized at time, passive excluded")
	north.hp=1950;north.heal(500,north,true)
	check(is_equal_approx(X.Contracts.progress(battle,"MTNK").second,22.5),"overheal excluded with fractional progress")
	Counts.settle(battle,false);Counts.settle(battle,false)
	check(is_equal_approx(MetaProgress.academy.hero_contracts.MTNK.second,22.5),"settlement idempotent")
	await finish()
	start(MatchRules.EXTENDED)
	north=battle.spawn_unit("MTNK","ally",Vector2(1100,1100));north.special.academy_hero="MTNK"
	north.max_hp=1000;north.hp=900;north.heal(25,north,true)
	for i in 20:
		var enemy=battle.spawn_unit("MTNK","enemy",Vector2(1300,1100));enemy.receive_hit(100000,"shell",{},north)
	Counts.settle(battle,true)
	check(MetaProgress.academy.hero_contracts.MTNK.complete,"north contract three goals complete across matches")
	check(MetaProgress.skill_unlocked("ap_north_twin") and MetaProgress.skill_unlocked("ps_north_echo"),"contract grants both independent cards")
	MetaProgress.save();MetaProgress.load_save()
	check(MetaProgress.academy.hero_contracts.MTNK.complete,"contract completion persists")
	await finish()

func battlefield() -> void:
	start(MatchRules.EXTENDED)
	BattleRequest.skirmish_config.fog_of_war=false
	var spine=battle.spawn_unit("HTNK","ally",Vector2(1100,1100));spine.special.academy_hero="HTNK";spine.passive=GameData.get_skill("ps_spine_scrap")
	var foe=battle.spawn_unit("MTNK","enemy",Vector2(1140,1100));foe.hp=10
	foe.receive_hit(10000,"shell",{},spine)
	check(X.Contracts.progress(battle,"HTNK").first==1,"actual enemy vehicle death counts")
	check(battle.allied_state.get("expansion_scraps",[]).size()==1,"death leaves scrap")
	X.Cards.world_tick(battle,.1)
	check(R.state(spine).get("scrap",[]).size()==1,"nearby scrap collected")
	var armor:float=R.state(spine).scrap[0]
	check(is_zero_approx(X.Heroes.absorb(spine,armor/2)) and is_equal_approx(R.state(spine).scrap[0],armor/2),"armor absorbs without refilling")
	var crown=card(spine,"ap_spine_crown")
	check(X.cast(spine,crown,Vector2(1150,1100)),"crown consumes scrap")
	check(R.state(spine).scrap.is_empty() and R.state(spine).crown.count==2,"one base shot plus one scrap")
	X.Heroes.tick(spine,1.1)
	check(battle.allied_state.expansion_zones.size()==1,"crown leaves field")
	var siege=battle.spawn_unit("SCHP","ally",Vector2(1300,1200));siege.set_deployed(true,false)
	var quake=card(siege,"ap_seismic_anchor")
	var victim=battle.spawn_unit("MTNK","enemy",Vector2(1350,1200));victim.max_hp=10000;victim.hp=10000
	check(X.cast(siege,quake,victim.position),"deployed siege anchor")
	var before:float=victim.hp;X.Cards.world_tick(battle,.9)
	check(victim.hp==before,"quake warning has no damage")
	X.Cards.world_tick(battle,.1)
	var initial:float=victim.hp
	check(initial<before,"quake first impact")
	for i in 10:
		before=victim.hp;X.Cards.world_tick(battle,1.0);check(victim.hp<before,"aftershock pulse "+str(i))
	before=victim.hp;X.Cards.world_tick(battle,1.0);check(victim.hp==before and X.Cards.zones(battle).is_empty(),"ten seconds of aftershocks finish and remove field")
	var zep=battle.spawn_unit("ZEP","ally",Vector2(1500,1300));var nests=card(zep,"ap_bomb_nests")
	check(X.cast(zep,nests,Vector2.INF),"airdrop cast")
	X.Cards.tick(zep,.01)
	check(battle.units.filter(func(u):return is_instance_valid(u) and u.special.get("expansion_temporary",{}).get("kind")=="nest").size()==1,"first nest immediate")
	X.Cards.tick(zep,.58)
	check(battle.units.filter(func(u):return is_instance_valid(u) and u.special.get("expansion_temporary",{}).get("kind")=="nest").size()==1,"second nest waits")
	X.Cards.tick(zep,.62)
	check(battle.units.filter(func(u):return is_instance_valid(u) and u.special.get("expansion_temporary",{}).get("kind")=="nest").size()==3,"three spaced nests")
	var prism=battle.spawn_unit("SREF","ally",Vector2(1500,1500));prism.passive=GameData.get_skill("ps_prism_recycle")
	R.state(prism).volley=1
	foe=battle.spawn_unit("MTNK","enemy",Vector2(1560,1500));foe.receive_hit(10000,"laser",{},prism)
	check(R.state(prism).get("crystals",[]).size()==1,"prism native kill gives crystal")
	var reload_time:=X.modify_reload(prism,10)
	var packet:={"attack_bonus":1.0};X.shot(prism,victim,packet)
	check(reload_time<10 and packet.attack_bonus>1,"prism reload plus extra main damage")
	var tesla=battle.spawn_unit("TTNK","ally",Vector2(1500,1700));tesla.passive=GameData.get_skill("ps_zero_arc")
	var close=battle.spawn_unit("MTNK","enemy",Vector2(1570,1700));var other=battle.spawn_unit("MTNK","enemy",Vector2(1620,1700))
	before=other.hp
	for i in 3:X.impact(close,tesla,1,{})
	check(other.hp<before,"third direct electric hit chains")
	var watcher=battle.spawn_unit("E1","ally",Vector2(800,1500));watcher.special.academy_hero="E1";watcher.passive=GameData.get_skill("ps_watch_succession")
	X.cast(watcher,card(watcher,"ap_watch_posts"),Vector2.INF);watcher.hp=0;X.before_death(watcher,null)
	var chosen=R.state(watcher).succession.chosen
	chosen.special.test_successor=true
	var codec=preload("res://scripts/save/battle_snapshot.gd").new();var snapshot:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"snapshot schema accepts all new runtime state")
	codec.restore(battle,snapshot)
	watcher=battle.units.filter(func(u):return u.special.get("academy_hero")=="E1")[0]
	check(R.state(watcher).succession.chosen.special.get("test_successor",false),"save preserves chosen successor identity")
	X.Heroes.tick(watcher,2.1)
	check(watcher.visible and not R.state(watcher).has("succession"),"loaded succession completes")
	await finish()
	await navy()

func navy() -> void:
	start(MatchRules.EXTENDED)
	BattleRequest.skirmish_config.fog_of_war=false
	battle.water_rects=[Rect2(600,600,1300,1300)];battle.path_service.set_water(battle.water_rects)
	var sub=battle.spawn_unit("SUB","ally",Vector2(1100,1100))
	var enemy=battle.spawn_unit("DLPH","enemy",Vector2(1160,1100));enemy.attack_ordered=true
	var decoy=card(sub,"ap_tidal_decoy")
	check(X.cast(sub,decoy,Vector2.INF),"tidal decoy in water")
	check(R.state(sub).has("dive") and not X.target_allowed(enemy,sub),"deep escape prevents enemy targeting")
	check(R.state(enemy).has("taunt"),"legal sonar attacker forced onto bait")
	if R.state(enemy).has("taunt"):
		var bait=R.state(enemy).taunt
		check(not X.target_allowed(enemy,sub),"taunt cannot retarget hero")
		X.damaged(bait,enemy,1,{})
		check(not R.state(enemy).has("taunt"),"each attacker released by its own hit")
	var squid=battle.spawn_unit("SQD","ally",Vector2(1500,1500));var mine_card=card(squid,"ap_ink_mine")
	check(X.cast(squid,mine_card,Vector2.INF),"underwater mine cast")
	var mines:Array=battle.units.filter(func(u):return is_instance_valid(u) and u.special.get("expansion_temporary",{}).get("kind")=="ink")
	var ship=battle.spawn_unit("DEST","enemy",Vector2(1510,1500));var health:float=ship.hp
	X.Cards.mine_tick(mines[0],.7);check(ship.hp==health,"mine cannot explode before armed")
	X.Cards.mine_tick(mines[0],.2);check(ship.hp<health and mines[0].is_queued_for_deletion(),"armed mine damages surface ship once")
	await finish()

func interfaces() -> void:
	var ui=load("res://scenes/meta.tscn").instantiate();add_child(ui)
	ui._set_page("heroes");ui.heroes.selected="MTNK"
	for i in ui.heroes.picker.item_count:
		if ui.heroes.picker.get_item_metadata(i)=="MTNK":ui.heroes.picker.select(i)
	ui.heroes.refresh()
	await get_tree().process_frame
	check(ui.heroes.expansion_contract.visible,"hero page displays north contract")
	if DisplayServer.get_name()!="headless" and OS.get_environment("IRON_TIDE_CAPTURE_SCREENSHOTS")=="1":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("north-contract.png"))
	ui._open_card_demo("ap_north_twin","MTNK")
	var gallery=ui.get_node("FactionCardDemos")
	for card in GameData.raw_docs["progression_expansion.json"].skills:
		var index:int=gallery.ids.find(card.id)
		check(index>=0,"gallery contains "+card.id)
		for rank in 4:
			gallery.select_card(index,rank)
			check(not gallery.summary.text.contains("{") and not gallery.values.text.contains("{"),"gallery rank values "+card.id+str(rank))
	gallery.select_card(gallery.ids.find("ap_north_twin"),3)
	gallery.playback.user_seek(2.5)
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless" and OS.get_environment("IRON_TIDE_CAPTURE_SCREENSHOTS")=="1":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("north-twin-demo.png"))
	ui.free()
	await get_tree().process_frame
	await tracer_preview()

func tracer_preview() -> void:
	var before:=JSON.stringify(MetaProgress.to_dict())
	var context:=BattleRequest.combat_context.duplicate(true)
	var stage_script=preload("res://scripts/ui/expansion_card_stage.gd")
	var ui=load("res://scenes/meta.tscn").instantiate();add_child(ui)
	ui._set_page("units")
	ui._unit_sel="MTNK"
	ui._rebuild_unit_detail()
	for definition in ui.exclusive_cards_by_unit.get("MTNK",[]):
		var growth=ui.unit_detail.find_child("Growth_"+str(definition.id),true,false)
		check(growth!=null and growth.get_child_count()==4,"refit builds all four growth levels without optional stat field "+str(definition.id))
	var button:Button=ui.unit_detail.find_child("Demo_ap_tracer_mark",true,false)
	check(button!=null and not button.disabled,"unowned tracer refit demo button is available")
	if button==null:ui.free();return
	button.pressed.emit()
	var gallery=ui.get_node_or_null("FactionCardDemos")
	check(gallery!=null,"actual tracer refit button opens gallery")
	if gallery==null:ui.free();return
	check(gallery.stage.card=="ap_tracer_mark" and gallery.refit_unit=="MTNK","tracer refit selects correct card and vehicle")
	for rank in 4:
		gallery.levels.item_selected.emit(rank)
		var waiting:Dictionary=stage_script.tracer_state(0.9,rank)
		var marked:Dictionary=stage_script.tracer_state(1.0,rank)
		check(not waiting.marked and marked.marked and marked.charges==3,"initial shot creates three charges without consuming one "+str(rank))
		check(is_equal_approx(marked.bonus,[5.0,7.0,9.0,12.0][rank]),"tracer preview rank bonus "+str(rank))
		for i in 3:
			gallery.playback.user_seek(2.0+i*0.8)
			var state:Dictionary=stage_script.tracer_state(gallery.stage.elapsed,rank)
			check(state.hits==i+1 and state.charges==2-i and state.marked==(i<2),"each subsequent hit consumes one tracer charge "+str(rank)+str(i))
		gallery.playback.user_seek(4.6)
		check(not stage_script.tracer_state(gallery.stage.elapsed,rank).marked,"fourth follow-up is not boosted "+str(rank))
	gallery.playback.user_seek(2.3)
	gallery.stage._process(0.5)
	check(is_equal_approx(gallery.stage.elapsed,2.3) and not gallery.stage.playing,"tracer seeking pauses the animation")
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless" and OS.get_environment("IRON_TIDE_CAPTURE_SCREENSHOTS")=="1":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir.path_join("tracer-mark-demo.png"))
	ui.free()
	await get_tree().process_frame
	check(JSON.stringify(MetaProgress.to_dict())==before and BattleRequest.combat_context==context,"tracer preview leaves progression and battle state untouched")

func remaining_mechanics() -> void:
	start(MatchRules.EXTENDED)
	var unit=battle.spawn_unit("TTNK","ally",Vector2(1000,1300))
	BattleRequest.combat_context.unit_talents.TTNK={"ground_capacitor":3}
	R.state(unit).shot_idle=3.0;X.Talents.tick(unit,2.1)
	unit.position+=Vector2(60,0);X.Talents.tick(unit,.1)
	check(R.state(unit).has("capacitor") and R.state(unit).has("capacitor_cd"),"stationary charge leaves one capacitor after moving a cell")
	var enemy=battle.spawn_unit("MTNK","enemy",Vector2(1010,1300));var health:float=enemy.hp
	X.Talents.tick(unit,.1)
	check(enemy.hp<health and not R.state(unit).has("capacitor"),"capacitor triggers once")
	var launcher=battle.spawn_unit("V3","ally",Vector2(1000,1500));BattleRequest.combat_context.unit_talents.V3={"lost_missile":3}
	launcher.special.missile_racks=[10.0]
	var missile=battle.spawn_unit("V3ROCKET","ally",Vector2(1200,1500));missile.special.flight={"source":launcher,"elapsed":5.0,"windup":1.0,"rack_slot":0}
	X.Talents.missile_destroyed(missile,enemy)
	check(is_equal_approx(launcher.special.missile_racks[0],7.5),"intercepted V3 cuts remaining reload 25 percent")
	X.Talents.missile_destroyed(missile,enemy);check(is_equal_approx(launcher.special.missile_racks[0],7.5),"same rocket cannot refund twice")
	var destroyer=battle.spawn_unit("DEST","ally",Vector2(1500,1000));BattleRequest.combat_context.unit_talents.DEST={"naval_tracking":3}
	var sub=battle.spawn_unit("SUB","enemy",Vector2(1550,1000))
	X.Talents.hit(destroyer,sub,false)
	check(R.state(destroyer).tracking.left==4,"tracking rank duration")
	var eagle=battle.spawn_unit("BEAG","ally",Vector2(1500,1300));BattleRequest.combat_context.unit_talents.BEAG={"dive_momentum":3}
	var bonus:={"attack_bonus":1.0};X.shot(eagle,enemy,bonus)
	check(R.state(eagle).has("dive_boost") and is_equal_approx(X.speed(eagle),1.25),"first bombing run gains dive speed")
	X.Talents.tick(eagle,2.1);X.shot(eagle,enemy,bonus)
	check(not R.state(eagle).has("dive_boost"),"same sortie cannot gain dive speed twice")
	var infantry=battle.spawn_unit("E1","ally",Vector2(1200,1700));infantry.passive=GameData.get_skill("ps_field_relay")
	var ally=battle.spawn_unit("E2","ally",Vector2(1210,1700));ally.receive_hit(10000,"bullet",{},enemy)
	check(R.state(infantry).has("relay_left") and X.modify_reload(infantry,10)<10,"friendly infantry death speeds next reload")
	check(is_equal_approx(X.modify_reload(infantry,10),10),"relay affects only next reload")
	var carrier=battle.spawn_unit("CARRIER","ally",Vector2(1600,1600));carrier.passive=GameData.get_skill("ps_deck_rotation")
	var first=battle.spawn_unit("HORNET","ally",Vector2(1620,1600));var second=battle.spawn_unit("HORNET","ally",Vector2(1620,1620))
	second.set_stowed(carrier);carrier.logistics.squadron=[{"unit":first,"timer":10.0},{"unit":second,"timer":10.0}]
	X.Cards.recover(carrier,first)
	check(is_equal_approx(carrier.logistics.squadron[1].timer,9.2),"deck rotation cuts other rearming timer")
	X.Cards.recover(carrier,first);check(is_equal_approx(carrier.logistics.squadron[1].timer,9.2),"deck rotation respects internal cooldown")
	eagle.passive=GameData.get_skill("ps_formation_cover");eagle.logistics.air_lift=1.0
	for i in 5:
		var neighbor=battle.spawn_unit("ORCA","ally",eagle.position+Vector2(i*15,30));neighbor.logistics.air_lift=1.0
	check(is_equal_approx(X.impact(eagle,enemy,100,{}),88),"formation cover stacks to four neighbors")
	var drone=battle.spawn_unit("DRON","ally",Vector2(1300,1700));drone.passive=GameData.get_skill("ps_drone_trip")
	for i in 3:X.impact(enemy,drone,1,{})
	check(is_equal_approx(R.state(enemy).move_lock,.3) and X.speed(enemy)==0,"third parasite pulse locks movement without silence")
	var mirage=battle.spawn_unit("MGTK","ally",Vector2(900,1700));var ab=card(mirage,"ap_mirror_fork")
	check(mirage.use_ability(mirage.skills.size()-1),"W input dispatches refractive fork")
	var mirrors:Array=battle.units.filter(func(u):return is_instance_valid(u) and u.special.get("expansion_temporary",{}).get("kind")=="mirror")
	check(mirrors.size()==2 and not mirrors[0].weapon.is_empty() and mirrors[0].has_move_order,"two moving armed mirrors")
	await finish()

func enhanced_sonic() -> void:
	start(MatchRules.EXTENDED)
	var dolphin=battle.spawn_unit("DLPH","ally",Vector2(800,1100))
	BattleRequest.combat_context.unit_talents.DLPH={"third_sonic":0}
	var before=battle.spawn_unit("DEST","enemy",Vector2(900,1100))
	var target=battle.spawn_unit("DEST","enemy",Vector2(1000,1100))
	var after=battle.spawn_unit("DEST","enemy",Vector2(1080,1100))
	var outside=battle.spawn_unit("DEST","enemy",Vector2(1300,1100))
	var friendly=battle.spawn_unit("DEST","ally",Vector2(950,1100))
	var hp:Array=[before.hp,target.hp,after.hp,outside.hp,friendly.hp]
	R.state(dolphin).sonic_count=2
	dolphin._fire_shot(target)
	var waves:Array=battle.projectiles_root.get_children().filter(func(p):return p is Projectile and p.is_sonic)
	check(waves.size()==1 and waves[0].attacker_bonus.has("expansion_sonic"),"third real shot creates enhanced wave")
	if not waves.is_empty():
		var wave=waves[0]
		wave._sonic_pulse(wave._sonic_origin+wave._heading*wave._sonic_range)
		var once:Array=[before.hp,target.hp,after.hp]
		check(before.hp<hp[0] and target.hp<hp[1] and after.hp<hp[2],"enhanced wave hits before target, target and two-cell extension")
		wave._sonic_pulse(wave._sonic_origin+wave._heading*wave._sonic_range)
		check([before.hp,target.hp,after.hp]==once,"whole enhanced wave hits every target exactly once")
		check(outside.hp==hp[3] and friendly.hp==hp[4],"wave excludes beyond extension and friendly targets")
	await finish()
	start(MatchRules.RA2)
	var academy_before:Dictionary=MetaProgress.academy.duplicate(true)
	X.Contracts.settle(MetaProgress,battle,true)
	check(MetaProgress.academy==academy_before,"classic RA2 settlement does not write expansion progress")
	await finish()
