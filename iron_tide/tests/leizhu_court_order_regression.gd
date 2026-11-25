extends "res://tests/leizhu_input_regression.gd"
const Order=preload("res://scripts/units/leizhu_court_order.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	input_view=SubViewport.new();input_view.size=Vector2i(1600,900);add_child(input_view)
	await get_tree().process_frame
	for rank in 4:await distant_cast(rank)
	await manual_court()
	await illegal_points()
	await preview_cursor()
	await cancel_orders()
	await invalidated_orders()
	await replace_order()
	await restore_order()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("LEIZHU_COURT_ORDER ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func driving(hero) -> void:
	hero.process_mode=Node.PROCESS_MODE_ALWAYS
	hero.set_process(false);hero.set_physics_process(false)
	hero.set_fire_stance("none")

func until_cast(hero) -> void:
	for frame in 1800:
		hero._physics_process(1.0/60)
		if battle.allied_state.has(LC.FIELDS):break
		if frame%30==0:await get_tree().physics_frame
	check(battle.allied_state.has(LC.FIELDS),"real ground movement enters range and casts",hero.position)

func distant_cast(rank:int) -> void:
	var hero=cards_hero(rank);driving(hero)
	var start:Vector2=hero.position
	var point:Vector2=start+Vector2(650,0)
	await get_tree().physics_frame
	check(hero.position.distance_to(point)>hero.attack_range and not LC.placement(hero,point) and LC.selectable(hero,point),"far valid ground can be selected outside weapon and cast ranges")
	confirm(hero,point)
	check(hero.special.get(Order.KEY,{}).get("point",Vector2.INF).is_equal_approx(point) and hero.has_move_order,"HUD queues distant W and starts ground navigation",hero.special.get(Order.KEY))
	check(ability(hero).cd_left==0 and not battle.allied_state.has(LC.FIELDS),"approach does not create field or spend cooldown")
	check(not hero.use_ability(UnitSkillLayout.find(hero,LC.ACTIVE),start),"automatic cast cannot consume pending manual W")
	await until_cast(hero)
	check(hero.position.distance_to(start)>300 and LC.placement(hero,point),"hero actually drove into five-cell casting range")
	check(not hero.special.has(Order.KEY) and not hero.has_move_order,"arrival consumes movement order")
	check(ability(hero).cd_left>[48.,44.,40.,36.][rank]-.1 and ability(hero).cd_left<=[48.,44.,40.,36.][rank],"arrival starts one rank cooldown")
	if battle.allied_state.has(LC.FIELDS):
		check(battle.allied_state[LC.FIELDS].size()==1 and battle.allied_state[LC.FIELDS][0].point.is_equal_approx(point) and battle.allied_state[LC.FIELDS][0].nodes.size()==3,"one court retains distant clicked center",battle.allied_state[LC.FIELDS][0].point)
	await finish()

func preview_cursor() -> void:
	var hero=cards_hero()
	battle.select_unit(hero,false)
	battle.request_ability(UnitSkillLayout.find(hero,LC.ACTIVE))
	check(battle.command_cursor.resolve(hero.position+Vector2(120,0))=="attack","near legal point uses immediate cast cursor")
	var point:Vector2=hero.position+Vector2(650,0)
	check(battle.command_cursor.resolve(point)=="move","far legal point uses approach cursor")
	battle.path_service.water_rects=[Rect2(point-Vector2(20,20),Vector2(40,40))]
	check(battle.command_cursor.resolve(point)=="blocked","illegal far ground retains blocked cursor")
	await finish()

func cancel_orders() -> void:
	for command in ["stop","move","guard","attack","patrol"]:
		var hero=cards_hero();var point:Vector2=hero.position+Vector2(650,0)
		check(Order.request(hero,point),"queue before command: "+command)
		match command:
			"stop":hero.order_stop()
			"move":hero.order_move(hero.position+Vector2(0,300))
			"guard":hero.order_guard()
			"attack":hero.order_target(target("HTNK","enemy",point),false,false)
			"patrol":hero.order_patrol(hero.position+Vector2(0,300))
		check(not hero.special.has(Order.KEY) and ability(hero).cd_left==0 and not battle.allied_state.has(LC.FIELDS),"new order cancels W without cooldown: "+command)
		await finish()

func invalidated_orders() -> void:
	for reason in ["water","vertex","fog","side","dead","stun","path_stopped"]:
		var hero=cards_hero();var point:Vector2=hero.position+Vector2(650,0)
		check(Order.request(hero,point),"queue before invalidation: "+reason)
		match reason:
			"water":battle.path_service.water_rects=[Rect2(point-Vector2(20,20),Vector2(40,40))]
			"vertex":battle.path_service.water_rects=[Rect2(LC.points(point)[0]-Vector2(15,15),Vector2(30,30))]
			"fog":
				var fog=load("res://scripts/world/fog_of_war.gd").new();battle.add_child(fog);fog.setup(battle);battle.fog=fog
				for side in fog.visible_cells:fog.visible_cells[side].fill(0)
			"side":hero.side="enemy"
			"dead":hero.hp=0
			"stun":hero._stun_timer=1
			"path_stopped":hero.has_move_order=false
		Order.tick(hero)
		check(not hero.special.has(Order.KEY) and not hero.has_move_order and ability(hero).cd_left==0 and not battle.allied_state.has(LC.FIELDS),"invalid pending cast cancels without cost: "+reason)
		await finish()

func replace_order() -> void:
	var hero=cards_hero();driving(hero)
	var first:Vector2=hero.position+Vector2(650,0)
	var second:Vector2=hero.position+Vector2(0,650)
	check(Order.request(hero,first) and Order.request(hero,second),"a second W replaces pending point")
	check(hero.special[Order.KEY].point==second and hero.move_target==second and ability(hero).cd_left==0,"latest valid point owns pending movement")
	await until_cast(hero)
	if battle.allied_state.has(LC.FIELDS):check(battle.allied_state[LC.FIELDS][0].point==second,"replacement casts at latest clicked point")
	await finish()

func restore_order() -> void:
	var hero=cards_hero();driving(hero)
	var point:Vector2=hero.position+Vector2(650,0)
	check(Order.request(hero,point),"queue before save")
	for i in 30:hero._physics_process(1.0/60)
	var codec=BattleSaves.Snapshot.new()
	var file=FileAccess.open(output_dir.path_join("pending-court.bin"),FileAccess.WRITE)
	file.store_var(codec.capture(battle),false);file.close()
	file=FileAccess.open(output_dir.path_join("pending-court.bin"),FileAccess.READ)
	var snapshot=file.get_var(false);file.close();codec.restore(battle,snapshot)
	get_tree().paused=false
	hero=get_hero();driving(hero)
	check(codec.error.is_empty() and hero.special.get(Order.KEY,{}).get("point")==point and hero.has_move_order,"binary restore retains pending point and movement")
	check(ability(hero).cd_left==0,"saved approach has no cooldown cost")
	await get_tree().physics_frame
	await until_cast(hero)
	check(not hero.special.has(Order.KEY) and battle.allied_state.get(LC.FIELDS,[]).size()==1,"restored approach casts exactly once")
	await finish()
