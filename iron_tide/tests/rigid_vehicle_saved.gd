extends Node
const Refresh=preload("res://scripts/units/grizzly_visual_refresh.gd")
var checks:Array=[]
var failed:=0
var micro:Array=[]
var eligible:=0
var moving:=0
var finished:=0
var out:String
func check(ok:bool,label:String):
 checks.append({"passed":ok,"name":label})
 if not ok:failed+=1;print("FAIL ",label)
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS;get_tree().current_scene=null;run.call_deferred()
func signature(unit:Unit)->Array:
 return [unit._body_bounds,unit._art_frame,unit._art_aframes,unit._pick_body_rect,unit._turret_draw_rect,unit._turret_draw_source,unit._shadow_draw_rect,unit.art_center(),unit.hp_bar_rect()]
func capture(unit:Unit):
 var old_position=unit.position;var old_anim=unit._anim
 var records:Array=[]
 var label=unit.side+"/"+unit.unit_id+"/"+str(unit.get_instance_id())
 for pass_index in 6:
  unit.position=old_position;unit._anim=old_anim;unit._draw_pose()
  var draws:=0;var valid:=true
  var begin=Time.get_ticks_usec()
  for i in 100:
   unit.position+=unit.velocity/15.0;unit._anim+=1.0/15
   if pass_index%2==0 or Refresh.refresh(unit):unit._draw_pose();draws+=1
   if pass_index==0:records.append(signature(unit))
   elif pass_index==1:valid=valid and signature(unit)==records[i]
  micro.append({"actor":label,"variant":"before" if pass_index%2==0 else "after","us":Time.get_ticks_usec()-begin,"calls":100,"draws":draws})
  if pass_index==1:check(valid,label+" real saved body, shadow, picking, HUD identical after every translation")
 unit.position=old_position;unit._anim=old_anim;finished+=1
func run():
 out=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if out.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 var meta_path=OS.get_environment("IRON_META")
 if not meta_path.is_empty():
  var expected=JSON.parse_string(FileAccess.get_file_as_string(meta_path))
  check(MetaProgress.unit_cosmetics==expected.get("unit_cosmetics",{}) and MetaProgress.attachment_positions==expected.get("attachment_positions",{}),"actual saved cosmetic profile loaded")
 DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
 DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"),BattleSaves.slot_path("slot1"))
 if not BattleSaves.load_into_scene("slot1").ok:get_tree().quit(2);return
 while get_tree().current_scene==null:await get_tree().process_frame
 get_tree().paused=true
 var world=get_tree().current_scene.battle
 for unit:Unit in world.units:
  if not world.actor_alive(unit):continue
  if unit.velocity.length_squared()>16.0:moving+=1
  if not Refresh.rigid_vehicle(unit) or unit.velocity.length_squared()<=16.0:continue
  eligible+=1;unit.show();unit.draw.connect(capture.bind(unit),CONNECT_ONE_SHOT);unit.queue_redraw()
 await get_tree().process_frame;await get_tree().process_frame
 check(eligible>0 and finished==eligible,"saved moving workload actually rendered "+str([eligible,finished,moving]))
 FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro,"eligible":eligible,"moving":moving,"finished":finished}))
 get_tree().quit(0 if failed==0 else 1)
