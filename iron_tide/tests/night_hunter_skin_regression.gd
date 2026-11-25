extends "res://tests/base_recovery_regression.gd"
const NightLooks=preload("res://scripts/units/night_hunter_skin.gd")
const Picker=preload("res://scripts/ui/unit_skin_picker.gd")
const Showcase=preload("res://scripts/ui/unit_showcase.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	await get_tree().process_frame
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		for id:String in NightLooks.SKINS:exercise(id)
		await finish()
	if DisplayServer.get_name()!="headless":await render_cases()
	FileAccess.open(output_dir.path_join("night-hunter-result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"rendered":DisplayServer.get_name()!="headless"},"  "))
	print("NIGHT_HUNTER_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func exercise(id:String) -> void:
	var skin_id:String=NightLooks.SKINS[id]
	check(Picker.choices(id).has(skin_id),id+" real refit catalog lists skin")
	if not MetaProgress.cosmetic_owned(skin_id):
		MetaProgress.grant("diamonds",6000)
		var before:=MetaProgress.balance("diamonds")
		check(MetaProgress.buy_cosmetic(id,"skin",skin_id) and MetaProgress.balance("diamonds")==before-6000,id+" normal purchase unlocks skin")
	check(MetaProgress.cosmetic_owned(skin_id),id+" paid skin ownership is retained")
	var wallet:Dictionary=MetaProgress.currency.duplicate(true)
	check(MetaProgress.set_cosmetic(id,"skin",skin_id),id+" normal equip/save succeeds")
	check(MetaProgress.currency==wallet,id+" no wallet mutation")
	MetaProgress.unit_cosmetics.clear();MetaProgress.load_save()
	check(MetaProgress.cosmetic_style(id).get("skin")==skin_id,id+" appearance reloads from real save")
	var actor:Unit=battle.spawn_unit(id,"ally",Vector2(1200,1200))
	var enemy:Unit=battle.spawn_unit(id,"enemy",Vector2(1400,1200))
	check(actor.night_skin!=null and enemy.night_skin==null,id+" only equipped owner has runtime model")
	check(actor.radius==enemy.radius and actor.max_hp==enemy.max_hp,id+" visual size does not modify collision or life")
	var rig=actor.night_skin
	var original_color:=HouseColor.player_id
	for entry:Dictionary in HouseColor.palette():
		HouseColor.set_player(entry.id)
		check(rig.surface.get_shader_parameter("house_color")==HouseColor.player_color(),id+" existing skin follows real color picker: "+str(entry.id))
	HouseColor.set_player(original_color)
	var native:=RA2Art.art("SCHP" if id=="SCHP" else "DRON")
	var original_width:=0.0
	var new_width:=0.0
	for i in 8:
		var native_frame:=i*int(native.get("facings",8))/8 if id=="SCHP" else 48+i
		original_width+=RA2Art.visible_sprite_rect(native,RA2Art.draw_rect(native,actor.radius,range(0,8) if id=="SCHP" else range(48,56)),RA2Art.src_rect(native,native_frame)).size.x
		new_width+=rig.frame_width(i*4)*rig.visual_scale(actor)
	check(is_equal_approx(new_width/original_width,1.0 if id=="SCHP" else 1.4),id+" matches requested native size ratio",new_width/original_width)
	for slot:String in {"paint":"ice","top":"crystal","wing":"angel","weapon_fx":"cyber_hit"}:
		var value:String={"paint":"ice","top":"crystal","wing":"angel","weapon_fx":"cyber_hit"}[slot]
		check(not MetaProgress.Cosmetics.available(id,slot,value),id+" RA3 combination remains reserved: "+slot)
	actor.selected=false;actor.velocity=Vector2.ZERO
	rig.clock=0;var low:float=rig.intensity()
	rig.tick(actor,1.6)
	check(rig.intensity()>low+.65,id+" idle unselected simulation clock brightens light")
	rig.tick(actor,1.6)
	check(is_equal_approx(rig.intensity(),low),id+" full breathing cycle returns to dim")
	var model:Dictionary=rig.model()
	var poses:int=5 if id=="SCHP" else 11
	var tile:int=256 if id=="SCHP" else 192
	check(model.facings==32 and model.poses.size()==poses and model.bounds.size()==poses*32,id+" 32 directions and complete model animation states")
	check(model.method=="single articulated mesh; offline depth-buffered 32-facing bake",id+" one consistent model owns every direction and pose")
	check(not rig.surface.shader.code.contains("blend_amount") and not rig.surface.shader.code.contains("row_a"),id+" shader contains no neighboring-frame fusion")
	var atlas:=NightLooks.asset(rig.key())
	atlas.image=NightLooks.pixels(rig.key())
	check(atlas.image.has_mipmaps(),id+" real imported texture has minification levels")
	check(atlas.image.get_size()==Vector2i(tile*8,tile*(poses*4+1 if id=="SCHP" else poses*4)) and model.texture_tile==tile,id+" compact model atlas dimensions match animation contract")
	check(model.source_sha256.size()==2 and model.revision=="model-20261118",id+" model authoring and renderer have reproducible source hashes")
	check(model.pose_anchors.size()==poses*32,id+" fixed model ground pivot for every pose")
	check(atlas.image.get_pixel(1,1).a==0,id+" background is actually transparent")
	for pose in poses:
		for angle in 32:
			var source:Rect2=rig.motion_source(angle,pose)
			check(Rect2(Vector2.ZERO,atlas.image.get_size()).encloses(source) and atlas.image.get_region(Rect2i(source)).get_used_rect().has_area(),id+" nonempty pose/direction "+str(pose)+"/"+str(angle))
			var cell:Image=atlas.image.get_region(Rect2i(source))
			var clear_border:=true
			for edge:Rect2i in [Rect2i(0,0,3,tile),Rect2i(tile-3,0,3,tile),Rect2i(0,0,tile,3),Rect2i(0,tile-3,tile,3)]:
				if cell.get_region(edge).get_used_rect().has_area():clear_border=false
			check(clear_border,id+" all four gutters prevent neighbouring selection debris "+str(pose)+"/"+str(angle))
			if id=="SCHP":
				rig.body_source=source
				var center:Vector2=rig.rotor_center(angle)
				var anchor:Array=model.pose_anchors[pose*32+angle]
				check((center-Vector2(anchor[0],anchor[1])).is_equal_approx(Vector2(0,-27.6*sqrt(.75)*1.2)),"rotor and model pivot stay registered "+str(pose)+"/"+str(angle))
				check(cell.get_pixelv(Vector2i(center*tile/128)).a>.2,"registered rotor cap lies on visible hull "+str(pose)+"/"+str(angle))
			if id=="DRON":
				var cell_image:Image=atlas.image.get_region(Rect2i(source))
				var bottom:=-1
				var left:=cell_image.get_width();var right:=-1
				for y in cell_image.get_height():
					for x in cell_image.get_width():
						if cell_image.get_pixel(x,y).a>0:
							bottom=maxi(bottom,y);left=mini(left,x);right=maxi(right,x)
				var entry:=pose*32+angle
				check(Vector2(model.pose_anchors[entry][0],model.pose_anchors[entry][1])==Vector2(64,94),"all articulated poses use the same physical ground pivot "+str(entry))
				check(is_equal_approx(float(model.bounds[entry][2]),float(right-left+1)*128/tile),"size uses visible body without transparent residue "+str(entry))
	if id=="DRON":
		for pose in model.leg_rig.size():
			var legs:Array=model.leg_rig[pose]
			var grounded:=0
			check(legs.size()==4,"every baked gait pose contains exactly four articulated legs")
			for leg:Dictionary in legs:
				check(float(leg.foot[2])>=0,"feet never penetrate the ground plane")
				if float(leg.foot[2])<.001:grounded+=1
			if pose<9:check(grounded>=2,"at least a diagonal pair supports every grounded gait pose")
			else:check(grounded==0,"pounce poses intentionally retract or extend all four airborne feet")
	if id=="SCHP":
		hover_cases(actor)
		check(rig.exhaust.visible(actor,0) and not rig.exhaust.visible(actor,1),"exhaust runs in flight and stops when deployed")
		for direction in 32:
			check(rig.exhaust.vertices(direction,rig.visual_scale(actor),Vector2.ZERO).size()==8,"two cached exhaust quads direction "+str(direction))
		actor.set_deployed(true,false);actor.logistics.tick(15);actor.logistics.tick(actor.logistics.SiegeChopper.duration());rig.tick(actor,.1)
		check(actor.is_deployed() and rig.fold==1.0 and actor.collision_layer==1,"skin follows actual siege deployment")
		actor.set_deployed(false,false);actor.logistics.tick(actor.logistics.SiegeChopper.duration());actor.logistics.tick(15);rig.tick(actor,.1)
		check(not actor.is_deployed() and rig.fold==0.0 and actor.collision_layer==8,"skin follows actual siege takeoff")
	else:
		actor.velocity=Vector2(60,0);rig.tick(actor,.1)
		var initial_phase:float=rig.gait_phase
		actor.hull_angle+=.4;rig.tick(actor,.1)
		check(rig.gait_phase==initial_phase and rig.pose_index(0,.3)==0,"turning or blocked velocity cannot walk in place")
		actor.position.x+=18;rig.tick(actor,.3)
		check(is_equal_approx(rig.gait_phase-initial_phase,.45),"slow gait uses 40 pixel stride without idle phase resets")
		check(rig.pose_index(0,.1)==1 and rig.pose_index(0,.6)==5,"walking advances eight model poses without repeated idle frames")
		actor.velocity=Vector2.ZERO;rig.tick(actor,.1)
		check(rig.pose_index(0,.6)==0,"stopping returns idle without reverse cycling")
		initial_phase=rig.gait_phase;actor.position.x+=30;rig.tick(actor,.1)
		check(is_equal_approx(fposmod(rig.gait_phase-initial_phase,1),.3),"fast movement caps gait at three cycles per second")
		initial_phase=rig.gait_phase;actor.position.x+=1000;rig.tick(actor,.1)
		check(rig.gait_phase==initial_phase,"teleport cannot fast-forward walking")
		actor.position.x-=1048;rig.tick(actor,.1)
		var host:Unit=battle.spawn_unit("HTNK","enemy",Vector2(1250,1200))
		actor.set_stowed(host)
		var stopped:float=rig.clock;rig.tick(actor,.5)
		check(not actor.visible and rig.clock==stopped,"parasite and lights hidden together")
		actor.set_stowed(null);rig.tick(actor,.5)
		check(actor.visible and rig.clock>stopped,"released drone resumes lights")
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	var restored:Unit
	for item in battle.units:
		if item.unit_id==id and item.side=="ally":restored=item
	check(restored!=null and restored.night_skin!=null,id+" battle snapshot restores equipped renderer")
	check(MetaProgress.set_cosmetic(id,"skin","stock"),id+" can restore stock")
	restored.refresh_house_color()
	check(restored.night_skin==null,id+" restoring stock removes runtime renderer")
	check(not MetaProgress.Cosmetics.available("MTNK","skin",skin_id),id+" no unrelated unit can equip")

func hover_cases(actor:Unit) -> void:
	var rig=actor.night_skin
	var saved_seed:=actor._seed;var saved_clock:float=rig.clock;var saved_previous:float=rig.previous_clock
	var saved_lift:float=actor.logistics.air_lift
	var position:=actor.global_position;var collision:=actor.collision_layer;var radius:=actor.radius
	actor._seed=0;actor.logistics.air_lift=1.0
	rig.clock=.8;rig.previous_clock=.8
	check(is_equal_approx(rig.hover_lift(actor),1.8),"idle helicopter reaches subtle hover crest")
	var lifted:float=actor._visual_lift();var muzzle:=actor._weapon_muzzle()
	actor.night_skin=null
	var stock_lift:float=actor._visual_lift()
	actor.night_skin=rig
	check(is_equal_approx(lifted-stock_lift,1.8),"hover passes through canonical visual lift")
	# World coordinates around 1200 lose sub-millipixel precision when subtracted.
	rig.clock=0;rig.previous_clock=0
	var resting_muzzle:=actor._weapon_muzzle()
	rig.clock=.8;rig.previous_clock=.8
	var expected_muzzle:=RA2Art.art_dir(Vector2(0,-1.8))
	check((muzzle-resting_muzzle).distance_to(expected_muzzle)<.001,"baked weapon muzzle shares helicopter hover offset",{"actual":muzzle-resting_muzzle,"expected":expected_muzzle})
	rig.clock=2.4;rig.previous_clock=2.4
	check(is_equal_approx(rig.hover_lift(actor),-1.8),"hover smoothly reaches opposite trough")
	actor.velocity=Vector2(actor.move_speed,0)
	check(is_equal_approx(rig.hover_lift(actor),-.7),"moving helicopter reduces hover amplitude")
	actor.velocity=Vector2.ZERO
	actor.special.siege_progress=.375
	check(is_equal_approx(rig.hover_lift(actor),-.9),"deploying fades hover continuously")
	actor.special.siege_progress=.75
	check(is_zero_approx(rig.hover_lift(actor)),"hover stops before legs finish deployment")
	actor.special.erase("siege_progress");actor.logistics.air_lift=0
	check(is_zero_approx(rig.hover_lift(actor)),"grounded helicopter never bobs")
	check(is_equal_approx(rig.hover_lift(actor,true),-1.8),"skin preview shows the same hover cycle")
	actor._dead=true;check(is_zero_approx(rig.hover_lift(actor,true)),"dead helicopter cannot hover");actor._dead=false
	check(actor.global_position==position and actor.collision_layer==collision and actor.radius==radius,"cosmetic hover never moves gameplay position or collision")
	actor._seed=saved_seed;actor.logistics.air_lift=saved_lift;rig.clock=saved_clock;rig.previous_clock=saved_previous

func rendered_frame() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func rendered_house_colors(preview,id:String) -> void:
	var actor:Unit=preview.actor
	var rig=actor.night_skin
	var original_color:=HouseColor.player_id
	var original_angle:=actor.hull_angle
	for pose in 3:
		for facing in [0,8,16,24]:
			actor.hull_angle=Iso.eff_angle()+facing*TAU/32
			rig.fold=pose*.5 if id=="SCHP" else 0.0;rig.previous_fold=rig.fold
			rig.was_moving=id=="DRON" and pose>0
			rig.gait_phase=.6 if pose==2 else .1;rig.previous_walk=rig.gait_phase
			HouseColor.set_player("red");actor.queue_redraw();await rendered_frame()
			var red:Image=preview.viewport.get_texture().get_image()
			var red_bounds:=actor._body_bounds
			HouseColor.set_player("allied");actor.queue_redraw();await rendered_frame()
			var blue:Image=preview.viewport.get_texture().get_image()
			var colored:=0;var preserved:=0;var alpha_changed:=0
			for y in red.get_height():
				for x in red.get_width():
					var r:=red.get_pixel(x,y);var b:=blue.get_pixel(x,y)
					if absf(r.a-b.a)>.01:alpha_changed+=1
					if r.a<.5:continue
					if absf(r.r-b.r)+absf(r.g-b.g)+absf(r.b-b.b)>.08:colored+=1
					else:preserved+=1
			check(colored>25 and preserved>colored*.25,id+" owner color changes trim while retaining metal "+str(pose)+"/"+str(facing),{"colored":colored,"preserved":preserved})
			check(alpha_changed==0 and actor._body_bounds==red_bounds,id+" owner color preserves silhouette and bounds "+str(pose)+"/"+str(facing))
	HouseColor.set_player(original_color)
	actor.hull_angle=original_angle
	rig.fold=0;rig.previous_fold=0;rig.was_moving=false;rig.gait_phase=0;rig.previous_walk=0

func render_cases() -> void:
	var record:=OS.get_environment("IRON_SKIN_RECORD")=="1"
	var review:=OS.get_environment("IRON_SKIN_REVIEW")=="1"
	var overview:=Image.create(640,480,false,Image.FORMAT_RGBA8)
	var preview=Showcase.new();preview.workshop_view=true;add_child(preview)
	for id:String in NightLooks.SKINS:
		preview.show_unit(id);preview.try_outfit("skin",NightLooks.SKINS[id]);preview.set_process(false)
		var actor:Unit=preview.actor
		actor.hull_angle=Iso.eff_angle()+PI/4;actor.turret_angle=actor.hull_angle;actor.velocity=Vector2.ZERO;actor._walk_phase=0
		await rendered_house_colors(preview,id)
		actor.night_skin.rotor=.3;actor.night_skin.clock=0;actor.queue_redraw()
		await rendered_frame()
		var dim:Image=preview.viewport.get_texture().get_image()
		actor.night_skin.tick(actor,1.6);actor.night_skin.rotor=.3;actor.queue_redraw()
		await rendered_frame()
		var bright:Image=preview.viewport.get_texture().get_image()
		var changed:=0
		for y in dim.get_height():
			for x in dim.get_width():
				if dim.get_pixel(x,y)!=bright.get_pixel(x,y):changed+=1
		check(changed>10,id+" actual rendered idle light pixels change",changed)
		actor.night_skin.surface.set_shader_parameter("lamps_online",false);actor.queue_redraw();await rendered_frame()
		var lamps_off:Image=preview.viewport.get_texture().get_image()
		actor.night_skin.surface.set_shader_parameter("lamps_online",true);actor.queue_redraw();await rendered_frame()
		var lamps_on:Image=preview.viewport.get_texture().get_image()
		check(hash(lamps_off.get_data())!=hash(lamps_on.get_data()),id+" local light halos and lamps shut off independently of body geometry")
		if id=="SCHP":
			actor.night_skin.surface.set_shader_parameter("exhaust_phase",.25);actor.queue_redraw();await rendered_frame()
			var exhaust_before:Image=preview.viewport.get_texture().get_image()
			actor.night_skin.surface.set_shader_parameter("exhaust_phase",.75);actor.queue_redraw();await rendered_frame()
			var exhaust_after:Image=preview.viewport.get_texture().get_image()
			var flowing:=0
			for y in exhaust_before.get_height():
				for x in exhaust_before.get_width():
					if exhaust_before.get_pixel(x,y)!=exhaust_after.get_pixel(x,y):flowing+=1
			check(flowing>10,"exhaust changes actual pixels with body lamps and rotor frozen",flowing)
		check(actor._body_bounds.has_area(),id+" rendered selection bounds exist")
		var point:Vector2=actor.global_position+RA2Art.art_dir(actor._body_bounds.get_center())
		check(actor.hit_test(point),id+" body pixel can be selected")
		check(not actor.hit_test(point+Vector2(1000,1000)),id+" distant pixel rejected")
		if id=="DRON":
			actor.night_skin.was_moving=false;actor.queue_redraw();await rendered_frame()
			var resting:Vector2=actor.night_skin.body_rect.position
			actor.special.pounce={"elapsed":.175,"duration":.35};actor.queue_redraw();await rendered_frame()
			check(int(actor.night_skin.body_source.position.y/192)/4==10,"actual pounce state selects extended four-leg pose")
			check(is_equal_approx(resting.y-actor.night_skin.body_rect.position.y,16),"pounce body and picking follow native leap height")
			actor.special.pounce.elapsed=.02;actor.queue_redraw();await rendered_frame()
			check(int(actor.night_skin.body_source.position.y/192)/4==9,"takeoff selects coiled legs before extension")
			actor.special.erase("pounce");actor.queue_redraw();await rendered_frame()
			check(actor.night_skin.body_rect.position.is_equal_approx(resting),"ending pounce returns to the same ground pivot")
		var motion_dir:=output_dir.path_join(id+"-motion")
		if record:DirAccess.make_dir_recursive_absolute(motion_dir)
		for frame in 96:
			if frame<32:
				actor.hull_angle=Iso.eff_angle()+frame*TAU/32;actor.turret_angle=actor.hull_angle
			elif id=="SCHP":
				actor.special.siege_progress=(frame-32)/31.0 if frame<64 else (95-frame)/31.0
			else:
				actor.velocity=Vector2(40,0) if frame<80 else Vector2.ZERO
				actor._walk_phase=fposmod((frame-32)/16.0,1.0)
			actor.night_skin.tick(actor,1.0/30.0);actor.queue_redraw();await rendered_frame()
			check(actor.night_skin.body_regions.size()==1,id+" exactly one direction/pose drawn at frame "+str(frame))
			if record:preview.viewport.get_texture().get_image().save_png(motion_dir.path_join("%02d.png"%frame))
			if id=="SCHP" and frame in [32,48,63,95]:
				check(is_equal_approx(actor.night_skin.fold,float(actor.special.siege_progress)),"rendered deployment follows real progress "+str(frame))
				check(actor.night_skin.has_gun==(frame in [48,63]),"cannon extends and retracts with deployment "+str(frame))
		actor.special.erase("siege_progress");actor.velocity=Vector2.ZERO
		actor._deployed=false;actor.special.erase("siege_progress");actor.hull_angle=Iso.eff_angle()+PI/4;actor.turret_angle=actor.hull_angle
		var comparison:=Image.create(640,240,false,Image.FORMAT_RGBA8)
		for version in 2:
			preview.try_outfit("skin","stock" if version==0 else NightLooks.SKINS[id])
			preview.viewport.size=Vector2i(320,240)
			preview.viewport.canvas_transform=Transform2D(Iso.dir(Vector2.RIGHT)*2.5,Iso.dir(Vector2.DOWN)*2.5,Vector2(160,155))
			if actor.night_skin!=null:actor.night_skin.tick(actor,.1)
			actor.queue_redraw();await rendered_frame()
			comparison.blit_rect(preview.viewport.get_texture().get_image(),Rect2i(0,0,320,240),Vector2i(version*320,0))
		if record:comparison.save_png(output_dir.path_join(id+"-native-size-comparison.png"))
		if review:overview.blit_rect(comparison,Rect2i(0,0,640,240),Vector2i(0,0 if id=="SCHP" else 240))
		preview.refresh_outfit()
		if id=="SCHP":
			actor._deployed=true;actor.special.erase("siege_progress");actor.night_skin.tick(actor,.1);actor.queue_redraw();await rendered_frame()
			if record:preview.viewport.get_texture().get_image().save_png(output_dir.path_join("SCHP-deployed.png"))
		actor.embarked_in=Unit.new();actor.hide();await rendered_frame()
		check(preview.viewport.get_texture().get_image().get_used_rect().size==Vector2i.ZERO,id+" hidden body produces no separate glow")
		actor.embarked_in.free();actor.embarked_in=null
	if review:overview.save_png(output_dir.path_join("size-and-detail.png"))
	preview.free()
