extends "res://tests/peregrine_command_regression.gd"
const D=preload("res://scripts/units/peregrine_defense.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await missiles()
	await healing()
	await baseline_reload_healing()
	await control()
	await defense_purchase()
	await resume_and_modes()
	await contact_boundaries()
	await expedition_defense()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("PEREGRINE_DEFENSE_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func defense_hero(rank:int,command_rank:=2):
	MetaProgress.reset_save();MetaProgress.academy.hero_survival_ranks={"ORCA":rank}
	MetaProgress.academy.hero_escort_ranks={"ORCA":command_rank}
	Pool.grant(MetaProgress,"peregrine_contract")
	MetaProgress.unlocked_skills.assign([PC.ACTIVE,PC.PASSIVE])
	Loadouts.equip(MetaProgress,"ORCA","active",PC.ACTIVE)
	Loadouts.equip(MetaProgress,"ORCA","passive",PC.PASSIVE)
	boot("TANY")
	var hero=battle.spawn_unit("ORCA","ally",Vector2(1000,1000));P.promote(MetaProgress,battle,hero)
	hero.special[P.KEY].erase("rearm_shield")
	return hero

func missile(hero):
	var enemy=victim("FV",hero.position+Vector2(240,0))
	enemy.attack_target=hero;enemy.attack_ordered=true;enemy.hull_angle=PI;enemy.turret_angle=PI;enemy.aim_dir=Vector2.LEFT
	check(enemy._try_fire_ready(),"native IFV actually fires at flying Peregrine")
	var shots:Array=battle.projectiles_root.get_children().filter(func(p):return p is Projectile and is_same(p.shooter(),enemy) and not p._detonated)
	check(shots.size()==1,"real IFV first burst emits one native projectile")
	return shots[0] if shots.size()==1 else null

func advance(shot,seconds:float) -> void:
	for i in ceili(seconds/.01):
		if not is_instance_valid(shot) or shot._detonated or shot.is_queued_for_deletion():break
		shot._physics_process(.01)

func missiles() -> void:
	var hero=defense_hero(1);var hp:float=hero.hp
	var shot=missile(hero)
	if shot==null:await finish();return
	check(shot.ra2_homing and shot.ra2_aa and shot.attack_type=="shell","native guided IFV missile retains imported shell damage type",[shot.attack_type,shot.ra2_homing,shot.ra2_aa])
	shot._physics_process(.01)
	check(hero.special[P.KEY].decoy_ready and not shot._detonated,"outside one cell preserves decoy")
	advance(shot,2)
	check(shot.splinters.get("peregrine_deflected",false) and shot._detonated and hero.hp==hp and not hero.special[P.KEY].decoy_ready,"first actual approach is diverted without damage")
	check(not D.deflect(shot,hero.position),"queued missile cannot consume another decoy")
	shot=missile(hero);advance(shot,2)
	check(not shot.splinters.get("peregrine_deflected",false) and hero.hp<hp,"next missile hits normally in same cycle")
	hero.logistics.spend_ammo(2,false);P.tick(hero,6)
	check(not hero.special[P.KEY].decoy_ready,"partial reload cannot restore decoy")
	P.tick(hero,6);check(hero.special[P.KEY].decoy_ready,"real full reload restores one decoy")
	shot=missile(hero);shot.global_position=hero.position+Vector2(70,0);shot.speed=9000;shot._physics_process(.02)
	check(shot.splinters.get("peregrine_deflected",false),"fast segment crossing one-cell radius cannot skip interception")
	for kind in ["bullet","laser","inviso","unguided","protected","friendly","grounded","rank0","wreck"]:
		hero.special[P.KEY].decoy_ready=true;hero.special.hero_survival_rank=1;hero.logistics.air_lift=1
		shot=missile(hero);shot.global_position=hero.position+Vector2(30,0)
		if kind in ["bullet","laser"]:shot.attack_type=kind
		elif kind=="inviso":shot.ra2_inviso=true
		elif kind=="unguided":shot.ra2_homing=false
		elif kind=="protected":shot.attacker_bonus.uninterceptable=true
		elif kind=="friendly":shot.owner_side=hero.side
		elif kind=="grounded":hero.logistics.air_lift=0
		elif kind=="rank0":hero.special.hero_survival_rank=0
		elif kind=="wreck":hero.special.hero_wreck={}
		check(not D.deflect(shot,hero.position) and hero.special[P.KEY].decoy_ready,"decoy excludes "+kind)
		hero.special.erase("hero_wreck");shot.queue_free()
	await finish()

func healing() -> void:
	for rank in [1,2,3]:
		var hero=defense_hero(rank);hero.hp=hero.max_hp*.5;var hp:float=hero.hp
		P.tick(hero,100)
		check(hero.hp==hp,"full idle never heals or creates a new cycle "+str(rank))
		var target=victim("HTNK",hero.position+Vector2(150,0))
		normal_shot(hero,target);P.tick(hero,5.99)
		check(hero.hp==hp,"valid hit but incomplete reload cannot heal")
		P.tick(hero,.01)
		check(is_equal_approx(hero.hp,hp+(hero.max_hp*.05 if rank>=2 else 0)),"real hit and real full heal exactly five percent only at rank two "+str(rank))
		hp=hero.hp;P.tick(hero,100)
		check(hero.hp==hp and not hero.special[P.KEY].hits,"full plateau consumes hit qualification once")
		hero.logistics.spend_ammo(1,false);P.tick(hero,6)
		check(hero.hp==hp,"empty expenditure without combat contact cannot heal")
		check(hero.use_ability(UnitSkillLayout.find(hero,PC.ACTIVE),target.position),"real W release for maintenance qualification")
		P.tick(hero,1)
		check(hero.hp==hp and not hero.special[P.KEY].hits,"W launch without actual impact cannot qualify")
		PC.world_tick(battle,3);P.tick(hero,11)
		check(is_equal_approx(hero.hp,hp+(hero.max_hp*.05 if rank>=2 else 0)),"W actual main impact qualifies one heal at full")
		hp=hero.hp
		var air=victim("ORCA",hero.position+Vector2(150,0));air.logistics.air_lift=1
		normal_shot(hero,air);hero.logistics.spend_ammo(1,false);P.tick(hero,6)
		check(hero.hp==hp and not hero.special[P.KEY].hits,"AA self-defense cannot qualify maintenance")
		await finish()
	var hero=defense_hero(2);hero.hp=hero.max_hp*.99
	normal_shot(hero,victim("HTNK",hero.position+Vector2(150,0)));P.tick(hero,6)
	check(hero.hp==hero.max_hp,"maintenance healing clamps at actual maximum")
	await finish()

func baseline_reload_healing() -> void:
	for shots in [1,2]:
		var hero=defense_hero(2,0);hero.passive={};hero.hp=hero.max_hp*.6
		var health:float=hero.hp
		var target=victim("HTNK",hero.position+Vector2(150,0))
		check(hero.logistics.ammo_max==4,"signature demo baseline uses real command-zero four-round magazine")
		normal_shot(hero,target)
		P.tick(hero,1)
		if shots==2:normal_shot(hero,target)
		P.tick(hero,6.999)
		check(hero.hp==health and hero.logistics.ammo==4-shots,"first reload waits eight seconds from expenditure")
		P.tick(hero,.001)
		if shots==2:
			check(hero.hp==health and hero.logistics.ammo==3 and hero.special[P.KEY].hits,"partial refill retains contact qualification but cannot heal")
			P.tick(hero,7.999)
			check(hero.hp==health and hero.logistics.ammo==3,"second round also requires a full eight seconds")
			P.tick(hero,.001)
		check(is_equal_approx(hero.hp,health+hero.max_hp*.05) and hero.logistics.ammo==4,"full magazine heals exactly five percent at baseline cadence")
		P.tick(hero,20)
		check(is_equal_approx(hero.hp,health+hero.max_hp*.05),"remaining full never repeats signature healing")
		await finish()

func control() -> void:
	var hero=defense_hero(3);var target=victim("HTNK",hero.position+Vector2(150,0))
	hero.stun(5,"tesla_emp")
	check(hero._stun_timer==0 and not hero.has_buff("tesla_emp") and not hero.special[P.KEY].control_ready and D.silent(hero),"real timed EMP is canceled once with two-second steady state")
	hero.attack_target=target;hero.attack_ordered=true;hero._cd_timer=0;hero.hull_angle=0;hero.turret_angle=0
	var ammo:int=hero.logistics.ammo;var hp:float=target.hp;var cd:float=ability(hero).cd_left
	check(not hero._try_fire_ready() and not hero.use_ability(UnitSkillLayout.find(hero,PC.ACTIVE),target.position),"steady state blocks ordinary and actual W entry")
	hero._fire_shot(target)
	check(hero.logistics.ammo==ammo and target.hp==hp and ability(hero).cd_left==cd,"blocked attacks have no ammo, damage or cooldown side effects")
	hero.process_mode=Node.PROCESS_MODE_ALWAYS;hero.set_process(false);hero.set_physics_process(false)
	await get_tree().physics_frame
	var origin:Vector2=hero.position;hero.order_move(origin+Vector2(100,0))
	for i in 10:hero._physics_process(1.0/Engine.physics_ticks_per_second)
	check(hero.position.distance_to(origin)>1 and D.silent(hero),"real flight movement remains available during steady state")
	hero.order_stop();P.tick(hero,2)
	check(not D.silent(hero),"steady restriction ends after duration")
	hero.stun(4)
	check(hero._stun_timer==4 and hero.has_buff("stun"),"second timed stun in same cycle applies normally")
	hero._stun_timer=0;hero.buffs.clear();hero.logistics.spend_ammo(2,false);P.tick(hero,6)
	check(not hero.special[P.KEY].control_ready,"partial refill cannot renew resistance")
	P.tick(hero,6);hero.stun(2)
	check(hero._stun_timer==0 and D.silent(hero),"next real full cycle renews one resistance")
	hero.special[P.KEY].control_ready=true;hero._stun_timer=7;hero.stun(2)
	check(hero._stun_timer==7,"resistance does not erase already active stun")
	hero._stun_timer=0;hero.special[P.KEY].control_ready=true
	hero.special.chrono_left=10
	check(AlliedAbilities.frozen(hero) and hero.special[P.KEY].control_ready,"continuous freeze remains effective without consuming timed resistance")
	hero.special.erase("chrono_left")
	for seconds in [0.,-1.,INF]:check(not D.resist(hero,seconds,"stun"),"invalid duration does not consume resistance "+str(seconds))
	check(not D.resist(hero,1,"continuous") and hero.special[P.KEY].control_ready,"non-timed control channel is excluded")
	hero.special.hero_survival_rank=2;hero.stun(1)
	check(hero._stun_timer==1,"rank two has no timed resistance")
	await finish()

func defense_purchase() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_builds={"ORCA":5}
	var page=load("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="ORCA"
	for rank in D.OPEN_RANK:
		var price:int=[40,120,240,400,600][rank]
		MetaProgress.currency.cores=price-1;page.refresh()
		check(A.hero_talent_cost("survival",rank,"ORCA")==price and page.survival.disabled and not A.purchase(MetaProgress,"survival","ORCA"),"survival actual cost and insufficient balance "+str(rank))
		MetaProgress.currency.cores=price;page.refresh()
		check(not page.survival.disabled and A.purchase(MetaProgress,"survival","ORCA"),"actual survival purchase "+str(rank))
		MetaProgress.load_save()
		check(MetaProgress.academy.hero_survival_ranks.ORCA==rank+1 and MetaProgress.balance("cores")==0,"purchased rank and debit survive disk")
	page.refresh();MetaProgress.currency.cores=10000
	check(page.survival.disabled and page.survival_detail.text.contains("抗扰飞控") and not A.purchase(MetaProgress,"survival","ORCA"),"fully trained defense cannot be purchased again")
	page.talent_demo.talent.select(1);page.talent_demo._select_talent()
	check(page.talent_demo.levels.item_count==6,"all six survival levels are previewable")
	for rank in 4:
		page.talent_demo.levels.select(rank);page.talent_demo.refresh_caption()
		check(page.talent_demo.caption.text.contains(D.DEFENSE[rank]),"distinct cumulative survival caption "+str(rank))
	page.free();boot("TANY")
	var hero=battle.spawn_unit("ORCA","ally",Vector2(1000,1000));P.promote(MetaProgress,battle,hero)
	check(D.rank(hero)==5,"new match consumes actually purchased survival rank")
	MetaProgress.academy.hero_survival_ranks.ORCA=0
	check(D.rank(hero)==5,"in-match rank stays frozen after profile edits")
	await finish()
	MetaProgress.academy.hero_survival_ranks.ORCA=2;MetaProgress.currency.cores=240;MetaProgress.save()
	var before:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)
	DirAccess.make_dir_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(not A.purchase(MetaProgress,"survival","ORCA") and MetaProgress.balance("cores")==240 and MetaProgress.academy.hero_survival_ranks.ORCA==2,"failed write rolls back survival rank and wallet")
	check(before==FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH),"failed upgrade preserves exact profile bytes")
	DirAccess.remove_absolute(MetaProgress.SAVE_PATH+".tmp")
	check(A.purchase(MetaProgress,"survival","ORCA"),"retry succeeds without duplicate debit")

func resume_and_modes() -> void:
	var hero=defense_hero(3);var shot=missile(hero);advance(shot,2)
	hero.stun(3);hero.logistics.spend_ammo(1,false)
	P.tick(hero,1)
	var codec=BattleSaves.Snapshot.new();var snap:Dictionary=codec.capture(battle)
	var f=FileAccess.open(output_dir.path_join("defense.bin"),FileAccess.WRITE);f.store_var(snap,false);f.close()
	f=FileAccess.open(output_dir.path_join("defense.bin"),FileAccess.READ);snap=f.get_var(false);f.close();codec.restore(battle,snap)
	hero=get_hero()
	check(codec.error.is_empty() and D.rank(hero)==3 and not hero.special[P.KEY].decoy_ready and not hero.special[P.KEY].control_ready and is_equal_approx(hero.special[P.KEY].steady_left,1),"binary snapshot preserves consumed quotas and remaining steady time")
	check(D.entries(hero).size()==4,"status displays decoy, contact, resistance and actual steady restriction")
	P.tick(hero,1);check(not D.silent(hero),"restored steady state expires once at remaining time")
	await finish()
	boot("TANY",MatchRules.RA2)
	hero=battle.spawn_unit("ORCA","ally",Vector2(1000,1000));P.promote(MetaProgress,battle,hero)
	check(not hero.special.has(P.KEY) and D.rank(hero)==-1,"classic ordinary aircraft never acquires survival nodes")
	hero.stun(2);check(hero._stun_timer==2,"classic timed stun remains native")
	await finish()

func contact_boundaries() -> void:
	for kind in ["harvester","temporary","neutral","invulnerable","destroyed_before_impact"]:
		var hero=defense_hero(2);hero.hp=hero.max_hp*.5;var hp:float=hero.hp
		var target=victim("HARV" if kind=="harvester" else "HTNK",hero.position+Vector2(150,0))
		if kind=="temporary":target.special.expansion_temporary={"kind":"test"}
		elif kind=="neutral":target.side="neutral"
		elif kind=="invulnerable":target.special.iron_left=10.0
		hero.attack_target=target;hero._cd_timer=0;hero._burst_left=0;hero.hull_angle=0;hero.turret_angle=0;hero.attack_ordered=true
		# Fire through the real primitive for invalid enemy selections too, as
		# force-fire can hit neutral objects without qualifying hero contracts.
		hero.logistics.spend_ammo(1,true,target);hero._fire_shot(target)
		if kind=="destroyed_before_impact":target._die()
		for shot in battle.projectiles_root.get_children():
			if shot is Projectile and is_same(shot.shooter(),hero) and not shot._detonated:shot._explode()
		P.tick(hero,6)
		check(hero.hp==hp and not hero.special[P.KEY].hits,"maintenance excludes contact with "+kind)
		await finish()
	var hero=defense_hero(2);hero.passive={};hero.hp=hero.max_hp*.5
	var hp:float=hero.hp;normal_shot(hero,victim("HTNK",hero.position+Vector2(150,0)))
	P.tick(hero,3)
	var codec=BattleSaves.Snapshot.new();var snap:Dictionary=codec.capture(battle);codec.restore(battle,snap)
	hero=get_hero();P.tick(hero,3)
	check(codec.error.is_empty() and is_equal_approx(hero.hp,hp+hero.max_hp*.05),"saved hit qualification heals at remaining reload without requiring passive card")
	check(not hero.special[P.KEY].hits,"restored heal consumes cycle qualification")
	await finish()

func expedition_defense() -> void:
	MetaProgress.reset_save();MetaProgress.academy.hero_survival_ranks={"ORCA":3}
	check(Expedition.start("美国","",904) and Expedition.choose(0),"start expedition with trained defense")
	var prepared:Dictionary=Expedition.state.duplicate(true);prepared.stage=5
	check(preload("res://scripts/expedition/heroes.gd").recruit(prepared,"ORCA") and Expedition.commit(prepared) and Expedition.launch(0),"actual expedition recruits defense-trained Peregrine")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
	var hero=get_hero()
	check(hero!=null and D.rank(hero)==3,"expedition uses actual purchased defense rank")
	if hero==null:await finish();return
	hero.stun(4);P.tick(hero,.5)
	check(Expedition.checkpoint(battle),"defense state checkpoint writes")
	await finish()
	check(Expedition.load_run() and Expedition.prepare_battle(),"defense checkpoint reloads")
	screen=load("res://scenes/battle.tscn").instantiate();add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle;hero=get_hero()
	check(hero!=null and D.rank(hero)==3 and not hero.special[P.KEY].control_ready and is_equal_approx(hero.special[P.KEY].steady_left,1.5),"expedition restore retains resistance quota and steady time")
	await finish()
