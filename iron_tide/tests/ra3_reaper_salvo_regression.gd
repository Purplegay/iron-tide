extends "res://tests/allied_abilities_regression.gd"
const Soviet=preload("res://scripts/units/ra3_soviet.gd")
func exercise_mode(mode:String) -> void:
	if mode==MatchRules.RA2 or DisplayServer.get_name()=="headless":return
	setup_logistics_scene(mode,"苏俄")
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var base_pos:=Vector2(1530,1420)
	var target=actor("MTNK","enemy",base_pos+Vector2(195,0));target.hp=100000;target.max_hp=100000
	battle.camera.position=base_pos+Vector2(90,0);battle.camera.reset_smoothing();battle.camera.force_update_scroll()
	var tanks:Array=[]
	for i in 3:
		var unit=actor("R3REAPER","ally",base_pos+Vector2(0,(i-1)*30))
		unit.set_selected(true);unit.attack_target=target;unit.attack_ordered=true
		unit.hull_angle=unit.position.angle_to_point(target.position);unit.turret_angle=unit.hull_angle
		tanks.append(unit)
	await RenderingServer.frame_post_draw
	seed(731)
	var frames:Array[float]=[]
	var peak:=0
	var owners:Dictionary={}
	var reused:=0
	var fired:=0
	var fire_us:=0;var travel_us:=0;var hit_us:=0;var fx_us:=0
	for frame in 140:
		var start:=Time.get_ticks_usec()
		var before:int=battle.projectiles_root.get_child_count()
		for unit in tanks:
			Soviet.tick(unit,1.0/60);Soviet.fire(unit)
		var projectiles:Array=battle.projectiles_root.get_children()
		fired+=projectiles.size()-before
		fire_us+=Time.get_ticks_usec()-start
		for i in range(before,projectiles.size()):
			var shot=projectiles[i]
			var render=shot.get_node_or_null("ReaperRound")
			if render==null:continue
			var key:int=render.get_instance_id()
			if owners.has(key) and owners[key]!=shot.get_instance_id():reused+=1
			owners[key]=shot.get_instance_id()
		for shot in battle.projectiles_root.get_children():
			if not shot is Projectile or shot.is_queued_for_deletion():continue
			shot.set_physics_process(false)
			var t:=Time.get_ticks_usec()
			Soviet.advance(shot,1.0/60)
			if shot.is_queued_for_deletion():hit_us+=Time.get_ticks_usec()-t
			else:travel_us+=Time.get_ticks_usec()-t
		var particles:=0
		var t:=Time.get_ticks_usec()
		for fx in battle.get_tree().get_nodes_in_group("reaper_particles"):
			if battle.is_ancestor_of(fx) and not fx.is_queued_for_deletion():
				fx._process(1.0/60)
				if "rows" in fx:particles+=fx.rows.size()
		fx_us+=Time.get_ticks_usec()-t
		peak=maxi(peak,particles)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		frames.append((Time.get_ticks_usec()-start)/1000.0)
	frames.sort()
	print("SALVO shots=",fired," reused=",reused," hp=",target.hp," peak=",peak," cpu_ms launch/travel/hit/particles=",[fire_us/1000.0,travel_us/1000.0,hit_us/1000.0,fx_us/1000.0]," p50/p95/max_ms=",[frames[70],frames[133],frames[-1]])
	check(fired==57 and target.hp<100000,"real volleys fire and deal damage")
	check(reused>0,"native renderers reused for later shots",reused)
	check(peak>0 and peak<520,"salvo retains impact and trail particles within budget",peak)
	var pool=battle.get_node_or_null("ReaperRoundPool")
	check(pool!=null and pool.get_child_count()>0 and pool.get_child_count()<=24,"retired native renderers are bounded and reusable")
	if pool!=null:
		check(pool.get_children().all(func(r):return not r.is_visible_in_tree() and r.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and not r.is_in_group("ra3_weapon_fx_captures")),"idle renderers spend no capture budget")
	screen.free();await get_tree().process_frame
