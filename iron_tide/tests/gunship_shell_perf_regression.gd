extends "res://tests/base_recovery_regression.gd"
const Before=preload("res://tests/gunship_before_ra3_gunship_shell.gd")
const After=preload("res://scripts/units/ra3_gunship_shell.gd")
var micro:Array=[]
func projectile(target,legacy:=false):
 var shot:=Projectile.new();shot.target=target;shot.target_point=Vector2(2200,1800)
 shot.splinters={"shell_start":Vector3(1200,1200,285),"shell_end":shot.target_point,"shell_tangent":Vector3(1,0,-0.2),"shell_scatter":Vector2(5,-8),"shell_time":0.0,"shell_frame":0,"shell_distance":0.0,"start":Vector2(1200,1200),"age":0.0}
 if legacy:
  for key in ["shell_start","shell_end","shell_tangent","shell_scatter","shell_time","shell_frame","shell_distance"]:shot.splinters.erase(key)
 return shot
func _ready() -> void:
 output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 start(MatchRules.EXTENDED)
 var target=battle.spawn_unit("MTNK","enemy",Vector2(2200,1800));target.process_mode=Node.PROCESS_MODE_DISABLED
 for legacy in [false,true]:
  for motion in ["still","moving","lost"]:
   for delta in [1.0/60.0,1.0/30.0,1.0/15.0,0.2]:
    var a=projectile(target,legacy);var b=projectile(target,legacy)
    for frame in 180:
     target.position=Vector2(2200,1800)+Vector2(frame*2,frame*-0.3) if motion=="moving" else Vector2(2200,1800)
     if motion=="lost" and frame==10:a.target=null;b.target=null
     a.splinters.age+=delta;b.splinters.age+=delta
     var x:bool=Before.advance(a,delta);var y:bool=After.advance(b,delta)
     check(x==y and a.splinters==b.splinters and a.position.is_equal_approx(b.position) and a.target_point==b.target_point,"shell trajectory/arrival "+str([legacy,motion,delta,frame]))
     if frame==9:
      # A loaded payload must work without the disposable cache.
      b.remove_meta("gunship_curve")
     if x:break
    a.free();b.free()
 for moving in [false,true]:
  var a=projectile(target);var b=projectile(target)
  for sample in 18:
   var shot=a if sample%2==0 else b
   var begun:=Time.get_ticks_usec()
   for pass_ in 12:
    shot.splinters.shell_time=0.0;shot.splinters.shell_frame=0;shot.splinters.shell_distance=0.0;shot.splinters.shell_end=Vector2(2200,1800)
    if shot.has_meta("gunship_curve"):shot.remove_meta("gunship_curve")
    for frame in 60:
     target.position=Vector2(2200,1800)+Vector2(frame*2,frame*-0.3) if moving else Vector2(2200,1800)
     if sample%2==0:Before.advance(shot,1.0/60.0)
     else:After.advance(shot,1.0/60.0)
   micro.append({"id":"moving" if moving else "still","variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":720})
  a.free();b.free()
 await finish()
 FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
 get_tree().quit(0 if failed==0 else 1)
