extends "res://tests/base_recovery_regression.gd"

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	await get_tree().process_frame
	var sampled := 0
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra2/shp_geometry.json"))
	for id in data:
		var art := RA2Art.art(id)
		if art.get("kind")!="shp": continue
		check(art.has("foot_bounds"),id+" metadata matches imported atlas layout")
		var image: Image = art.tex.get_image()
		if image.is_compressed(): image.decompress()
		for frame in art.rects.size():
			var source := RA2Art.src_rect(art,frame)
			var actual := RA2Art.visible_sprite_rect(art,Rect2(Vector2.ZERO,source.size),source)
			var expected := Rect2(image.get_region(Rect2i(source)).get_used_rect())
			check(actual==expected,id+" frame crop "+str(frame))
			sampled += 1
		var fallback := art.duplicate()
		fallback.erase("foot_bounds")
		fallback.img = image
		fallback.pose_anchors = {}
		for frames in [[0],range(mini(8,art.rects.size())),[art.rects.size()-1]]:
			check(RA2Art.anchor(art,frames)==RA2Art.anchor(fallback,frames),id+" exact foot anchor "+str(frames))
	check(sampled>10000,"All available SHP animation poses compared",sampled)
	var before := RA2Art.art("E1")
	RA2Art.clear_cache()
	check(RA2Art._cache.is_empty() and not before.is_empty() and before.tex.get_width()>0,"Eviction retains live draw-owner resources")
	var reload := RA2Art.art("E1")
	check(reload.has("foot_bounds") and not reload.has("img"),"Reload geometry does not allocate CPU atlas copy")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"frames":sampled}))
	print("GEOMETRY ",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
