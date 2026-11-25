extends RefCounted
const Auto=preload("res://scripts/units/auto_w.gd")
const Drone=preload("res://scripts/units/expansion_2_drone.gd")

static func run(t) -> void:
	for id in Auto.Maneuvers.SUPPORTED:
		t.check(Auto.supported(id) and not Auto.MANUAL_ONLY.has(id) and not Auto.hint(id).is_empty(),"maneuver policy registered "+id)
	buoys(t)
	pounce(t)
	breather(t)

static func gates(t,actor) -> void:
	var ab:Ability=actor.ability_at(UnitSkillLayout.index(actor,1))
	for gate in ["off","cooldown","paused","manual_pick","stunned","frozen"]:
		match gate:
			"off":t.battle.allied_state.auto_w_preferences={actor.unit_id:false}
			"cooldown":ab.cd_left=3
			"paused":t.battle.paused=true
			"manual_pick":t.battle.cast_slot=1
			"stunned":actor._stun_timer=2
			"frozen":actor.special.chrono_left=1
		t.check(not Auto.evaluate(actor),"maneuver respects "+gate+" "+ab.id)
		t.battle.allied_state.auto_w_preferences={};ab.cd_left=0;t.battle.paused=false;t.battle.cast_slot=-1;actor._stun_timer=0;actor.special.erase("chrono_left")

static func buoys(t) -> void:
	t.battle.water_rects=[Rect2(600,600,1800,1300)];t.battle.path_service.set_water(t.battle.water_rects)
	var actor=t.make("DEST","ap_buoy")
	var hidden=t.make("SUB","","enemy",actor.position+Vector2(550,0))
	hidden.special.erase("dive_remaining")
	t.arm(actor,hidden)
	t.check(not t.battle.actor_visible_to(actor.side,hidden,actor),"submarine outside native sonar is truly hidden")
	t.check(not Auto.evaluate(actor) and not actor.special.has("buoy_left"),"buoy never aims at hidden current target")
	Auto.record_hit(actor,10,hidden)
	t.check(not Auto.evaluate(actor),"hidden attacker identity does not reveal its coordinates to buoy")
	var known=t.make("SUB","","enemy",actor.position+Vector2(250,0))
	known.special.erase("dive_remaining")
	t.check(t.battle.actor_visible_to(actor.side,known,actor),"closer submarine is a real sonar contact")
	gates(t,actor)
	var destination:Vector2=actor.move_target
	t.check(Auto.evaluate(actor) and actor.special.buoy_point==known.position,"buoy chooses visible contact instead of hidden selected target")
	t.check(actor.attack_target==hidden and actor.move_target==destination,"buoy preserves main target and route")
	var ab:Ability=actor.ability_at(UnitSkillLayout.index(actor,1));ab.cd_left=0
	var point:Vector2=actor.special.buoy_point;known.position+=Vector2(30,0)
	t.check(not Auto.evaluate(actor) and actor.special.buoy_point==point,"active buoy is not replaced when enemy moves")
	var elapsed:float=float(actor.special.buoy_left)+.1
	Unit.FactionCards.tick(actor,elapsed);ab.tick(elapsed)
	t.arm(actor,known)
	t.check(Auto.evaluate(actor) and actor.special.buoy_point==known.position,"expired buoy may reacquire current visible target")
	elapsed=float(actor.special.get("buoy_left",0))+.1
	Unit.FactionCards.tick(actor,elapsed);ab.tick(elapsed);ab.cd_left=0
	known.position=actor.position+Vector2(800,0);NavalContact.surface(known)
	t.check(not Auto.evaluate(actor),"visible submarine beyond cast range does not waste W")
	t.battle.allied_state.auto_w_preferences={"DEST":false}
	t.check(actor.use_ability(UnitSkillLayout.index(actor,1),actor.position+Vector2(80,0)),"manual buoy still accepts player water position with Auto off")
	t.clear_actors();t.battle.allied_state.auto_w_preferences={};t.battle.water_rects=[];t.battle.path_service.set_water([])

static func pounce(t) -> void:
	var actor=t.make("DRON","ap_lure_pounce")
	var target=t.make("HTNK","","enemy",actor.position+Vector2(80,0))
	actor.attack_target=target;actor.fire_stance="free"
	t.check(not Auto.evaluate(actor),"ambient drone acquisition does not commit W")
	actor.order_target(target,false,false)
	t.check(actor.attack_ordered and not actor.attack_move,"real explicit drone attack command is recognized")
	target.position=actor.position+Vector2(1200,0)
	t.check(not Auto.evaluate(actor),"drone saves short buff during long approach")
	target.position=actor.position+Vector2(80,0)
	target.special.echo_cloaked=true;t.check(not Auto.evaluate(actor),"drone rejects hidden attack target");target.special.erase("echo_cloaked")
	actor.attack_move=true;t.check(not Auto.evaluate(actor),"attack move does not independently commit pounce");actor.attack_move=false
	gates(t,actor)
	var destination:Vector2=actor.move_target;var position:Vector2=actor.position
	t.check(Auto.evaluate(actor) and Drone.invulnerable(actor),"near explicit target starts real acceleration and entry guard")
	t.check(actor.move_target==destination and actor.position==position and actor.attack_target==target,"pounce leaves chase command and target intact")
	actor.ability_at(UnitSkillLayout.index(actor,1)).cd_left=0
	t.check(not Auto.evaluate(actor),"active pounce cannot repeat")
	t.clear_actors()

static func breather(t) -> void:
	for type in ["E1","E2","GGI"]:
		var actor=t.make(type,"ap_battle_breather")
		var enemy=t.make("HTNK","","enemy",actor.position+Vector2(100,0))
		actor.order_move(actor.position+Vector2(-250,0));actor.velocity=Vector2(-25,0)
		t.check(not Auto.evaluate(actor),"uninjured ordinary movement does not stop fire "+type)
		actor.hp-=100;Auto.record_hit(actor,100,enemy)
		actor.attack_move=true;t.check(not Auto.evaluate(actor),"advance command cannot trigger retreat buff "+type);actor.attack_move=false
		actor.attack_ordered=true;t.check(not Auto.evaluate(actor),"explicit attack cannot trigger retreat buff "+type);actor.attack_ordered=false
		actor.velocity=Vector2.ZERO;t.check(not Auto.evaluate(actor),"stationary wounded infantry retains W "+type);actor.velocity=Vector2(-25,0)
		actor.move_target=actor.position+Vector2(250,0);t.check(not Auto.evaluate(actor),"moving toward attacker is not retreat "+type);actor.move_target=actor.position+Vector2(-250,0)
		enemy.special.echo_cloaked=true;t.check(not Auto.evaluate(actor),"retreat never reads hidden attacker position "+type);enemy.special.erase("echo_cloaked")
		actor.special.auto_w_hit_left=0;t.check(not Auto.evaluate(actor),"old wounds alone cannot start retreat buff "+type);Auto.record_hit(actor,100,enemy)
		gates(t,actor)
		var destination:Vector2=actor.move_target
		t.check(Auto.evaluate(actor) and actor.special.get("progression_v2",{}).has("breather_left"),"actual recent-injury retreat enables breather "+type)
		t.check(actor.move_target==destination and not actor.attack_ordered and not actor.attack_move,"breather preserves ordinary retreat order "+type)
		t.check(not preload("res://scripts/units/progression_expansion_2.gd").can_attack(actor),"real retreat buff prevents new fire "+type)
		actor.ability_at(UnitSkillLayout.index(actor,1)).cd_left=0;t.check(not Auto.evaluate(actor),"active breather does not restart "+type)
		t.clear_actors()
