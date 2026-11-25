extends "res://tests/progression_expansion_2_naval_regression.gd"
const Sub=preload("res://scripts/units/expansion_2_submarine.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for level in 4:
		await pressure(level)
		await pressure_boundaries(level)
		await fork(level)
		await fork_radius(level)
	await short_and_land()
	await boundaries_sub()
	await flight_save()
	await shield_and_visibility()
	await purchase()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_SUBMARINE_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func prepare(level:int) -> void:
	setup(level)
	BattleRequest.combat_context.card_ranks[Sub.SHIELD]=level
	BattleRequest.combat_context.unit_talents.SUB={Sub.FORK:level}
	BattleRequest.combat_context.loadouts.SUB={"active":[],"passive":Sub.SHIELD}
	battle.water_rects=[Rect2(900,900,1300,800)];battle.path_service.water_rects=battle.water_rects
	battle._refresh_pathing()

func advance(projectile,limit:=1200) -> void:
	for i in limit:
		if projectile.is_queued_for_deletion():return
		projectile._physics_process(1.0/60.0)
	check(projectile.is_queued_for_deletion(),"native torpedo flight terminates")

func forks() -> Array:
	return battle.projectiles_root.get_children().filter(func(p):return p is Projectile and p.splinters.has("expansion_fork") and not p.is_queued_for_deletion())

func pressure(level:int) -> void:
	prepare(level)
	var sub:=make("SUB","ally",Vector2(1100,1200));var enemy:=make("DEST","enemy",Vector2(1300,1200))
	sub.max_hp=1000;sub.hp=1000;sub._base_max_hp=1000
	var amount:float=1000*[.05,.07,.09,.12][level]
	var sight:float=sub.sight;var range:float=sub.attack_range
	var submerged:=NavalContact.submerged(sub)
	X.tick(sub,3.99);check(not Sub.state(sub).has("pressure_shield"),"pressure waits four seconds "+str(level))
	X.tick(sub,.01)
	check(Sub.state(sub).pressure_shield.hp==amount and Sub.state(sub).pressure_shield.left==15 and Sub.state(sub).pressure_cd==20,"four rank shield maximum and fifteen-second lifetime")
	check(NavalContact.submerged(sub)==submerged and sub.sight==sight and sub.attack_range==range,"shield does not change submergence or grant sight and range")
	check(normal_shot(sub,enemy),"normal torpedo fires through active shield")
	check(Sub.state(sub).pressure_shield.hp==amount and Sub.state(sub).pressure_shield.left==15 and Sub.state(sub).pressure_idle==0,"fire keeps shield without refreshing lifetime and restarts idle")
	check(not NavalContact.submerged(sub),"normal native firing still surfaces submarine")
	sub.receive_hit(amount*.5,"torpedo",{},enemy)
	check(sub.hp==1000 and is_equal_approx(Sub.state(sub).pressure_shield.hp,amount*.5),"real incoming hit consumes shield before health")
	X.tick(sub,2)
	check(normal_shot(sub,enemy) and Sub.state(sub).pressure_shield.left==13,"later actual firing does not refresh existing shield lifetime")
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	for unit in battle.units:
		if unit.side=="ally":sub=unit
		else:enemy=unit
	check(is_equal_approx(Sub.state(sub).pressure_shield.hp,amount*.5) and Sub.state(sub).pressure_shield.left==13 and Sub.state(sub).pressure_cd==18,"snapshot preserves partial shield remaining time and cooldown")
	X.tick(sub,12.99);check(Sub.state(sub).has("pressure_shield"),"pressure exists just before expiry")
	X.tick(sub,.01);check(not Sub.state(sub).has("pressure_shield"),"pressure expires fifteen seconds after grant")
	var hp:float=sub.hp;sub.receive_hit(10,"torpedo",{},enemy);check(sub.hp==hp-10,"damage reaches health after shield expiry")
	X.tick(sub,4.99);check(not Sub.state(sub).has("pressure_shield"),"cooldown blocks continuous idle regeneration")
	X.tick(sub,.02);check(Sub.state(sub).get("pressure_shield",{}).get("hp",0)==amount,"new shield only after twenty-second trigger interval")
	sub.side="enemy";X.tick(sub,.01);check(not sub.special.has(Sub.KEY),"capture removes prior owner's shield")
	await finish()

func fork(level:int) -> void:
	prepare(level)
	var sub:=make("SUB","ally",Vector2(1100,1200));var primary:=make("DEST","enemy",Vector2(1430,1200));var secondary:=make("HYD","enemy",Vector2(1520,1200))
	var farther:=make("DEST","enemy",Vector2(1430,1100))
	check(normal_shot(sub,primary),"real native main torpedo "+str(level))
	var parent=missiles(sub)[0];var original:float=parent.base_damage
	advance(parent)
	var children:=forks()
	check(float(parent.splinters[Sub.FLIGHT].distance)>=110 and parent.splinters[Sub.FLIGHT].used,"actual water travel qualifies once")
	check(children.size()==1,"one supplementary native torpedo generated")
	if not children.is_empty():
		var child=children[0]
		check(child.target==secondary and child.global_position==primary.position,"fork begins at impact and chooses nearest other vessel")
		check(is_equal_approx(child.base_damage,original*[.3,.4,.5,.6][level]) and child.ra2_image=="SUBT" and child.ra2_homing,"fork inherits native torpedo and rank attack fraction")
		check(child.attacker_bonus.expansion_extra and not child.attacker_bonus.has(Sub.FLIGHT),"child cannot reenter normal hit counting or fork path")
		check(is_equal_approx(child.splinters.expansion_fork.range,[2,2.5,3,3.5][level]*55),"rank secondary tracking radius")
		Sub.finish(parent);check(forks().size()==1,"repeat finish cannot generate twice")
		var before:float=secondary.hp;advance(child)
		check(secondary.hp<before and forks().is_empty(),"real secondary torpedo hits and cannot recursively split")
	check(sub.attack_target==primary and sub._cd_timer>0 and farther.hp==100000,"fork preserves launcher target reload and other vessel")
	await finish()

func short_and_land() -> void:
	for water in [true,false]:
		prepare(3)
		var sub:=make("SUB","ally",Vector2(1100,1200))
		var primary:=make("DEST","enemy",Vector2(1190 if water else 1430,1200));make("HYD","enemy",primary.position+Vector2(90,0))
		if not water:battle.path_service.water_rects=[Rect2(1100,1100,75,300)]
		check(normal_shot(sub,primary),"native near or partial-water shot")
		var parent=missiles(sub)[0];advance(parent)
		check(float(parent.splinters[Sub.FLIGHT].distance)<110 and forks().is_empty(),"short actual water distance cannot fork "+str(water),parent.splinters[Sub.FLIGHT])
		await finish()

func boundaries_sub() -> void:
	prepare(0)
	var sub:=make("SUB","ally",Vector2(1100,1200));var primary:=make("DEST","enemy",Vector2(1430,1200));var secondary:=make("HYD","enemy",Vector2(1520,1200))
	check(normal_shot(sub,primary),"launch before moving shooter")
	var parent=missiles(sub)[0]
	sub.position+=Vector2(200,100);Sub.travel(parent)
	check(parent.splinters[Sub.FLIGHT].distance==0,"moving launcher never adds torpedo distance")
	var land:=make("HTNK","enemy",Vector2(1470,1200));var air:=make("JUMPJET","enemy",Vector2(1470,1200));var friend:=make("HYD","ally",Vector2(1470,1200))
	for target in [land,air,friend]:check(not Sub.target_allowed(parent,target),"fork excludes target domain or friendly "+target.unit_id)
	var hidden:=make("SUB","enemy",Vector2(1525,1200));hidden.special.erase("dive_remaining")
	check(Sub.target_allowed(parent,hidden),"native sub sonar allows nearby submerged enemy")
	sub.position=Vector2(950,1000)
	check(not Sub.target_allowed(parent,hidden),"submerged enemy outside actual sonar coverage remains hidden")
	primary.hp=0;advance(parent);check(forks().is_empty(),"main target dead before contact cannot fork")
	await finish()
	prepare(3)
	sub=make("SUB","ally",Vector2(1100,1200));primary=make("DEST","enemy",Vector2(1430,1200));secondary=make("HYD","enemy",Vector2(1520,1200))
	normal_shot(sub,primary);parent=missiles(sub)[0];sub.free();battle.units.erase(sub)
	advance(parent)
	check(forks().size()==1,"fired torpedo retains attack snapshot after launcher removal")
	if not forks().is_empty():
		var child=forks()[0];secondary.position+=Vector2(400,0);Sub.travel(child)
		check(child.target==null and child.splinters.expansion_fork.lost,"secondary leaving impact-centered range loses lock")
		secondary.position=Vector2(1520,1200);Sub.travel(child)
		check(child.target==null,"lost child cannot reacquire after target returns")
	await finish()
	start(MatchRules.RA2);battle.fog=null
	sub=make("SUB","ally",Vector2(1100,1200));sub.passive=GameData.get_skill(Sub.SHIELD);X.tick(sub,4)
	check(not sub.special.has(Sub.KEY),"classic mode does not grant pressure shield")
	await finish()

func flight_save() -> void:
	prepare(3)
	var sub:=make("SUB","ally",Vector2(1100,1200));var primary:=make("DEST","enemy",Vector2(1430,1200));var secondary:=make("HYD","enemy",Vector2(1520,1200))
	normal_shot(sub,primary);var parent=missiles(sub)[0]
	for step in 12:parent._physics_process(1.0/60.0)
	var distance:float=parent.splinters[Sub.FLIGHT].distance
	var position_before:Vector2=parent.position;var prior:Vector2=parent.splinters[Sub.FLIGHT].previous
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	for unit in battle.units:
		if unit.unit_id=="SUB":sub=unit
		elif unit.unit_id=="DEST":primary=unit
		else:secondary=unit
	parent=missiles(sub)[0]
	check(parent.splinters[Sub.FLIGHT].distance==distance and parent.position==position_before and parent.splinters[Sub.FLIGHT].previous==prior,"snapshot preserves actual cumulative and previous torpedo coordinates")
	Sub.travel(parent);var after:float=parent.splinters[Sub.FLIGHT].distance
	Sub.travel(parent);check(parent.splinters[Sub.FLIGHT].distance==after and is_equal_approx(after-distance,prior.distance_to(position_before)),"restore accounts pending actual displacement once without adding save displacement")
	advance(parent);check(forks().size()==1,"restored main torpedo generates one fork")
	if not forks().is_empty():
		var child=forks()[0];child._physics_process(1.0/60.0)
		snapshot=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
		check(forks().size()==1 and forks()[0].attacker_bonus.expansion_extra and not forks()[0].splinters.has(Sub.FLIGHT),"saved fork retains secondary identity and cannot fork anew")
		child=forks()[0];advance(child);check(forks().is_empty(),"restored secondary terminates without grandchildren")
	await finish()

func purchase() -> void:
	MetaProgress.currency.cores=100000
	var offer:=MetaProgress.talent_unlock_quote("SUB",Sub.FORK)
	check(MetaProgress.unlock_unit_talent("SUB",Sub.FORK,offer.get("cost",-1)),"real submarine talent unlock")
	for rank in 3:check(MetaProgress.upgrade_talent("SUB",Sub.FORK,rank),"real submarine talent upgrade "+str(rank))
	MetaProgress.load_save();check(MetaProgress.talent_rank("SUB",Sub.FORK,MetaProgress.unit_talents)==3,"submarine rank persists on disk")

func fork_radius(level:int) -> void:
	prepare(level)
	var sub:=make("SUB","ally",Vector2(1100,1200));var primary:=make("DEST","enemy",Vector2(1430,1200))
	var radius:float=[2,2.5,3,3.5][level]*55
	var secondary:=make("HYD","enemy",primary.position+Vector2(radius+.1,0))
	normal_shot(sub,primary);var parent=missiles(sub)[0];advance(parent)
	check(forks().is_empty(),"opposite vessel beyond rank split radius excluded "+str(level))
	secondary.position.x-=.2;normal_shot(sub,primary);parent=missiles(sub)[0];advance(parent)
	check(forks().size()==1 and forks()[0].target==secondary,"rank radius starts at impact not launcher "+str(level))
	await finish()

func shield_and_visibility() -> void:
	prepare(3)
	var sub:=make("SUB","ally",Vector2(1100,1200));var primary:=make("SUB","enemy",Vector2(1430,1200));var secondary:=make("HYD","enemy",Vector2(1520,1200))
	Sub.state(primary).pressure_shield={"hp":10000.0,"left":5.0}
	check(normal_shot(sub,primary),"native torpedo launches at detected shielded submarine")
	var parent=missiles(sub)[0];advance(parent)
	check(primary.hp==100000 and forks().size()==1,"shield absorption still counts as real direct torpedo contact")
	await finish()
	prepare(3)
	sub=make("SUB","ally",Vector2(1100,1200));primary=make("DEST","enemy",Vector2(1430,1200));secondary=make("HYD","enemy",Vector2(1520,1200))
	normal_shot(sub,primary);parent=missiles(sub)[0]
	BattleRequest.skirmish_config.fog_of_war=true
	var fog=preload("res://scripts/world/fog_of_war.gd").new();battle.add_child(fog);fog.setup(battle);battle.fog=fog
	fog.visible_cells.ally.fill(0);fog.explored_cells.ally.fill(0)
	fog.visible_cells.ally[fog._index(primary.position)]=1
	advance(parent);check(forks().is_empty(),"secondary hidden by actual fog cannot be selected")
	normal_shot(sub,primary);parent=missiles(sub)[0]
	fog.visible_cells.ally.fill(0);fog.visible_cells.ally[fog._index(secondary.position)]=1
	advance(parent);check(forks().size()==1,"already fired primary hitting under fog may fork at a visible secondary")
	await finish()
	prepare(3)
	sub=make("SUB","ally",Vector2(1100,1200));primary=make("DEST","enemy",Vector2(1430,1200));secondary=make("HYD","enemy",Vector2(1520,1200))
	X.tick(sub,3.9);primary.add_buff("dodge",10,.95,"test");seed(101)
	var missed:=false
	for attempt in 20:
		Sub.state(sub).pressure_idle=3.9
		var count:=missiles(sub).size();normal_shot(sub,primary)
		if missiles(sub).size()==count:missed=true;break
	check(Sub.state(sub).pressure_idle==0 and missed,"ordinary miss restarts pressure idle without producing a main torpedo")
	X.tick(sub,.2);check(not Sub.state(sub).has("pressure_shield"),"pre-miss idle cannot carry into post-shot shield")
	await finish()

func pressure_boundaries(level:int) -> void:
	prepare(level)
	var sub:=make("SUB","ally",Vector2(1100,1200));var enemy:=make("DEST","enemy",Vector2(1300,1200))
	sub.max_hp=1000;sub.hp=1000;sub._base_max_hp=1000
	var amount:float=1000*[.05,.07,.09,.12][level]
	sub.velocity=Vector2(30,0);sub.position.x+=30
	X.tick(sub,3.5)
	check(Sub.state(sub).pressure_idle==3.5 and not Sub.state(sub).has("pressure_shield"),"moving submarine still accumulates quiet time")
	check(normal_shot(sub,enemy) and Sub.state(sub).pressure_idle==0,"pre-grant real firing resets quiet requirement")
	X.tick(sub,3.99);check(not Sub.state(sub).has("pressure_shield"),"pre-shot quiet time is not carried over")
	X.tick(sub,.01);check(Sub.state(sub).pressure_shield.hp==amount,"four post-shot seconds grants shield while moving")
	sub.receive_hit(amount+7,"torpedo",{},enemy)
	check(sub.hp==993 and not Sub.state(sub).has("pressure_shield") and Sub.state(sub).pressure_cd==20,"real torpedo breaks shield with seven overflow and keeps trigger interval")
	X.tick(sub,19.5);check(normal_shot(sub,enemy),"real firing shortly before interval ends")
	X.tick(sub,.5)
	check(not Sub.state(sub).has("pressure_cd") and not Sub.state(sub).has("pressure_shield"),"ready interval alone cannot bypass four quiet seconds")
	X.tick(sub,3.49);check(not Sub.state(sub).has("pressure_shield"),"still waits for full quiet time after cooldown ready")
	X.tick(sub,.01);check(Sub.state(sub).pressure_shield.hp==amount and sub.hp==993,"later full quiet interval grants shield without healing lost health")
	await finish()
