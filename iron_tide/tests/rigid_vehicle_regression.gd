extends "res://tests/base_recovery_regression.gd"
const Actor=preload("res://tests/rigid_vehicle_actor.gd")
const Refresh=preload("res://scripts/units/grizzly_visual_refresh.gd")
var micro:Array=[]
func _ready():
 output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 start(MatchRules.EXTENDED)
 for id in ["HTNK","APOC","HTK","FV","TTNK","SREF"]:
  var unit=Actor.new();unit.setup(GameData.get_unit(id),"enemy",Vector2(1100,1100))
  battle.add_child(unit);unit.process_mode=Node.PROCESS_MODE_DISABLED;unit.queue_redraw()
  await get_tree().process_frame;await get_tree().process_frame
  check(unit.completed and unit.comparisons==120 and unit.mismatches.is_empty(),id+" retained sprites, shadows, picking and bars match every movement/turn step",unit.mismatches)
  micro.append_array(unit.micro)
  check(Refresh.eligible(unit),id+" stock rigid body eligible")
  for row in unit.micro:
   check(row.draws==120 if row.variant=="before" else row.draws<30,id+" redraw decisions consume same movement workload",row)
  for key in ["selected","hovered","_back_in"]:
   unit.set(key,true);check(Refresh.refresh(unit),id+" immediate "+key);unit.set(key,false)
  for key in ["_muzzle","_recoil","_rock_t","_stun_timer","_hp_flash"]:
   unit.set(key,1.0);check(Refresh.refresh(unit),id+" immediate "+key);unit.set(key,0.0)
  unit.hp=unit.max_hp*0.7;check(Refresh.eligible(unit),id+" settled health bar remains in independent HUD")
  unit.hp=unit.max_hp*0.4;check(Refresh.refresh(unit),id+" low health smoke refresh");unit.hp=unit.max_hp
  unit.buffs=[{"kind":"speed"}];check(Refresh.refresh(unit),id+" animated buff refresh");unit.buffs=[]
  unit.special.progression_v1={"arc_count":1};check(Refresh.refresh(unit),id+" progression overlay refresh")
  unit.special.progression_v1={};unit.special.new_effect=true;check(Refresh.refresh(unit),id+" unknown effect refresh");unit.special.erase("new_effect")
  unit.passive={"id":"ps_spine_scrap"};check(Refresh.refresh(unit),id+" passive refresh");unit.passive={}
  unit.special.iron_left=1.0;check(Refresh.refresh(unit),id+" invulnerability overlay refresh")
  unit.free()
 await finish()
 FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
 get_tree().quit(0 if failed==0 else 1)
