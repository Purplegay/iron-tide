extends "res://tests/leizhu_base_regression.gd"
const Art=preload("res://scripts/units/leizhu_art.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var hero=setup_hero()
	var ordinary=battle.spawn_unit("TTNK","ally",hero.position+Vector2(110,-110))
	check(hero.hero_art!=null and ordinary.hero_art==null,"hero identity selects copper skin; ordinary Tesla tank remains native")
	check(Art.data.facings==32 and Art.data.bounds.size()==32,"all thirty-two authored directions are available")
	check(FileAccess.get_file_as_bytes(Art.PATH+".png").size()<1500000,"detailed model atlas stays below 1.5 MB")
	check(Art.texture.get_size()==Vector2(2048,1024),"atlas contains one 256px tile per direction")
	var scale:float=Art.scale_for(hero)
	check(scale>0 and scale<2,"native-width calibration gives finite reasonable scale",scale)
	battle.camera.position=hero.position;battle.camera.reset_smoothing();Iso.apply_to(battle.camera,2);battle.camera.force_update_scroll()
	var hashes:Array=[]
	var source:=Art.texture.get_image();if source.is_compressed():source.decompress()
	for frame in 32:
		hero.hull_angle=Iso.eff_angle()+TAU*frame/32;hero.turret_angle=hero.hull_angle;hero.motion_pose.capture(hero);hero.queue_redraw()
		await rendered()
		check(Art.frame_for(hero)==frame,"logical yaw chooses expected direct frame "+str(frame))
		check(hero.hero_art.source_rect.position==Vector2(frame%8,frame/8)*256,"drawing consumes exactly one authored tile "+str(frame))
		check(hero._body_bounds.has_area() and hero._body_bounds.size.x<110,"native-size visible body bounds "+str(frame),hero._body_bounds)
		var pose:=Art.pose(hero)
		check(hero.hit_test(hero.global_position+RA2Art.art_dir(pose.reactor)),"picking follows visible reactor "+str(frame))
		check(not hero.hit_test(hero.global_position+RA2Art.art_dir(pose.rect.position+Vector2.ONE)),"transparent tile corner is not selectable "+str(frame))
		var digest:=hash(source.get_region(Rect2i(pose.source)).get_data())
		if not hashes.has(digest):hashes.append(digest)
	check(hashes.size()==32,"all directions use distinct authored pixels, not duplicate or mirrored source tiles")
	hero.hull_angle=Iso.eff_angle()+PI/4;hero.motion_pose.capture(hero);hero.queue_redraw();await rendered()
	check(hero._weapon_muzzle().distance_to(hero.global_position+RA2Art.art_dir(Art.pose(hero).coil-Vector2(0,3)))<.01,"real electric weapon starts at custom coil")
	hero.material.set_shader_parameter("house_color",Color(.15,.35,1));await rendered()
	var blue:=mean_color(crop(hero))
	hero.material.set_shader_parameter("house_color",Color(.15,1,.25));await rendered()
	var green:=mean_color(crop(hero))
	check(blue.b>green.b and green.g>blue.g,"GPU recolors armor with owning house color",[blue,green])
	hero.refresh_house_color();hero.hero_art.tick(hero,0);await rendered()
	var lit:=amber(crop(hero))
	hero.special.leizhu.shutdown_left=2.0;hero.hero_art.tick(hero,0);await rendered()
	var dark:=amber(crop(hero))
	check(lit>dark+3,"real shutdown turns off reactor lamps",[lit,dark])
	hero.special.leizhu.erase("shutdown_left");hero.special.leizhu.power_active=true;hero.hero_art.tick(hero,0);await rendered()
	check(hero.material.get_shader_parameter("online") and hero.material.get_shader_parameter("supplying"),"real supply state drives powered reactor visual")
	hero.hero_art.clock=.6;hero.hero_art.tick(hero,0);await rendered()
	var supply_frame:=crop(hero)
	hero.hero_art.clock=.9;hero.hero_art.tick(hero,0);await rendered()
	check(hash(supply_frame.get_data())!=hash(crop(hero).get_data()),"supply arcs and local glow animate inside the copper crown")
	var phase:float=hero.material.get_shader_parameter("phase")
	hero.hero_art.tick(hero,0)
	check(is_equal_approx(hero.material.get_shader_parameter("phase"),phase),"paused visual clock freezes shader light phase")
	var stats:=[hero.hp,hero.max_hp,hero._base_atk,hero.move_speed,hero._cd_timer]
	for i in 10:hero.hero_art.tick(hero,.1)
	check(stats==[hero.hp,hero.max_hp,hero._base_atk,hero.move_speed,hero._cd_timer],"cosmetic clock does not advance gameplay or change stats")
	var codec=BattleSaves.Snapshot.new();var saved:Dictionary=codec.capture(battle);codec.restore(battle,saved);hero=get_hero()
	check(codec.error.is_empty() and hero.hero_art!=null and Art.handles(hero),"actual battle snapshot restores skin from hero identity")
	hero.special.leizhu.erase("power_active");hero.hero_art.tick(hero,0)
	var foe=battle.spawn_unit("TTNK","enemy",hero.position+Vector2(-110,110));L.promote(MetaProgress,battle,foe)
	check(foe.hero_art!=null and foe.material.get_shader_parameter("house_color")==foe._col,"enemy hero receives its own owner color")
	var victim=target("HTNK","enemy",hero.position+Vector2(160,0));var amount:=fire(hero,victim)
	check(amount>0 and hero.special.leizhu.marks.has(victim),"native Tesla shot and high-voltage mark still resolve with custom muzzle")
	if is_instance_valid(victim):victim.visible=false
	for unit in battle.units:unit.queue_redraw()
	await rendered()
	if OS.get_environment("IRON_HERO_ART_PREVIEW")=="1":get_viewport().get_texture().get_image().save_png(output_dir.path_join("leizhu-live.png"))
	await finish()
	var saved_profile:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)
	var page=preload("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="TTNK";page.refresh()
	check(page.preview.actor.hero_art!=null and page.skin_description.text.contains("铜冕雷炉"),"hero progression displays bundled copper appearance")
	check(not page.outfit.visible and not page.trial.visible,"bundled hero appearance adds no purchase or equip gate")
	page.selected="ORCA";page.refresh()
	check(preload("res://scripts/units/peregrine_art.gd").handles(page.preview.actor) and page.preview.actor.hero_art.get_script()==preload("res://scripts/units/peregrine_art.gd"),"changing hero replaces copper appearance with Peregrine")
	page.free()
	check(FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)==saved_profile,"hero appearance previews leave profile bytes unchanged")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":int(OS.get_environment("IRON_HERO_ART_PREVIEW")=="1")},"  "))
	get_tree().quit(0 if failed==0 else 1)

func rendered() -> void:
	await get_tree().process_frame;await RenderingServer.frame_post_draw

func crop(actor) -> Image:
	var start:Vector2=actor.get_global_transform_with_canvas()*RA2Art.art_dir(actor._body_bounds.position)
	var size:Vector2=actor._body_bounds.size*battle.camera.zoom.x
	var image:=get_viewport().get_texture().get_image()
	var ratio:=Vector2(image.get_size())/get_viewport().get_visible_rect().size
	start*=ratio;size*=ratio
	return image.get_region(Rect2i(start,Vector2i(size)+Vector2i.ONE).intersection(Rect2i(Vector2i.ZERO,image.get_size())))

func mean_color(image:Image) -> Color:
	var sum:=Color(0,0,0,0)
	for y in image.get_height():
		for x in image.get_width():sum+=image.get_pixel(x,y)
	return sum/maxf(1,image.get_width()*image.get_height())

func amber(image:Image) -> int:
	var count:=0
	for y in image.get_height():
		for x in image.get_width():
			var color:=image.get_pixel(x,y)
			if color.r>.65 and color.g>.3 and color.b<.25:count+=1
	return count
