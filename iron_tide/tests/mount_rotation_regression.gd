extends "res://tests/progression_bookmarks_regression.gd"
const Editor=preload("res://scripts/ui/mount_position_editor.gd")
const Styles=preload("res://scripts/units/unit_cosmetics.gd")

func key(editor,code:int,shift:=false,ctrl:=false) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true;event.shift_pressed=shift;event.ctrl_pressed=ctrl
	editor._input(event)

func ring_drag(editor,axis:int,snap:=false) -> void:
	editor._set_mode(Editor.ROTATE);editor.selected_axis=axis
	editor._set_angles(Vector3i.ZERO)
	var points:PackedVector2Array=editor._ring_points(axis)
	var sample:=0
	for j in range(5,60):
		if editor._ring_at(points[j])==axis and editor._ring_at(points[j+5])==axis:sample=j;break
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=points[sample]
	editor._stage_input(event)
	check(editor.drag_button==MOUSE_BUTTON_LEFT and editor.drag_axis==axis,"ring hit axis "+str(axis))
	var motion:=InputEventMouseMotion.new();motion.position=points[sample+5];motion.ctrl_pressed=snap
	editor._stage_input(motion)
	event.pressed=false;editor._stage_input(event)
	check(editor._angles()!=Vector3i.ZERO,"drag rotates axis "+str(axis))
	check(abs(editor._angles()[axis]-(30 if snap else 25))<=1 if is_finite(editor.ring_last) else abs(editor._angles()[axis])>1,"drag angle or edge-on tangent "+str(axis))

func run() -> void:
	surface=SubViewport.new();surface.size=Vector2i(1440,1100);surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(surface)
	MetaProgress.reset_save();MetaProgress.currency.credits=2000
	MetaProgress.owned_cosmetics={"demon":true}
	MetaProgress.attachment_positions={"R3APOC":{"wing":{"offset":[3,4,5],"pitch":30}}}
	check(MetaProgress.attachment_rotation("R3APOC","wing")==Vector3i(0,0,30),"legacy pitch retains exact axis")
	MetaProgress.attachment_positions.R3APOC.wing.roll="bad";MetaProgress.attachment_positions.R3APOC.wing.yaw=INF
	check(MetaProgress.attachment_rotation("R3APOC","wing")==Vector3i(0,0,30),"malformed new angles default safely")
	MetaProgress.attachment_positions.clear()
	MetaProgress.unit_cosmetics={"R3APOC":{"wing":"demon"}}
	var shop=load("res://scenes/paint.tscn").instantiate();shop.initial_unit="R3APOC";surface.add_child(shop);await settle()
	var button=shop.slots.find_child("Adjust_wing",true,false);button.pressed.emit();await settle()
	var editor=shop.get_node("MountEditor")
	key(editor,KEY_E);check(editor.edit_mode==Editor.ROTATE and editor.mode_picker.selected==3,"E enables rotation rings")
	for axis in 3:ring_drag(editor,axis,axis==1)
	editor._set_angles(Vector3i.ZERO)
	key(editor,KEY_X);key(editor,KEY_RIGHT);key(editor,KEY_RIGHT,true)
	check(editor._angles()==Vector3i(6,0,0),"keyboard axis plus 5 and 1 degree steps")
	editor._set_angles(Vector3i.ZERO);key(editor,KEY_Y);key(editor,KEY_LEFT,false,true)
	check(editor._angles()==Vector3i(0,-15,0),"Ctrl keyboard 15 degree snap")
	for spec in [[KEY_W,0],[KEY_R,1],[KEY_T,2],[KEY_E,3]]:
		key(editor,spec[0]);check(editor.edit_mode==spec[1],"mode shortcut "+str(spec[0]))
	editor.rotation_controls[0].get_line_edit().grab_focus()
	key(editor,KEY_W);check(editor.edit_mode==3,"typing numeric field does not switch tools")
	editor.rotation_controls[0].get_line_edit().release_focus()
	editor.rotation_controls[0].value=20;editor.rotation_controls[1].value=35;editor.tilt_spin.value=-25
	editor.size_spin.value=120;editor.stretch_controls[1].value=140
	var offset:Vector3=editor.mount.position
	var expected:=Basis.from_euler(Vector3(20,35,-25)*PI/180.0)
	check(editor.mount.rotation_basis().is_equal_approx(expected),"three numeric angles reach preview transform")
	var rotated:Vector3i=editor._rotated_angles(editor._angles(),0,15)
	var actual:=Basis.from_euler(Vector3(rotated)*PI/180.0)
	var wanted:=Basis(Vector3.RIGHT,PI/12)*expected
	check(actual.x.distance_to(wanted.x)<.025 and actual.y.distance_to(wanted.y)<.025,"ring remains true displayed X axis after compound rotation")
	check(MetaProgress.attachment_rotation("R3APOC","wing")==Vector3i.ZERO and MetaProgress.balance("credits")==2000,"draft is uncharged and unsaved")
	editor.closed.emit(false);await settle()
	check(shop.preview.actor._ra3_model.hull.get_node("CosmeticMount/wing").angles==Vector3i.ZERO,"cancel restores original rotation")
	button.pressed.emit();await settle();editor=shop.get_node("MountEditor")
	editor._set_angles(Vector3i(20,35,-25));editor.size_spin.value=120;editor.stretch_controls[1].value=140
	editor.part="Turret";editor.set_draft(Vector3i(2,3,4));editor._save();await settle()
	MetaProgress.load_save()
	check(MetaProgress.attachment_rotation("R3APOC","wing")==Vector3i(20,35,-25) and MetaProgress.balance("credits")==1900,"one fee and disk round trip")
	check(MetaProgress.attachment_scale("R3APOC","wing").is_equal_approx(Vector3(1.2,1.68,1.2)),"rotation preserves size and stretch")
	MetaProgress.set_attachment_position("R3APOC","wing",Vector3i(4,3,2))
	check(MetaProgress.attachment_rotation("R3APOC","wing")==Vector3i(20,35,-25),"position setter retains all rotation")
	button.pressed.emit();await settle();editor=shop.get_node("MountEditor")
	check(editor._angles()==Vector3i(20,35,-25) and editor.rotation_controls[1].value==35,"reopen restores angles and controls")
	check(editor.mount.angles==Vector3i(20,35,-25) and editor.mount.rotation_basis().is_equal_approx(expected),"model install restores all saved angles")
	editor.mount._sync_pose()
	check(editor.mount.rotation_basis().is_equal_approx(expected),"bone pose refresh preserves authored rotation")
	var funds:float=MetaProgress.balance("credits");editor._save();await settle()
	check(MetaProgress.balance("credits")==funds,"unchanged save free")
	check(not MetaProgress.save_attachment("R3APOC","wing",Vector3i.ZERO,"",0,100,Vector3i(100,100,100),181,0),"reject invalid roll")
	button.pressed.emit();await settle();editor=shop.get_node("MountEditor");editor._set_mode(Editor.ROTATE)
	await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("rotation-editor.png"))
	for node in editor.find_children("*","Button",true,false):
		if node.text=="复位挂点":node.pressed.emit();break
	check(editor._angles()==Vector3i.ZERO and editor.size_percent==100,"reset includes all rotation axes")
	editor._save();await settle();check(not MetaProgress.attachment_positions.has("R3APOC"),"reset removes complete override")
	shop.free();await settle()
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(failed)
