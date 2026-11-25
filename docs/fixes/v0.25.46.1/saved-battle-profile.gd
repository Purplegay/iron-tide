extends Node
var report:Dictionary={}
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS
 var dest=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if not OS.get_user_data_dir().contains("CodexIronTideValidation") or dest.is_empty():get_tree().quit(2);return
 DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
 DirAccess.copy_absolute(OS.get_environment("IRON_PROFILE_SAVE"),ProjectSettings.globalize_path(BattleSaves.slot_path("slot1")))
 get_tree().current_scene=null
 seed(12345)
 var loaded=BattleSaves.load_into_scene("slot1")
 print("LOAD ",loaded)
 if not loaded.ok:get_tree().quit(3);return
 await get_tree().process_frame
 await get_tree().process_frame
 var screen=get_tree().current_scene
 var world=screen.battle
 var mode=OS.get_environment("IRON_PROFILE_CASE")
 var heroes:Array=[]
 var skins:=0
 var outfits:Dictionary={}
 var counts:Dictionary={}
 for u in world.units:
  counts[u.unit_id]=int(counts.get(u.unit_id,0))+1
  if u.unit_id=="HTNK" and u.side=="ally":
   heroes.append(u)
   var skin:String=str(u.cosmetic_outfit().get("skin","stock"))
   outfits[skin]=int(outfits.get(skin,0))+1
   if u.tank_finish!=null:skins+=1
   if mode in ["ember_off","ember_fx_off"]:u.tank_finish=null
   if mode=="ember_off" and u.material is ShaderMaterial:u.material.set_shader_parameter("unit_skin",0)
 report={"case":mode,"units":world.units.size(),"buildings":world.buildings.size(),"rhinos":heroes.size(),"skins":skins,"outfits":outfits,"counts":counts,"phases":[]}
 print("SCENE ",report)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 if mode=="no_ai" and world.skirmish_ai!=null:world.skirmish_ai.set_process(false)
 world.paused=false;get_tree().paused=false
 for i in 45:await get_tree().process_frame
 for phase in ["saved_view","rhinos_selected","rhinos_moving"]:
  if phase=="rhinos_selected":
   world.clear_selection()
   for u in heroes:
    if is_instance_valid(u) and not u._dead:world.select_unit(u,true)
   world.center_on_selection()
  if phase=="rhinos_moving" and not heroes.is_empty():world._command_move(heroes[0].position+Vector2(400,200))
  var samples:Array=[]
  for i in 180:
   var begin=Time.get_ticks_usec()
   await get_tree().process_frame
   samples.append({"ms":(Time.get_ticks_usec()-begin)/1000.0,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
  report.phases.append({"phase":phase,"samples":samples})
  print("PHASE ",phase)
 FileAccess.open(dest.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify(report))
 get_tree().quit()
