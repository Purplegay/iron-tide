extends "res://tests/ground_control_regression.gd"
const Soviet = preload("res://scripts/units/soviet_specials.gd")

func exercise(mode:String) -> void:
	start(mode)
	battle.fog=null
	var target=battle._place_building("GAWEAP","enemy",Vector2(1400,1400),true)
	target._buildup_play=-1
	var boris=battle.spawn_unit("BORIS","ally",Vector2(1250,1400))
	activate(boris)
	boris.attack_target=target;boris.attack_ordered=true
	var arrivals:Array=[]
	for rank in [-1,0,1,2,3]:
		BattleRequest.combat_context.native_training_version=4
		BattleRequest.combat_context.unit_talents={"BORIS":{} if rank<0 else {"native_arrival":rank}}
		target.special.erase("airstrike_mark")
		Soviet.designate(boris,target)
		var jets:Array=target.special.airstrike_mark.jets
		for jet in jets: activate(jet)
		var jet=jets[0]
		var fraction:float=1.0-0.125*(rank+1) if mode==MatchRules.EXTENDED else 1.0
		check(is_equal_approx(jet.special.strike_run.inbound_speed_factor,1.0/fraction),prefix+"snapshot arrival factor rank "+str(rank))
		check(is_equal_approx(boris.special.airstrike_cd,100.0/15.0),prefix+"new training does not reduce recharge")
		var elapsed:=0.0
		while not jet.special.strike_run.outbound and elapsed<90:
			Soviet.fly_mig(jet,0.01)
			elapsed+=0.01
		arrivals.append(elapsed)
		check(jet.special.strike_run.outbound and jet.special.strike_run.ammo==0,prefix+"actual arrival fires missiles rank "+str(rank))
		check(absf(elapsed-float(arrivals[0])*fraction)<0.02,prefix+"actual arrival time follows bounded reduction rank "+str(rank))
		var before:Vector2=jet.position
		Soviet.fly_mig(jet,0.01)
		check(absf(jet.position.distance_to(before)-jet.move_speed*0.01)<0.001,prefix+"return flight remains original speed")
		for member in jets:
			battle.units.erase(member);member.free()
		Soviet.advance_sortie_reload(boris,0.1)
		check(is_equal_approx(boris.special.airstrike_cd,100.0/15.0),prefix+"last jet leaving starts unchanged recharge")
	# Old battles preserve the already-frozen recharge benefit, with normal inbound speed.
	BattleRequest.combat_context.native_training_version=2
	boris.skill_power=2.2
	target.special.erase("airstrike_mark")
	Soviet.designate(boris,target)
	var legacy:Array=target.special.airstrike_mark.jets
	for jet in legacy: activate(jet)
	check(legacy[0].special.strike_run.inbound_speed_factor==1.0,prefix+"v2 saved rules keep original inbound speed")
	check(is_equal_approx(boris.special.airstrike_cd,100.0/15.0/(2.0 if mode==MatchRules.EXTENDED else 1.0)),prefix+"v2 saved rules keep previous recharge")
	for jet in legacy:
		battle.units.erase(jet);jet.free()
	BattleRequest.combat_context.native_training_version=3
	target.special.erase("airstrike_mark")
	Soviet.designate(boris,target)
	var codec=BattleSaves.Snapshot.new()
	var snapshot:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),prefix+"inbound wing snapshot captures")
	codec.restore(battle,snapshot)
	var restored=battle.units.filter(func(u):return u.unit_id=="BPLN" and u.special.has("strike_run"))
	check(not restored.is_empty() and is_equal_approx(restored[0].special.strike_run.inbound_speed_factor,2.0 if mode==MatchRules.EXTENDED else 1.0),prefix+"readback keeps frozen arrival factor")
	await finish()
