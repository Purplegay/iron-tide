extends "res://tests/progression_expansion_2_naval_regression.gd"
const Aircraft=preload("res://scripts/units/expansion_2_aircraft.gd")
const Cards=preload("res://scripts/units/expansion_cards.gd")
var airfield

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for level in 4:
		await cycle(level)
		for id in ["ORCA","BEAG"]:await burning(level,id)
	await cycle_contract()
	await peregrine_cycles()
	await burning_boundaries()
	for level in 4:await flight_save_air(level)
	await talent_purchase()
	await classic_aircraft()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPANSION_2_AIRCRAFT_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func prepare_aircraft(level:int,card:String,first:=true) -> void:
	setup(level)
	for id in [Aircraft.LAST,Aircraft.BURN]:BattleRequest.combat_context.card_ranks[id]=level
	BattleRequest.combat_context.unit_talents.ORCA={Aircraft.FIRST:level} if first else {}
	for id in ["ORCA","BEAG"]:BattleRequest.combat_context.loadouts[id]={"active":[],"passive":card if id=="ORCA" or card==Aircraft.BURN else ""}
	airfield=battle._place_building("GAAIRC","ally",Vector2(1800,1600),true);airfield._buildup_play=-1;airfield.power=0
	battle.power_low=false

func refill(unit) -> void:
	unit.logistics.home=airfield;unit.logistics.dock_slot=0;unit.position=unit.logistics.dock_destination()
	unit.logistics.air_state="rearming";unit.logistics.air_lift=0;unit.logistics.reload_elapsed=0
	unit.logistics.tick_return(18)
	check(unit.logistics.ammo==unit.logistics.ammo_max and unit.logistics.air_state=="parked","native powered airfield fills and parks")
	unit.order_move(Vector2(1100,1100));unit.position=Vector2(1100,1100);unit.logistics.air_lift=1
	check(unit.logistics.air_state=="flying","real move order starts next sortie")

func air_shot(unit,target):
	check(normal_shot(unit,target),"native aircraft ordinary volley fires")
	var shots:=missiles(unit)
	check(not shots.is_empty(),"actual missile exists after normal launch")
	return shots[0] if not shots.is_empty() else null

func cycle(level:int) -> void:
	prepare_aircraft(level,Aircraft.LAST)
	var plane:=make("ORCA","ally",Vector2(1100,1100));var target:=make("HTNK","enemy",Vector2(1350,1100))
	var base_bonus:float=plane.bonuses.get("attack_bonus",1.0)
	var shot=air_shot(plane,target)
	if shot==null:await finish();return
	var add:float=[.12,.18,.24,.3][level]+[.08,.12,.16,.2][level]
	check(plane.logistics.ammo_max==1 and plane.logistics.ammo==0,"native single-round aircraft spends one real ammo")
	check(is_equal_approx(shot.attacker_bonus.attack_bonus,base_bonus+add),"first and last bonuses add rather than multiply "+str(level),[plane._active_weapon(),Aircraft.state(plane),shot.attacker_bonus])
	check(shot.attacker_bonus.get("expansion_air_cycle",{}).get("first",false) and shot.attacker_bonus.get("expansion_air_cycle",{}).get("last",false),"one native round is both first and last")
	var expected:=CombatMath.full_damage(plane._active_weapon(),target.armor,shot.attacker_bonus,null,target.ra2_armor,0,target)
	var before:float=target.hp;fly_missiles(plane)
	check(absf(before-target.hp-Ra2Damage.quantize(expected))<=1,"real missile damage consumes additive rank bonus",[before-target.hp,expected])
	check(not Aircraft.state(plane).air_first and not Aircraft.state(plane).air_last,"both qualifications are consumed exactly once")
	check(not normal_shot(plane,target),"empty native plane cannot shoot again")
	refill(plane)
	check(Aircraft.state(plane).air_cycle==2 and Aircraft.state(plane).air_first and Aircraft.state(plane).air_last,"real full reload creates second cycle")
	Aircraft.refill_complete(plane,0,1,1);check(Aircraft.state(plane).air_cycle==2,"duplicate full notification does not create another cycle")
	shot=air_shot(plane,target)
	check(shot!=null and is_equal_approx(shot.attacker_bonus.attack_bonus,base_bonus+add),"next fully reloaded sortie gains bonus again")
	fly_missiles(plane);await finish()

func cycle_contract() -> void:
	prepare_aircraft(3,Aircraft.LAST)
	var plane:=make("ORCA","ally",Vector2(1100,1100));var target:=make("HTNK","enemy",Vector2(1350,1100))
	# Shared callback contract for future multi-round airborne hero; no hero locomotion is simulated.
	plane.logistics.ammo_max=3;plane.logistics.ammo=1
	Aircraft.ground_ammo_spent(plane,3,1,false)
	check(not Aircraft.state(plane).air_first and Aircraft.state(plane).air_last,"W spends first qualification but preserves unspent final round")
	var shot=air_shot(plane,target)
	check(shot!=null and is_equal_approx(shot.attacker_bonus.attack_bonus,float(plane.bonuses.attack_bonus)+.3),"normal final round after W receives only last bonus")
	fly_missiles(plane)
	plane.logistics.ammo=1;Aircraft.refill_complete(plane,0,1,3)
	shot=air_shot(plane,target)
	check(shot!=null and is_equal_approx(shot.attacker_bonus.attack_bonus,float(plane.bonuses.attack_bonus)),"partial reload cannot farm first or final bonus")
	fly_missiles(plane)
	plane.logistics.ammo=3;Aircraft.refill_complete(plane,0,3,3)
	var cycle_id:int=Aircraft.state(plane).air_cycle
	plane.logistics.ammo=0;Aircraft.ground_ammo_spent(plane,3,0,false)
	check(not Aircraft.state(plane).air_first and not Aircraft.state(plane).air_last and not Aircraft.state(plane).has("air_pending"),"W emptying full magazine consumes both without bonus packet")
	var extra:Dictionary={"attack_bonus":1.0,"expansion_extra":true}
	Aircraft.shot(plane,target,extra)
	check(extra.attack_bonus==1.0 and not extra.has("expansion_air_cycle") and not extra.has("expansion_burning"),"explicit W shot never inherits old normal bonus or burn marker")
	Aircraft.refill_complete(plane,0,3,3);check(Aircraft.state(plane).air_cycle==cycle_id,"callback cannot claim full refill while actual magazine is empty")
	await finish()

func peregrine_cycles() -> void:
	const Hero=preload("res://scripts/units/peregrine.gd")
	const Loadouts=preload("res://scripts/rules/hero_loadouts.gd")
	for card in [Aircraft.LAST,Aircraft.BURN]:
		MetaProgress.reset_save()
		check(MetaProgress.unlock_skill(card) and Loadouts.equip(MetaProgress,"ORCA","passive",card),"hero independently equips owned ordinary aircraft passive "+card)
		MetaProgress.load_save()
		check(Loadouts.effective(MetaProgress,"ORCA").passive==card,"hero aircraft passive persists on disk "+card)
		prepare_aircraft(3,card)
		var plane:=make("ORCA","ally",Vector2(1100,1100));var target:=make("HTNK","enemy",Vector2(1350,1100))
		Hero.promote(MetaProgress,battle,plane)
		check(Hero.active(plane) and plane.passive.get("id")==card and plane.logistics.ammo==4,"real hero promotion installs four-round magazine and ordinary passive")
		var base_bonus:float=plane.bonuses.attack_bonus
		for i in 4:
			var shot=air_shot(plane,target)
			var extra:float=.2 if i==0 else (.3 if i==3 and card==Aircraft.LAST else 0.0)
			check(shot!=null and is_equal_approx(shot.attacker_bonus.attack_bonus,base_bonus+extra),"real hero first and final round bonuses "+card+str(i))
			fly_missiles(plane)
			if card==Aircraft.BURN:
				check(Aircraft.state(plane).burning_hits==(i+1)%2,"Lv3 hero accumulates every two ordinary direct hits")
				check(battle.allied_state.get(Aircraft.FIELDS,[]).size()==(0 if i==0 else 1),"Lv3 hero second hit creates field and fourth replaces it")
		check(plane.logistics.ammo==0 and not Aircraft.state(plane).air_first and not Aircraft.state(plane).air_last,"hero complete magazine consumes both qualifications")
		Hero.tick(plane,8)
		check(plane.logistics.ammo==1 and Aircraft.state(plane).air_cycle==1,"real airborne single-round refill does not refresh cycle")
		var shot=air_shot(plane,target)
		check(shot!=null and is_equal_approx(shot.attacker_bonus.attack_bonus,base_bonus),"hero firing one partially reloaded round cannot farm bonuses")
		fly_missiles(plane)
		Hero.tick(plane,31.9)
		check(plane.logistics.ammo==3 and not Aircraft.state(plane).air_first,"hero refill must actually reach capacity")
		Hero.tick(plane,.100001)
		check(plane.logistics.ammo==4 and Aircraft.state(plane).air_cycle==2 and Aircraft.state(plane).air_first and Aircraft.state(plane).air_last,"real airborne full refill refreshes both qualifications exactly once")
		Hero.tick(plane,100)
		check(Aircraft.state(plane).air_cycle==2 and plane.logistics.home==null and plane.logistics.air_state=="flying","full hero stays airborne without duplicate cycle or airport reservation")
		var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle)
		BattleSaves.Snapshot.new().restore(battle,snapshot)
		plane=battle.units.filter(func(u):return u.unit_id=="ORCA")[0];target=battle.units.filter(func(u):return u.unit_id=="HTNK")[0]
		check(Hero.active(plane) and Aircraft.state(plane).air_cycle==2 and plane.logistics.ammo==4,"combined hero and ordinary cycle survive snapshot")
		shot=air_shot(plane,target)
		check(shot!=null and is_equal_approx(shot.attacker_bonus.attack_bonus,float(plane.bonuses.attack_bonus)+.2),"restored full hero receives next cycle first-shot bonus")
		fly_missiles(plane)
		await finish()

func burning(level:int,id:String) -> void:
	prepare_aircraft(level,Aircraft.BURN,false)
	var plane:=make(id,"ally",Vector2(1100,1100));var target:=make("HTNK","enemy",Vector2(1350,1100))
	var nearby:=make("FV","enemy",Vector2(1390,1100));var outside:=make("FV","enemy",Vector2(1406,1100));var ally:=make("E1","ally",Vector2(1350,1130))
	var shot
	var limit:=2 if level==3 else 3
	check(plane.logistics.ammo_max==1,"ordinary aircraft has one native missile per full magazine "+id)
	for i in limit:
		shot=air_shot(plane,target);fly_missiles(plane)
		check(int(Aircraft.state(plane).get("burning_hits",0))==(i+1)%limit,"only primary direct impact counts once despite native splash "+id+str(level)+str(i))
		check(battle.allied_state.get(Aircraft.FIELDS,[]).size()==(1 if i==limit-1 else 0),"field starts only on rank-specific cumulative hit threshold")
		var entry:Dictionary=Aircraft.entries(plane)[0]
		check(entry.limit==limit and entry.stacks==(i+1)%limit,"live status shows rank-specific cumulative counter")
		if i<limit-1:
			refill(plane)
			check(Aircraft.state(plane).burning_hits==i+1,"real airport full reload preserves cumulative hits")
	var field:Dictionary=battle.allied_state[Aircraft.FIELDS][0]
	var before:float=target.hp;var near_hp:float=nearby.hp;var far_hp:float=outside.hp;var ally_hp:float=ally.hp
	var expected:=Ra2Damage.quantize(CombatMath.full_damage(field.weapon,target.armor,field.bonus,null,target.ra2_armor,0,target))
	check(is_equal_approx(float(field.weapon.damage),plane._active_weapon().damage*[.15,.2,.25,.3][level]*.5),"half-second burn uses rank fraction of triggering attack snapshot")
	Cards.world_tick(battle,.49);check(target.hp==before,"no burn tick before half second")
	Cards.world_tick(battle,.01)
	check(is_equal_approx(before-target.hp,expected) and nearby.hp<near_hp,"first burn pulse hits each in-range ground target once",[before-target.hp,expected])
	check(outside.hp==far_hp and ally.hp==ally_hp,"one-cell boundary and friendly exclusion")
	check(Aircraft.state(plane).burning_hits==0,"burn damage never advances direct missile counter")
	Cards.world_tick(battle,2.5)
	check(is_equal_approx(before-target.hp,6*expected) and not battle.allied_state.has(Aircraft.FIELDS),"exactly six half-second pulses then expiry")
	check(battle.has_node("ExpansionFields"),"reuses world effect renderer")
	await finish()

func burning_boundaries() -> void:
	prepare_aircraft(3,Aircraft.BURN,false)
	var plane:=make("ORCA","ally",Vector2(1100,1100));var target:=make("HTNK","enemy",Vector2(1350,1100))
	var shot=air_shot(plane,target)
	shot.attacker_bonus.expansion_extra=true;fly_missiles(plane)
	check(int(Aircraft.state(plane).get("burning_hits",0))==0,"W and secondary extra projectiles cannot advance counter")
	refill(plane);shot=air_shot(plane,target);shot.target=null;shot.target_point=Vector2(2200,2200);shot._explode()
	check(int(Aircraft.state(plane).get("burning_hits",0))==0,"missed main target cannot count area-only detonation")
	for i in 2:refill(plane);air_shot(plane,target);fly_missiles(plane)
	var old:Dictionary=battle.allied_state[Aircraft.FIELDS][0]
	Cards.world_tick(battle,.5)
	check(old.next==1.0,"old burning zone resolves its first pulse before replacement")
	var old_damage:float=old.weapon.damage;var old_bonus:float=old.bonus.attack_bonus
	plane.bonuses.attack_bonus=5.0;plane.weapon=plane.weapon.duplicate(true);plane.weapon.damage*=2
	check(old.weapon.damage==old_damage and old.bonus.attack_bonus==old_bonus,"ongoing fire retains original attack snapshot")
	var second:=make("HTNK","enemy",Vector2(1350,1200))
	for i in 2:refill(plane);air_shot(plane,second);fly_missiles(plane)
	check(battle.allied_state[Aircraft.FIELDS].size()==1 and battle.allied_state[Aircraft.FIELDS][0].point==second.position,"Lv3 next second hit replaces rather than stacks own prior field")
	var old_target_hp:float=target.hp
	var replacement:Dictionary=battle.allied_state[Aircraft.FIELDS][0]
	var pulse_damage:=Ra2Damage.quantize(CombatMath.full_damage(replacement.weapon,second.armor,replacement.bonus,null,second.ra2_armor,0,second))
	var before:float=second.hp;plane.hp=0;Cards.world_tick(battle,.5)
	check(second.hp<before,"already created fire persists after source dies")
	Cards.world_tick(battle,2.5)
	check(is_equal_approx(before-second.hp,6*pulse_damage) and not battle.allied_state.has(Aircraft.FIELDS),"replacement zone finishes exactly six new pulses after source death")
	check(target.hp==old_target_hp,"replaced old zone never emits its five remaining pulses")
	await finish()

func flight_save_air(level:int) -> void:
	prepare_aircraft(level,Aircraft.BURN,true)
	var plane:=make("ORCA","ally",Vector2(1100,1100));var target:=make("HTNK","enemy",Vector2(1350,1100))
	var prior:=1 if level==3 else 2
	for i in prior:air_shot(plane,target);fly_missiles(plane);refill(plane)
	var shot=air_shot(plane,target)
	var bonus:float=shot.attacker_bonus.attack_bonus
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	plane=battle.units.filter(func(u):return u.unit_id=="ORCA")[0];target=battle.units.filter(func(u):return u.unit_id=="HTNK")[0]
	check(Aircraft.state(plane).burning_hits==prior and not Aircraft.state(plane).air_first and not Aircraft.state(plane).air_last,"snapshot preserves cumulative direct hits and spent cycle "+str(level))
	check(missiles(plane).size()==1 and missiles(plane)[0].attacker_bonus.attack_bonus==bonus,"in-flight snapshot retains first-shot damage without refreshing qualification")
	fly_missiles(plane);Cards.world_tick(battle,.7)
	check(battle.allied_state.get(Aircraft.FIELDS,[]).size()==1,"restored threshold missile creates exactly one zone "+str(level))
	snapshot=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	target=battle.units.filter(func(u):return u.unit_id=="HTNK")[0]
	var field:Dictionary=battle.allied_state[Aircraft.FIELDS][0];var before:float=target.hp
	var expected:=Ra2Damage.quantize(CombatMath.full_damage(field.weapon,target.armor,field.bonus,null,target.ra2_armor,0,target))
	check(is_equal_approx(field.age,.7) and field.next==1.0,"snapshot preserves burn phase not just remaining lifetime")
	Cards.world_tick(battle,2.3)
	check(is_equal_approx(before-target.hp,5*expected) and not battle.allied_state.has(Aircraft.FIELDS),"restored zone produces remaining five pulses without duplication")
	await finish()

func talent_purchase() -> void:
	MetaProgress.reset_save();MetaProgress.currency.cores=100000
	var quote:=MetaProgress.talent_unlock_quote("ORCA",Aircraft.FIRST)
	check(not quote.is_empty() and MetaProgress.unlock_unit_talent("ORCA",Aircraft.FIRST,quote.get("cost",-1)),"real aircraft talent unlock")
	for rank in 3:check(MetaProgress.upgrade_talent("ORCA",Aircraft.FIRST,rank),"real aircraft talent rank purchase "+str(rank))
	MetaProgress.load_save()
	check(MetaProgress.talent_rank("ORCA",Aircraft.FIRST,MetaProgress.unit_talents)==3,"aircraft talent survives permanent disk reload")

func classic_aircraft() -> void:
	start(MatchRules.RA2);battle.fog=null
	var plane:=make("ORCA","ally",Vector2(1100,1100));plane.passive=GameData.get_skill(Aircraft.LAST)
	var target:=make("HTNK","enemy",Vector2(1350,1100));var shot=air_shot(plane,target)
	check(shot!=null and not shot.attacker_bonus.has("expansion_air_cycle") and not plane.special.has(Aircraft.KEY),"classic aircraft ignores forced expansion cards")
	fly_missiles(plane);await finish()
