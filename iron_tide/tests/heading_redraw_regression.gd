extends "res://tests/base_recovery_regression.gd"
const Actor=preload("res://tests/heading_redraw_actor.gd")
var counts:Array=[]
func before(unit:Unit)->void:
	if not unit._harvest_heading_free():return
	if unit.velocity.length()>12.0:
		unit.aim_dir=unit.velocity.normalized()
		unit.turret_angle=unit.aim_dir.angle()
		unit.hull_angle=unit.turret_angle
		unit.queue_redraw()
func frame()->void:
	await get_tree().process_frame
	await get_tree().process_frame
func _ready()->void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	for id in ["HTNK","APOC","HTK","FV","TTNK","SREF","E1","HARV","MTNK"]:
		var actor=Actor.new();actor.setup(GameData.get_unit(id),"enemy",Vector2(1100,1100))
		battle.add_child(actor);actor.process_mode=Node.PROCESS_MODE_ALWAYS;actor.set_physics_process(false);actor.set_process(false)
		actor.special={"ai_campaign_role":"assault","progression_v1":{"shot_idle":1.0,"arc_count":0},"reveal":1.0}
		actor.passive={};actor.buffs=[];actor.selected=false;actor.hovered=false;actor.hp=actor.max_hp
		actor._muzzle=0;actor._recoil=0;actor._rock_t=0;actor._stun_timer=0;actor._hp_flash=0
		var expected:Array=[]
		for variant in [false,true]:
			actor.position=Vector2(1100,1100);actor.hull_angle=0.0;actor.turret_angle=0.0;actor.aim_dir=Vector2.RIGHT
			actor.velocity=Vector2(70,0);actor.queue_redraw();await frame()
			var begin:int=actor.draw_count
			for step in 24:
				actor.position+=Vector2(4,0)
				actor.velocity=Vector2.from_angle(float(step/8)*0.6)*70.0
				if variant:actor._face_if_moving()
				else:before(actor)
				await frame()
				if not variant:expected.append([actor.signature(),actor.aim_dir,actor.hull_angle,actor.turret_angle])
				else:check([actor.signature(),actor.aim_dir,actor.hull_angle,actor.turret_angle]==expected[step],id+" actual queued drawing and movement state "+str(step))
			counts.append({"id":id,"after":variant,"draws":actor.draw_count-begin})
			if variant and id in ["HTNK","APOC","HTK","FV","TTNK","SREF"]:check(actor.draw_count-begin==2,id+" only two actual heading changes redraw")
		for field in ["selected","hovered"]:
			actor.set(field,true);await verify_refresh(actor,id+" "+field);actor.set(field,false)
		for field in ["_muzzle","_recoil","_rock_t","_stun_timer","_hp_flash"]:
			actor.set(field,1.0);await verify_refresh(actor,id+" "+field);actor.set(field,0.0)
		actor.special.new_effect=true;await verify_refresh(actor,id+" unknown effect");actor.special.erase("new_effect")
		actor.special.progression_v1.arc_count=1;await verify_refresh(actor,id+" live overlay");actor.special.progression_v1.arc_count=0
		actor.hp=actor.max_hp*.3;await verify_refresh(actor,id+" damage smoke")
		if id=="HARV":
			for state in ["back_in","unloading","docking"]:
				actor._back_in=state=="back_in"
				actor.harvest_state="unloading" if state=="unloading" else "to_base"
				actor._dock_phase=1 if state=="docking" else 0
				actor.hull_angle=0.25;actor.turret_angle=0.5;actor.aim_dir=Vector2.UP
				actor._face_if_moving()
				check(actor.hull_angle==0.25 and actor.turret_angle==0.5 and actor.aim_dir==Vector2.UP,"harvester preserves "+state)
		actor.free()
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"draw_counts":counts},"  "))
	get_tree().quit(0 if failed==0 else 1)
func verify_refresh(actor:Unit,label:String)->void:
	actor.queue_redraw();await frame()
	var previous:int=actor.draw_count
	actor._face_if_moving();await frame()
	check(actor.draw_count>previous,label+" keeps immediate drawing")
