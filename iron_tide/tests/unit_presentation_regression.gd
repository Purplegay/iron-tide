extends "res://tests/base_recovery_regression.gd"
const Idle = preload("res://scripts/units/unit_expansion_idle.gd")
const Expansion = preload("res://scripts/units/progression_expansion.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	var old_interpolation:=get_tree().physics_interpolation
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		check(Engine.physics_ticks_per_second==15,prefix+"visual interpolation does not increase simulation frequency")
		check(get_tree().physics_interpolation,prefix+"native interpolation enabled in battle")
		check(screen.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_OFF,prefix+"camera and HUD do not inherit interpolation")
		var actor:Unit=battle.spawn_unit("MTNK","enemy",Vector2(700,700))
		check(actor.is_physics_interpolated_and_enabled(),prefix+"moving Unit explicitly interpolates")
		actor.hull_angle=deg_to_rad(170)
		actor.turret_angle=deg_to_rad(-170)
		actor.motion_pose.capture(actor)
		actor.hull_angle=deg_to_rad(-170)
		actor.turret_angle=deg_to_rad(170)
		var before:=Vector3(actor.hull_angle,actor.turret_angle,actor.hp)
		check(absf(absf(actor.motion_pose.hull(actor,.5))-PI)<.0001,prefix+"hull takes short turn across angle wrap")
		check(absf(absf(actor.motion_pose.turret(actor,.5))-PI)<.0001,prefix+"turret takes independent short turn")
		check(before==Vector3(actor.hull_angle,actor.turret_angle,actor.hp),prefix+"sampling changes no combat state")
		actor.motion_pose.previous_position=actor.position-Vector2(100,0)
		check(actor.motion_pose.point(actor,.5)==actor.position-Vector2(50,0),prefix+"halfway display pose is independent of collider")
		actor.position+=Vector2(300,0)
		check(actor.motion_pose.previous_position==actor.position,prefix+"out-of-physics teleport resets sample")
		actor.reset_physics_interpolation()
		check(not actor.motion_pose.turning(actor),prefix+"spawn/load reset removes old bearing")
		actor.motion_pose.previous_position-=Vector2(100,0)
		actor.set_stowed(null)
		check(actor.motion_pose.previous_position==actor.position,prefix+"disembarking resets old transport position")
		actor.motion_pose.previous_hull=0
		actor.hull_angle=.5
		actor.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		check(is_equal_approx(actor.hull_angle,.5) and is_equal_approx(actor.turret_angle,before.y),prefix+"render callback restores authoritative bearings")
		actor.motion_pose.previous_position-=Vector2(100,0)
		actor.notification(Node.NOTIFICATION_PAUSED)
		check(actor.motion_pose.previous_position==actor.position,prefix+"pause freezes current pose without a pending slide")
		if mode==MatchRules.EXTENDED:
			for id in ["E1","MTNK","HTNK","MGTK","TTNK","V3","HTK","DLPH","CARRIER","BEAG","DEST","SHK"]:
				var candidate:Unit=battle.spawn_unit(id,"enemy",Vector2(1000,1000))
				exercise_idle(candidate)
				battle.units.erase(candidate)
				candidate.free()
		await finish()
		check(get_tree().physics_interpolation==old_interpolation,prefix+"leaving battle restores global interpolation")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)

func exercise_idle(actor:Unit) -> void:
	for side in ["enemy","ai2","ai3","ai4","ai5","neutral"]:
		actor.side=side
		actor.passive={}
		for state in [{},{"shot_idle":1.2},{"arc_count":7,"rest":3.0,"shot_origin":Vector2(1,2),"scrap_idle":.2,"scrap_drop":1,"volley":3},{"arc_count":0,"shot_idle":2.5,"rest":0.0,"shot_origin":Vector2(80,90),"scrap_idle":0,"scrap_drop":0,"volley":30,"prism_damage":0.0}]:
			for delta in [0.0,1.0/15.0,.2,1.0]:
				actor.special.progression_v1=state.duplicate(true)
				Expansion.Cards.tick(actor,delta)
				Expansion.Talents.tick(actor,delta)
				Expansion.Heroes.tick(actor,delta)
				var expected:Dictionary=actor.special.progression_v1.duplicate(true)
				actor.special.progression_v1=state.duplicate(true)
				check(Idle.try_tick(actor,delta) and actor.special.progression_v1==expected,"idle expansion equals original handlers: "+side)
	for key in ["speed_bonus","speed_left","mark","taunt","nests","tracking","afterburn","move_lock","succession","crown","future_unknown_effect","prism_damage"]:
		actor.special.progression_v1={key:1.0}
		var expected:Dictionary=actor.special.progression_v1.duplicate(true)
		check(not Idle.try_tick(actor,.1) and actor.special.progression_v1==expected,"new/active state wakes original handlers: "+key)
	actor.special.progression_v1={}
	actor.side="ally"
	var autonomous := Expansion.R.talent_rank(actor,"mirage_afterheat")>=0 or Expansion.R.talent_rank(actor,"ground_capacitor")>=0
	if autonomous:
		check(not Idle.try_tick(actor,.1) and actor.special.progression_v1.is_empty(),"active player talent retains full handler without consuming time")
	else:
		Expansion.Cards.tick(actor,.1)
		Expansion.Talents.tick(actor,.1)
		Expansion.Heroes.tick(actor,.1)
		var expected:Dictionary=actor.special.progression_v1.duplicate(true)
		actor.special.progression_v1={}
		check(Idle.try_tick(actor,.1) and actor.special.progression_v1==expected,"player bookkeeping matches original handlers when no autonomous talent is active")
	actor.side="enemy";actor.passive={"id":"ps_spine_scrap"}
	check(not Idle.try_tick(actor,.1),"autonomous scrap passive keeps its full update")
