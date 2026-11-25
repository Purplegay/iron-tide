extends Node
var checks:Array=[]
var failed:=0

func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failed+=1;push_error(label)

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(700,460);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var demo=preload("res://tests/hero_demo_text_probe.gd").new();demo.size=Vector2(700,460);viewport.add_child(demo)
	demo.show_hero("TTNK")
	var descent:=ThemeDB.fallback_font.get_descent(14)
	for track in 2:
		demo.talent.select(track);demo._select_talent()
		for rank in 6:
			demo.levels.select(rank);demo.restart();demo.playing=false
			for t:float in [.1,2.1,3.1,5.1,8.1]:
				demo.elapsed=t;demo.refresh_preview()
				await get_tree().process_frame;await RenderingServer.frame_post_draw
				check(not demo.drawn_text.is_empty(),"actual draw emits text "+str(track)+"/"+str(rank)+" at "+str(t))
				for entry in demo.drawn_text:
					check(float(entry.position.y)+descent<=demo.stage.size.y,"visible text baseline "+str(track)+"/"+str(rank)+" "+entry.text)
				if track==0 and rank==5:
					var picture:=viewport.get_texture().get_image().get_region(Rect2i(demo.stage.get_global_rect()))
					check(cyan_footer(picture)>30,"power arithmetic produces visible cyan pixels below old crop at "+str(t))
	demo.show_hero("BORIS");await get_tree().process_frame
	check(demo.stage.custom_minimum_size.y==148,"switching to another hero restores its compact stage")
	demo.show_hero("TTNK");await get_tree().process_frame
	check(demo.stage.custom_minimum_size.y>=174,"switching back restores space for bottom labels")
	viewport.free()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)

func cyan_footer(picture:Image) -> int:
	var pixels:=0
	for y in range(148,mini(166,picture.get_height())):
		for x in picture.get_width():
			var c:=picture.get_pixel(x,y)
			if c.r<.35 and c.g>.65 and c.b>.65:pixels+=1
	return pixels
