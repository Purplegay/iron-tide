extends "res://tests/ra3_future_presentation_regression.gd"

func capture_scene(label: String) -> void:
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for i in 8:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output_dir.path_join(label+".png"))

func verify_particle_alpha() -> void:
	var view:=SubViewport.new();view.size=Vector2i(80,40);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(view)
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color(.5,.4,.3,.5))
	var texture:=ImageTexture.create_from_image(image)
	for i in 2:
		var sprite:=Sprite2D.new();sprite.texture=texture;sprite.scale=Vector2.ONE*24;sprite.position=Vector2(20+i*40,20)
		if i==1:
			var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/ra3_damage_particle.gdshader");sprite.material=mat
		view.add_child(sprite)
	for i in 4:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels:=view.get_texture().get_image();var actual:=pixels.get_pixel(60,20);var expected:=pixels.get_pixel(20,20)
	check(absf(actual.a-expected.a)<.01 and absf(actual.r-expected.r)<.01,"particle shader applies texture and alpha once, matching native CanvasItem blend",{"actual":str(actual),"expected":str(expected)})
	view.free()

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	await verify_particle_alpha()
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	battle.water_rects=[];battle.path_service.set_water([]);battle._refresh_pathing();battle.paused=false
	battle.camera.position=Vector2(1500,1500)
	for i in 3:await get_tree().process_frame
	check(GM.has_battle_tools(),"actual battle registers live unit test hook")
	var panel=preload("res://scripts/admin/gm_unit_panel.gd").new()
	var messages: Array=[];panel.notify=func(message):messages.append(message)
	battle.hud.add_child(panel)
	panel.search.text="未来";panel._filter("未来")
	check(panel.ids==["R3FUTURE"],"Chinese search resolves Future Tank")
	panel._filter("r3harbinger")
	check(panel.ids==["R3HARBINGER"],"ID search is case insensitive")
	panel._filter("不存在的名字")
	check(panel.ids.is_empty(),"unknown search safely produces no selection")
	panel.get_node("SpawnUnit").pressed.emit()
	check(battle.units.is_empty(),"empty selection cannot spawn unrelated units")
	panel._filter("R3FUTURE");panel.count.value=2;panel.rank.select(2);panel.health.value=25
	panel.get_node("SpawnUnit").pressed.emit()
	check(battle.units.size()==2 and messages.size()==1,"real GM button routes through singleton and battle hook")
	for unit in battle.units:
		activate(unit)
		check(unit.side=="ally" and unit.veteran_level==2 and is_equal_approx(unit.hp/unit.max_hp,.25),"spawn applies side, veterancy and health")
		check(battle.camera_play_rect().has_point(unit.get_global_transform_with_canvas().origin),"spawn lies in visible play area")
	check(battle.units[0].position.distance_to(battle.units[1].position)>battle.units[0].radius+battle.units[1].radius,"spawn placement avoids unit overlaps")
	var unit=battle.units[0];battle.selected_units=[unit]
	unit._cd_timer=5;unit.special.ra3_riot_cd=12
	panel.get_node("ResetCooldown").pressed.emit()
	check(unit._cd_timer==0 and unit.special.ra3_riot_cd==0,"reset clears ordinary and native Q cooldown")
	unit.special.ra3_riot_point=unit.position;unit.special.ra3_riot_cd=12
	panel.get_node("ResetCooldown").pressed.emit()
	check(unit.special.ra3_riot_cd==12 and unit.special.has("ra3_riot_point"),"reset does not cancel or refund active Q")
	unit.special.erase("ra3_riot_point");panel.rank.select(3);panel.get_node("SetRank").pressed.emit()
	check(unit.veteran_level==3,"selected RA3 unit can test heroic state")
	panel.health.value=100;panel.get_node("SetHealth").pressed.emit()
	check(is_equal_approx(unit.hp,unit.max_hp),"selected health update restores current ranked maximum")
	panel.side.select(1);panel.stationary.button_pressed=true;panel.count.value=1
	panel.get_node("SpawnUnit").pressed.emit()
	var enemy=battle.units[-1]
	check(enemy.side=="enemy" and enemy.special.gm_stationary and enemy.is_physics_processing() and enemy.fire_stance=="none","enemy target suppresses combat while retaining lifecycle callbacks")
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot=codec.capture(battle);codec.restore(battle,snapshot)
	enemy=battle.units.filter(func(u):return u.side=="enemy")[0]
	var old_position: Vector2=enemy.position;enemy._physics_process(1)
	check(enemy.special.gm_stationary and enemy.position==old_position,"stationary test target survives save/restore")
	var existing=actor("MTNK","ally",Vector2(2200,2200))
	panel.get_node("ClearSpawns").pressed.emit()
	await get_tree().process_frame
	check(battle.units==[existing] and battle.selected_units.is_empty(),"cleanup removes only GM spawned actors, preserving existing units")
	panel.get_node("SpawnExpansion").pressed.emit()
	var air_units: Array=battle.units.filter(func(u):return u.unit_id=="R3HARBINGER")
	check(air_units.size()==1,"quick pair creates Harbinger")
	if not air_units.is_empty():
		var air=air_units[0];activate(air)
		var body: Vector2=air.get_global_transform_with_canvas().origin+Vector2(0,-air._visual_lift()*battle.camera.zoom.x)
		check(battle.camera_play_rect().grow(-40).has_point(body),"GM aircraft body is visible rather than only its ground shadow")
	GM.cmd_unit_tools({"action":"clear"});await get_tree().process_frame
	check(GM.cmd_unit_tools({"action":"spawn","id":"INVALID"}).begins_with("未知单位"),"invalid ID reports an error")
	panel.free()
	for id in ["R3FUTURE","R3HARBINGER"]:
		var actor_=actor(id,"ally",Vector2(1500,1500));var model=actor_._ra3_model;model.set_process(false)
		if actor_.is_air:actor_.position+=RA2Art.art_dir(Vector2(0,actor_._visual_lift()))
		var state=model.damage_state
		check(not state.skins.is_empty(),id+" native damage diffuse bindings found")
		for bone in (["B_FENDER01"] if id=="R3FUTURE" else ["FXDAMAGE01","FXDAMAGE02"]):
			check(model.source.bones.any(func(b):return str(b.name).to_upper()==bone),id+" native emitter bone exists: "+bone)
		actor_.hp=actor_.max_hp;state.tick(0)
		check(state.state==0 and state.rows.is_empty(),id+" healthy has no damage emitter")
		var normal: Image=await capture(model.viewport,id+"-healthy")
		actor_.hp=actor_.max_hp*.6
		check(is_equal_approx(actor_._ramped_speed(1),actor_.move_speed*(.75 if id=="R3FUTURE" else 1.0)),id+" native damaged movement multiplier consumed")
		for i in 20:state.tick(1.0/30)
		check(state.state==1 and not state.rows.is_empty() and state.rows.all(func(row):return row.smoke),id+" damaged emits smoke only")
		for skin in state.skins:check(skin.material.get_shader_parameter("diffuse_map")==skin.original,id+" damaged keeps ordinary skin")
		actor_.hp=actor_.max_hp*.25
		for i in 12:state.tick(1.0/30)
		check(state.state==2 and state.rows.any(func(row):return not row.smoke),id+" really damaged adds fire")
		for skin in state.skins:check(skin.material.get_shader_parameter("diffuse_map")==skin.damaged,id+" really damaged replaces native diffuse")
		check((not state.lights.is_empty())==(id=="R3FUTURE"),id+" fire light follows exact unit XML state")
		var damaged: Image=await capture(model.viewport,id+"-damaged")
		check(changed_pixels(normal,damaged)>30,id+" damaged material changes actual rendered pixels")
		model.set_process(true)
		actor_.queue_redraw()
		await capture_scene(id+"-smoke-fire")
		check(actor_.is_visible_in_tree(),id+" presentation visible",{"rect":str(model.draw_rect),"screen":str(actor_.get_global_transform_with_canvas().origin),"opacity":Ra3Mirage.CloakVisual.opacity(actor_),"child":str(state.global_transform),"sprite":str(state.rows[0].sprite.global_position) if not state.rows.is_empty() else "none"})
		model.set_process(false)
		actor_.hp=actor_.max_hp;state.tick(0)
		check(is_equal_approx(actor_._ramped_speed(1),actor_.move_speed),id+" repair restores movement speed")
		for i in 40:state.tick(1.0/30)
		check(state.state==0 and state.rows.is_empty() and state.lights.is_empty(),id+" repair stops emission and lets old particles expire")
		for skin in state.skins:check(skin.material.get_shader_parameter("diffuse_map")==skin.original,id+" repair restores original texture")
		actor_.free();battle.units.erase(actor_)
	battle.hud._toggle_gm()
	for i in 4:await get_tree().process_frame
	var console=battle.hud.gm_console;var rect: Rect2=console.get_child(0).get_global_rect()
	check(rect.size.y>400 and rect.end.y<=stage.size.y,"floating console spans right side without clipping vertically",str(rect))
	GM.unlock_production_tech=false;console._process(0)
	check(not console._flag_checks.unlock_production_tech.button_pressed,"sixth flag synchronizes by name rather than checkbox index")
	check(not console._body.get_child(0).stationary.button_pressed,"GM flag sync cannot toggle stationary-target checkbox")
	await capture_scene("gm-unit-panel")
	battle.gm_unit_lab=true;battle._update_waves(10000);battle._check_end();battle.end_battle(true)
	check(not battle.ended,"unit lab cannot trigger end or meta reward settlement")
	screen.free();await get_tree().process_frame
	check(not GM.has_battle_tools() and GM.cmd_spawn("R3FUTURE",1).begins_with("请先"),"leaving battle unregisters tools and reports no active battle")
	# Keep this harness alive while exercising the real backend scene-change button.
	get_tree().current_scene=null
	var backend=preload("res://scripts/admin/gm_unit_panel.gd").new();backend.notify=func(_message):pass
	add_child(backend)
	check(backend.has_node("LaunchUnitLab"),"menu backend exposes test arena entry")
	backend.get_node("LaunchUnitLab").pressed.emit()
	for i in 10:await get_tree().process_frame
	var live=get_tree().current_scene
	check(live is BattleScreen and live.battle.gm_unit_lab,"backend button starts real unit test scene")
	check(live.battle.skirmish_ai==null and live.hud.gm_console.visible,"test scene has no AI and opens GM panel automatically")
	var timer: float=live.battle.wave_timer;live.battle._update_waves(10000)
	check(live.battle.wave_timer==timer,"test arena disables preparation waves")
	get_tree().current_scene=null;live.free();backend.free()
	await get_tree().process_frame
