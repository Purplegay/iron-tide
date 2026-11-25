extends "res://tests/allied_abilities_regression.gd"

func exercise_mode(mode:String) -> void:
	if mode==MatchRules.RA2: return
	BattleRequest.configure_skirmish(mode,{"map_size":3200,"starting_funds":20000,"country":"美国","fog_of_war":true})
	screen=load("res://scenes/battle.tscn").instantiate(); stage.add_child(screen)
	battle=screen.battle; screen.process_mode=Node.PROCESS_MODE_DISABLED
	battle.camera.position=Vector2(1800,1800); battle.camera.zoom=Iso.cam_zoom(2)
	battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
	if battle.fog!=null: battle.fog.free(); battle.fog=null
	var tracks:=VehicleTracks.new(); tracks.name="VehicleTracks"; tracks.world=battle
	tracks.z_as_relative=false; tracks.z_index=DepthLayers.DECAL+1
	battle.add_child(tracks)
	tracks.add_mark(Vector2(1800,1800),0,false)
	tracks.add_mark(Vector2(1800,1820),PI/3,true)
	tracks._process(VehicleTracks.UPDATE_INTERVAL)
	check(tracks._batches.size()==2 and tracks.get_child_count()==2,"two GPU batches instead of one canvas command per mark")
	for i in 2:
		var batch:MultiMeshInstance2D=tracks._batches[i]
		check(batch.multimesh.visible_instance_count==1,"separate native and RA2 track batches")
		check(batch.multimesh.instance_count==VehicleTracks.LIMIT,"fixed buffer capacity")
		check(batch.multimesh.get_instance_transform_2d(0).is_equal_approx(tracks.marks[i].transform),"position and turn angle retained")
		check(absf(batch.multimesh.get_instance_color(0).a-0.8)<1.0/255.0,"initial opacity retained")
	check(tracks._batches[0].texture==tracks.tank_texture and tracks._batches[1].texture==tracks.tire_texture,"original textures retained")
	tracks.clock=15.5; tracks._refresh_batches()
	check(absf(tracks._batches[0].multimesh.get_instance_color(0).a-0.4)<1.0/255.0,"five-second end fade midpoint")
	tracks.add_mark(Vector2(-20000,-20000),0,false); tracks._refresh_batches()
	check(tracks._batches[0].multimesh.visible_instance_count==1,"offscreen records not submitted")
	battle.fog=preload("res://scripts/world/fog_of_war.gd").new()
	battle.add_child(battle.fog); battle.fog.setup(battle)
	var cells:PackedByteArray=battle.fog.visible_cells["ally"]
	cells.fill(0); battle.fog.visible_cells["ally"]=cells
	tracks._refresh_batches()
	check(tracks._batches.all(func(b):return b.multimesh.visible_instance_count==0),"fog hides existing track instances")
	cells.fill(1); battle.fog.visible_cells["ally"]=cells
	tracks._refresh_batches()
	check(tracks._batches[1].multimesh.visible_instance_count==1,"visible terrain restores retained tracks")
	var old_owned:=MetaProgress.owned_cosmetics.duplicate()
	var old_styles:=MetaProgress.unit_cosmetics.duplicate(true)
	MetaProgress.owned_cosmetics.chevron_track=true
	var reaper=actor("R3REAPER","ally",Vector2(1800,1800))
	check(not MetaProgress.set_cosmetic("R3REAPER","track","chevron_track"),"walker cannot equip tire skin")
	var before := tracks.marks.size()
	MetaProgress.unit_cosmetics["R3REAPER"] = {"track":"chevron_track"}
	VehicleTracks.sample(reaper,0.1);reaper.position.x+=12;VehicleTracks.sample(reaper,0.1)
	check(tracks.marks.size()==before,"even a stale walker outfit cannot create tire marks")
	var tank=actor("R3APOC","ally",Vector2(1800,1800))
	check(MetaProgress.set_cosmetic("R3APOC","track","chevron_track"),"tracked chassis accepts tireskin")
	VehicleTracks.sample(tank,0.1);tank.position.x+=12;VehicleTracks.sample(tank,0.1)
	tracks._refresh_batches()
	check(tracks._batches.size()==3 and tracks._batches[2].texture==VehicleTracks.CHEVRON and tracks._batches[2].multimesh.visible_instance_count==4,"equipped tank writes two paired chevrons into dedicated batch")
	# The tank drives out, turns and doubles back. The farthest footprint
	# at the stop belongs to the bend, not to either end of the route.
	tank.hull_angle = PI/2
	tank.position.y+=65
	VehicleTracks.sample(tank,0.15)
	tank.hull_angle = -PI/2
	tank.position.y-=60
	VehicleTracks.sample(tank,0.15)
	var expected: Dictionary = {}
	for mark: Dictionary in tracks.marks:
		if not mark.chevron: continue
		if expected.is_empty() or tank.position.distance_to(mark.position) >= tank.position.distance_to(expected.position):
			expected = mark
	check(not expected.is_empty() and expected.position.y>tank.position.y+45,"fixture farthest point is on the bend")
	tracks.add_mark(tank.position+Vector2(300,0),0,true,true,reaper.get_instance_id())
	tracks.add_mark(tank.position+Vector2(280,0),0,true,true,tank.get_instance_id())
	tracks.marks.back().born=tracks.clock-VehicleTracks.LIFETIME
	var before_stop := tracks.get_child_count()
	VehicleTracks.sample(tank,0.1)
	check(tracks.get_child_count()==before_stop,"brief movement gap does not plant an arrow")
	VehicleTracks.sample(tank,0.2)
	var arrow=tracks.get_child(-1)
	check(arrow.get_script()==VehicleTracks.Arrow and arrow.position.is_equal_approx(expected.position) and is_equal_approx(arrow.heading,expected.angle),"one arrow at end of chevron trail")
	VehicleTracks.sample(tank,1.0)
	check(tracks.get_child_count()==before_stop+1,"idle tank does not repeat arrows")
	arrow._process(VehicleTracks.Arrow.LIFE)
	check(arrow.is_queued_for_deletion(),"parked arrow expires")
	var count:=tracks.marks.size()
	reaper.special.walker_jump={};reaper.position.x+=12;VehicleTracks.sample(reaper,0.1)
	check(tracks.marks.size()==count,"airborne jump never produces wheel prints")
	MetaProgress.unit_cosmetics=old_styles;MetaProgress.owned_cosmetics=old_owned;MetaProgress.save()
	tracks._process(VehicleTracks.LIFETIME)
	var after_expiry:=tracks.get_child_count()
	tracks.plant_arrow(tank)
	check(tracks.get_child_count()==after_expiry,"no arrow when all owned prints are gone")
	check(tracks.marks.is_empty() and tracks._batches.all(func(b):return b.multimesh.visible_instance_count==0),"expiry clears both batch counts")
	var updates:=tracks.batch_updates
	for frame in 60:
		for i in 30: tracks.add_mark(Vector2(1750+i*5,1750+frame*2),frame*0.02,i%2==0)
		tracks._process(1.0/60)
	check(tracks.marks.size()==VehicleTracks.LIMIT,"global mark cap preserved")
	check(tracks.batch_updates-updates>0 and tracks.batch_updates-updates<=5,"new marks upload at most five times per second without dropping samples")
	check(tracks._batches[0].multimesh.visible_instance_count+tracks._batches[1].multimesh.visible_instance_count==VehicleTracks.LIMIT,"all 1600 visible marks survive batching")
	battle.fog.visible=false # Inspect marks without the stale fog texture from the injected mask.
	for f in 3: await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join("batched-tracks.png"))
	battle.fog.rebuild()
	var saved:=BattleSaves.save_slot(battle,"quick"); var loaded:=BattleSaves.read_slot("quick")
	check(saved.ok and loaded.ok,"real save entry succeeds with batched tracks",saved.get("message"))
	if loaded.ok: BattleSaves.Snapshot.new().restore(battle,loaded.snapshot)
	check(battle.get_node_or_null("VehicleTracks")==null,"restore removes old GPU batches and marks")
	screen.free(); Music.stop(); Ra2Sfx.stop_all()
