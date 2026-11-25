extends "res://tests/peregrine_visual_regression.gd"
const Art=preload("res://scripts/units/peregrine_art.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var hero=service_hero();place_service(hero)
	var ordinary=battle.spawn_unit("ORCA","ally",hero.position+Vector2(180,0))
	check(hero.hero_art!=null and ordinary.hero_art==null,"only Peregrine selects authored model bake")
	check(Art.texture.get_size()==Vector2(3072,1024) and Art.data.facings==32,"four-times detail atlas contains 32 independent directions")
	check(FileAccess.get_file_as_bytes(Art.PATH+".png").size()+FileAccess.get_file_as_bytes(Art.PATH+"_mask.png").size()<1500000,"detailed body and owner/emission atlas remain below 1.5 MB")
	battle.camera.position=hero.position;battle.camera.reset_smoothing();Iso.apply_to(battle.camera,2);battle.camera.force_update_scroll()
	var image:=Art.texture.get_image();if image.is_compressed():image.decompress()
	var hashes:Array=[];var frames:Array=[];var native_width:=0.0;var custom_width:=0.0
	for index in 32:
		hero.hull_angle=Iso.eff_angle()+TAU*index/32;hero.motion_pose.capture(hero)
		await picture(hero)
		var value:=Art.pose(hero);var frame:int=value.frame
		frames.append(frame)
		check(hero.hero_art.source_rect==value.source,"runtime consumes one direct frame "+str(index))
		var digest:=hash(image.get_region(Rect2i(value.source)).get_data())
		if not hashes.has(digest):hashes.append(digest)
		check(hero._body_bounds.has_area() and hero._body_bounds.size.x<80,"native-scale visible width "+str(index),hero._body_bounds.size.x)
		var core:Vector2=value.rect.position+Vector2(48,103.0/3.0)*float(Art.data.scale)*float(value.scale)
		check(hero.hit_test(hero.global_position+RA2Art.art_dir(core)),"opaque central body is selectable "+str(index))
		check(not hero.hit_test(hero.global_position+RA2Art.art_dir(value.rect.position+Vector2.ONE)),"transparent corner is not selectable "+str(index))
		check(hero._weapon_muzzle().distance_to(hero.global_position+RA2Art.art_dir(value.muzzle))<.01,"weapon consumes baked nose anchor "+str(index))
		var native_rect:=RA2Art.draw_rect(hero._ra2,hero.radius,range(32),0,hero.RA2_SPRITE_SCALE)
		var native_origin:Vector2=native_rect.position+Art.point(hero._weapon_art.origins[frame])*hero.RA2_SPRITE_SCALE
		var nose:Vector2=value.muzzle+Vector2(0,hero._visual_lift())-native_origin
		# Remove the model nose's Z=4 elevation before comparing world XY heading.
		nose.y+=4*sqrt(.75)*Art.BODY_SCALE*hero.RA2_SPRITE_SCALE
		check(RA2Art.art_dir(nose).dot(Vector2.from_angle(hero.hull_angle))>20,"model nose points along actual world heading "+str(index),nose)
		native_width+=RA2Art.visible_sprite_rect(hero._ra2,native_rect,RA2Art.src_rect(hero._ra2,frame)).size.x
		custom_width+=hero._body_bounds.size.x
	check(hashes.size()==32 and frames.size()==32,"all directions have distinct pixels")
	check(custom_width/native_width>.75 and custom_width/native_width<1.15,"mean body width remains close to original ORCA",custom_width/native_width)
	hero.hull_angle=Iso.eff_angle()+PI/4;hero.motion_pose.capture(hero)
	hero.material.set_shader_parameter("house_color",Color(.1,.25,1));var blue:=average(await picture(hero))
	hero.material.set_shader_parameter("house_color",Color(.1,1,.2));var green:=average(await picture(hero))
	check(blue.b>green.b and green.g>blue.g,"actual GPU mask follows owner color",[blue,green])
	hero.refresh_house_color()
	hero.hero_art.clock=0;hero.hero_art.tick(hero,0);var dim:=await picture(hero)
	hero.hero_art.clock=PI/4.8;hero.hero_art.tick(hero,0);var lit:=await picture(hero)
	check(hash(dim.get_data())!=hash(lit.get_data()),"runtime engine lamps pulse on the rendered body")
	var prior:Dictionary=hero.special.duplicate(true)
	var stats:=[hero.hp,hero.max_hp,hero.logistics.ammo,hero.position,hero._cd_timer]
	var nodes:=get_tree().get_node_count()
	for i in 1000:hero.hero_art.tick(hero,.016)
	check(prior==hero.special and stats==[hero.hp,hero.max_hp,hero.logistics.ammo,hero.position,hero._cd_timer],"appearance clock cannot advance gameplay")
	check(nodes==get_tree().get_node_count(),"appearance tick allocates no scene nodes")
	make_wreck(hero);P.tick(hero,1);hero.hero_art.tick(hero,0)
	check(hero.material.get_shader_parameter("broken") and not hero.material.get_shader_parameter("online"),"real crash darkens body and disables engine lamps")
	await picture(hero)
	var codec=BattleSaves.Snapshot.new();var snapshot:Dictionary=codec.capture(battle);codec.restore(battle,snapshot);hero=get_hero()
	check(codec.error.is_empty() and hero.hero_art!=null and hero.material.get_shader_parameter("broken"),"battle save restores custom wreck without serializing renderer objects")
	S.recover(hero);hero.flight.altitude(1,.1);hero.hero_art.tick(hero,0)
	check(not hero.material.get_shader_parameter("broken") and hero.material.get_shader_parameter("online"),"recovery restores live body and lamps")
	var foe=battle.spawn_unit("ORCA","enemy",hero.position+Vector2(-120,0));P.promote(MetaProgress,battle,foe)
	check(foe.hero_art!=null and foe.material.get_shader_parameter("house_color")==foe._col,"enemy hero uses enemy ownership color")
	await finish()
	var saved:=FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)
	var page=preload("res://scripts/ui/hero_progression.gd").new();add_child(page);page.selected="ORCA";page.refresh()
	check(Art.handles(page.preview.actor) and page.preview.actor.hero_art!=null and page.skin_description.text.contains("极地游隼"),"hero page installs and describes bundled model appearance")
	page.preview.playing=false;var clock:float=page.preview.actor.hero_art.clock;page.preview._process(1)
	check(page.preview.actor.hero_art.clock==clock,"paused showcase freezes body pulse")
	var actor=page.preview.actor
	preload("res://scripts/ui/aircraft_cycle_demo.gd").sync_actor(actor,{"hero":false,"ammo":1,"capacity":1})
	check(actor.hero_art==null and actor.peregrine_fx==null,"cycle demo resets to ordinary native aircraft")
	page.selected="TTNK";page.refresh()
	check(page.preview.actor.hero_art.get_script()==preload("res://scripts/units/leizhu_art.gd"),"switching heroes installs Tesla appearance independently")
	page.free()
	check(FileAccess.get_file_as_bytes(MetaProgress.SAVE_PATH)==saved,"showcase and demo do not write profile")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)

func average(image:Image) -> Color:
	var sum:=Color(0,0,0,0)
	for y in image.get_height():
		for x in image.get_width():sum+=image.get_pixel(x,y)
	return sum/maxf(1,image.get_width()*image.get_height())
