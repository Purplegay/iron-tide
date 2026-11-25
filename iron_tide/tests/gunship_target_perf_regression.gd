extends "res://tests/base_recovery_regression.gd"
const Old=preload("res://tests/gunship_before_mounts.gd")
const New=preload("res://scripts/units/ra3_gunship_mounts.gd")
var micro:Array=[]
func compare(actor,label:String) -> void:
 for key in ["front","side","rear"]:check(is_same(Old.choose(actor,key),New.choose(actor,key)),"mount target identity "+label+key)
func _ready() -> void:
 output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 start(MatchRules.EXTENDED)
 battle.gm_unit_lab=true
 var actor=battle.spawn_unit("R3HARBINGER","ally",Vector2(1200,1200));actor.process_mode=Node.PROCESS_MODE_DISABLED;actor.logistics.air_lift=1.0
 var assigned=battle.spawn_unit("MTNK","enemy",Vector2(1500,1200));assigned.process_mode=Node.PROCESS_MODE_DISABLED
 actor.attack_target=assigned;actor.attack_ordered=true
 var all:=New.states(actor)
 for i in 220:
  var target=battle.spawn_unit("MTNK","enemy" if i%3 else "ally",Vector2(100+i%20*120,200+i/20*150));target.process_mode=Node.PROCESS_MODE_DISABLED
 for point in [Vector2(1200,900),Vector2(1200,900),Vector2(1200,600),Vector2(1200,1125)]:
  var target=battle.spawn_unit("MTNK","enemy",point);target.process_mode=Node.PROCESS_MODE_DISABLED
 var building=battle._place_building("NAPOWR","enemy",Vector2(1200,900),true);building.process_mode=Node.PROCESS_MODE_DISABLED;building._buildup_play=-1
 for angle in 32:
  actor.hull_angle=angle*TAU/32
  for range_ in [0.0,75.0,450.0,600.0,750.0]:
   actor.attack_range=range_
   for used in [0,1]:
    all.front.used=used
    all.front.target=building;all.side.target=null;all.rear.target=assigned
    compare(actor,str([angle,range_,used]))
 actor.attack_range=600;actor.hull_angle=0
 for state in [{},{"progression_v1":{"taunt":building}},{"progression_v1":{"succession":1}}]:
  actor.special=state.duplicate(true);New.states(actor);compare(actor,str(state))
 actor.special={};all=New.states(actor)
 for stance in ["none","return","defend","free"]:
  actor.fire_stance=stance
  for ordered in [false,true]:actor.attack_ordered=ordered;compare(actor,str([stance,ordered]))
 actor.fire_stance="defend";actor.attack_ordered=true
 assigned.hp=0;compare(actor,"dead assigned");assigned.hp=assigned.max_hp
 var original_data:Dictionary=actor.data;actor.data=original_data.duplicate(true);actor.data.special_weapon={};compare(actor,"target dependent fallback");actor.data=original_data
 for sample in 18:
  var begun:=Time.get_ticks_usec()
  for i in 200:
   actor.hull_angle=float(i%16)*TAU/16
   for key in ["side","rear"]:
    if sample%2==0:Old.choose(actor,key)
    else:New.choose(actor,key)
  micro.append({"variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":400,"units":battle.units.size(),"buildings":battle.buildings.size()})
 await finish()
 FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
 get_tree().quit(0 if failed==0 else 1)
