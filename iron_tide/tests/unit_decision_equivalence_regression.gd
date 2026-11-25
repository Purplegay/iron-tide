extends "res://tests/base_recovery_regression.gd"
const Actor = preload("res://tests/unit_decision_actor.gd")
const Reference = preload("res://tests/unit_decision_reference.gd")
var query_counts := {"before":0,"after":0,"cargo_before":0,"cargo_after":0}

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		battle.fog=null
		exercise_bursts()
		exercise_reload_only()
		exercise_cargo()
		exercise_aim()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"query_counts":query_counts},"  "))
	get_tree().quit(0 if failed==0 else 1)

func actor(id: String, old: bool) -> Unit:
	var unit: Unit = Reference.new() if old else Actor.new()
	unit.setup(GameData.get_unit(id).duplicate(true),"ally",Vector2(1000,1000))
	unit._combat_world=battle
	battle.add_child(unit);battle.units.append(unit)
	unit.set_physics_process(false)
	unit.fire_stance="free"
	return unit

func discard(unit: Unit) -> void:
	battle.units.erase(unit);unit.free()

func exercise_reload_only() -> void:
	for speed in [1.0,2.0,3.0]:
		BattleClock.set_speed(speed)
		for rate in [0.0,0.5,1.0]:
			for reload in [0.0,0.001,1.0/60.0,1.0/15.0,0.2,1.0]:
				var guns: Array[Unit]=[actor("MTNK",true),actor("MTNK",false)]
				var foe: Unit=battle.spawn_unit("HTNK","enemy",Vector2(1080,1000))
				for gun in guns:
					gun.attack_target=foe;gun.attack_ordered=true;gun._cd_timer=reload
					gun.weapon.burst=1;gun.hull_angle=0;gun.turret_angle=0;gun.aim_dir=Vector2.RIGHT
				for tick in 8:
					for gun in guns:
						var previous:float=gun._cd_timer
						gun._cd_timer-=speed/15.0*rate
						gun._advance_firing(speed/15.0,previous,foe,rate)
					check(guns[0]._cd_timer==guns[1]._cd_timer and guns[0].fired==guns[1].fired and guns[0]._burst_left==guns[1]._burst_left,prefix+"reload-only exact subtraction and fire boundary %s/%s/%s/%s"%[speed,rate,reload,tick])
				for gun in guns:discard(gun)
				discard(foe)
	BattleClock.set_speed(1.0)

func exercise_bursts() -> void:
	for speed in [1.0,2.0,3.0]:
		BattleClock.set_speed(speed)
		for delay in [0.01,0.05,0.1,0.3]:
			for mutation in ["","kill","friendly","freeze","range","weapon","turn"]:
				var guns: Array[Unit]=[actor("MTNK",true),actor("MTNK",false)]
				var foes: Array[Unit]=[]
				for gun in guns:
					var foe: Unit=battle.spawn_unit("HTNK","enemy",Vector2(1080,1000))
					foes.append(foe)
					gun.attack_target=foe;gun._burst_target=foe;gun._burst_left=4
					gun.attack_ordered=true;gun._burst_timer=delay;gun._cd_timer=1.0
					gun.weapon.burst_delay=delay;gun.weapon.burst=4;gun.cooldown=0.15
					gun.hull_angle=0;gun.turret_angle=0;gun.aim_dir=Vector2.RIGHT
					gun.mutation=mutation
				for tick in 5:
					for gun in guns:
						var previous: float=gun._cd_timer
						gun._cd_timer-=speed/15.0
						gun._advance_firing(speed/15.0,previous,gun.attack_target)
					check(guns[0].fired==guns[1].fired and guns[0]._burst_left==guns[1]._burst_left and guns[0]._burst_timer==guns[1]._burst_timer and guns[0]._cd_timer==guns[1]._cd_timer,prefix+"burst state matches original %s/%s/%s/%s"%[speed,delay,mutation,tick])
				query_counts.before+=guns[0].target_calls;query_counts.after+=guns[1].target_calls
				for gun in guns: discard(gun)
				for foe in foes: discard(foe)
	check(query_counts.after<query_counts.before,prefix+"burst reuse reduces actual target validations",query_counts.duplicate())
	BattleClock.set_speed(1.0)

func exercise_cargo() -> void:
	var acquired := 0
	var accepted := 0
	var rejected := 0
	var ground: Unit=battle.spawn_unit("HTNK","enemy",Vector2(1100,1000))
	var air: Unit=battle.spawn_unit("JUMPJET","enemy",Vector2(1100,1030))
	air.logistics.air_lift=1.0
	var guns: Array[Unit]=[actor("BFRT",true),actor("BFRT",false)]
	for id in ["E1","GGI","CLEG"]:
		for gun in guns:
			var passenger: Unit=actor(id,false)
			gun.logistics.passengers.append(passenger)
			passenger.set_stowed(gun)
	for rank in [0,2]:
		for stance in ["free","defend","return","none"]:
			for variant in ["normal","zero_range","dead","controlled","frozen","concealed"]:
				for gun in guns:
					gun.veteran_level=rank;gun._refresh_veteran_bonuses(false)
					gun.fire_stance=stance;gun.attack_ordered=false;gun.attack_target=null
					gun._return_timer=2.0;gun.special.retaliation_target=ground
					for passenger in gun.logistics.passengers:
						passenger.hp=0.0 if variant=="dead" else passenger.max_hp
						passenger.side="enemy" if variant=="controlled" else "ally"
						passenger.special.chrono_left=2.0 if variant=="frozen" else 0.0
					ground.special.reveal=0.0
					if variant=="concealed":ground.special.echo_cloaked=true
					else:ground.special.erase("echo_cloaked")
					gun.attack_range=0.0 if variant=="zero_range" else float(gun.weapon.range)
					for target in [ground,air]:
						var weapon: Dictionary=gun._weapon_for_target(target)
						var expected_range: float=OpenTopped.command_range(gun,target,weapon)
						var expected: bool=gun._weapon_domain_valid(target,false,weapon) or OpenTopped.cargo_can_attack(gun,target)
						if expected: accepted+=1
						else: rejected+=1
						var domain := [not expected]
						var reach: float=OpenTopped.command_range(gun,target,weapon,domain)
						check(reach==expected_range and domain[0]==expected,prefix+"cargo range/domain %s/%s/%s/%s"%[rank,stance,variant,target.unit_id])
					var calls := domain_calls(gun)
					gun._refresh_target()
					query_counts["cargo_before" if gun==guns[0] else "cargo_after"]+=domain_calls(gun)-calls
					if gun.attack_target!=null: acquired+=1
				check(guns[0].attack_target==guns[1].attack_target,prefix+"target choice matches original %s/%s/%s"%[rank,stance,variant])
	check(acquired>0 and accepted>0 and rejected>0,prefix+"cargo fixture covers acquisitions, accepted and rejected targets",[acquired,accepted,rejected])
	check(query_counts.cargo_after<query_counts.cargo_before,prefix+"cargo query reuse reduces actual carrier/passenger domain validations",query_counts.duplicate())
	for gun in guns:
		for passenger in gun.logistics.passengers: discard(passenger)
		gun.logistics.passengers.clear();discard(gun)
	discard(ground);discard(air)

func domain_calls(gun: Unit) -> int:
	var count: int=gun.domain_calls
	for passenger in gun.logistics.passengers: count+=passenger.domain_calls
	return count

func exercise_aim() -> void:
	for id in ["MTNK","E1","GGI","SUB","ZEP","R3MIRAGE"]:
		var guns: Array[Unit]=[actor(id,true),actor(id,false)]
		for moving in [false,true]:
			for attack_move in [false,true]:
				for point in [Vector2.ZERO,Vector2(0.001,0),Vector2(80,0),Vector2(80,0),Vector2(0,-80),Vector2(-90,0),Vector2(80,80)]:
					for gun in guns:
						gun.has_move_order=moving;gun.attack_move=attack_move
						gun._face(gun.global_position+point)
					check(guns[0].aim_dir==guns[1].aim_dir and guns[0].turret_angle==guns[1].turret_angle and guns[0].hull_angle==guns[1].hull_angle,prefix+"aim state matches original "+id)
		for gun in guns: discard(gun)
