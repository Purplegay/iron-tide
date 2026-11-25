extends "res://tests/base_recovery_regression.gd"
const Hero=preload("res://scripts/units/tank_hero.gd")
const Academy=preload("res://scripts/rules/academy.gd")

func hero(id:String,command:int,defense:int,point:Vector2):
	MetaProgress.academy.get_or_add("hero_builds",{})[id]=20
	BattleRequest.combat_context.get_or_add("hero_escort_ranks",{})[id]=command
	BattleRequest.combat_context.get_or_add("hero_survival_ranks",{})[id]=defense
	battle.allied_state.get_or_add("named_heroes",{}).erase(id)
	var unit=battle.spawn_unit(id,"ally",point)
	Academy.promote(MetaProgress,battle,id,unit)
	return unit

func world_tick() -> void:
	battle.allied_state.hero_tank_scan=0
	Hero.tick_world(battle,0.25)

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	MetaProgress.reset_save()
	var old_save:Dictionary=MetaProgress.to_dict()
	old_save.academy.hero_builds={"E1":77}
	old_save.stats.player_production={"factions":{"allied":{"unit":{"MTNK":{"built":20}}},"soviet":{"unit":{"HTNK":{"built":23}}}}}
	FileAccess.open(MetaProgress.SAVE_PATH,FileAccess.WRITE).store_string(JSON.stringify(old_save))
	MetaProgress.load_save()
	check(Academy.hero_build_count(MetaProgress,"MTNK")==20 and Academy.hero_build_count(MetaProgress,"HTNK")==23 and Academy.hero_build_count(MetaProgress,"E1")==77,"old production backfills tank heroes without altering infantry")
	MetaProgress.save();MetaProgress.load_save()
	check(Academy.hero_build_count(MetaProgress,"MTNK")==20,"production backfill is idempotent")
	MetaProgress.reset_save()
	start(MatchRules.EXTENDED)
	battle.paused=false
	get_tree().paused=false
	check(Academy.hero_requirement("MTNK")==20 and Academy.hero_requirement("HTNK")==20 and Academy.hero_requirement("E1")==50,"per hero unlock requirements")
	MetaProgress.academy.hero_builds={"MTNK":19,"HTNK":20}
	var factory=battle._place_building("GAWEAP","ally",Vector2(1400,500),true)
	world_tick()
	check(not battle.allied_state.get("named_heroes",{}).has("MTNK"),"nineteen builds do not unlock hero")
	check(not battle.allied_state.get("named_heroes",{}).has("HTNK"),"allied factory does not grant soviet hero")
	MetaProgress.academy.hero_builds.MTNK=20
	factory.under_construction=true
	world_tick()
	check(not battle.allied_state.get("named_heroes",{}).has("MTNK"),"unfinished factory does not grant hero")
	factory.under_construction=false
	world_tick()
	var gifts=battle.units.filter(func(u):return u.special.get("academy_hero")=="MTNK")
	check(gifts.size()==1 and gifts[0].veteran_level==2,"ready factory grants one elite hero")
	var count:int=battle.units.size()
	world_tick();world_tick()
	check(battle.units.size()==count and MetaProgress.academy.hero_builds.MTNK==20,"gift is not production and does not duplicate")
	factory.side="enemy"
	var field_hero=hero("MTNK",3,5,Vector2(900,1000))
	var submarine=battle.spawn_unit("SUB","enemy",field_hero.position+Vector2(80,0))
	check(NavalContact.detected(battle,"ally",submarine) and NavalContact.weapon_allows(field_hero,submarine),"hero detects and permits in-range submarine")
	check(field_hero._weapon_domain_valid(submarine),"real targeting accepts underwater enemy")
	var shot=Projectile.new()
	shot.setup(field_hero.position,submarine,field_hero._active_weapon(),50,field_hero.bonuses,"ally",field_hero)
	battle.projectiles_root.add_child(shot)
	shot.position=submarine.position
	var sub_hp:float=submarine.hp
	shot._explode()
	check(submarine.hp<sub_hp,"hero shell actually damages submarine")
	var enemy_bases=battle.buildings.filter(func(b):return b.side=="enemy" and b.is_hq)
	if not enemy_bases.is_empty():
		var isolated_fog=preload("res://scripts/world/fog_of_war.gd").new()
		battle.add_child(isolated_fog)
		isolated_fog.setup(battle)
		battle.fog=isolated_fog
		Hero.scout(field_hero,battle)
		var cell:int=battle.fog._index(enemy_bases[0].position)
		check(battle.fog.is_explored_at("ally",enemy_bases[0].position) and battle.fog.sight_until.ally.get(cell,0)>battle.fog.sight_clock,"arrival reveals enemy base temporarily")
		check(battle.fog.sight_until.ally[cell]<=battle.fog.sight_clock+5.001,"base reveal is bounded to normal scout hold")
		battle.fog=null
		isolated_fog.free()
	submarine.position+=Vector2(900,0)
	check(not NavalContact.weapon_allows(field_hero,submarine),"anti submarine weapon restricted to own range")
	var soldier=battle.spawn_unit("GGI","ally",field_hero.position+Vector2(50,0))
	var original_speed:float=soldier.move_speed
	world_tick()
	check(soldier.move_speed>=field_hero.move_speed,"nearby slower unit catches hero speed")
	soldier.set_deployed(true,false)
	var native_range:float=soldier._active_weapon().range
	world_tick()
	check(is_equal_approx(soldier._active_weapon().range,native_range+110) and soldier.move_speed==0,"deployed ally gains two cells but cannot move")
	check(not field_hero.special.has("hero_range_aura"),"hero excluded from own range aura")
	var emplacement=battle._place_building("R3REAPERTURRET","ally",field_hero.position+Vector2(130,0),true)
	var mount=preload("res://scripts/buildings/ra3_reaper_emplacement.gd").mount(emplacement)
	var old_reaper_range:float=mount._active_weapon().range
	world_tick()
	check(is_equal_approx(mount._active_weapon().range,old_reaper_range+110),"deployed Reaper building mount receives aura")
	var rule:Dictionary=preload("res://scripts/units/ra3_reaper_pose.gd").definitions.rounds.grenade
	check(preload("res://scripts/units/ra3_reaper_pose.gd").in_range(rule,float(rule.max_range)*1.5+100,float(mount.special.get("hero_range_aura",0))),"deployed Reaper individual weapon respects added reach")
	emplacement.position+=Vector2(1000,0)
	world_tick()
	check(not emplacement.special.has("hero_range_aura") and is_equal_approx(mount._active_weapon().range,old_reaper_range),"emplacement loses aura outside range")
	soldier.position+=Vector2(1000,0)
	world_tick()
	check(not soldier.special.has("hero_range_aura") and not soldier.special.has("hero_speed_floor"),"leaving range removes both bonuses")
	soldier.set_deployed(false,false)
	check(is_equal_approx(soldier.move_speed,original_speed),"original speed restored without permanent stat inflation")
	var attacker=battle.spawn_unit("DRON","enemy",Vector2(1000,1000))
	Unit.SovietWeapons.contact(attacker,field_hero)
	var hp:float=field_hero.hp
	var rock:int=field_hero.rock_events
	field_hero.receive_hit(100,"melee",{},attacker,"YR_SOV_Parasite")
	check(hp-field_hero.hp<=10.01 and field_hero.hp<hp and field_hero.rock_events==rock,"parasitized hero takes tenth damage without rolling")
	Unit.SovietWeapons.cleanse(field_hero)
	hp=field_hero.hp
	field_hero.receive_hit(999999,"crush")
	check(field_hero.hp==hp,"rank three immunity includes real crush damage")
	check(preload("res://scripts/units/ra3_apocalypse_crush.gd").target_level(field_hero)>=30,"RA3 crush eligibility respects hero immunity")
	check(is_equal_approx(Hero.defend(field_hero,100,"RadSite","radiation",null),70),"biochemical damage reduced by thirty percent")
	check(is_equal_approx(Hero.defend(field_hero,100,"YR_CAP_Virus","bullet",null),70),"virus payload shares biochemical resistance")
	field_hero.hp=field_hero.max_hp
	check(is_equal_approx(Hero.defend(field_hero,999999,"YR_SOV_TerrorBombWH","explosion",null),field_hero.max_hp*2/3),"lethal explosion cap uses maximum health")
	field_hero.hp=field_hero.max_hp*0.1
	check(Hero.defend(field_hero,999999,"YR_SOV_TerrorBombWH","explosion",null)>field_hero.hp,"low health can still die to capped explosion")
	field_hero.hp=field_hero.max_hp
	var chrono=battle.spawn_unit("CLEG","enemy",field_hero.position+Vector2(40,0))
	chrono.attack_target=field_hero
	chrono.attack_ordered=true
	AlliedAbilities.special_shot(chrono,field_hero,chrono._active_weapon())
	var normal_speed:float=field_hero.move_speed
	Hero.tick(field_hero,0.01)
	check(not AlliedAbilities.frozen(field_hero) and is_equal_approx(field_hero.move_speed,normal_speed*0.5),"temporal freeze allows movement at half speed")
	AlliedAbilities.channel(chrono,1000)
	check(not field_hero._dead and field_hero.hp>0 and float(chrono.special.get("temporal_work",0))==0,"temporal channel cannot erase protected hero")
	AlliedAbilities.release_temporal(chrono)
	Hero.tick(field_hero,0.01)
	check(is_equal_approx(field_hero.move_speed,normal_speed),"ending freeze restores normal movement")
	field_hero.special.chrono_left=10.0
	field_hero._cd_timer=2.0
	field_hero.fire_stance="none"
	field_hero._physics_process(1.0)
	check(is_equal_approx(field_hero._cd_timer,1.5),"freeze immediately halves existing reload progress")
	field_hero.special.erase("chrono_left")
	Hero.tick(field_hero,0)
	var prone=battle.spawn_unit("GGI","enemy",field_hero.position+Vector2(3,0))
	prone.set_deployed(true,false)
	field_hero.velocity=Vector2(50,0)
	field_hero._crush_cd=0
	field_hero._crush_tick(0.2)
	check(not prone._dead,"rank five respects deployed Guardian GI crush immunity")
	prone._die()
	field_hero.velocity=Vector2.ZERO
	var max_health:float=field_hero.max_hp
	field_hero.hp=0;field_hero._die()
	check(not field_hero._dead and field_hero.special.has("hero_wreck") and is_equal_approx(field_hero.max_hp,max_health*1.5),"lethal hit produces 150 percent health wreck")
	check(field_hero._active_weapon().is_empty() and field_hero.move_speed==0,"wreck has no combat or movement")
	field_hero.hp=field_hero.max_hp*0.4
	field_hero.heal(99999)
	check(is_equal_approx(field_hero.hp,field_hero.max_hp*0.4),"wreck cannot be repaired to bypass remaining-health rule")
	Hero.tick(field_hero,14.99)
	check(field_hero.special.has("hero_wreck"),"revival waits full fifteen seconds")
	Hero.tick(field_hero,0.01)
	check(not field_hero.special.has("hero_wreck") and is_equal_approx(field_hero.hp,max_health*0.45) and field_hero.special.hero_revive_used,"revival heals remaining wreck fraction and consumes one use")
	field_hero.hp=0;field_hero._die()
	check(field_hero._dead,"second death is final")
	var second=hero("HTNK",1,0,Vector2(1500,1500))
	second.hp=0;second._die()
	Hero.tick(second,4)
	second.hp=second.max_hp*0.6
	var codec=BattleSaves.Snapshot.new()
	var snapshot:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"wreck state serializes")
	codec.restore(battle,snapshot)
	second=battle.units.filter(func(u):return u.special.get("academy_hero")=="HTNK")[0]
	check(second.special.hero_wreck.left==11 and is_equal_approx(second.hp/second.max_hp,0.6),"load preserves wreck timer and health")
	second.hp=0;second._die()
	check(second._dead and not second.special.has("hero_wreck"),"destroyed wreck never revives")
	MetaProgress.currency.cores=3600 # Two heroes: 400 command + 1400 survival each.
	MetaProgress.academy.hero_escort_ranks={}
	MetaProgress.academy.hero_survival_ranks={}
	for id in Hero.IDS:
		for i in 3:check(Academy.purchase(MetaProgress,"escort",id),"tank command talent purchases level %d" % (i+1))
		check(not Academy.purchase(MetaProgress,"escort",id),"command talent capped at three")
		for i in 5:check(Academy.purchase(MetaProgress,"survival",id),"tank defense purchases level %d" % (i+1))
		check(not Academy.purchase(MetaProgress,"survival",id),"defense talent capped at five")
	await finish()
	var ui=load("res://scenes/heroes.tscn").instantiate()
	add_child(ui)
	# Hero view is embedded by the existing heroes scene; verify the control directly.
	var page=load("res://scripts/ui/hero_progression.gd").new()
	add_child(page)
	page.open_page()
	for id in Hero.IDS:
		page.selected=id;page.refresh()
		check(page.progress_label.text.contains("20") and page.escort_detail.text.contains("反潜") and page.survival_detail.text.contains("90%"),"tank hero UI includes unlock and both talent lines")
		check(page.trial.visible and page.outfit.visible and page.skin_description.text.contains("炮塔"),"tank hero exposes dedicated skin, preview and description")
		page._try_skin(true)
		check(Unit.TankHeroSkin.enabled(page.preview.actor),"tank hero preview enables its own armor")
		check(Academy.purchase(MetaProgress,"skin",id),"unlocked tank hero equips independent skin")
		MetaProgress.save();MetaProgress.load_save()
		check(MetaProgress.academy.hero_skin[id],"tank hero skin persists across reload")
		page.preview.actor.special.hero_wreck={"left":15}
		check(not Unit.TankHeroSkin.enabled(page.preview.actor),"wreck suppresses pristine hero armor and lights")
		page.preview.actor.special.erase("hero_wreck")
		var baked:Dictionary=Unit.TankHeroSkin.data.units[id]
		check(Unit.TankHeroSkin.data.facings==32 and baked.layers.size()==2 and baked.layers.all(func(layer):return layer.visible>0 and layer.clipped>0),"hero hull and turret have depth-clipped 32-direction bakes")
		page.talent_demo.talent.select(1);page.talent_demo._select_talent()
		check(page.talent_demo.levels.item_count==6,"tank defense preview includes zero through five")
	page.free();ui.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
