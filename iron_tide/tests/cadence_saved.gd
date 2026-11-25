extends Node
const ProbeAI=preload("res://tests/cadence_ai_actor.gd")
const OldTracks=preload("res://tests/cadence_tracks_reference.gd")
var checks:Array=[]
var failed:=0
var cadence:Array=[]
func check(ok:bool,label:String):
 checks.append({"passed":ok,"name":label})
 if not ok:failed+=1;print("FAIL ",label)
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS;get_tree().current_scene=null;run.call_deferred()
func run():
 var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if out.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
 DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"),BattleSaves.slot_path("slot1"))
 if not BattleSaves.load_into_scene("slot1").ok:get_tree().quit(2);return
 while get_tree().current_scene==null:await get_tree().process_frame
 var screen=get_tree().current_scene
 var world:Battle=screen.battle
 screen.process_mode=Node.PROCESS_MODE_DISABLED
 get_tree().paused=false;world.paused=false
 var probe=ProbeAI.new();probe.battle=world;probe.enemy_base="swarm";add_child(probe);probe.set_process(false)
 check(world.units.size()>300,"actual six-house checkpoint loaded")
 for speed in [1.0,2.0,3.0]:
  Engine.time_scale=speed;GM.fast_forward=speed
  for frame_seconds in [1.0/60,0.16,0.23]:
   probe._decision_elapsed=0;probe._decision_wall=0;probe.decision_calls=0;probe.advanced=0
   var duration:=0.0
   for i in 120:
    probe._process(frame_seconds*speed);duration+=frame_seconds
   check(probe.decision_calls<=ceili(duration/probe.LARGE_DECISION_INTERVAL),"large army decision cap at speed/frame "+str([speed,frame_seconds]))
   check(is_equal_approx(probe.advanced+probe._decision_elapsed,duration*speed),"all simulation time conserved, including pending partial interval "+str([speed,frame_seconds]))
   check(probe._decision_wall<probe.LARGE_DECISION_INTERVAL,"poll cannot remain overdue")
   cadence.append({"speed":speed,"frame":frame_seconds,"wall":duration,"decisions":probe.decision_calls,"advanced":probe.advanced,"pending":probe._decision_elapsed})
 var units=world.units
 world.units=[];probe._decision_elapsed=0;probe._decision_wall=0;probe.decision_calls=0;probe.advanced=0
 Engine.time_scale=1;GM.fast_forward=1
 for i in 60:probe._process(1.0/60)
 check(probe.decision_calls>=12 and probe.decision_calls<=15,"small battles keep fast decision cadence")
 world.units=units
 var advanced:float=probe.advanced;var pending:float=probe._decision_elapsed
 world.paused=true;probe._process(5)
 check(probe.advanced==advanced and probe._decision_elapsed==pending,"pause never banks AI catch-up time")
 world.paused=false
 var probes:Array=[]
 for side in BattleRequest.house_teams:
  if side=="ally":continue
  var actor=ProbeAI.new();actor.battle=world;actor.house_id=side;actor.enemy_base="swarm";add_child(actor);actor.set_process(false);probes.append(actor)
 var peak:=0
 for frame in 600:
  var due:=0
  for actor in probes:
   var count:int=actor.decision_calls;actor._process(1.0/60.0)
   due+=actor.decision_calls-count
  peak=maxi(peak,due)
 check(peak<=2,"house phases prevent five simultaneous strategy polls")
 for actor in probes:
  check(actor.decision_calls>=19 and actor.decision_calls<=21,"each house receives two polls per wall second")
  check(is_equal_approx(actor.advanced+actor._decision_elapsed,10.0),"staggering conserves actual simulation time")
  actor.queue_free()
 # The fog-frequency candidate was rejected after full-match profiling.
 # Preserve ordinary scouting and immediate reveal expiry with slower AI/UI.
 var fog=world.fog
 fog.firing_positions.clear();world.frame_pacing.tier=3;fog._elapsed=0
 var before:int=fog.rebuild_count;var clock:float=fog.sight_clock
 for i in 60:fog._process(1.0/60)
 var rebuilds:int=fog.rebuild_count-before
 check(rebuilds==3,"ordinary fog retains the original heavy-tier cadence")
 check(is_equal_approx(fog.sight_clock-clock,1.0),"held vision ages continuously between rebuilds")
 # Expired firing reveals must bypass the periodic gate in that same call.
 fog.firing_positions[-777]={"side":"ally","position":Vector2(300,300),"remaining":0.001}
 fog._elapsed=0;before=fog.rebuild_count
 fog._process(0.002)
 check(fog.rebuild_count==before+1 and not fog.firing_positions.has(-777),"shot reveal expiry is immediate inside the slow interval")
 var tracks=VehicleTracks.new();tracks.world=world;add_child(tracks);tracks.set_process(false)
 for speed in [1.0,3.0]:
  Engine.time_scale=speed;GM.fast_forward=speed;tracks._redraw_clock=0
  var uploads:int=tracks.batch_updates
  for i in 60:tracks._process(speed/60.0)
  check(tracks.batch_updates-uploads==5,"cosmetic uploads remain 5 Hz at speed "+str(speed))
 Engine.time_scale=1;GM.fast_forward=1
 var prior_fog=world.fog;world.fog=null
 var old_tracks=OldTracks.new();old_tracks.world=world;add_child(old_tracks);old_tracks.set_process(false)
 var micro:Array=[];var expected:Array=[]
 for pass_index in 12:
  var layer=old_tracks if pass_index%2==0 else tracks
  layer.clock=0;layer._redraw_clock=0;layer.marks.clear()
  var center:Vector2=layer.get_global_transform_with_canvas().affine_inverse()*layer.get_viewport_rect().get_center()
  for i in VehicleTracks.LIMIT:layer.add_mark(center+Vector2(i%20,i%30),0,i%2==0)
  var updates:int=layer.batch_updates;var elapsed:=0
  for frame in 60:
   layer.add_mark(center+Vector2(frame%20,frame%30),frame*0.02,frame%2==0)
   var begin:=Time.get_ticks_usec()
   layer._process(1.0/60)
   elapsed+=Time.get_ticks_usec()-begin
  micro.append({"variant":"before" if pass_index%2==0 else "after","us":elapsed,"uploads":layer.batch_updates-updates})
  var actual:Array=[]
  for mark in layer.marks:actual.append([mark.position,mark.angle,mark.born])
  if pass_index%2==0:expected=actual
  else:check(actual==expected,"all 1600 sampled track positions/angles/birth times retained pass "+str(pass_index))
  check(layer._batches[0].multimesh.visible_instance_count+layer._batches[1].multimesh.visible_instance_count==VehicleTracks.LIMIT,"benchmark exercises 1600 visible instances")
 world.fog=prior_fog
 FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"cadence":cadence,"micro":micro}))
 get_tree().quit(0 if failed==0 else 1)
