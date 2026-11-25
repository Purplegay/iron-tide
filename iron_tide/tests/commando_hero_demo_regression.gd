extends Node
var checks:Array=[]
var failed:=0

func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failed+=1;push_error(label)

func _ready() -> void:
	var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(600,360);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var demo=load("res://scripts/ui/hero_talent_demo.gd").new()
	demo.size=Vector2(600,360);viewport.add_child(demo)
	for id in ["TANY","BORIS"]:
		demo.show_hero(id)
		for track in 2:
			demo.talent.select(track);demo._select_talent();demo.playing=false
			var hashes:Array=[]
			for time in [0.5,2.5,4.25,5.5]:
				demo.elapsed=time;demo.refresh_preview()
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var image:Image=viewport.get_texture().get_image()
				check(not image.is_empty(),"GPU renders "+id+str(track)+str(time))
				var rendered:=hash(image.get_data())
				if not hashes.has(rendered):hashes.append(rendered)
			check(hashes.size()>=2 if id!="BORIS" or track==1 else hashes.size()>=1,"animation state changes or static vision diagram "+id+str(track))
			check(demo.caption.text.contains("Lv.0") and demo.levels.item_count==6,"implemented levels available while baseline is selected "+id+str(track))
	demo.show_hero("TANY");demo.talent.select(1);demo._select_talent();demo.levels.select(0);demo.playing=false
	const Timeline=preload("res://scripts/ui/hero_commando_demo.gd")
	for entry in [[.99,100,0],[1.,80,0],[1.19,80,0],[1.2,80,10],[4.19,80,10],[4.2,80,0],[5.5,80,0]]:
		var state:=Timeline.escape_sample(entry[0])
		check(state.hp==entry[1] and state.shield==entry[2],"same survivor health/shield timeline at "+str(entry[0]))
	var shield_pixels:Array=[]
	for time in [1.05,1.25,4.25]:
		demo.elapsed=time;demo.refresh_preview()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		var picture:=viewport.get_texture().get_image().get_region(Rect2i(demo.stage.get_global_rect()))
		var offset:float=(demo.stage.size.x-540)*.5
		shield_pixels.append([cyan_pixels(picture,Rect2i(int(offset+540*.4-35),42,70,70)),cyan_pixels(picture,Rect2i(int(offset+540*.78-35),42,70,70))])
	check(shield_pixels[1][0]>shield_pixels[0][0]+100,"shield ring appears around Tanya only after initial damage beat")
	check(shield_pixels[1][1]==shield_pixels[0][1],"attacker receives no shield ring")
	check(shield_pixels[2][0]<shield_pixels[1][0]-100,"Tanya shield ring expires after its three-second lifetime")
	viewport.queue_free()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)

func cyan_pixels(picture:Image,rect:Rect2i) -> int:
	var count:=0
	for x in range(rect.position.x,rect.end.x):
		for y in range(rect.position.y,rect.end.y):
			var color:=picture.get_pixel(x,y)
			if color.r<.1 and color.g>.9 and color.b>.9:count+=1
	return count
