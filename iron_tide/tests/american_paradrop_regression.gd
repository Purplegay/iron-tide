extends "res://tests/base_recovery_regression.gd"
const Drop = preload("res://scripts/world/american_paradrop.gd")
const Snapshot = preload("res://scripts/save/battle_snapshot.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		await exercise(mode)
	var out := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks":checks,"failed":failed}))
	out.close()
	get_tree().quit(0 if failed == 0 else 1)

func exercise(mode: String) -> void:
	start(mode)
	var field = battle._place_building("GAAIRC","ally",Vector2(500,600),true)
	var second = battle._place_building("GAAIRC","ally",Vector2(800,600),true)
	field._buildup_play = -1
	second._buildup_play = -1
	battle._countries.enemy = "French"
	var french = battle._place_building("GAAIRC","enemy",Vector2(1600,200),true)
	check(french.superweapon.is_empty() and field.sw_type()=="AmerParaDrop",prefix+"American airfield grants national support")
	field._tick_superweapon(239)
	second._tick_superweapon(239)
	check(not field.sw_ready() and is_equal_approx(second._sw_charge,239.0),prefix+"two fields share a single four minute clock")
	field._tick_superweapon(1)
	var panel = battle.hud._sw_sidebar
	panel.refresh()
	check(field.sw_ready() and panel.buttons.has(field.get_instance_id()) and not panel.buttons.has(second.get_instance_id()) and panel.buttons[field.get_instance_id()].icon != null,prefix+"one ready sidebar button with original icon")
	panel.buttons[field.get_instance_id()].pressed.emit()
	var target := Vector2(1200,1300)
	check(battle.command_cursor.resolve(target) == "para_drop" and battle.command_cursor.resolve(Vector2(-50,0)) == "blocked", prefix+"targeting cursor and boundary")
	battle._issue_command_at(Vector2(-50,0))
	check(field.sw_ready(),prefix+"invalid point preserves ready charge")
	battle._issue_command_at(target)
	var planes: Array = battle.units.filter(func(u): return u.unit_id=="PDPLANE")
	check(planes.size()==1 and field._sw_charge==0 and not second.sw_ready(),prefix+"targeting spawns one support plane")
	if planes.is_empty():
		await finish()
		return
	var plane = planes[0]
	for i in 500:
		plane._physics_process(0.05)
		if plane.special.para_left < 8: break
	var troops: Array = battle.units.filter(func(u): return u.unit_id=="E1" and u.special.has("para_height"))
	check(troops.size() > 0 and troops.size()<8 and troops[0].is_air_target() and not troops[0].set_deployed(true,false),prefix+"infantry leaves aircraft progressively under parachute")
	var codec := Snapshot.new()
	var snap := codec.capture(battle)
	check(BattleSaves.validate(snap).is_empty(),prefix+"aircraft and open parachutes validate in mid-drop save",BattleSaves.validate(snap))
	codec.restore(battle,snap)
	get_tree().paused=false
	battle.paused=false
	plane = battle.units.filter(func(u): return u.unit_id=="PDPLANE")[0]
	for i in 500:
		plane._physics_process(0.1)
		if plane._dead: break
	troops = battle.units.filter(func(u): return u.unit_id=="E1" and u.special.has("para_height"))
	check(plane._dead and troops.size()==8,prefix+"resume delivers eight GIs exactly once then plane exits")
	for u in troops:
		u._physics_process(45)
	check(troops.all(func(u): return battle.actor_alive(u) and not u.is_air_target() and u.is_in_group("ground_units") and not u.is_in_group("air_units") and not u.special.has("para_height") and u.collision_layer!=0),prefix+"touchdown restores live ground infantry")
	battle.select_unit(troops[0],false)
	battle._issue_order(troops[0].position + Vector2(0,120))
	check(troops[0].has_move_order and troops[0].set_deployed(true,false),prefix+"landed GI accepts normal player movement and deployment")
	battle._countries.enemy = "Americans"
	var ai_field = battle._place_building("GAAIRC","enemy",Vector2(1700,200),true)
	ai_field._buildup_play = -1
	ai_field._sw_charge = ai_field.sw_recharge()
	var ops = preload("res://scripts/world/skirmish_operations.gd")
	ops.tick(battle.skirmish_ai)
	var enemy_planes: Array = battle.units.filter(func(u): return battle.actor_alive(u) and u.unit_id=="PDPLANE" and u.side=="enemy")
	check(enemy_planes.size()==1,prefix+"American AI launches using visible objectives")
	if not enemy_planes.is_empty():
		var intercepted = enemy_planes[0]
		intercepted.receive_hit(100000)
		intercepted._physics_process(10)
		check(intercepted._dead and intercepted.special.para_left==8 and not battle.units.any(func(u): return u.unit_id=="E1" and u.side=="enemy" and not u.special.get("escaped_driver", false)),prefix+"interception prevents unreleased troops from appearing")
	await finish()
