extends "res://tests/fog_rules_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		for id in ["GAYARD", "NAYARD"]:
			for side in ["ally", "enemy"]:
				await dock_at_boundary(mode, id, side)
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks, "failed":failed}))
	get_tree().quit(0 if failed == 0 else 1)

func dock_at_boundary(mode: String, id: String, side: String) -> void:
	start(mode)
	for actor in battle.units + battle.buildings: actor.free()
	battle.units.clear()
	battle.buildings.clear()
	var center := Vector2(1200, 1200)
	var dock = battle._place_building(id, "enemy" if side == "ally" else "ally", center, true)
	dock._buildup_play = -1
	var gun = battle.spawn_unit("MTNK", side, center + RA2Art.art_dir(Vector2.DOWN).normalized() * 300)
	gun.attack_range = 320
	gun.sight = 320
	gun.attack_target = dock
	gun.turret_angle = gun.position.angle_to_point(center)
	gun.attack_ordered = true
	if battle.fog == null:
		battle.fog = preload("res://scripts/world/fog_of_war.gd").new()
		battle.add_child(battle.fog)
		battle.fog.setup(battle)
	battle.fog.rebuild()
	var points: Array[Vector2] = []
	var src := RA2Art.src_rect(dock._ra2, 0)
	var rect := RA2Art.draw_rect(dock._ra2, dock.radius, dock.body_anchor_frames(0), 0, dock.RA2_SPRITE_SCALE)
	var img := RA2Art.sprite_image(dock._ra2)
	for y in range(0, int(src.size.y), 4):
		for x in range(0, int(src.size.x), 4):
			if img.get_pixelv(Vector2i(src.position) + Vector2i(x,y)).a > 0.8:
				points.append(center + RA2Art.art_dir(rect.position + Vector2(x,y) * dock.RA2_SPRITE_SCALE))
	var fog = battle.fog
	check(battle.actor_visible_to(side,dock) and points.any(func(p): return not fog.is_visible_at(side,p)), id+" visible center but partially shrouded artwork before combat")
	check(shoot(gun,dock),id+" fires through unit weapon entry")
	check(points.all(func(p): return fog.is_visible_at(side,p) and (side != "ally" or fog.mask_image.get_pixelv(Vector2i(p / fog.CELL)).a < 0.01)),id+" all opaque hull samples clear immediately")
	check(not fog.is_visible_at(side,center + Vector2.UP * 650),id+" distant coast stays hidden")
	var snapshot = BattleSaves.Snapshot.new()
	snapshot.restore(battle,snapshot.capture(battle))
	gun = battle.units.filter(func(u): return u.unit_id == "MTNK" and u.side == side)[0]
	dock = battle.buildings.filter(func(b): return b.building_id == id)[0]
	get_tree().paused = false
	battle.paused = false
	check(points.all(func(p): return fog.is_visible_at(side,p)),id+" combat visibility survives restore")
	fog._process(2.0)
	check(shoot(gun,dock),id+" fires second salvo")
	fog._process(2.0)
	check(points.all(func(p): return fog.is_visible_at(side,p)),id+" sustained fire keeps whole dock clear")
	dock.receive_hit(10, "shell", {}, gun)
	fog._process(1.1)
	check(points.all(func(p): return fog.is_visible_at(side,p)), id+" delayed impact refreshes visible building")
	fog._process(2.0)
	check(points.any(func(p): return not fog.is_visible_at(side,p)),id+" edge returns to fog after ceasefire")
	gun.global_position += Vector2(750, 300)
	fog.rebuild()
	fog._process(6.0)
	check(not fog.is_visible_at(side,center), id+" lost contact after withdrawal")
	dock.receive_hit(10,"shell",{},gun)
	check(not fog.is_visible_at(side,center), id+" blind splash cannot reveal an unseen building")
	await finish()
