extends "res://tests/peregrine_service_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for owner in ["ally","enemy"]:await occupied_landing(owner)
	await blocked_area()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)

func occupied_landing(owner:String) -> void:
	var hero=service_hero();var normal:float=hero.max_hp
	make_wreck(hero);P.tick(hero,.5)
	var blocker=battle.spawn_unit("MTNK",owner,hero.special.hero_wreck.point)
	P.tick(hero,.5)
	check(not hero._dead and hero.hp==normal*10,"occupied touchdown cannot kill full durability: "+owner)
	if hero._dead:await finish();return
	check(hero.logistics.air_lift==0 and S.ground_clear(hero,hero.position) and hero.position.distance_to(blocker.position)>hero.radius+blocker.radius,"touchdown selects a different clear point: "+owner)
	P.tick(hero,180)
	check(not hero.special.has("hero_wreck") and hero.hp==normal,"rerouted landing retains automatic recovery: "+owner)
	await finish()

func blocked_area() -> void:
	var hero=service_hero();var normal:float=hero.max_hp
	var enemy=make_wreck(hero);P.tick(hero,.5)
	battle.path_service.water_rects=[Rect2(hero.position-Vector2(400,400),Vector2(800,800))]
	P.tick(hero,.5)
	check(not hero._dead,"loss of all landing points cannot bypass remaining durability")
	if hero._dead:await finish();return
	check(hero.logistics.air_lift>0 and hero.special.hero_wreck.left==180,"blocked descent waits without starting grounded repair timer")
	hero.receive_hit(30,"shell",{},enemy);var damaged:float=hero.hp
	check(damaged<normal*10 and damaged>0,"waiting aircraft remains damageable")
	await binary_restore("blocked-descent");hero=get_hero()
	check(hero!=null and hero.hp==damaged,"blocked descent retains damage across binary restore")
	if hero==null:await finish();return
	battle.path_service.water_rects=[Rect2(hero.position-Vector2(400,400),Vector2(800,800))]
	P.tick(hero,2)
	check(not hero._dead and hero.special.hero_wreck.left==180 and hero.hp==damaged,"continued obstruction neither kills nor heals nor repairs")
	battle.path_service.water_rects=[];P.tick(hero,1)
	check(not hero._dead and hero.logistics.air_lift==0 and hero.hp==damaged,"cleared landing resumes without restoring durability")
	P.tick(hero,180)
	check(not hero.special.has("hero_wreck") and hero.max_hp==normal and hero.hp==normal,"cleared landing leads to one normal recovery")
	await finish()
