extends RefCounted
const Auto=preload("res://scripts/units/auto_w.gd")
const Extra=preload("res://tests/auto_w_expansion_cases.gd")
const POSITIONAL=["ap_tanya_breach","ap_boris_corridor","ap_leizhu_court","ap_prism_cross"]

static func run(t) -> void:
	for row in [["TANY","ap_tanya_breach"],["BORIS","ap_boris_corridor"],["TTNK","ap_leizhu_court"],["SREF","ap_prism_cross"],["SHK","ap_overload_seal"],["V3","ap_tractor_warhead"],["SNIPE","ap_observer_line"],["HYD","ap_gun_ballast"]]:
		var id:String=row[1]
		var hero:bool=row[0] in ["TANY","BORIS","TTNK"]
		if row[0]=="HYD":
			t.battle.water_rects=[Rect2(600,600,1300,1300)];t.battle.path_service.set_water(t.battle.water_rects)
		var actor=Extra.hero(t,row[0],id) if hero else t.make(row[0],id)
		if row[0] in ["TANY","BORIS"]:preload("res://scripts/units/expansion_2_commandos.gd").install(actor)
		if row[0]=="TTNK":actor.special.leizhu={"quiet":0.0,"marks":{},"side":actor.side}
		var enemy=t.make("DEST" if row[0]=="HYD" else "E2" if row[0]=="SNIPE" else "HTNK","","enemy",actor.position+Vector2(180,0))
		if row[0]=="V3":enemy.position=actor.position+Vector2(maxf(330,actor.min_range+30),0)
		t.check(Auto.supported(id) and not Auto.MANUAL_ONLY.has(id) and not Auto.hint(id).is_empty(),"new tactical W has auto policy and hint "+id)
		t.check(not Auto.evaluate(actor),"idle tactical W preserves resource "+id)
		t.arm(actor,enemy)
		if id=="ap_overload_seal":
			t.check(not Auto.evaluate(actor),"seal does not waste on idle enemy")
			t.arm(enemy,actor)
		var index:int=UnitSkillLayout.index(actor,1)
		var ab:Ability=actor.ability_at(index)
		for gate in ["move_intent","moving","hold_fire","hidden","cooldown","off","paused","manual_cast","stun"]:
			match gate:
				"move_intent":actor.has_move_order=true
				"moving":actor.velocity=Vector2(30,0)
				"hold_fire":actor.fire_stance="none";actor.attack_ordered=false
				"hidden":enemy.special.echo_cloaked=true
				"cooldown":ab.cd_left=5
				"off":t.battle.allied_state.auto_w_preferences={row[0]:false}
				"paused":t.battle.paused=true
				"manual_cast":t.battle.cast_slot=1
				"stun":actor._stun_timer=2
			t.check(not Auto.evaluate(actor),"tactical respects "+gate+" "+id)
			actor.has_move_order=false;actor.velocity=Vector2.ZERO;actor.fire_stance="free";actor.attack_ordered=true
			enemy.special.erase("echo_cloaked");ab.cd_left=0;t.battle.allied_state.auto_w_preferences={};t.battle.paused=false;t.battle.cast_slot=-1;actor._stun_timer=0
		if id in POSITIONAL:
			enemy.velocity=Vector2(15,0)
			t.check(not Auto.evaluate(actor),"delayed area does not guess moving target "+id)
			enemy.velocity=Vector2.ZERO;enemy.has_move_order=true
			t.check(not Auto.evaluate(actor),"delayed area rejects pending target movement "+id)
			enemy.has_move_order=false
			var at:Vector2=enemy.position;enemy.position+=Vector2(3000,0)
			t.check(not Auto.evaluate(actor),"area rejects out-of-range target "+id)
			enemy.position=at
			enemy.side=actor.side;t.check(not Auto.evaluate(actor),"area rejects friendly target "+id);enemy.side="enemy"
			enemy.is_air=true;t.check(not Auto.evaluate(actor),"area rejects airborne target "+id);enemy.is_air=false
		if id=="ap_gun_ballast":
			actor.hp=actor.max_hp*.69;t.check(not Auto.evaluate(actor),"low health ship retains defense and speed")
			actor.hp=actor.max_hp*.7
		var at:Vector2=actor.position;var destination:Vector2=actor.move_target
		t.check(Auto.evaluate(actor),"real automatic cast succeeds "+id,[actor.special,Auto.firing_soon(actor),actor.ability_ready(index)])
		t.check(actor.position==at and actor.move_target==destination and actor.attack_target==enemy,"automatic W preserves location route and main target "+id)
		t.check(ab.cd_left>0 or actor.special.get("commando_hero_v2",{}).has("corridor_call"),"automatic cast consumes cooldown or begins real channel "+id)
		t.check(not Auto.evaluate(actor),"automatic cast cannot repeat immediately "+id)
		if id in ["ap_observer_line","ap_overload_seal","ap_tractor_warhead"]:
			ab.cd_left=0;t.check(not Auto.evaluate(actor),"existing tactical state prevents replacement even after cooldown reset "+id)
		t.clear_actors()
		t.battle.allied_state.erase("leizhu_courts");t.battle.allied_state.erase("expansion_overload_targets")
		t.battle.water_rects=[];t.battle.path_service.set_water([])
	tractor_carriers(t)

static func tractor_carriers(t) -> void:
	for type in ["DRED","SCHP"]:
		if type=="DRED":
			t.battle.water_rects=[Rect2(600,600,650,1300)];t.battle.path_service.set_water(t.battle.water_rects)
		var actor=t.make(type,"ap_tractor_warhead")
		var enemy=t.make("HTNK","","enemy",actor.position+Vector2(maxf(450,actor.min_range+30),0))
		t.arm(actor,enemy)
		if type=="SCHP":
			t.check(not Auto.evaluate(actor) and not actor._deployed,"auto tractor never deploys helicopter")
			actor.logistics.air_lift=0
			t.check(actor.set_deployed(true,false),"player deployment starts")
			t.check(not Auto.evaluate(actor),"auto tractor waits for helicopter deployment animation")
			actor.logistics.SiegeChopper.tick(actor,actor.logistics.SiegeChopper.duration()+.01)
			t.arm(actor,enemy)
		actor._cd_timer=2;t.check(not Auto.evaluate(actor),"tractor waits for next actual volley "+type);actor._cd_timer=0
		t.check(Auto.evaluate(actor) and actor.special.get("progression_v2",{}).has("tractor_arm"),"tractor auto arms carrier "+type,[Auto.firing_soon(actor),actor.attack_range,actor.min_range,actor._deployed])
		t.clear_actors();t.battle.water_rects=[];t.battle.path_service.set_water([])
