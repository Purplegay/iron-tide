extends "res://tests/peregrine_contract_regression.gd"
const Order=preload("res://scripts/units/peregrine_hunt_order.gd")
var input_view:SubViewport

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	input_view=SubViewport.new();input_view.size=Vector2i(1600,900);add_child(input_view)
	await get_tree().process_frame
	await click_and_fly()
	await instant_click()
	await resume_order()
	await cancel_orders()
	await invalid_targets()
	await follow_target()
	await building_target()
	await rejected_selection()
	await paused_control()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("PEREGRINE_HUNT_ORDER_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func boot(id:String,mode:=MatchRules.EXTENDED) -> void:
	super.boot(id,mode)
	screen.reparent(input_view)

func flying(hero) -> void:
	hero.process_mode=Node.PROCESS_MODE_ALWAYS
	hero.set_process(false);hero.set_physics_process(false)
	hero.set_fire_stance("none")

func click(hero,target) -> void:
	battle.select_unit(hero,false)
	var slot:=UnitSkillLayout.find(hero,PC.ACTIVE)
	check(battle.request_ability(slot)==-1,"actual W request enters targeting")
	battle.camera.position=target.position
	battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	var motion:=InputEventMouseMotion.new()
	motion.position=battle.get_global_transform_with_canvas()*target.art_center()
	input_view.push_input(motion,true)
	check(battle.get_global_mouse_position().is_equal_approx(target.art_center()),"viewport mouse maps to target artwork",battle.get_global_mouse_position())
	check(battle._pick_at(target.art_center(),false)==target,"visible enemy artwork resolves clicked actor")
	battle.confirm_cast()
	check(battle.cast_slot==-1,"confirmed target exits aiming")

func until_launch(hero) -> void:
	for frame in 1500:
		hero._physics_process(1.0/60)
		if battle.allied_state.has(PC.EVENTS):break
		if frame%30==0:await get_tree().physics_frame
	check(battle.allied_state.has(PC.EVENTS),"actual physics movement reaches range and launches",hero.position)

func click_and_fly() -> void:
	var hero=cards_hero();flying(hero)
	var target=victim("HTNK",hero.position+Vector2(850,0))
	await get_tree().physics_frame
	var start:Vector2=hero.position
	click(hero,target)
	check(hero.special.get(Order.KEY,{}).get("target")==target,"HUD selects target outside primary weapon range")
	check(hero.logistics.ammo==4 and ability(hero).cd_left==0 and not battle.allied_state.has(PC.EVENTS),"queued cast spends no ammo or cooldown")
	check(not hero.use_ability(UnitSkillLayout.find(hero,PC.ACTIVE),target.position),"automatic immediate cast cannot steal pending manual order")
	await until_launch(hero)
	check(hero.position.distance_to(start)>100 and PC.target_in_range(hero,target),"flight enters actual primary range")
	check(hero.logistics.ammo==2 and ability(hero).cd_left==38 and not hero.special.has(Order.KEY),"arrival spends exactly two rounds and starts cooldown once")
	check(battle.allied_state.get(PC.EVENTS,[]).size()==1,"one accepted order creates one salvo")
	if battle.allied_state.has(PC.EVENTS):
		check(battle.allied_state[PC.EVENTS][0].missiles.size()==4 and battle.allied_state[PC.EVENTS][0].missiles[0].target==target,"all four missiles retain clicked target")
	PC.world_tick(battle,4)
	check(target.hp<100000,"moving cast causes real target damage")
	await finish()

func instant_click() -> void:
	var hero=cards_hero();var target=victim("HTNK",hero.position+Vector2(150,0))
	var start:Vector2=hero.position
	click(hero,target)
	check(hero.position==start and hero.logistics.ammo==2 and ability(hero).cd_left==38,"in-range HUD click launches immediately without approach")
	check(not hero.special.has(Order.KEY),"instant cast leaves no pending movement")
	await finish()

func resume_order() -> void:
	var hero=cards_hero();flying(hero)
	var target=victim("HTNK",hero.position+Vector2(850,0))
	check(Order.request(hero,ability(hero),target),"queue before binary snapshot")
	for i in 30:hero._physics_process(1.0/60)
	var codec=BattleSaves.Snapshot.new()
	var file=FileAccess.open(output_dir.path_join("pending-hunt.bin"),FileAccess.WRITE)
	file.store_var(codec.capture(battle),false);file.close()
	file=FileAccess.open(output_dir.path_join("pending-hunt.bin"),FileAccess.READ)
	var snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot)
	hero=get_hero();flying(hero)
	target=battle.units.filter(func(u):return u.side=="enemy" and u.unit_id=="HTNK")[0]
	check(codec.error.is_empty() and hero.special.get(Order.KEY,{}).get("target")==target,"binary restore remaps pending target reference")
	check(hero.logistics.ammo==4 and ability(hero).cd_left==0,"restore keeps pending resources unspent")
	await get_tree().physics_frame
	await until_launch(hero)
	check(hero.logistics.ammo==2 and battle.allied_state.get(PC.EVENTS,[]).size()==1,"restored order launches exactly once")
	await finish()

func cancel_orders() -> void:
	for command in ["stop","move","guard","attack","patrol"]:
		var hero=cards_hero();var target=victim("HTNK",hero.position+Vector2(850,0))
		Order.request(hero,ability(hero),target)
		match command:
			"stop":hero.order_stop()
			"move":hero.order_move(hero.position+Vector2(0,300))
			"guard":hero.order_guard()
			"attack":hero.order_target(target,false,false)
			"patrol":hero.order_patrol(hero.position+Vector2(0,300))
		check(not hero.special.has(Order.KEY) and hero.logistics.ammo==4 and ability(hero).cd_left==0,"new command cancels unspent cast: "+command)
		await finish()

func invalid_targets() -> void:
	for reason in ["death","friendly","cloak","immune","freed","owner","ammo","fog"]:
		var hero=cards_hero();var target=victim("HTNK",hero.position+Vector2(850,0))
		Order.request(hero,ability(hero),target)
		match reason:
			"death":target._die()
			"friendly":target.side="ally"
			"cloak":target.special.echo_cloaked=true
			"immune":target.special.iron_left=1
			"freed":battle.units.erase(target);target.free()
			"owner":hero.side="enemy"
			"ammo":hero.logistics.ammo=1
			"fog":
				var fog=load("res://scripts/world/fog_of_war.gd").new();battle.add_child(fog);fog.setup(battle);battle.fog=fog
				for side in fog.visible_cells:fog.visible_cells[side].fill(0)
		var ammo:int=hero.logistics.ammo
		Order.tick(hero,1.0/60)
		check(not hero.special.has(Order.KEY) and not hero.has_move_order and not battle.allied_state.has(PC.EVENTS) and hero.logistics.ammo==ammo and ability(hero).cd_left==0,"invalidated target/order cancels without cost: "+reason)
		await finish()

func follow_target() -> void:
	var hero=cards_hero();flying(hero)
	var target=victim("HTNK",hero.position+Vector2(800,0))
	Order.request(hero,ability(hero),target)
	target.position+=Vector2(0,250)
	await get_tree().physics_frame
	await until_launch(hero)
	check(PC.target_in_range(hero,target),"approach follows target's latest position")
	await finish()

func building_target() -> void:
	var hero=cards_hero();flying(hero)
	var target=battle._place_building("NAPOWR","enemy",hero.position+Vector2(850,0),true)
	target._buildup_play=-1
	await get_tree().physics_frame
	click(hero,target)
	check(hero.special.get(Order.KEY,{}).get("target")==target,"building artwork selects distant structure")
	await until_launch(hero)
	check(hero.logistics.ammo==2 and PC.target_in_range(hero,target),"building cast uses footprint range and shared two-round cost")
	await finish()

func rejected_selection() -> void:
	var hero=cards_hero()
	for kind in ["friendly","air","neutral","concealed"]:
		var target=victim("ORCA" if kind=="air" else "HTNK",hero.position+Vector2(700,0))
		match kind:
			"friendly":target.side="ally"
			"air":target.logistics.air_lift=1
			"neutral":target.side="neutral"
			"concealed":target.special.echo_cloaked=true
		check(not Order.request(hero,ability(hero),target) and not hero.special.has(Order.KEY) and hero.logistics.ammo==4 and ability(hero).cd_left==0,"initial selection rejects "+kind)
		battle.units.erase(target);target.free()
	check(not Order.request(hero,ability(hero),null),"empty ground cannot create an approach order")
	await finish()

func paused_control() -> void:
	var hero=cards_hero();flying(hero)
	var target=victim("HTNK",hero.position+Vector2(850,0))
	Order.request(hero,ability(hero),target)
	hero._stun_timer=1
	var start:Vector2=hero.position
	for i in 20:hero._physics_process(1.0/60)
	check(hero.position==start and hero.special.has(Order.KEY) and hero.logistics.ammo==4 and ability(hero).cd_left==0,"stun pauses movement and release without spending pending resources")
	hero._stun_timer=0
	await get_tree().physics_frame
	await until_launch(hero)
	check(hero.logistics.ammo==2,"stun expiry resumes exactly one cast")
	await finish()
