extends "res://tests/progression_expansion_2_regression.gd"
const Field=preload("res://scripts/units/leizhu_cards.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	start(MatchRules.EXTENDED)
	BattleRequest.skirmish_config.fog_of_war=false
	var target:Building=battle._place_building("GACNST","enemy",Vector2(1400,1200),true)
	var original:=target.footprint_poly().duplicate()
	var radius:=target.footprint_radius()
	var center:=Placement.aabb(original,target.position).get_center()
	var segment:=PackedVector2Array([center-Vector2(250,0),center+Vector2(250,0)])
	var triangle:=PackedVector2Array([center+Vector2(-250,-250),center+Vector2(250,-250),center+Vector2(0,300)])
	for attempt in 6:
		check(Field.covers(segment,target),"repeated line field still covers building "+str(attempt))
		check(Field.covers(triangle,target),"repeated triangle field still covers building "+str(attempt))
		check(target.footprint_poly()==original and target.footprint_radius()==radius,"field queries preserve local foundation and radius "+str(attempt))
	check(not Field.covers(PackedVector2Array([Vector2.ZERO,Vector2(100,0)]),target),"distant field excludes building")
	var gun:Unit=battle.spawn_unit("APOC","ally",Vector2(1220,1200))
	for elite in [false,true]:
		gun.veteran_level=2 if elite else 0
		gun._refresh_veteran_bonuses(false)
		gun.order_target(target,false,false)
		check(normal_shot(gun,target),"manual building volley after field queries "+str(elite))
		var count:int=gun._active_weapon().burst
		for shot in count-1:gun._advance_valid_burst(1,gun._active_weapon())
		check(missiles(gun).size()==(4 if elite else 2),"native normal or elite burst preserved "+str(elite))
		var before:float=target.hp
		fly_missiles(gun)
		check(target.hp<before,"real shells damage building "+str(elite))
	# Reproduce the saved corruption: each field query added the world position.
	var damaged:=original.duplicate()
	for i in damaged.size():damaged[i]+=target.position*6
	target._fp_poly=damaged
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	for b in battle.buildings:
		if b.building_id=="GACNST" and b.side=="enemy":target=b
	for u in battle.units:
		if u.unit_id=="APOC":gun=u
	check(target.footprint_poly()==original,"restore rebuilds derived local foundation from building definition")
	check(is_equal_approx(target.footprint_radius(),radius),"restore recalculates foundation radius")
	var physics_ok:=false
	for child in target.get_children():
		if child is CollisionPolygon2D:physics_ok=child.polygon==target.footprint_poly()
	check(physics_ok,"restored range and physics use identical foundation")
	check(normal_shot(gun,target),"restored apocalypse fires on restored building")
	var before:float=target.hp
	fly_missiles(gun)
	check(target.hp<before,"restored building receives actual shell damage")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
