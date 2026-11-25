extends Unit
const Refresh=preload("res://scripts/units/grizzly_visual_refresh.gd")
var completed:=false
var comparisons:=0
var mismatches:Array=[]
var captured:Array=[]
var micro:Array=[]
func draw_body_sprite(art:Dictionary,target:Rect2,source:Rect2,tint:=Color.WHITE,waterline:=INF)->void:
 captured.append([art.get("key"),target,source,tint,waterline])
 super.draw_body_sprite(art,target,source,tint,waterline)
func snapshot()->Array:
 return [captured.duplicate(true),_body_bounds,_art_frame,_pick_body_rect,_turret_draw_rect,_turret_draw_source,_shadow_draw_rect,art_center(),hp_bar_rect()]
func _draw():
 if completed:return
 special={"ai_campaign_role":"assault","progression_v1":{"shot_idle":1.0,"arc_count":0},"reveal":1.0}
 passive={};buffs=[];selected=false;hovered=false;hp=max_hp
 _muzzle=0;_recoil=0;_rock_t=0;_stun_timer=0;_hp_flash=0;velocity=Vector2(70,0)
 var records:Array=[]
 for pass_index in 10:
  hull_angle=0.2;turret_angle=0.4;_anim=0;position=Vector2(1100,1100)
  captured=[];_draw_pose()
  var before=pass_index%2==0
  var draws:=0
  var begin=Time.get_ticks_usec()
  for step in 120:
   position+=Vector2(4,0);_anim+=1.0/15
   if step%20==0:turret_angle+=0.12
   if step%40==0:hull_angle+=0.18
   if before or Refresh.refresh(self):
    captured=[];_draw_pose();draws+=1
   if pass_index==0:records.append(snapshot())
   elif pass_index==1:
    comparisons+=1
    if snapshot()!=records[step]:mismatches.append(step)
  micro.append({"id":unit_id,"variant":"before" if before else "after","us":Time.get_ticks_usec()-begin,"calls":120,"draws":draws})
 completed=true
