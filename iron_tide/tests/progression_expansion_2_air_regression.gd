extends "res://tests/progression_expansion_2_regression.gd"
const Air=preload("res://scripts/units/expansion_2_air.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for level in 4:
		await hover(level)
		for id in ["JUMPJET","SHAD","SCHP"]:await observe(level,id)
	await boundaries();await acquisition()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_AIR_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func setup(level:int) -> void:
	start(MatchRules.EXTENDED)
	BattleRequest.combat_context.unit_talents.JUMPJET={Air.HOVER:level}
	BattleRequest.combat_context.card_ranks[Air.OBSERVE]=level

func make(id:String,side:String,point:Vector2) -> Unit:
	var unit:Unit=battle.spawn_unit(id,side,point);unit.max_hp=100000;unit.hp=100000
	if unit.is_air:unit.logistics.air_lift=1.0
	return unit

func hover(level:int) -> void:
	setup(level);battle.fog=null
	var gun:=make("JUMPJET","ally",Vector2(1100,1200));var target:=make("HTNK","enemy",Vector2(1200,1200))
	var reach:float=gun.attack_range;var height:float=gun.logistics.air_lift;var vision:float=gun.sight
	gun.passive=GameData.get_skill(Air.OBSERVE)
	var base_damage:=Ra2Damage.quantize(CombatMath.with_defense(CombatMath.full_damage(gun._active_weapon(),target.armor,gun.bonuses,null,target.ra2_armor,0,target),target.bonuses))
	var elapsed:=0.0
	for step in [0.,.8,.8,.39]:
		X.tick(gun,step);elapsed+=step
		var before:float=target.hp
		check(normal_shot(gun,target),"aimed stationary firing during initial calibration "+str(elapsed))
		fly_missiles(gun)
		check(is_equal_approx(before-target.hp,base_damage) and not Air.hovering(gun),"shots before two seconds retain base damage "+str(level)+"/"+str(elapsed))
		check(is_equal_approx(float(Air.state(gun).hover_age),elapsed) and Second.sight(gun)==0,"firing resets observation but preserves hover calibration progress")
	check(not Air.hovering(gun),"hover not ready before two seconds")
	var saved:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,saved)
	for unit in battle.units:
		if unit.unit_id=="JUMPJET":gun=unit
		elif unit.unit_id=="HTNK":target=unit
	check(is_equal_approx(float(Air.state(gun).hover_age),1.99) and not Air.hovering(gun),"snapshot restores partial hover time without granting readiness")
	X.tick(gun,.01);check(Air.hovering(gun),"hover ready at exact two seconds "+str(level))
	var weapon:Dictionary=gun._active_weapon().duplicate(true);weapon.damage*=1.0+float([.08,.12,.16,.2][level])
	var expected:=Ra2Damage.quantize(CombatMath.with_defense(CombatMath.full_damage(weapon,target.armor,gun.bonuses,null,target.ra2_armor,0,target),target.bonuses))
	for shot in 2:
		var before:float=target.hp;check(normal_shot(gun,target),"native hovering weapon fires");fly_missiles(gun)
		check(is_equal_approx(before-target.hp,expected) and Air.hovering(gun),"native direct hit receives exact boost and does not consume hover "+str(level),[before-target.hp,expected])
	check(gun.attack_range==reach and gun.sight==vision and gun.logistics.air_lift==height,"hover cannot change range vision or flight height")
	gun.position+=Vector2(1,0)
	check(not Air.hovering(gun),"actual displacement immediately invalidates hover even before next tick")
	X.tick(gun,.1);X.tick(gun,1.99);check(not Air.hovering(gun),"moving forces complete new two-second calibration")
	X.tick(gun,.01);check(Air.hovering(gun),"fresh stationary interval restores hover")
	gun.logistics.air_lift=0;X.tick(gun,.01);check(not Air.hovering(gun),"landing clears hover")
	gun.logistics.air_lift=1;X.tick(gun,1);check(not Air.hovering(gun),"takeoff cannot restore old hover credit")
	await finish()

func observe(level:int,id:String) -> void:
	setup(level)
	var gun:=make(id,"ally",Vector2(1100,1200));gun.passive=GameData.get_skill(Air.OBSERVE)
	var target:=make("HTNK","enemy",Vector2(1200,1200))
	var fog=preload("res://scripts/world/fog_of_war.gd").new();var radius:float=fog._unit_vision_radius(gun);battle.fog=null
	var reach:float=gun.attack_range
	gun.velocity=Vector2.RIGHT*50;X.tick(gun,1.99)
	check(Second.sight(gun)==0,"moving observer still waits two seconds "+id)
	gun.position+=Vector2(5,0);X.tick(gun,.01)
	var extra:float=[.5,1,1.5,2][level]*55
	check(is_equal_approx(Second.sight(gun),extra) and is_equal_approx(fog._unit_vision_radius(gun),radius+extra),"actual fog consumes exact moving-air observation rank "+id+str(level))
	fog.free()
	check(gun.attack_range==reach and not NavalContact.SENSOR_CELLS.has(id),"observation does not change weapon range or grant sensors")
	gun.velocity=Vector2.ZERO
	if id!="SHAD":
		normal_shot(gun,target);fly_missiles(gun)
		check(Second.sight(gun)==0,"actual normal shot immediately removes observation "+id)
	else:
		var bomb:=ability(gun,"ap_bomb_nests")
		check(gun.use_ability(gun.skills.size()-1),"night hawk casts real attack nests")
		X.Cards.tick(gun,.01)
		check(Second.sight(gun)==0 and bomb.cd_left>0,"actual attack payload drop clears observation")
		X.tick(gun,.6);X.tick(gun,.6)
		check(Second.sight(gun)==0 and not gun.special.get("progression_v1",{}).has("nests"),"remaining two actual payload drops restart observation before idle save")
	X.tick(gun,1.5)
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	for unit in battle.units:if unit.side=="ally" and unit.unit_id==id:gun=unit
	check(is_equal_approx(float(Air.state(gun).air_observe),1.5) and Second.sight(gun)==0,"snapshot keeps only earned idle observation time "+id)
	X.tick(gun,.5);check(is_equal_approx(Second.sight(gun),extra),"remaining half second after load restores observation "+id)
	gun.logistics.air_lift=0;check(Second.sight(gun)==0,"landed query cannot retain aerial sight")
	X.tick(gun,.01);gun.logistics.air_lift=1;X.tick(gun,1)
	check(Second.sight(gun)==0,"landing resets observation credit before new flight")
	gun.side="enemy";X.tick(gun,.01);check(not gun.special.has(Second.KEY),"capture clears airborne talent and passive state")
	await finish()

func boundaries() -> void:
	setup(3);battle.fog=null
	var gun:=make("JUMPJET","ally",Vector2(1100,1200));gun.passive=GameData.get_skill(Air.OBSERVE)
	var target:=make("HTNK","enemy",Vector2(1200,1200));target.add_buff("dodge",100,1.0)
	X.tick(gun,2);seed(1);var before:float=target.hp;normal_shot(gun,target);fly_missiles(gun)
	check(target.hp==before and Second.sight(gun)==0,"dodged actual shot still ends observation")
	var packet:Dictionary={};Air.shot(gun,packet)
	check(is_equal_approx(float(packet.get("expansion_hover_damage",0)),.2),"normal hover bonus captured on shot")
	packet.expansion_extra=true
	check(Air.impact(target,gun,100,packet)==100,"additional skill damage never inherits hover")
	packet.erase("expansion_extra")
	for key in ["equipment_secondary","expansion_scatter"]:
		packet[key]=true;check(Air.impact(target,gun,100,packet)==100,"secondary attack cannot copy hover "+key);packet.erase(key)
	var projectile:=Projectile.new();projectile.target=gun
	check(Air.impact(target,projectile,100,packet)==100,"splash neighbor never receives direct-hit bonus")
	projectile.target=target;gun.free()
	check(is_equal_approx(Air.impact(target,projectile,100,packet),120),"already fired shot keeps captured bonus after shooter removal")
	projectile.free();battle.units=battle.units.filter(func(unit):return is_instance_valid(unit))
	var plane:=make("HORNET","ally",Vector2(1100,1200));plane.passive=GameData.get_skill(Air.OBSERVE);X.tick(plane,3)
	check(Second.sight(plane)==0,"carrier aircraft cannot inherit observation")
	var temporary:=make("JUMPJET","ally",Vector2(1100,1250));temporary.passive=GameData.get_skill(Air.OBSERVE);temporary.special.expansion_temporary={"kind":"mirror","owner":plane,"left":10,"origin":temporary.position}
	X.tick(temporary,3);check(Second.sight(temporary)==0 and not Air.hovering(temporary),"temporary copy cannot inherit either bonus")
	await finish()
	start(MatchRules.RA2)
	gun=make("JUMPJET","ally",Vector2(1100,1200));gun.passive=GameData.get_skill(Air.OBSERVE);X.tick(gun,3)
	check(Second.sight(gun)==0 and not Air.hovering(gun),"classic mode suppresses both new effects")
	await finish()

func acquisition() -> void:
	MetaProgress.currency.credits=100000;MetaProgress.currency.cores=100000
	var quote:=MetaProgress.talent_unlock_quote("JUMPJET",Air.HOVER)
	check(MetaProgress.unlock_unit_talent("JUMPJET",Air.HOVER,quote.cost),"new hover talent uses real unlock")
	for rank in 3:check(MetaProgress.upgrade_talent("JUMPJET",Air.HOVER,rank),"real hover talent rank upgrade "+str(rank))
	MetaProgress.load_save()
	check(MetaProgress.talent_rank("JUMPJET",Air.HOVER,MetaProgress.unit_talents)==3,"hover rank saved to profile")
