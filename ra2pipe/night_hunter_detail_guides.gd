extends SceneTree
## Re-layout existing authored frames into small AI edit targets, without inventing angles.
func _initialize() -> void:
	var root:=OS.get_environment("IRON_SKIN_SOURCE")
	var output:=OS.get_environment("IRON_SKIN_OUTPUT")
	if root.is_empty() or output.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	for id:String in ["night_owl","rift_hunter"]:
		var poses:=["flight","mid","down"] if id=="night_owl" else ["idle","walk","walk_b"]
		for group in 8:
			var guide:=Image.create(896,672,false,Image.FORMAT_RGBA8)
			for pose in 3:
				var source:=Image.load_from_file(root.path_join(id+"_"+poses[pose]+".png"))
				var cell:=Vector2(source.get_size())/Vector2(8,4)
				for column in 4:
					var frame:=group*4+column
					var origin:=Vector2(frame%8,frame/8)*cell
					var region:=Rect2i(Vector2i(origin.round()),Vector2i((origin+cell).round()-origin.round()))
					var tile:=source.get_region(region)
					tile.resize(208,208,Image.INTERPOLATE_LANCZOS)
					guide.blit_rect(tile,Rect2i(0,0,208,208),Vector2i(column*224+8,pose*224+8))
			guide.save_png(output.path_join(id+"_%02d.png"%group))
	print("Prepared 16 existing-frame edit guides")
	quit()
