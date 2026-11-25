extends "res://tests/special_mechanics_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false): get_tree().quit(2); return
	await get_tree().process_frame
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for side in ["ally", "enemy"]:
			for kind in ["cell_spread", "no_ally_spread", "custom_aoe", "direct", "mirage_delay"]:
				for forced in [false, true]:
					arena(mode)
					await lost_target(side, kind, forced)
					await finish()
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed}, "  ")); file.close()
	Ra2Sfx.stop_all(); Music.stop(); Music.player.stream = null
	OS.delay_msec(150)
	await get_tree().process_frame
	get_tree().quit(0 if failed == 0 else 1)

func lost_target(side: String, kind: String, forced: bool) -> void:
	var label := prefix + side + "/" + kind + "/force=" + str(forced) + ": "
	var foe := "enemy" if side == "ally" else "ally"
	var shooter = spawn("FV", side, AIM - Vector2(250, 0))
	var victim = spawn("MTNK", foe, AIM)
	var nearby = spawn("MTNK", foe, AIM + Vector2(4, 0))
	var friend = spawn("MTNK", side, AIM + Vector2(4, 4))
	var weapon: Dictionary = GameData.get_unit("FV").weapon.duplicate(true)
	weapon.damage = 50.0
	var shot := Projectile.new()
	shot.setup(shooter.position, victim, weapon, 50.0, {}, side, shooter)
	shot.ra2_inviso = false; shot.ra2_arcing = false; shot.ra2_homing = true
	shot.ra2_warhead = "AP" if kind == "cell_spread" else "YR_CAP_SuperPsiPulse" if kind == "no_ally_spread" else ""
	shot.aoe = 60.0 if kind == "custom_aoe" else 0.0
	shot.speed = 1000.0; shot.life = 5.0
	shot.splinters.force_fire = forced
	if kind == "mirage_delay": shot.splinters.ra3_hit_delay = 0.1
	battle.projectiles_root.add_child(shot)
	shot.process_mode = Node.PROCESS_MODE_DISABLED
	if kind == "cell_spread": check(Ra2Damage.cells("AP") > 0, label + "real spread warhead")
	if kind == "cell_spread": check(Ra2Damage._extra("AP","AffectsAllies").to_lower() not in ["no","false","0"],label+"native AP retains documented friendly splash")
	if kind == "no_ally_spread":check(Ra2Damage.cells(shot.ra2_warhead)>0 and Ra2Damage._extra(shot.ra2_warhead,"AffectsAllies").to_lower()=="no",label+"real no-friendly-fire spread warhead")
	battle.units.erase(victim)
	if forced:
		victim.queue_free()
		await get_tree().process_frame
	else: victim.free()
	check(not is_instance_valid(shot.target), label + "target actually freed before impact")
	battle.units.erase(shooter); shooter.free()
	var enemy_hp: float = nearby.hp
	var friend_hp: float = friend.hp
	shot._physics_process(0.5)
	check((shot._detonated or kind == "mirage_delay") and shot.is_queued_for_deletion(), label + "impact finishes and removes projectile")
	var splash := kind in ["cell_spread", "no_ally_spread", "custom_aoe"]
	check(nearby.hp < enemy_hp if splash else nearby.hp == enemy_hp, label + "splash survives lost target; direct shot does not retarget")
	# v0.22.18.2 restored native CellSpread friendly damage; only the legacy
	# custom AoE path still requires force fire. AffectsAllies=no wins in both.
	var friendly_splash:=kind=="cell_spread" or (kind=="custom_aoe" and forced)
	check(friend.hp < friend_hp if friendly_splash else friend.hp == friend_hp, label + "friendly splash follows native warhead or legacy force-fire policy")
	var after: float = nearby.hp
	shot._explode()
	check(nearby.hp == after, label + "impact cannot apply damage twice")
