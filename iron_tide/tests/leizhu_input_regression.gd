extends "res://tests/leizhu_cards_regression.gd"
var input_view:SubViewport

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	input_view=SubViewport.new();input_view.size=Vector2i(1600,900);add_child(input_view)
	await get_tree().process_frame
	await manual_court()
	await illegal_points()
	for rank in 4:await real_passive(rank)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("LEIZHU_INPUT_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func boot(id:String,mode:=MatchRules.EXTENDED) -> void:
	super.boot(id,mode)
	screen.reparent(input_view)

func confirm(hero,point:Vector2) -> void:
	battle.select_unit(hero,false)
	check(battle.request_ability(UnitSkillLayout.find(hero,LC.ACTIVE))==-1,"actual W request enters targeting")
	battle.camera.position=point;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	var motion:=InputEventMouseMotion.new()
	motion.position=battle.get_global_transform_with_canvas()*point
	input_view.push_input(motion,true)
	check(battle.get_global_mouse_position().is_equal_approx(point),"viewport click maps to selected ground point")
	battle.confirm_cast()
	check(battle.cast_slot==-1,"confirm exits targeting")

func manual_court() -> void:
	var hero=cards_hero();var point:Vector2=hero.position+Vector2(120,0)
	var victim=target("HTNK","enemy",point)
	check(LC.placement(hero,point),"clicked ground and all three electrode positions are legal")
	confirm(hero,point)
	check(battle.allied_state.get(LC.FIELDS,[]).size()==1,"HUD confirmation creates one electric court")
	check(ability(hero).cd_left==48,"successful HUD cast starts one cooldown")
	if battle.allied_state.has(LC.FIELDS):
		var field:Dictionary=battle.allied_state[LC.FIELDS][0]
		check(field.point.is_equal_approx(point) and field.nodes.size()==3,"field uses actual clicked point and three electrodes")
		LC.world_tick(battle,.5)
		check(victim.hp<100000 and victim.move_speed<victim._base_speed,"manually placed field deals damage and slows")
		check(hero.special[L.KEY].get("charge_count",0)==0,"W damage does not substitute passive primary hits")
	await finish()

func illegal_points() -> void:
	for reason in ["water","vertex","fog"]:
		var hero=cards_hero();var point:Vector2=hero.position+Vector2(120,0)
		match reason:
			"water":battle.path_service.water_rects=[Rect2(point-Vector2(200,200),Vector2(400,400))]
			"vertex":battle.path_service.water_rects=[Rect2(LC.points(point)[0]-Vector2(15,15),Vector2(30,30))]
			"fog":
				var fog=load("res://scripts/world/fog_of_war.gd").new();battle.add_child(fog);fog.setup(battle);battle.fog=fog
				for side in fog.visible_cells:fog.visible_cells[side].fill(0)
		check(not LC.placement(hero,point),"illegal placement fixture: "+reason)
		confirm(hero,point)
		check(not battle.allied_state.has(LC.FIELDS) and ability(hero).cd_left==0,"invalid manual ground selection spends no cooldown: "+reason)
		await finish()

func real_passive(rank:int) -> void:
	var hero=cards_hero(rank)
	var victim=target("HTNK","enemy",hero.position+Vector2(220,0))
	var nearby=target("E2","enemy",hero.position+Vector2(-60,0))
	var radius:float=[2.,2.25,2.5,3.][rank]*55
	var outside=target("E2","enemy",hero.position+Vector2(0,radius+5))
	var expected_damage:=expected(hero,nearby,[.3,.4,.5,.6][rank])
	hero.process_mode=Node.PROCESS_MODE_ALWAYS;hero.set_process(false);hero.set_physics_process(false)
	await get_tree().physics_frame
	hero.order_target(victim,false,false)
	var stages:Array=[]
	for frame in 1800:
		hero._physics_process(1.0/60)
		var layers:int=hero.special[L.KEY].get("charge_count",0)
		if layers>0 and layers not in stages:stages.append(layers)
		if hero.special[L.KEY].has("arc_flash"):break
		if frame%30==0:await get_tree().physics_frame
	check(stages==[1,2],"actual physical combat accumulates first and second layers rank "+str(rank),stages)
	check(hero.special[L.KEY].has("arc_flash") and hero.special[L.KEY].get("charge_count",0)==0,"third real primary hit discharges and consumes layers")
	check(is_equal_approx(100000-nearby.hp,expected_damage),"real passive damages nearby enemy at rank "+str(rank),[100000-nearby.hp,expected_damage])
	check(outside.hp==100000 and hero.position.distance_to(victim.position)>radius,"discharge is centered on hero, excludes distant primary surroundings")
	check(not battle.allied_state.has(LC.FIELDS),"passive triggers without casting W")
	await finish()
