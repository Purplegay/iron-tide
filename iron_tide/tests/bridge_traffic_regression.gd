extends "res://tests/base_recovery_regression.gd"
const Traffic = preload("res://scripts/world/bridge_traffic.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	battle.fog=null
	var metric=Traffic.new()
	metric.initialized=true
	metric.decks=[Rect2(1000,1000,400,100)]
	var unit:Unit=battle.spawn_unit("MTNK","ally",Vector2(1100,1050))
	unit.has_move_order=true;unit.move_target=Vector2(1350,1050)
	var before:Vector2=unit.position
	for tick in 5:metric.sample(battle,1.0)
	metric.note(battle,unit,"yield_requested",unit)
	metric.note(battle,unit,"yield_rejected_busy",unit)
	var report:Dictionary=metric.take()
	check(unit.position==before and unit.has_move_order and unit.move_target==Vector2(1350,1050),"diagnostics never move or redirect actor")
	check(report.waiting_sample_count==1 and report.longest_waiting[0].no_progress_s==4.0,"continuous no-progress observation uses active simulation time")
	check(report.bridges[0].events.yield_requested==1 and report.bridges[0].events.yield_rejected_busy==1,"per-bridge event counts are exact")
	check(report.bridges[0].busy_reasons.move_order==1,"busy refusal classifies moving order")
	check(report.bridges[0].peak_waiter.unit==unit.get_instance_id() and report.bridges[0].peak_waiter.no_progress_s==4.0,"peak observation retains actor identity and duration")
	check(report.sampled_actor_visits==5,"single actor sampling does not repeat within one frame")
	check(metric.take().bridges.is_empty(),"window event counts reset after export")
	unit.position+=Vector2(9,0);metric.sample(battle,1.0)
	check(metric.take().waiting_sample_count==0,"eight-pixel progress resets waiting duration")
	for tick in 4:metric.sample(battle,1.0)
	unit.has_move_order=false;metric.sample(battle,1.0)
	report=metric.take()
	check(report.waiting_sample_count==0,"stopped order removes intentional idle actor")
	check(report.bridges[0].peak_waiter.unit==unit.get_instance_id() and report.bridges[0].peak_waiter.no_progress_s==4.0,"peak identity survives progress or loss of movement intent before export")
	check(report.bridges[0].peak_waiter.position==[1109.0,1050.0],"peak snapshot retains observed position")
	unit.has_move_order=true;unit.position=Vector2(500,500);metric.sample(battle,1.0)
	metric.note(battle,unit,"yield_requested")
	check(metric.take().bridges.is_empty(),"off-bridge events excluded")
	for i in 40:battle.spawn_unit("E1","enemy",Vector2(500+i,500))
	metric.sample(battle,1.0)
	check(metric.take().sampled_actor_visits==Traffic.BUDGET,"dense battle is capped at sixteen actor visits per frame")
	unit.position=Vector2(1100,1050)
	for i in 100:metric.note(battle,unit,"head_on")
	report=metric.take()
	check(report.recent_events.size()==1 and report.suppressed_duplicate_details==99 and report.bridges[0].events.head_on==100,"duplicate details sampled without losing exact totals")
	for i in 60:metric.note(battle,unit,"test_event_"+str(i))
	report=metric.take()
	check(report.recent_events.size()==Traffic.RECENT_LIMIT and report.recent_events[0].event=="test_event_12","recent sampled details remain bounded and ordered")
	var blocker:Unit=battle.spawn_unit("MTNK","ally",Vector2(1120,1050))
	var fields: Array = ["has_move_order","hold_position","_deployed","is_harvester","repairing","is_air","is_naval","attack_target","_stun_timer"]
	var reasons: Array = ["move_order","hold_position","deployed","harvester","repairing","air","naval","attack_target","stunned"]
	for i in fields.size():
		blocker.set(fields[i],unit if fields[i]=="attack_target" else (1.0 if fields[i]=="_stun_timer" else true))
	for i in fields.size():
		metric.note(battle,unit,"yield_rejected_busy",blocker)
		check(metric.busy_reason(blocker)==reasons[i],"busy reason uses original first-match precedence: "+reasons[i])
		blocker.set(fields[i],null if fields[i]=="attack_target" else (0.0 if fields[i]=="_stun_timer" else false))
	report=metric.take()
	check(report.bridges[0].busy_reasons.size()==reasons.size() and report.bridges[0].events.yield_rejected_busy==reasons.size(),"busy reasons partition exact refusal count")
	blocker.side="enemy";blocker.hold_position=true;blocker.special.ai_campaign_role="guard"
	check(metric.busy_reason(blocker)=="unknown","mobile AI guard exemption is preserved")
	blocker.special.action="test"
	check(metric.busy_reason(blocker)=="hold_position","explicit AI action disables guard exemption")
	check(JSON.parse_string(JSON.stringify(report)) is Dictionary,"traffic report round-trips through JSON")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
