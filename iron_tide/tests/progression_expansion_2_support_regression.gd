extends "res://tests/progression_expansion_2_naval_regression.gd"
const Calibration=preload("res://scripts/units/expansion_2_calibration.gd")
const Convoy=preload("res://scripts/units/expansion_2_convoy.gd")
const Cards=preload("res://scripts/units/expansion_cards.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for level in 4:
		await calibration(level)
		for id in ["MTNK","HTNK","FV","HTK"]:await convoy(level,id)
	await overlap()
	await seismic()
	await excluded_support()
	await convoy_boundaries()
	await support_save()
	await flight_and_rearm()
	await convoy_prepare_save()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_SUPPORT_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func prepare_support(level:int) -> void:
	setup(level)
	for id in [Calibration.CARD,Convoy.CARD]:BattleRequest.combat_context.card_ranks[id]=level
	BattleRequest.combat_context.loadouts.SCHP={"active":["ap_seismic_anchor"],"passive":Calibration.CARD}
	for id in ["MTNK","HTNK","FV","HTK"]:BattleRequest.combat_context.loadouts[id]={"active":[],"passive":Convoy.CARD}

func deploy_chopper(at:Vector2) -> Unit:
	var unit:=make("SCHP","ally",at)
	unit.set_deployed(true,false);unit.logistics.air_lift=0
	preload("res://scripts/units/siege_chopper.gd").tick(unit,10)
	check(Calibration.deployed(unit),"native chopper completes deployed cannon state")
	return unit

func cannon_loss(unit,target) -> float:
	var before:float=target.hp
	check(normal_shot(unit,target),"native deployed cannon fires")
	fly_missiles(unit)
	return before-target.hp

func calibration(level:int) -> void:
	prepare_support(level)
	var gun:=deploy_chopper(Vector2(1000,1100));var target:=make("HTNK","enemy",Vector2(1300,1100))
	gun.passive={};var base:=cannon_loss(gun,target)
	gun.passive=GameData.get_skill(Calibration.CARD)
	var first:=cannon_loss(gun,target)
	check(base>0 and first==base,"triggering shell does not boost itself "+str(level),[base,first])
	var zones:Array=battle.allied_state.get(Calibration.ZONES,[])
	check(zones.size()==1 and zones[0].left==4 and gun.special.progression_v2.calibration_cd==6,"direct impact creates one four-second zone and six-second cooldown")
	var loss:=cannon_loss(gun,target)
	check(absf(loss-Ra2Damage.quantize(base*(1+[.08,.12,.16,.2][level])))<=1,"ordinary cannon receives exact rank zone bonus",[base,loss])
	check(zones.size()==1 and zones[0].left==4,"cooldown cannot create or refresh another field")
	var ally:=deploy_chopper(Vector2(1000,900));ally.passive={}
	loss=cannon_loss(ally,target)
	check(absf(loss-Ra2Damage.quantize(base*(1+[.08,.12,.16,.2][level])))<=1,"unequipped allied deployed cannon receives shared bonus")
	var before:float=target.hp
	var bonus:Dictionary={"expansion_extra":true,"reference_weapon":gun.deployed_weapon()}
	target.receive_hit(1000,"shell",bonus,gun)
	check(is_equal_approx(before-target.hp,1000*(1+[.08,.12,.16,.2][level])),"actual deployed cannon skill damage gets one multiplier")
	check(zones.size()==1,"cannon skill cannot generate additional field")
	gun._deployed=false
	before=target.hp;target.receive_hit(1000,"shell",bonus,gun)
	check(target.hp==before-1000,"airborne or folded caster cannot receive cannon skill bonus")
	check(Calibration.bonus_at(battle,"ally",target)>0,"takeoff leaves existing fixed-duration field")
	Calibration.world_tick(battle,3.99);check(Calibration.bonus_at(battle,"ally",target)>0,"zone persists just before expiry")
	Calibration.world_tick(battle,.01);check(not battle.allied_state.has(Calibration.ZONES),"zone expires exactly at four seconds")
	await finish()

func overlap() -> void:
	prepare_support(3)
	var gun:=deploy_chopper(Vector2(1000,1100));var target:=make("HTNK","enemy",Vector2(1300,1100))
	gun.passive={}
	var base:=cannon_loss(gun,target)
	battle.allied_state[Calibration.ZONES]=[
		{"owner":gun,"side":"ally","point":target.position,"left":4.0,"damage":.12},
		{"owner":gun,"side":"ally","point":target.position,"left":1.0,"damage":.2},
		{"owner":gun,"side":"enemy","point":target.position,"left":4.0,"damage":.9}]
	check(Calibration.bonus_at(battle,"ally",target)==.2,"overlap takes highest friendly bonus without stacking")
	check(absf(cannon_loss(gun,target)-Ra2Damage.quantize(base*1.2))<=1,"real ordinary cannon uses twenty rather than thirty-two percent in overlapping fields")
	Calibration.world_tick(battle,1)
	check(Calibration.bonus_at(battle,"ally",target)==.12 and battle.allied_state[Calibration.ZONES][0].left==3,"strong expiry retains weaker independent field")
	check(absf(cannon_loss(gun,target)-Ra2Damage.quantize(base*1.12))<=1,"real ordinary cannon falls back to twelve percent after stronger field expires")
	target.position+=Vector2(83,0)
	check(Calibration.bonus_at(battle,"ally",target)==0,"target beyond one-and-half-cell radius receives no boost")
	target.position-=Vector2(83,0)
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	target=battle.units.filter(func(u):return u.side=="enemy")[0]
	check(Calibration.bonus_at(battle,"ally",target)==.12 and battle.allied_state[Calibration.ZONES][0].left==3,"snapshot restores independent world fields with remaining lifetime")
	await finish()

func move_pair(unit,peer,dt:float) -> void:
	unit.position+=Vector2(10*dt,0);peer.position+=Vector2(10*dt,0)
	battle.neighborhood.relocate(unit);battle.neighborhood.relocate(peer)
	X.tick(unit,dt)

func convoy(level:int,id:String) -> void:
	prepare_support(level)
	var unit:=make(id,"ally",Vector2(1000,1100));var peer:=make("MTNK","ally",Vector2(1040,1100));peer.passive={}
	unit.max_hp=1000;unit.hp=500;peer.hp=500
	X.tick(unit,0)
	move_pair(unit,peer,2.99)
	check(not unit.special.progression_v2.has("convoy_left") and unit.hp==500,"convoy requires full three seconds "+id+str(level))
	move_pair(unit,peer,.01)
	check(unit.special.progression_v2.get("convoy_left",0)==3 and unit.special.progression_v2.get("convoy_cd",0)==18,"real displacement and moving companion arm three-second self repair")
	move_pair(unit,peer,1)
	var rate:float=[.005,.007,.009,.011][level]
	check(is_equal_approx(unit.hp,500+1000*rate) and peer.hp==500,"rank healing affects only carrier "+id+str(level))
	move_pair(unit,peer,2)
	check(is_equal_approx(unit.hp,500+3000*rate) and not unit.special.progression_v2.has("convoy_left"),"three-second maximum healing duration")
	move_pair(unit,peer,3)
	check(not unit.special.progression_v2.has("convoy_left"),"eighteen-second interval prevents continuous healing")
	await finish()

func convoy_boundaries() -> void:
	for mode in ["stop","stationary_peer","far","miner","air","infantry","mirror","enemy","damage","friendly","capture"]:
		prepare_support(3)
		var unit:=make("MTNK","ally",Vector2(1000,1100));var peer:=make("HTNK","ally",Vector2(1040,1100));peer.passive={}
		unit.max_hp=1000;unit.hp=500;X.tick(unit,0);move_pair(unit,peer,3)
		check(unit.special.progression_v2.has("convoy_left"),"boundary starts with actual active repair "+mode)
		match mode:
			"stop":X.tick(unit,.1)
			"stationary_peer":unit.position+=Vector2(1,0);X.tick(unit,.1)
			"far":peer.position+=Vector2(200,0);move_pair(unit,peer,.1)
			"miner":peer.is_harvester=true;move_pair(unit,peer,.1)
			"air":peer.is_air=true;move_pair(unit,peer,.1)
			"infantry":peer.data=peer.data.duplicate(true);peer.data.role="infantry";move_pair(unit,peer,.1)
			"mirror":peer.special.expansion_temporary={"kind":"mirror"};move_pair(unit,peer,.1)
			"enemy":peer.side="enemy";move_pair(unit,peer,.1)
			"damage":
				var enemy:=make("HTNK","enemy",Vector2(1300,1100));unit.receive_hit(10,"shell",{},enemy)
			"friendly":unit.receive_hit(10,"shell",{},peer)
			"capture":unit.side="enemy";X.tick(unit,.1)
		check(unit.special.get("progression_v2",{}).has("convoy_left")==(mode=="friendly"),"only enemy damage or invalid actual companionship cancels repair "+mode)
		if mode=="damage":
			var damaged_hp:float=unit.hp
			move_pair(unit,peer,3)
			check(unit.hp==damaged_hp and not unit.special.progression_v2.has("convoy_left"),"resuming valid movement after enemy hit does not bypass remaining interval")
			move_pair(unit,peer,14.99)
			check(not unit.special.progression_v2.has("convoy_left"),"damage cancellation keeps original eighteen-second interval")
			move_pair(unit,peer,.01)
			check(unit.special.progression_v2.get("convoy_left",0)==3 and unit.hp==damaged_hp,"fresh repair starts after original interval without instant retroactive healing")
		await finish()

func support_save() -> void:
	prepare_support(3)
	var unit:=make("MTNK","ally",Vector2(1000,1100));var peer:=make("HTNK","ally",Vector2(1040,1100));peer.passive={}
	unit.max_hp=1000;unit.hp=500;X.tick(unit,0);move_pair(unit,peer,3);move_pair(unit,peer,1)
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	unit=battle.units.filter(func(u):return u.unit_id=="MTNK")[0];peer=battle.units.filter(func(u):return u.unit_id=="HTNK")[0]
	check(unit.special.progression_v2.convoy_left==2 and unit.special.progression_v2.convoy_cd==17,"snapshot restores active repair and cooldown")
	check(unit.special.progression_v2.convoy_peers[0].unit==peer,"snapshot restores tracked companion reference")
	var before:float=unit.hp;move_pair(unit,peer,1)
	check(is_equal_approx(unit.hp,before+unit.max_hp*.011) and unit.special.progression_v2.convoy_left==1,"restored moving convoy continues without restarting duration")
	unit.hp=unit.max_hp-1;move_pair(unit,peer,1);check(unit.hp==unit.max_hp,"repair caps at maximum health")
	await finish()

func seismic() -> void:
	prepare_support(3)
	var gun:=deploy_chopper(Vector2(1000,1100));var target:=make("HTNK","enemy",Vector2(1300,1100))
	var slot:=UnitSkillLayout.index(gun,1)
	check(gun.ability_at(slot).id=="ap_seismic_anchor" and gun.passive.id==Calibration.CARD,"legendary cannon W and calibration passive equip simultaneously")
	check(gun.use_ability(slot,target.position),"real deployed cannon W casts")
	var before:float=target.hp;Cards.world_tick(battle,1);var base:float=before-target.hp
	check(base>0 and not battle.allied_state.has(Calibration.ZONES),"real seismic damage alone cannot create calibration field")
	before=target.hp;Cards.world_tick(battle,1);var base_pulse:float=before-target.hp
	check(base_pulse>0,"baseline uses actual later seismic pulse rather than first-hit coefficient")
	battle.allied_state.erase("expansion_zones");gun.ability_at(slot).cd_left=0
	var peer:=deploy_chopper(Vector2(1000,900))
	battle.allied_state[Calibration.ZONES]=[{"owner":gun,"side":"ally","point":target.position,"left":1.5,"damage":.2},{"owner":peer,"side":"ally","point":target.position,"left":4.0,"damage":.12}]
	check(gun.use_ability(slot,target.position),"real W also casts inside calibration field")
	before=target.hp;Cards.world_tick(battle,1)
	check(absf(before-target.hp-Ra2Damage.quantize(base*1.2))<=1,"real world seismic pulse receives exactly one calibration multiplier",[base,before-target.hp])
	before=target.hp;Cards.world_tick(battle,1)
	check(absf(before-target.hp-Ra2Damage.quantize(base_pulse*1.12))<=1 and battle.allied_state[Calibration.ZONES][0].left==2,"actual later W pulse falls back to independent twelve-percent field after stronger field expires",[base_pulse,before-target.hp])
	check(battle.has_node("ExpansionFields") and battle.fog==null,"world field visual host created without fog mutation")
	check(not gun.special.get("progression_v2",{}).has("calibration_cd"),"W never spends normal-impact generation cooldown")
	await finish()

func excluded_support() -> void:
	start(MatchRules.RA2);battle.fog=null
	var unit:=make("MTNK","ally",Vector2(1000,1100));var peer:=make("HTNK","ally",Vector2(1040,1100))
	unit.passive=GameData.get_skill(Convoy.CARD);unit.hp=500
	X.tick(unit,0);move_pair(unit,peer,4)
	check(unit.hp==500 and not unit.special.get("progression_v2",{}).has("convoy_left"),"classic mode excludes convoy even with forced card")
	var gun:=make("SCHP","ally",Vector2(1000,900));gun._deployed=true;gun.logistics.air_lift=0;gun.passive=GameData.get_skill(Calibration.CARD)
	check(not Calibration.deployed(gun),"classic mode excludes calibration")
	await finish()

func flight_and_rearm() -> void:
	prepare_support(3)
	var gun:=deploy_chopper(Vector2(1000,1100));var target:=make("HTNK","enemy",Vector2(1300,1100))
	check(normal_shot(gun,target),"launch native calibration shell before snapshot")
	check(not missiles(gun).is_empty() and not battle.allied_state.has(Calibration.ZONES),"launch alone creates no calibration zone")
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	gun=battle.units.filter(func(u):return u.unit_id=="SCHP")[0];target=battle.units.filter(func(u):return u.side=="enemy")[0]
	fly_missiles(gun)
	check(battle.allied_state.get(Calibration.ZONES,[]).size()==1 and gun.special.progression_v2.get("calibration_cd",0)==6,"restored in-flight shell creates one zone on actual impact")
	Calibration.world_tick(battle,4);X.tick(gun,4)
	check(cannon_loss(gun,target)>0 and not battle.allied_state.has(Calibration.ZONES),"field expiry does not bypass remaining generation cooldown")
	X.tick(gun,2);cannon_loss(gun,target)
	check(battle.allied_state.get(Calibration.ZONES,[]).size()==1,"new normal impact after six seconds generates fresh zone")
	gun.hp=0
	check(Calibration.bonus_at(battle,"ally",target)==.2,"existing zone has independent lifetime after owner dies")
	await finish()
	prepare_support(3)
	gun=deploy_chopper(Vector2(1000,1100));target=make("HTNK","enemy",Vector2(1300,1100))
	check(normal_shot(gun,target),"launch then change deployed posture")
	gun.set_deployed(false,false);gun.special.erase("siege_progress");fly_missiles(gun)
	check(not battle.allied_state.has(Calibration.ZONES),"folding before impact prevents zone generation")
	await finish()

func convoy_prepare_save() -> void:
	prepare_support(3)
	var unit:=make("MTNK","ally",Vector2(1000,1100));var peer:=make("HTNK","ally",Vector2(1040,1100));peer.passive={}
	unit.hp=500;X.tick(unit,0);unit.has_move_order=true;unit.move_target=Vector2(1400,1100);unit.hull_angle+=.5
	X.tick(unit,4)
	check(not unit.special.progression_v2.has("convoy_left") and unit.special.progression_v2.convoy_age==0,"turning and queued movement without displacement do not prepare repair")
	move_pair(unit,peer,2)
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	unit=battle.units.filter(func(u):return u.unit_id=="MTNK")[0];peer=battle.units.filter(func(u):return u.unit_id=="HTNK")[0]
	check(unit.special.progression_v2.convoy_age==2,"snapshot preserves two seconds of actual accompanied movement")
	move_pair(unit,peer,1);check(unit.special.progression_v2.get("convoy_left",0)==3,"restored preparation triggers after only remaining second")
	move_pair(unit,peer,3);move_pair(unit,peer,14.99)
	check(not unit.special.progression_v2.has("convoy_left"),"repair cannot restart before full eighteen-second interval")
	move_pair(unit,peer,.01)
	check(unit.special.progression_v2.get("convoy_left",0)==3,"continuous eligible movement can rearm at eighteen-second interval")
	await finish()
