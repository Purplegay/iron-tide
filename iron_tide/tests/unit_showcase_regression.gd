extends Node

var failures:=0
var checks:=0
var folder: String

func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL ",message)

func frames(n:int) -> void:
	for i in n:await get_tree().process_frame
	await RenderingServer.frame_post_draw

func pick(picker:OptionButton,id:String) -> void:
	for i in picker.item_count:
		if str(picker.get_item_metadata(i))==id:
			picker.select(i)
			picker.item_selected.emit(i)
			return
	check(false,"missing option "+id)

func _ready() -> void:
	folder=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if folder.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	await check_cosmetic_shop()
	var original=MetaProgress.unit_cosmetics.duplicate(true)
	var original_mounts:=MetaProgress.attachment_positions.duplicate(true)
	var original_credits:=MetaProgress.balance("credits")
	MetaProgress.currency.credits=1200
	MetaProgress.attachment_positions={"R3MIRAGE":{"top":[1,2,3]}}
	check(MetaProgress.attachment_position("R3MIRAGE","top")==Vector3i(1,2,3) and MetaProgress.attachment_pose("R3MIRAGE","top")=={"part":"","pitch":0},"legacy mounts default to hull with zero pitch")
	var original_owned:=MetaProgress.owned_cosmetics.duplicate()
	for value in Effects.Looks.CHOICES.values()+["winter","night_shift","ice","wine","star","crystal","angel","demon","amber_tail","chevron_track","cobalt_porcelain","ember_steel"]:
		MetaProgress.owned_cosmetics[value]=true
	var team:=MetaProgress.house_color
	var main=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var colors=main.find_child("HouseColorPicker",true,false)
	check(colors!=null,"main menu exposes team colour")
	colors.select(1);colors.item_selected.emit(1)
	check(HouseColor.player_id=="red" and MetaProgress.house_color=="red","menu changes saved team colour")
	main.free()
	var lobby=load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	check(lobby.find_child("HouseColorPicker",true,false).selected==1,"opening menu remembers saved team colour")
	lobby.free()
	var shop=load("res://scenes/paint.tscn").instantiate()
	add_child(shop)
	check_exclusive_filter(shop)
	for i in shop.units.item_count:
		var id:String=shop.units.get_item_metadata(i)
		pick(shop.units,id)
		await frames(3)
		if MetaProgress.Cosmetics.Styles.EXCLUSIVE_MOUNTS.has(id):
			await check_signature(shop,id)
		if id=="R3REAPER":
			shop.preview.try_outfit("track","chevron_track")
			check(shop.slots.find_child("track",true,false)==null and shop.tread_strip==null and not shop.preview.track_sample.visible,"walker has no tire slot or preview strip")
		if id=="R3HARBINGER":await inspect_aircraft(shop.preview)
		check(shop.slots.find_child("paint",true,false)!=null and shop.slots.find_child("body",true,false)==null and shop.slots.find_child("weapon",true,false)==null,id+" has one whole-model paint picker")
		var model=shop.preview.actor._ra3_model
		for bone in preload("res://scripts/units/unit_cosmetics.gd").PARTS[id]:
			check(model.cosmetic_skeleton().find_bone(bone)>=0,id+" offers a real mount bone "+bone)
		var has_weapon_surface:=false
		var has_body_surface:=false
		for part in model.hull.get_children():
			if not part is MeshInstance3D or not part.material_override is ShaderMaterial or part.material_override.shader!=model.OBJECT_SHADER:continue
			var uv2:PackedVector2Array=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
			for mask in uv2:
				if mask.x>0.5:has_weapon_surface=true
				else:has_body_surface=true
		check(has_weapon_surface and has_body_surface,id+" exposes independently paintable body and weapon surfaces")
	pick(shop.units,"R3HARBINGER")
	var wing_picker=shop.slots.find_child("wing",true,false)
	pick(wing_picker,"stock")
	await frames(5)
	var display=shop.preview
	display._inspect()
	await frames(3)
	var wing_adjust:Button=shop.slots.find_child("Adjust_wing",true,false)
	check(wing_adjust.disabled,"empty wing slot disables adjustment")
	var bare:Image=display.actor._ra3_model.viewport.get_texture().get_image()
	pick(wing_picker,"demon")
	await frames(3)
	check(not wing_adjust.disabled,"equipping wings enables adjustment")
	var equipped:Image=display.actor._ra3_model.viewport.get_texture().get_image()
	check(wing_pixels(bare,equipped)>50,"equipping demon wings adds visible wing pixels while inspection is paused")
	display.viewport.get_texture().get_image().save_png(folder.path_join("gunship-demon-wings.png"))
	pick(wing_picker,"stock")
	await frames(3)
	check(wing_adjust.disabled,"removing wings disables adjustment again")
	var removed:Image=display.actor._ra3_model.viewport.get_texture().get_image()
	check(wing_pixels(removed,equipped)>50 and wing_pixels(bare,removed)<wing_pixels(bare,equipped)*0.1,"removing wings clears their pixels without turning")
	pick(wing_picker,"demon")
	check(shop.slots.find_child("tail",true,false).item_count==1,"no universal rear attachment")
	await frames(3)
	check(not display.actor._ra3_model.hull.has_node("CosmeticMount/RearMarker") and shop.slots.find_child("track",true,false)==null,"aircraft preview fits rear marker without a track slot")
	pick(shop.units,"R3TESLA")
	for slot in [["tail","stock"],["paint","ice"],["top","crystal"],["wing","angel"]]:
		pick(shop.slots.find_child(slot[0],true,false),slot[1])
	await frames(20)
	var actor:Unit=shop.preview.actor
	var mount=actor._ra3_model.hull.get_node("CosmeticMount")
	check(mount.has_node("top/CrystalSparkles") and mount.get_node("wing").get_child_count()==2,"crystal and wings have independent mounts")
	for key in ["top","wing","tail"]:
		var funds:=MetaProgress.balance("credits")
		var adjust:Button=shop.slots.find_child("Adjust_"+key,true,false)
		if key=="tail":
			check(adjust.disabled,"unit without rear attachments disables adjustment")
			adjust.pressed.emit()
			check(not shop.has_node("MountEditor") and MetaProgress.balance("credits")==funds,"empty mount cannot open editor or charge")
			continue
		check(not adjust.disabled,"equipped mount permits adjustment "+key)
		adjust.pressed.emit()
		var editor=shop.get_node("MountEditor")
		await frames(3)
		check(not shop.workshop.visible and not actor.can_process() and actor.velocity.is_zero_approx(),"separate editor keeps vehicle stationary "+key)
		check(editor.alignment_views.size()==3,"three simultaneous alignment views "+key)
		var directions:=[Vector3.RIGHT,Vector3.BACK,Vector3.UP]
		for index in 3:
			var view=editor.alignment_views[index]
			var expected:Vector3=actor._ra3_model.hull.global_basis.orthonormalized()*directions[index]
			check(view.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and view.camera.global_basis.z.is_equal_approx(expected) and view.anchor==editor.mount,"fixed hull-relative view "+str(index))
			check(view.texture.get_image().get_used_rect().size.x>40,"alignment viewport renders the unit "+str(index))
		for i in 3:
			var start:Vector2=editor._screen(editor.mount.global_position)
			var step:Vector2=editor._axis_step(i)
			var at:=start+step.normalized()*52.0
			var press:=InputEventMouseButton.new()
			press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
			press.position=editor.stage.get_global_transform_with_canvas()*at
			press.global_position=press.position
			get_viewport().push_input(press,true)
			var motion:=InputEventMouseMotion.new()
			motion.position=editor.stage.get_global_transform_with_canvas()*(at+step*float([12,-8,5][i]))
			motion.global_position=motion.position
			motion.relative=motion.position-press.position
			motion.button_mask=MOUSE_BUTTON_MASK_LEFT
			get_viewport().push_input(motion,true)
			press.pressed=false;press.position=motion.position;press.global_position=motion.position
			get_viewport().push_input(press,true)
		check(editor.draft==Vector3i(12,-8,5) and MetaProgress.attachment_position("R3TESLA",key)==Vector3i.ZERO,"mouse axes edit draft only "+key)
		if key=="top":
			pick(editor.parts,"FX_Weapon_01")
			var tilt_press:=InputEventMouseButton.new()
			tilt_press.button_index=MOUSE_BUTTON_LEFT;tilt_press.alt_pressed=true;tilt_press.pressed=true
			tilt_press.position=editor._screen(editor.mount.global_position)
			editor._stage_input(tilt_press)
			var tilt_drag:=InputEventMouseMotion.new()
			tilt_drag.position=tilt_press.position+Vector2(0,-50)
			editor._stage_input(tilt_drag)
			tilt_press.pressed=false
			editor._stage_input(tilt_press)
			check(editor.tilt==25 and editor.mount.part_id>=0 and MetaProgress.balance("credits")==funds,"part and tilt are a free draft")
			var previous_offset:Vector3i=editor.draft
			var center:Vector2=editor._screen(editor.mount.global_position)
			var plane:=InputEventMouseButton.new()
			plane.button_index=MOUSE_BUTTON_LEFT;plane.pressed=true;plane.position=center
			editor._stage_input(plane)
			var translate:=InputEventMouseMotion.new()
			translate.position=center+Vector2(15,12)
			editor._stage_input(translate)
			plane.pressed=false;editor._stage_input(plane)
			check(editor.draft!=previous_offset and editor.draft.distance_to(previous_offset)>1,"center drag translates along camera plane")
			editor.set_draft(previous_offset)
			var orbit:=InputEventMouseButton.new()
			orbit.button_index=MOUSE_BUTTON_RIGHT;orbit.pressed=true;orbit.position=Vector2(50,50)
			editor._stage_input(orbit)
			var motion:=InputEventMouseMotion.new()
			motion.relative=Vector2(32,12);editor._stage_input(motion)
			orbit.pressed=false;editor._stage_input(orbit)
			check(not is_equal_approx(editor.yaw,0.7) and editor.draft==Vector3i(12,-8,5),"orbit changes view only")
			await frames(3)
			check(editor.scene_view.get_texture().get_image().get_used_rect().size.x>40,"editor draws actual model")
			get_viewport().get_texture().get_image().save_png(folder.path_join("mount-editor.png"))
		if key=="top":
			MetaProgress.currency.credits=99
			editor._save()
			check(shop.has_node("MountEditor") and MetaProgress.balance("credits")==99 and MetaProgress.attachment_position("R3TESLA",key)==Vector3i.ZERO,"insufficient funds keep draft and saved transform intact")
			MetaProgress.currency.credits=funds
			var tmp:=MetaProgress.SAVE_PATH+".tmp"
			check(DirAccess.make_dir_absolute(tmp)==OK,"block adjustment transaction")
			editor._save()
			check(MetaProgress.balance("credits")==funds and shop.has_node("MountEditor") and MetaProgress.attachment_pose("R3TESLA",key).pitch==0,"failed save rolls back pose and fee")
			DirAccess.remove_absolute(tmp)
		editor._save()
		check(MetaProgress.balance("credits")==funds-100,"one fee for all adjustments "+key)
		check(shop.workshop.visible and MetaProgress.attachment_position("R3TESLA",key)==Vector3i(12,-8,5),"save returns to original unit "+key)
		adjust.pressed.emit()
		editor=shop.get_node("MountEditor")
		editor.set_draft(Vector3i.ZERO)
		if key!="top": editor._save()
		else: editor.closed.emit(false)
		check(MetaProgress.attachment_position("R3TESLA","top")==Vector3i(12,-8,5),"cancel or another slot reset preserves top")
	var balance_after:=MetaProgress.balance("credits")
	check(MetaProgress.save_attachment("R3TESLA","top",Vector3i(12,-8,5),"FX_Weapon_01",25) and MetaProgress.balance("credits")==balance_after,"unchanged settings cost zero")
	MetaProgress.load_save()
	check(MetaProgress.attachment_pose("R3TESLA","top")=={"part":"FX_Weapon_01","pitch":25} and MetaProgress.balance("credits")==balance_after,"attachment and charged wallet reload together")
	check(MetaProgress.attachment_position("R3TESLA","top")==Vector3i(12,-8,5) and MetaProgress.attachment_position("R3APOC","top")==Vector3i.ZERO,"offset persists independently per unit")

	check(shop.slots.find_child("tail",true,false).item_count==1,"no universal rear attachment")
	pick(shop.slots.find_child("track",true,false),"chevron_track")
	await frames(3)
	shop.slots.find_child("Preview_track",true,false).pressed.emit()
	check(not actor._ra3_model.hull.has_node("CosmeticMount/RearMarker") and shop.preview.track_sample.visible,"workshop simultaneously displays rear marker and chevron track sample")
	shop.preview.viewport.get_texture().get_image().save_png(folder.path_join("rear-and-tracks.png"))
	check(shop.preview.viewport.get_texture().get_image().get_used_rect().size.x>25,"RA3 preview actually draws pixels")
	var art_before:PackedByteArray=shop.preview.viewport.get_texture().get_image().get_data()
	var heading:=actor.hull_angle
	await frames(20)
	check(not is_equal_approx(heading,actor.hull_angle) and shop.preview.viewport.get_texture().get_image().get_data()!=art_before,"RA3 model moves across rendered frames")
	for mat in actor._ra3_model.materials:
		if mat.shader==actor._ra3_model.OBJECT_SHADER:
			check(mat.get_shader_parameter("custom_body")==preload("res://scripts/units/unit_cosmetics.gd").COLORS.ice and mat.get_shader_parameter("custom_weapon")==preload("res://scripts/units/unit_cosmetics.gd").COLORS.ice,"one paint choice reaches both native material channels")
			break
	get_viewport().get_texture().get_image().save_png(folder.path_join("workshop.png"))
	pick(shop.slots.find_child("wing",true,false),"demon")
	check(MetaProgress.cosmetic_style("R3TESLA").wing=="demon" and MetaProgress.house_color=="red","replacing wings preserves team colour")
	shop.series.select(1);shop.series.item_selected.emit(1)
	for id in ["SREF","GGI","TTNK","APOC"]:
		await check_yr_skin(shop,id)
	for id in ["E1","E2"]:await check_hero_idle_armor(shop.preview,id)
	await check_casemate_frame(shop)
	for aircraft_id in ["SCHP","SHAD","ORCA","BEAG","ZEP","JUMPJET"]:
		pick(shop.units,aircraft_id)
		await inspect_yr_aircraft(shop.preview)
	pick(shop.units,"TERROR")
	await frames(4)
	await check_click_pause(shop.preview)
	for entry in [["MTNK","cobalt_porcelain",4],["HTNK","ember_steel",5]]:
		pick(shop.units,entry[0])
		pick(shop.slots.find_child("skin",true,false),entry[1])
		await frames(5)
		check(shop.preview.actor.material.get_shader_parameter("unit_skin")==entry[2],"workshop displays "+entry[1])
		shop.preview.viewport.get_texture().get_image().save_png(folder.path_join(entry[1]+".png"))
		shop.preview._inspect()
		var painted:Unit=shop.preview.actor
		var pose:Image=shop.preview.viewport.get_texture().get_image()
		if entry[0]=="MTNK":
			painted.tank_finish.tick(painted,8.0,true)
		else:
			painted.tank_finish.shell_hit()
			painted.tank_finish.tick(painted,0.21,true)
		painted.queue_redraw()
		await frames(4)
		var painted_frame:Image=shop.preview.viewport.get_texture().get_image()
		check(pose.get_data()!=painted_frame.get_data(),"fixed-pose tank skin effects change real pixels "+entry[1])
		painted_frame.save_png(folder.path_join(entry[1]+"-active.png"))
		if entry[0]=="MTNK":
			var preserved:=0
			for x in pose.get_width():
				for y in pose.get_height():
					var color:=pose.get_pixel(x,y)
					if color.a>0.95 and color.r>0.2 and color.r>color.g*2 and color==painted_frame.get_pixel(x,y):preserved+=1
			check(preserved>25,"red house markings survive full cyan crystallization")
			shop.preview._process(2.0)
			var partial:float=painted.material.get_shader_parameter("crystal_growth")
			check(partial>0.4 and partial<=0.5,"inspection previews the same gradual parking fade")
			await frames(3)
			var fading:Image=shop.preview.viewport.get_texture().get_image()
			check(fading.get_data()!=painted_frame.get_data(),"parked preview fade changes rendered tank")
	pick(shop.units,"MTNK")
	var tank_skins:OptionButton=shop.slots.find_child("skin",true,false)
	var listed:Array=[]
	for i in tank_skins.item_count:listed.append(tank_skins.get_item_metadata(i))
	check(listed==["stock","winter","cobalt_porcelain"],"tank has original, snow camouflage and its exclusive skin")
	pick(tank_skins,"winter")
	await frames(4)
	check(shop.preview.actor.material.get_shader_parameter("unit_skin")==2,"RA2 skin reaches rendered actor")
	var skin_before:PackedByteArray=shop.preview.viewport.get_texture().get_image().get_data()
	await frames(28)
	check(shop.preview.viewport.get_texture().get_image().get_data()!=skin_before,"YR skin and tank rotate in preview")
	MetaProgress.load_save()
	check(MetaProgress.cosmetic_style("R3TESLA").top=="crystal" and MetaProgress.cosmetic_style("MTNK").skin=="winter","both per-unit outfits survive reload")
	pick(shop.units,"HARV")
	pick(shop.slots.find_child("skin",true,false),"night_shift")
	await frames(6)
	check(shop.preview.actor.material.get_shader_parameter("unit_skin")==3,"night shift miner uses graphite paint")
	shop.preview._inspect()
	shop.preview.actor.cargo=0;shop.preview.actor.queue_redraw()
	await frames(3)
	var empty:Image=shop.preview.viewport.get_texture().get_image()
	shop.preview.actor.cargo=shop.preview.actor.cargo_cap;shop.preview.actor.queue_redraw()
	await frames(3)
	var loaded:Image=shop.preview.viewport.get_texture().get_image()
	check(empty.get_data()!=loaded.get_data(),"night shift lamps respond to cargo with a fixed pose")
	loaded.save_png(folder.path_join("night-miner.png"))
	await check_roof_lamps(shop.preview)
	pick(shop.units,"SUB")
	pick(shop.slots.find_child("weapon_fx",true,false),"quiet_sonar")
	check(shop.fx_host.get_child_count()==2 and shop.fx_host.get_child(0).launch,"submarine workshop previews both events")
	for fx in shop.fx_host.get_children():
		fx.age=0.27;fx.set_process(false);fx.queue_redraw()
	await frames(3)
	get_viewport().get_texture().get_image().get_region(screen_crop(shop.fx_strip)).save_png(folder.path_join("quiet-sonar.png"))
	shop.series.select(2);shop.series.item_selected.emit(2)
	pick(shop.units,"NAREFN")
	pick(shop.slots.find_child("skin",true,false),"night_shift")
	await frames(5)
	check(shop.structure.material.get_shader_parameter("unit_skin")==3,"refinery preview has independent night shift skin")
	var factory_rect:=screen_crop(shop.structure)
	get_viewport().get_texture().get_image().get_region(factory_rect).save_png(folder.path_join("night-refinery.png"))
	shop.free()
	var meta=load("res://scenes/meta.tscn").instantiate()
	add_child(meta)
	meta._set_page("units")
	meta._unit_sel="R3HARBINGER";meta._rebuild_unit_detail()
	await frames(8)
	var visible_ship:=false
	for item in meta.unit_detail.find_children("*","TextureRect",true,false):
		if item.has_method("show_unit") and item.actor.unit_id=="R3HARBINGER":
			visible_ship=item.viewport.get_texture().get_image().get_used_rect().has_area()
	check(visible_ship,"gunship visible in unit modification screen")
	meta._unit_sel="R3REAPER";meta._rebuild_unit_detail()
	await frames(10)
	get_viewport().get_texture().get_image().save_png(folder.path_join("unit-mods.png"))
	for id in ["reaper_split_fire","reaper_fire_control"]:
		meta._show_talent_demo("R3REAPER",id,3)
		var window=meta.get_node("TalentDemo")
		var preview=window.find_child("Preview",true,false)
		preview.age=5.5
		await frames(5)
		check(preview.actor.attack_target==preview.primary and not preview.actor.is_physics_processing(),"demo uses isolated target and visual-only actor")
		if id=="reaper_split_fire":check(preview.actor.special.split_side_index in [1,2],"E designates one real side mount")
		get_viewport().get_texture().get_image().save_png(folder.path_join(id+".png"))
		window.queue_free()
		await frames(1)
	meta.free()
	var screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen);screen.process_mode=Node.PROCESS_MODE_DISABLED
	var gunship=screen.battle.spawn_unit("R3HARBINGER","ally",Vector2(980,980))
	check(gunship._visual_lift()>0,"battle gunship retains airborne height")
	var gun_model=gunship._ra3_model
	var installed=gun_model.hull.get_node_or_null("CosmeticMount")
	check(installed!=null,"battle gunship loads saved wings")
	if installed!=null:
		gun_model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await frames(3)
		var with_wings:Image=gun_model.viewport.get_texture().get_image()
		installed.hide()
		gun_model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await frames(3)
		check(wing_pixels(gun_model.viewport.get_texture().get_image(),with_wings)>50,"battle gunship renders saved demon wings")
	var allied=screen.battle.spawn_unit("R3TESLA","ally",Vector2(1000,1000))
	var enemy=screen.battle.spawn_unit("R3TESLA","enemy",Vector2(1100,1000))
	var anchor=allied._ra3_model.hull.get_node("CosmeticMount/top")
	check(anchor.offset==Vector3i(12,-8,5) and anchor.tilt==25 and not anchor.has_node("AdjustMarker"),"battle uses saved offset and pitch without editor marker")
	var before_turn:Transform3D=anchor.global_transform
	allied.turret_angle+=PI/2
	allied._ra3_model._sample(1.0/30.0)
	await frames(3)
	var bone_pose:Transform3D=anchor.rig.global_transform*anchor.rig.get_bone_global_pose(anchor.part_id)
	check(not anchor.global_transform.is_equal_approx(before_turn) and (anchor.get_parent_node_3d().global_transform*anchor.anchor_frame).origin.is_equal_approx(bone_pose.origin),"attached decoration follows actual moving turret socket")
	check(anchor.transform.is_equal_approx(anchor.anchor_frame*Transform3D(Basis(Vector3.BACK,deg_to_rad(25)),Vector3(0.12,-0.08,0.05))),"local tilt and offset survive bone motion")
	check(allied._ra3_model.hull.has_node("CosmeticMount") and not enemy._ra3_model.hull.has_node("CosmeticMount"),"battle applies player equipment to allied units only")
	MetaProgress.owned_cosmetics.slag_chains=true
	check(MetaProgress.set_cosmetic("R3APOC","tail","slag_chains"),"equip drag chains for battle")
	var visible_center:Vector2=screen.battle.get_canvas_transform().affine_inverse()*screen.battle.get_viewport_rect().get_center()
	var tracked=screen.battle.spawn_unit("R3APOC","ally",visible_center)
	await check_dragging(tracked._ra3_model.hull.get_node("CosmeticMount/tail").get_child(0),tracked,false)
	check_wind_crown_contacts(screen.battle)
	check_rangefinder_contact(screen.battle)
	check_yr_combat_skins(screen.battle)
	var tank=screen.battle.spawn_unit("MTNK","ally",Vector2(1020,1050))
	check(tank.material.get_shader_parameter("unit_skin")==2,"battle loads complete RA2 skin")
	MetaProgress.set_cosmetic("MTNK","skin","cobalt_porcelain")
	var moving:Unit=screen.battle.spawn_unit("MTNK","ally",Vector2(600,800))
	var parked:Unit=screen.battle.spawn_unit("MTNK","ally",Vector2(700,850))
	for i in 82:
		moving.position.x+=3
		moving.tank_finish.tick(moving,0.1)
		parked.tank_finish.tick(parked,0.1)
	check(moving.material!=parked.material and is_equal_approx(moving.material.get_shader_parameter("crystal_growth"),1) and is_zero_approx(parked.material.get_shader_parameter("crystal_growth")),"only moving Grizzly crystallizes")
	moving.tank_finish.tick(moving,2)
	check(is_equal_approx(moving.special.cobalt_travel,0.5) and is_equal_approx(moving.material.get_shader_parameter("crystal_growth"),0.5),"parked Grizzly fades halfway in two seconds")
	moving.position.x+=3
	moving.tank_finish.tick(moving,1)
	check(is_equal_approx(moving.special.cobalt_travel,0.625),"driving resumes from the partially faded finish")
	moving.tank_finish.tick(moving,3)
	check(is_zero_approx(moving.special.cobalt_travel) and is_zero_approx(moving.material.get_shader_parameter("crystal_growth")),"parking restores the base porcelain without undershoot")
	var rhino:Unit=screen.battle.spawn_unit("HTNK","ally",Vector2(820,800))
	rhino.receive_hit(3,"bullet")
	check(is_zero_approx(rhino.tank_finish.wall),"small arms leave Rhino armor idle")
	rhino.receive_hit(3,"shell")
	check(rhino.tank_finish.wall>0,"damaging shell triggers armor")
	rhino.tank_finish.tick(rhino,0.1)
	rhino.position.x+=3
	rhino.tank_finish.tick(rhino,0.1)
	check(rhino.tank_finish.dust>0,"actual displacement builds orbital dust")
	rhino.tank_finish.tick(rhino,2)
	check(rhino.tank_finish.dust==0 and rhino.tank_finish.wall==0,"sand settles and armor flash expires")
	check_economy_and_sonar(screen.battle)
	screen.free()
	await check_live_wind_crown()
	MetaProgress.currency.credits=original_credits
	MetaProgress.attachment_positions=original_mounts
	MetaProgress.owned_cosmetics=original_owned
	MetaProgress.unit_cosmetics=original
	HouseColor.set_player(team)
	print("SHOWCASE checks=",checks," failed=",failures)
	get_tree().quit(0 if failures==0 else 1)

func pointer(preview:Control,point:Vector2,relative:Vector2,dragging:bool) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=point
	event.global_position=point
	event.relative=relative
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if dragging else 0
	preview.get_viewport().push_input(event,true)

func inspect_aircraft(preview) -> void:
	var ship:Unit=preview.actor
	var model=ship._ra3_model
	check(model.viewport.get_texture().get_image().get_used_rect().has_area(),"gunship mesh rendered inside native viewport")
	var image:Image=preview.viewport.get_texture().get_image()
	check(image.get_used_rect().has_area(),"gunship visible in workshop")
	image.save_png(folder.path_join("gunship-preview.png"))
	await check_click_pause(preview)
	await check_drag_directions(preview)
	preview.set_process(false)
	var held:float=ship.hull_angle
	preview._process(4.99-preview.idle_seconds)
	check(ship.hull_angle==held and preview.view_mode==preview.ViewMode.INSPECT,"view holds for the full idle delay")
	preview._process(0.011)
	check(preview.view_mode==preview.ViewMode.RETURN,"idle for five seconds starts recentering while still hovered")
	for i in 40:
		if preview.view_mode==preview.ViewMode.SPIN:break
		preview._process(0.025)
	check(is_zero_approx(ship.hull_angle) and preview.view_mode==preview.ViewMode.SPIN,"inspection returns to its original heading")
	preview._process(0.25)
	check(ship.hull_angle>0.1,"automatic rotation resumes")
	pointer(preview,Vector2(2,2),Vector2(-60,0),false)

func check_click_pause(preview) -> void:
	var center:Vector2=preview.get_global_rect().get_center()
	pointer(preview,center,Vector2(2,0),false)
	var before:float=preview.actor.hull_angle
	await frames(6)
	check(preview.view_mode==preview.ViewMode.SPIN and preview.actor.hull_angle!=before,"hover keeps spinning "+preview.unit_id)
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.position=center
	click.pressed=true
	preview.get_viewport().push_input(click,true)
	before=preview.actor.hull_angle
	await frames(3)
	check(preview.view_mode==preview.ViewMode.INSPECT and preview.actor.hull_angle==before,"left press pauses immediately "+preview.unit_id)
	click.pressed=false
	preview.get_viewport().push_input(click,true)
	await frames(4)
	var elapsed:float=preview.idle_seconds
	pointer(preview,center+Vector2(3,0),Vector2(3,0),false)
	check(preview.idle_seconds>=elapsed and preview.actor.hull_angle==before,"hover after click does not reset idle timer "+preview.unit_id)

func check_drag_directions(preview) -> void:
	var center:Vector2=preview.get_global_rect().get_center()
	var start:float=preview.actor.hull_angle
	var before_pixels:PackedByteArray=preview.viewport.get_texture().get_image().get_data()
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.position=center
	click.pressed=true
	preview.get_viewport().push_input(click,true)
	pointer(preview,center+Vector2(75,0),Vector2(75,0),true)
	await frames(3)
	var right:float=preview.actor.hull_angle
	var right_pixels:PackedByteArray=preview.viewport.get_texture().get_image().get_data()
	check(angle_difference(start,right)<-0.4 and right_pixels!=before_pixels,"right drag turns "+preview.unit_id)
	pointer(preview,center+Vector2(20,0),Vector2(-55,0),true)
	click.pressed=false
	click.position=center+Vector2(20,0)
	preview.get_viewport().push_input(click,true)
	await frames(3)
	check(angle_difference(right,preview.actor.hull_angle)>0.3 and preview.viewport.get_texture().get_image().get_data()!=right_pixels,"left drag reverses "+preview.unit_id)

func inspect_yr_aircraft(preview) -> void:
	var unit:Unit=preview.actor
	await frames(4)
	preview._inspect()
	if unit.unit_id=="SCHP":await check_drag_directions(preview)
	var all_visible:=true
	for facing in 8:
		preview.view_heading=TAU*facing/8
		preview._display_heading()
		await frames(2)
		var picture:Image=preview.viewport.get_texture().get_image()
		var body:=Rect2i()
		var pixels:=0
		for y in picture.get_height():
			for x in picture.get_width():
				var color:=picture.get_pixel(x,y)
				if color.a<0.85 or color.v<0.20:continue
				body=body.merge(Rect2i(x,y,1,1)) if pixels>0 else Rect2i(x,y,1,1)
				pixels+=1
		if facing==1:picture.save_png(folder.path_join(unit.unit_id+"-preview.png"))
		if pixels<45 or body.position.y<1 or body.end.y>=picture.get_height() or body.position.x<1 or body.end.x>=picture.get_width():
			print(unit.unit_id," facing=",facing," body=",body," pixels=",pixels)
			all_visible=false
	check(all_visible,unit.unit_id+" coloured body visible and fully framed in eight directions")
func wing_pixels(bare:Image,equipped:Image) -> int:
	var count:=0
	for y in equipped.get_height():
		for x in equipped.get_width():
			var pixel:=equipped.get_pixel(x,y)
			if pixel.a>0.9 and pixel.r>pixel.g*1.6 and pixel!=bare.get_pixel(x,y):count+=1
	return count

func check_economy_and_sonar(world) -> void:
	const Counts=preload("res://scripts/world/production_counts.gd")
	var saved_stats:=MetaProgress.stats.duplicate(true)
	MetaProgress.stats.erase(Counts.KEY)
	var at:=Vector2(1300,1300)
	var ref=world._place_building("NAREFN","ally",at,true)
	ref._buildup_play=-1
	check(ref.material.get_shader_parameter("unit_skin")==3,"placed refinery loads night outfit")
	var sub=world.spawn_unit("SUB","ally",at)
	var ship=world.spawn_unit("DEST","enemy",at+Vector2(110,0))
	ship.hp=10000;ship.max_hp=10000
	sub.attack_target=ship;sub.aim_dir=Vector2.RIGHT;sub.hull_angle=0
	var first:int=world.effects_root.get_child_count()
	sub._fire_shot(ship)
	var shot=world.projectiles_root.get_children().back()
	check(shot.splinters.get("weapon_look")=="quiet_sonar","launched torpedo retains selected look")
	var hp:float=ship.hp
	shot.target_point=ship.position;shot._explode()
	var bubbles:=0
	var rings:=0
	for fx in world.effects_root.get_children().slice(first):
		if fx.get_script()!=Effects.Looks.Sonar:continue
		if fx.launch:bubbles+=1
		else:rings+=1
	check(bubbles==1 and rings==1 and ship.hp<hp,"real torpedo launch and damage generate a bubble pair effect and impact rings")
	check(not world.allied_state.has(Counts.KEY),"spawned fixtures do not count as player production")
	world.struct_ready["NAPOWR"]=1
	world.deliver_ready_structure("NAPOWR","ally",at+Vector2(300,0))
	var b=world._place_building("GAPILE","ally",at+Vector2(0,300),true)
	b._buildup_play=-1
	world.funds=20000
	b.enqueue("E1");b._process(240)
	check(world.allied_state.get(Counts.KEY,{}).get("building",{}).get("NAPOWR")==1 and world.allied_state.get(Counts.KEY,{}).get("unit",{}).get("E1")==1,"placed paid structure and completed factory queue increment once")
	b.enqueue("E1");b._process(240)
	ref.notify_construction_placed();ref._tick_construction_free_unit(1.0)
	check(not world.allied_state[Counts.KEY].unit.has("HARV"),"refinery delivery never counts as a paid miner")
	world.enemy_struct_ready["NAPOWR"]=1
	world.deliver_ready_structure("NAPOWR","enemy",at+Vector2(360,80))
	check(world.allied_state[Counts.KEY].building.NAPOWR==1,"enemy construction excluded from player totals")
	var miner=world.spawn_unit("HARV","ally",ref.refinery_dock_point(10))
	miner.cargo=miner.cargo_cap;miner.harvest_state="unloading";miner.home_base=ref
	miner._dock_locked=true;miner._dock_home=ref;miner._dock_pt=miner.position
	check(ref.unloading_miner()==miner,"ramp reads miner occupying refinery dock")
	miner.position+=Vector2(90,0)
	check(ref.unloading_miner()==null,"ramp turns off when miner is away")
	Counts.settle(world);Counts.settle(world)
	var rows:Dictionary=MetaProgress.stats[Counts.KEY].factions[world.roster_faction()]
	check(rows.matches==1 and rows.unit.E1=={"built":2,"matches":1} and rows.building.NAPOWR=={"built":1,"matches":1},"reloading same match cannot duplicate total or usage")
	MetaProgress.load_save()
	check(Counts.summary().contains("美国大兵　2 个　·　1 局"),"workshop statistics survive reload and show uses separately")
	MetaProgress.stats=saved_stats

func screen_crop(control:Control) -> Rect2i:
	var viewport:=control.get_viewport()
	var pixels:=viewport.get_texture().get_size()
	var local:=Rect2(Vector2.ZERO,control.size)
	var mapped:Rect2=viewport.get_final_transform()*control.get_global_transform_with_canvas()*local
	return Rect2i(mapped).intersection(Rect2i(Vector2i.ZERO,Vector2i(pixels)))

func check_live_wind_crown() -> void:
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"fog_of_war":true})
	var screen=load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	var world=screen.battle
	var at:Vector2=world.player_start()+Vector2(160,-120)
	var gun=world.spawn_unit("R3REAPER","ally",at)
	gun.fire_stance="none"
	var crown=gun._ra3_model.hull.get_node("CosmeticMount/top").get_child(0)
	world.camera.position=at
	await frames(30)
	check(world.fog!=null and crown.last_signal==0,"live battle starts with dark crown and fog enabled")
	var tower=world._place_building("TESLA","enemy",at+Vector2(160,80),true)
	await frames(36)
	check(world.actor_visible_to("ally",tower,gun) and not gun.selected and not gun.special.has("split_enemy"),"ordinary visible enemy tower, no selection or E")
	check(crown.last_signal>0 and not gun.attack_ordered,"engine updates crown on nearby enemy tower without an order")
	var reach:float=crown.ReaperPose.definitions.rounds.grenade.max_range*1.5
	tower.global_position=gun.global_position+Vector2(reach+2,0)
	await frames(32)
	check(gun.global_position.distance_to(tower.global_position)>reach and CommandoCombat.distance_to(gun,tower)<=reach,"tower footprint straddles firing radius: %.2f / %.2f" % [gun.global_position.distance_to(tower.global_position),CommandoCombat.distance_to(gun,tower)])
	check(crown.last_signal>0,"near edge of a visible tower lights the crown without E")
	tower.global_position+=Vector2(350,0)
	await frames(32)
	check(crown.last_signal==0,"engine clears crown after tower leaves range")
	await check_drive_pivot_plume(world)
	screen.free()

func check_drive_pivot_plume(world) -> void:
	MetaProgress.owned_cosmetics.phase_case=true
	check(MetaProgress.set_cosmetic("R3FUTURE","tail","phase_case"),"equip battle X-1 steering exhaust")
	var at:=Vector2.ZERO
	var leg:=Vector2(-360,100)
	var paths=world.path_service
	for y in range(400,int(world.map_size)-400,100):
		for x in range(500,int(world.map_size*0.5),100):
			var start:=Vector2(x,y)
			if paths.line_walkable(start,start+leg,paths.cost) and paths.line_walkable(start+Vector2.DOWN*40,start+leg+Vector2.DOWN*40,paths.cost):
				at=start
				break
		if at!=Vector2.ZERO:break
	check(at!=Vector2.ZERO,"clear corridor for real driving order")
	var tank=world.spawn_unit("R3FUTURE","ally",at)
	var model=tank._ra3_model
	var ornament=model.hull.get_node("CosmeticMount/tail").get_child(0)
	tank.fire_stance="none"
	world.camera.position=at
	await frames(3)
	tank.order_move(at+leg)
	var pivot_frames:=0
	var bent_bright_frames:=0
	var max_bend:=0.0
	var traveled:=0.0
	var capture:=OS.get_environment("IRON_TIDE_DRIVE_CLIP")=="1"
	for i in 145:
		await get_tree().process_frame
		if tank._drive_turning and tank.velocity.length_squared()<1:
			pivot_frames+=1
			max_bend=maxf(max_bend,absf(ornament.plume_bend))
			if ornament.light_level>0.5 and absf(ornament.plume_bend)>0.30:bent_bright_frames+=1
		if capture and i%4==0:
			await RenderingServer.frame_post_draw
			model.viewport.get_texture().get_image().save_png(folder.path_join("drive-%03d.png"%i))
		traveled=maxf(traveled,tank.position.distance_to(at))
	print("X1 pivot frames=%d bright/bent=%d peak=%.2f travel=%.1f"%[pivot_frames,bent_bright_frames,max_bend,traveled])
	check(pivot_frames>=10 and bent_bright_frames>=6,"visible curved exhaust during a real zero-speed pivot")
	check(traveled>30,"tank proceeds along the requested route")
	tank.order_stop()

	MetaProgress.owned_cosmetics.casemate_frame=true
	check(MetaProgress.set_cosmetic("TNKD","skin","casemate_frame"),"equip TNKD turbine in battle")
	var start:=at+Vector2.DOWN*40
	var hunter=world.spawn_unit("TNKD","ally",start)
	hunter.fire_stance="none"
	world.camera.position=start
	await frames(3)
	hunter.order_move(start+leg)
	var pivot_lit:=0
	var straight_lit:=false
	for i in 150:
		await get_tree().process_frame
		if hunter._drive_turning and hunter.velocity.length_squared()<1 and hunter.casemate_thruster.thrust>0.25 and absf(hunter.casemate_thruster.bend)>0.1:
			pivot_lit+=1
		if hunter.position.distance_to(start)>30 and hunter.casemate_thruster.thrust>0.5:straight_lit=true
	check(pivot_lit>=3 and straight_lit,"TNKD turbine lit and curved in real pivot (%d frames), then driving"%pivot_lit)
	hunter.order_stop()
	await frames(60)
	check(is_zero_approx(hunter.casemate_thruster.thrust),"TNKD turbine extinguishes after a real stop")

	var lights=hunter.casemate_thruster
	check(lights.light_time==0.0,"unselected TNKD holds its starting lights even after driving")
	world.select_unit(hunter,false)
	await frames(18)
	check(lights.light_rate==1.0 and lights.light_time>0,"selecting restarts the lamps")
	world.clear_selection()
	var coast_start:float=lights.light_time
	await frames(45)
	var early:float=lights.light_time-coast_start
	await frames(45)
	var late:float=lights.light_time-coast_start-early
	check(late>0.0 and late<early and lights.light_rate<1.0,"deselection gradually slows the phase")
	var before_reselect:float=lights.light_time
	world.select_unit(hunter,false)
	await frames(2)
	check(lights.light_rate==1.0 and lights.light_time>before_reselect and lights.light_time-before_reselect<0.2,"reselect during coast continues the same phase")
	world.clear_selection()
	await frames(195)
	var held:float=lights.light_time
	await frames(12)
	check(lights.light_rate==0.0 and lights.light_time==held,"all eight lamps hold their final colour and brightness")
	world.select_unit(hunter,false)
	await frames(2)
	check(lights.light_time>held and lights.light_time-held<0.2,"reselect after resting resumes from the held phase")
	world.clear_selection()

	# Move into range under an attack order, then keep fighting after deselection.
	hunter.position=start
	hunter.fire_stance="none"
	var dummy=world.spawn_unit("HTNK","enemy",start+leg.normalized()*(hunter.attack_range+75.0))
	dummy.special.gm_stationary=true
	dummy.max_hp=20000
	dummy.hp=dummy.max_hp
	world.select_unit(hunter,false)
	hunter.order_target(dummy,false,false)
	var shots_seen:=0
	var dry_reload_frames:=0
	var approach_lit:=false
	var last_cd:float=hunter._cd_timer
	var wet_shots:=0
	for i in ceili((2.0*hunter.cooldown+8.0)*Engine.physics_ticks_per_second):
		await get_tree().process_frame
		if hunter.velocity.length_squared()>16 and lights.flame_visible(hunter):approach_lit=true
		if hunter._cd_timer>last_cd+0.05:
			shots_seen+=1
			if shots_seen==1:world.clear_selection()
			if lights.flame_visible(hunter):wet_shots+=1
		last_cd=hunter._cd_timer
		if shots_seen>0 and hunter.velocity.is_zero_approx() and hunter._muzzle<=0 and last_cd>0.1:
			if lights.flame_visible(hunter) or lights.light_rate!=1.0:wet_shots+=1
			else:dry_reload_frames+=1
	check(approach_lit and shots_seen>=2 and dummy.hp<dummy.max_hp,"TNKD drives into range with exhaust, then repeatedly fires")
	check(wet_shots==0 and dry_reload_frames>10,"parked TNKD fires and reloads with no exhaust and both lamp banks active after deselection")
	var phase:float=lights.light_time
	await frames(12)
	check(lights.light_time>phase and lights.light_rate==1.0,"unselected combat continues both lighting cycles")
	hunter.order_stop()
	dummy.queue_free()
	await frames(200)
	check(is_zero_approx(lights.thrust) and is_zero_approx(lights.light_rate),"parked out of combat: exhaust off and lamps settle")

func check_wind_crown_contacts(world) -> void:
	MetaProgress.owned_cosmetics.wind_crown=true
	check(MetaProgress.set_cosmetic("R3REAPER","top","wind_crown"),"equip wind crown")
	var gun=world.spawn_unit("R3REAPER","ally",Vector2(800,800))
	var target=world.spawn_unit("E1","enemy",Vector2(800,800))
	var crown=gun._ra3_model.hull.get_node("CosmeticMount/top").get_child(0)
	var fog=world.fog
	world.fog=null
	gun.position=Vector2(-9000,-9000)
	gun.hull_angle=0
	for direction in [1,-1]:
		target.position=gun.position+Vector2(120,direction*120)
		crown._process(0.25)
		var expected:=3 if direction==1 else 5
		check(crown.last_signal==expected,"covered vanes follow target bearing without an attack order")
		for i in 3:
			check(crown.crown_vanes[i].material_override.get_shader_parameter("signal_on")==bool(expected & (1<<i)),"whole vane material matches its sector")
	target.special.echo_cloaked=true
	crown._process(0.25)
	check(crown.last_signal==0,"concealed target clears all vanes")
	target.special.erase("echo_cloaked")
	gun.side="enemy"
	crown._process(0.25)
	check(crown.last_signal==0,"enemy-controlled crown has no signal")
	gun.side="ally"
	world.fog=fog
	target.queue_free()
	gun.queue_free()

func check_rangefinder_contact(world) -> void:
	MetaProgress.owned_cosmetics.rangefinder=true
	check(MetaProgress.set_cosmetic("R3MIRAGE","top","rangefinder"),"equip contact optics")
	var tank=world.spawn_unit("R3MIRAGE","ally",Vector2(800,800))
	var second=world.spawn_unit("R3MIRAGE","ally",Vector2(800,800))
	var target=world.spawn_unit("E1","enemy",Vector2(800,800))
	var pod=tank._ra3_model.hull.get_node("CosmeticMount/top").get_child(0)
	var other=second._ra3_model.hull.get_node("CosmeticMount/top").get_child(0)
	# Isolate range checks from the map's starting armies and fog cells.
	tank.position=Vector2(-8000,-8000)
	second.position=tank.position-Vector2(2000,0)
	var fog=world.fog
	world.fog=null
	target.position=tank.position+Vector2(tank.attack_range+2,0)
	pod._process(0.25)
	check(pod.last_signal==0,"out of range keeps lenses dark")
	target.position=tank.position+Vector2(tank.attack_range,0)
	pod._process(0.25)
	other._process(0.25)
	check(pod.optic_finish.get_shader_parameter("contact")==1.0 and other.optic_finish.get_shader_parameter("contact")==0.0,"unselected tank signals on range boundary without lighting another tank")
	target.special.echo_cloaked=true
	pod._process(0.25)
	check(pod.last_signal==0,"cloaked contact does not light lenses")
	target.special.erase("echo_cloaked")
	world.fog=fog
	if fog!=null:
		pod._process(0.25)
		check(pod.last_signal==0,"contact outside visible fog cells stays dark")
	world.fog=null
	pod._process(0.25)
	tank.side="enemy"
	pod._process(0.01)
	check(pod.last_signal==0,"loss of player control clears lamp immediately")
	tank.side="ally"
	target.hp=0
	pod._process(0.25)
	check(pod.last_signal==0,"dead contact does not light optics")
	world.fog=fog
	target.queue_free()
	tank.queue_free()
	second.queue_free()

func check_yr_combat_skins(world) -> void:
	var point:=Vector2(1320,1100)
	var target=world.spawn_unit("HTNK","enemy",point+Vector2(100,0))
	var neighbor=world.spawn_unit("MTNK","enemy",target.position+Vector2(22,0))
	target.max_hp=30000;target.hp=30000
	neighbor.max_hp=30000;neighbor.hp=30000
	var flyer=world.spawn_unit("JUMPJET","enemy",target.position)
	for id in ["SREF","TTNK","APOC","GGI"]:
		var skin:String=MetaProgress.Cosmetics.EXCLUSIVE_SKINS[id]
		MetaProgress.owned_cosmetics[skin]=true
		check(MetaProgress.set_cosmetic(id,"skin",skin),"equip battle skin "+id)
		var look:String=Effects.Looks.CHOICES.get(id,"")
		if not look.is_empty():check(MetaProgress.set_cosmetic(id,"weapon_fx",look),"combine weapon and unit finish "+id)
		var actor=world.spawn_unit(id,"ally",point)
		actor.attack_target=target
		actor._burst_left=int(actor.weapon.get("burst",1))
		actor._fire_shot(target)
		check(actor.yr_finish!=null and actor.yr_finish.flash>0,"battle shot animates "+id)
		if id=="APOC":
			check(actor.yr_finish.barrel==0 and actor.yr_finish.first_star>0 and actor.yr_finish.constellation==0,"first ground barrel lights a single star")
			actor._burst_left-=1
			actor._fire_shot(target)
			var projectile=world.projectiles_root.get_child(-1)
			check(actor.yr_finish.barrel==1 and actor.yr_finish.constellation>0 and projectile.splinters.get("weapon_look")=="molten_gold","second ground barrel coexists with molten hit")
			actor.attack_target=flyer
			actor._fire_shot(flyer)
			check(actor.yr_finish.air_rack,"shooting aircraft switches to AA lamps")
			actor.velocity=Vector2.ZERO
			actor.attack_ordered=true
			actor._cd_timer=3.0
			actor.yr_finish.tick(actor,1.5)
			check(actor.yr_finish.halo_open==1,"parked AA reload holds orbit after its flash ends")
			actor.attack_target=target
			actor.yr_finish.tick(actor,2.0)
			check(actor.yr_finish.halo_open==1,"parked ground attack holds orbit throughout reload")
			actor.yr_finish.fire(0,actor.weapon,Vector2.ZERO)
			actor.yr_finish.fire(1,actor.weapon,Vector2.ZERO)
			actor.attack_target=null
			actor.yr_finish.tick(actor,1.0)
			check(actor.yr_finish.constellation>0 and actor.yr_finish.halo_open==1,"finishing salvo keeps stars inside a full ring after target loss")
			actor.yr_finish.tick(actor,0.9)
			check(actor.yr_finish.halo_open>0 and actor.yr_finish.halo_open<1,"idle orbit retracts after final stars")
			actor.yr_finish.tick(actor,1.2)
			check(actor.yr_finish.halo_open==0,"no parked orbit after combat")
		elif id=="TTNK":
			MetaProgress.load_save()
			check(MetaProgress.cosmetic_owned("amber_coils") and MetaProgress.cosmetic_style("TTNK").get("skin")=="amber_coils","old Tesla purchase and equipped stable key survive reload")
			var found:=false
			for fx in world.effects_root.get_children():
				if fx is Effects.ElectricBolt and fx.signature and fx.look=="spectrum" and fx.strands.size()==3:found=true
			check(found,"amber afterbolts use native filaments with spectrum equipped")
		elif id=="SREF":
			var found:=false
			for fx in world.effects_root.get_children():
				if fx is Effects.Beam and fx.signature and fx.branch and fx.look in ["prism_red","prism_blue"]:found=true
			check(found,"real refracted hit retains duplex and gold shards")
		else:
			actor.set_deployed(true,false)
			actor.yr_finish.tick(actor,0.5)
			actor._fire_shot(target)
			check(actor.yr_finish.fold==1 and actor.yr_finish.flash>0,"deployed launcher produces its cosmetic exhaust")
			var hp_before:float=actor.hp
			actor.receive_hit(2,"bullet",{},target)
			check(actor.hp<hp_before and actor.yr_finish.warning_left>0,"deployed hit flashes the range rig and still damages the gunner")
			actor.set_deployed(false,false)
			actor.yr_finish.tick(actor,0.5)
			actor.receive_hit(2,"bullet",{},target)
			check(actor.yr_finish.warning_left==0,"standing hits do not trigger the deployed warning")

func check_hero_idle_armor(display,id:String) -> void:
	display.show_unit(id)
	display._inspect()
	display.set_process(false)
	var actor=display.actor
	actor.velocity=Vector2.ZERO
	actor.special.hero_skin=true
	actor.idle_pose.appearance=id
	for name in ["Idle1","Idle2"]:
		actor.idle_pose.clip=name
		var segment:Dictionary=actor._seq[name]
		for i in int(segment.per):
			var frame:=int(segment.start)+i
			actor.idle_pose.frame=frame
			display.view_heading=0.0
			display._display_heading()
			await frames(1)
			var shot:Image=display.viewport.get_texture().get_image()
			display.view_heading=PI
			display._display_heading()
			await frames(1)
			check(actor._art_frame==frame and shot.get_data()==display.viewport.get_texture().get_image().get_data(),id+" armour independent of order heading at idle frame "+str(frame))
			if OS.get_environment("IRON_TIDE_HERO_IDLE_CLIP")=="1":shot.save_png(folder.path_join("hero-%s-%d.png"%[id,frame]))
	actor.order_move(actor.position+Vector2.RIGHT*90)
	actor.idle_pose.tick(actor,0.02)
	check(actor.idle_pose.frame<0 and actor.HeroArmor.pose_bearing(actor,0,6)==6.0,id+" armour resumes order direction on move")
	display.set_process(true)

func check_casemate_frame(shop) -> void:
	pick(shop.units,"TNKD")
	var display=shop.preview
	var actor=display.actor
	var picker=shop.slots.find_child("skin",true,false)
	pick(picker,"casemate_frame")
	display._inspect()
	display.set_process(false)
	var facings:Dictionary={}
	for i in 32:
		display.view_heading=Iso.eff_angle()+TAU*i/32.0
		display._display_heading()
		display.try_outfit("skin","stock")
		await frames(1)
		var original:Image=display.viewport.get_texture().get_image()
		var muzzle:Vector2=actor._weapon_muzzle()
		display.try_outfit("skin","casemate_frame")
		await frames(1)
		var fitted:Image=display.viewport.get_texture().get_image()
		check(fitted.get_data()!=original.get_data() and actor._weapon_muzzle().is_equal_approx(muzzle),"visible exoframe, identical native muzzle at facing "+str(i))
		facings[actor._art_frame]=true
		if OS.get_environment("IRON_TIDE_CASING_CLIP")=="1":fitted.save_png(folder.path_join("tnkd-%02d.png"%i))
		if i==0:original.save_png(folder.path_join("tnkd-stock.png"))
	check(facings.size()==32 and actor._ra2_tur.is_empty(),"all native casemate facings covered by chassis socket")
	var before:Image=display.viewport.get_texture().get_image()
	actor.turret_angle+=PI/2
	actor.queue_redraw()
	await frames(1)
	check(before.get_data()==display.viewport.get_texture().get_image().get_data(),"fixed casemate fittings ignore independent turret aim")
	var half_cycles:Array[Image]=[]
	display.view_heading=Iso.eff_angle()+0.38
	display._display_heading()
	actor.velocity=Vector2.ZERO
	for second in [0,4,8,2,6,3.5]:
		actor.casemate_thruster.light_time=second
		actor.queue_redraw()
		await frames(2)
		half_cycles.append(display.viewport.get_texture().get_image())
	var swaps:=0
	for y in half_cycles[0].get_height():
		for x in half_cycles[0].get_width():
			var a:=half_cycles[0].get_pixel(x,y)
			var b:=half_cycles[1].get_pixel(x,y)
			if (a.r-a.b)*(b.r-b.b)< -0.12:swaps+=1
	check(swaps>6,"lamps exchange hues after a long hold")
	check(half_cycles[0].get_data()!=half_cycles[3].get_data(),"lamps pulse while their colour holds")
	var ordering:Array[float]=[]
	for flank in 2:
		display.view_heading=Iso.eff_angle()+flank*PI
		display._display_heading()
		var previous:Image=null
		var opposed:=false
		var side_peak_step:=0.0
		var last_sec:=0.0
		for sec in [0.0,0.1,0.27,0.38,0.6,0.85,1.0,1.25]:
			actor.casemate_thruster.light_time=sec
			actor.queue_redraw()
			await frames(1)
			var shot:Image=display.viewport.get_texture().get_image()
			if previous!=null:
				var red_up:=0
				var blue_up:=0
				var red_down:=0
				var blue_down:=0
				for y in range(0,shot.get_height(),2):
					for x in range(0,shot.get_width(),2):
						var a:=previous.get_pixel(x,y)
						var b:=shot.get_pixel(x,y)
						if y>=int(shot.get_height()*0.62):
							if sec-last_sec<0.15:
								side_peak_step=maxf(side_peak_step,maxf(absf(a.r-b.r),absf(a.b-b.b)))
							continue
						if y>shot.get_height()*0.58:continue
						if b.r>b.b+0.10:
							if b.r>a.r+0.06:red_up+=1
							if b.r<a.r-0.06:red_down+=1
						if b.b>b.r+0.10:
							if b.b>a.b+0.06:blue_up+=1
							if b.b<a.b-0.06:blue_down+=1
				opposed=opposed or mini(red_up,blue_down)>5 or mini(red_down,blue_up)>5
			previous=shot
			last_sec=sec
		check(opposed,"cannon feeds heartbeat independently on flank "+str(flank))
		check(side_peak_step>0.01 and side_peak_step<0.10,"side tubes breathe gradually without a heartbeat spike: "+str(side_peak_step))
		if OS.get_environment("IRON_TIDE_BEAT_CLIP")=="1" and flank==0:
			for sample in 100:
				actor.casemate_thruster.light_time=sample*0.05
				actor.queue_redraw()
				await frames(1)
				display.viewport.get_texture().get_image().save_png(folder.path_join("beat-%02d.png"%sample))
		var endpoints:Array[Image]=[]
		for sec in [0,4]:
			actor.casemate_thruster.light_time=sec
			actor.queue_redraw()
			await frames(2)
			var image:Image=display.viewport.get_texture().get_image()
			endpoints.append(image)
			image.save_png(folder.path_join("tubes-%d-%d.png"%[flank,sec]))
		var warm_y:=0.0
		var cold_y:=0.0
		var warm:=0
		var cold:=0
		# In both fixed profile shots the skirt sits below the cannon. Judge
		# tube order by hue even when a tube is between heartbeats.
		for y in range(roundi(endpoints[0].get_height()*0.62),endpoints[0].get_height()):
			for x in endpoints[0].get_width():
				var a:=endpoints[0].get_pixel(x,y)
				var b:=endpoints[1].get_pixel(x,y)
				if a.r-a.b>0.16 and b.b-b.r>0.16:
					warm+=1
					warm_y+=y
				if a.b-a.r>0.16 and b.r-b.b>0.16:
					cold+=1
					cold_y+=y
		check(warm>30 and cold>30,"both bright red and bright blue tubes swap on flank "+str(flank))
		ordering.append(warm_y/maxi(warm,1)-cold_y/maxi(cold,1))
	check(ordering[0]*ordering[1]<-4,"top and bottom tube order is mirrored on the other side")
	display.view_heading=Iso.eff_angle()+TAU*22/32
	display._display_heading()
	actor.casemate_thruster.light_time=8
	actor.queue_redraw()
	await frames(2)
	var parked:Image=display.viewport.get_texture().get_image()
	actor.casemate_thruster.light_time=8
	actor.velocity=Vector2.from_angle(actor.hull_angle)*actor.move_speed
	actor.casemate_thruster.tick(actor,0.25)
	actor.queue_redraw()
	await frames(2)
	var driving:Image=display.viewport.get_texture().get_image()
	var blue_flame:=0
	var red_flame:=0
	for y in driving.get_height():
		for x in driving.get_width():
			var on:=driving.get_pixel(x,y)
			var off:=parked.get_pixel(x,y)
			if on.b*on.a-off.b*off.a>0.13 and on.b>on.r+0.08:blue_flame+=1
			if on.r*on.a-off.r*off.a>0.20 and on.r>on.b+0.14:red_flame+=1
	check(blue_flame>8 and red_flame==0,"turbine exhaust stays blue on red armor (%d blue, %d red)"%[blue_flame,red_flame])
	check(actor.casemate_thruster.rotor_angle>0.5 and actor.casemate_thruster.powered_time<actor.CasemateFrame.WINDUP,"rotor spins during ignition before jet expansion")
	var base_phase:Image=driving
	actor.casemate_thruster.tick(actor,0.3)
	actor.queue_redraw()
	await frames(2)
	check(base_phase.get_data()!=display.viewport.get_texture().get_image().get_data(),"quarter-turn advances the visible flame around the rim while neon holds")
	for i in 100:actor.casemate_thruster.tick(actor,1.0/60)
	actor.queue_redraw()
	await frames(2)
	var burning:Image=display.viewport.get_texture().get_image()
	# Full thrust now lies partly over the hull shadow. Measure the blue flame
	# added to the parked image in premultiplied colour, including over shadow.
	var expanded:=0
	for y in burning.get_height():
		for x in burning.get_width():
			var on:=burning.get_pixel(x,y)
			var off:=base_phase.get_pixel(x,y)
			if on.b*on.a-off.b*off.a>0.20 and on.b-on.r>0.15:expanded+=1
	check(expanded>100,"compact full jet is visible beyond ignition over the shadow (%d pixels)"%expanded)
	if OS.get_environment("IRON_TIDE_CASING_CLIP")=="1":
		actor.casemate_thruster=actor.CasemateFrame.new()
		for i in 80:
			display.view_heading=Iso.eff_angle()+TAU*(22.0+7.0*sin(clampf(i-30.0,0,40)*TAU/40))/32
			display._display_heading()
			actor._anim=i*0.06
			actor.casemate_thruster.advance_lights(true,0.06)
			actor.velocity=Vector2.from_angle(actor.hull_angle)*actor.move_speed if i<73 else Vector2.ZERO
			actor.casemate_thruster.tick(actor,0.06)
			actor.queue_redraw()
			await frames(1)
			display.viewport.get_texture().get_image().save_png(folder.path_join("orbit-%02d.png"%i))
	actor.velocity=Vector2.ZERO
	pick(picker,"stock")
	display.set_process(true)

func check_yr_skin(shop,id:String) -> void:
	var looks=MetaProgress.Cosmetics
	var skin:String=looks.EXCLUSIVE_SKINS[id]
	pick(shop.units,id)
	var picker:OptionButton=shop.slots.find_child("skin",true,false)
	pick(picker,skin)
	var display=shop.preview
	var actor=display.actor
	display._inspect()
	display.view_heading=0.12
	display._display_heading()
	await frames(3)
	check(actor.yr_finish!=null and actor.yr_finish.skin==looks.SKIN_MATERIALS[skin],id+" workshop renders exclusive finish")
	check(not looks.available("E1","skin",skin) and not looks.available("R3APOC","skin",skin),"exclusive skin rejects unrelated units")
	var shot:Image=display.viewport.get_texture().get_image()
	shot.save_png(folder.path_join(skin+".png"))
	match id:
		"GGI":
			display.set_process(false)
			actor.velocity=Vector2.ZERO
			actor.idle_pose.appearance="GGI"
			for name in ["Idle1","Idle2"]:
				var segment:Dictionary=actor._seq[name]
				for step in int(segment.per):
					actor.idle_pose.frame=int(segment.start)+step
					display.view_heading=0
					display._display_heading()
					await frames(1)
					var pose:Image=display.viewport.get_texture().get_image()
					display.view_heading=PI
					display._display_heading()
					await frames(1)
					check(actor._art_frame==int(segment.start)+step and pose.get_data()==display.viewport.get_texture().get_image().get_data(),"coastal pack follows the drawn single-facing idle frame %d"%actor._art_frame)
					if OS.get_environment("IRON_TIDE_GGI_POSES")=="1":pose.save_png(folder.path_join("idle-%d.png"%actor._art_frame))
			actor.idle_pose.reset(actor)
			for facing in 8:
				display.view_heading=TAU*facing/8
				display._display_heading()
				await frames(1)
				if OS.get_environment("IRON_TIDE_GGI_POSES")=="1":display.viewport.get_texture().get_image().save_png(folder.path_join("guard-%d.png"%actor._art_frame))
			actor.set_deployed(true,false)
			actor.yr_finish.tick(actor,0.16)
			check(actor.yr_finish.fold>0 and actor.yr_finish.fold<1,"stabilizers extend during deployment")
			actor.yr_finish.tick(actor,0.4)
			var sprite_frames:={}
			for facing in 8:
				display.view_heading=TAU*facing/8
				display._display_heading()
				await frames(2)
				var index:=int(actor._art_frame)-int(actor._deploy_frame)
				sprite_frames[index]=true
				var img:Image=display.viewport.get_texture().get_image()
				var bounds:=img.get_used_rect()
				check(bounds.has_area() and bounds.position.y>0 and bounds.end.y<img.get_height(),"coastal equipment and scan fit direction "+str(index))
				if index in [1,5] or OS.get_environment("IRON_TIDE_GGI_POSES")=="1":img.save_png(folder.path_join("coastal-facing-%d.png"%index))
			check(sprite_frames.size()==8 and looks.display_name("cliff_sentry")=="岸防导弹手","redesigned legacy skin uses all eight native facings")
			# Exercise the real firing renderer as well as the stationary poses.
			# The optical rack must remain on a valid torso socket through recoil.
			for deployed in [false,true]:
				actor._deployed=deployed
				actor.yr_finish.fold=float(deployed)
				var firing:Dictionary=actor._seq["DeployedFire" if deployed else "FireUp"]
				for facing in 8:
					display.view_heading=Iso.eff_angle()-PI/2-float(facing)*TAU/8
					display._display_heading()
					for step in int(firing.per):
						actor._fire_anim_time=(step+0.01)/16.0
						actor.queue_redraw()
						await frames(1)
						var frame:int=actor._art_frame
						check(frame>=int(firing.start) and frame<int(firing.start)+int(firing.per)*8 and actor.CoastalRig.sockets[frame]!=null,"coastal torso socket follows native firing frame %d"%frame)
						var bounds:Rect2i=display.viewport.get_texture().get_image().get_used_rect()
						check(bounds.has_area() and bounds.position.y>0 and bounds.end.y<display.viewport.size.y,"coastal firing equipment stays in view %d"%frame)
			actor._fire_anim_time=-1.0
			actor._deployed=true
			var rig=actor.yr_finish
			actor.velocity=Vector2.ZERO
			display.view_heading=Iso.eff_angle()-PI/2
			display._display_heading()
			var low:=0.0
			var high:=0.0
			for step in 60:
				rig.tick(actor,1.0/30.0)
				low=minf(low,rig.rig_lean)
				high=maxf(high,rig.rig_lean)
				if OS.get_environment("IRON_TIDE_RIG_CLIP")=="1" and step%2==0:
					actor.queue_redraw()
					await frames(1)
					display.viewport.get_texture().get_image().save_png(folder.path_join("rig-%02d.png"%step))
			check(low< -0.10 and high>0.10 and rig.fold==1,"deployed optics sweep to both sides with feet extended")
			actor.set_deployed(false,false)
			rig.tick(actor,2.0)
			actor.hull_angle+=0.7
			rig.tick(actor,0.05)
			check(rig.rig_lean< -0.04,"turning makes the folded rack briefly lag")
			rig.tick(actor,1.5)
			check(absf(rig.rig_lean)<0.001,"parked rack settles back to centre")
			actor.velocity=Vector2.RIGHT*36.0
			actor._walk_phase=0.25
			rig.tick(actor,0.4)
			check(rig.rig_lean>0.1,"folded rack leans with first footfall")
			actor._walk_phase=0.75
			rig.tick(actor,0.4)
			check(rig.rig_lean< -0.1,"opposite footfall reverses the lean")
			actor.velocity=Vector2.ZERO
			actor.set_deployed(true,false)
			rig.tick(actor,0.4)
			display.view_heading=Iso.eff_angle()+0.46
			display._display_heading()
			actor.yr_finish.fire(-1,actor.deployed_weapon(),Vector2.ZERO)
			check(actor.yr_finish.fold==1,"deployed outriggers render at eight facings")
			actor.yr_finish.mount_hit()
			actor.yr_finish.tick(actor,0.10)
			display.set_process(true)
		"TTNK":
			check(looks.display_name("amber_coils")=="皮卡丘 · 雷霆机甲" and actor.yr_finish.PIKA_ATLAS.get_size()==Vector2(1024,1024),"legacy Tesla skin ID resolves to both 32-facing voxel layers")
			var angles:Dictionary={}
			for facing in 32:
				display.view_heading=TAU*facing/32
				display._display_heading()
				await frames(1)
				var bounds:Rect2i=display.viewport.get_texture().get_image().get_used_rect()
				check(bounds.has_area() and bounds.position.y>0 and bounds.end.y<display.viewport.size.y,"Pikachu ears and tail stay in frame "+str(facing))
				angles[actor._sprite_facing(actor._ra2_tur,actor.turret_angle)]=true
				if OS.get_environment("IRON_TIDE_PIKA_TURNTABLE")=="1":display.viewport.get_texture().get_image().save_png(folder.path_join("pika-%02d.png"%facing))
			check(angles.size()==32,"preview traverses all native Tesla turret frames")
			var body_frame:int=actor._sprite_facing(actor._ra2,actor.hull_angle)
			var head_frame:int=actor._sprite_facing(actor._ra2_tur,actor.turret_angle)
			actor.turret_angle+=PI/2
			actor.queue_redraw()
			await frames(2)
			check(actor._sprite_facing(actor._ra2,actor.hull_angle)==body_frame and actor._sprite_facing(actor._ra2_tur,actor.turret_angle)!=head_frame,"turning turret picks a new armoured head while tail holds hull frame")
			display.view_heading=Iso.eff_angle()+0.85
			display._display_heading()
			actor.yr_finish.tick(actor,0.1,1.0)
		"SREF":
			actor.velocity=Vector2.ZERO
			actor.yr_finish.tick(actor,1.5)
			check(actor.yr_finish.stopped==1,"parked mirrors light in sequence")
			var headings:Dictionary={}
			var rig=actor.yr_finish
			for facing in 32:
				display.view_heading=Iso.eff_angle()+facing*TAU/32
				display._display_heading()
				actor.queue_redraw()
				await frames(1)
				var pose:Image=display.viewport.get_texture().get_image()
				headings[actor._art_frame]=true
				check(pose.get_used_rect().has_area() and pose.get_used_rect().end.y<=pose.get_height(),"solar-veined hull rendered in facing "+str(facing))
			check(headings.size()==32,"solar hull visits all native bearings")
			display.view_heading=Iso.eff_angle()+0.35
			display._display_heading()
			actor.velocity=Vector2.RIGHT*40
			rig.tick(actor,1.5)
			var phases:Array[Image]=[]
			for stage in 3:
				if stage==1:
					actor.velocity=Vector2.ZERO
					rig.tick(actor,1.5)
				elif stage==2:
					rig.fire(-1,actor._active_weapon(),Iso.dir(actor._weapon_muzzle()-actor.global_position))
					rig.tick(actor,.16)
				actor.queue_redraw()
				await frames(2)
				var im:Image=display.viewport.get_texture().get_image()
				phases.append(im)
				im.save_png(folder.path_join("solar-phase-%d.png"%stage))
			var charged_pixels:=0
			var shot_pixels:=0
			for y in range(phases[0].get_height()/2,phases[0].get_height(),2):
				for x in range(0,phases[0].get_width(),2):
					var a:=phases[0].get_pixel(x,y)
					var b:=phases[1].get_pixel(x,y)
					var c:=phases[2].get_pixel(x,y)
					if a.r>a.b+0.10 and b.g>a.g+0.07 and b.r>a.r:charged_pixels+=1
					if c.g>b.g+0.05 and c.r>c.b+0.15:shot_pixels+=1
			check(charged_pixels>25 and shot_pixels>12,"parked branches turn gold and firing lights hull branches (%d/%d)"%[charged_pixels,shot_pixels])
		"APOC":
			for idx in 2:
				actor.yr_finish.fire(idx,actor.weapon,Vector2.ZERO)
				check(actor.yr_finish.barrel==idx and not actor.yr_finish.air_rack,"main gun selects its own brass slide")
			actor.yr_finish.fire(-1,actor.data.anti_air_weapon,Vector2.ZERO)
			check(actor.yr_finish.air_rack,"native AA weapon selects side lights")
			for i in 2:actor.yr_finish.fire(i,actor.weapon,Vector2.ZERO)
			actor.yr_finish.tick(actor,0.38)
	actor.queue_redraw()
	await frames(3)
	display.viewport.get_texture().get_image().save_png(folder.path_join(skin+"-active.png"))
	if id=="APOC":
		check(display.viewport.size==Vector2i(960,600) and display.custom_minimum_size.y>=280,"workshop opens a large polar preview")
		actor.velocity=Vector2.ZERO
		actor.yr_finish.tick(actor,2.0)
		var screen_pose:Transform2D=actor.get_global_transform_with_canvas()*Transform2D(Iso.eff_angle(),Iso.up(),0,Vector2.ZERO)
		var above_roof:=Rect2i(0,0,display.viewport.size.x,int((screen_pose*actor._body_bounds.position).y)-8)
		var widths:Array[int]=[]
		for state in ["parked","cruising","closing","parked-again"]:
			actor.velocity=Vector2.RIGHT*60 if state=="cruising" else Vector2.ZERO
			actor.yr_finish.tick(actor,0.58 if state=="closing" else 1.25)
			await frames(2)
			var frame:Image=display.viewport.get_texture().get_image()
			widths.append(frame.get_region(above_roof).get_used_rect().size.x)
			frame.save_png(folder.path_join("polar-"+state+".png"))
		check(widths[0]==0 and widths[1]>widths[2] and widths[2]>0 and widths[3]==0,"halo extends on motion, shrinks while stopping and clears the sky: "+str(widths))
		actor.velocity=Vector2.RIGHT*60
		actor.yr_finish.tick(actor,0.4)
		actor.velocity=Vector2.ZERO
		actor.yr_finish.tick(actor,0.2)
		var partial:float=actor.yr_finish.halo_open
		actor.velocity=Vector2.RIGHT*60
		actor.yr_finish.tick(actor,0.1)
		check(partial>0 and actor.yr_finish.halo_open>partial and actor.yr_finish.halo_open<1,"resuming motion reverses a partially retracted ring")
		actor.velocity=Vector2.ZERO
		actor.yr_finish.tick(actor,1.25)
		for facing in 4:
			display.view_heading=0.12+facing*PI/2
			display._display_heading()
			actor.yr_finish.constellation=0
			actor.yr_finish.first_star=0
			actor.yr_finish.tick(actor,2.0)
			actor.queue_redraw()
			await frames(2)
			var idle:Image=display.viewport.get_texture().get_image()
			actor.yr_finish.fire(0,actor.weapon,Vector2.ZERO)
			actor.yr_finish.fire(1,actor.weapon,Vector2.ZERO)
			actor.yr_finish.tick(actor,0.38)
			actor.queue_redraw()
			await frames(2)
			var stars:Image=display.viewport.get_texture().get_image()
			check(actor.yr_finish.halo_open==1 and actor.yr_finish.constellation>0,"stationary volley shows full orbit together with its stars")
			if facing==0:stars.save_png(folder.path_join("polar-parked-fire.png"))
			var screen:Transform2D=actor.get_global_transform_with_canvas()*Transform2D(Iso.eff_angle(),Iso.up(),0,Vector2.ZERO)
			var roof_y:=int((screen*actor._body_bounds.position).y)
			var sky:=Rect2i(0,0,stars.get_width(),clampi(roof_y-8,0,stars.get_height()))
			check(sky.has_area() and idle.get_region(sky).get_data()!=stars.get_region(sky).get_data(),"constellation appears in the air above the roof at angle "+str(facing))
			check(stars.get_used_rect().position.y>0,"floating halo is fully framed at angle "+str(facing))
	if id=="GGI":
		actor.set_deployed(false,false)
		actor.yr_finish.tick(actor,0.4)
		check(actor.yr_finish.fold==0,"range rig folds back onto the pack")
	pick(picker,"stock")
	check(actor.yr_finish==null,"removing "+skin+" clears its visual state")
	if id=="APOC":check(display.viewport.size==display.SIZE,"unequipping observatory restores normal framing")

func check_dragging(ornament,actor,in_preview:bool) -> void:
	var side:Vector2=Vector2.from_angle(actor.hull_angle)
	for i in 90:
		actor.velocity=side*55
		if not in_preview:actor.position+=actor.velocity/60.0
		ornament._process(1.0/60.0)
	if in_preview:
		actor._ra3_model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await frames(2)
		actor._ra3_model.viewport.get_texture().get_image().save_png(folder.path_join("slag-chain-travel.png"))
		var model=actor._ra3_model
		var old_size:Vector2i=model.viewport.size
		model.viewport.size=Vector2i(1536,1536)
		var chain=ornament.chains[1]
		var pin:Vector2i=Vector2i(model.camera.unproject_position(chain.root.global_position))
		var shoe:Vector2i=Vector2i(model.camera.unproject_position(chain.shoe.global_position))
		var crop:=Rect2i(pin,Vector2i.ONE).expand(shoe).grow(64).intersection(Rect2i(Vector2i.ZERO,model.viewport.size))
		var cold:Image
		for hot:bool in [false,true]:
			actor.special.crush_contact=0.25 if hot else 0.0
			ornament._process(0.0)
			model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			await frames(2)
			var img:Image=model.viewport.get_texture().get_image().get_region(crop)
			img.save_png(folder.path_join("slag-iron-%s.png"%("hot" if hot else "cold")))
			if hot:check(img.get_data()!=cold.get_data(),"grinder heat changes visible pixels on a stationary weight")
			else:cold=img
		model.viewport.size=old_size
	for chain in ornament.chains:
		var tip:Vector3=chain.points[-1]
		var pin:Vector3=chain.points[0]
		var trailing:=Vector2(pin.x-tip.x,pin.z-tip.z)
		check(trailing.dot(side)>0.23,"driving pulls chain behind the vehicle")
		var grounded:=0
		for j in range(1,chain.points.size()):
			if chain.points[j].y<=chain.LINK_CLEARANCE+0.002:grounded+=1
		check(grounded>=2 and absf(tip.y-chain.SHOE_CLEARANCE)<0.001,"several links and the weight drag on the floor")
	var first=ornament.chains[0]
	var old_tip:Vector3=first.points[-1]
	actor.hull_angle+=0.32
	actor._ra3_model.sync_pose()
	actor.velocity=Vector2.ZERO
	ornament._process(1.0/60.0)
	check(old_tip.distance_to(first.points[-1])<0.04,"grounded weight lags the pin during a turn")
	for i in 150:ornament._process(1.0/60.0)
	for chain in ornament.chains:
		var legal:=true
		for j in range(1,chain.points.size()):
			var height:float=chain.SHOE_CLEARANCE if j==chain.LINKS else chain.LINK_CLEARANCE
			legal=legal and chain.points[j].y>=height-0.00001 and absf(chain.points[j-1].distance_to(chain.points[j])-chain.LENGTH)<0.004
		check(legal and chain.points[-1].distance_to(chain.previous[-1])<0.001,"braking leaves a settled chain with connected links above ground")
	if not in_preview:
		actor.position+=Vector2(180,30)
		ornament._process(1.0/60.0)
		check(old_tip.distance_to(first.points[-1])>1.25 and first.points[0].distance_to(first.points[-1])<first.LINKS*first.LENGTH,"teleport resets chain at its new pin")

func check_crown_seat(model,ornament) -> void:
	# Compare against the independently skinned surface vertex, not the socket bounds.
	var mesh:Dictionary=model.source.meshes[0]
	var v:=874
	var seat:=Vector3(mesh.vertices[3*v],mesh.vertices[3*v+1],mesh.vertices[3*v+2])
	var bone:int=mesh.bones[v*4]
	check(mesh.weights[v*4]==1.0 and model.rig.get_bone_name(bone)==ornament.get_parent().native_part,"crown uses the rigid SCYTHE shell bone")
	var actor=model.actor
	for pose in ["idle","walk","deployed"]:
		actor.velocity=Vector2.RIGHT*42 if pose=="walk" else Vector2.ZERO
		actor.special.walker_deployed=pose=="deployed"
		for i in 4:
			model._sample(0.19)
			await frames(1)
			var skinning:Transform3D=model.rig.get_bone_global_pose(bone)*model.rig.get_bone_global_rest(bone).affine_inverse()
			var actual:Vector3=ornament.to_local(model.rig.to_global(skinning*seat))
			check(actual.length()<0.001,"crown stays seated on the animated shell in "+pose)
	actor.special.erase("walker_deployed")
	actor.velocity=Vector2.RIGHT*42
	model._sample(0.0)
	model._sample(0.45)
	await frames(2)

func check_roof_lamps(display) -> void:
	var actor=display.actor
	var art:Dictionary=actor._ra2
	var frame_count:=int(art.facings)
	var seen:={}
	for i in frame_count:
		display.view_heading=Iso.eff_angle()+i*TAU/frame_count
		display._display_heading()
		actor.cargo=0
		actor.queue_redraw()
		await frames(2)
		var empty:Image=display.viewport.get_texture().get_image()
		var facing:int=actor._art_frame
		seen[facing]=true
		var sc:float=actor._art_sc
		var base:Vector2=-RA2Art.anchor(art,actor._art_aframes)*sc+Vector2.DOWN*(actor.radius*0.35-actor._art_lift)
		var pixel:=preload("res://scripts/units/night_shift.gd").roof_pixel(facing,frame_count)
		var src:=RA2Art.src_rect(art,facing)
		check(art.img.get_pixelv(Vector2i(src.position+pixel)).a>0.95,"roof mount hits opaque hull at facing "+str(facing))
		var screen:Transform2D=actor.get_global_transform_with_canvas()*Transform2D(Iso.eff_angle(),Iso.up(),0,Vector2.ZERO)
		var middle:Vector2=base+(pixel+Vector2.UP*2.0)*sc
		for fill in [2,4]:
			actor.cargo=actor.cargo_cap*fill/4.0
			actor.queue_redraw()
			await frames(2)
			var image:Image=display.viewport.get_texture().get_image()
			var correct:=true
			for lamp in 4:
				var sample:=Vector2i(screen*(middle+Vector2.RIGHT*(lamp-1.5)*3.4*sc))
				var changed:=not empty.get_pixelv(sample).is_equal_approx(image.get_pixelv(sample))
				if changed!=(lamp<fill):correct=false
			check(correct,"horizontal roof lamps show left-to-right fill %d at facing %d"%[fill,facing])
			if i%8==0 and fill==4:image.save_png(folder.path_join("night-roof-%02d.png"%i))
	check(seen.size()==32,"roof lamp coverage includes all 32 unique hull sprites")

func check_exhaust_turns(preview,model,ornament) -> void:
	var actor=preview.actor
	var heading:float=actor.hull_angle
	var jet=ornament.lamps[0]
	var nozzle:Vector3=jet.global_position
	var root_pixel:Vector2=model.camera.unproject_position(nozzle)
	var aft:Vector2=model.camera.unproject_position(jet.to_global(Vector3.LEFT))-root_pixel
	var flank:Vector2=model.camera.unproject_position(jet.to_global(Vector3.BACK))-root_pixel
	var across:=aft.normalized().orthogonal()
	if across.dot(flank)<0:across=-across
	var offsets:Array[float]=[]
	for direction:int in [-1,0,1]:
		actor.hull_angle=heading-direction*0.88
		actor.velocity=Vector2.ZERO
		ornament._process(1.0)
		actor.velocity=Vector2.from_angle(actor.hull_angle)*30
		ornament._process(1.0)
		for step in 8:
			actor.hull_angle+=direction*0.11
			actor.velocity=Vector2.from_angle(actor.hull_angle)*30
			ornament._process(1.0/30.0)
		check(is_equal_approx(actor.hull_angle,heading) and signf(ornament.plume_bend)==float(direction),"opposite maneuvers arrive at the same facing with opposite trails")
		for lamp in ornament.lamps:
			lamp.material_override.set_shader_parameter("phase",0.5)
			check(is_equal_approx(float(lamp.material_override.get_shader_parameter("bend")),ornament.plume_bend),"both nozzles receive hull turn")
		model.sync_pose()
		check(jet.global_position.is_equal_approx(nozzle),"turn history does not displace nozzle")
		model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await frames(2)
		var image:Image=model.viewport.get_texture().get_image()
		image.save_png(folder.path_join("phase-turn-%d.png"%direction))
		var weight:=0.0
		var sum:=0.0
		for y in image.get_height():
			for x in image.get_width():
				var offset:=Vector2(x,y)-root_pixel
				if offset.dot(aft.normalized())<aft.length()*0.32:continue
				var c:=image.get_pixel(x,y)
				var blue:=maxf(c.b-c.r-0.08,0.0)*c.a
				sum+=offset.dot(across)*blue
				weight+=blue
		check(weight>1,"rendered blue tail present for steering sample")
		offsets.append(sum/maxf(0.001,weight))
	check(offsets[0]+0.5<offsets[1] and offsets[1]+0.5<offsets[2],"rendered plume bends to opposite sides of straight exhaust: "+str(offsets))
	ornament._process(3.5)
	check(absf(ornament.plume_bend)<0.002,"holding heading straightens the trail")
	actor.velocity=Vector2.ZERO
	actor.hull_angle=PI-0.02
	ornament._process(1.0)
	actor.velocity=Vector2.LEFT*30
	ornament._process(0.2)
	actor.hull_angle=-PI+0.02
	ornament._process(1.0/60.0)
	check(ornament.plume_bend>0 and ornament.plume_bend<0.05,"angle wrap stays a small turn")
	actor.velocity=Vector2.ZERO
	actor.hull_angle=heading
	ornament._process(1.0)
	check(ornament.plume_bend==0,"parking clears previous turn")
	actor.velocity=Vector2.from_angle(heading)*30
	ornament._process(1.0)

func check_phase_house_colors(preview,model,ornament) -> void:
	var owner:=HouseColor.player_id
	var images:Array[Image]=[]
	var gpu_colors:Array[Color]=[]
	for id in ["red","green"]:
		HouseColor.set_player_id(id)
		preview.actor.refresh_house_color()
		for mat in model.materials:mat.set_shader_parameter("house_color",preview.actor._col)
		gpu_colors.append(preview.actor._col)
		model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		preview.actor.queue_redraw()
		await frames(3)
		var shot:Image=preview.viewport.get_texture().get_image()
		images.append(shot)
		shot.save_png(folder.path_join("ion-trail-"+id+".png"))
	for jet in ornament.lamps:jet.hide()
	model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	await frames(3)
	var unlit:Image=preview.viewport.get_texture().get_image()
	var cold_pixels:=0
	var stained:=0
	var painted:=0
	for y in unlit.get_height():
		for x in unlit.get_width():
			var off:=unlit.get_pixel(x,y)
			var red:=images[0].get_pixel(x,y)
			var green:=images[1].get_pixel(x,y)
			if off.a>0.95 and red.r>green.r+0.15 and green.g>red.g+0.10:painted+=1
			if off.a>0.01 or red.a<0.20:continue
			if red.b>red.r+0.08:cold_pixels+=1
			if absf(red.r-green.r)>0.025 or absf(red.g-green.g)>0.025:stained+=1
	check(gpu_colors[0]!=gpu_colors[1] and painted>5,"tank armor uses different native red and green paints")
	check(cold_pixels>=12 and stained==0,"final scene plume stays icy blue across houses (%d blue, %d recolored)"%[cold_pixels,stained])
	HouseColor.set_player_id(owner)
	preview.actor.refresh_house_color()
	for mat in model.materials:mat.set_shader_parameter("house_color",preview.actor._col)

func check_signature(shop,id:String) -> void:
	var styles=MetaProgress.Cosmetics.Styles
	var item:String=styles.EXCLUSIVE_MOUNTS[id]
	var slot:="top" if styles.TOP.has(item) else "tail"
	var picker:OptionButton=shop.slots.find_child(slot,true,false)
	var preview=shop.preview
	var model=preview.actor._ra3_model
	preview._inspect()
	preview.view_heading=Iso.eff_angle()-(0.88 if slot=="tail" else -0.52)
	if item=="slag_chains":preview.view_heading=Iso.eff_angle()-0.22
	preview._display_heading()
	pick(picker,"stock")
	await frames(4)
	var base:Image=model.viewport.get_texture().get_image()
	base.save_png(folder.path_join(item+"-base.png"))
	pick(picker,item)
	await frames(4)
	var installed=model.hull.get_node_or_null("CosmeticMount/"+slot)
	check(installed!=null and installed.find_children("*","MeshInstance3D",true,false).size()>=6,id+" installs exclusive geometry on the selected socket")
	if installed!=null:
		var ornament=installed.get_child(0)
		match item:
			"phase_case":
				preview.actor.velocity=Vector2.RIGHT*20
				ornament._process(1.0)
				check(ornament.lamps[0].visible and ornament.lamps[1].visible,"both phase exhausts light while driving")
				for jet in ornament.lamps:
					check(jet.mesh is QuadMesh and jet.material_override.get_shader_parameter("plume")==ornament.PHASE_PLUME,"future exhaust uses the alpha plume texture")
				var socket:Vector3=ornament.lamps[0].position
				ornament._process(0.10)
				check(ornament.lamps[0].position==socket and ornament.lamps[0].material_override.get_shader_parameter("phase")!=ornament.lamps[1].material_override.get_shader_parameter("phase"),"plume roots stay anchored while flow phases differ")
				preview.actor.velocity=Vector2.ZERO
				ornament._process(0.30)
				check(ornament.lamps[0].visible and not ornament.lamps[1].visible,"second exhaust goes dark before first")
				ornament._process(0.30)
				check(not ornament.lamps[0].visible and not ornament.lamps[1].visible,"both plumes fully disappear at rest")
				preview.actor.velocity=Vector2.RIGHT*20
				ornament._process(1.0)
			"slag_chains":
				preview.actor.special.harpoon_target=preview.actor
				preview.actor.special.crush_contact=0.25
				await check_dragging(ornament,preview.actor,true)
				for chain in ornament.chains:
					check(chain.shoe.material_override.get_shader_parameter("heat")==1.0,"grinder contact heats both weights")
					check(chain.rings[0].material_override.get_shader_parameter("forged")==ornament.SLAG_ATLAS and chain.rings[0].material_override.get_shader_parameter("heat")==0.0,"rusted links keep their cold iron surface")
			"wind_crown":
				await check_crown_seat(model,ornament)
				preview.actor.special.split_enemy=preview.actor
				for side in [1,2]:
					preview.actor.special.split_side_index=side
					ornament._process(0.1)
					for i in 3:
						check(ornament.lamps[i].material_override.get_shader_parameter("enamel").is_equal_approx(ornament.HEAT if i==side else ornament.DARK),"only assigned Reaper vane lights")
		model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await frames(3)
	var equipped:Image=model.viewport.get_texture().get_image()
	equipped.save_png(folder.path_join(item+".png"))
	check(base.get_data()!=equipped.get_data(),id+" exclusive attachment changes rendered pixels")
	if item=="phase_case" and installed!=null:
		var ornament=installed.get_child(0)
		var original_size:Vector2i=model.viewport.size
		model.viewport.size=Vector2i(1280,1280)
		model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await frames(3)
		var focus:=Vector2i(model.camera.unproject_position(ornament.to_global(Vector3(-0.17,0.03,0))))
		var image:Image=model.viewport.get_texture().get_image()
		var detail:=Rect2i(focus-Vector2i(220,140),Vector2i(440,280)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		image.get_region(detail).save_png(folder.path_join("phase-exhaust-detail.png"))
		for jet in ornament.lamps:jet.hide()
		model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await frames(3)
		check(model.viewport.get_texture().get_image().get_region(detail).get_data()!=image.get_region(detail).get_data(),"visible exhaust changes pixels beyond parked nozzle geometry")
		model.viewport.size=Vector2i(256,256)
		# Freeze the hull, keeping the gas phase as the only changing render input.
		var socket:Vector2=model.camera.unproject_position(ornament.lamps[0].global_position)
		var axis:Vector2=model.camera.unproject_position(ornament.lamps[0].to_global(Vector3.LEFT))-socket
		var first:Image
		var far_motion:=0
		var capture_clip:=OS.get_environment("IRON_TIDE_EXHAUST_CLIP")=="1"
		var ticks:=range(64) if capture_clip else [0,3]
		for tick:int in ticks:
			for i in ornament.lamps.size():
				var jet=ornament.lamps[i]
				jet.visible=true
				jet.material_override.set_shader_parameter("thrust",1.0)
				jet.material_override.set_shader_parameter("phase",TAU*tick/64.0+i*1.71)
			model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			await frames(2)
			var sample:Image=model.viewport.get_texture().get_image()
			if capture_clip:sample.save_png(folder.path_join("phase-flow-%02d.png"%tick))
			if tick==0:first=sample
			if tick==3:
				for y in sample.get_height():
					for x in sample.get_width():
						if (Vector2(x,y)-socket).dot(axis.normalized())<axis.length()*0.34:continue
						var now:=sample.get_pixel(x,y)
						var old:=first.get_pixel(x,y)
						if absf(now.b*now.a-old.b*old.a)>0.08:far_motion+=1
		check(far_motion>=10,"advancing blue flow visible beyond the previous plume length (%d pixels)"%far_motion)
		var saved_heading:float=model.hull.rotation.y
		for facing in 8:
			model.hull.rotation.y=facing*PI/4
			for jet in ornament.lamps:
				var tip:Vector2=model.camera.unproject_position(jet.to_global(Vector3.LEFT*0.69))
				check(Rect2(Vector2.ZERO,model.viewport.size).grow(-2).has_point(tip),"no exhaust crop in facing %d at %s"%[facing,tip])
		model.hull.rotation.y=saved_heading
		await check_exhaust_turns(preview,model,ornament)
		model.viewport.size=original_size
		await check_phase_house_colors(preview,model,ornament)

	if item=="rangefinder":
		var old_size:Vector2i=model.viewport.size
		for paint:String in ["stock","ice"]:
			preview.try_outfit("paint",paint)
			var pod=model.hull.get_node("CosmeticMount/top").get_child(0)
			for side:String in ["OpticLeft","OpticRight"]:
				var lens:MeshInstance3D=pod.get_node(side)
				check(lens.material_override.get_shader_parameter("atlas")==pod.OPTIC_ATLAS and is_equal_approx(lens.material_override.get_shader_parameter("ice"),float(paint=="ice")),"rangefinder glass and shell for "+paint+"/"+side)
			check(pod.get_parent().native_part=="B_CHASISANIM","rangefinder remains attached to Mirage chassis")
			model.viewport.size=Vector2i(1536,1536)
			model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			await frames(3)
			var focus:=Vector2i(model.camera.unproject_position(pod.global_position))
			model.viewport.get_texture().get_image().get_region(Rect2i(focus-Vector2i(202,175),Vector2i(404,310))).save_png(folder.path_join("rangefinder-"+paint+"-detail.png"))
		model.viewport.size=old_size
		preview.try_outfit("paint","stock")
	if item=="wind_crown" and installed!=null:
		var crown=installed.get_child(0)
		var fins:Array=crown.find_children("SensorVane","MeshInstance3D",true,false)
		check(fins.size()==3 and crown.get_node("SensorBearing").material_override.get_shader_parameter("plates")==crown.CROWN_ATLAS,"crown bearing uses the sensor texture atlas")
		for fin in fins:
			check(fin.material_override.get_shader_parameter("plates")==crown.CROWN_ATLAS and fin.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].size()>0,"swept vane has mapped enamel panels")
		var old_size:Vector2i=model.viewport.size
		model.viewport.size=Vector2i(1536,1536)
		model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await frames(3)
		var focus:=Vector2i(model.camera.unproject_position(crown.global_position))
		var detail:Image=model.viewport.get_texture().get_image().get_region(Rect2i(focus-Vector2i(180,150),Vector2i(360,300)))
		detail.save_png(folder.path_join("wind-crown-detail.png"))
		model.viewport.size=Vector2i(256,256)
		model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await frames(3)
		var lit_image:Image=model.viewport.get_texture().get_image()
		preview.actor.special.erase("split_enemy")
		crown._process(0.25)
		model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await frames(3)
		var dark_image:Image=model.viewport.get_texture().get_image()
		var bright_pixels:=0
		for y in lit_image.get_height():
			for x in lit_image.get_width():
				var lit:=lit_image.get_pixel(x,y)
				var dark:=dark_image.get_pixel(x,y)
				if lit.r>dark.r+0.18 and lit.g>dark.g+0.08: bright_pixels+=1
		check(bright_pixels>=12,"whole vane is visibly brighter at battle scale (%d pixels)" % bright_pixels)
		lit_image.save_png(folder.path_join("wind-crown-on.png"))
		dark_image.save_png(folder.path_join("wind-crown-off.png"))
		model.viewport.size=old_size
	for other in styles.EXCLUSIVE_MOUNTS:
		if other!=id:check(not MetaProgress.Cosmetics.available(other,slot,item),id+" rejects cross-unit equip on "+other)
	pick(picker,"stock")

func check_exclusive_filter(shop) -> void:
	pick(shop.units,"R3TESLA")
	shop.exclusive_only.button_pressed=true
	var listed:=[]
	for i in shop.units.item_count:listed.append(shop.units.get_item_metadata(i))
	check(listed.has("R3APOC") and listed.has("R3TESLA") and not listed.has("R3HARBINGER") and shop.unit_id=="R3TESLA","RA3 filter excludes shared attachments and keeps the selected unit")
	shop.series.select(1);shop.series.item_selected.emit(1)
	listed.clear()
	for i in shop.units.item_count:listed.append(shop.units.get_item_metadata(i))
	check(listed.has("HARV") and listed.has("SUB") and listed.has("MTNK") and listed.has("HTNK") and not listed.has("E1"),"YR filter includes unit-only skin and weapon looks, excludes generic camo")
	shop.series.select(2);shop.series.item_selected.emit(2)
	pick(shop.units,"NAREFN")
	check(shop.exclusive_only.button_pressed and shop.structure.visible,"filter stays active across categories and includes refinery skin")
	shop.series.select(0);shop.series.item_selected.emit(0)
	shop.exclusive_only.button_pressed=false
	pick(shop.units,"R3HARBINGER")
	shop.exclusive_only.button_pressed=true
	check(shop.preview.actor.unit_id==shop.unit_id and shop.unit_id!="R3HARBINGER","filtered-out selection switches its visible preview")
	shop.exclusive_only.button_pressed=false

func check_cosmetic_shop() -> void:
	var cosmetics = MetaProgress.Cosmetics
	var slots_to_check := {"paint":cosmetics.Styles.PAINT,"top":cosmetics.Styles.TOP,"wing":cosmetics.Styles.WINGS,"tail":cosmetics.Styles.TAILS,"track":cosmetics.Styles.TRACKS,"skin":cosmetics.Styles.SKINS}
	for slot in slots_to_check:
		for item in slots_to_check[slot]:
			check(not cosmetics.effect_text("",slot,item).is_empty(),"appearance description "+slot+"/"+item)
	for id in cosmetics.WEAPON_FX:
		check(not cosmetics.effect_text(id,"weapon_fx",cosmetics.WEAPON_FX[id]).is_empty(),"weapon description "+id)
	for id in cosmetics.EXCLUSIVE_SKINS:
		check(not cosmetics.effect_text(id,"skin",cosmetics.EXCLUSIVE_SKINS[id]).is_empty(),"exclusive description "+id)
	check(cosmetics.effect_text("HARV","skin","night_shift")!=cosmetics.effect_text("NAREFN","skin","night_shift"),"night shift descriptions reflect each unit's lamps")
	var original:=JSON.stringify(MetaProgress.to_dict())
	var legacy:=MetaProgress.to_dict().duplicate(true)
	legacy.owned_cosmetics={"woodland":true}
	legacy.unlocked_technologies=[]
	legacy.currency.diamonds=6000
	legacy.stats.erase("appearance_wins")
	legacy.stats.battles_won=36
	legacy.unit_cosmetics={"HARV":{"skin":"woodland"},"MTNK":{"skin":"winter"},"R3TESLA":{"wing":"angel","decal":"star","ornament":"crystal"},"R3APOC":{"decal":"diamond","body":"ice","weapon":"wine"},"R3MIRAGE":{"weapon":"sand"},"R3FUTURE":{"ornament":"beacon"}}
	var file:=FileAccess.open(MetaProgress.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy));file.close()
	MetaProgress.load_save()
	check(MetaProgress.appearance_wins()==36 and MetaProgress.owned_cosmetics.size()==9 and MetaProgress.cosmetic_style("HARV").is_empty() and not MetaProgress.cosmetic_owned("angel") and MetaProgress.cosmetic_style("MTNK").is_empty(),"36 historical wins grant first nine without inventing difficulty wins")
	check(MetaProgress.cosmetic_style("R3APOC")=={"paint":"ice"} and MetaProgress.cosmetic_style("R3MIRAGE").is_empty(),"old hull paint wins conflicts and weapon-only paint is retained")
	check(MetaProgress.set_cosmetic("R3APOC","paint","ice") and MetaProgress.set_cosmetic("SHK","weapon_fx","spectrum"),"earned paint shared across slots and spectrum across series")
	check(MetaProgress.cosmetic_style("R3TESLA")=={"top":"crystal"} and not MetaProgress.cosmetic_owned("star"),"old double slot equips ornament and keeps badge ownership")
	check(MetaProgress.cosmetic_style("R3APOC")=={"paint":"ice"} and MetaProgress.cosmetic_style("R3FUTURE").is_empty(),"single legacy decorations retain their slot selection")
	var shop=load("res://scenes/paint.tscn").instantiate()
	add_child(shop)
	var exclusive_tops:={"R3MIRAGE":"rangefinder","R3REAPER":"wind_crown"}
	for id in exclusive_tops:
		pick(shop.units,id)
		pick(shop.slots.find_child("top",true,false),exclusive_tops[id])
	for id in exclusive_tops:
		pick(shop.units,id)
		var selector:OptionButton=shop.slots.find_child("top",true,false)
		check(selector.get_item_metadata(selector.selected)==exclusive_tops[id],"switching unit keeps its own top "+id)
	shop.free()
	MetaProgress.load_save()
	shop=load("res://scenes/paint.tscn").instantiate()
	add_child(shop)
	for id in exclusive_tops:
		pick(shop.units,id)
		var selector:OptionButton=shop.slots.find_child("top",true,false)
		var mount=shop.preview.actor._ra3_model.hull.get_node_or_null("CosmeticMount/top")
		check(selector.get_item_metadata(selector.selected)==exclusive_tops[id] and mount!=null and mount.get_child(0).style==exclusive_tops[id],"reopened workshop restores exclusive top picker and model "+id)
	pick(shop.units,"R3TESLA")
	var top=shop.slots.find_child("top",true,false)
	check(top.item_count==2 and top.get_item_metadata(top.selected)=="crystal","merged selector shows migrated choice, four decorations and empty option")
	for value in ["crystal","stock"]:
		pick(top,value)
		check(MetaProgress.cosmetic_style("R3TESLA").get("top","stock")==value,"switch or clear top decoration "+value)
	MetaProgress.load_save()
	check(MetaProgress.cosmetic_style("R3TESLA").is_empty(),"clearing merged slot survives reload")
	pick(shop.slots.find_child("wing",true,false),"angel")
	check(not shop.slots.find_child("Buy_wing",true,false).visible and "还差 4 胜" in shop.status.text and not MetaProgress.buy_cosmetic("R3TESLA","wing","angel"),"locked milestone shows remaining wins and has no purchase route")
	for slot in ["wing","tail","paint","top"]:
		check(shop.slots.find_child("Preview_"+slot,true,false)==null,"no duplicate preview button for "+slot)
	var paint := shop.slots.find_child("paint",true,false) as OptionButton
	check(paint.item_count==2 and paint.get_item_metadata(0)=="stock" and paint.get_item_metadata(1)=="ice","whole-model paint only lists original and ice")
	var credits_before:=MetaProgress.balance("diamonds")
	pick(shop.units,"R3APOC")
	pick(shop.slots.find_child("track",true,false),"chevron_track")
	shop.slots.find_child("Preview_track",true,false).pressed.emit()
	check(shop.tread_strip.visible and shop.tread_strip.tread==VehicleTracks.CHEVRON and shop.preview.track_sample.visible and shop.preview.track_sample.tread==VehicleTracks.CHEVRON and not MetaProgress.cosmetic_owned("chevron_track") and not MetaProgress.cosmetic_style("R3APOC").has("track"),"research-locked tread previews without entitlement or equip")
	await frames(5)
	shop.preview.viewport.get_texture().get_image().save_png(folder.path_join("locked-tread.png"))
	shop.preview._process(1.5)
	var sample=shop.preview.track_sample
	var last_print:=Vector2(-sample.rear-7*VehicleTracks.STEP-sample.phase,sample.spacing)
	check(is_instance_valid(shop.preview.track_arrow) and shop.preview.track_arrow.position.is_equal_approx(sample.to_global(last_print)),"parked preview arrow is centered on the last printed chevron")
	shop.preview.view_heading+=PI/2
	shop.preview._display_heading()
	check(shop.preview.track_arrow.position.is_equal_approx(sample.to_global(last_print)),"turning the preview keeps the arrow on its footprint")
	var track_btn=shop.slots.find_child("Preview_track",true,false)
	track_btn.pressed.emit()
	check(not shop.preview.track_sample.visible and not shop.tread_strip.visible and not shop.tread_strip.is_processing() and not is_instance_valid(shop.preview.track_arrow),"stop preview clears both surfaces without changing selection")
	track_btn.pressed.emit()
	pick(shop.slots.find_child("track",true,false),"stock")
	check(not shop.preview.track_sample.visible and shop.preview.track_sample.tread==null and not shop.tread_strip.visible and shop.tread_strip.tread==null,"restore original clears both samples")
	shop.preview.refresh_outfit()
	check(not shop.preview.track_sample.visible,"refreshing another cosmetic does not revive a dismissed sample")
	shop.series.select(1);shop._list_units();pick(shop.units,"MTNK")
	pick(shop.slots.find_child("skin",true,false),"cobalt_porcelain")
	check(shop.slots.find_child("Preview_skin",true,false)==null,"skin is previewed directly from picker")
	check(shop.preview.actor.tank_finish.skin==4 and not MetaProgress.cosmetic_style("MTNK").has("skin") and not MetaProgress.cosmetic_owned("cobalt_porcelain"),"locked skin previews with dynamic armor")
	shop.series.select(2);shop._list_units();pick(shop.units,"NAREFN")
	pick(shop.slots.find_child("skin",true,false),"night_shift")
	check(shop.slots.find_child("EffectText_skin",true,false).text.contains("坡道") and shop.slots.find_child("skin",true,false).tooltip_text.contains("卸货"),"locked refinery preview and hover show the ramp effect")
	check(shop.structure.material.get_shader_parameter("unit_skin")==3 and not MetaProgress.cosmetic_owned("night_shift") and MetaProgress.balance("diamonds")==credits_before,"building skin trial never charges")
	shop.series.select(1);shop._list_units();pick(shop.units,"MTNK")
	check(shop.preview.actor.tank_finish==null,"switching unit clears temporary outfit")
	# A purchase made before this version remains usable even below its new threshold.
	legacy.owned_cosmetics={"crystal":true}
	legacy.stats.battles_won=0
	file=FileAccess.open(MetaProgress.SAVE_PATH,FileAccess.WRITE);file.store_string(JSON.stringify(legacy));file.close()
	MetaProgress.load_save()
	check(MetaProgress.appearance_wins()==0 and MetaProgress.cosmetic_owned("crystal") and not MetaProgress.cosmetic_owned("ice"),"older paid attachments survive without adding wins")
	check(not MetaProgress.buy_cosmetic("SHK","weapon_fx","spectrum") and not MetaProgress.buy_cosmetic("R3TESLA","weapon_fx","spectrum"),"shared arc cannot be bought from either series")
	# A second art ID with the same workshop name inherits the same ownership.
	var catalog=MetaProgress.Cosmetics
	var old_name:String=catalog.display_name("ice")
	catalog.names_by_id.ice=catalog.display_name("crystal")
	check(MetaProgress.set_cosmetic("R3APOC","paint","ice") and not MetaProgress.buy_cosmetic("R3APOC","paint","ice"),"same name across IDs shares existing ownership")
	MetaProgress.load_save()
	check(MetaProgress.cosmetic_style("R3APOC").get("paint")=="ice","same-name equipment survives reload")
	catalog.names_by_id.ice=old_name
	check(not MetaProgress.buy_cosmetic("MTNK","skin","winter") and not MetaProgress.buy_cosmetic("MTNK","wing","angel"),"difficulty and slot restrictions")
	var tmp:=MetaProgress.SAVE_PATH+".tmp"
	DirAccess.make_dir_absolute(tmp)
	check(not MetaProgress.buy_cosmetic("HARV","skin","night_shift") and MetaProgress.balance("diamonds")==6000 and not MetaProgress.cosmetic_owned("night_shift"),"failed YR purchase rolls back")
	DirAccess.remove_absolute(tmp)
	shop.series.select(1);shop.series.item_selected.emit(1);pick(shop.units,"HARV")
	pick(shop.slots.find_child("skin",true,false),"night_shift")
	check(shop.slots.find_child("Buy_skin",true,false).visible and MetaProgress.balance("diamonds")==6000,"selecting priced YR skin does not spend")
	shop.slots.find_child("Buy_skin",true,false).pressed.emit()
	check(MetaProgress.balance("diamonds")==0 and MetaProgress.set_cosmetic("NAREFN","skin","night_shift") and not MetaProgress.buy_cosmetic("HARV","skin","night_shift"),"paid YR skin shared with refinery without rebilling")
	MetaProgress.grant("diamonds",12000)
	check(not MetaProgress.buy_cosmetic("MTNK","skin","ember_steel"),"exclusive skin rejected for the wrong tank")
	for entry in [["MTNK","cobalt_porcelain"],["HTNK","ember_steel"]]:
		var credits:=MetaProgress.balance("diamonds")
		check(MetaProgress.buy_cosmetic(entry[0],"skin",entry[1]) and MetaProgress.balance("diamonds")==credits-6000,"tank skin purchase "+entry[1])
		check(MetaProgress.set_cosmetic(entry[0],"skin",entry[1]) and not MetaProgress.buy_cosmetic(entry[0],"skin",entry[1]),"tank skin equips without repeat billing")
	MetaProgress.load_save()
	check(MetaProgress.cosmetic_style("HTNK").skin=="ember_steel" and MetaProgress.cosmetic_style("MTNK").skin=="cobalt_porcelain","both purchased tank outfits persist")
	check(not MetaProgress.buy_cosmetic("FLAKT","weapon_fx","pixel_blast"),"insufficient balance cannot buy another paid look")
	MetaProgress.grant("diamonds",18000)
	for row in [["APOC","molten_duet"],["CLEG","time_fracture"],["V3","reentry"]]:
		pick(shop.units,row[0])
		pick(shop.slots.find_child("weapon_fx",true,false),row[1])
		var credits:=MetaProgress.balance("diamonds")
		shop.slots.find_child("Buy_weapon_fx",true,false).pressed.emit()
		check(MetaProgress.balance("diamonds")==credits-6000 and MetaProgress.cosmetic_style(row[0]).get("weapon_fx")==row[1],"purchase and equip signature "+row[1])
		shop.fx_button.pressed.emit()
		check(shop.fx_host.get_child(0).get_script()==Effects.Looks.Signature,"workshop trial "+row[1])
	check(MetaProgress.set_cosmetic("DRED","weapon_fx","reentry") and not MetaProgress.buy_cosmetic("DRED","weapon_fx","reentry"),"Dreadnought shares the V3 purchase")
	MetaProgress.load_save()
	check(MetaProgress.cosmetic_style("DRED").get("weapon_fx")=="reentry","Dreadnought shared equipment persists")
	MetaProgress.load_save()
	check(MetaProgress.cosmetic_owned("night_shift") and MetaProgress.balance("diamonds")==0,"paid YR skin persisted")
	shop.free()
	for row in [[1,true,false,false],[3,false,false,false],[3,true,true,false],[3,true,false,true],[2,true,false,false],[3,true,false,false]]:
		var mode:=MatchRules.RA2 if int(row[0])==2 else MatchRules.EXTENDED
		BattleRequest.configure_skirmish(mode,{"difficulty":row[0]})
		var scene=load("res://scenes/battle.tscn").instantiate()
		add_child(scene);scene.process_mode=Node.PROCESS_MODE_DISABLED
		var wins_before:=MetaProgress.appearance_wins()
		scene.battle.end_battle(row[1],row[2],row[3])
		var counts:bool=row[1] and not row[2] and not row[3]
		check(MetaProgress.appearance_wins()==wins_before+int(counts),"qualifying wins count in both modes "+str(row))
		preload("res://scripts/world/production_counts.gd").settle(scene.battle,true)
		check(MetaProgress.appearance_wins()==wins_before+int(counts),"duplicate settlement never grants an extra win")
		var eligible:bool=row[1] and not row[2] and not row[3] and row[0]>=2
		check(not MetaProgress.owned_cosmetics.has("woodland") and MetaProgress.cosmetic_owned("winter")== (eligible and row[0]==3),"difficulty rewards from real battle settlement "+str(row))
		scene.free()
	MetaProgress.owned_cosmetics.erase("woodland");MetaProgress.owned_cosmetics.erase("winter")
	var before:=MetaProgress.balance("diamonds")
	check(MetaProgress.award_victory_skins(3)==PackedStringArray(["winter"]) and MetaProgress.award_victory_skins(3).is_empty() and MetaProgress.balance("diamonds")==before,"first brutal win awards snow camouflage once for free")
	MetaProgress.load_save()
	check(MetaProgress.set_cosmetic("MTNK","skin","winter") and MetaProgress.set_cosmetic("HARV","skin","winter") and not MetaProgress.set_cosmetic("HARV","skin","woodland"),"difficulty rewards shared and persisted")
	MetaProgress.owned_cosmetics={}
	var threshold_values:=[3,5,8,12,16,20,25,30,40,50]
	var expected:=["ice","phase_case","slag_chains","rangefinder","wind_crown","crystal","spectrum","blue_arc","angel","demon"]
	for i in expected.size():
		MetaProgress.stats.appearance_wins=threshold_values[i]-1
		check(MetaProgress.grant_win_milestones().is_empty(),"no early milestone "+expected[i])
		MetaProgress.stats.appearance_wins=threshold_values[i]
		check(MetaProgress.grant_win_milestones()==PackedStringArray([expected[i]]) and MetaProgress.grant_win_milestones().is_empty(),"grant each milestone exactly once "+expected[i])
	MetaProgress.unlocked_technologies.clear()
	MetaProgress.owned_cosmetics.erase("amber_tail")
	MetaProgress.owned_cosmetics.erase("chevron_track")
	MetaProgress.grant("cores",1000)
	var nodes:=["repair_all","refinery_miner","structure_queue","bunker_optics_1","unit_queue_1"]
	for i in nodes.size():
		check(MetaProgress.research_technology(nodes[i]),"buy distinct technology "+nodes[i])
		check(not MetaProgress.cosmetic_owned("amber_tail") and MetaProgress.cosmetic_owned("chevron_track")== (i>=4),"3/5 research reward threshold "+str(i+1))
	MetaProgress.set_effect_enabled("tech","repair_all","",false)
	check(MetaProgress.researched_count()==5 and not MetaProgress.research_technology("repair_all"),"disabled or duplicate research does not change milestone count")
	check(not MetaProgress.set_cosmetic("R3HARBINGER","tail","amber_tail") and not MetaProgress.set_cosmetic("R3HARBINGER","track","chevron_track"),"aircraft supports rear marker but no ground prints")
	check(MetaProgress.set_cosmetic("R3APOC","track","chevron_track") and not MetaProgress.set_cosmetic("R3REAPER","track","chevron_track"),"tire skin requires tracked chassis")
	var old_tech:=MetaProgress.to_dict().duplicate(true)
	old_tech.unit_cosmetics.R3REAPER = {"track":"chevron_track","paint":"ice"}
	old_tech.owned_cosmetics.erase("amber_tail");old_tech.owned_cosmetics.erase("chevron_track")
	file=FileAccess.open(MetaProgress.SAVE_PATH,FileAccess.WRITE);file.store_string(JSON.stringify(old_tech));file.close()
	MetaProgress.load_save()
	check(MetaProgress.cosmetic_style("R3REAPER")=={"paint":"ice"},"old incompatible wheel marks cleared without losing paint")
	check(not MetaProgress.cosmetic_owned("amber_tail") and MetaProgress.cosmetic_owned("chevron_track") and MetaProgress.cosmetic_style("R3APOC").track=="chevron_track","old research grants retroactive rewards before outfit restore")
	file=FileAccess.open(MetaProgress.SAVE_PATH,FileAccess.WRITE)
	file.store_string(original);file.close();MetaProgress.load_save()
