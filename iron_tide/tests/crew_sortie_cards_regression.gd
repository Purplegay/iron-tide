extends "res://tests/electric_cards_regression.gd"

func impact(gun,target) -> float:
	var before:float=target.hp
	var shot:=Projectile.new()
	shot.setup(gun.position,target,{"damage":100.0,"attack_type":"bullet"},100.0,{},gun.side,gun)
	battle.projectiles_root.add_child(shot)
	shot._explode()
	return before-target.hp

func exercise(mode:String) -> void:
	start(mode);battle.fog=null
	BattleRequest.combat_context.bonuses=MatchRules.neutral_bonuses()
	BattleRequest.combat_context.unit_bonus={}
	for rank in 4:
		equip("BFRT","",Cards.GUARD,rank)
		var carrier=make("BFRT","ally",Vector2(1200,1200))
		var crew:Array=[]
		for i in 5:
			var passenger=make("E1","ally",carrier.position)
			carrier.logistics.passengers.append(passenger);passenger.set_stowed(carrier)
			crew.append(passenger)
		var target=make("HTNK","enemy",Vector2(1250,1200))
		var boosted:float=[110,115,120,125][rank] if mode==MatchRules.EXTENDED else 100
		check(impact(crew[0],target)==100 and impact(crew[0],target)==100,prefix+"same passenger cannot trigger rank "+str(rank))
		check(is_equal_approx(impact(crew[1],target),boosted),prefix+"second different passenger boosts actual projectile impact")
		for i in range(2,5):check(impact(crew[i],target)==100,prefix+"five passengers share cooldown; no stacking "+str(i))
		Cards.tick(carrier,2.99)
		check(impact(crew[0],target)==100,prefix+"cooldown has not ended early")
		Cards.tick(carrier,0.02)
		check(impact(crew[0],target)==100 and is_equal_approx(impact(crew[1],target),boosted),prefix+"new pair can trigger after three seconds")
		Cards.tick(carrier,3.01)
		impact(crew[0],target);Cards.tick(carrier,2.01)
		check(impact(crew[1],target)==100,prefix+"hits more than two seconds apart do not pair")
		carrier.special.erase(Cards.CREW)
		var building=battle._place_building("NAPOWR","enemy",Vector2(1700,1700),true)
		building.hp=100000;building.max_hp=100000
		check(impact(crew[0],building)==100 and is_equal_approx(impact(crew[1],building),boosted),prefix+"building damage uses same crew rule")
		check(impact(crew[0],target)==100 and is_equal_approx(impact(crew[1],target),boosted),prefix+"per-target cooldowns are independent")
		carrier.special.erase(Cards.CREW)
		impact(crew[0],target)
		var snapshot=BattleSaves.Snapshot.new()
		var saved:Dictionary=snapshot.capture(battle)
		check(snapshot.error.is_empty(),prefix+"crew target and passenger references serialize")
		snapshot.restore(battle,saved)
		carrier=battle.units.filter(func(u):return u.unit_id=="BFRT")[0]
		crew=carrier.logistics.passengers
		target=battle.units.filter(func(u):return u.unit_id=="HTNK")[0]
		check(is_equal_approx(impact(crew[1],target),boosted),prefix+"readback restores pending pair")
		if mode==MatchRules.EXTENDED:
			check(carrier.special[Cards.CREW][target].cooling,prefix+"pair transitions to shared cooldown")
			carrier.special.erase(Cards.CREW);impact(crew[0],target)
			crew[0].set_stowed(null)
			check(impact(crew[1],target)==100,prefix+"unloaded passenger cannot complete pair")
		clear_units()
	for id in ["ORCA","BEAG"]:
		for rank in 4:
			equip(id,"",Cards.STRIDE,rank)
			var plane=make(id,"ally",Vector2(1200,1200))
			var home=battle._place_building("GAAIRC","ally",Vector2(2000,1200),true)
			home._buildup_play=-1
			plane.logistics.home=home;plane.logistics.air_lift=1;plane.logistics.ammo=0;plane.logistics.air_state="returning"
			var factor:=1.0+float([.08,.10,.12,.14][rank]) if mode==MatchRules.EXTENDED else 1.0
			check(is_equal_approx(plane.flight.max_speed(),plane.move_speed*factor),prefix+"empty return top speed "+id+str(rank))
			plane.hull_angle=0;plane.velocity=Vector2.RIGHT*plane.flight.max_speed()
			plane.flight.travel(Vector2(2200,1200),0.1)
			check(is_equal_approx(plane.velocity.length(),plane.move_speed*factor),prefix+"real flight consumes return speed")
			for state in ["flying","rearming","parked"]:
				plane.logistics.air_state=state
				check(Cards.return_speed(plane)==1,prefix+"no bonus in "+state)
			plane.logistics.air_state="returning";plane.logistics.ammo=1
			check(Cards.return_speed(plane)==1,prefix+"partial ammo return unboosted")
			plane.logistics.ammo=0;plane.logistics.air_lift=0
			check(Cards.return_speed(plane)==1,prefix+"touchdown ends bonus")
			plane.logistics.air_lift=1;plane.logistics.home=null
			check(Cards.return_speed(plane)==1,prefix+"no airfield destination no bonus")
			clear_units()
	if mode==MatchRules.EXTENDED:
		for id in ["SHK","TTNK","R3TESLA"]:
			equip(id,Cards.PULSE,"",0)
			var actor=make(id,"ally",Vector2(1200,1200))
			check(actor.use_ability(UnitSkillLayout.index(actor,1)),"each electric sibling can cast pulse "+id)
			clear_units()
		var legacy=UnitSkillLayout.normalize("E1",{"active":[Cards.PULSE],"passive":Cards.GUARD})
		check(legacy.active==[""] and legacy.passive=="","old incompatible loadout filtered without deleting ownership")
		equip("BFRT","",Cards.GUARD,3)
		BattleRequest.combat_context.card_strength_overrides[Cards.GUARD]=1.6
		var fortress=make("BFRT","ally",Vector2(1200,1200))
		check(is_equal_approx(fortress.passive.value,0.25),"new production in legacy battle uses saved rank with redesigned curve")
		fortress.passive={"id":Cards.GUARD,"name":"接地护甲","value":0.16}
		var soldier=make("E1","ally",Vector2(1300,1200))
		soldier.passive=fortress.passive.duplicate()
		var pulse:=Ability.new();pulse.setup(GameData.get_skill(Cards.PULSE));soldier.skills.append(pulse)
		soldier.add_buff("electric_stride",4,0.14)
		var codec=BattleSaves.Snapshot.new()
		var saved:Dictionary=codec.capture(battle)
		codec.restore(battle,saved)
		fortress=battle.units.filter(func(u):return u.unit_id=="BFRT")[0]
		soldier=battle.units.filter(func(u):return u.unit_id=="E1")[0]
		check(fortress.passive.name=="乘员协同" and is_equal_approx(fortress.passive.value,0.25),"old battle passive refreshed without losing saved rank")
		check(soldier.passive.is_empty() and UnitSkillLayout.find(soldier,Cards.PULSE)<0 and not soldier.has_buff("electric_stride"),"legacy incompatible equipment and retired buff removed on snapshot restore")
		clear_units()
	await finish()
