extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		exercise_bonuses()
		exercise_ranges()
		exercise_clocks()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed == 0 else 1)

func exercise_clocks() -> void:
	var unit = battle.spawn_unit("MTNK","ally",Vector2(700,700))
	var ability:=Ability.new()
	unit.skills=[ability];unit._has_active_skills=true
	for cooldown_left in [-1.0,0.0,0.05,0.2]:
		for active_left in [-1.0,0.0,0.05,0.2]:
			for delta in [-0.1,0.0,0.1,0.2]:
				ability.cd_left=cooldown_left;ability.active_left=active_left
				unit._tick_skills(delta)
				check(ability.cd_left==(maxf(0.0,cooldown_left-delta) if cooldown_left>0 else cooldown_left),prefix+"exact cooldown tick")
				check(ability.active_left==(maxf(0.0,active_left-delta) if active_left>0 else active_left),prefix+"exact active clock tick")

func exercise_bonuses() -> void:
	for id in ["MTNK","E1","GGI"]:
		var unit = battle.spawn_unit(id,"ally",Vector2(800,800))
		for deployed in [false,true]:
			unit._deployed = deployed
			for variant in 8:
				unit.buffs = []
				for i in variant:
					unit.buffs.append({"kind":["attack","defense","speed","electric_slow","attack","regen","speed"][i],"value":0.1*(i+1),"left":5.0})
				unit.special.slope_speed = 0.25
				unit.special.hero_speed_floor = 35.0
				var attack: float = unit._base_atk * unit.buff_mult_scalar("attack") * (unit._deploy_atk if deployed else 1.0)
				var armor: float = unit._deploy_def * (Unit.Training.scale(unit) if id in ["E1","GGI"] else 1.0) if deployed else 1.0
				var defense: float = unit._base_def * unit.buff_mult_scalar("defense") * armor
				var speed: float = unit._base_speed * unit.buff_mult_scalar("speed") * (0.0 if deployed else 1.0)
				speed *= 1.25
				speed *= 1.0 - clampf(unit.buff_value("electric_slow"),0.0,0.8)
				speed = Unit.TankHero.speed(unit,speed)
				unit._recompute_base_bonuses()
				check(is_equal_approx(attack,unit.bonuses.attack_bonus) and is_equal_approx(defense,unit.bonuses.defense_bonus) and is_equal_approx(speed,unit.move_speed),prefix+"single-pass buffs equal original formula %s/%s/%s" % [id,deployed,variant])
		unit.special.clear()
		check(not AlliedAbilities.frozen(unit),prefix+"ordinary actor has no freeze")
		unit.special.chrono_left = 1.0
		check(AlliedAbilities.frozen(unit),prefix+"live chrono arrival freeze still applies")
		unit.special.chrono_left = 0.0
		check(not AlliedAbilities.frozen(unit),prefix+"expired chrono state is not frozen")
		unit.special.temporal_by = unit
		check(AlliedAbilities.frozen(unit),prefix+"live temporal owner still freezes")
		unit.special.erase("temporal_by")
		unit._deployed = false
		check(not unit.logistics.tick(0.1),prefix+"idle ground logistics has no work")

func exercise_ranges() -> void:
	var ground = battle.spawn_unit("HTNK","enemy",Vector2(850,800))
	var air = battle.spawn_unit("JUMPJET","enemy",Vector2(850,830))
	for id in ["MTNK","APOC","BFRT","DRED","DEST","GHOST","FV"]:
		var unit = battle.spawn_unit(id,"ally",Vector2(800,800))
		for target in [ground,air]:
			for rank in [0,2]:
				unit.veteran_level = rank
				unit._refresh_veteran_bonuses(false)
				var gun: Dictionary = unit._weapon_for_target(target)
				check(unit._weapon_domain_valid(target) == unit._weapon_domain_valid(target,false,gun),prefix+"resolved weapon preserves domain %s/%s/%s" % [id,target.unit_id,rank])
				check(unit._weapon_target_valid(target) == unit._weapon_target_valid(target,gun),prefix+"resolved weapon preserves fire readiness %s/%s/%s" % [id,target.unit_id,rank])
				var old: float = OpenTopped.command_range(unit,target)
				var reused: float = OpenTopped.command_range(unit,target,gun)
				check(old == reused,prefix+"resolved weapon preserves reach %s/%s/%s" % [id,target.unit_id,rank])
