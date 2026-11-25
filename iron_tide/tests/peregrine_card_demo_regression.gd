extends "res://tests/peregrine_contract_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var viewport:=SubViewport.new();viewport.size=Vector2i(700,308)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var stage=preload("res://scripts/ui/faction_card_stage.gd").new()
	stage.size=Vector2(700,308);viewport.add_child(stage);stage.set_process(false)
	const Demo=preload("res://scripts/ui/peregrine_card_demo.gd")
	for card in [PC.ACTIVE,PC.PASSIVE]:
		for rank in 4:
			stage.configure(card,0,"",rank);stage.playing=false
			check(stage.caster_model.actor.hero_art!=null and preload("res://scripts/units/peregrine_art.gd").handles(stage.caster_model.actor),"contract card uses bundled Peregrine appearance "+card+str(rank))
			var hashes:Array=[]
			for clock in [.1,.6,.9,1.3,2.05,3.2,4.2,5.5,6.5,9.5]:
				stage.elapsed=clock;stage.sync_caster();stage.queue_redraw()
				await get_tree().process_frame;await RenderingServer.frame_post_draw
				var picture:=viewport.get_texture().get_image()
				check(not picture.is_empty() and stage.caster_model_id=="ORCA" and not stage.caster_model.texture.get_size().is_zero_approx(),"GPU card and real caster render "+card+str(rank)+str(clock))
				var digest:=hash(picture.get_data())
				if not hashes.has(digest):hashes.append(digest)
				check(ThemeDB.fallback_font.get_string_size(Demo.sample(card,rank,clock).text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x<=326,"demo caption fits the actual fixed canvas "+card+str(rank)+str(clock))
			check(hashes.size()>=4,"demo changes through launch/impact or refill/damage/linkage phases "+card+str(rank))
			var sample:Dictionary=Demo.sample(card,rank,4.2)
			if card==PC.ACTIVE:
				check(sample.damage==200*[.4,.5,.6,.75][rank] and sample.radius==[1.,1.2,1.4,1.6][rank] and sample.cooldown==[38.,35.,32.,29.][rank],"demo rank values match approved W numbers "+str(rank))
			else:
				check(is_equal_approx(sample.shield,2*[.04,.06,.08,.1][rank]) and sample.linked and is_equal_approx(sample.reload,8*(1-[.1,.15,.2,.25][rank])),"demo shows residual stacked shield and hero-only reload link "+str(rank))
	stage.configure("ps_last_calibration",0,"",0);stage.elapsed=17;stage.sync_caster()
	check(stage.caster_model.actor.hero_art!=null,"ordinary aircraft card's hero segment installs Peregrine")
	stage.elapsed=.1;stage.sync_caster()
	check(stage.caster_model.actor.hero_art==null and stage.caster_model.actor.peregrine_fx==null,"rewinding aircraft card restores ordinary body and clears hover effects")
	stage.configure("ap_leizhu_court",0,"",0)
	check(stage.caster_model.actor.hero_art!=null and stage.caster_model.actor.hero_art.get_script()==preload("res://scripts/units/leizhu_art.gd"),"switching card owner preserves Tesla hero renderer")
	stage.configure(PC.ACTIVE,0,"",0)
	check(preload("res://scripts/units/peregrine_art.gd").handles(stage.caster_model.actor),"switching back to Peregrine rebuilds its own model renderer")
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	viewport.free()
	var hero=cards_hero(3);var target=victim("HTNK",hero.position+Vector2(150,0))
	battle.camera.position=hero.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	hero.selected=true;PC.cast(hero,ability(hero),target.position)
	var hashes:Array=[]
	for delta in [.05,.1,.2,.2,.2,.2,.5]:
		PC.world_tick(battle,delta);hero.queue_redraw();battle.queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		var picture:=get_viewport().get_texture().get_image()
		check(not picture.is_empty(),"real W flight and shield draw "+str(delta))
		var digest:=hash(picture.get_data())
		if not hashes.has(digest):hashes.append(digest)
	check(hashes.size()>=4 and target.hp<100000,"real flight changes across multiple frames and damages its target")
	check(not battle.allied_state.has(PC.EVENTS),"real rendered volley finishes and retires")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
