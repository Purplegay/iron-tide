extends "res://tests/logistics_regression.gd"

const AirportDock = preload("res://scripts/buildings/airport_dock.gd")

func exercise_mode(mode: String) -> void:
	if mode != MatchRules.EXTENDED: return
	setup_logistics_scene(mode, "美国")
	if battle.fog != null: battle.fog.free(); battle.fog = null
	var b = battle._place_building("GAPILE", "ally", Vector2(2050,2050), true)
	b._buildup_play = -1.0
	var center: Vector2 = b.depth_anchor()
	battle.camera.position = center
	battle.camera.zoom = Iso.cam_zoom(2)
	battle.camera.reset_smoothing()
	battle.camera.force_update_scroll()
	var u = battle.spawn_unit("MTNK", "ally", center)
	for sign_y in [-1,1]:
		var direction := Vector2.DOWN.rotated(Iso.eff_angle()) * float(sign_y)
		u.position = center
		while Geometry2D.is_point_in_polygon(u.position-b.position,b.footprint_poly()):
			u.position += direction
		u.position += direction*3
		battle._update_depth_order()
		var front: bool = sign_y == 1
		var label := "front" if front else "rear"
		check((u.z_index>b.z_index) if front else (u.z_index<b.z_index),label+" ground depth", [u.z_index,b.z_index])
		if DisplayServer.get_name() != "headless":
			var rect := Rect2i(Vector2i(u.get_global_transform_with_canvas().origin)-Vector2i(100,110),Vector2i(200,160))
			var both := await capture_crop(rect)
			both.save_png(output_dir.path_join(label+".png"))
			u.hide()
			var building_only := await capture_crop(rect)
			b.hide()
			var empty := await capture_crop(rect)
			u.show()
			var unit_only := await capture_crop(rect)
			b.show()
			var top_unit := 0
			var top_building := 0
			for y in rect.size.y:
				for x in rect.size.x:
					var a := building_only.get_pixel(x,y)
					var t := unit_only.get_pixel(x,y)
					var bg := empty.get_pixel(x,y)
					if a == bg or t == bg or a == t: continue
					var actual := both.get_pixel(x,y)
					if actual == a: top_building += 1
					elif actual == t: top_unit += 1
			check(top_unit>top_building and top_unit>20 if front else top_building>top_unit and top_building>20,label+" opaque overlap pixels",[top_unit,top_building])
	var rear:=center-Vector2.DOWN.rotated(Iso.eff_angle())*75
	var infantry = battle.spawn_unit("GGI","ally",rear)
	check(infantry.deploy(),"Guardian GI deploys behind barracks")
	battle._update_depth_order()
	check(infantry.z_index<b.z_index,"deployed Guardian GI stays behind barracks")
	var depot = battle._place_building("GADEPT","ally",center+Vector2(350,0),true)
	u.position = depot.depth_anchor()
	u.repairing = true
	u.repair_depot = depot
	u.special.repair_stage = "inside"
	var airport = battle._place_building("GAAIRC","ally",center+Vector2(700,0),true)
	var plane = battle.spawn_unit("ORCA","ally",AirportDock.production_point(airport,"ORCA"),airport)
	battle._update_depth_order()
	check(u.z_index>depot.z_index,"tank on repair pad is visible")
	check(plane.logistics.air_state=="parked" and plane.z_index>airport.z_index,"parked aircraft is above its airport")
	plane.logistics.air_lift=100
	battle._update_depth_order()
	check(plane.z_index==DepthLayers.AIR,"airborne aircraft clears buildings")

	var old_yaw:=Iso.USE_YAW
	var old_mirror:=Iso.MIRROR
	u.repairing=false
	for settings in [[true,true],[false,false]]:
		Iso.USE_YAW=settings[0]
		Iso.MIRROR=settings[1]
		var near_side:=Vector2.DOWN.rotated(Iso.eff_angle())*80
		u.position=center-near_side
		battle._update_depth_order()
		check(u.z_index<b.z_index,"rear depth for alternate projection "+str(settings))
		u.position=center+near_side
		battle._update_depth_order()
		check(u.z_index>b.z_index,"front depth for alternate projection "+str(settings))
	Iso.USE_YAW=old_yaw
	Iso.MIRROR=old_mirror
	screen.free()
	await get_tree().process_frame

func capture_crop(rect:Rect2i) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return stage.get_texture().get_image().get_region(rect)
