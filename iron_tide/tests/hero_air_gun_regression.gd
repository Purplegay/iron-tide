extends "res://tests/tank_hero_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	MetaProgress.reset_save()
	for id: String in Hero.IDS:
		start(MatchRules.EXTENDED)
		GM.god_mode = false
		GM.one_shot_kill = false
		if battle.fog != null:
			battle.fog.free()
			battle.fog = null
		var gun = hero(id, 0, 5, Vector2(1000, 1000))
		var jet = battle.spawn_unit("ORCA", "enemy", gun.position + Vector2(160, 0))
		jet.logistics.air_lift = 64
		jet.hp = 10000
		jet.max_hp = 10000
		var ordinary = battle.spawn_unit(id, "ally", gun.position + Vector2(-80, 80))
		check(not ordinary.attack_domain_valid(jet), id + " ordinary tank cannot target aircraft")
		gun.special.hero_survival_rank = 4
		check(not gun.attack_domain_valid(jet), id + " rank four cannot target aircraft")
		gun.special.hero_survival_rank = 5
		check(gun.attack_domain_valid(jet) and ForceFire.reason(battle, gun, jet).is_empty(), id + " rank five can target aircraft")
		var original: float = gun._weapon_for_target(null).damage
		check(is_equal_approx(float(gun._weapon_for_target(jet).damage), original * 0.5), id + " anti-air base damage is half")
		var air_damage := shoot_and_measure(gun, jet, true)
		jet.logistics.air_lift = 0
		check(is_equal_approx(float(gun._weapon_for_target(jet).damage), original), id + " landed aircraft takes normal shell")
		var ground_damage := shoot_and_measure(gun, jet, false)
		check(air_damage > 0 and absf(ground_damage - 2.0 * air_damage) <= 1.0, id + " actual air/ground damage differs twofold within integer rounding", [air_damage, ground_damage])
		await finish()
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed == 0 else 1)

func shoot_and_measure(gun, jet, air: bool) -> float:
	gun.order_target(jet, false, false)
	gun._cancel_burst()
	gun._cd_timer = 0
	gun.turret_angle = gun.position.direction_to(jet.position).angle()
	var old_hp: float = jet.hp
	if not gun._try_fire_ready():
		check(false, gun.unit_id + " fire command rejected")
		return 0.0
	var shot = battle.projectiles_root.get_children().back()
	if not shot is Projectile:
		check(false, gun.unit_id + " missing shell")
		return 0.0
	var ground = battle.spawn_unit("E2", "enemy", jet.position + Vector2(0, 20))
	var hp_before: float = ground.hp
	if air:
		jet.position.y += 20
	shot._step_arc(shot._arc_dur)
	if air:
		check(shot.target_point.is_equal_approx(jet.position) and shot._arc_z > 0, gun.unit_id + " shell bursts at moving aircraft")
		check(is_equal_approx(ground.hp, hp_before), gun.unit_id + " airburst spares ground beneath jet")
	ground._die()
	return old_hp - jet.hp
