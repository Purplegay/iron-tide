extends "res://tests/commando_hero_regression.gd"
const P=preload("res://scripts/units/peregrine.gd")
const Gifts=preload("res://scripts/rules/hero_reinforcements.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	await actual_production()
	await gift_after_reload()
	await flight_and_save()
	await eligibility_and_retry()
	await ui_and_expedition()
	await native_fire_and_flight()
	await automatic_fire()
	await expedition_runtime()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("PEREGRINE_BASE_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func boot(id:String,mode:=MatchRules.EXTENDED) -> void:
	# Combat cases exercise an unlocked profile; threshold cases explicitly seed 0..4.
	MetaProgress.academy.get_or_add("hero_builds",{}).get_or_add("ORCA",5)
	super.boot(id,mode)

func airport(owner:="ally"):
	var pad=battle._place_building("GAAIRC",owner,Vector2(1500,1300),true)
	pad._buildup_play=-1
	return pad

func queue_plane(pad) -> Array:
	var before:Array=battle.units.duplicate()
	var funds:float=battle.funds
	check(pad.enqueue("ORCA"),"real paid ORCA queue accepts")
	for i in 1800:
		if pad.production.is_empty():break
		pad._process(.1)
	var added:Array=battle.units.filter(func(u):return not before.has(u))
	check(pad.production.is_empty(),"real production completes")
	check(is_equal_approx(funds-battle.funds,battle.production_price(GameData.get_unit("ORCA"),"ally")),"only ordinary product charged",funds-battle.funds)
	return added

func get_hero():
	for unit in battle.units:
		if P.active(unit) and AlliedAbilities.alive(unit):return unit
	return null

func actual_production() -> void:
	boot("TANY")
	var pad=airport()
	var added:=queue_plane(pad)
	check(added.size()==2,"first paid aircraft retains product and grants one extra",added.size())
	var hero=get_hero()
	check(hero!=null,"unlocked profile receives first-aircraft hero")
	if hero==null:await finish();return
	var ordinary=added[0] if added[0]!=hero else added[1]
	check(not ordinary.special.has("academy_hero") and ordinary.logistics.home==pad,"paid product remains ordinary and owns its dock")
	check(hero.logistics.home==null and hero.logistics.dock_slot==-1 and battle.aircraft_population("ally")==1,"gift uses zero airport slots")
	check(hero.logistics.ammo==4 and hero.logistics.ammo_max==4 and hero.veteran_level==2,"hero starts full four rounds and full native veterancy")
	check(hero.special.hero_command_rank==0 and hero.special.hero_survival_rank==0,"both baseline traits available without purchase")
	check(not A.legacy_bonuses(hero) and A.survival_rank(hero)==-1,"hero does not inherit infantry guard or lethal protection")
	Gifts.produced(battle,pad,ordinary)
	check(battle.units.size()==added.size(),"duplicate production notification cannot grant again")
	var next:=queue_plane(pad)
	check(next.size()==1,"second production grants only ordinary aircraft")
	for i in 2:queue_plane(pad)
	check(battle.aircraft_population("ally")==4 and not pad.enqueue("ORCA"),"all four ordinary airport slots remain available beside hero")
	battle.units.erase(ordinary);ordinary.free()
	hero._die()
	next=queue_plane(pad)
	check(next.size()==1 and get_hero()==null,"death never renews per-match gift")
	await finish()
	boot("TANY")
	pad=airport();added=queue_plane(pad)
	check(get_hero()!=null and added.size()==2,"next match grants a fresh hero")
	await finish()
	boot("TANY",MatchRules.RA2)
	pad=airport();added=queue_plane(pad)
	check(added.size()==1 and get_hero()==null,"classic real production remains ordinary")
	await finish()

func setup_hero():
	boot("TANY")
	var hero=battle.spawn_unit("ORCA","ally",Vector2(1000,1000))
	P.promote(MetaProgress,battle,hero)
	return hero

func gift_after_reload() -> void:
	MetaProgress.reset_save();boot("TANY")
	var pad=airport();queue_plane(pad)
	var codec=BattleSaves.Snapshot.new()
	var snapshot:Dictionary=codec.capture(battle);codec.restore(battle,snapshot)
	pad=battle.buildings.filter(func(b):return b.building_id=="GAAIRC" and b.side=="ally")[0]
	var ordinary=battle.units.filter(func(u):return u.unit_id=="ORCA" and not P.active(u))[0]
	Gifts.produced(battle,pad,ordinary);Gifts.tick(battle,1)
	check(codec.error.is_empty() and battle.units.filter(func(u):return P.active(u)).size()==1 and battle.aircraft_population("ally")==1,"restored completed product replay preserves one gift and one occupied dock")
	get_hero()._die()
	snapshot=codec.capture(battle);codec.restore(battle,snapshot)
	pad=battle.buildings.filter(func(b):return b.building_id=="GAAIRC" and b.side=="ally")[0]
	check(codec.error.is_empty() and queue_plane(pad).size()==1 and get_hero()==null,"save after gift death and real production cannot renew hero")
	check(battle.aircraft_population("ally")==2,"restored death leaves only two ordinary occupied docks")
	await finish()

func flight_and_save() -> void:
	var hero=setup_hero()
	var target=battle.spawn_unit("HTNK","enemy",Vector2(1200,1000))
	target.hp=100000;target.max_hp=100000
	hero.set_fire_stance("none");hero.order_stop()
	var origin:Vector2=hero.position
	for i in 20:hero.logistics.tick(.1);hero.flight.process_combat(.1)
	check(hero.position==origin and hero.logistics.air_lift==1 and hero.logistics.air_state=="flying","idle and stop maintain airborne hover")
	check(not hero.logistics.request_return() and not hero.logistics.choose_home(),"manual airport return cannot reserve a dock")
	hero.logistics.consume_volley(target)
	P.tick(hero,3)
	check(hero.logistics.ammo==3 and is_equal_approx(hero.special[P.KEY].progress,.375),"partial airborne refill uses normalized eight-second progress")
	var panel:Dictionary=preload("res://scripts/ui/aircraft_ammo_indicator.gd").state(hero)
	check(panel.rearming and is_equal_approx(panel.progress,.375) and panel.status=="空中补弹 37%","ammo UI consumes real hero refill progress")
	hero.logistics.consume_volley(target)
	check(is_equal_approx(hero.special[P.KEY].progress,.375),"firing does not reset pending reload")
	P.tick(hero,5)
	check(hero.logistics.ammo==3 and hero.special[P.KEY].progress==0,"one elapsed round replenishes independently of weapon cooldown")
	hero._stun_timer=4;P.tick(hero,10)
	check(hero.logistics.ammo==3 and hero.special[P.KEY].progress==0,"stun suspends ammo progress")
	hero._stun_timer=0;hero.special.iron_left=2
	P.tick(hero,2)
	check(is_equal_approx(hero.special[P.KEY].progress,.25),"non-freezing protection does not halt reload")
	hero.special.erase("iron_left")
	P.tick(hero,6)
	check(hero.logistics.ammo==4 and hero.special[P.KEY].cycle==1,"actual incomplete-to-full transition advances one cycle")
	P.tick(hero,100)
	check(hero.special[P.KEY].cycle==1 and hero.special[P.KEY].progress==0,"full magazine cannot bank progress or duplicate cycles")
	for i in 4:hero.logistics.consume_volley(target)
	check(hero.logistics.ammo==0 and hero.special[P.KEY].empty_speed==3 and not hero.special[P.KEY].empty_ready,"empty magazine consumes one speed allowance")
	check(not hero.logistics.tick(.1) and hero.logistics.air_state=="flying" and hero.logistics.home==null,"empty hero does not auto return")
	hero.add_buff("speed",10,.15);hero._recompute_bonuses()
	check(is_equal_approx(hero.move_speed,hero._base_speed*1.35),"empty speed adds to another speed source")
	P.tick(hero,8)
	hero.logistics.consume_volley(target)
	check(not hero.special[P.KEY].has("empty_speed"),"partial one-round refill cannot rearm empty-speed allowance")
	P.tick(hero,3)
	var codec=load("res://scripts/save/battle_snapshot.gd").new()
	var snapshot:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"hero ammo state snapshot captures")
	var path:=output_dir.path_join("peregrine.snapshot")
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_var(snapshot);file.close()
	file=FileAccess.open(path,FileAccess.READ);snapshot=file.get_var();file.close()
	codec.restore(battle,snapshot)
	check(codec.error.is_empty(),"binary hero ammo state restores")
	hero=get_hero()
	check(hero!=null and hero.logistics.ammo==0 and is_equal_approx(hero.special[P.KEY].progress,.375),"restore preserves partial refill without extra ammo")
	check(hero.flight.jumpjet and hero.flight.balloon and hero.logistics.home==null and not hero.special[P.KEY].empty_ready,"restore rebuilds hover profile without renewing spent quota")
	P.tick(hero,29)
	check(hero.logistics.ammo==4 and hero.special[P.KEY].cycle==2 and hero.special[P.KEY].empty_ready,"remaining real refill opens next cycle exactly once")
	for rank in 6:
		hero.special.hero_command_rank=rank;hero.logistics.ammo=3;hero.special[P.KEY].progress=0.0
		P.tick(hero,(8-rank)-.1)
		check(hero.logistics.ammo==3,"rank timing waits for full interval "+str(rank))
		P.tick(hero,.100001)
		check(hero.logistics.ammo==4,"rank timing completes at 8/7/6/5/4/3 seconds "+str(rank))
	check(not P.entries(hero).is_empty(),"live ammo status is inspectable")
	await finish()

func eligibility_and_retry() -> void:
	boot("TANY")
	var pad=airport()
	var infantry=battle.spawn_unit("JUMPJET","ally",Vector2(1000,1000),pad)
	Gifts.produced(battle,pad,infantry)
	check(get_hero()==null,"rocket infantry does not qualify as first aircraft")
	var direct=battle.spawn_unit("ORCA","ally",Vector2(1000,1100))
	check(get_hero()==null,"direct free spawn does not invoke gift event")
	var origin:Vector2=direct.position
	var blockers:Array=[]
	for ring in [55.0,85.0,115.0]:
		for i in 12:blockers.append(battle.spawn_unit("ORCA","ally",origin+Vector2.from_angle(TAU*i/12)*ring))
	Gifts.produced(battle,pad,direct)
	check(get_hero()==null and battle.allied_state[Gifts.KEY].ally.pending,"blocked airspace retains pending gift")
	var pending_codec=load("res://scripts/save/battle_snapshot.gd").new()
	var pending:Dictionary=pending_codec.capture(battle)
	pending_codec.restore(battle,pending)
	check(pending_codec.error.is_empty() and battle.allied_state[Gifts.KEY].ally.pending and get_hero()==null,"blocked pending gift survives snapshot without early spawn")
	for blocker in battle.units.duplicate():
		if blocker.unit_id=="ORCA" and not blocker.special.has("hero_production_counted"):battle.units.erase(blocker);blocker.free()
	Gifts.tick(battle,.25)
	check(get_hero()!=null and not battle.allied_state[Gifts.KEY].ally.pending,"cleared airspace releases exactly one pending gift")
	var codec=load("res://scripts/save/battle_snapshot.gd").new()
	var snapshot:Dictionary=codec.capture(battle);codec.restore(battle,snapshot)
	check(codec.error.is_empty(),"gift ledger saves and restores")
	Gifts.tick(battle,10)
	check(battle.units.filter(func(u):return P.active(u)).size()==1,"restore cannot replay completed gift")
	pad=airport("enemy")
	var enemy=battle.spawn_unit("SCHP","enemy",Vector2(1800,1800))
	Gifts.produced(battle,pad,enemy)
	check(battle.units.filter(func(u):return P.active(u) and u.side=="enemy").is_empty(),"AI helicopter production never grants Peregrine")
	await finish()

func ui_and_expedition() -> void:
	check(A.hero_requirement("ORCA")==5,"permanent hero roster requires five aircraft")
	MetaProgress.currency.credits=100000
	check(A.purchase(MetaProgress,"firepower","ORCA"),"new hero training accepts actual purchase")
	MetaProgress.currency.cores=0
	check(not A.purchase(MetaProgress,"escort","ORCA") and not A.purchase(MetaProgress,"survival","ORCA"),"both implemented tracks require sufficient cores")
	var view=load("res://scripts/ui/hero_progression.gd").new();add_child(view)
	view.selected="ORCA";view.refresh()
	check(view.progress_label.text.contains("额外赠送") and view.escort.disabled and view.survival.disabled,"hero roster explains gift and unaffordable upgrades")
	check(view.escort_detail.text.contains("航拍落点") and view.survival_detail.text.contains("离场余速"),"baseline traits are distinct in UI")
	for i in 2:
		view.talent_demo.talent.select(i);view.talent_demo._select_talent()
		check(view.talent_demo.levels.item_count==6,"only implemented command and survival levels are previewable "+str(i))
	view.queue_free();await get_tree().process_frame
	var roster=load("res://scripts/expedition/heroes.gd")
	var run:Dictionary={"country":"美国","stage":4,"heroes":[]}
	check("ORCA" not in roster.available(run),"expedition excludes hero before stage five")
	run.stage=5
	check("ORCA" in roster.available(run) and roster.recruit(run,"ORCA"),"stage five can recruit hero without permanent production")
	check(("ORCA" in Expedition.heroes("美国"))==(A.hero_build_count(MetaProgress,"ORCA")>=A.hero_requirement("ORCA")),"opening Peregrine follows permanent unlock eligibility")

func native_fire_and_flight() -> void:
	var hero=setup_hero()
	hero.process_mode=Node.PROCESS_MODE_ALWAYS;hero.set_process(false);hero.set_physics_process(false)
	await get_tree().physics_frame
	var target=battle.spawn_unit("HTNK","enemy",hero.position+Vector2(160,0))
	target.hp=100000;target.max_hp=100000
	hero.attack_target=target;hero.attack_ordered=true;hero.hull_angle=0;hero.turret_angle=0;hero._cd_timer=0
	check(hero._try_fire_ready() and hero.logistics.ammo==3,"real native ordinary volley consumes one shared hero round")
	var shots:Array=battle.projectiles_root.get_children().filter(func(shot):return shot is Projectile and is_same(shot.shooter(),hero))
	check(shots.size()==1 and shots[0].attacker_bonus.get("peregrine_normal",false),"native projectile carries hero contact event")
	var fog=load("res://scripts/world/fog_of_war.gd").new();battle.add_child(fog);fog.setup(battle);battle.fog=fog
	var point:Vector2=target.position
	for shot in shots:shot._explode()
	check(hero.special[P.KEY].hits and target.hp<100000,"actual native impact records valid cycle combat contact")
	check(not fog.sight_until.ally.is_empty() and fog.is_visible_at("ally",point),"ordinary impact reveals actual fixed landing point")
	var leases:Dictionary=fog.sight_until.ally.duplicate(true)
	target.position+=Vector2(400,0)
	check(fog.sight_until.ally==leases,"reveal never follows the displaced target")
	hero.order_stop();hero.set_fire_stance("none")
	var from:Vector2=hero.position
	hero.order_move(from+Vector2(220,0))
	for i in Engine.physics_ticks_per_second*10:
		hero._physics_process(1.0/Engine.physics_ticks_per_second)
		if not hero.has_move_order:break
	check(hero.position.distance_to(from+Vector2(220,0))<=6 and hero.logistics.air_lift==1,"real physics reaches move order and stays airborne",hero.position)
	hero.order_stop();var stopped:Vector2=hero.position
	for i in Engine.physics_ticks_per_second:hero._physics_process(1.0/Engine.physics_ticks_per_second)
	check(hero.position.distance_to(stopped)<1 and hero.logistics.air_state=="flying","stop holds position without auto-landing")
	var pad=airport();pad._die()
	hero.logistics.ammo=3;hero.special[P.KEY].progress=0.0;P.tick(hero,8)
	check(hero.logistics.ammo==4 and AlliedAbilities.alive(hero),"destroyed airport does not stop hero airborne reload")
	var ordinary=battle.spawn_unit("ORCA","ally",Vector2(900,900))
	check(not ordinary.flight.jumpjet and ordinary.logistics.ammo_max==int(GameData.ra2_source_units.ORCA.extra.Ammo),"ordinary ORCA retains native flight and ammunition")
	ordinary.logistics.ammo=0;ordinary.logistics.tick(.01)
	check(ordinary.logistics.air_state!="flying","ordinary empty aircraft still requests airport return")
	await finish()

func automatic_fire() -> void:
	var hero=setup_hero()
	var origin:Vector2=hero.position
	var target=battle.spawn_unit("HTNK","enemy",origin+Vector2(160,0))
	target.hp=100000;target.max_hp=100000
	var reach:float=hero._weapon_for_target(target).range
	target.position=origin+Vector2(reach+32,0)
	hero.set_fire_stance("free")
	hero._refresh_target()
	check(hero.attack_target!=target,"Peregrine does not acquire an out-of-range tank in free fire",[reach,hero.attack_range,str(hero.attack_target)])
	target.position=origin+Vector2(160,0)
	for stance in ["none","return"]:
		hero.set_fire_stance(stance)
		hero._refresh_target()
		check(hero.attack_target==null,"Peregrine respects non-acquiring stance: "+stance)
	hero.order_stop()
	hero.hull_angle=0;hero.turret_angle=0;hero._think_timer=0;hero._cd_timer=0
	var rounds:int=hero.logistics.ammo
	for i in 120:
		hero._physics_process(1.0/60)
		if hero.logistics.ammo<rounds:break
	check(hero.fire_stance=="defend" and hero.attack_target==target and not hero.attack_ordered,"default defense automatically acquires a nearby enemy unit")
	check(hero.logistics.ammo==rounds-1 and hero.position.distance_to(origin)<1,"automatic ground volley consumes one round without pursuing")
	var shots:Array=battle.projectiles_root.get_children().filter(func(shot):return shot is Projectile and is_same(shot.shooter(),hero))
	check(not shots.is_empty(),"automatic fire launches a real projectile")
	for shot in shots:shot._explode()
	check(target.hp<100000,"automatic missile impact damages the enemy")
	var ordinary=battle.spawn_unit("ORCA","ally",origin+Vector2(0,20))
	ordinary._refresh_target()
	check(ordinary.attack_target==null and not ordinary.attack_ordered,"ordinary ORCA still requires a manual attack order")
	hero.order_stop()
	hero.special.hero_command_rank=2
	hero.logistics.ammo=0
	hero._think_timer=0;hero._cd_timer=0
	var air=battle.spawn_unit("ZEP","enemy",origin+Vector2(128,0))
	air.logistics.air_lift=1.0
	var air_hp:float=air.hp
	for i in 120:
		hero._physics_process(1.0/60)
		if air.hp<air_hp:break
	check(hero.attack_target==air and not hero.attack_ordered and air.hp<air_hp and hero.logistics.ammo==0,"unlocked AA gun automatically hits aircraft even with empty ground ammo")
	await finish()

func expedition_runtime() -> void:
	MetaProgress.reset_save()
	check(Expedition.start("美国","",901) and Expedition.choose(0),"prepare actual expedition for Peregrine")
	var prepared:Dictionary=Expedition.state.duplicate(true);prepared.stage=5
	check(preload("res://scripts/expedition/heroes.gd").recruit(prepared,"ORCA") and Expedition.commit(prepared),"recruit stage-five hero through roster")
	check(Expedition.launch(0),"launch expedition with Peregrine")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	check(screen.expedition_runtime.error.is_empty(),"real expedition deployment succeeds",screen.expedition_runtime.error)
	var hero=get_hero()
	check(hero!=null and hero.logistics.home==null and battle.aircraft_population("ally")==0,"expedition recruits hero without using airport slot")
	if hero==null:await finish();return
	var pad=null
	for structure in battle.buildings:
		if structure.building_id=="GAAIRC" and structure.side=="ally":pad=structure;break
	check(pad!=null,"expedition prepares required airport for recruited hero")
	if pad!=null:
		for i in 4:battle.spawn_unit("ORCA","ally",pad.position,pad)
		var extra=screen.expedition_runtime.deploy("ORCA","ORCA")
		check(extra!=null and extra.logistics.home==null,"hero deployment finds airspace even when airport docks are full")
		if extra!=null:battle.units.erase(extra);extra.free()
		hero.hp=hero.max_hp*.5;hero.logistics.ammo=2;hero.special[P.KEY].progress=.4
	check(Expedition.checkpoint(battle),"Peregrine expedition checkpoint writes")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"Peregrine checkpoint loads from disk")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
	screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	hero=get_hero()
	check(hero!=null and is_equal_approx(hero.hp/hero.max_hp,.5) and hero.logistics.ammo==2 and is_equal_approx(hero.special[P.KEY].progress,.4),"checkpoint keeps hero health/ammo/progress without duplicate grant")
	await finish()
