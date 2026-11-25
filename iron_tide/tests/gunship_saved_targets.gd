extends Node
const Old=preload("res://tests/gunship_before_mounts.gd")
const New=preload("res://scripts/units/ra3_gunship_mounts.gd")
var checks:Array=[]
var failed:=0
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 get_tree().current_scene=null
 run.call_deferred()
func run() -> void:
 var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
 var source:=OS.get_environment("IRON_SAVE")
 if source.is_empty() or out.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
 if DirAccess.copy_absolute(source,BattleSaves.slot_path("slot1"))!=OK or not BattleSaves.load_into_scene("slot1").ok:get_tree().quit(2);return
 while get_tree().current_scene==null:await get_tree().process_frame
 get_tree().paused=true
 var world=get_tree().current_scene.battle
 var fleet:Array=[]
 for actor in world.units:
  if actor.unit_id=="R3HARBINGER":fleet.append(actor)
 if fleet.is_empty():get_tree().quit(2);return
 for actor in fleet:
  var old_heading:float=actor.hull_angle
  for angle in 16:
   actor.hull_angle=angle*TAU/16.0
   for key in ["front","side","rear"]:
    var same:=is_same(Old.choose(actor,key),New.choose(actor,key))
    checks.append({"passed":same,"name":"saved actor "+str([actor.side,actor.position,angle,key])})
    if not same:failed+=1
  actor.hull_angle=old_heading
 var micro:Array=[]
 for sample in 18:
  var begun:=Time.get_ticks_usec()
  for i in 8:
   for actor in fleet:
    for key in ["side","rear"]:
     if sample%2==0:Old.choose(actor,key)
     else:New.choose(actor,key)
  micro.append({"variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":fleet.size()*16})
 FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro,"gunships":fleet.size(),"units":world.units.size(),"buildings":world.buildings.size()}))
 get_tree().quit(0 if failed==0 else 1)
