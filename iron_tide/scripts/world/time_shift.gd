extends RefCounted

const ID := "yr_time_shift"
const FIELD = preload("res://data/time_shift_field.json")
const POWER_PLANTS := ["GAPOWRA","GAPOWRB","GAPOWRC","GAPOWRD","GAPOWRE","GAPOWRF"]
const ASSETS = preload("res://data/time_shift_assets.json")
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
	"S01_P01E": ["Mis_xS1_ZofiaBriefing01", "Mis_xS1_ZofiaBriefing02", "Mis_xS1_BorisReporting", "Unit_Sofia_Boris", "Mis_xS1_ZofiaBriefing03"],
	"S01_P02E": [],
	"S01_P03E": ["Mis_xS1_ZofiaSovietBase", "Mis_xS1_ZofiaBorisInPast", "Mis_xS1_BorisPuzzled", "Mis_xS1_ZofiaRespondsToBoris"],
}

static func scenario_film(world,clip:String) -> void:
	Film.show_clip(world,clip,func():
		for event in AFTER_FILM[clip]: voice(world,event)
		voice(world,"EVA_BattlefieldControlOnline")
		if clip != "S01_F00E" or int(world.allied_state.time_shift.phase) == 0:
			announce_radar_objectives(world))

static func place(world,id:String,owner:String,pos:Vector2,tag:String=""):
	var def:=GameData.get_building(id)
	if def.is_empty():return null
	var dims:=str(def.get("foundation","1x1")).to_lower().split("x")
	if dims.size()==2:pos+=Vector2(1-int(dims[1]),int(dims[0])-1)*27.5
	var b=world._place_building(id,owner,pos,true)
	if b!=null:
		b.special.time_shift_tag=tag
		if id=="YAPPPT" or id=="YAPPET":b.special.yuri_power=true;b.refresh_house_color()
		b._buildup_play=-1
	return b

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
			if id in ["CATIME01","CATIME02"]:world.allied_state.time_shift.machine=b
			if id=="YAPPPT":world.allied_state.time_shift.dominator=b
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
	for row in FIELD.data.fleet:
		var goal:=wp(row[1])
		var start:Vector2=world.path_service.nearest_reachable(goal.move_toward(wp(row[2]),150),goal,true,8)
		var ship=world.spawn_unit(row[0],"ally",start)
		ship.order_move(goal,false,null,world.path_for_unit(ship,goal))
	world.center_on(wp(18))
	scenario_film(world,"S01_F00E")

static func cleared(world,tag:String) -> bool:
	for group in [world.buildings,world.units]:
		for actor in group:
			if world.actor_alive(actor) and actor.side=="enemy" and actor.special.get("time_shift_tag")==tag:return false
	return true

static func land(world) -> void:
	world.hud.minimap.clear_objective_flashes()
	for row in FIELD.data.landing:
		var shore:=wp(row[0])
		var start:Vector2=world.path_service.nearest_reachable(shore.move_toward(wp(23),180),shore,false,8,true)
		var carrier=world.spawn_unit("SAPC","ally",start)
		for id in row[1]:
			if id=="SAPC":continue
			for i in int(row[1][id]):
				var u=world.spawn_unit("SOV_DOG" if id=="DOG" else id,"ally",start)
				u.set_stowed(carrier)
				carrier.logistics.passengers.append(u)
		carrier.special.shift_beach=shore
		carrier.order_move(shore,false,null,world.path_for_unit(carrier,shore))
	world.center_on(wp(55))
	scenario_film(world,"S01_P01E")

static func begin_crossing(world, state: Dictionary, era: int) -> void:
	world.hud.minimap.clear_objective_flashes()
	world.center_on(state.machine.position)
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
	state.crossing_time += seconds
	sync_crossing_visual(world, state)
	var progress := float(state.crossing_time) / CROSSING_DURATION
	var era := int(state.crossing_era)
	if progress >= 0.5 and int(state.phase) == era + 1:
		state.phase = era + 2
		change_era(world, era)
	if progress >= 1.0:
		state.erase("crossing_time")
		state.erase("crossing_era")
		sync_crossing_visual(world, state)
		scenario_film(world, "S01_P02E" if era == 1 else "S01_P03E")

static func change_era(world,era:int) -> void:
	var old_boris=world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="BORIS" and u.side=="ally")
	var keep_boris:bool=not old_boris.is_empty()
	for u in world.units.duplicate():
		if world.actor_alive(u):AlliedAbilities.consume(u)
	for b in world.buildings.duplicate():
		if world.actor_alive(b) and (b.side!="neutral" or b.building_id=="CATIME01"):
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
		world.center_on(wp(68))
		world.allied_state.time_shift.boris_lost=not keep_boris
		if keep_boris:world.spawn_unit("BORIS","ally",wp(68)+Vector2(80,40))
		for row in FIELD.data.units:
			if row[0] in ["DNOAA","DNOB"]:
				var animal=world.spawn_unit("DNOA" if row[0]=="DNOAA" else "DNOB","neutral",Vector2(row[1],row[2])*55)
				if animal!=null and row[0]=="DNOAA":animal.special.shift_rexy=true;animal.hp=3500;animal.max_hp=3500
	else:
		Story.return_city(world)
		for row in FIELD.data.base:
			var b=place(world,row[0],"neutral" if row[3]=="ally" else "enemy",Vector2(row[1],row[2])*55)
			if b!=null and row[3]=="ally":b.special.shift_base=true
		var base:=wp(71)
		world.spawn_unit("BORIS","ally",base+Vector2(-160,0))
		if world.allied_state.time_shift.get("boris_lost",false):Story.once(world,"Mis_xS1_ZofiaFindBoris")
		world.spawn_unit("SAPC","ally",wp(97))
		for i in 4:world.spawn_unit("HTNK","ally",base+Vector2(i*45,80))
		for row in FIELD.data.yuri:
			for id in row[1]:
				for i in int(row[1][id]):
					var u=world.spawn_unit(id,"enemy",wp(row[0])+Vector2(i*24,0))
					if u!=null:u.order_guard()
		world.center_on(base)
	world._refresh_pathing()
	if world.fog!=null:world.fog.rebuild()

static func tick(world,delta:float) -> void:
	if world.ended or world.paused or not world.allied_state.has("time_shift"):return
	var s:Dictionary=world.allied_state.time_shift
	if s.has("crossing_era"):
		advance_crossing(world,s,BattleClock.control_delta(delta))
		return
	s.scan-=delta
	s.elapsed=float(s.get("elapsed",0))+delta
	var film=world.get_node_or_null("HollywoodFilm")
	if film!=null and not film.is_queued_for_deletion():return
	if s.phase==2:s.power_elapsed=float(s.get("power_elapsed",0.0))+delta
	if s.phase==3:s.timer-=delta;s.dino_due-=delta
	if s.scan>0:return
	s.scan=0.4
	Story.props(world,s)
	if s.phase==4:Story.bridge(world,s)
	if s.phase==1 or s.phase==2:
		for u in world.units:
			if world.actor_alive(u) and u.special.has("shift_beach") and u.position.distance_to(u.special.shift_beach)<100:
				u.special.erase("shift_beach")
				u.logistics.request_unload()
	if s.phase in [0,1,2,3] and not world.actor_alive(s.get("machine")):
		voice(world,"Mis_xS1_ZofiaLostTimeMach","时光机被摧毁了。")
		world.end_battle(false)
		return
	match int(s.phase):
		0:
			var eliminated:=cleared(world,"SP2.1_Destroy_AlliedDef")
			if not eliminated:
				for id in ["DRED","SUB","HYD","SQD"]:
					if not world.units.any(func(u):return world.actor_alive(u) and u.unit_id==id and u.side=="ally"):
						var r=FIELD.data.fleet.filter(func(row):return row[0]==id)[0]
						world.spawn_unit(id,"ally",wp(r[1]))
						voice(world,"EVA_ReinforcementsHaveArrived")
			else:s.phase=1;s.elapsed=0.0;voice(world,"EVA_ObjectiveComplete");bounds(world,0,true);land(world)
		1:
			if cleared(world,"Destroy_Time Defenses"):
				AlliedAbilities.change_side(s.machine,"ally")
				s.phase=2
				announce_radar_objectives(world)
				preload("res://scripts/world/american_paradrop.gd").launch_story(world,wp(114),"SENGINEER",10)
				s.power_elapsed=0.0
		2:
			var supply:=0
			var remaining:=0
			var seized:=0
			for b in world.buildings:
				if world.actor_alive(b) and str(b.building_id).begins_with("GAPOWR") and b.building_id.length()==7:
					remaining+=1
					if b.side=="ally":supply+=int(b.power)
					elif b.special.get("yuri_power",false):seized+=1
			if remaining<4:voice(world,"Mis_xS1_ZofiaNoPowerLeft");world.end_battle(false)
			elif seized>=4:voice(world,"EVA_PsychicDominatorDetected");world.end_battle(false)
			elif supply>=625:
				if s.get("Mis_xS1_ZofiaBorisDeadMourn",false):Story.once(world,"Mis_xS1_ZofiaFindBoris")
				voice(world,"Mis_xS1_ZofiaEnoughPower")
				begin_crossing(world,s,1)
			elif seized==3 and not s.has("Mis_xS1_ZofiaYuriAlmostPowered"):Story.once(world,"Mis_xS1_ZofiaYuriAlmostPowered")
			elif not world.units.any(func(u):return world.actor_alive(u) and u.side=="ally" and u.unit_id=="SENGINEER"):
				preload("res://scripts/world/american_paradrop.gd").launch_story(world,wp(114),"SENGINEER",6)
			if s.phase==2 and not world.ended:Story.power_contest(world,s)
		3:
			if s.timer<=0:
				voice(world,"Mis_xS1_ZofiaTimeMachineReady")
				begin_crossing(world,s,2)
			elif s.dino_due<=0:
				s.dino_due=10.0
				var machine=s.machine
				var point:Vector2=world.path_service.nearest_reachable(wp(69+int(s.dinos)%2),machine.position,false,25)
				s.dinos+=1
				var rex=world.spawn_unit("DNOA","enemy",point)
				if rex != null:
					var approach := wp(68)
					rex.order_move(approach, true, null, world.path_for_unit(rex, approach))
		4:
			if not world.actor_alive(s.get("dominator")):world.end_battle(true);return
	if not world.has_surviving_assets("ally"):world.end_battle(false)
