extends "res://tests/expedition_regression.gd"
func _ready() -> void:
 output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 new_ready("美国",29)
 check(Expedition.launch(0),"launch")
 if instantiate_battle():
  var t=screen.expedition_runtime.tasks
  check(t.state.kind=="defend" and t.summary().contains("6:00"),"six minutes")
  for u in battle.units:u.position=Vector2(-8000,-8000)
  for i in 8:battle.spawn_unit("E1","ally",t.actor("defense").position)
  t.tick(10.0)
  check(t.state.progress==10.0,"defenders do not speed clock")
  battle.spawn_unit("E1","ally",t.state.points[0]);battle.spawn_unit("E1","ally",t.state.points[2])
  var hostile=battle.spawn_unit("E2","enemy",t.state.points[2]);t.tick(20.0)
  check(t.state.progress==75 and t.state.relay_work==[20.0,0.0],"first relay and contested second")
  hostile.position=Vector2(-8000,-8000);t.tick(20.0);t.tick(1.0)
  check(t.state.progress==141 and t.state.relay_work==[20.0,20.0],"two credits exactly once")
  var seen:Array=[]
  for i in 5:
   var before:int=battle.units.size();t.wave()
   for u in battle.units.slice(before):seen.append(u.unit_id)
  for id in ["TTNK","V3","APOC","ZEP","DESO","DRON"]:check(id in seen,"spawn "+id)
  t.tick(218.0);check(not battle.ended and t.summary().contains("0:01"),"one second remaining")
  t.tick(1.0);check(t.state.outcome==1 and t.state.elapsed==270.0,"win at 4:30")
  await finish()
 for stage in [9,19,24,29]:
  new_ready("美国",stage)
  check(Expedition.launch(0),"launch "+str(stage))
  if instantiate_battle():
   var t=screen.expedition_runtime.tasks
   for u in battle.units:u.position=Vector2(-8000,-8000)
   t.tick(359.0);check(not battle.ended and t.summary().contains("0:01"),"full defense boundary "+str(stage))
   t.tick(1.0);check(t.state.outcome==1 and t.state.elapsed==360.0,"full six minutes "+str(stage))
   await finish()
 print("DEFENSE checks=",checks.size()," failed=",failed)
 get_tree().quit(0 if failed==0 else 1)
