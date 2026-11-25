extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for side in ["ally", "enemy"]:
			await exercise(mode, side)
	var f := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failed":failed}, "  "))
	f.close()
	get_tree().quit(0 if failed == 0 else 1)

func exercise(mode: String, side: String) -> void:
	start(mode)
	prefix += side + ": "
	for b in battle.buildings: b.free()
	battle.buildings.clear()
	var opponent := "enemy" if side == "ally" else "ally"
	var shooter = battle.spawn_unit("TNKD", side, Vector2(1000,1000))
	var infantry = battle.spawn_unit("E1", opponent, Vector2(1100,1000))
	var tank = battle.spawn_unit("MTNK", opponent, Vector2(1140,1000))
	shooter._refresh_target()
	check(shooter.attack_target == tank, prefix + "tank destroyer prefers vulnerable armor over nearest infantry")
	var weak = battle.spawn_unit("MTNK", opponent, Vector2(1160,1020))
	weak.hp = 1
	shooter._refresh_target()
	check(shooter.attack_target == weak, prefix + "one-shot armored target beats healthy armor")
	weak.position = Vector2(1000 + shooter.attack_range + 40,1000)
	shooter._refresh_target()
	check(shooter.attack_target == tank, prefix + "shootable target beats weak target beyond weapon range")
	shooter.attack_target = infantry
	shooter.attack_ordered = true
	shooter._refresh_target()
	check(shooter.attack_target == infantry, prefix + "manual focus overrides automatic counter and health priority")
	shooter.attack_ordered = false
	weak.hp = weak.max_hp
	weak.position = tank.position + Vector2(1,0)
	shooter.attack_target = weak
	for i in 8:
		tank.position.y += 0.1
		shooter._refresh_target()
	check(shooter.attack_target == weak, prefix + "small distance changes do not churn current target")
	weak.embarked_in = shooter
	shooter._refresh_target()
	check(shooter.attack_target != weak, prefix + "embarked units are excluded before scoring")
	weak.embarked_in = null
	weak.hp = 1
	weak.position = Vector2(1160,1000)
	shooter.attack_target = tank
	shooter._burst_left = 1
	shooter._burst_target = tank
	shooter._refresh_target()
	check(shooter.attack_target == tank, prefix + "automatic retargeting preserves a valid ongoing burst")
	shooter._burst_left = 0
	shooter._refresh_target()
	check(shooter.attack_target == weak, prefix + "retargeting resumes when volley ends")
	shooter.set_fire_stance("none")
	shooter._refresh_target()
	check(shooter.attack_target == null, prefix + "cease fire prevents autonomous target choice")
	# Enemy spawn intentionally receives attack-move; stop before testing idle return fire.
	shooter.order_stop()
	shooter.set_fire_stance("return")
	shooter._return_timer = 0
	shooter._refresh_target()
	check(shooter.attack_target == null, prefix + "return fire without provocation remains idle")
	# An infantry weapon should select infantry; use the live deployed weapon too.
	shooter.set_fire_stance("none")
	var gi = battle.spawn_unit("E1", side, Vector2(1000,1000))
	weak.hp = weak.max_hp
	infantry.position = Vector2(1150,1000)
	tank.position = Vector2(1100,1000)
	gi._refresh_target()
	check(gi.attack_target == infantry, prefix + "GI prefers infantry despite closer tank")
	# Blind zones must not monopolize an automatic target.
	gi.min_range = 120
	infantry.position = Vector2(1020,1000)
	tank.position = Vector2(1150,1000)
	gi.attack_target = null
	gi._refresh_target()
	check(gi.attack_target != infantry, prefix + "automatic fire ignores targets inside minimum range")
	var turret = battle._place_building("GAPILL", side, Vector2(1000,1000), true)
	turret._buildup_play = -1.0
	infantry.position = Vector2(1150,1000)
	tank.position = Vector2(1100,1000)
	turret._acquire_target()
	check(turret.attack_target == infantry, prefix + "defensive buildings use the same counter priority")
	# Follow the chosen target through real projectile creation and damage.
	GM.god_mode = false
	GM.one_shot_kill = false
	shooter.set_fire_stance("free")
	shooter._cd_timer = 0.0
	shooter._think_timer = 0.0
	shooter.attack_target = null
	weak.hp = 1.0
	var holder: Node = shooter._pick_projectile_parent()
	var shot = null
	for tick in 180:
		shooter._physics_process(1.0/60.0)
		for child in holder.get_children():
			if child is Projectile:
				shot = child
				break
		if shot != null: break
	check(shot != null and shot.target == weak, prefix + "real automatic volley targets the low-health counter target")
	if shot != null:
		shot.process_mode = Node.PROCESS_MODE_DISABLED
		for tick in 240:
			if shot.is_queued_for_deletion(): break
			shot._physics_process(1.0/60.0)
		check(weak.hp <= 0.0, prefix + "selected low-health target takes real lethal damage")
	var flak = battle.spawn_unit("FLAKT",side,Vector2(1800,1800))
	var air = battle.spawn_unit("ZEP",opponent,flak.position+Vector2(365,0))
	flak.order_stop()
	flak.set_fire_stance("defend")
	flak._refresh_target()
	check(flak.attack_target==air,prefix+"AA acquires a plane beyond its ground weapon range")
	var rifle := AlliedAbilities.weapon("MP5")
	var damage: float = rifle.damage
	rifle.damage = 0
	check(AlliedAbilities.weapon("MP5").damage == damage,prefix+"editing one shot leaves the cached weapon intact")
	await finish()
