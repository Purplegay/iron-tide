extends "res://tests/base_recovery_regression.gd"
const Old=preload("res://tests/gunship_before_impact.gd")
const New=preload("res://scripts/units/ra3_gunship_impact.gd")
var micro:Array=[]
func original_extent(pose:Transform3D,bounds:AABB) -> float:
 var result:=0.0
 for i in 8:
  var v:=pose*bounds.get_endpoint(i)
  result=maxf(result,maxf(absf(v.x),absf(v.z*0.5-v.y*sqrt(0.75))))
 return result
func snapshot(effect) -> Array:
 var rows:Array=[]
 for p in effect.particles:
  rows.append([p.node.visible,p.node.transform])
 return rows
func _ready() -> void:
 output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 start(MatchRules.EXTENDED)
 seed(714)
 for i in 2000:
  var pose:=Transform3D(Basis.from_euler(Vector3(randf()*TAU,randf()*TAU,randf()*TAU)).scaled(Vector3(randf()*10,randf()*10,randf()*10)),Vector3(randf()*100,randf()*100,randf()*100))
  var bounds:=AABB(Vector3(-30,-15,-20),Vector3(randf()*100,randf()*100,randf()*100))
  check(is_equal_approx(original_extent(pose,bounds),New.projected_extent(pose,bounds)),"eight-corner orthographic extent "+str(i))
 for heroic in [false,true]:
  var before=Old.new();var after=New.new()
  for effect in [before,after]:
   effect.world=battle;effect.position=Vector2(1400,1400);effect.effect_id="FX_AlliedGunshipProtonHitVet" if heroic else "FX_AlliedGunshipProtonHit"
   battle.add_child(effect);effect.set_process(false);seed(714);effect._build()
  for age in [0.0,0.05,0.2,0.8,1.5,3.0]:
   before.age=age;after.age=age;before._sample();after._sample()
   check(snapshot(before)==snapshot(after) and is_equal_approx(before.draw_size,after.draw_size) and before.viewport.size==after.viewport.size,"proton effect particle poses and capture bounds "+str([heroic,age]))
  for sample in 18:
   var effect=before if sample%2==0 else after
   var begun:=Time.get_ticks_usec()
   for i in 100:
    effect.age=0.05+float(i%20)*0.02;effect._sample()
   micro.append({"id":"heroic" if heroic else "normal","variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":100,"particles":effect.particles.size()})
  before.free();after.free()
 await finish()
 FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
 get_tree().quit(0 if failed==0 else 1)
