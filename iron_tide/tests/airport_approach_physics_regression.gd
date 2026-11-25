extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		battle.fog=null
		var base:Building=battle._place_building("GAAIRC","ally",Vector2(1200,1200),true,true)
		base._buildup_play=-1.0;base.under_construction=false;base.power=0.0
		battle.power_low=false
		for id in ["ORCA","BEAG"]:
			var planes:Array=[]
			for i in 4:
				var plane:Unit=battle.spawn_unit(id,"ally",base.position)
				plane.set_physics_process(false)
				plane.logistics.assign_producer(base)
				planes.append(plane)
			var returning:Unit=planes[0]
			returning.process_mode=Node.PROCESS_MODE_ALWAYS
			returning.set_process(false)
			for direction in [Vector2.LEFT,Vector2.UP]:
				returning.order_stop();returning.fire_stance="none"
				returning.position=returning.logistics.dock_destination()+direction*420.0
				returning.logistics.air_state="returning";returning.logistics.air_lift=1.0
				returning.logistics.ammo=0;returning.velocity=Vector2.ZERO
				returning.add_collision_exception_with(planes[1])
				returning.set_physics_process(true)
				var steps:=0
				while steps<600 and returning.logistics.air_state!="rearming":
					await get_tree().physics_frame
					steps+=1
				returning.set_physics_process(false)
				check(returning.logistics.air_state=="rearming" and returning.logistics.air_lift<=0.05,prefix+id+" real 15Hz physics reaches dock",{"steps":steps,"state":returning.logistics.air_state,"position":returning.position,"destination":returning.logistics.dock_destination()})
				check(returning.position.distance_to(returning.logistics.dock_destination())<0.01,prefix+id+" exact pad landing")
				var exceptions:=returning.get_collision_exceptions()
				check(exceptions.has(planes[1]) and not exceptions.has(planes[2]) and not exceptions.has(planes[3]),prefix+id+" transient exceptions removed; preexisting exception retained")
				returning.remove_collision_exception_with(planes[1])
			for plane in planes:
				battle.units.erase(plane);plane.free()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
