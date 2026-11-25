extends Node
var checks:Array=[]
var failed:=0
func check(ok: bool, name: String):
 checks.append({"passed":ok,"name":name})
 if not ok:failed+=1;print("FAIL ",name)
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS
 get_tree().current_scene=null
 run.call_deferred()
func run():
 var out:=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 DirAccess.make_dir_recursive_absolute(BattleSaves.DIRECTORY)
 DirAccess.copy_absolute(OS.get_environment("IRON_SAVE"),BattleSaves.slot_path("slot1"))
 if not BattleSaves.load_into_scene("slot1").ok:get_tree().quit(2);return
 while get_tree().current_scene==null:await get_tree().process_frame
 get_tree().paused=true
 var screen=get_tree().current_scene
 screen.process_mode=Node.PROCESS_MODE_DISABLED
 var hud=screen.hud
 var inspector=hud._production_inspector
 for i in 5:await get_tree().process_frame
 var funds=screen.battle.funds
 var queues:Array=[]
 for building in screen.battle.buildings:queues.append(building.production.duplicate())
 var rows:Array=[]
 for tab in ["infantry","vehicle","air","naval","building","defense"]:
  hud.select_prod_tab(tab)
  for i in 3:await get_tree().process_frame
  for repeat in 6:
   for id in hud._prod_buttons:
    var btn=hud._prod_buttons[id]
    var t:=Time.get_ticks_usec()
    btn.mouse_entered.emit()
    var inspect_us:=Time.get_ticks_usec()-t
    t=Time.get_ticks_usec()
    inspector.description.get_content_height()
    var layout_us:=Time.get_ticks_usec()-t
    t=Time.get_ticks_usec()
    await get_tree().process_frame
    rows.append({"id":id,"tab":tab,"repeat":repeat,"inspect_us":inspect_us,"layout_us":layout_us,"frame_us":Time.get_ticks_usec()-t,"chars":inspector.description.text.length(),"size":str(inspector.size),"text":inspector.description.text,"title":inspector.title.text,"status":inspector.status.text,"icon":inspector.icon.cameo_texture.resource_path if inspector.icon.cameo_texture != null else ""})
    check(inspector.title.text==str(btn.get_meta("inspector_title")),"saved hover title "+str([tab,id,repeat]))
    check(btn.detail_highlight and btn.get_tooltip().is_empty(),"saved highlight and no floating tooltip "+str([tab,id,repeat]))
    check(inspector.description.get_global_rect().size.x>100,"description has resolved width "+str([tab,id,repeat]))
 check(screen.battle.funds==funds,"hover does not spend funds")
 for i in screen.battle.buildings.size():check(screen.battle.buildings[i].production==queues[i],"hover does not change queue "+str(i))
 inspector.clear()
 var controls:Array=[]
 for i in 35:
  var control:=Control.new()
  add_child(control)
  inspector.bind_hint(control,"Hint "+str(i),"Original "+str(i)+"\n"+"long line\n".repeat(50))
  controls.append(control)
  control.mouse_entered.emit()
  await get_tree().process_frame
  check(inspector.title.text=="Hint "+str(i),"bounded cache new card "+str(i))
  if inspector.get("_descriptions")!=null:check(inspector._descriptions.size()<=24,"cache bounded "+str(i))
 var last=controls.back()
 var last_label=inspector.description
 var scroll=last_label.get_v_scroll_bar()
 scroll.value=30
 var old_scroll=scroll.value
 inspector.refresh()
 check(scroll.value==old_scroll,"stationary refresh preserves scroll")
 controls[0].mouse_entered.emit()
 last.set_meta("inspector_hint","Updated live requirements")
 last.mouse_entered.emit()
 check(inspector.description.text=="Updated live requirements","cached hidden card refreshes live content")
 check(inspector.description.get_v_scroll_bar().value==0,"switch resets scroll")
 last.set_meta("inspector_hint","Updated while hovered")
 inspector.refresh()
 check(inspector.description.text=="Updated while hovered","stationary card refreshes live content")
 last.free()
 inspector.refresh()
 check(inspector.title.text=="生产情报","freed card clears inspector")
 for control in controls:
  if is_instance_valid(control):control.free()
 inspector.clear()
 await get_tree().process_frame
 if inspector.get("_descriptions")!=null:
  check(inspector._descriptions.is_empty(),"clear releases cache")
  check(inspector._description_host.get_child_count()==2,"clear retains only header and idle description")
 FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"rows":rows,"meta_cosmetics":MetaProgress.unit_cosmetics,"user_dir":OS.get_user_data_dir(),"units":screen.battle.units.size(),"buildings":screen.battle.buildings.size()}))
 get_tree().quit(0 if failed==0 else 1)
