extends "res://tests/base_recovery_regression.gd"
const Old=preload("res://tests/gunship_before_ra3_expansion_model.gd")
const New=preload("res://scripts/units/ra3_expansion_model.gd")
var micro:Array=[]
func pose(model) -> Array:
 var result:Array=[]
 for i in model.rig.get_bone_count():result.append(model.rig.get_bone_global_pose(i))
 for part in model.parts.values():result.append(part.visible)
 for lamp in model.fire_lights:result.append([lamp.visible,lamp.light_energy,lamp.position])
 for name in ["FXGUN_FRONT","FXGUN_FR","FXGUN_BR","FXCON_R","FXCON_L","MISSING"]:result.append(model.bone_world(name))
 result.append(model.hull.get_node("CosmeticMount/wing").transform)
 return result
func _ready() -> void:
 output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 start(MatchRules.EXTENDED)
 var actor=battle.spawn_unit("R3HARBINGER","ally",Vector2(1100,1100));actor.process_mode=Node.PROCESS_MODE_DISABLED
 actor.logistics.air_lift=1.0
 preload("res://scripts/units/ra3_gunship_mounts.gd").states(actor)
 var target=battle.spawn_unit("MTNK","enemy",Vector2(1400,1600));target.process_mode=Node.PROCESS_MODE_DISABLED
 var before=Old.new();before.actor=actor;actor.add_child(before);before._build();before.set_process(false)
 var after=New.new();after.actor=actor;actor.add_child(after);after._build();after.set_process(false)
 MetaProgress.attachment_positions["R3HARBINGER"]={"wing":{"offset":[11,-13,0],"part":"","pitch":42,"size":64,"stretch":[100,100,122]}}
 for model in [before,after]:preload("res://scripts/units/unit_cosmetics.gd").install(model,{"wing":"angel"})
 for live in [true,false]:
  actor.attack_target=target if live else null
  for gun in [true,false]:
   actor.special.ra3_gun_mode=gun
   for step in 80:
    actor.hull_angle=step*0.07;actor.velocity=Vector2.from_angle(actor.hull_angle)*156
    for key in ["front","side","rear"]:
     actor.special["ra3_aim_"+key]=step*0.03
     actor.special["ra3_aim_"+key+"_pitch"]=step*0.006
     actor.special.ra3_mounts[key].flash=fposmod(step*0.03,0.5)
    before._sample(1.0/30);after._sample(1.0/30)
    check(pose(before)==pose(after),"winged gunship bones, lights, muzzles and contrail sockets "+str([live,gun,step]))
 actor.attack_target=target
 for sample in 18:
  var model=before if sample%2==0 else after
  var begun:=Time.get_ticks_usec()
  for i in 1000:
   actor.hull_angle=i*0.01
   model._sample(1.0/30)
   model.bone_world("FXCON_R");model.bone_world("FXCON_L")
  micro.append({"variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":1000})
 await finish()
 FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
 get_tree().quit(0 if failed==0 else 1)
