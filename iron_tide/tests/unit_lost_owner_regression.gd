extends "res://tests/base_recovery_regression.gd"
const EVENT="EVA_UNITLOST"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		for country in ["美国","苏俄"]:
			BattleRequest.configure_skirmish(mode,{"houses":[{"country":country,"team":1,"seat":0},{"country":"苏俄","team":2,"seat":1},{"country":"美国","team":1,"seat":2},{"country":"美国","team":2,"seat":3}],"country":country,"map_layout":"yr_crctbrd","starting_funds":12000})
			screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
			screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
			check(BattleRequest.friendly("ally","ai2") and not BattleRequest.friendly("ally","enemy"),mode+country+" actual team setup")
			for owner in ["ai2","enemy","ai3","neutral","ally"]:
				var unit=battle.spawn_unit("E1",owner,Vector2(1200,1200))
				Ra2Sfx.stop_all()
				var plays:int=Ra2Sfx.a_eva_plays
				var queued:int=Ra2Sfx.a_eva_queued
				unit.hp=0;unit._die(null,true)
				check(unit._dead,mode+country+" real death "+owner)
				if owner=="ally":
					check(Ra2Sfx._eva_last.has(EVENT) and Ra2Sfx.a_eva_plays==plays+1,mode+country+" own death announces Unit Lost")
				else:
					check(not Ra2Sfx._eva_last.has(EVENT) and Ra2Sfx.a_eva_plays==plays and Ra2Sfx.a_eva_queued==queued and Ra2Sfx._eva_queue.is_empty(),mode+country+" non-player death neither plays nor queues "+owner)
			var teammate=battle.spawn_unit("E1","ai2",Vector2(1400,1200))
			var last:Dictionary=Ra2Sfx._eva_last.duplicate()
			var queue:Array=Ra2Sfx._eva_queue.duplicate(true)
			var count:int=Ra2Sfx.a_eva_plays
			teammate.hp=0;teammate._die(null,true)
			check(Ra2Sfx._eva_last==last and Ra2Sfx._eva_queue==queue and Ra2Sfx.a_eva_plays==count,mode+country+" teammate death leaves existing player announcement untouched")
			check_carrier_deaths(mode+country)
			Ra2Sfx.stop_all();await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)

func check_carrier_deaths(label: String) -> void:
	if battle.fog != null: battle.fog.free(); battle.fog=null
	var ship=battle.spawn_unit("CARRIER","ally",Vector2(1600,1450))
	var target=battle.spawn_unit("MTNK","enemy",Vector2(1600,1650))
	ship.order_target(target,false,false)
	ship.logistics.tick_squadron(0.0)
	var plane=ship.logistics.squadron[0].unit
	check(is_instance_valid(plane) and plane.unit_id=="HORNET",label+" actual carrier launches Hornet")
	if not is_instance_valid(plane): return
	Ra2Sfx.stop_all()
	var plays:int=Ra2Sfx.a_eva_plays
	var queued:int=Ra2Sfx.a_eva_queued
	plane.hp=0;plane._die(null,true)
	check(plane._dead and ship.logistics.squadron[0].unit==null and ship.logistics.squadron[0].timer>0,label+" lost Hornet still dies and starts replacement timer")
	check(not Ra2Sfx._eva_last.has(EVENT) and Ra2Sfx.a_eva_plays==plays and Ra2Sfx.a_eva_queued==queued and Ra2Sfx._eva_queue.is_empty(),label+" Hornet death neither plays nor queues Unit Lost")
	ship.hp=0;ship._die(null,true)
	check(ship._dead and ship.logistics.squadron.is_empty(),label+" carrier death still destroys remaining squadron")
	check(Ra2Sfx._eva_last.has(EVENT) and Ra2Sfx.a_eva_plays==plays+1 and Ra2Sfx.a_eva_queued==queued,label+" carrier loss announces exactly once without squadron announcements")
	var last:Dictionary=Ra2Sfx._eva_last.duplicate()
	var orphan=battle.spawn_unit("HORNET","ally",Vector2(1700,1450))
	orphan.hp=0;orphan._die(null,true)
	check(Ra2Sfx._eva_last==last and Ra2Sfx.a_eva_plays==plays+1 and Ra2Sfx.a_eva_queued==queued,label+" ownerless Hornet leaves existing announcement untouched")
	Ra2Sfx.stop_all()
	var jet=battle.spawn_unit("ORCA","ally",Vector2(1800,1450))
	jet.hp=0;jet._die(null,true)
	check(Ra2Sfx._eva_last.has(EVENT) and Ra2Sfx.a_eva_plays==plays+2,label+" ordinary aircraft still announces Unit Lost")
