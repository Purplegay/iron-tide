extends Node
const Campaign = preload("res://scripts/world/skirmish_campaign.gd")
var checks:Array=[]
var failed:=0
func check(ok:bool,label:String):
 checks.append({"name":label,"passed":ok})
 if not ok:failed+=1;print("FAIL ",label)
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS
 get_tree().current_scene=null
 run.call_deferred()
func run():
 var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if out.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
 DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"),BattleSaves.slot_path("slot1"))
 if not BattleSaves.load_into_scene("slot1").ok:get_tree().quit(2);return
 while get_tree().current_scene==null:await get_tree().process_frame
 get_tree().paused=true
 var world=get_tree().current_scene.battle
 var ai=world.house_controllers.ai2
 var state:Dictionary=ai.ai_state
 var alarm:Dictionary=state.brutal_alarm.duplicate(true)
 check(BattleRequest.skirmish_config.houses[2].color=="gray","saved white AI selected")
 check(not alarm.base and alarm.point.distance_to(ai.base_center)>2000,"saved alarm comes from remote field combat")
 var guards_before:=Campaign.guards(ai)
 check(guards_before==37,"saved surplus consists of 37 guards")
 var original_roles:Dictionary={}
 var eligible:=0
 for unit in world.units:
  if Campaign.eligible(ai,unit):
   original_roles[unit]=unit.special.get(Campaign.ROLE,"")
   eligible+=1
 state.brutal_alarm=alarm.duplicate(true)
 state.brutal_alarm.base=true
 Campaign.rebalance(ai)
 check(Campaign.guards(ai)==guards_before,"building alarm retains all saved reserves")
 state.brutal_alarm.erase("base")
 Campaign.rebalance(ai)
 check(Campaign.guards(ai)==guards_before,"legacy alarm without base flag retains reserves")
 state.brutal_alarm=alarm
 Campaign.rebalance(ai)
 var promoted:Array=[]
 for unit in original_roles:
  if original_roles[unit]=="guard" and unit.special.get(Campaign.ROLE)=="attack":
   promoted.append(unit)
   check(not unit.repairing and not world.actor_alive(unit.attack_target) and not unit.special.has("brutal_relief_at"),"only idle unassigned guard promoted "+str(unit.get_instance_id()))
 check(promoted.size()>9 and Campaign.guards(ai)>=Campaign.HOME_GUARD,"saved idle surplus joins offense while retaining ten guards and busy responders")
 ai._form_wave(state)
 var attempts:=0
 while state.has("attack_dispatch") and attempts<128:
  ai.dispatch_attacker(state)
  attempts+=1
 for unit in promoted:
  check(unit.has_move_order and unit.attack_move or unit.special.has("ai_dispatch_pending"),"real sortie order issued "+str(unit.get_instance_id()))
 var saved:Dictionary=BattleSaves.Snapshot.new().capture(world)
 check(BattleSaves.validate(saved).is_empty(),"updated roles and orders remain valid save data")
 FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"meta_cosmetics":MetaProgress.unit_cosmetics,"checks":checks,"failed":failed,"guards_before":guards_before,"guards_after":Campaign.guards(ai),"promoted":promoted.size()},"  "))
 get_tree().quit(0 if failed==0 else 1)
