extends "res://tests/progression_expansion_2_regression.gd"
const Drone=preload("res://scripts/units/expansion_2_drone.gd")
const Native=preload("res://scripts/units/soviet_advanced.gd")
const Leap=preload("res://scripts/units/dog_pounce.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	await purchases()
	for level in 4:
		await lure(level)
		await hunt(level)
		await flight_toggle(level)
	await controls()
	await boundaries_drone()
	await saved_states()
	await failed_transfers()
	await invalid_lures()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_DRONE_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup_rank(level:int) -> Unit:
	start(MatchRules.EXTENDED);BattleRequest.skirmish_config.fog_of_war=false
	BattleRequest.combat_context.card_ranks.ap_lure_pounce=level
	BattleRequest.combat_context.unit_talents.DRON={"host_hunt":level}
	BattleRequest.combat_context.loadouts.DRON={"active":["ap_lure_pounce"],"passive":""}
	var unit:Unit=battle.spawn_unit("DRON","ally",Vector2(1100,1200))
	unit.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	return unit

func host(at:Vector2) -> Unit:
	var unit:Unit=battle.spawn_unit("HTNK","enemy",at);unit.max_hp=10000;unit.hp=10000
	unit.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	return unit

func bite(target) -> void:
	target.special.parasite_timer=0.0;Native.burrow_tick(target,.01)

func purchases() -> void:
	MetaProgress.currency.cores=100000
	MetaProgress.academy.card_shards=10000
	check(MetaProgress.Academy.purchase(MetaProgress,"redeem","ap_lure_pounce"),"real legend redemption unlocks lure pounce")
	for level in 3:check(MetaProgress.Academy.purchase(MetaProgress,"level","ap_lure_pounce"),"real lure card upgrade "+str(level))
	check(MetaProgress.set_unit_skill("DRON","active",0,"ap_lure_pounce"),"purchased lure equips W")
	var quote:=MetaProgress.talent_unlock_quote("DRON","host_hunt")
	check(MetaProgress.unlock_unit_talent("DRON","host_hunt",quote.get("cost",-1)),"real purchase drone functional talent")
	for level in 3:check(MetaProgress.upgrade_talent("DRON","host_hunt",level),"upgrade drone talent "+str(level))
	MetaProgress.load_save();start(MatchRules.EXTENDED)
	check(BattleRequest.has_unit_talent("DRON","host_hunt","ally") and MetaProgress.talent_rank("DRON","host_hunt",BattleRequest.combat_context.unit_talents)==3,"profile reload and new match preserve purchased talent")
	var drone:Unit=battle.spawn_unit("DRON","ally",Vector2(1100,1200))
	check(BattleRequest.combat_context.card_ranks.get("ap_lure_pounce",-1)==3 and drone.ability_at(UnitSkillLayout.index(drone,1)).id=="ap_lure_pounce" and UnitSkillLayout.index(drone,0)>=0,"profile reload freezes purchased rank three W alongside talent Q")
	await finish();MetaProgress.reset_save()

func lure(level:int) -> void:
	var drone:=setup_rank(level);var target:=host(Vector2(1300,1200))
	var w:=UnitSkillLayout.index(drone,1);var ab:=drone.ability_at(w)
	var speed:float=drone.move_speed
	check(not drone.use_ability(w) and ab.cd_left==0,"W rejects missing target without cooldown")
	drone.attack_target=target
	check(drone.use_ability(w) and ab.cd_left==32,"real equipped W casts "+str(level))
	check(is_equal_approx(drone.move_speed,speed*(1+[.2,.3,.4,.5][level])) and not Drone.invulnerable(drone),"rank speed and outside two cells not immune")
	drone.position=target.position-Vector2(110,0);X.tick(drone,.01)
	check(Drone.invulnerable(drone),"first entering exactly two cells grants guard")
	var hp:float=drone.hp;drone._stun_timer=.5;drone.receive_hit(100,"bullet",{},target)
	check(drone.hp==hp and drone._stun_timer==.5,"guard prevents damage without cleansing control")
	drone._stun_timer=0;X.tick(drone,float([1,1.25,1.5,2][level]))
	check(not Drone.invulnerable(drone),"rank guard expires exactly once")
	X.tick(drone,.01);check(not Drone.invulnerable(drone),"remaining approach window does not regrant guard")
	ab.cd_left=0;X.tick(drone,3);drone.attack_target=target;drone.use_ability(w)
	check(Drone.invulnerable(drone),"cast already within two cells grants immediate guard")
	Native.contact(drone,target)
	check(drone.embarked_in==target and not Drone.invulnerable(drone) and is_equal_approx(drone.move_speed,speed),"native infestation removes guard and approach speed")
	bite(target)
	check(is_equal_approx(target.special.parasite_timer,drone.weapon.cooldown*(1-[.1,.15,.2,.25][level])),"actual parasite timer shortened by W rank")
	X.tick(drone,2);bite(target)
	check(is_equal_approx(target.special.parasite_timer,drone.weapon.cooldown),"after two seconds native parasite interval restored")
	check(preload("res://scripts/units/auto_w.gd").supported("ap_lure_pounce"),"lure W supports conditional auto policy")
	await finish()

func hunt(level:int) -> void:
	var drone:=setup_rank(level);var original:=host(Vector2(1200,1200))
	var distance:float=[2,2.5,3,3.5][level]*55
	var next:=host(original.position+Vector2(distance,0))
	var farther:=host(original.position+Vector2(distance+50,70))
	var hp:float=drone.hp;var identity:=drone.get_instance_id()
	drone.ability_at(UnitSkillLayout.index(drone,1)).cd_left=19
	Native.contact(drone,original);original.hp=3999
	bite(original);bite(original)
	check(drone.embarked_in==original and Drone.state(drone).hunt_hits==2,"two effective bites retain original host")
	var before:float=original.hp;bite(original);var normal_loss:float=before-original.hp
	check(drone.embarked_in==null and not original.special.has("parasite") and drone.special.has("pounce"),"third actual bite starts physical transfer "+str(level))
	check(drone.special.get("pounce",{}).get("target")==next and next.special.get("parasite")==null and farther.special.get("parasite")==null,"nearest legal host chosen at rank range without remote infestation")
	check(drone.hp==hp and drone.get_instance_id()==identity and drone.ability_at(UnitSkillLayout.index(drone,1)).cd_left==19 and not Drone.invulnerable(drone),"transfer keeps same actor HP W cooldown without invulnerability")
	drone.receive_hit(1,"bullet",{},original);check(drone.hp<hp,"exposed transfer receives damage")
	for frame in 23:
		if drone.special.has("pounce"):
			Leap.tick(drone,1.0/60)
	check(drone.embarked_in==next and next.special.get("parasite")==drone and Drone.state(drone).hunt_hits==0,"native physical leap reaches new host within .35 seconds",{"position":drone.position,"next":next.position})
	check(drone.get_collision_exceptions().is_empty(),"old-host exit exception does not persist")
	var tear_start:float=original.hp;X.tick(original,1)
	var tear_loss:float=tear_start-original.hp
	check(is_equal_approx(tear_loss,Ra2Damage.quantize(normal_loss*[.3,.4,.5,.6][level])),"one residual tear has exact scaled parasite damage",[tear_loss,normal_loss])
	X.tick(original,2)
	check(is_equal_approx(tear_start-original.hp,tear_loss*3) and not Drone.state(original).has("hunt_tears"),"exactly three residual tears then stop")
	next.hp=3999
	if next.special.has("parasite"):bite(next);bite(next);bite(next)
	check(drone.embarked_in==next and Drone.state(drone).hunt_hits==3,"ten-second cooldown prevents immediate next transfer")
	await finish()

func saved_states() -> void:
	var drone:=setup_rank(3);var original:=host(Vector2(1200,1200));host(Vector2(1330,1200))
	drone.attack_target=original;drone.use_ability(UnitSkillLayout.index(drone,1));X.tick(drone,.4)
	var snap:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snap)
	for actor in battle.units:
		if actor.unit_id=="DRON":drone=actor
		elif actor.position.is_equal_approx(Vector2(1200,1200)):original=actor
	check(is_equal_approx(Drone.state(drone).pounce_guard,1.6) and is_equal_approx(Drone.state(drone).pounce_left,2.6) and Drone.state(drone).pounce_target==original,"save restores independent guard approach timers and locked target")
	Native.contact(drone,original);drone.use_ability(UnitSkillLayout.index(drone,0));original.hp=3999
	bite(original);bite(original)
	snap=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snap)
	for actor in battle.units:
		if actor.unit_id=="DRON":drone=actor
		elif actor.position.is_equal_approx(Vector2(1200,1200)):original=actor
	check(not Drone.automatic(drone) and Drone.state(drone).hunt_hits==2 and drone.embarked_in==original and Drone.state(drone).hunt_host==original,"save preserves Q off actual bite count and host identity")
	check(drone.skills.filter(func(ab):return ab.id==Drone.TOGGLE).size()==1,"restoring owned native Q never duplicates Ability")
	bite(original);check(drone.embarked_in==original,"Q remains off after loaded third bite")
	drone.use_ability(UnitSkillLayout.index(drone,0));bite(original);X.tick(original,1)
	var hp:float=original.hp
	snap=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snap)
	for actor in battle.units:
		if actor.unit_id=="DRON":drone=actor
		elif actor.position.is_equal_approx(Vector2(1200,1200)):original=actor
	check(Drone.state(original).hunt_tears[0].ticks==1 and Drone.state(original).hunt_tears[0].owner==drone,"save preserves already consumed residual pulse and damage owner")
	X.tick(original,2);var after:float=original.hp;X.tick(original,2)
	check(after<hp and original.hp==after and not Drone.state(original).has("hunt_tears"),"loaded residual emits remaining two pulses only")
	await finish()

func failed_transfers() -> void:
	for reason in ["blocked","occupied","death","control","repair","fatal","shield","range"]:
		var drone:=setup_rank(3);var original:=host(Vector2(1200,1200));var next:=host(Vector2(1390,1200));original.hp=3999
		Native.contact(drone,original)
		if reason=="shield":Drone.state(original).module_shield={"left":30.0,"hp":1000.0}
		if reason=="range":next.position=Vector2(1393,1200)
		if reason=="repair":Native.cleanse(original,true)
		elif reason=="fatal":original.hp=1;bite(original)
		else:bite(original);bite(original);bite(original)
		match reason:
			"repair":check(not original.special.has("parasite") and not Drone.state(original).has("hunt_tears"),"repair destroys parasite without jumping or residual")
			"fatal":check(not Drone.state(original).has("hunt_tears") and not drone.special.has("pounce"),"fatal bite uses native host-death release without new leap")
			"shield":check(Drone.state(drone).hunt_hits==0 and drone.embarked_in==original,"shield-only damage never counts toward three bites")
			"range":check(drone.embarked_in==original,"outside rank range retains original parasite")
			_:
				if reason=="blocked":host(Vector2(1270,1200))
				if reason=="occupied":
					var intruder:Unit=battle.spawn_unit("DRON","ally",next.position);Native.contact(intruder,next)
				if reason=="death":next.hp=0
				if reason=="control":drone._stun_timer=1
				for frame in 24:
					if drone.special.has("pounce"):Leap.tick(drone,1.0/60)
				check(drone.embarked_in==null and not drone.special.has("pounce") and Drone.state(drone).hunt_cd==10,"failed physical transfer is exposed with cooldown retained: "+reason)
				if reason=="blocked":check(drone.position.x<1270,"leap cannot pass through an intervening solid enemy")
		await finish()

func invalid_lures() -> void:
	for reason in ["retarget","expiry","friendly","infantry","air","naval","iron","stun","temporary","ownership","hidden","occupied","freed"]:
		var drone:=setup_rank(2);var target:=host(Vector2(1300,1200));drone.attack_target=target
		var w:=UnitSkillLayout.index(drone,1)
		match reason:
			"friendly":target.side="ally"
			"infantry":target.free();target=battle.spawn_unit("E1","enemy",Vector2(1300,1200));drone.attack_target=target
			"air":target.is_air=true;target.logistics.air_lift=40
			"naval":target.is_naval=true
			"iron":target.special.iron_left=10
			"stun":drone._stun_timer=1
			"temporary":drone.special.expansion_temporary={"kind":"twin"}
			"hidden":target.special.echo_cloaked=true
			"freed":target.free()
			"occupied":
				var another:Unit=battle.spawn_unit("DRON","ally",target.position);Native.contact(another,target)
		if reason in ["retarget","expiry","ownership"]:
			drone.use_ability(w)
			if reason=="retarget":drone.attack_target=host(Vector2(1300,1250))
			if reason=="ownership":drone.side="enemy"
			X.tick(drone,3.0 if reason=="expiry" else .01);drone.position=target.position-Vector2(100,0);X.tick(drone,.01)
			check(not Drone.invulnerable(drone),"untriggered guard cannot revive after "+reason)
		else:check(not drone.use_ability(w) and drone.ability_at(w).cd_left==0,"illegal lure rejected without cooldown: "+reason)
		await finish()

func controls() -> void:
	var drone:=setup_rank(3);var other:Unit=battle.spawn_unit("DRON","ally",Vector2(1050,1200))
	var original:=host(Vector2(1200,1200));host(Vector2(1300,1200))
	check(Drone.automatic(drone) and Drone.automatic(other) and UnitSkillLayout.index(drone,0)>=0,"owned talent creates default-on Q without occupying W")
	battle.select_unit(drone,false);battle.select_unit(other,true)
	check(battle.request_ability(UnitSkillLayout.index(drone,0))==2 and not Drone.automatic(drone) and not Drone.automatic(other),"group Q turns all off")
	other.use_ability(UnitSkillLayout.index(other,0))
	check(battle.request_ability(UnitSkillLayout.index(drone,0))==1 and not Drone.automatic(other) and not Drone.automatic(drone),"mixed group Q consistently turns all off")
	Native.contact(drone,original);original.hp=3999;bite(original);bite(original);bite(original)
	check(drone.embarked_in==original and Drone.state(drone).hunt_hits==3,"Q off retains parasite after three low-health bites")
	battle.select_unit(drone,false);battle._emit_selection()
	check(battle.inspected_target_on(original)==drone and battle.selected_skill_unit()==drone,"selecting host exposes own parasite Q control")
	check(battle.request_ability(UnitSkillLayout.index(drone,0))==1 and Drone.automatic(drone),"Q can enable while inside enemy host")
	X.tick(drone,.5);check(drone.embarked_in==original,"Q enabling and timer tick do not trigger early transfer")
	bite(original);check(drone.embarked_in==null and drone.special.has("pounce"),"next real parasite bite performs transfer")
	drone.use_ability(UnitSkillLayout.index(drone,0))
	check(drone.special.has("pounce") and not Drone.automatic(drone),"Q off in flight preserves current leap")
	drone.order_stop();check(not drone.special.has("pounce") and Drone.state(drone).hunt_cd==10,"stop cancels transfer without cooldown refund")
	var at:Vector2=drone.position;drone.move_with_traffic_exceptions(Vector2(0,45))
	check(drone.position.distance_to(at)>30 and drone.get_collision_exceptions().is_empty(),"cancelled leap can physically exit old host without leaving a collision exception")
	await finish()

func flight_toggle(level:int) -> void:
	var drone:=setup_rank(level)
	var original:=host(Vector2(1200,1200));var next:=host(Vector2(1300,1200))
	Native.contact(drone,original);original.hp=3999
	bite(original);bite(original);bite(original)
	Leap.tick(drone,.1)
	check(drone.special.has("pounce") and drone.embarked_in==null,"fixture is physically mid-leap "+str(level))
	var remaining:float=Drone.state(drone).hunt_cd
	drone.use_ability(UnitSkillLayout.index(drone,0))
	var snap:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snap)
	for actor in battle.units:
		# This fixture disables scene processing and manually advances movement.
		# Restored actors need the same physics-server policy as setup_rank/host.
		actor.disable_mode=CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		if actor.unit_id=="DRON":drone=actor
		elif actor.position.is_equal_approx(Vector2(1300,1200)):next=actor
	check(not Drone.automatic(drone) and drone.special.has("pounce") and is_equal_approx(Drone.state(drone).hunt_cd,remaining),"mid-leap Q off and cooldown survive snapshot "+str(level))
	for frame in 23:
		if drone.special.has("pounce"):Leap.tick(drone,1.0/60)
	check(drone.embarked_in==next and next.special.get("parasite")==drone and not Drone.automatic(drone),"Q off does not retract current leap after load "+str(level),[drone.position,next.position,drone.special.has("pounce"),Drone.legal(drone,next)])
	X.tick(drone,10);next.hp=3999
	if next.special.has("parasite"):bite(next);bite(next);bite(next)
	check(drone.embarked_in==next and Drone.state(drone).hunt_hits==3 and not Drone.state(drone).has("hunt_cd"),"Q off prevents a later leap even after cooldown and three bites "+str(level))
	await finish()

func boundaries_drone() -> void:
	var drone:=setup_rank(3);var original:=host(Vector2(1200,1200));original.hp=3999
	Native.contact(drone,original)
	original.special.iron_left=5.0;bite(original)
	check(Drone.state(drone).hunt_hits==0,"zero damage invulnerable bite does not count")
	original.special.erase("iron_left");bite(original);bite(original);bite(original)
	check(drone.embarked_in==original,"no legal next host retains current parasite")
	var next:=host(Vector2(1300,1200));next.special.iron_left=5.0;bite(original)
	check(drone.embarked_in==original,"invulnerable next host is not a legal transfer")
	next.special.erase("iron_left");bite(original)
	var save:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,save)
	for actor in battle.units:
		if actor.unit_id=="DRON":drone=actor
		elif actor.position.is_equal_approx(Vector2(1200,1200)):original=actor
		elif actor.position.is_equal_approx(Vector2(1300,1200)):next=actor
	check(drone.special.pounce.target==next and drone.special.pounce.hunt_from==original and Drone.state(drone).hunt_cd==10,"snapshot restores transfer target old host and cooldown")
	Native.cleanse(original,true);check(not Drone.state(original).has("hunt_tears"),"repair clears residual even without live parasite")
	drone.order_move(drone.position+Vector2(0,50));check(not drone.special.has("pounce"),"new movement order cancels only transfer leap")
	await finish()
	start(MatchRules.RA2)
	drone=battle.spawn_unit("DRON","ally",Vector2(1100,1200))
	check(UnitSkillLayout.index(drone,0)<0 and not Drone.enabled(drone),"classic drone has no talent Q")
	await finish()
