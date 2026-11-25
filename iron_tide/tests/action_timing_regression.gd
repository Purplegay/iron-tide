extends "res://tests/base_recovery_regression.gd"
var observed_building: Building
var observed_bomb: Projectile
var active := false
var start_us := 0
var build_wall := -1.0
var bomb_wall := -1.0
var process_elapsed := 0.0
var physics_elapsed := 0.0
var rows: Array = []

func boundaries() -> void:
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		var point:=Vector2(1700,1700)
		var placed:Building=battle._place_building("GAPOWR","ally",point,true)
		var funds:float=battle.funds
		check(not placed.is_operational(),"placed structure waits for makeup")
		placed._process(.45)
		check(is_equal_approx(placed._buildup_play,.9) and not placed.is_operational(),"quarter playback retains native saved cursor")
		var saved:Dictionary=BattleSaves.Snapshot.new().capture(battle)
		BattleSaves.Snapshot.new().restore(battle,saved)
		for actor in battle.buildings:
			if actor.building_id=="GAPOWR" and actor.position==point:placed=actor;break
		check(is_instance_valid(placed) and is_equal_approx(placed._buildup_play,.9),"restore retains exact buildup progress")
		placed._process(1.34)
		check(not placed.is_operational(),"buildup cannot complete before 1.8 game seconds")
		placed._process(.02)
		check(placed.is_operational() and placed._buildup_play<0,"buildup completion enables structure")
		check(battle.funds==funds,"playback neither charges nor refunds money")
		var fast:Building=battle._place_building("GAPOWR","ally",Vector2(2100,1700),true)
		GM.no_build_time=true
		fast._process(GM.FAST_BUILD_SECONDS*.5)
		check(is_equal_approx(fast._buildup_play,GameData.ra2_buildup_seconds()*.5),"GM fast-build time is not accelerated twice")
		GM.no_build_time=false
		check(is_equal_approx(GameData.ra2_buildup_seconds(),3.6),"native stored animation duration unchanged")
		check(is_equal_approx(GameData.ra2_build_time(GameData.get_building("GAPOWR")),33.6),"native sidebar production duration unchanged")
		check(Engine.physics_ticks_per_second==15 and Engine.max_physics_steps_per_frame==64,"action pace preserves selected sixty-four-step scheduling")
		await finish()

func _process(delta: float) -> void:
	if not active:return
	process_elapsed+=delta
	if build_wall<0:
		observed_building._process(delta)
		if observed_building._buildup_play<0:build_wall=(Time.get_ticks_usec()-start_us)/1000000.0

func _physics_process(delta: float) -> void:
	if not active:return
	physics_elapsed+=delta
	if bomb_wall<0:
		observed_bomb._physics_process(delta)
		if observed_bomb._detonated:bomb_wall=(Time.get_ticks_usec()-start_us)/1000000.0

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	await boundaries()
	# Snapshot restore intentionally pauses the tree; resume before wall-clock probes.
	get_tree().paused=false
	for fps in [60,5]:
		for speed in [1.0,3.0]:
			start(MatchRules.RA2)
			Engine.max_fps=fps
			BattleClock.set_speed(speed)
			observed_building=battle._place_building("GAPOWR","ally",Vector2(1700,1700),true)
			var blimp:Unit=battle.spawn_unit("ZEP","ally",Vector2(1200,1200))
			blimp.logistics.air_lift=1.0
			var target:Unit=battle.spawn_unit("HTNK","enemy",Vector2(1200,1200))
			target.hp=100000;target.max_hp=100000
			observed_bomb=Projectile.new()
			observed_bomb.setup(blimp.position,target,blimp._active_weapon(),250,{},"ally",blimp)
			battle.projectiles_root.add_child(observed_bomb)
			var flight:Dictionary=observed_bomb.splinters.duplicate(true)
			check(observed_building._buildup_play==0 and observed_bomb.splinters.has("drop_height"),"real buildup and native Kirov bomb created")
			await get_tree().process_frame
			await get_tree().process_frame
			start_us=Time.get_ticks_usec();build_wall=-1;bomb_wall=-1;process_elapsed=0;physics_elapsed=0;active=true
			while build_wall<0 or bomb_wall<0:
				await get_tree().process_frame
				if Time.get_ticks_usec()-start_us>12000000:break
			active=false
			var row:Dictionary={"fps_cap":fps,"speed":speed,"hz":Engine.physics_ticks_per_second,"step_cap":Engine.max_physics_steps_per_frame,"build_wall":build_wall,"bomb_wall":bomb_wall,"process_game_seconds":process_elapsed,"physics_game_seconds":physics_elapsed,"flight":flight}
			rows.append(row)
			var tolerance:=maxf(0.25,2.0/fps)
			check(absf(build_wall-1.8/speed)<tolerance,"buildup follows game time at FPS cap",row)
			check(absf(bomb_wall-(40.0/30.0)/speed)<tolerance,"bomb follows game time at FPS cap",row)
			print("TIMING ",JSON.stringify(row))
			await finish()
	Engine.max_fps=0
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"timings":rows},"  "))
	get_tree().quit(0 if failed==0 else 1)
