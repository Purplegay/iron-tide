extends "res://tests/cargo_query_regression.gd"
func batch(car,repetitions:int) -> float:
	var begin:=Time.get_ticks_usec()
	for i in repetitions:
		car._scan_grant_until=999999999
		car._refresh_target()
		for crew in car.logistics.passengers:
			crew._scan_grant_until=999999999;crew.hold_position=true;crew._refresh_target()
	return (Time.get_ticks_usec()-begin)/1000.0
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	start(MatchRules.EXTENDED);battle.fog=null
	for i in 24:
		var target=battle.spawn_unit("JUMPJET" if i%3==0 else "MTNK","enemy",Vector2(1230+i*10,1100+i%4*18))
		target.set_physics_process(false)
		if target.is_air:target.logistics.air_lift=120.0
	var cars=[make("BFRT",true),make("BFRT",false)]
	for car in cars:
		for i in 5:
			var crew=make("GGI",car==cars[0]);car.logistics.passengers.append(crew);crew.set_stowed(car)
		batch(car,5)
	var before=[];var after=[]
	for i in 11:
		var order=[0,1] if i%2==0 else [1,0]
		for index in order:
			var ms=batch(cars[index],30)
			(before if index==0 else after).append(ms)
		check(cars[0].attack_target==cars[1].attack_target and cars[0].attack_target!=null,"bench carrier target unchanged")
		for seat in 5:check(cars[0].logistics.passengers[seat].attack_target==cars[1].logistics.passengers[seat].attack_target,"bench passenger target unchanged")
	before.sort();after.sort()
	var metrics={"batch_repetitions":30,"before_ms":before,"after_ms":after,"before_p50_ms":before[5],"after_p50_ms":after[5]}
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"metrics":metrics},"  "))
	get_tree().quit(0 if failed==0 else 1)
