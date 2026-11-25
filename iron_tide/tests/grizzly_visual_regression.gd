extends "res://tests/base_recovery_regression.gd"
const Refresh=preload("res://scripts/units/grizzly_visual_refresh.gd")
const Finish=preload("res://scripts/units/tank_finish.gd")
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	var tank=battle.spawn_unit("MTNK","ally",Vector2(1300,1300))
	tank.special.clear();tank.buffs.clear();tank.hp=tank.max_hp
	tank._hp_flash=0;tank._rock_t=0;tank._muzzle=0;tank._recoil=0
	tank._art_frame=tank._sprite_facing(tank._ra2,tank.hull_angle)
	tank._turret_draw_source=RA2Art.src_rect(tank._ra2_tur,tank._sprite_facing(tank._ra2_tur,tank.turret_angle))
	check(Refresh.eligible(tank),"healthy stock Grizzly uses rigid pose reuse")
	var updates:=0
	for frame in 60:
		if Refresh.refresh(tank):updates+=1
		await get_tree().physics_frame
	check(updates==30,"unchanged hull and turret refresh decorative art at 30 Hz",updates)
	tank.hull_angle+=PI/2
	check(Refresh.refresh(tank),"changed hull frame refreshes immediately")
	tank.hull_angle-=PI/2;tank.turret_angle+=PI/2
	check(Refresh.refresh(tank),"independent turret turn refreshes immediately")
	tank.buffs.append({"kind":"speed"})
	check(Refresh.eligible(tank),"overdrive ring can reuse the same vehicle pose")
	tank.buffs.append({"kind":"regen"})
	check(not Refresh.eligible(tank),"other status animation retains full refresh")
	tank.buffs.clear()
	for key in ["academy_hero","iron_left","chrono_left","reverse_heal_left"]:
		tank.special[key]=1
		check(not Refresh.eligible(tank),"special state bypasses cadence: "+key)
		tank.special.erase(key)
	for key in ["_muzzle","_recoil","_rock_t","_hp_flash","_stun_timer"]:
		tank.set(key,0.5)
		check(not Refresh.eligible(tank),"combat feedback bypasses cadence: "+key)
		tank.set(key,0.0)
	tank.hp-=1;check(not Refresh.eligible(tank),"damage keeps full-rate smoke and feedback")
	tank.hp=tank.max_hp;tank.unit_id="SCHP"
	check(not Refresh.eligible(tank),"deploying aircraft keeps original redraw")
	tank.unit_id="MTNK"
	var paint=Finish.new(4)
	tank.material=HouseColor.material_for(Color.CYAN).duplicate()
	paint.tick(tank,8,true)
	check(is_equal_approx(tank.special.cobalt_travel,1.0),"crystallization still reaches full in eight seconds")
	check(is_equal_approx(float(tank.material.get_shader_parameter("crystal_growth")),1.0),"shader receives full crystal value")
	paint.tick(tank,2)
	check(is_equal_approx(tank.special.cobalt_travel,0.5),"parking still fades over four seconds")
	var replacement=tank.material.duplicate();replacement.set_shader_parameter("crystal_growth",0.0)
	tank.material=replacement
	paint.tick(tank,0)
	check(is_equal_approx(float(replacement.get_shader_parameter("crystal_growth")),0.5),"new material immediately receives current crystal state")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
