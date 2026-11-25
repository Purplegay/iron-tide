extends "res://tests/dual_build_regression.gd"
const Clock = preload("res://scripts/ui/production_clock.gd")

func exercise_mode(mode: String) -> void:
	get_tree().paused=false
	BattleRequest.configure_skirmish(mode,{"map_size":3200,"starting_funds":50000})
	screen=load("res://scenes/battle.tscn").instantiate()
	stage.add_child(screen); battle=screen.battle
	screen.process_mode=Node.PROCESS_MODE_DISABLED
	var hud=screen.hud
	hud.process_mode=Node.PROCESS_MODE_DISABLED
	for b in battle.buildings: b._buildup_play=-1.0
	battle.power_low=false; battle.funds=50000.0
	GM.no_build_time=false; GM.infinite_funds=false
	battle.production_technology.unlock("structure_queue","ally")
	battle.request_structure("GAPOWR"); battle.request_structure("GAREFN")
	battle.request_structure("GAPILL")
	battle._tick_structure_queue(1.0)
	hud.select_prod_tab("building"); await refresh()
	var active=hud._prod_wipes.GAPOWR
	var current := job("GAPOWR")
	check(is_equal_approx(active.frac,float(current.elapsed)/float(current.time)) and active.phase=="producing",mode+": building reads actual queue progress")
	check(hud._prod_wipes.GAREFN.phase=="waiting" and hud._prod_wipes.GAREFN.frac==0,mode+": reservation has no fake progress")
	check(active.mouse_filter==Control.MOUSE_FILTER_IGNORE and active._badge_label.mouse_filter==Control.MOUSE_FILTER_IGNORE,mode+": clock and badge do not intercept clicks")
	check(active.clock_rect().size.x<50 and active.clock_rect().size.y<40,mode+": mask limited to portrait not name and price")
	var progress: float=active.frac
	battle.structure_right_click("GAPOWR"); battle._tick_structure_queue(1.0); await refresh()
	check(active.phase=="paused" and active.frac==progress,mode+": RMB hold stops clock without losing progress")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(output_dir.path_join(mode+"-building-paused.png"))
	battle.request_structure("GAPOWR"); battle.funds=0
	battle._tick_structure_queue(1.0); await refresh()
	check(active.phase=="blocked" and active.frac==progress,mode+": no funds preserves progress with blocked marker")
	battle.funds=50000; battle.power_low=true
	battle._tick_structure_queue(0.5); await refresh()
	check(active.phase=="producing" and active.frac>progress,mode+": reduced power still shows actual slower progress")
	battle.power_low=false
	hud.select_prod_tab("defense"); await refresh()
	check(hud._prod_wipes.GAPILL.phase=="producing" and hud._prod_wipes.GAPILL.frac>0,mode+": defense lane has independent clock")
	battle._tick_structure_queue(1000.0)
	hud.select_prod_tab("building"); await refresh()
	check(hud._prod_wipes.GAPOWR.phase=="ready" and hud._prod_wipes.GAPOWR.frac==1,mode+": finished building becomes full ring and check")
	battle.cancel_structure("GAPOWR"); await refresh()
	check(hud._prod_wipes.GAPOWR.frac<0 and hud._prod_wipes.GAPOWR.phase=="idle",mode+": cancelled ready card clears clock")
	var factory
	for b in battle.buildings:
		if b.side=="ally" and b.building_id=="GAPILE": factory=b
	check(is_instance_valid(factory),mode+": existing barracks available")
	factory.enqueue_many("E1",2); factory.enqueue("ENGINEER")
	factory._process(0.5)
	hud.select_prod_tab("infantry"); hud._factories.choose(factory); await refresh()
	active=hud._prod_wipes.E1
	check(active.phase=="producing" and active.badge==2 and is_equal_approx(active.frac,factory.queue_progress()),mode+": unit head and quantity match factory")
	check(hud._prod_wipes.ENGINEER.phase=="waiting",mode+": following unit waits")
	check(hud._prod_bars.queue[0].get_script()==Clock and is_equal_approx(hud._prod_bars.queue[0].frac,active.frac),mode+": queue footer shares same circular progress")
	progress=active.frac
	factory.production_right_click("E1"); factory._process(1.0); await refresh()
	check(active.phase=="paused" and active.frac==progress and hud._prod_bars.queue[0].phase=="paused",mode+": unit pause updates both clocks")
	factory.resume_production("E1"); await refresh()
	check(active.phase=="producing" and active.frac==progress,mode+": resume keeps fraction")
	battle.paused=true; await refresh()
	check(active.phase=="paused" and active.frac==progress,mode+": game pause has no autonomous spinning")
	battle.paused=false
	var second=battle._place_building("GAPILE","ally",Vector2(1800,1800),true)
	second._buildup_play=-1.0
	second.enqueue("E1")
	hud._factories.choose(second); await refresh()
	check(hud._prod_wipes.E1.frac==0 and hud._prod_wipes.E1.badge==1,mode+": second factory starts its own zero clock")
	hud._factories.choose(factory); await refresh()
	check(is_equal_approx(hud._prod_wipes.E1.frac,progress) and hud._prod_wipes.E1.badge==2,mode+": original factory retains its clock and badge")
	var rect := Rect2(0,0,60,48)
	for item in [[0.25,Vector2(45,12),Vector2(15,36)],[0.5,Vector2(45,12),Vector2(15,36)],[0.75,Vector2(45,36),Vector2(15,12)]]:
		var polygon := Clock.remaining_sector(rect,float(item[0]))
		check(not Geometry2D.is_point_in_polygon(item[1],polygon) and Geometry2D.is_point_in_polygon(item[2],polygon),mode+": clockwise reveal quadrant "+str(item[0]))
	var bounded=Clock.new()
	bounded.set_state(2.0,-1)
	check(bounded.frac==1.0 and bounded.badge==0,mode+": progress and count clamp safely")
	bounded.set_state(-1.0,0)
	check(bounded.phase=="idle",mode+": idle resets previous completion")
	bounded.free()
	for faction in ["allied","soviet","yuri"]:
		check(Clock.color_for(faction)!=Clock.color_for({"allied":"soviet","soviet":"yuri","yuri":"allied"}[faction]),mode+": distinct faction accent "+faction)
	check(Clock.color_for("unknown")==Clock.color_for("allied") and Clock.color_for("ThirdSide")==Clock.color_for("yuri"),mode+": unknown fallback and Yuri alias")
	if mode==MatchRules.RA2 and DisplayServer.get_name()!="headless": await preview(hud)
	screen.free(); await get_tree().process_frame

func preview(hud) -> void:
	var layer:=CanvasLayer.new(); layer.layer=100; stage.add_child(layer)
	var panel:=Panel.new(); panel.position=Vector2(80,220); panel.size=Vector2(1440,445); layer.add_child(panel)
	var vb:=VBoxContainer.new(); vb.position=Vector2(12,12); panel.add_child(vb)
	var title:=Label.new(); title.text="尤复式建造进度 · 配色预览（苏联/尤里为显示预留，不代表阵营已接入）"; vb.add_child(title)
	var captures: Array[Image]=[]
	for faction in ["allied","soviet","yuri"]:
		var label:=Label.new(); label.text={"allied":"盟军 · 蓝","soviet":"苏联 · 红","yuri":"尤里 · 紫"}[faction]; vb.add_child(label)
		var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",6); vb.add_child(row)
		for item in [[0.0,"producing","开始"],[0.25,"producing","25%"],[0.5,"producing","50%"],[0.75,"producing","75%"],[0.5,"paused","暂停"],[0.5,"blocked","资金不足"],[0.0,"waiting","等待"],[1.0,"ready","就绪"]]:
			var data:=GameData.get_building("GAPOWR").duplicate(true)
			data.faction=faction; data.name=str(item[2])
			var button: Button=hud._make_cameo(data,800,0)
			button.custom_minimum_size=Vector2(170,70); row.add_child(button)
			var clock=button.get_node("CameoWipe"); clock.set_state(float(item[0]),3,str(item[1]))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var rendered := stage.get_texture().get_image()
		captures.append(rendered)
		var clock=row.get_child(3).get_node("CameoWipe")
		var rect: Rect2=clock.clock_rect()
		var radius: float=minf(rect.size.x,rect.size.y)*0.5-2.0
		var point: Vector2=clock.global_position+rect.get_center()+Vector2(0,radius)
		var expected := Clock.color_for(faction)
		var closest := 10.0
		for x in range(-1,2):
			for y in range(-1,2):
				var pixel := rendered.get_pixel(int(point.x)+x,int(point.y)+y)
				closest=minf(closest,absf(pixel.r-expected.r)+absf(pixel.g-expected.g)+absf(pixel.b-expected.b))
		check(closest<0.15,"actual 75% ring renders faction accent "+faction,closest)
	stage.get_texture().get_image().save_png(output_dir.path_join("faction-clock-preview.png"))
	check(captures.size()==3,"rendered three faction rows")
	layer.free()
