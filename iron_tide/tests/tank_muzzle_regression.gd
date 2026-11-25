extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	var target=battle.spawn_unit("HTNK","enemy",Vector2(1400,1200))
	for id in ["MTNK","HTNK"]:
		var unit=battle.spawn_unit(id,"ally",Vector2(1000,1000))
		var descriptor:Dictionary=unit._weapon_art
		check(descriptor.get("muzzles",[]).size()==32,id+" has native 32-direction muzzle sockets")
		if descriptor.get("muzzles",[]).size()!=32:continue
		var point:Array=descriptor.muzzle_model_point
		check(float(point[0])>29 and float(point[2])>12,id+" emitter is at the elevated barrel tip")
		for skin in [false,true]:
			unit.special.hero_skin=skin
			if skin:unit.special.academy_hero=id
			unit.refresh_house_color()
			for facing in 32:
				unit.turret_angle=facing*TAU/32.0
				unit.hull_angle=unit.turret_angle+PI/2.0
				unit.aim_dir=Vector2.from_angle(unit.turret_angle)
				var frame:int=unit._sprite_facing(unit._ra2_tur,unit.turret_angle)
				var az:=PI/4-frame*TAU/32.0
				var native:=Vector2(-point[0]*sin(az)+point[1]*cos(az),0.5*(point[0]*cos(az)+point[1]*sin(az))-point[2]*sqrt(0.75))
				var origin:Array=descriptor.origins[frame]
				var base:=RA2Art.draw_rect(unit._ra2,unit.radius,range(32),unit._visual_lift(),Unit.RA2_SPRITE_SCALE).position
				var expected:Vector2=base+(Vector2(origin[0],origin[1])+native)*Unit.RA2_SPRITE_SCALE
				if skin:
					var anchor:Array=Unit.TankHeroSkin.data.units[id].anchor
					check(Vector2(anchor[0],anchor[1]).distance_to(Vector2(origin[0],origin[1]))<0.01,id+" hero armor shares native atlas origin "+str(facing))
				for rocking in [false,true]:
					unit._rock_t=Ra2Damage.rocking_seconds()*0.7 if rocking else 0.0
					unit._rock_amp=1.0
					unit._rock_dir=Vector2.LEFT
					var posed:Vector2=unit.rocking_pose()*expected
					var muzzle:Vector2=unit._weapon_muzzle()
					var label:="%s skin=%s facing=%d rock=%s " % [id,skin,facing,rocking]
					check(Iso.dir(muzzle-unit.global_position).distance_to(posed)<0.01,label+"matches barrel projection, independent of hull")
					var holder=unit._pick_projectile_parent()
					var previous:Array=holder.get_children()
					var host=Effects._host()
					var old_fx:Array=host.get_children()
					unit._fire_shot(target)
					var shots:Array=holder.get_children().filter(func(n):return n is Projectile and not previous.has(n))
					check(shots.size()==1 and shots[0].global_position.distance_to(muzzle)<0.01,label+"real projectile starts at barrel")
					var flashes:Array=host.get_children().filter(func(n):return n is Ra2Fx and not old_fx.has(n))
					check(flashes.size()==1 and flashes[0].global_position.distance_to(muzzle)<0.01,label+"native firing flash shares projectile socket")
					for n in holder.get_children():
						if not previous.has(n):n.free()
					for n in host.get_children():
						if not old_fx.has(n):n.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
