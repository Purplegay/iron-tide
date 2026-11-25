extends "res://tests/ground_control_regression.gd"
const Native = preload("res://scripts/world/native_maps.gd")
func exercise(mode:String) -> void:
 if mode != MatchRules.RA2:return
 for spec in [["yr_isleland",Rect2(105,91,23,3)],["yr_crctbrd",Rect2(115,56,6,3)]]:
  for kind in ["E1","mixed"]:
   BattleRequest.configure_skirmish(mode,{"map_layout":spec[0],"opening":"mcv","fog_of_war":false})
   screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
   screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
   var rect:Rect2=spec[1];var left:Vector2=(rect.position+Vector2(-2,1.5))*Native.CELL
   var right:Vector2=(rect.position+Vector2(rect.size.x+2,1.5))*Native.CELL
   var actors=[]
   for i in 60:
    var side_i:int=i%30;var forward:bool=i<30
    var id:String="E1" if kind=="E1" else ["E1","MTNK","GGI","HTNK","BFRT"][i%5]
    var u=battle.spawn_unit(id,"ally",(left if forward else right)+Vector2((-1 if forward else 1)*65*(side_i/3),(side_i%3-1)*54))
    activate(u);actors.append(u)
    u.order_move((right if forward else left)+Vector2((1 if forward else -1)*65*(side_i/3),(side_i%3-1)*54))
   await get_tree().physics_frame
   var rows=[]
   for tick in 4800:
    await get_tree().physics_frame
    for u in actors:u._physics_process(1.0/60)
    if tick%600==0:
     rows.append(actors.map(func(u):return [u.position,u.has_move_order,u._path_i,u._path_pts,u.velocity,u._local_traffic.yield_target]))
    if actors.all(func(u):return not u.has_move_order):break
   var reached:=0
   for i in actors.size():
    if (actors[i].position.x>right.x-65 if i<30 else actors[i].position.x<left.x+65):reached+=1
   check(reached==60,str(spec[0])+kind+" all cross",reached)
   metrics.append({"map":spec[0],"kind":kind,"reached":reached,"rows":rows,"final":actors.map(func(u):return [u.unit_id,u.position,u.move_target,u._path_pts,u._path_i,u._drive_turning,u._nav_stuck_t])})
   await finish()
