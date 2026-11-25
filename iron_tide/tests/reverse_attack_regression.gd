extends "res://tests/electric_cards_regression.gd"
const Reverse = preload("res://scripts/units/reverse_attack.gd")
const Hotkeys = preload("res://scripts/ui/battle_hotkeys.gd")

func exercise(mode:String) -> void:
	start(mode);battle.fog=null
	await get_tree().physics_frame
	Hotkeys.bindings=Hotkeys.defaults();Hotkeys.loaded=true
	battle.paused=false;get_tree().paused=false;get_window().focus_entered.emit()
	var cfg:=ConfigFile.new()
	for id in Hotkeys.ACTIONS:
		if id != Reverse.ID:cfg.set_value("keys",id,KEY_D if id=="deploy" else Hotkeys.ACTIONS[id][1])
	var migrated:=Hotkeys.read_bindings(cfg)
	check(migrated.deploy==KEY_J and migrated.reverse_attack==KEY_D,"legacy deploy D migrates to J with reverse D")
	cfg.set_value("keys","deploy",KEY_B)
	migrated=Hotkeys.read_bindings(cfg)
	check(migrated.deploy==KEY_B and migrated.reverse_attack==KEY_D,"custom deploy key preserved")
	var origin:=Vector2(1400,1400)
	for id in ["MTNK","HTNK","E1"]:
		for direction in 4:
			var tank=make(id,"ally",origin)
			tank.hp=tank.max_hp*0.5;tank.hull_angle=0;tank.turret_angle=0
			var destination:Vector2=origin+Vector2.from_angle(direction*PI/2)*240
			battle.select_unit(tank,false)
			check(Reverse.issue(battle,destination),id+" accepts reverse "+str(direction))
			var backward:=true
			for frame in 1800:
				if not tank.special.has(Reverse.ID):break
				var before:Vector2=tank.position
				tank._physics_process(1.0/60)
				var motion:Vector2=tank.position-before
				if motion.length()>0.01:backward=backward and motion.normalized().dot(-Vector2.from_angle(tank.hull_angle))>0.98
			check(backward and tank.position.distance_to(destination)<tank.ARRIVE_EPS+1 and not tank.special.has(Reverse.ID),id+" arrives rearward "+str(direction),tank.position)
			check(not tank.special.has("reverse_heal_left") and tank.hp==tank.max_hp*0.5,"generic reverse grants no talent healing")
			clear_units()
	var tank=make("MTNK","ally",origin)
	var enemy=make("HTNK","enemy",origin+Vector2(130,0))
	tank.attack_target=enemy;tank.attack_ordered=true
	battle.select_unit(tank,false)
	press(KEY_D)
	check(battle.command_mode==Reverse.ID,"D arms reverse command through HUD input")
	press(KEY_ESCAPE)
	check(battle.command_mode=="","Escape cancels reverse targeting")
	battle.paused=true;press(KEY_D);battle.paused=false
	check(battle.command_mode=="","paused battle rejects D")
	Hotkeys.modal_count=1;press(KEY_D);Hotkeys.modal_count=0
	check(battle.command_mode=="","key editor modal rejects D")
	Hotkeys.bindings[Reverse.ID]=KEY_B
	press(KEY_D)
	check(battle.command_mode=="","remapping removes original D")
	press(KEY_B)
	check(battle.command_mode==Reverse.ID,"custom reverse key reaches command")
	Hotkeys.bindings=Hotkeys.defaults()
	battle._issue_command_at(origin-Vector2(400,0))
	check(battle.command_mode=="" and tank.special.has(Reverse.ID),"left ground confirmation issues reverse")
	var fired:=false
	for frame in 30:
		tank._physics_process(1.0/60)
		fired=fired or tank._cd_timer>0
	check(fired and tank.position.x<origin.x-5 and tank.has_move_order,"fires while retreating without stopping or chasing")
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle)
	var instance:int=codec.ids[tank]
	check(codec.error.is_empty(),"reverse save captures")
	codec.restore(battle,snapshot);battle.paused=false;get_tree().paused=false
	tank=codec.objects[instance]
	tank.process_mode=Node.PROCESS_MODE_ALWAYS;tank.set_process(false);tank.set_physics_process(false)
	check(tank.special.has(Reverse.ID),"reverse survives save restoration")
	for frame in 1500:
		if not tank.special.has(Reverse.ID):break
		tank._physics_process(1.0/60)
	check(tank.position.distance_to(origin-Vector2(400,0))<tank.ARRIVE_EPS+1,"restored reverse arrives")
	battle.select_unit(tank,false)
	for replacement in ["stop","move","guard","target","talent"]:
		Reverse.issue(battle,origin)
		match replacement:
			"stop":tank.order_stop()
			"move":tank.order_move(origin)
			"guard":tank.order_guard()
			"target":tank.order_target(battle.spawn_unit("HTNK","enemy",origin+Vector2(180,0)),false,false)
			"talent":
				if mode==MatchRules.RA2:continue
				BattleRequest.combat_context.get_or_add("unit_talents",{}).MTNK={Unit.YRTalents.REVERSE:3}
				Unit.YRTalents.start_reverse(tank,tank.position-Vector2(80,0))
		check(not tank.special.has(Reverse.ID),"replacement clears reverse: "+replacement)
	clear_units()
	var soldier=make("E1","ally",origin);battle.select_unit(soldier,false)
	press(KEY_J)
	check(soldier._deployed,"J retains deployment")
	press(KEY_J)
	check(not soldier._deployed,"J retains undeployment")
	clear_units()
	for id in ["AMCV","ENGINEER","ORCA","HARV"]:
		var actor=make(id,"ally",origin)
		check(not Reverse.ready(actor),"unsupported actor rejected: "+id)
		clear_units()
	tank=make("MTNK","ally",origin);battle.select_unit(tank,false)
	check(not Reverse.issue(battle,Vector2.INF) and not Reverse.issue(battle,Vector2(-10,0)),"invalid destinations rejected")
	var wall=battle._place_building("NAWALL","enemy",origin-Vector2(100,0),true)
	battle._refresh_pathing()
	check(Reverse.issue(battle,origin-Vector2(260,0)),"routes around wall")
	var crossed:=false
	for frame in 2400:
		if not tank.special.has(Reverse.ID):break
		tank._physics_process(1.0/60)
		crossed=crossed or tank.position.distance_to(wall.position)<15
	check(not crossed and tank.position.distance_to(origin-Vector2(260,0))<tank.ARRIVE_EPS+1,"wall remains solid and reverse reaches detour destination",tank.position)
	clear_units();await finish()

func press(key:int) -> void:
	var event:=InputEventKey.new();event.keycode=key;event.pressed=true
	screen.hud._input(event)
