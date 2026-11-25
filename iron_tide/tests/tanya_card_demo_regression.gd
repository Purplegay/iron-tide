extends "res://tests/tanya_contract_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(700,308);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var stage=preload("res://scripts/ui/faction_card_stage.gd").new()
	stage.size=Vector2(700,308);viewport.add_child(stage);stage.set_process(false)
	for card in [B.ID,CQ.PASSIVE]:
		for rank in 4:
			stage.configure(card,0,"",rank);stage.playing=false
			var hashes:Array=[]
			for clock in [.1,.6,.9,1.3,2.05,2.45,2.85,4.1,9.1]:
				stage.elapsed=clock;stage.sync_caster();stage.queue_redraw()
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var image:=viewport.get_texture().get_image()
				check(not image.is_empty() and stage.caster_model_id=="TANY" and not stage.caster_model.texture.get_size().is_zero_approx(),"GPU Tanya card and live unit render "+card+str(rank)+str(clock))
				var digest:=hash(image.get_data())
				if not hashes.has(digest):hashes.append(digest)
			check(hashes.size()>=4,"card timeline visibly changes across throwing, fuse, destruction or passive states "+card+str(rank))
	viewport.free()
	var hero=setup_hero(3)
	var ab:Ability=hero.skills[UnitSkillLayout.find(hero,B.ID)]
	B.cast(hero,ab,hero.position+Vector2(150,0))
	var bomb=bombs()[0]
	for delta in [.1,.2,.2,.7]:
		B.charge_tick(bomb,delta)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(bomb._body_bounds.position.is_finite() and bomb._body_bounds.size==Vector2(16,16),"live bomb arc and landed fuse draw finite selectable bounds")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
