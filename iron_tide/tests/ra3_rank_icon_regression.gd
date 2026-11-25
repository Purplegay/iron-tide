extends "res://tests/allied_abilities_regression.gd"

const Indicator = preload("res://scripts/ui/veterancy_indicator.gd")

class RankCanvas extends Node2D:
	var actors: Array = []
	func _draw() -> void:
		for unit in actors:
			preload("res://scripts/ui/veterancy_indicator.gd").paint(unit, self)

func exercise_mode(mode: String) -> void:
	if mode == MatchRules.RA2: return
	setup_logistics_scene(mode, "美国")
	for node in battle.units + battle.buildings: node.free()
	battle.units.clear(); battle.buildings.clear()
	if battle.fog != null: battle.fog.free(); battle.fog = null
	if DisplayServer.get_name()=="headless":
		await check_rank_surfaces()
		screen.free()
		await get_tree().process_frame
		return
	# No HUD selection and no test-owned Texture2D: either would accidentally
	# keep the rank resource alive and mask a dangling canvas texture RID.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 160); viewport.transparent_bg = true
	viewport.disable_3d = true; viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var canvas := RankCanvas.new(); viewport.add_child(canvas)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for rank in [1, 2, 3]:
		var unit = actor("R3MIRAGE", "ally", Vector2(100 + rank * 100, 120))
		unit._grant_veteran(rank, false)
		canvas.actors.append(unit)
	canvas.queue_redraw()
	for frame in 5: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check_icons(viewport, canvas, "unselected")
	# Retained draw commands must remain valid without another _draw call.
	for frame in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check_icons(viewport, canvas, "retained")
	var rank_ref: WeakRef = weakref(Ra3Mirage.rank_texture(1))
	await get_tree().process_frame
	check(rank_ref.get_ref() != null, "rank texture stays alive after local references are released")
	viewport.free(); screen.free()
	await get_tree().process_frame

func check_icons(viewport: SubViewport, canvas: RankCanvas, label: String) -> void:
	var actual := viewport.get_texture().get_image()
	actual.save_png(output_dir.path_join(label + ".png"))
	for unit in canvas.actors:
		var rank: int = unit.veteran_level
		# Decode source pixels as Image, never a Texture2D held by this test.
		var expected := Image.load_from_file("res://assets/ra3/mirage/uprising/rank%d.png" % rank)
		expected.resize(roundi(expected.get_width()*0.75),roundi(expected.get_height()*0.75),Image.INTERPOLATE_NEAREST)
		var origin := Vector2i((Indicator.screen_center(unit, canvas) - Vector2(expected.get_size()) * 0.5).floor())
		var bad_alpha := 0
		var gold := 0
		for y in expected.get_height():
			for x in expected.get_width():
				var pixel := actual.get_pixelv(origin + Vector2i(x, y))
				if absf(pixel.a - expected.get_pixel(x, y).a) > 0.02: bad_alpha += 1
				if pixel.a > 0.8 and pixel.r > 0.7 and pixel.g > 0.4 and pixel.b < 0.4: gold += 1
		check(bad_alpha == 0, "%s rank%d retains original transparent silhouette" % [label, rank], bad_alpha)
		check(gold >= 8, "%s rank%d draws gold badge rather than a white rectangle" % [label, rank], gold)

func check_rank_surfaces() -> void:
	for id in ["R3APOC","R3TESLA","R3REAPER","R3MIRAGE","R3FUTURE","R3HARBINGER","MTNK"]:
		var unit=actor(id,"ally",Vector2(1400,1400))
		battle.select_unit(unit,false)
		battle._emit_selection()
		var hud=screen.hud
		var tile=hud._strip_icons[0].icon
		var cap:=2 if id=="MTNK" else 3
		for rank in range(cap+1):
			unit._grant_veteran(rank,false)
			hud._refresh_veterancy_live(unit)
			hud._refresh_strip_live()
			var state:=Indicator.state(unit)
			if rank==0:
				check(state.is_empty() and not hud.sel_rank_icon.visible and tile.rank_badge==null,id+" recruit has no badge")
				continue
			var path:String
			if id=="MTNK":
				path="res://assets/ra2/pips/"+("veteran.png" if rank==1 else "elite.png")
			else:
				var folder:="soviet" if id in ["R3APOC","R3TESLA","R3REAPER"] else "mirage/uprising"
				path="res://assets/ra3/%s/rank%d.png"%[folder,rank]
			check(state.badge.resource_path==path and hud.sel_rank_icon.texture==state.badge and tile.rank_badge==state.badge,"%s rank %d agrees across battlefield, selection details and portrait"%[id,rank])
			if rank==2 and cap==3:check("英雄" in hud.sel_xp_label.text,id+" next promotion is heroic")
			if rank==3:check("英雄" in hud.sel_xp_label.text and unit.veterancy_status().maxed,id+" heroic star agrees with max rank")
	for faction in ["soviet","allied"]:
		for rank in [1,2,3]:
			var texture:=HpBar.rank_texture(rank,{"id":"R3TEST","faction":faction})
			var mesh:=Indicator.badge_mesh(texture)
			var surface:=mesh.surface_get_arrays(0)
			var vertices:PackedVector2Array=surface[Mesh.ARRAY_VERTEX]
			var colors:PackedColorArray=surface[Mesh.ARRAY_COLOR]
			var original:=Image.new()
			original.load_png_from_buffer(FileAccess.get_file_as_bytes(texture.resource_path))
			var dims:Vector2i=(Vector2(original.get_size())*0.75).round()
			original.resize(dims.x,dims.y,Image.INTERPOLATE_NEAREST)
			var reconstructed:=Image.create_empty(dims.x,dims.y,false,Image.FORMAT_RGBA8)
			for i in range(0,vertices.size(),4):reconstructed.set_pixelv(Vector2i(vertices[i]),colors[i])
			check(original.get_data()==reconstructed.get_data(),"%s rank %d untextured world geometry matches native pixels including transparency"%[faction,rank])
	var before:WeakRef=weakref(HpBar.rank_texture(3,GameData.get_unit("R3APOC")))
	await get_tree().process_frame
	check(before.get_ref()!=null,"unselected Soviet hero texture is retained")
