extends "res://tests/boris_contract_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var viewport:=SubViewport.new();viewport.size=Vector2i(700,308);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var stage=preload("res://scripts/ui/faction_card_stage.gd").new();stage.size=Vector2(700,308);viewport.add_child(stage);stage.set_process(false)
	for card in [BF.ACTIVE,BF.PASSIVE]:
		for rank in 4:
			stage.configure(card,0,"",rank);stage.playing=false
			var hashes:Array=[]
			for clock in [.1,.4,.65,1.6,1.85,2.3,2.65,3.45,4.2,5.1,5.8,8.1,19.9,20.1]:
				stage.elapsed=clock;stage.sync_caster();stage.queue_redraw()
				await get_tree().process_frame;await RenderingServer.frame_post_draw
				var picture:=viewport.get_texture().get_image()
				check(not picture.is_empty() and stage.caster_model_id=="BORIS" and not stage.caster_model.texture.get_size().is_zero_approx(),"Boris four-rank GPU card "+card+str(rank)+str(clock))
				var digest:=hash(picture.get_data())
				if not hashes.has(digest):hashes.append(digest)
			check(hashes.size()>=4,"timeline changes across call, warning, impacts or receipt consumption "+card+str(rank))
	viewport.free()
	var hero=setup_boris(3);earn(hero,3)
	var point:Vector2=hero.position+Vector2(150,0)
	battle.selected_units.assign([hero]);battle.cast_slot=UnitSkillLayout.find(hero,BF.ACTIVE)
	BF.cast(hero,hero.ability_at(battle.cast_slot),point);BF.tick(hero,.601)
	var elapsed:=0.0
	for delta in [.1,1.1,.8,.8]:
		elapsed+=delta
		BF.world_tick(battle,delta);battle.queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		var events:Array=battle.allied_state.get(BF.EVENTS,[])
		check(events.is_empty() if elapsed>=2.79 else events.size()==1 and is_equal_approx(events[0].radius,96.25),"live world retains scaled warning until final impact")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
