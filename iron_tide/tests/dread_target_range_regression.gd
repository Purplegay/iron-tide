extends "res://tests/base_recovery_regression.gd"

func acquire(gun:Unit):
	gun.attack_target=null
	gun._scan_grant_until=2147483647
	gun._refresh_target()
	return gun.attack_target

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		battle.fog=null
		var gun:Unit=battle.spawn_unit("DRED","ally",Vector2(800,1200))
		gun.order_stop();gun.fire_stance="free";gun.hold_position=true
		var group:=BattleRequest.foes_group(gun.side)
		for foe in get_tree().get_nodes_in_group(group):foe.remove_from_group(group)
		for id in ["GACNST","GAPOWR","NAYARD"]:
			var target:Building=battle._place_building(id,"enemy",Vector2(1400,1200),true)
			for elite in [false,true]:
				gun.veteran_level=2 if elite else 0
				gun._refresh_veteran_bonuses(false)
				var reach:=OpenTopped.command_range(gun,target)
				check(reach>gun.attack_range,mode+" building adds command reach "+id)
				for heading in [0.0,0.7,2.1,3.8]:
					for margin in [-0.5,0.5,800.0]:
						gun.position=target.position+Vector2.from_angle(heading)*(reach+margin)
						check(is_same(acquire(gun),target) if margin<0 else acquire(gun)==null,mode+" foundation range boundary "+id+" "+str(margin))
				gun.hold_position=false
				gun.position=target.position+Vector2.RIGHT*(reach+55)
				gun._return_timer=3;gun.special.retaliation_target=target;gun.special.retaliation_origin=gun.position
				check(is_same(acquire(gun),target),mode+" known attacker retained beyond ordinary reach "+id)
				gun._return_timer=0;gun.special.erase("retaliation_target");gun.special.erase("retaliation_origin")
				gun.position=target.position+Vector2.RIGHT*(reach+800)
				gun.attack_target=target;gun.attack_ordered=true;gun._scan_grant_until=2147483647;gun._refresh_target()
				check(is_same(gun.attack_target,target),mode+" distant explicit order retained "+id)
				gun.attack_ordered=false;gun.hold_position=true
			# Equal-score targets retain scene/group order, not spatial bucket order.
			var second:Building=battle._place_building(id,"enemy",target.position,true)
			gun.position=target.position+Vector2.RIGHT*(gun.attack_range-20)
			check(is_same(acquire(gun),target),mode+" equal-score first target preserved "+id)
			target.hp=0
			check(is_same(acquire(gun),second),mode+" dead first target rejected "+id)
			target.remove_from_group(group);second.remove_from_group(group)
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks.size(),"failed":failed,"cases":checks},"  "))
	get_tree().quit(0 if failed==0 else 1)
