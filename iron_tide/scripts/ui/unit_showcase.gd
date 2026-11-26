extends TextureRect
## A live display model in a private world. Only visual clocks advance here.
# Flight height is meaningful on a battlefield. This camera frames the model itself.
class DisplayUnit extends Unit:
	var trial:Dictionary={}
	func cosmetic_preview_travel(delta:float) -> Vector2:
		return velocity*delta
	func cosmetic_outfit() -> Dictionary:
		if special.has("academy_hero"): return {}
		return super.cosmetic_outfit().merged(trial,true)
	func _visual_lift() -> float:
		return night_skin.hover_lift(self,true) if night_skin!=null else 0.0

enum ViewMode { SPIN, INSPECT, RETURN }
const IDLE_SECONDS := 5.0
const SPIN_SPEED := 0.63
var view_mode := ViewMode.SPIN
var view_heading := 0.0
var idle_seconds := 0.0
var crystal_refresh_clock := 0.0
var dragging := false
var actor: DisplayUnit
# Short sample behind the model, using the same texture and spacing as the battle renderer.
class TrackSample extends Node2D:
	const PAIRS := 8
	var spacing:=0.0
	var rear:=0.0
	var phase:=0.0
	var tread:Texture2D
	func print_center(i:int,side:int) -> Vector2:
		return Vector2(-rear-i*VehicleTracks.STEP-phase,spacing*side)

	func _draw() -> void:
		if tread==null:return
		for i in PAIRS:
			for sign_y in [-1,1]:
				var pos:=print_center(i,sign_y)
				draw_texture_rect(tread,Rect2(pos-Vector2(2.65,3.2),Vector2(5.3,6.4)),false)

var track_sample:=TrackSample.new()
var edit_mount := ""
var track_demo_time := 0.0
var track_arrow: Node2D
var viewport: SubViewport
var age := 0.0
var playing:=true
var playback_speed:=1.0
class DemoTarget extends Node2D:
	var hp := 1.0
	var _dead := false

var primary: DemoTarget
var secondary: DemoTarget
const MAIN_POINT := Vector2(309,51)
const SIDE_POINT := Vector2(283,136)
const Split = preload("res://scripts/units/ra3_reaper_split.gd")
var unit_id := ""
var demo := ""
var rank := 0
const SIZE := Vector2i(430, 172)
const POLAR_SIZE:=Vector2i(960,600)
var workshop_view:=false
var hero_gallery:=false

func _ready() -> void:
	custom_minimum_size = Vector2(240, 158)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.world_2d = World2D.new()
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	add_child(viewport)
	viewport.add_child(track_sample)
	track_sample.hide()
	texture = viewport.get_texture()
	visibility_changed.connect(_visibility)
	_visibility()

func _visibility() -> void:
	var active := is_visible_in_tree()
	if not active:dragging=false
	set_process(active)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if actor != null: actor.process_mode = Node.PROCESS_MODE_INHERIT if active and view_mode==ViewMode.SPIN else Node.PROCESS_MODE_DISABLED

func try_outfit(slot:String,value:String) -> void:
	if actor==null:return
	if slot == "track" and not VehicleTracks.supports_tire_skin(unit_id): return
	if slot=="skin" and actor.unit_id=="GGI" and actor.is_deployed():actor.set_deployed(false,false)
	actor.trial[slot]=value
	if slot=="skin":
		actor.special.erase("cobalt_travel")
		actor.tank_finish=null
	refresh_outfit()

func refresh_outfit() -> void:
	if actor == null:return
	actor.refresh_house_color()
	if actor._ra3_model != null:
		preload("res://scripts/units/unit_cosmetics.gd").install(actor._ra3_model,actor.cosmetic_outfit(),edit_mount)
		actor._ra3_model.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_frame_model()
	actor.queue_redraw()

func show_unit(id: String, talent := "", level := 0) -> void:
	if actor != null: actor.free()
	if primary != null: primary.free()
	if secondary != null: secondary.free()
	set_track_preview(false)
	edit_mount = ""
	unit_id = id
	demo = talent
	rank = level
	dragging = false
	age = 0.0
	view_heading = 0.0
	view_mode = ViewMode.SPIN
	idle_seconds = 0.0
	mouse_filter = Control.MOUSE_FILTER_PASS if demo.is_empty() else Control.MOUSE_FILTER_IGNORE
	var data := GameData.get_unit(id)
	if data.is_empty(): return
	actor = DisplayUnit.new()
	actor.set_meta("stack_preview",true)
	actor.setup(data, "ally", Vector2.ZERO)
	actor.collision_layer = 0
	actor.collision_mask = 0
	viewport.add_child(actor)
	actor.set_physics_process(false)
	for group in ["combatants","allies","enemy_targets","ground_units","air_units"]:
		if actor.is_in_group(group): actor.remove_from_group(group)
	_frame_model()
	if not demo.is_empty():
		primary = DemoTarget.new()
		secondary = DemoTarget.new()
		viewport.add_child(primary)
		viewport.add_child(secondary)
		primary.position = viewport.canvas_transform.affine_inverse() * MAIN_POINT
		secondary.position = viewport.canvas_transform.affine_inverse() * SIDE_POINT
		actor.attack_target = primary
	_visibility()
	_animate()

func set_track_preview(enabled: bool) -> void:
	track_sample.visible = enabled and demo.is_empty() and VehicleTracks.supports_tire_skin(unit_id)
	track_sample.tread = null
	track_sample.phase = 0.0
	track_demo_time = 0.0
	if is_instance_valid(track_arrow): track_arrow.free()
	if track_sample.visible:
		var chevron: bool = actor.cosmetic_outfit().get("track") == "chevron_track"
		track_sample.tread = VehicleTracks.CHEVRON if chevron else preload("res://assets/ra3/mirage/presentation/EXTireTrack2.png")
	track_sample.queue_redraw()

func _frame_model() -> void:
	track_sample.spacing=16.0 if unit_id=="R3MIRAGE" else actor.radius*0.65
	track_sample.rear=actor.radius*0.6
	track_sample.rotation=actor.hull_angle
	track_sample.queue_redraw()
	var zoom := clampf(61.0/maxf(13.0,actor.radius),1.1,3.6)
	var center:=Vector2(215,86) if demo.is_empty() else Vector2(123,82)
	var polar:bool=workshop_view and unit_id=="APOC" and actor.cosmetic_outfit().get("skin")=="polar_observatory"
	var pika:bool=workshop_view and unit_id=="TTNK" and actor.cosmetic_outfit().get("skin")=="amber_coils"
	var coastal:bool=workshop_view and unit_id=="GGI" and actor.cosmetic_outfit().get("skin")=="cliff_sentry"
	var casemate:bool=workshop_view and unit_id=="TNKD" and actor.cosmetic_outfit().get("skin")=="casemate_frame"
	var solar:bool=workshop_view and unit_id=="SREF" and actor.cosmetic_outfit().get("skin")=="corona_glass"
	var enlarged:=polar or pika or coastal or casemate or solar or (workshop_view and actor.night_skin!=null)
	if workshop_view:
		viewport.size=POLAR_SIZE if enlarged else SIZE
		custom_minimum_size.y=288 if enlarged else 158
	var convoy_gallery:=hero_gallery and unit_id in ["FV","HARV"]
	if hero_gallery:
		viewport.size=Vector2i(960,432) if convoy_gallery else SIZE
		custom_minimum_size.y=220 if convoy_gallery else 158
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR if convoy_gallery else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	if enlarged or convoy_gallery:center=Vector2(viewport.size)*0.5
	var origin:=center+Vector2.DOWN*22
	if actor.hero_art!=null and actor.hero_art.has_method("view_bounds"):
		var box:Rect2=actor.hero_art.view_bounds()
		zoom=minf((viewport.size.x-40)/box.size.x,(viewport.size.y-26)/box.size.y)
		origin=center-box.get_center()*zoom
	elif actor.night_skin!=null:
		var box:Rect2=actor.night_skin.view_bounds(actor)
		zoom=minf((viewport.size.x-24)/box.size.x,(viewport.size.y-16)/box.size.y)
		origin=center-box.get_center()*zoom
	elif actor._ra3_model!=null:
		var model=actor._ra3_model
		var box:AABB=model.hull_bounds
		var bounds:=Rect2()
		# Frame the full rotation, including the tall launcher and equipped wings.
		for i in 8:
			var point:Vector3=box.get_endpoint(i)
			var radius:=Vector2(point.x,point.z).length()
			for z in [-radius,radius]:
				var edge:Vector2=model.draw_rect.position+model.project(Vector3(0,point.y,z))
				if i==0 and z==-radius:bounds=Rect2(edge,Vector2.ZERO)
				else:bounds=bounds.expand(edge)
		if actor.cosmetic_outfit().get("wing","stock")!="stock":
			bounds=bounds.grow_individual(0,0.55*maxf(box.size.x,box.size.z),0,0)
		zoom=minf(zoom,146.0/maxf(1,bounds.size.y))
		origin=center-bounds.get_center()*zoom
	elif not actor._ra2.is_empty():
		var art:=actor._ra2
		var box:=RA2Art.draw_rect(art,actor.radius,[0])
		var roof_lamps:bool=unit_id=="HARV" and actor.cosmetic_outfit().get("skin")=="night_shift"
		if (actor.is_air or roof_lamps or enlarged) and art.get("kind")=="vxl":
			var frames:=range(int(art.facings)*int(art.get("poses",1)))
			var canvas:=RA2Art.draw_rect(art,actor.radius,frames)
			var body:=Rect2()
			for frame in frames:
				var bounds:=RA2Art.visible_sprite_rect(art,canvas,RA2Art.src_rect(art,frame))
				if bounds.has_area():
					body=body.merge(bounds) if body.has_area() else bounds
			if body.has_area():box=body
			zoom=minf(zoom,(SIZE.x-24.0)/maxf(1.0,box.size.x))
		if hero_gallery and unit_id in ["TANY","BORIS"]:
			var guard_frames:=range(8)
			var canvas:=RA2Art.draw_rect(art,actor.radius,guard_frames)
			box=Rect2()
			for frame in guard_frames:
				var visible_body:=RA2Art.visible_sprite_rect(art,canvas,RA2Art.src_rect(art,frame))
				box=box.merge(visible_body) if box.has_area() else visible_body
			box=box.grow_individual(5,26,5,2)
		if roof_lamps:box=box.grow_individual(0,13,0,0)
		if pika:box=box.grow_individual(16,22,16,4)
		elif actor.yr_finish!=null and unit_id in ["SREF","TTNK"]:
			box=box.grow_individual(6,20,6,2)
		if polar:
			# Include the floating rim and the gun barrels at every facing.
			var radius:=actor.radius
			box=box.grow_individual(radius*0.35,radius*(actor.YRFinish.HALO_LIFT+actor.YRFinish.HALO_WIDTH*0.46)+5,radius*0.35,radius*0.5)
		if casemate:box=box.grow_individual(23,6,23,6)
		if coastal:
			# The world-space range fan extends ahead of the deployed infantry in any facing.
			box=Rect2(-31,-43,62,65)
		if enlarged or convoy_gallery:zoom=minf((viewport.size.x-64)/box.size.x,(viewport.size.y-36)/box.size.y)
		else:
			zoom=minf(zoom,147.0/maxf(1.0,box.size.y))
		origin=center-box.get_center()*zoom
	var project := Transform2D(Iso.dir(Vector2.RIGHT)*zoom,Iso.dir(Vector2.DOWN)*zoom,origin)
	viewport.canvas_transform = project

func _inspect() -> void:
	if actor == null or not demo.is_empty():return
	view_mode = ViewMode.INSPECT
	idle_seconds = 0.0
	actor.process_mode = Node.PROCESS_MODE_DISABLED

func _gui_input(event: InputEvent) -> void:
	if actor == null or not demo.is_empty():return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging=true
			_inspect()
		elif dragging:
			dragging=false
		else:return
		accept_event()
	elif event is InputEventMouseMotion and dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT and not event.relative.is_zero_approx():
		_inspect()
		var width:=minf(size.x,size.y*float(viewport.size.x)/viewport.size.y)
		view_heading=wrapf(view_heading-event.relative.x*TAU/maxf(1,width),-PI,PI)
		_display_heading()
		accept_event()

func _display_heading() -> void:
	actor.hull_angle=view_heading
	track_sample.rotation=view_heading
	if is_instance_valid(track_arrow): _align_preview_arrow()
	actor.turret_angle=view_heading
	var model=actor._ra3_model
	if model!=null:
		model.sync_pose()
		model.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	actor.queue_redraw()

func _align_preview_arrow() -> void:
	track_arrow.heading = track_sample.rotation
	track_arrow.position = track_sample.to_global(track_sample.print_center(TrackSample.PAIRS-1,1))

func _track_parked() -> bool:
	return track_sample.visible and track_sample.tread == VehicleTracks.CHEVRON and track_demo_time >= 1.5

func _process(delta: float) -> void:
	if actor==null:return
	if actor.night_skin!=null:actor.night_skin.tick(actor,delta)
	if actor.hero_art!=null:
		if actor.hero_art.has_method("preview_cycle"):actor.hero_art.preview_cycle(actor,age)
		actor.hero_art.tick(actor,delta if playing else 0.0)
	if actor.peregrine_fx!=null:actor.peregrine_fx.tick(actor,delta*playback_speed if playing else 0.0)
	if not demo.is_empty():
		if not playing:return
		delta*=playback_speed
	if track_sample.visible:
		var before := track_demo_time
		track_demo_time = fposmod(track_demo_time + delta, 1.5 + VehicleTracks.Arrow.LIFE)
		if _track_parked():
			if before < 1.5:
				if is_instance_valid(track_arrow): track_arrow.free()
				track_arrow = VehicleTracks.Arrow.new()
				viewport.add_child(track_arrow)
				_align_preview_arrow()
		else:
			track_sample.phase = fposmod(track_sample.phase + delta*13, VehicleTracks.STEP)
			track_sample.queue_redraw()
	if view_mode!=ViewMode.SPIN and actor.tank_finish!=null and actor.tank_finish.skin==4:
		actor.tank_finish.tick(actor,delta)
	if view_mode==ViewMode.INSPECT:
		if actor._ra3_model != null and actor.cosmetic_outfit().get("top") == "crystal":
			crystal_refresh_clock += delta
			if crystal_refresh_clock >= 1.0 / 15.0:
				crystal_refresh_clock = 0.0
				actor._ra3_model.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		idle_seconds+=delta
		if idle_seconds<IDLE_SECONDS:return
		view_mode=ViewMode.RETURN
	if view_mode==ViewMode.RETURN:
		view_heading=rotate_toward(view_heading,0.0,TAU*delta)
		_display_heading()
		if absf(angle_difference(view_heading,0.0))<0.0001:
			view_heading=0.0
			view_mode=ViewMode.SPIN
			_visibility()
		return
	var previous_age:=age
	age += delta
	if not demo.is_empty():age=fposmod(age,demo_duration())
	if actor.tank_finish!=null:
		if actor.tank_finish.skin==5 and floori(previous_age/3.0)!=floori(age/3.0):actor.tank_finish.shell_hit()
		actor.tank_finish.tick(actor,delta,true)
	if not _track_parked(): view_heading=wrapf(view_heading+SPIN_SPEED*delta,-PI,PI)
	_animate()
	if hero_gallery and actor.special.get("hero_skin",false) and unit_id in ["TANY","BORIS"] and demo.is_empty():
		var phase:=fposmod(age,1.6)
		actor._fire_anim_time=phase if phase<0.26 else -1.0
		if floori(previous_age/1.6)!=floori(age/1.6):
			var look:=Unit.CommandoFx.LASER if unit_id=="TANY" else Unit.CommandoFx.SODA
			var muzzle:=Unit.CommandoSkin.shot_origin(actor,actor.global_position)
			var direction:=Iso.dir(Vector2.from_angle(view_heading)).normalized()
			var end:=muzzle+RA2Art.art_dir(Vector2(direction.x*41,direction.y*16))
			Unit.CommandoFx.spawn(viewport,look,muzzle,end)
			Unit.CommandoFx.spawn(viewport,look,end,end,true)
	if actor.casemate_thruster!=null:
		actor.casemate_thruster.advance_lights(true,delta)
		actor.casemate_thruster.tick(actor,delta)
	if actor.yr_finish!=null and demo.is_empty():
		_preview_finish(previous_age,delta)

func _preview_finish(previous:float,delta:float) -> void:
	var phase:=fmod(age,4.0)
	if unit_id=="GGI":
		var deploy:=phase>1.5 and phase<3.6
		if actor.is_deployed()!=deploy:actor.set_deployed(deploy,false)
		if deploy:actor.velocity=Vector2.ZERO
	elif (unit_id=="SREF" and phase>1.0) or (unit_id=="APOC" and phase>=1.5):actor.velocity=Vector2.ZERO
	actor.yr_finish.tick(actor,delta,fmod(age,2.0)*0.5)
	var first:=floori(age)!=floori(previous)
	var second_barrel:=unit_id=="APOC" and floori(age)%4!=3 and floori(age-0.12)!=floori(previous-0.12) and age>0.12
	if first or second_barrel:
		var aa:=unit_id=="APOC" and floori(age)%4==3
		var barrel:=int(second_barrel) if unit_id=="APOC" and not aa else -1
		var weapon:Dictionary=actor.data.get("anti_air_weapon",{}) if aa else actor._active_weapon()
		actor.aim_dir=Vector2.from_angle(actor.hull_angle)
		actor.yr_finish.fire(barrel,weapon,Iso.dir(actor._weapon_muzzle(barrel)-actor.global_position))
		if unit_id=="GGI" and actor.is_deployed() and floori(age)%4==2:actor.yr_finish.mount_hit()

func _demo_clock() -> float:
	return fmod(age,demo_duration())

func reverse_demo_geometry() -> Dictionary:
	var inverse:=viewport.canvas_transform.affine_inverse()
	var center:Vector2=inverse*Vector2(123,104)
	var end:Vector2=inverse*Vector2(65,58)
	var start:float=center.direction_to(inverse*MAIN_POINT).angle()
	var heading:float=end.direction_to(center).angle()
	var rate:=deg_to_rad(float(actor._mv("rot",0.0)))
	return {"center":center,"end":end,"start":start,"heading":heading,"turn":absf(angle_difference(start,heading))/rate if rate>0 else 0.0}

const PoolTalents = preload("res://scripts/ui/pool_talent_demo.gd")

func demo_duration() -> float:
	if demo == "fleet_rockets":return 2.0*PoolTalents.value(self)+3.0
	if demo == "fv_intercept":return PoolTalents.value(self)+3.0
	if demo in preload("res://scripts/ui/expansion_2_demo.gd").TALENTS:return preload("res://scripts/ui/expansion_2_demo.gd").duration(demo)
	if demo=="lost_missile":return preload("res://scripts/ui/lost_missile_demo.gd").duration()
	if demo==Unit.YRTalents.REVERSE and actor!=null:
		return reverse_demo_geometry().turn+float(MetaProgress.talent_options(unit_id)[demo].heal_seconds[rank])+1.0
	if demo == "tesla_reserve":
		var config: Dictionary = MetaProgress.talent_options(unit_id)[demo]
		return float(config.intervals[rank]) * int(config.stack_limits[rank]) + 1.6
	if demo==Unit.YRTalents.GROWTH:
		return float(MetaProgress.talent_options(unit_id)[demo].intervals[rank])*3+3
	if demo=="reaper_fire_control" and rank>0:
		var rule:Dictionary=MetaProgress.talent_options(unit_id)[demo].ranks[rank-1]
		var cap:=ceili(float(rule.linger)/float(rule.charge_seconds))
		return 1.8+float(rule.charge_seconds)*cap+2.0
	return 8.0

func _animate() -> void:
	if actor == null: return
	var heading := view_heading
	if not demo.is_empty() and unit_id!="R3REAPER":
		var center:=viewport.canvas_transform.affine_inverse()*Vector2(123,104)
		var target_point:=viewport.canvas_transform.affine_inverse()*MAIN_POINT
		heading=center.direction_to(target_point).angle()
		actor.position=center
		if demo in ["fleet_rockets","fleet_cannon"]:
			actor.position=viewport.canvas_transform.affine_inverse()*(Vector2(94,105)+Vector2(52,-14)*(_demo_clock()/demo_duration()))
		if demo==Unit.YRTalents.REVERSE:
			var route:=reverse_demo_geometry()
			var clock:=_demo_clock()
			heading=lerp_angle(route.start,route.heading,clampf(clock/maxf(0.001,route.turn),0,1))
			actor.position=route.center.lerp(route.end,clampf((clock-route.turn)/2.0,0,1))
		if unit_id=="DESO":
			var deployed:=true
			if demo==Unit.YRTalents.GROWTH:deployed=_demo_clock()<float(MetaProgress.talent_options(unit_id)[demo].intervals[rank])*3+1.5
			if actor.is_deployed()!=deployed:actor.set_deployed(deployed,false)
	elif demo != "":
		var bearing:=primary.position.angle()
		heading = bearing if demo==Split.ID else lerp_angle(bearing-1.7,bearing,smoothstep(0.0,1.8,_demo_clock()))
		if demo==Split.ID:
			actor.hull_angle=heading
			if _demo_clock()>1.0:
				actor.special.split_primary=primary
				actor.special.split_enemy=secondary
				actor.special.split_side_index=Split.choose_side(actor,secondary)
			else:Split.clear(actor)
	actor.hull_angle = heading
	track_sample.rotation=heading
	actor.turret_angle = heading
	if demo==Unit.YRTalents.REVERSE:actor.turret_angle=actor.position.direction_to(viewport.canvas_transform.affine_inverse()*MAIN_POINT).angle()
	if unit_id=="HARV" and actor.cosmetic_outfit().get("skin")=="night_shift":
		actor.cargo=actor.cargo_cap*fposmod(age/5.0,1.0)
	actor._anim = age
	actor._walk_phase = fposmod(age*1.4,1.0)
	actor.velocity = Vector2.from_angle(heading)*42 if demo.is_empty() and not _track_parked() else Vector2.ZERO
	if demo==Unit.YRTalents.REVERSE:
		var route:=reverse_demo_geometry()
		if _demo_clock()>route.turn and _demo_clock()<route.turn+2:actor.velocity=(route.end-route.center)/2.0
	if demo=="dive_momentum":preload("res://scripts/ui/dive_momentum_demo.gd").animate(self)
	if demo=="lost_missile":preload("res://scripts/ui/lost_missile_demo.gd").animate(self)
	if demo in preload("res://scripts/ui/expansion_2_demo.gd").TALENTS:preload("res://scripts/ui/expansion_2_demo.gd").animate(self)
	actor.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if demo.is_empty() or actor == null: return
	var scale_factor:=minf(size.x/SIZE.x,size.y/SIZE.y)
	draw_set_transform((size-Vector2(SIZE)*scale_factor)*0.5,0,Vector2.ONE*scale_factor)
	var clock:=_demo_clock()
	if demo in PoolTalents.IDS:
		PoolTalents.paint(self,clock)
		return
	if demo in preload("res://scripts/ui/expansion_2_demo.gd").TALENTS:
		preload("res://scripts/ui/expansion_2_demo.gd").draw_talent(self,clock)
		return
	if demo=="lost_missile":
		preload("res://scripts/ui/lost_missile_demo.gd").draw(self,clock)
		return
	if demo=="dive_momentum":
		preload("res://scripts/ui/dive_momentum_demo.gd").draw(self,clock)
		return
	if unit_id!="R3REAPER":
		_draw_yr_talent(clock)
		return
	var split:=demo==Split.ID
	for i in Split.Pose.definitions.grenade_mounts.size():
		var diverted: bool=split and actor.special.get("split_side_index",-1)==i
		var target=secondary if diverted else primary
		var mount:Dictionary=Split.Pose.definitions.grenade_mounts[i]
		if not Split.covers(actor,target,mount):continue
		var origin:=viewport.canvas_transform*actor.position
		if actor._ra3_model != null:
			var model=actor._ra3_model
			var bone:int=model.rig.find_bone(mount.bone)
			if bone>=0:
				var socket:Vector3=model.hull.transform * model.rig.get_bone_global_pose(bone).origin
				origin+=(model.draw_rect.position+model.project(socket))*viewport.canvas_transform.x.length()/Iso.dir(Vector2.RIGHT).length()
		_trace(origin,SIDE_POINT if diverted else MAIN_POINT,Color("#73d7ff") if diverted else Color("#e8b74c"),clock+i*0.18)
	_marker(MAIN_POINT,"主目标",Color("#ffc964"))
	if split:
		_marker(SIDE_POINT,"E 副目标",Color("#73d7ff"))
		if rank>0 and clock>1.0:
			var mult:float=MetaProgress.talent_options(unit_id)[demo].ranks[rank-1].damage
			draw_string(ThemeDB.fallback_font,SIDE_POINT+Vector2(12,21),"Split ×%.2f"%mult,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.SKY_BLUE)
	elif rank>0:
		var rule:Dictionary=MetaProgress.talent_options(unit_id)[demo].ranks[rank-1]
		var stacks:=mini(ceili(float(rule.linger)/float(rule.charge_seconds)),floori(maxf(0,clock-1.8)/float(rule.charge_seconds)))
		preload("res://scripts/ui/talent_stack_indicator.gd").paint(self,viewport.canvas_transform*actor.position,"主热",stacks,ceili(float(rule.linger)/float(rule.charge_seconds)),28)

func _draw_yr_talent(clock:float) -> void:
	var rule:Dictionary=MetaProgress.talent_options(unit_id)[demo]
	var amount:float=rule.base if rank==0 else rule.ranks[rank-1].value
	var origin:=viewport.canvas_transform*actor.position
	var label:=""
	match demo:
		"tesla_reserve":
			var limit: int = rule.stack_limits[rank]
			# Briefly show full charge before the illustrative shot consumes it.
			var duration: float = float(rule.intervals[rank]) * limit + 0.6
			var fired := clock >= duration
			var stacks := 0 if fired else mini(limit, floori(clock / float(rule.intervals[rank])))
			preload("res://scripts/ui/talent_stack_indicator.gd").paint(self,origin,"蓄电",stacks,limit,24)
			if fired: _trace(origin, MAIN_POINT, Color.SKY_BLUE, clock-duration)
			_marker(MAIN_POINT,"目标",Color.SKY_BLUE)
			label = "开火 +%d%% · 层数清空" % roundi(amount*limit) if fired else "蓄电 %d/%d · 下次攻击 +%d%% · 每 %s 秒一层" % [stacks,limit,roundi(amount*stacks),str(rule.intervals[rank])]
		Unit.YRTalents.GROWTH:
			var interval:float=rule.intervals[rank]
			var stacks:=mini(3,floori(clock/interval)) if actor.is_deployed() else 0
			var cells:=amount*stacks/3.0
			var radius:=34.0+cells*9.0
			if actor.is_deployed():
				var outline:=PackedVector2Array()
				for i in 49:
					var direction:=Vector2.from_angle(TAU*i/48.0)
					outline.append(origin+direction*Vector2(radius,radius*0.45))
				draw_colored_polygon(outline,Color(0.32,0.85,0.18,0.23))
				draw_polyline(outline,Color.GREEN_YELLOW,2,true)
			label="扩散 %d/3 层 · 半径 +%.2f 格 · 每 %s 秒叠层" % [stacks,cells,str(interval)] if actor.is_deployed() else "起身 · 扩散层数清空"
			preload("res://scripts/ui/talent_stack_indicator.gd").paint(self,origin,"扩散",stacks,3,24)
		Unit.YRTalents.REVERSE:
			var route:=reverse_demo_geometry()
			var endpoint:=Vector2(65,58)
			draw_dashed_line(Vector2(123,104),endpoint,Color.AQUAMARINE,2)
			draw_circle(endpoint,5,Color.AQUAMARINE,false,2)
			_trace(origin,MAIN_POINT,Color.SKY_BLUE,clock)
			draw_rect(Rect2(50,136,94,6),Color("#374350"))
			var duration:float=rule.heal_seconds[rank]
			var healing:=maxf(0,clock-route.turn)
			draw_rect(Rect2(50,136,94*(0.50+minf(healing,duration)*0.01),6),Color.GREEN_YELLOW)
			var phase:="自动转向 · 尚未回血" if clock<route.turn else ("沿路线倒车" if healing<2 else ("停车回血" if healing<duration else "回血结束"))
			label="%s · 速度 %d%% · 回血 %.1f 秒 · 冷却 %.1f 秒" % [phase,amount,maxf(duration-healing,0),maxf(Unit.YRTalents.REVERSE_COOLDOWN-clock,0)]
		Unit.YRTalents.BOOK:
			var returning:=clock>=3
			if clock<2 or returning:_trace(origin,MAIN_POINT,Color.SKY_BLUE,clock)
			_marker(MAIN_POINT,"目标",Color.SKY_BLUE)
			label="中断 · 书签有效 %d 秒" % amount if clock>=2 and not returning else ("重连 · 继承一半进度" if returning else "持续擦除")
			label+=" · 攻击间隔 -%d%%" % rule.cooldown_reduction[rank]
		Unit.YRTalents.SPLIT:
			var side_a:=MAIN_POINT+Vector2(-54,48)
			var side_b:=MAIN_POINT+Vector2(36,48)
			for pt in [MAIN_POINT,side_a,side_b]:draw_rect(Rect2(pt-Vector2(13,10),Vector2(26,20)),Color("#936951"))
			_trace(origin,MAIN_POINT,Color.GOLD,clock)
			if clock>0.6:
				for pt in [side_a,side_b]:_trace(MAIN_POINT,pt,Color.SKY_BLUE,clock-0.6)
			label="Split · 相邻建筑各受 %d%% 炮击伤害" % amount
	draw_string(ThemeDB.fallback_font,Vector2(10,163),label,HORIZONTAL_ALIGNMENT_CENTER,405,15,Color.WHITE)

func _trace(from:Vector2,to:Vector2,color:Color,t:float) -> void:
	draw_dashed_line(from,to,Color(color,0.45),1.2,5)
	draw_circle(from.lerp(to,fposmod(t*1.8,1.0)),3,color)

func _marker(at:Vector2,label:String,color:Color) -> void:
	draw_arc(at,8,0,TAU,20,color,2,true)
	draw_string(ThemeDB.fallback_font,at+Vector2(15,5),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
