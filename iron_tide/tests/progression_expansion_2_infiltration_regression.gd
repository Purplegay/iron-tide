extends "res://tests/progression_expansion_2_naval_regression.gd"
const Infiltration=preload("res://scripts/units/expansion_2_infiltration.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for level in 4:
		await shore(level)
		for id in ["GHOST","TANY","BORIS"]:await escort(level,id)
	await cloak_interruptions()
	await escort_boundaries()
	await infiltration_save()
	await incoming_missile()
	await hero_equipment()
	await classic_infiltration()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_INFILTRATION_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func prepare_infiltration(level:int,shore_card:=true) -> void:
	setup(level)
	for id in [Infiltration.SHORE,Infiltration.ESCORT]:BattleRequest.combat_context.card_ranks[id]=level
	for id in ["GHOST","TANY","BORIS"]:BattleRequest.combat_context.loadouts[id]={"active":[],"passive":Infiltration.SHORE if id=="GHOST" and shore_card else Infiltration.ESCORT}
	battle.water_rects=[Rect2(900,900,300,500)];battle.path_service.set_water(battle.water_rects)

func swim(unit,dt:float) -> void:
	unit.position+=Vector2(10*dt,0);battle.neighborhood.relocate(unit);X.tick(unit,dt)

func land(unit) -> void:
	unit.position=Vector2(1210,1100);battle.neighborhood.relocate(unit);X.tick(unit,.01)

func ready_shore(unit) -> void:
	unit.position=Vector2(1100,1100);X.tick(unit,0);swim(unit,2);land(unit)

func shore(level:int) -> void:
	prepare_infiltration(level)
	var unit:=make("GHOST","ally",Vector2(1100,1100));var speed:float=unit.move_speed
	X.tick(unit,0);unit.has_move_order=true;unit.move_target=Vector2(1190,1100);unit.hull_angle+=.5;X.tick(unit,3)
	check(not Infiltration.state(unit).get("shore_ready",false),"orders and turning alone do not charge shore "+str(level))
	swim(unit,1.99);check(not Infiltration.state(unit).get("shore_ready",false),"requires full two seconds of actual swimming")
	swim(unit,.01);check(Infiltration.state(unit).get("shore_ready",false),"continuous actual swimming arms shore")
	X.tick(unit,1);check(Infiltration.state(unit).get("shore_ready",false),"completed preparation remains available until landing")
	land(unit)
	check(Infiltration.hidden(unit) and is_equal_approx(unit.move_speed,speed*1.2),"landing grants native movement bonus and cloak")
	check(Infiltration.state(unit).shore_speed==[2,2.5,3,3.5][level] and Infiltration.state(unit).shore_cloak==[1,1.5,2,2.5][level],"independent rank speed and cloak durations")
	check(not battle.actor_visible_to("enemy",unit) and AlliedAbilities.concealed(unit,"enemy") and battle.actor_visible_to("ally",unit),"world visibility and target concealment agree while owner still sees unit")
	check(is_equal_approx(preload("res://scripts/units/ra3_cloak_visual.gd").opacity(unit),.32),"shared unit renderer applies translucent owner presentation")
	X.tick(unit,float([1,1.5,2,2.5][level]))
	check(not Infiltration.hidden(unit) and is_equal_approx(unit.move_speed,speed*1.2),"cloak expires independently while speed remains")
	X.tick(unit,1)
	check(is_equal_approx(unit.move_speed,speed) and not Infiltration.state(unit).has("shore_speed"),"speed returns exactly to original after its own duration")
	await finish()

func cloak_interruptions() -> void:
	for mode in ["fire","c4","load","damage","detect","hop","capture","stunned_landing"]:
		prepare_infiltration(3)
		var unit:=make("GHOST","ally",Vector2(1100,1100));ready_shore(unit)
		var before:float=Infiltration.state(unit).shore_speed
		match mode:
			"fire":
				var enemy:=make("E2","enemy",Vector2(1280,1100))
				check(normal_shot(unit,enemy),"native MP5 fires while cloaked")
			"c4":
				var building=battle._place_building("GAPOWR","enemy",Vector2(1450,1100),true)
				unit.position=AlliedAbilities.approach(unit,building);unit.has_move_order=false
				check(CommandoCombat.begin_c4(unit,building),"real C4 approach starts")
				for body in screen.find_children("*","CollisionObject2D",true,false):body.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
				CommandoCombat.tick_c4(unit,0)
				check(unit.special.get("c4_stage","")=="enter","native C4 reaches installation entry")
			"load":
				var carrier:=make("FV","ally",Vector2(1260,1100));unit.set_stowed(carrier)
			"damage":
				var enemy:=make("MTNK","enemy",Vector2(1300,1100));var hp:float=unit.hp
				unit.receive_hit(10,"shell",{"expansion_extra":true},enemy)
				check(unit.hp==hp-10 and Infiltration.hidden(unit),"AoE-like incoming damage still lands without unrequested damage break")
			"detect":
				make("DOG","enemy",Vector2(1250,1100))
				check(battle.actor_visible_to("enemy",unit) and not AlliedAbilities.concealed(unit,"enemy") and Infiltration.hidden(unit),"native detector exposes without consuming cloak")
			"hop":
				unit.position=Vector2(1100,1100);X.tick(unit,.1);swim(unit,2);land(unit)
				check(float(Infiltration.state(unit).get("shore_cloak",0))<.4 and not Infiltration.state(unit).get("shore_ready",false),"water hops during existing cloak cannot renew or precharge next cloak")
			"capture":unit.side="enemy";X.tick(unit,.01)
			"stunned_landing":
				Infiltration.attacking(unit);unit.position=Vector2(1100,1100);X.tick(unit,0);swim(unit,2);unit._stun_timer=1;land(unit)
				check(Infiltration.hidden(unit) and not Infiltration.state(unit).has("shore_ready"),"completed water preparation grants once on landing even if stunned")
		if mode in ["fire","c4","load"]:
			check(not Infiltration.hidden(unit) and Infiltration.state(unit).shore_speed==before,"actual action breaks cloak but preserves speed "+mode)
		if mode=="capture":check(not unit.special.has(Infiltration.KEY),"ownership change clears previous shore state")
		await finish()

func escort(level:int,id:String) -> void:
	prepare_infiltration(level,false)
	var unit:=make(id,"ally",Vector2(1400,1100));unit.max_hp=1000;unit.hp=500
	var first:=make("E1","ally",Vector2(1440,1100));var second:=make("E2","ally",Vector2(1460,1100));var third:=make("GGI","ally",Vector2(1480,1100))
	var enemy:=make("MTNK","enemy",Vector2(1600,1100))
	var speed:float=first.move_speed;var own_speed:float=unit.move_speed
	first.has_move_order=true;first.move_target=Vector2(1700,1100)
	unit.receive_hit(100,"shell",{},enemy)
	check(Infiltration.escort_speed(first)==0 and unit.hp==400,"exact forty percent does not trigger "+id+str(level))
	unit.receive_hit(1,"shell",{},enemy)
	var value:float=[.15,.2,.25,.3][level]
	check(is_equal_approx(Infiltration.escort_speed(first),value) and is_equal_approx(Infiltration.escort_speed(second),value) and Infiltration.escort_speed(third)==0,"only nearest two eligible allies receive rank escort")
	check(is_equal_approx(first.move_speed,speed*(1+value)) and unit.move_speed==own_speed,"real recipient speed changes without boosting caster")
	check(first.has_move_order and first.move_target==Vector2(1700,1100) and not second.has_move_order,"escort preserves existing orders and never forces movement")
	unit.receive_hit(1,"shell",{},enemy)
	check(Infiltration.state(first).escort_buffs.size()==1,"continued low-health hits cannot retrigger")
	first.position+=Vector2(300,0);X.tick(first,1.99)
	check(Infiltration.escort_speed(first)>0,"chosen ally retains two-second buff after leaving radius")
	X.tick(first,.01);check(Infiltration.escort_speed(first)==0 and is_equal_approx(first.move_speed,speed),"exact two-second expiry restores recipient speed")
	unit.hp=400;unit.receive_hit(1,"shell",{},enemy)
	check(Infiltration.escort_speed(third)==0,"healed threshold crossing inside cooldown cannot grant another escort")
	X.tick(unit,25);unit.receive_hit(1,"shell",{},enemy)
	check(Infiltration.escort_speed(third)==0,"cooldown expiry alone does not rearm continuously low-health caster")
	unit.hp=400;unit.receive_hit(1,"shell",{},enemy)
	check(Infiltration.escort_speed(third)>0,"healing to exact forty percent permits a new crossing after cooldown")
	await finish()

func escort_boundaries() -> void:
	prepare_infiltration(3,false)
	var unit:=make("GHOST","ally",Vector2(1400,1100));unit.max_hp=1000;unit.hp=500
	var hero:=make("E1","ally",Vector2(1410,1100));hero.special.academy_hero="E1"
	var native:=make("TANY","ally",Vector2(1420,1100))
	var mirror:=make("E2","ally",Vector2(1430,1100));mirror.special.expansion_temporary={"kind":"mirror"}
	var far:=make("E2","ally",Vector2(1511,1100));var enemy:=make("E2","enemy",Vector2(1440,1100))
	var loaded:=make("GGI","ally",Vector2(1440,1100));loaded.set_stowed(make("FV","ally",Vector2(1450,1100)))
	unit.receive_hit(101,"shell",{},enemy)
	for other in [hero,native,mirror,far,enemy,loaded]:check(Infiltration.escort_speed(other)==0,"hero temporary out-of-range enemy and embarked recipients excluded "+other.unit_id)
	check(Infiltration.state(unit).escort_cd==25,"empty recipient set still consumes threshold event")
	await finish()
	prepare_infiltration(3,false)
	unit=make("GHOST","ally",Vector2(1400,1100));unit.max_hp=1000;unit.hp=500
	var ally:=make("E1","ally",Vector2(1440,1100));enemy=make("E2","enemy",Vector2(1500,1100))
	unit.receive_hit(500,"shell",{},enemy)
	check(Infiltration.escort_speed(ally)==0,"fatal damage does not grant survival escort")
	await finish()

func infiltration_save() -> void:
	prepare_infiltration(3)
	var unit:=make("GHOST","ally",Vector2(1100,1100));X.tick(unit,0);swim(unit,1)
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot);unit=battle.units[0]
	check(Infiltration.state(unit).shore_age==1,"water preparation survives snapshot")
	swim(unit,1);land(unit);X.tick(unit,.5)
	snapshot=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot);unit=battle.units[0]
	check(Infiltration.hidden(unit) and Infiltration.state(unit).shore_cloak==2 and Infiltration.state(unit).shore_speed==3,"independent shore timers survive snapshot")
	await finish()
	prepare_infiltration(3,false)
	unit=make("GHOST","ally",Vector2(1400,1100));unit.max_hp=1000;unit.hp=500
	var ally:=make("E1","ally",Vector2(1440,1100));var enemy:=make("E2","enemy",Vector2(1500,1100))
	unit.receive_hit(101,"shell",{},enemy);X.tick(ally,1);X.tick(unit,1)
	# A weaker later source grants its own duration; it cannot extend the stronger value.
	BattleRequest.combat_context.card_ranks[Infiltration.ESCORT]=0
	var other:=make("BORIS","ally",Vector2(1400,1140));other.max_hp=1000;other.hp=500;other.receive_hit(101,"shell",{},enemy)
	check(is_equal_approx(Infiltration.escort_speed(ally),.3),"different ranks do not add or overwrite stronger escort")
	snapshot=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	unit=battle.units.filter(func(u):return u.unit_id=="GHOST")[0];ally=battle.units.filter(func(u):return u.unit_id=="E1")[0]
	check(Infiltration.state(unit).escort_cd==24 and Infiltration.state(ally).escort_buffs.size()==2,"cooldown and overlapping independent buff timers restore")
	X.tick(ally,1);check(is_equal_approx(Infiltration.escort_speed(ally),.15),"strong buff expires leaving younger weak buff")
	ally.side="enemy";X.tick(ally,.1);check(Infiltration.escort_speed(ally)==0,"capture removes recipient speed buff")
	await finish()

func classic_infiltration() -> void:
	start(MatchRules.RA2);battle.fog=null
	var unit:=make("GHOST","ally",Vector2(1100,1100));unit.passive=GameData.get_skill(Infiltration.SHORE)
	Infiltration.state(unit).shore_cloak=2
	check(not Infiltration.hidden(unit),"classic mode rejects forced expansion cloak")
	unit.passive=GameData.get_skill(Infiltration.ESCORT);unit.max_hp=1000;unit.hp=500
	var ally:=make("E1","ally",Vector2(1140,1100));var enemy:=make("E2","enemy",Vector2(1200,1100));unit.receive_hit(101,"shell",{},enemy)
	check(Infiltration.escort_speed(ally)==0,"classic mode rejects forced escort card")
	await finish()

func incoming_missile() -> void:
	prepare_infiltration(3)
	var unit:=make("GHOST","ally",Vector2(1100,1100));X.tick(unit,0);swim(unit,2)
	var attacker:=make("GGI","enemy",Vector2(1300,1100));attacker.set_deployed(true,false)
	check(normal_shot(attacker,unit) and not missiles(attacker).is_empty(),"real ground missile launches before shore concealment")
	land(unit);check(not battle.actor_visible_to("enemy",unit),"target becomes concealed with existing missile still in flight")
	var before:float=unit.hp;fly_missiles(attacker)
	check(unit.hp<before and Infiltration.hidden(unit),"already launched native missile can hit without cloak damage immunity")
	await finish()

func hero_equipment() -> void:
	const Loadouts=preload("res://scripts/rules/hero_loadouts.gd")
	const Academy=preload("res://scripts/rules/academy.gd")
	for id in ["TANY","BORIS"]:
		MetaProgress.reset_save();MetaProgress.academy.hero_builds={id:5}
		MetaProgress.academy.hero_survival_ranks={id:5 if id=="TANY" else 0}
		check(MetaProgress.unlock_skill(Infiltration.ESCORT) and Loadouts.equip(MetaProgress,id,"passive",Infiltration.ESCORT),"real separate hero loadout accepts owned ordinary escort "+id)
		MetaProgress.load_save()
		check(Loadouts.effective(MetaProgress,id).passive==Infiltration.ESCORT,"hero passive selection persists on disk "+id)
		prepare_infiltration(3,false)
		var hero:=make(id,"ally",Vector2(1400,1100));Academy.promote(MetaProgress,battle,id,hero)
		check(hero.special.get("academy_hero")==id and hero.passive.get("id")==Infiltration.ESCORT,"real promotion installs ordinary passive alongside hero talents "+id)
		hero.max_hp=1000;hero._base_max_hp=1000;hero.hp=500
		var ally:=make("E1","ally",Vector2(1440,1100));var enemy:=make("HTNK","enemy",Vector2(1600,1100))
		hero.receive_hit(5000 if id=="TANY" else 300,"shell",{},enemy)
		check(hero.hp>0 and hero.hp<400 and Infiltration.escort_speed(ally)>0,"hero surviving actual threshold hit grants escort "+id,[hero.hp,Infiltration.escort_speed(ally)])
		if id=="TANY":check(hero.special.commando_hero_v2.get("last_used",false) and hero.hp==1,"escort observes final damage after real level-five death prevention")
		await finish()
