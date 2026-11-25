extends "res://tests/base_recovery_regression.gd"
const Reference=preload("res://tests/move_slots_reference.gd")
var micro:Array=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		var reference=Reference.new()
		reference.path_service=battle.path_service
		var actors:Array=[]
		for i in 96:
			actors.append(battle.spawn_unit(["MTNK","E1","ORCA","SUB","LCRF","R3APOC"][i%6],"ally",Vector2(800+(i%12)*36,800+(i/12)*36)))
		for count in [1,8,32,96]:
			var group:Array=actors.slice(0,count)
			for center in [Vector2(900,900),Vector2(1800,1600),Vector2(100,100)]:
				var slots:Array=Formations.layout(count,center,Vector2.RIGHT,"line",battle._formation_spacing(group))
				for defer_routes in [true,false]:
					var before:Dictionary=reference.original_assign_move_slots(group,slots,center,defer_routes)
					var after:Dictionary=battle._assign_move_slots(group,slots,center,defer_routes)
					for actor in group:check(before[actor]==after[actor],"mixed formation %s/%s/%s/%s"%[mode,count,center,defer_routes])
		for actor in actors:
			actor.is_air=false;actor.is_naval=false;actor.is_amphibious=false
		var slots:Array=Formations.layout(actors.size(),Vector2(1700,1700),Vector2.RIGHT,"line",battle._formation_spacing(actors))
		check(actors.size()==96 and slots.size()==96,"benchmark has 96 actors and slots")
		for pass_index in 12:
			var assigned_count:=0
			var began:=Time.get_ticks_usec()
			for i in 8:
				var assigned:Dictionary=reference.original_assign_move_slots(actors,slots,Vector2(1700,1700),true) if pass_index%2==0 else battle._assign_move_slots(actors,slots,Vector2(1700,1700),true)
				assigned_count+=assigned.size()
			micro.append({"mode":mode,"variant":"before" if pass_index%2==0 else "after","commands":8,"units":96,"us":Time.get_ticks_usec()-began})
			check(assigned_count==768,"benchmark consumes all formation results")
		# A new command must see terrain changes rather than retain prior slot results.
		battle.path_service.cost.fill(-1)
		var before:Dictionary=reference.original_assign_move_slots(actors,slots,Vector2(1700,1700),true)
		var after:Dictionary=battle._assign_move_slots(actors,slots,Vector2(1700,1700),true)
		for actor in actors:check(before[actor]==after[actor],"terrain changes invalidate per-command reuse")
		reference.free()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)

