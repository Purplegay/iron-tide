extends Node
const Actor=preload("res://tests/target_cadence_actor.gd")
const Reference=preload("res://tests/target_cadence_reference.gd")
var checks:Array=[]
var failed:=0
func check(ok:bool,label:String,details=null):
	checks.append({"passed":ok,"name":label,"details":details})
	if not ok:failed+=1;print("FAIL ",label," ",details)
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS;get_tree().current_scene=null;run.call_deferred()
func make(world,old:bool,side:String,point:Vector2):
	var u=Reference.new() if old else Actor.new()
	u.setup(GameData.get_unit("MTNK").duplicate(true),side,point)
	u._combat_world=world
	world.add_child(u);world.units.append(u)
	u.set_physics_process(false);u.set_process(false)
	u.fire_stance="free";u.hold_position=true;u._think_timer=0;u._cd_timer=0.2
	return u
func run():
	var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if out.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
	DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"),BattleSaves.slot_path("slot1"))
	if not BattleSaves.load_into_scene("slot1").ok:get_tree().quit(2);return
	while get_tree().current_scene==null:await get_tree().process_frame
	get_tree().paused=true
	var world=get_tree().current_scene.battle
	check(world.units.size()>300 and world.house_controllers.size()==5,"original six-house save loads")
	var fog=world.fog;world.fog=null
	var victim=make(world,false,"ally",Vector2(1080,1000))
	var probe=make(world,false,"enemy",Vector2(1000,1000))
	var all_units:Array=world.units
	for population in [127,128]:
		world.units=all_units.slice(0,population)
		for side in ["ally","enemy","ai5"]:
			for has_target in [false,true]:
				for ordered in [false,true]:
					for moving in [false,true]:
						for assault in [false,true]:
							for retaliation in [false,true]:
								probe.side=side;probe.attack_target=victim if has_target else null
								probe.attack_ordered=ordered;probe.has_move_order=moving;probe.attack_move=assault;probe._return_timer=1.0 if retaliation else 0.0
								var extended:bool=population==128 and side!="ally" and not ordered and not retaliation and (has_target or (not moving and not assault))
								check(is_equal_approx(probe._target_refresh_interval(),0.64 if extended else 0.32),"scan cadence policy "+str([population,side,has_target,ordered,moving,assault,retaliation]))
	world.units=all_units;world.units.erase(probe);probe.free()
	var metrics:Array=[]
	for speed in [1.0,3.0]:
		BattleClock.set_speed(speed)
		for side in ["ally","enemy"]:
			for explicit in [false,true]:
				var before=make(world,true,side,Vector2(1000,1000));var after=make(world,false,side,Vector2(1000,1000))
				victim.side="ai3" # The saved enemy seat is allied with ally; ai3 is on team 2.
				for unit in [before,after]:unit.attack_target=victim;unit.attack_ordered=explicit
				for tick in 300:
					before._physics_process(speed/15.0);after._physics_process(speed/15.0)
					check(before.shots==after.shots and before._cd_timer==after._cd_timer and before._burst_left==after._burst_left,"same per-step fire/reload "+str([speed,side,explicit,tick]))
				check(before.shots>0,"actual firing path exercised "+str([speed,side,explicit]),[before.shots,before._weapon_target_valid(victim),before._weapon_domain_valid(victim,true),before._weapon_aligned(victim),before.logistics.can_start_volley(),before.global_position,victim.global_position,before.attack_range,before._cd_timer,before.special,victim.special,BattleRequest.house_teams])
				check(after.scans<before.scans if side!="ally" and not explicit else after.scans==before.scans,"only autonomous AI scans decrease "+str([speed,side,explicit]),[before.scans,after.scans])
				metrics.append({"speed":speed,"side":side,"explicit":explicit,"scans":[before.scans,after.scans],"shots":[before.shots,after.shots]})
				for unit in [before,after]:world.units.erase(unit);unit.free()
	BattleClock.set_speed(1.0)
	victim.side="ally"
	probe=make(world,false,"enemy",Vector2(1000,1000))
	probe.attack_target=victim;probe._think_timer=0.64;victim.hp=0
	probe._physics_process(1.0/15.0)
	check(probe.scans==1 and probe.attack_target==null,"dead target in extra wait segment triggers next-step scan")
	world.units.erase(victim);victim.free();world.units.erase(probe);probe.free();world.fog=fog
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"failed":failed,"checks":checks,"metrics":metrics},"  "))
	get_tree().quit(0 if failed==0 else 1)
