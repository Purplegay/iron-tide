extends "res://tests/leizhu_cards_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	var viewport:=SubViewport.new();viewport.size=Vector2i(700,308);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var stage=preload("res://scripts/ui/faction_card_stage.gd").new();stage.size=Vector2(700,308);viewport.add_child(stage);stage.set_process(false)
	const Demo=preload("res://scripts/ui/leizhu_card_demo.gd")
	for card in [LC.ACTIVE,LC.PASSIVE]:
		for rank in 4:
			stage.configure(card,0,"",rank);stage.playing=false
			check(stage.caster_model.actor.hero_art!=null,"hero contract preview uses copper appearance "+card+str(rank))
			var hashes:Array=[]
			var clocks:Array=[.1,1.1,stage.duration*.42,stage.duration*.7,stage.duration-.1] if card==LC.ACTIVE else [.1,1.1,2.1,3.1,6.1,14.1]
			for clock in clocks:
				stage.elapsed=clock;stage.sync_caster();stage.queue_redraw()
				await get_tree().process_frame;await RenderingServer.frame_post_draw
				var picture:=viewport.get_texture().get_image()
				check(not picture.is_empty() and stage.caster_model_id=="TTNK" and not stage.caster_model.texture.get_size().is_zero_approx(),"GPU renders actual Tesla caster and timeline "+card+str(rank)+str(clock))
				var digest:=hash(picture.get_data());if not hashes.has(digest):hashes.append(digest)
				check(ThemeDB.fallback_font.get_string_size(Demo.sample(card,rank,clock).text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x<=326,"caption fits fixed stage width")
			check(hashes.size()>=4,"card phases yield distinct rendered output "+card+str(rank))
			if card==LC.ACTIVE:
				var state:=Demo.sample(card,rank,1.1)
				check(state.damage==200*[.4,.5,.6,.7][rank]*.5 and state.hp==1000*[.08,.1,.12,.15][rank],"demo uses strengthened four-rank half tick and electrode HP")
			else:
				check(Demo.sample(card,rank,3.1).flash and Demo.sample(card,rank,14.1).count==0,"third hit discharge and eight-second expiry depicted")
	# This shared card has no default model. Exercise its supported demo_model
	# consumer with TTNK so the identity boundary cannot pass by changing chassis.
	var ordinary_card:Dictionary=GameData.skill_index.ap_shock_pulse
	var had_model:=ordinary_card.has("demo_model");var original_model=ordinary_card.get("demo_model")
	ordinary_card.demo_model="TTNK"
	stage.configure("ap_shock_pulse",0,"",0)
	check(stage.caster_model_id=="TTNK" and stage.caster_model.actor.hero_art==null,"same-chassis ordinary card clears hero appearance")
	if had_model:ordinary_card.demo_model=original_model
	else:ordinary_card.erase("demo_model")
	stage.configure("ap_shock_pulse",0,"",0)
	check(stage.caster_model==null,"shared card without declared model retains original schematic fallback")
	viewport.free()
	var hero=cards_hero();var victim=target("HTNK","enemy",hero.position+Vector2(120,0))
	battle.camera.position=victim.position;battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	check(LC.cast(hero,ability(hero),victim.position),"real rendered court cast")
	preload("res://scripts/units/expansion_cards.gd").world_tick(battle,0)
	check(battle.has_node("ExpansionFields"),"live field overlay actually mounted")
	var field:Dictionary=battle.allied_state[LC.FIELDS][0];var hashes:Array=[]
	for i in 3:
		for node in field.nodes:
			if AlliedAbilities.alive(node):LC.electrode_tick(node,.1);node.queue_redraw()
		battle.get_node("ExpansionFields").queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		var picture:=get_viewport().get_texture().get_image();hashes.append(hash(picture.get_data()))
		check(not picture.is_empty() and LC.vertices(field).size()==3-i,"live renderer shows remaining electrode geometry")
		field.nodes[i].receive_hit(100000,"electric",{},victim);LC.world_tick(battle,.1)
	check(hashes[0]!=hashes[1] and hashes[1]!=hashes[2],"three/two/one electrode renders differ")
	battle.selected_units.assign([hero]);battle.hover_ability=UnitSkillLayout.find(hero,LC.ACTIVE)
	battle.queue_redraw();await get_tree().process_frame;await RenderingServer.frame_post_draw
	check(battle._range_preview_ability()==ability(hero) and not get_viewport().get_texture().get_image().is_empty(),"actual W hover draws triangle vertices and five-cell casting radius")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	get_tree().quit(0 if failed==0 else 1)
