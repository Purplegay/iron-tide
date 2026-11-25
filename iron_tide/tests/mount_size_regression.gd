extends "res://tests/progression_bookmarks_regression.gd"
const Styles=preload("res://scripts/units/unit_cosmetics.gd")
func drag(editor,axis:int,shift:bool) -> void:
	var center:Vector2=editor._screen(editor.mount.global_position)
	var direction:Vector2=Vector2(0,-1) if axis==3 else editor._axis_step(axis).normalized()
	var point:Vector2=center if axis==3 else center+direction*60
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=point;press.shift_pressed=shift
	editor._stage_input(press)
	var motion:=InputEventMouseMotion.new();motion.position=point+direction*30
	editor._stage_input(motion)
	press.pressed=false;editor._stage_input(press)
func run() -> void:
	surface=SubViewport.new();surface.size=Vector2i(1440,1000);add_child(surface)
	MetaProgress.reset_save();MetaProgress.currency.credits=2000
	MetaProgress.owned_cosmetics={"demon":true,"angel":true,"crystal":true,"slag_chains":true}
	MetaProgress.attachment_positions={"R3APOC":{"wing":[1,2,3],"top":{"offset":[0,0,0],"pitch":25}}}
	check(MetaProgress.attachment_scale("R3APOC","wing")==Vector3.ONE,"legacy array size defaults to one")
	check(MetaProgress.attachment_scale("R3APOC","top")==Vector3.ONE,"legacy pose size defaults to one")
	MetaProgress.attachment_positions.clear()
	MetaProgress.unit_cosmetics={"R3APOC":{"wing":"demon","top":"crystal","tail":"slag_chains"}}
	var shop=load("res://scenes/paint.tscn").instantiate();shop.initial_unit="R3APOC";surface.add_child(shop);await settle()
	var button=shop.slots.find_child("Adjust_wing",true,false)
	button.pressed.emit();await settle()
	var editor=shop.get_node("MountEditor")
	check(editor.alignment_views.size()==3,"three orthographic views preserved")
	var origin:Vector3=editor.mount.position
	var hull_scale:Vector3=shop.preview.actor._ra3_model.hull.scale
	editor.size_spin.value=150;editor.stretch_controls[0].value=120;editor.stretch_controls[1].value=80;editor.stretch_controls[2].value=180
	check(editor.mount.scale.is_equal_approx(Vector3(1.8,1.2,2.7)),"preview combines uniform scale and local axis stretch")
	check(editor.mount.position.is_equal_approx(origin) and shop.preview.actor._ra3_model.hull.scale==hull_scale,"size leaves anchor and whole unit unchanged")
	check(MetaProgress.attachment_scale("R3APOC","wing")==Vector3.ONE and MetaProgress.balance("credits")==2000,"draft neither saves nor charges")
	editor.closed.emit(false);await settle()
	check(shop.preview.actor._ra3_model.hull.get_node("CosmeticMount/wing").scale.is_equal_approx(Vector3.ONE),"cancel rebuilds original size")
	button.pressed.emit();await settle();editor=shop.get_node("MountEditor")
	drag(editor,3,true)
	check(editor.size_percent==118 and editor.edit_mode==0 and editor.draft==Vector3i.ZERO,"shift center scales without mode switch or translation")
	var axis:=0
	for i in 3:
		if editor._axis_step(i).length()>editor._axis_step(axis).length():axis=i
	drag(editor,axis,true)
	check(editor.stretch[axis]==118 and editor.size_percent==118,"shift axis stretches only chosen component")
	for i in 3:
		if i!=axis:check(editor.stretch[i]==100,"other stretch axis unchanged "+str(i))
	check(editor.drag_button==0 and editor.edit_mode==0,"release restores normal operation")
	var moved_from:Vector3i=editor.draft
	drag(editor,axis,false)
	check(editor.draft!=moved_from and editor.size_percent==118,"ordinary drag still moves after shift release")
	editor.set_draft(Vector3i.ZERO)
	editor.edit_mode=1;drag(editor,3,false)
	check(editor.size_percent==136,"scale mode works without shift")
	editor.edit_mode=2;drag(editor,axis,false)
	check(editor.stretch[axis]==136,"stretch mode works without shift")
	editor.edit_mode=0
	var before_scale:int=editor.size_percent
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
	editor._stage_input(wheel)
	check(editor.zoom>1 and editor.size_percent==before_scale,"wheel only changes camera zoom")
	editor.size_spin.value=150;editor.stretch_controls[0].value=120;editor.stretch_controls[1].value=80;editor.stretch_controls[2].value=180
	editor.tilt_spin.value=30
	editor.part="Turret";editor.set_draft(Vector3i(2,3,4))
	editor.mount._sync_pose()
	check(editor.mount.dimensions.is_equal_approx(Vector3(1.8,1.2,2.7)),"skeletal refresh retains dimensions")
	check(editor.mount.transform.basis.get_scale().is_equal_approx(Vector3(1.8,1.2,2.7)),"pitch rotation retains local size")
	check(editor.alignment_views[0].extent>editor.span,"orthographic framing expands for large accessories")
	MetaProgress.currency.credits=99;editor._save()
	check(shop.has_node("MountEditor") and MetaProgress.attachment_scale("R3APOC","wing")==Vector3.ONE and MetaProgress.balance("credits")==99,"insufficient funds preserves saved size")
	MetaProgress.currency.credits=2000
	var tmp:=MetaProgress.SAVE_PATH+".tmp"
	check(DirAccess.make_dir_absolute(tmp)==OK,"block save transaction")
	editor._save()
	check(MetaProgress.balance("credits")==2000 and MetaProgress.attachment_scale("R3APOC","wing")==Vector3.ONE,"failed write rolls back size and currency")
	DirAccess.remove_absolute(tmp);editor._save();await settle()
	check(not shop.has_node("MountEditor") and MetaProgress.balance("credits")==1900,"one save fee includes size stretch position pitch")
	MetaProgress.load_save()
	check(MetaProgress.attachment_scale("R3APOC","wing").is_equal_approx(Vector3(1.8,1.2,2.7)),"size survives profile reload")
	check(MetaProgress.attachment_scale("R3APOC","top")==Vector3.ONE and MetaProgress.attachment_scale("R3MIRAGE","wing")==Vector3.ONE,"other unit and slot isolated")
	button.pressed.emit();await settle();editor=shop.get_node("MountEditor")
	check(editor.size_spin.value==150 and editor.stretch_controls[2].value==180,"reopened editor restores controls")
	editor._save();await settle()
	check(MetaProgress.balance("credits")==1900,"unchanged save is free")
	check(not MetaProgress.save_attachment("R3APOC","wing",Vector3i.ZERO,"",0,0),"zero scale rejected")
	check(not MetaProgress.save_attachment("R3APOC","wing",Vector3i.ZERO,"",0,100,Vector3i(-1,100,100)),"negative stretch rejected")
	check(not MetaProgress.save_attachment("R3APOC","wing",Vector3i.ZERO,"",0,201),"out of bounds scale rejected")
	MetaProgress.set_attachment_position("R3APOC","wing",Vector3i(1,2,3))
	check(MetaProgress.attachment_scale("R3APOC","wing").is_equal_approx(Vector3(1.8,1.2,2.7)),"position-only setter preserves size")
	button.pressed.emit();await settle();editor=shop.get_node("MountEditor")
	for node in editor.find_children("*","Button",true,false):
		if node.text=="复位挂点":node.pressed.emit();break
	check(editor.size_percent==100 and editor.stretch==Vector3i(100,100,100) and editor.tilt==0 and editor.draft==Vector3i.ZERO,"reset restores all dimensions and pose")
	editor._save();await settle()
	check(not MetaProgress.attachment_positions.has("R3APOC"),"default transform removes saved override")
	var actor=Unit.new();actor.setup(GameData.get_unit("R3APOC"),"ally",Vector2.ZERO);surface.add_child(actor)
	MetaProgress.save_attachment("R3APOC","top",Vector3i.ZERO,"",0,125,Vector3i(100,80,120))
	Styles.install(actor._ra3_model,{"top":"crystal"})
	check(actor._ra3_model.hull.get_node("CosmeticMount/top").scale.is_equal_approx(Vector3(1.25,1,1.5)),"battle model install uses saved scale")
	var chain=preload("res://scripts/units/slag_drag_chain.gd").new()
	chain.set_dimensions(Vector3(2,1.5,1));chain.reset(Vector3(0,0.2,0),Vector3.LEFT)
	check(is_equal_approx(chain.points[0].distance_to(chain.points[1]),chain.LENGTH*2),"chain collision solver respects scaled length")
	check(is_equal_approx(chain.shoe_clearance,chain.SHOE_CLEARANCE*1.5),"chain floor clearance follows scaled height")
	actor.free();shop.free();await settle()
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(failed)
