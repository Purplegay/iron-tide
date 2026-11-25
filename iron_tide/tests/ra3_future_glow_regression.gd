extends "res://tests/allied_abilities_regression.gd"

# Reference renderer reproduces the previous unbounded SDR accumulation.
class LegacyGlow extends Node2D:
	var visual
	func _draw() -> void:
		Iso.begin(self)
		for g: Dictionary in visual.glows:
			var t: float=visual.age-float(g.born)
			var size_: float=(g.size+g.rate*visual.Particle.integral(t*30,g.damping))*3.0
			var tint: Color=g.color;tint.a=1.0-t/float(g.life)
			draw_texture_rect(visual.flare,Rect2(Iso.dir(g.point)-Vector2.ONE*size_/2,Vector2.ONE*size_),false,tint)

func snapshot(view: SubViewport, label: String) -> Dictionary:
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for i in 3:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture:=view.get_texture().get_image();picture.save_png(output_dir.path_join(label+".png"))
	var white:=0;var visible_pixels:=0;var energy:=0.0
	for y in range(0,picture.get_height(),2):
		for x in range(0,picture.get_width(),2):
			var c:=picture.get_pixel(x,y)
			if minf(c.r,minf(c.g,c.b))>0.85:white+=1
			if maxf(c.r,maxf(c.g,c.b))>0.02:visible_pixels+=1
			energy+=c.r+c.g+c.b
	return {"white":white,"visible":visible_pixels,"energy":energy}

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var unit=actor("R3FUTURE","ally",Vector2(1600,1600))
	battle.camera.position=Vector2(1750,1600);battle.camera.zoom=Iso.cam_zoom(1.5)
	battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	battle._ensure_visual_layers()
	var post=battle._post_layer
	var patch:=Rect2i(495,210,32,32)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var neutral:Image=stage.get_texture().get_image().get_region(patch)
	for heroic in [false,true]:
		var orb=Ra3Expansion.make_shot(unit,null,Vector2(1860,1600),"neutron")
		orb.splinters.heroic=heroic
		var peak:=0.0
		var far_change:=0.0
		var lit:=false
		for tick in 120:
			Ra3Expansion.tick_shot(orb,1.0/30)
			var visual=orb.get_node_or_null("NativeFx")
			if visual==null:continue
			visual.age=orb.splinters.age
			visual._sample()
			lit=lit or visual.rows.any(func(row):return row.node is OmniLight3D and row.node.visible and row.node.light_energy>0)
			post._process(1.0/30)
			peak=maxf(peak,post.exposure_ev)
			if tick%12==0:
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				far_change=maxf(far_change,patch_delta(neutral,stage.get_texture().get_image().get_region(patch)))
		check(lit,"neutron XML point light still active")
		check(peak==0.0 and far_change<0.001,"neutron impact preserves battlefield exposure and remote terrain",[heroic,peak,far_change])
		orb.free()
		post.clear_exposure()
		var label:="heroic" if heroic else "normal"
		var shot=Ra3Expansion.make_shot(unit,null,Vector2(1860,1600),"riot")
		shot.splinters.heroic=heroic;shot.splinters.origin=unit.position
		shot.splinters.muzzles=Ra3Expansion.riot_muzzles(unit)
		preload("res://scripts/units/ra3_future_beam.gd").spawn(shot)
		var fx=get_tree().get_nodes_in_group("ra3_future_beams")[-1];fx.set_process(false)
		for i in range(1,49):
			shot.splinters.age=i/60.0;fx._process(1.0/60.0)
		post._process(1.0/60)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var change:=patch_delta(neutral,stage.get_texture().get_image().get_region(patch))
		check(post.exposure_ev==0 and change<0.001,label+": Q leaves remote terrain stable",change)
		var counts: PackedInt32Array=fx.glow_counts()
		check(counts[2]>=23 and counts[3]>=23,label+": original 30 Hz endpoint particles retained")
		check(fx.glows.all(func(g):return is_equal_approx(float(g.life),1.0)),label+": original one-second particle life retained")
		var energy: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
		for g: Dictionary in fx.glows:
			var c: Color=fx.glow_tint(g,counts)
			energy[g.emitter]+=Vector3(c.r,c.g,c.b)*c.a
		check(energy.all(func(c):return maxf(c.x,maxf(c.y,c.z))<=0.35),label+": each emitter has bounded SDR energy after repeated emission")
		await snapshot(stage,label+"-battle")
		var view:=SubViewport.new();view.size=stage.size;view.transparent_bg=true
		view.world_2d=World2D.new();add_child(view);view.canvas_transform=stage.get_canvas_transform()
		fx.reparent(view,false)
		for beam in fx.beams:beam.visible=false
		var current:=await snapshot(view,label+"-glow-corrected")
		fx.visible=false
		var legacy:=LegacyGlow.new();legacy.visual=fx;view.add_child(legacy)
		var mat:=CanvasItemMaterial.new();mat.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;legacy.material=mat
		var previous:=await snapshot(view,label+"-glow-before")
		check(previous.white>10,label+": 60 FPS reproduction confirms large white regions in previous renderer",previous)
		check(current.white==0 and current.visible>20,label+": corrected render retains colored glow without saturated white regions",current)
		legacy.free();fx.visible=true
		shot.splinters.age=1.4;fx._process(0.6)
		var tail:=await snapshot(view,label+"-glow-tail")
		check(tail.energy<float(current.energy)*0.7,label+": residual light fades after firing stops",tail)
		fx.reparent(battle,false);view.free()
		fx.free();shot.free()
	screen.free();await get_tree().process_frame

func patch_delta(a:Image,b:Image) -> float:
	var total:=0.0
	for y in a.get_height():
		for x in a.get_width():
			total+=absf(a.get_pixel(x,y).get_luminance()-b.get_pixel(x,y).get_luminance())
	return total/(a.get_width()*a.get_height())
