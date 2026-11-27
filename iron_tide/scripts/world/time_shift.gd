extends RefCounted

const ID := "yr_time_shift"
const TIMERS = preload("res://data/maps/campaign_timer_drivers.json").data.sov01

static func random_timer(id:String) -> float:
	return floorf(float(TIMERS[id].seconds)*randi_range(50,150)/100.0)
const FIELD = preload("res://data/time_shift_field.json")
const POWER_PLANTS := ["GAPOWRA","GAPOWRB","GAPOWRC","GAPOWRD","GAPOWRE","GAPOWRF"]
const ASSETS = preload("res://data/time_shift_assets.json")
const Cleanup = preload("res://scripts/world/time_shift_retail_cleanup.gd")
const Staging = preload("res://scripts/world/time_shift_staging.gd")
const Story = preload("res://scripts/world/time_shift_events.gd")
const Film = preload("res://scripts/ui/hollywood_film.gd")
const OBJECTIVES := ["歼灭港口守军：航母、驱逐舰和岸防巨炮", "登陆后摧毁时光机附近的四座机枪碉堡", "用工程师占领至少四座科技发电厂", "保护时光机，等待重新充能", "摧毁恶魔岛上尚未完工的心灵控制器"]
const BOUNDS := [Rect2i(4,29,52,60),Rect2i(4,104,54,33),Rect2i(4,11,53,126)]

static func wp(index:int) -> Vector2:
	var p:Array=FIELD.data.waypoints[str(index)]
	return Vector2(p[0],p[1])*55

# Public mission locations share the objective checks' live actors, including after restore.
static func radar_marks(world) -> Array:
	var marks:Array=[]
	if world.ended:return marks
	var state:Dictionary=world.allied_state.time_shift
	if state.has("crossing_era"):return marks
	var phase:=int(state.phase)
	var gold:=Color("ffda59")
	if phase==3 or phase==4:
		if phase==4 and not state.get("base_found",false):
			marks.append({"position":wp(104),"title":"接管苏军基地","color":gold,"status":"active"})
		else:
			var site=state.get("machine" if phase==3 else "dominator")
			if world.actor_alive(site):marks.append({"position":site.position,"actor":site,"title":"保护时光机" if phase==3 else "摧毁心灵控制器","color":gold,"status":"active"})
		return marks
	var candidates:Array=world.buildings
	if phase==0:candidates=world.buildings+world.units
	for actor in candidates:
		if not world.actor_alive(actor):continue
		if phase==2:
			if actor.side=="ally" or actor.building_id not in POWER_PLANTS:continue
			marks.append({"position":actor.position,"actor":actor,"title":"占领科技发电厂","color":gold,"status":"active"})
		elif actor.side=="enemy" and actor.special.get("time_shift_tag")==("SP2.1_Destroy_AlliedDef" if phase==0 else "Destroy_Time Defenses"):
			marks.append({"position":actor.position,"actor":actor,"title":"摧毁"+actor.display_name,"color":gold,"status":"active"})
	return marks

# Announce new public objectives once at their phase transition, not on every radar redraw.
static func announce_radar_objectives(world) -> void:
	world.hud.minimap.clear_objective_flashes()
	for mark in radar_marks(world):
		Events.emit_radar_ping(mark.position, "campaign_site")

static func region(cell:Vector2i,area:Rect2i) -> bool:
	var x:=cell.y+10
	var y:=190-cell.x
	return Rect2i(area.position*2,area.size*2).has_point(Vector2i(x-y+57,x+y-59))

static func bounds(world,era:int, inland:=false) -> void:
	world.path_service.time_shift_area=Rect2i(4,29,52,67) if era==0 and inland else BOUNDS[era]
	world.path_service.set_bridge_damage({},[])
	world._refresh_pathing()

static func scenery(world) -> void:
	var root:=Node2D.new()
	root.name="SanFranciscoScenery"
	world.add_child(root)
	var textures:Dictionary={}
	var props:Array=FIELD.data.scenery+FIELD.data.overlay.filter(func(r):return r[0] not in ["CAFNCP","GAWALL"])
	for row in props:
		var id:String=row[0]
		if not textures.has(id):textures[id]=load("res://assets/ra2/time_shift/terrain/%s.png"%id)
		var sprite:=Sprite2D.new()
		sprite.texture=textures[id]
		var pos:=Vector2(row[1],row[2])*55
		sprite.offset.y=-sprite.texture.get_height()*0.5
		sprite.transform=Transform2D(Iso.eff_angle(),Iso.up()*1.30,0,pos)
		sprite.z_index=DepthLayers.entity_z(pos,world.map_size)
		root.add_child(sprite)

static func voice(world,cue:String,_message:String="") -> void:
	Story.dialogue(world,cue)

# Play mission control messages in order after each film finishes or is skipped.
const AFTER_FILM := {
	"S01_F00E": ["EVA_EstablishBattlefieldControl", "Mis_xS1_ZofiaAlcatrazIntro", "Mis_xS1_ZofiaNavalAttack"],
	"S01_P01E": ["Mis_xS1_ZofiaBriefing01", "Mis_xS1_ZofiaBriefing02", "Mis_xS1_ZofiaBriefing03"],
	"S01_P02E": [],
	"S01_P03E": ["Mis_xS1_ZofiaSovietBase", "Mis_xS1_ZofiaBorisInPast", "Mis_xS1_BorisPuzzled", "Mis_xS1_ZofiaRespondsToBoris"],
}

static func scenario_film(world,clip:String) -> void:
	Film.show_clip(world,clip,func():
		var state:Dictionary=world.allied_state.time_shift
		match clip:
			"S01_F00E":
				Staging.run(world,state,"0B76DF3C",false)
				Story.queue_media(state,"0DD8E18C")
				Story.queue_media(state,"094C722C",float(Story.FLEET.media["0DD8E18C"].delay)+float(Story.FLEET.media["094C722C"].delay))
			"S01_P01E":
				Story.queue_media(state,"0D17F50C")
				Story.queue_media(state,"09577E1C")
				Staging.queue(state,"05D70C3C")
				Staging.queue(state,"0B8A231C")
			"S01_P03E":
				Staging.queue(state,"090435FC")
				Story.Late.schedule(state,"090437CC")
				if not state.get("boris_lost",false):Story.queue_media(state,"0439CD6C")
		voice(world,"EVA_BattlefieldControlOnline")
		if clip != "S01_F00E" or int(world.allied_state.time_shift.phase) == 0:
			announce_radar_objectives(world)
		if clip=="S01_F00E" and int(world.allied_state.time_shift.phase)==0:
			var s:Dictionary=world.allied_state.time_shift
			s.naval_reminder_due=float(s.elapsed)+float(Story.FLEET.reminder.delay)
			Staging.opening(world,s))

static func place(world,id:String,owner:String,pos:Vector2,tag:String=""):
	var def:=GameData.get_building(id)
	if def.is_empty():return null
	var b=world._place_building(id,owner,site_center(def,pos),true)
	if b!=null:
		b.special.time_shift_tag=tag
		if id=="YAPPPT" or id=="YAPPET":b.special.yuri_power=true;b.refresh_house_color()
		b._buildup_play=-1
	return b

static func site_center(def:Dictionary,origin:Vector2) -> Vector2:
	var dims:=str(def.get("foundation","1x1")).to_lower().split("x")
	return origin+Vector2(1-int(dims[1]),int(dims[0])-1)*27.5 if dims.size()==2 else origin

static func populate(world,era:int) -> void:
	for row in FIELD.data.sites:
		var id:String=row[0]
		if row[4]==0:continue
		var area:Rect2i=Rect2i(4,29,52,67) if era==0 else BOUNDS[era]
		if not region(Vector2i(row[1],row[2]),area) and not (era==0 and id in ["YAPPET","NANRCT"]):continue
		if row[3]=="Neutral" and id!="CATIME01":continue # NativeMaps placed the civilian sites.
		if era==0 and (row[3] in ["YuriCountry","Soviet2House"]) or era==1 and id!="CATIME02" or era==2 and row[3]!="YuriCountry":continue
		var side:="ally" if id=="CATIME02" else "neutral" if id=="CATIME01" else "enemy"
		var b=place(world,id,side,Vector2(row[1],row[2])*55,row[5])
		if b!=null:
			b.hp=b.max_hp*float(row[4])/256.0
			b.special.time_shift_native_house=row[3]
			if row[3]=="YuriCountry":b.refresh_house_color()
			if id in ["CATIME01","CATIME02"]:world.allied_state.time_shift.machine=b
			if id=="YAPPPT":world.allied_state.time_shift.dominator=b
			if era==2 and id=="NANRCT" and Vector2(row[1],row[2])==Vector2(118.5,38.5):
				b.special.shift_reactor_repair_target=true
	for row in FIELD.data.units:
		if row[4]==0 or not region(Vector2i(row[1],row[2]),BOUNDS[era]):continue
		if era==0 and row[3]=="Soviet2House" or era==1 and row[3]!="Soviet2House" or era==2 or row[0] in ["DNOAA","DNOB"]:continue
		if GameData.get_unit(row[0]).is_empty():continue
		var side:="ally" if row[3]=="Soviet2House" else "neutral" if row[3]=="Neutral" else "enemy"
		var u=world.spawn_unit(row[0],side,Vector2(row[1],row[2])*55)
		if u!=null:
			u.order_guard()
			u.hp=u.max_hp*float(row[4])/256.0
			u.special.time_shift_tag=row[5]
			u.special.time_shift_native_house=row[3]

static func setup(world) -> void:
	scenery(world)
	if not BattleSaves.pending.is_empty():return
	world.allied_state.time_shift={"phase":0,"elapsed":0.0,"scan":0.0,"timer":120.0,"dino_due":10.0,"dinos":0}
	bounds(world,0)
	populate(world,0)
	for row in FIELD.data.overlay:
		if row[0] in ["CAFNCP","GAWALL"]:
			var wall=place(world,row[0],"neutral",Vector2(row[1],row[2])*55)
			if wall!=null:wall.special.native_wall_pitch=55
	for row in Story.FLEET.fleet:
		var goal:=wp(int(row.slot))
		var start:Vector2=world.path_service.nearest_reachable(goal.move_toward(wp(int(row.ingress)),150),goal,true,8)
		var ship=world.spawn_unit(row.type,"ally",start)
		ship.special.time_shift_fleet_slot=int(row.slot)
		ship.order_move(goal,false,null,world.path_for_unit(ship,goal))
	world.allied_state.time_shift.fleet_slots_initialized=true
	world.center_on(wp(18))
	scenario_film(world,"S01_F00E")

static func cleared(world,tag:String) -> bool:
	for group in [world.buildings,world.units]:
		for actor in group:
			if world.actor_alive(actor) and actor.side=="enemy" and actor.special.get("time_shift_tag")==tag:return false
	return true

static func land(world) -> void:
	world.hud.minimap.clear_objective_flashes()
	var state:Dictionary=world.allied_state.time_shift
	state.landing_backup={}
	for row in FIELD.data.landing:
		var carrier=landing_transport(world,row)
		if int(row[0])==int(Cleanup.RULES["05DB7F3C"].teams[0].at) and carrier!=null:state.s01_flak_boat=carrier
		if int(row[0]) in [55,56]:
			var slot:Dictionary={"carrier":carrier}
			if carrier!=null:slot.members=carrier.logistics.passengers.duplicate()
			state.landing_backup[str(int(row[0]))]=slot
	world.center_on(wp(55))
	scenario_film(world,"S01_P01E")

static func landing_transport(world,row:Array):
	var shore:=wp(int(row[0]))
	var start:Vector2=world.path_service.nearest_reachable(shore.move_toward(wp(23),180),shore,false,8,true)
	var carrier=world.spawn_unit("SAPC","ally",start)
	if carrier==null:return null
	for id in row[1]:
		if id=="SAPC":continue
		for i in int(row[1][id]):
			var u=world.spawn_unit("SOV_DOG" if id=="DOG" else id,"ally",start)
			if u==null:continue
			if id=="BORIS":u.special.shift_debut=true
			u.set_stowed(carrier)
			carrier.logistics.passengers.append(u)
	carrier.special.shift_beach=shore
	carrier.order_move(shore,false,null,world.path_for_unit(carrier,shore))
	return carrier

# SOV01 0959CAFC / 0959C92C rearm the separate Rhino / conscript transports.
static func landing_backup_tick(world,s:Dictionary) -> void:
	var groups:Dictionary=s.get("landing_backup",{})
	for key in groups:
		var slot:Dictionary=groups[key]
		if slot.get("done",false):
			if not slot.has("members") or slot.members.any(func(u):return world.actor_alive(u) and u.side=="ally"):continue
			# 082C3CEC: the first Rhino group lost on land launches both backup teams.
			if key=="55" and not slot.get("replacement",false):
				for paired in groups.values():
					if paired.get("replacement",false):continue
					paired.done=false
					paired.due=float(s.elapsed)
			else:
				# Only replacement infantry and replacement Rhinos have the group-loss tags.
				if not slot.get("replacement",false):continue
				var row:Dictionary=Staging.ROWS["082C77EC" if key=="55" else "082C79BC"]
				var next:Dictionary=Story.FLEET.landingTriggers.get(row.enable[0],{}) if Story.FLEET.has("landingTriggers") else {}
				slot.done=false
				slot.due=float(s.elapsed)+float(next.get("delay",9.0 if key=="55" else 3.0))
			continue
		var carrier=slot.get("carrier")
		if world.actor_alive(carrier) and not slot.has("due"):
			if not carrier.logistics.passengers.is_empty():continue
			slot.done=true
			if slot.get("replacement",false):
				Cleanup.landing_team(world,slot,key)
				voice(world,"EVA_ReinforcementsHaveArrived")
				Events.emit_radar_ping(wp(int(key)),"campaign_discovery")
				Events.emit_message("后续登陆部队已上岸。")
			else:Cleanup.landing_team(world,slot,key)
			continue
		if not slot.has("due"):slot.due=float(s.elapsed)+(9.0 if key=="55" else 3.0)
		if float(s.elapsed)<float(slot.due):continue
		var row:Array=FIELD.data.landing[0 if key=="55" else 1]
		carrier=landing_transport(world,row)
		if carrier==null:continue
		slot.carrier=carrier
		slot.members=carrier.logistics.passengers.duplicate()
		slot.replacement=true
		slot.erase("due")

static func begin_crossing(world, state: Dictionary, era: int) -> void:
	world.hud.minimap.clear_objective_flashes()
	world.center_on(state.machine.position)
	Staging.crossing(world,state,era)
	state.crossing_era = era
	state.crossing_time = 0.0

const CROSSING_DURATION := 2.8

static func sync_crossing_visual(world, state: Dictionary) -> void:
	var overlay = world.get_node_or_null("TimeVortex")
	if not state.has("crossing_era"):
		if overlay != null: overlay.queue_free()
		return
	if overlay == null:
		overlay = CanvasLayer.new()
		overlay.name = "TimeVortex"
		overlay.layer = 1
		world.add_child(overlay)
		var screen := ColorRect.new()
		screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(screen)
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.material = ShaderMaterial.new()
		screen.material.shader = preload("res://scripts/world/time_vortex.gdshader")
	var progress := clampf(float(state.crossing_time) / CROSSING_DURATION, 0.0, 1.0)
	overlay.get_child(0).material.set_shader_parameter("progress", progress)

static func advance_crossing(world, state: Dictionary, seconds: float) -> void:
	if int(state.crossing_era)==2:
		Cleanup.advance_grid_transfer(world,state,minf(seconds,maxf(0.0,CROSSING_DURATION-float(state.crossing_time))))
	state.crossing_time += seconds
	sync_crossing_visual(world, state)
	var progress := float(state.crossing_time) / CROSSING_DURATION
	var era := int(state.crossing_era)
	if era==1 and not state.get("s01_first_machine_returned",false) and Staging.ROWS["0BDE287C"].enable.has("09601D2C"):
		var row:Dictionary=Cleanup.PHASE_LINKS["09601D2C"]
		if float(state.crossing_time)>=float(row.delay):Cleanup.phase_apply(world,state,row.id)
	if progress >= 0.5 and int(state.phase) == era + 1:
		if era==2 and Staging.ROWS["0BDC985C"].enable.has("0CAAF7DC"):
			Cleanup.phase_apply(world,state,"0CAAF7DC")
		state.phase = era + 2
		change_era(world, era)
	if progress >= 1.0:
		state.erase("crossing_time")
		state.erase("crossing_era")
		sync_crossing_visual(world, state)
		var film_row:Dictionary=Staging.ROWS["0952E0FC" if era==1 else "095F1B8C"]
		var clip:String={"35":"S01_P02E","36":"S01_P03E"}.get(film_row.film,"")
		if not clip.is_empty():scenario_film(world,clip)
		Staging.after_crossing(world,state,era)

static func change_era(world,era:int) -> void:
	var old_boris=world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="BORIS" and u.side=="ally")
	var keep_boris:bool=not old_boris.is_empty()
	for u in world.units.duplicate():
		if world.actor_alive(u):AlliedAbilities.consume(u)
	for b in world.buildings.duplicate():
		if not world.actor_alive(b):continue
		var archived:bool=era==1 and Cleanup.archive_grid_plant(world,b)
		if archived or b.side!="neutral" or b.building_id=="CATIME01":
			world.buildings.erase(b)
			b.queue_free()
	world.invalidate_building_membership()
	world.selected_units.clear()
	world.selected_building=null
	world._emit_selection()
	world.hud.minimap.clear_radar_events()
	bounds(world,era)
	populate(world,era)
	if world.fog!=null:world.fog.reset_exploration("ally")
	if era==1:
		var state:Dictionary=world.allied_state.time_shift
		state.dino_trigger="0b554afc"
		state.dino_due=random_timer(state.dino_trigger)
		state.recharge_reminder_left=float(TIMERS["043e763c"].seconds)
		world.center_on(wp(68))
		world.allied_state.time_shift.boris_lost=not keep_boris
		if keep_boris:world.spawn_unit("BORIS","ally",wp(68)+Vector2(80,40))
		if not Staging.ROWS["0952C96C"].transfer.is_empty() and world.actor_alive(state.get("machine")):
			AlliedAbilities.change_side(state.machine,"ally")
		for row in FIELD.data.units:
			if row[0] in ["DNOAA","DNOB"]:
				var animal=world.spawn_unit("DNOA" if row[0]=="DNOAA" else "DNOB","neutral",Vector2(row[1],row[2])*55)
				if animal!=null and row[0]=="DNOAA":animal.special.shift_rexy=true;animal.hp=3500;animal.max_hp=3500
	else:
		Cleanup.restore_grid_plants(world)
		Story.return_city(world)
		var base_slots:Dictionary={}
		for item in Staging.ROWS["0439097C"].buildings:
			base_slots.get_or_add(item[0],[]).append(wp(int(item[1])))
		for row in FIELD.data.base:
			var b=place(world,row[0],"neutral" if row[3]=="ally" else "enemy",Vector2(row[1],row[2])*55)
			if b!=null and row[3]=="ally" and world.allied_state.time_shift.get("s01_return_setup",true):
				b.special.shift_base=true
				for p in base_slots.get(row[0],[]):
					if b.position.distance_to(p)<240.0:b.special.s01_retail_base=true;break
		var base:=wp(71)
		var s:Dictionary=world.allied_state.time_shift
		if s.get("boris_lost",false):
			Story.Late.apply(world,s,"0439E3FC")
			Cleanup.queue(s,"0439F14C")
		else:world.spawn_unit("BORIS","ally",base+Vector2(-160,0))
		world.spawn_unit("SAPC","ally",wp(97))
		for i in 4:world.spawn_unit("HTNK","ally",base+Vector2(i*45,80))
		for row in FIELD.data.yuri:
			for id in row[1]:
				for i in int(row[1][id]):
					var u=world.spawn_unit(id,"enemy",wp(row[0])+Vector2(i*24,0))
					if u==null:continue
					u.order_guard()
					if int(row[0])==53 and id=="YENGINEER":u.special.shift_reactor_fixer=true
					if not row[2].is_empty():Story.start_island_route(world,u,row[2],id=="LTNK")
		world.center_on(base)
	world._refresh_pathing()
	if world.fog!=null:world.fog.rebuild()

# 0C47F71C -> 06B600EC: celebrate at the destroyed controller, then win after five seconds.
static func finish_dominator(world,s:Dictionary,delta:float) -> void:
	if not s.has("dominator_win_left"):
		s.dominator_win_left=5.0
		world.hud.minimap.clear_objective_flashes()
		world.center_on(wp(144))
		Ra2Sfx.play("CameraSwitch")
		for u in world.units:
			if world.actor_alive(u) and u.side=="ally" and u._seq.has("Cheer"):
				u.special.cheer_elapsed=0.0
				u.queue_redraw()
		return
	s.dominator_win_left=maxf(0.0,float(s.dominator_win_left)-delta)
	if s.dominator_win_left<=4.0 and not s.get("dominator_complete_sent",false):
		s.dominator_complete_sent=true
		Events.emit_message("任务目标完成：心灵控制器已摧毁。") # 08E497AC, one second after destruction.
	if s.dominator_win_left<=0.0:world.end_battle(true)

# 06B602BC is shared by the tagged time machines and the Soviet annihilation branch.
static func begin_loss(world,s:Dictionary,cue:String="",delay:=0.0) -> void:
	if s.has("loss_left") or s.has("loss_warning_left"):return
	if delay>0.0:
		s.loss_warning_left=delay
		s.loss_warning_cue=cue
		return
	if not cue.is_empty():voice(world,cue)
	s.loss_left=15.0

static func finish_loss(world,s:Dictionary,delta:float) -> void:
	if s.has("loss_warning_left"):
		var left:=float(s.loss_warning_left)-delta
		if left>0.0:s.loss_warning_left=left;return
		var cue:String=s.loss_warning_cue
		s.erase("loss_warning_left")
		s.erase("loss_warning_cue")
		begin_loss(world,s,cue)
		delta=-left
	s.loss_left=maxf(0.0,float(s.loss_left)-delta)
	if s.loss_left<=0.0:world.end_battle(false)

static func recharge_reminder(s:Dictionary,delta:float) -> void:
	if not s.has("recharge_reminder_left"):return
	s.recharge_reminder_left=float(s.recharge_reminder_left)-delta
	if s.recharge_reminder_left>0.0:return
	s.erase("recharge_reminder_left")
	Events.emit_message("任务目标：保护时光机，等待重新充能。")

static func finish_power_grid(world,s:Dictionary) -> void:
	var full:Dictionary=Story.FLEET.grid.full
	var now:=float(s.power_elapsed)
	var latched:=float(s.grid_full_at)
	if now>=latched+float(full.enough.delay) and not s.get("grid_full_audio",false):
		s.grid_full_audio=true
		if s.get("Mis_xS1_ZofiaBorisDeadMourn",false):Story.once(world,"Mis_xS1_ZofiaFindBoris")
		voice(world,full.enough.cue)
	if now>=latched+float(full.enough.delay)+float(full.camera.delay) and not s.get("grid_full_camera",false):
		s.grid_full_camera=true
		world.center_on(wp(int(full.camera.slot)))
	if now>=latched+float(full.complete.delay) and not s.get("grid_full_message",false):
		s.grid_full_message=true
		if full.complete.text=="MISSION:Obj3Comp":Events.emit_message("供电目标已完成：时光机已通电。")
	if now>=latched+float(full.enough.delay)+float(full.effect.delay)+float(full.animation.delay):
		for key in ["engineer_arrival_due","engineer_hint_due","engineer_rescue_arrival_due","engineer_rescue_due","power_raid_pings","grid_warning_due"]:s.erase(key)
		if Staging.ROWS["0BDE287C"].enable.has("0951A8BC"):begin_crossing(world,s,1)

static func tick(world,delta:float) -> void:
	if world.ended or world.paused or not world.allied_state.has("time_shift"):return
	var s:Dictionary=world.allied_state.time_shift
	if s.has("loss_left") or s.has("loss_warning_left"):
		finish_loss(world,s,delta)
		return
	if s.phase==4 and not world.actor_alive(s.get("dominator")):
		finish_dominator(world,s,delta)
		return
	if s.has("crossing_era"):
		advance_crossing(world,s,BattleClock.control_delta(delta))
		return
	s.scan-=delta
	s.elapsed=float(s.get("elapsed",0))+delta
	if s.phase==4:Cleanup.advance_grid_transfer(world,s,delta)
	# Sailor notices can mature during the non-pausing landing radar film.
	if not s.get("fleet_notices",{}).is_empty() and (s.phase==0 or s.get("fleet_disarmed",false)):
		Story.fleet_notices(world,s)
	if s.has("naval_objective_due") and float(s.elapsed)>=float(s.naval_objective_due):
		s.erase("naval_objective_due")
		var objective:Dictionary=Story.FLEET.objective
		if objective.text=="MISSION:Obj1Comp":Events.emit_message("任务目标一已完成。")
		voice(world,objective.cue)
	var film=world.get_node_or_null("HollywoodFilm")
	if film!=null and not film.is_queued_for_deletion():return
	if s.phase==2:s.power_elapsed=float(s.get("power_elapsed",0.0))+delta
	if s.phase==3:
		s.timer-=delta
		s.dino_due-=delta
		if s.timer>0.0 and world.actor_alive(s.get("machine")):recharge_reminder(s,delta)
	if s.scan>0:return
	var elapsed:=0.4-float(s.scan)
	s.scan=0.4
	if not s.has("grid_full_at") or s.phase!=2:Staging.tick(world,s)
	Cleanup.tick(world,s)
	Cleanup.phase_tick(world,s)
	Story.props(world,s)
	if s.phase==4:
		s.s01_bridge_elapsed=elapsed
		Story.bridge(world,s)
		Story.reactor_repair(world)
		Story.island_patrols(world)
		Story.mixed_attack(world,s,elapsed)
		Story.mixed_orders(world)
		if Story.boat_loss(world,s):return
		preload("res://scripts/world/time_shift_global_ai.gd").tick(world,s,elapsed)
	if s.phase==1 or s.phase==2:
		landing_backup_tick(world,s)
		for u in world.units:
			if world.actor_alive(u) and u.special.has("shift_beach") and u.position.distance_to(u.special.shift_beach)<100:
				u.special.erase("shift_beach")
				u.logistics.request_unload()
		var flak=s.get("s01_flak_boat")
		if world.actor_alive(flak) and flak.logistics.passengers.is_empty() and not s.get("s01_flak_return",false):
			s.s01_flak_return=true
			Cleanup.apply(world,s,"079F9B1C")
	if s.phase in [0,1,2,3] and not world.actor_alive(s.get("machine")):
		begin_loss(world,s,"Mis_xS1_ZofiaLostTimeMach")
		return
	match int(s.phase):
		0:
			var eliminated:=cleared(world,"SP2.1_Destroy_AlliedDef")
			if not eliminated:
				if s.has("naval_reminder_due") and float(s.elapsed)>=float(s.naval_reminder_due):
					s.erase("naval_reminder_due")
					if Story.FLEET.reminder.text=="MISSION:Sov1Obj1":Events.emit_message("任务目标：消灭盟军舰队和岸防巨炮，为登陆部队开路。")
				Story.fleet_reinforcements(world,s)
			else:
				s.erase("naval_reminder_due")
				Story.fleet_disarm(s)
				s.phase=1;s.elapsed=0.0
				s.naval_objective_due=float(Story.FLEET.objective.delay)
				bounds(world,0,true);land(world)
		1:
			if cleared(world,"Destroy_Time Defenses"):Story.Late.acquire_machine(world,s)
		2:
			if s.has("grid_full_at"):
				finish_power_grid(world,s)
				return
			var supply:=0
			var live:Dictionary={}
			var seized:Dictionary={}
			for b in world.buildings:
				if not world.actor_alive(b):continue
				if b.building_id=="GAPOWR" and b.special.get("yuri_power",false):seized[b.building_id]=true
				if Story.FLEET.grid.plants.has(b.building_id):
					live[b.building_id]=true
					if b.side=="ally":supply+=int(b.power)
					elif b.special.get("yuri_power",false):seized[b.building_id]=true
			if Story.power_losses(s,live):begin_loss(world,s,"Mis_xS1_ZofiaNoPowerLeft",3.0);return
			var mission_plants:int=seized.size()-int(seized.has("GAPOWR"))
			if mission_plants>=4:
				Staging.run(world,s,"097DDE6C",false)
				Story.dominator_power_alarm(world,s,mission_plants)
				world.end_battle(false);return
			if supply>=625 and Staging.ROWS["095183EC"].enable.has("0BDE024C"):
				s.grid_full_at=float(s.power_elapsed)
				return
			Story.tech_power_warning(world,s,seized)
			Story.engineer_reinforcements(world,s,wp(114))
			Story.power_contest(world,s)
		3:
			if s.timer<=0:
				s.erase("recharge_reminder_left")
				voice(world,"Mis_xS1_ZofiaTimeMachineReady")
				Cleanup.phase_apply(world,s,"097651DC")
				begin_crossing(world,s,2)
			elif s.dino_due<=0:
				var rule:String=s.get("dino_trigger","0b554afc" if int(s.dinos)%2==0 else "0b557e6c")
				s.dino_trigger=TIMERS[rule].enable[0]
				s.dino_due=random_timer(s.dino_trigger)
				var machine=s.machine
				var point:Vector2=world.path_service.nearest_reachable(wp(69 if rule=="0b554afc" else 70),machine.position,false,25)
				s.dinos+=1
				var rex=world.spawn_unit("DNOA","enemy",point)
				if rex != null:
					var approach := wp(68)
					rex.order_move(approach, true, null, world.path_for_unit(rex, approach))
	if not world.has_surviving_assets("ally"):
		Events.emit_message("我方部队已全灭。")
		begin_loss(world,s)
