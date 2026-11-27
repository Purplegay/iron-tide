extends RefCounted

const ID := "yr_head_games"
const CASTLE := "CATRAN03"
const BEACON := "SOV07_BEACON"

const Orders = preload("res://scripts/world/head_games_orders.gd")
const FIELD = preload("res://data/head_games_field.json")
# SOV07UMD Tag 093B806C, Einstein House; the same actors change hands on discovery.
const VOLUNTEERS := [["TERROR",190,110],["TERROR",190,112],["TERROR",191,111],["DTRUCK",193,110],["DTRUCK",193,107]]
const VOLUNTEER_RALLY := Vector2(91.5,176.5)*55.0

static func point(row: Array) -> Vector2:
	return Vector2(row[1], row[2]) * 55.0

static func assign_wing(actor,wing:int) -> void:
	actor.special.head_games_wing=wing
	actor.refresh_house_color()

static func setup(world) -> void:
	var scenery := Node2D.new()
	scenery.name = "TransylvaniaScenery"
	world.add_child(scenery)
	var textures := {}
	for row in FIELD.data.props:
		var id: String = row[0]
		if not textures.has(id): textures[id] = load("res://assets/maps/yr/head_games/%s.png" % id)
		var sprite := Sprite2D.new()
		sprite.texture = textures[id]
		sprite.position = point(row)
		sprite.offset.y = -sprite.texture.get_height()*0.5
		sprite.transform = Transform2D(Iso.eff_angle(),Iso.up()*1.30,0,sprite.position)
		sprite.z_index = DepthLayers.entity_z(sprite.position,world.map_size)
		scenery.add_child(sprite)
	preload("res://scripts/world/head_games_sites.gd").lights(world)
	if not BattleSaves.pending.is_empty(): return
	world.HeadEconomy.initialize(world)
	preload("res://scripts/world/head_games_sites.gd").overlay_walls(world)
	for row in FIELD.data.sites:
		var id := BEACON if row[0] == "NAPSYB" else str(row[0])
		var definition := GameData.get_building(id)
		if definition.is_empty(): continue
		var dims := str(definition.get("foundation", "1x1")).split("x")
		var origin := point(row)
		if dims.size() == 2: origin += Vector2(1-int(dims[1]),int(dims[0])-1)*27.5
		var building = world._place_building(id,"enemy",origin,true)
		building._buildup_play = -1.0 # Retail fixtures are operational from the start.
		if id == BEACON: building.special.head_games_beacon = row[3]
		elif int(row[3]) >= 0: assign_wing(building,int(row[3]))
		if id == "YAGRND": building.special.head_grinder = "sw" if float(row[1])<60 else "ne"
		if id == CASTLE: building.hp = 5000; building.max_hp = 5000
		if id == "YAWEAP": world.spawn_points.assign([origin+Vector2(0,200)])
	for row in FIELD.data.units:
		var id := "SOV_DOG" if row[0] == "DOG" else "DOG" if row[0]=="ADOG" else str(row[0])
		var civilian := id.begins_with("CIV")
		var unit = world.spawn_unit(id,"neutral" if civilian else "enemy",point(row))
		if unit == null: continue
		# FIELD's twelve civilian rows are German1/German2 village residents.
		if civilian:
			unit.special.s07_resident_area="sw" if float(row[1])<60.0 else "ne"
			unit.special.s07_native_house="German1 House" if unit.special.s07_resident_area=="sw" else "German2 House"
		if int(row[3]) >= 0: assign_wing(unit,int(row[3]))
		if not unit.is_harvester:
			unit.order_stop()
			unit.hold_position = row[4] != "Area Guard"
			if not civilian and not unit.hold_position:
				unit.set_fire_stance("free")
				unit.special.campaign_area_guard = unit.global_position
	place_volunteers(world)
	var level:=clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)
	for trigger in Orders.DRIVERS.opening.values():
		if int(trigger.mask[level])==0:continue
		for spec in trigger.teams:
			if int(spec.target)!=0 or spec.at.is_empty():continue
			var composition:Dictionary={}
			for member in spec.members:
				var id:String={"ADOG":"DOG","DOG":"SOV_DOG"}.get(member[1],member[1])
				composition[id]=int(member[0])
			var origin:Vector2=Orders.location(spec.at)
			spawn_team_at(world,int(spec.wing),origin,composition,false)

static func arrive(world) -> void:
	if not BattleSaves.pending.is_empty(): return
	var first:Dictionary=Orders.DRIVERS.landing["0939307C"]
	land_column(world,first.members)
	if first.enable.has("093A04FC"):world.allied_state.s07_second_column_left=float(Orders.DRIVERS.landing["093A04FC"].delay)
	world.allied_state.head_brief_stage = 0

static func land_column(world,members:Array) -> void:
	var n := 0
	for row in members:
		for i in int(row[3]):
			var goal := point(row) + Vector2.RIGHT.rotated(n*2.4)*float(24+n*3)
			var start := goal.move_toward(Vector2(43.5,148.5)*55.0,200)
			if world.path_service.is_blocked(start): start=point(row)
			if world.path_service.is_blocked(goal): goal=point(row)
			var unit = world.spawn_unit("SOV_DOG" if row[0]=="DOG" else row[0],"ally",start)
			unit.order_move(goal,false,null,world.path_for_unit(unit,goal))
			n+=1

# Early retail-map snapshots left the opening column on the clipped entry cells.
static func recover_entry(world) -> void:
	var columns := {}
	var moved := false
	for unit in world.units:
		if not world.actor_alive(unit) or unit.side!="ally": continue
		if world.NativeMaps.flags("yr_sov07",unit.position)!=0: continue
		if unit.position.distance_to(Vector2(43.5,148.5)*55)>380: continue
		var id: String = "DOG" if unit.unit_id=="SOV_DOG" else unit.unit_id
		var slots: Array = []
		for row in FIELD.data.landing:
			if row[0]==id:
				for j in int(row[3]): slots.append(point(row)+Vector2.RIGHT.rotated(slots.size()*2.4)*j*28)
		if slots.is_empty(): continue
		var index := int(columns.get(id,0))
		unit.order_stop()
		unit.position = slots[index%slots.size()]
		world.neighborhood.relocate(unit)
		columns[id] = index+1
		moved = true
	if moved: world.center_on(world.player_start())

const Film = preload("res://scripts/ui/hollywood_film.gd")

static func start_film(world) -> void:
	world.allied_state.head_intro_done = false
	Film.show_clip(world, "S07_F00E", func(): start_radio.call_deferred(world))

# Original waypoints 43/44/45, cued to the baked S07_P01E + S07_p01 audio.
# The two wing cuts land on "allied troops" and "Soviet troops" respectively.
const BRIEFING_CUES := [0.0, 7.60, 10.36]

static func start_radio(world) -> void:
	world.allied_state.head_brief_stage = 0
	var intro: Dictionary = Orders.DRIVERS.extra["0947BC0C"]
	if not intro.enable.has("092D8F3C"):
		finish_briefing(world)
		return
	Film.show_clip(world, "S07_P01E", finish_briefing.bind(world), sync_briefing.bind(world))

static func briefing_point(stage: int) -> Vector2:
	var cell: Array = FIELD.data.briefing_points[stage - 1]
	return Vector2(cell[0], cell[1]) * 55.0

static func sync_briefing(seconds: float, world) -> void:
	var state: Dictionary = world.allied_state
	if not state.has("head_brief_stage"): return
	var stage := 1
	while stage < BRIEFING_CUES.size() and seconds >= BRIEFING_CUES[stage]:
		stage += 1
	if stage == int(state.head_brief_stage): return
	state.head_brief_stage = stage
	world.center_on(briefing_point(stage))
	world.camera.force_update_scroll()
	if world.fog != null: world.fog.rebuild()
	announce_objective_marks(world)

static func reveal_briefing_site(world, stage: int, duration := 0.0) -> void:
	world.fog._reveal("ally", briefing_point(stage), 410.0, duration)
	# The retail waypoint frames the area; the castle origin is outside that reveal disc.
	for actor in world.buildings:
		if not world.actor_alive(actor): continue
		if (stage == 1 and actor.building_id == CASTLE) or (stage > 1 and int(actor.special.get("head_games_beacon", -1)) == 3 - stage):
			world.fog._reveal("ally", actor.position, 410.0, duration)
			return

static func finish_briefing(world) -> void:
	var state: Dictionary = world.allied_state
	if not state.has("head_brief_stage"): return
	# A skip still leaves the locations explored, without running another camera tour.
	if world.fog != null:
		for stage in range(int(state.head_brief_stage) + 1, BRIEFING_CUES.size() + 1):
			reveal_briefing_site(world, stage, 1.0)
	state.head_intro_done = true
	state.erase("head_brief_stage")
	state.erase("head_brief_left") # Legacy saves only.
	if world.fog != null: world.fog.rebuild()
	world.center_on(world.player_start())
	world.camera.force_update_scroll()
	announce_objective_marks(world)
	Ra2Sfx.play_head_games_line("csof120")
	Events.emit_message("选中基地车，按 J 展开建造场。")

static func line(world,id:String,speaker:String,text:String) -> void:
	world.hud.show_field_transmission(speaker,text,"")
	Ra2Sfx.play_head_games_line(id)

static func briefing(world) -> void:
	if world.has_node("HollywoodFilm"): return
	var state: Dictionary = world.allied_state
	var resume_clip: String = state.get("head_resume_clip", "")
	if resume_clip == "S07_F00E" or resume_clip == "S07_P01E":
		state.erase("head_resume_clip")
		if resume_clip == "S07_F00E": start_film(world)
		else: start_radio(world)
	elif state.get("head_intro_done", true):
		# Older saves may resume the now-removed silent tour after the radio has ended.
		finish_briefing(world)

static func announce_objective_marks(world) -> void:
	world.hud.minimap.clear_objective_flashes()
	for mark in world.CampaignMarks.head_games(world):
		Events.emit_radar_ping(mark.position, "campaign_site")

# Retail waypoints used by the defender and attacker TeamTypes.
const WAYPOINTS := {63:163082,64:180108,15:177103,22:107147,62:167073,68:94124,1:107018,44:102029,58:60116,49:55091,65:104152,66:183115,67:106137}
const ATTACKERS := [{"E2":5,"DOG":1,"FLAKT":2},{"DOG":1,"E1":5,"GGI":2},{"INIT":5,"BRUTE":1}]

static func team(world,wing:int,waypoint:int,composition:Dictionary,attack:=false) -> void:
	var coord:int=WAYPOINTS[waypoint]
	var origin := Vector2(201.5-floori(coord/1000.0),coord%1000-10.5)*55.0
	spawn_team_at(world,wing,origin,composition,attack)

static func spawn_team_at(world,wing:int,origin:Vector2,composition:Dictionary,attack:bool) -> void:
	var side := "ally" if world.allied_state.has("head_games_freed_%d"%wing) else "enemy"
	var n := 0
	for id in composition:
		for i in int(composition[id]):
			var unit=world.spawn_unit(id,side,origin+Vector2.RIGHT.rotated(n*2.4)*(16+n*5))
			n+=1
			if unit==null: continue
			if wing>=0: assign_wing(unit,wing)
			if attack and side=="enemy":
				var goal:Vector2=world._player_target()
				unit.order_move(goal,true,null,world.path_for_unit(unit,goal))
			else: unit.order_guard()

static func field_events(world, delta:float) -> void:
	var state:Dictionary=world.allied_state
	state.head_field_poll=float(state.get("head_field_poll",0))-delta
	if state.head_field_poll>0 or world.fog==null: return
	state.head_field_poll=0.5
	retail_hostility_cells(world,state)
	media_events(world)
	Orders.tick(world,float(state.get("head_media_clock",0)))
	grinder_crates_tick(world)
	grinder_retail_tick(world)
	if not state.has("head_hello"):
		for unit in world.units:
			if world.actor_alive(unit) and unit.side=="ally" and unit.embarked_in==null and not unit.is_air_target() and Vector2i((unit.position/55).floor())==Vector2i(68,107):
				state.head_hello=true
				Events.emit_message("KBO AEO")
				break
	if not state.has("head_backdoor"):
		for u in world.units:
			if not world.actor_alive(u) or u.side!="ally" or u.is_air_target() or u.embarked_in!=null: continue
			var cell:Vector2i=Vector2i((u.position/55).floor())
			if not FIELD.data.backdoor_cells.any(func(p):return cell==Vector2i(p[0],p[1])): continue
			state.head_backdoor=true
			var p:Array=FIELD.data.backdoor_reveal
			# 0CBDEA2C uses radar action 55, not map reveal action 17.
			Events.emit_radar_ping((Vector2(p[0],p[1])+Vector2.ONE*0.5)*55,"campaign_discovery")
			line(world,"xs7so02","索菲亚","侦察部队发现了一条通往城堡后方的小路。")
			break
	for b in world.buildings:
		if not is_instance_valid(b) or not b.special.has("head_grinder"):continue
		var area:String=b.special.head_grinder
		if world.actor_alive(b) and b.side=="enemy" and world.actor_visible_to("ally",b): grinder_discovered(world,area)
		elif b.side!="enemy" and not state.has("head_grinder_lost_"+area): grinder_lost(world,area)

# SOV07 event 19 (Build Building Type), indices 24 and 54 in BuildingTypes.
static func retail_hostility_cells(world,s:Dictionary) -> void:
	var fired:Dictionary=s.get_or_add("s07_hostility_cells",{})
	for pair in [["0965013C",-1],["0965263C",0],["0965230C",1]]:
		var row:Dictionary=Orders.DRIVERS.extra[pair[0]]
		if fired.has(row.id) or s.has("head_games_freed_%d"%int(pair[1])):continue
		for u in world.units:
			if not world.actor_alive(u) or u.side!="ally" or u.embarked_in!=null or u.is_air_target():continue
			var tile:=Vector2i((u.position/55.0).floor())
			if not row.cells.any(func(c):return tile==Vector2i(int(c[0]),int(c[1]))):continue
			fired[row.id]=true
			var flags:Dictionary=s.get_or_add("s07_hostility_flags",{})
			for flag in row.clear:flags.erase(str(int(flag)))
			if not str(row.cue).is_empty():Ra2Sfx.play_player_eva(world,row.cue)
			Orders.dispatch(world,int(pair[1]))
			break

static func superweapon_built(world, site:Building) -> void:
	if site.side != "ally":return
	var rows:Dictionary=Orders.DRIVERS.superRows
	var kind:int={"NAIRON":24,"NAMISL":54}.get(site.building_id,-1)
	var level:=clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)
	var gates:Array=[]
	for id in ["0D06981C","0D06925C","0B5A3C8C","0B5A7A8C"]:
		if int(rows[id].conditions[0][0])==19 and int(rows[id].conditions[0][2])==kind:gates.append_array(rows[id].enable)
	if gates.is_empty() or int(rows["0DB011BC"].mask[level])==0:return
	var state:Dictionary = world.allied_state
	if state.has("head_super_start"): return
	state.head_super_start = float(state.get("head_media_clock",0))
	gates.append_array(rows["0DB011BC"].enable)
	state.s07_super_enabled=gates
	for id in ["0DB0041C","0DB01CAC","0DB018CC"]:
		if not super_conditions(state,rows[id]):continue
		line(world,"xs7yu01","尤里","好主意，指挥官。我看我的傀儡也该学学你，建造他们自己的超级武器。")
		break

static func super_conditions(state:Dictionary,row:Dictionary) -> bool:
	for e in row.conditions:
		if int(e[0]) not in [36,37]:continue
		var present:bool=state.has("head_super_start") if int(e[2])==0 else state.has("head_games_freed_%d"%(int(e[2])-5))
		if present!=(int(e[0])==36):return false
	return true

static func place_volunteers(world) -> void:
	for row in VOLUNTEERS:
		var u=world.spawn_unit(row[0],"neutral",Vector2(201.5-int(row[2]),int(row[1])-10.5)*55)
		if u==null: continue
		u.special.head_volunteer=true
		u.hold_position=true
		u.set_fire_stance("none")
	world.allied_state.head_volunteers_placed=true

static func rally_volunteers(world,s:Dictionary,now:float) -> void:
	if s.has("head_volunteers"): return
	# Old pre-discovery saves did not include the neutral actors.
	if not s.has("head_volunteers_placed"): place_volunteers(world)
	var actors:Array=world.units.filter(func(u):return world.actor_alive(u) and u.side=="neutral" and u.special.get("head_volunteer",false))
	var found:=false
	for u in actors:
		if world.actor_visible_to("ally",u):
			found=true
			break
	if not found: return
	s.head_volunteers=now
	var radius:=float(preload("res://scripts/core/yr_death_rules.gd").data().general.revealtriggerradius)*55.0
	for point in [VOLUNTEER_RALLY,Vector2(92.5,182.5)*55.0]: world.fog._reveal("ally",point,radius)
	Events.emit_radar_ping(VOLUNTEER_RALLY,"campaign_discovery")
	for u in actors:
		AlliedAbilities.change_side(u,"ally",false)
		u.hold_position=false
		u.set_fire_stance("free")
		u.order_move(VOLUNTEER_RALLY,false,null,world.path_for_unit(u,VOLUNTEER_RALLY))
	AlliedAbilities.refresh_after_side_changes(world)
	line(world,"xs7so04","索菲亚","指挥官，当地志愿军愿意加入我们的部队。")
	Events.emit_message("志愿军已加入。拥有雷达后，可在苏军兵营训练恐怖分子，在苏军战车工厂生产自爆卡车。")

static func media_events(world) -> void:
	var s:Dictionary=world.allied_state
	var now := float(s.get("head_media_clock",0))
	var difficulty := int(BattleRequest.skirmish_config.get("difficulty",1))
	rally_volunteers(world,s,now)
	if s.has("head_volunteers"):
		for row in [[5,"Terrorist-Sov07"],[10,"DemoTruck-Sov07"]]:
			if now-float(s.head_volunteers)>=int(row[0]) and not s.has(row[1]):
				s[row[1]]=true
				Ra2Sfx.play(row[1])
	var owned:Array=world.owned_building_ids("ally")
	preload("res://scripts/world/head_games_combine.gd").tick(world,now,difficulty,owned)
	if difficulty==0: return
	if not s.has("head_super_start"): return
	var since:=now-float(s.head_super_start)
	var rows:Dictionary=Orders.DRIVERS.superRows
	var hard:=difficulty==2
	var dom:Dictionary=rows["07F1BF3C" if hard else "0DB01E6C"]
	var timeline:Array=[[rows["07F2570C" if hard else "0D06808C"],"csof001",0],[rows["07F26E0C" if hard else "0CF90E6C"],"csof010",1],[dom,"csof125",-1],[rows["095CB76C"],"csof128",-1]]
	for cue in timeline:
		var entry:Dictionary=cue[0]
		var clip:String=cue[1]
		var due:=float(entry.delay)
		if clip=="csof128":
			if not dom.enable.has(entry.id):continue
			if s.has("s07_dom_spawn_at"):
				due=float(s.s07_dom_spawn_at)-float(s.head_super_start)+due
			elif s.get("csof125",false) and not s.has("s07_super_enabled") and not retail_yard_disabled(world,-1,"csof125"):
				due+=float(dom.delay) # Older saves did not record the spawn time.
			else:continue
		elif s.has("s07_super_enabled") and not s.s07_super_enabled.has(entry.id):continue
		if since<due or s.has(clip) or not super_conditions(s,entry):continue
		s[clip]=true
		if retail_yard_disabled(world,int(cue[2]),cue[1]):continue
		if int(cue[2])>=0 and s.has("head_games_freed_%d"%int(cue[2])):continue
		var site=preload("res://scripts/world/head_games_sites.gd").super_site(world,clip,entry.unit)
		if site==null:
			s.erase(clip)
			continue
		if clip=="csof125":s.s07_dom_spawn_at=now
		if clip=="csof128":
			Film.show_clip(world,"S07_P02E",func():Ra2Sfx.play_head_games_line("csof128"))
		else: Ra2Sfx.play_head_games_line(clip)

static func retail_yard_disabled(world,wing:int,clip:String) -> bool:
	var rule:Dictionary=Orders.DRIVERS.yards[str(wing)]
	var related:Array={"csof001":["0D06808C","0D06981C","0D06925C"],"csof010":["0B5A3C8C","0B5A7A8C","0CF90E6C"],"csof125":["0DB011BC","0DB01E6C"],"csof128":["095CB76C"]}.get(clip,[])
	return world.allied_state.has("s07_no_yard_%d"%wing) and related.any(func(id):return rule.disable.has(id))

static func grinder_discovered(world,area:String) -> void:
	var s:Dictionary=world.allied_state
	var key:="head_seen_"+area
	if s.has(key) or s.has("head_grinder_lost_"+area):return
	s[key]=true
	grinder_apply(world,"0CBEE55C" if area=="sw" else "0CBE799C")

static func grinder_apply(world,id:String) -> void:
	var row:Dictionary=Orders.DRIVERS.grinder[id]
	var s:Dictionary=world.allied_state
	var disabled:Dictionary=s.get_or_add("s07_grinder_disabled",{})
	if disabled.has(id) or int(row.mask[clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)])==0:return
	for next in row.disable:disabled[next]=true
	for flag in row.flags:s.get_or_add("s07_grinder_flags",{})[str(int(flag))]=true
	for next in row.enable:
		if not Orders.DRIVERS.grinder.has(next):continue
		if next=="0AA4409C":s.s07_grinder_sw_armed=true;continue
		s.get_or_add("s07_grinder_due",{})[next]=float(s.get("head_media_clock",0))+float(Orders.DRIVERS.grinder[next].delay)
	for crew in row.teams:
		if crew.at.is_empty() or s.has("head_games_freed_%d"%int(crew.wing)):continue
		var comp:Dictionary={}
		for member in crew.members:
			var type:String={"ADOG":"DOG","DOG":"SOV_DOG"}.get(member[1],member[1])
			comp[type]=int(member[0])
		spawn_team_at(world,int(crew.wing),Orders.location(crew.at),comp,id in ["0CBE9A3C","0CC9415C","0CC9453C","06B1C55C"])

static func grinder_retail_tick(world) -> void:
	var s:Dictionary=world.allied_state
	var due:Dictionary=s.get("s07_grinder_due",{})
	for id in due.keys():
		if float(s.get("head_media_clock",0))<float(due[id]):continue
		due.erase(id)
		grinder_apply(world,id)

# SOV07 action 108 type 0: SoloCrateMoney, at BU (72) or BV (73).
const GRINDER_CASH := 2500 # SOV07UMD overrides the global 5000 in [CrateRules].
const GRINDER_CRATE := preload("res://assets/maps/yr/field_crate.png")

static func grinder_crates_tick(world) -> void:
	var crates:Dictionary=world.allied_state.get("head_grinder_crates",{})
	if crates.is_empty():return
	for u in world.units:
		if not world.actor_alive(u) or u.side!="ally" or u.is_air_target() or u.embarked_in!=null:continue
		for area in crates.keys():
			var p:Vector2=crates[area]
			if Vector2i((u.position/55.0).floor())!=Vector2i((p/55.0).floor()):continue
			crates.erase(area)
			Ra2Fx.play(world.effects_root, p, "MONEY")
			world.add_funds(GRINDER_CASH)
			Events.emit_message("已拾取资金箱，获得 %d 资金。" % GRINDER_CASH)

static func draw_grinder_crates(world) -> void:
	for p in world.allied_state.get("head_grinder_crates",{}).values():
		if not world.position_visible_to("ally",p):continue
		var pos:=Iso.dir(p)
		var size:=GRINDER_CRATE.get_size()
		world.hp_overlay.draw_texture(GRINDER_CRATE,pos-Vector2(size.x*0.5,size.y-10.0))

static func grinder_lost(world,area:String) -> void:
	if world.allied_state.has("head_grinder_lost_"+area):return
	world.allied_state["head_grinder_lost_"+area]=true
	Orders.free_grinder_residents(world,area)
	world.allied_state.get_or_add("head_grinder_crates",{})[area]=(Vector2(20.5,94.5) if area=="sw" else Vector2(108.5,133.5))*55.0
	if area=="sw" and world.allied_state.get("s07_grinder_sw_armed",false):grinder_apply(world,"0AA4409C")
	grinder_apply(world,"0CBE9A3C" if area=="sw" else "06B1C55C")

static func attackers(world,delta:float) -> void:
	var s:Dictionary=world.allied_state
	s.head_media_clock=float(s.get("head_media_clock",0))+delta
	if s.has("s07_second_column_left"):
		s.s07_second_column_left=float(s.s07_second_column_left)-delta
		if float(s.s07_second_column_left)<=0.0:
			s.erase("s07_second_column_left")
			land_column(world,Orders.DRIVERS.landing["093A04FC"].members)
	if s.get("head_attack_done",false): return
	var elapsed:=float(s.get("head_scenario_time",0))+delta
	s.head_scenario_time=elapsed
	var retail:Array=Orders.DRIVERS.attack
	if not s.has("head_deployed"):
		if world._player_hq()!=null and retail[1].enable.has(retail[3].id):
			s.head_deployed=elapsed
			s.head_deploy_trigger=retail[0].id
		elif elapsed>=float(retail[2].delay) and retail[2].disable.has(retail[3].id):
			line(world,"xs7yu02","尤里","我已经等得不耐烦了。无论你在哪里建立基地，我和我控制的盟军、苏军都会找到你。")
			for wing in 3: attack_team(world,wing)
			s.head_attack_done=true
		if not s.has("head_deployed"): return
	var since:=elapsed-float(s.head_deployed)
	var level:=int(BattleRequest.skirmish_config.get("difficulty",1))
	var stage:=int(s.get("head_attack_stage",0))
	var opening:float=retail[3].delay
	var repeat:Dictionary=retail[6 if level==2 else 7]
	var delays:=[opening,opening+float(retail[4].delay),opening+float(retail[5].delay),opening+float(repeat.delay)]
	while stage<delays.size() and since>=int(delays[stage]):
		if stage==3:
			for wing in 3: attack_team(world,wing)
		else: attack_team(world,[1,0,2][stage])
		stage+=1
		s.head_attack_stage=stage
		if stage==4 or (int(repeat.mask[clampi(level,0,2)])==0 and stage==3):
			s.head_attack_done=true
			break

static func attack_team(world,wing:int) -> void:
	team(world,wing if wing<2 else -1,65+wing,ATTACKERS[wing],true)

# SOV07 05BC965C: actual attack event, not a later HP poll.
static func castle_attacked(world,building) -> void:
	if world.allied_state.has("castle_alert") or world.ended:return
	world.allied_state.castle_alert=true
	Ra2Sfx.play("NukeSiren")
	for row in FIELD.data.castle_guards:
		var wing:=int(row[4])
		var owner:="ally" if wing>=0 and world.allied_state.has("head_games_freed_%d"%wing) else "enemy"
		for i in int(row[3]):
			var guard=world.spawn_unit(row[0],owner,point(row)+Vector2(i*30,0))
			if guard==null:continue
			if wing>=0:assign_wing(guard,wing)
			if row[0]=="YENGINEER" and world.actor_alive(building):guard.order_interaction("allied_engineer",building,false)
	Events.emit_message("城堡拉响了警报，守军正在集结。")

static func check_player_loss(world) -> bool:
	if not Orders.DRIVERS.extra["0947BC0C"].enable.has("05FD863C") or not Orders.DRIVERS.extra["05FD863C"].lose:return false
	if world.has_surviving_assets("ally"):return false
	world.end_battle(false)
	return true

static func objectives(world) -> void:
	var active := [false,false]
	var castle_alive := false
	for building in world.buildings:
		if not world.actor_alive(building): continue
		if building.building_id==CASTLE:castle_alive=true
		if building.special.has("head_games_beacon"): active[int(building.special.head_games_beacon)] = true
	var now:=float(world.allied_state.get("head_media_clock",0))
	if not castle_alive:
		if not world.allied_state.has("s07_castle_down"):
			world.allied_state.s07_castle_down = now
			world.hud.minimap.clear_objective_flashes()
		var timeline:Array=Orders.DRIVERS.finish
		if not timeline[0].enable.has(timeline[1].id) or now-float(world.allied_state.s07_castle_down)<float(timeline[1].delay):return
	var released := false
	for wing in 2:
		var key := "head_games_freed_%d" % wing
		if (castle_alive and active[wing]) or world.allied_state.has(key): continue
		world.allied_state[key] = true
		released = true
		if not castle_alive:
			# 0E2AB85C / 0CD9E15C remove each remaining beacon before transfer.
			for beacon in world.buildings.duplicate():
				if world.actor_alive(beacon) and int(beacon.special.get("head_games_beacon",-1))==wing:beacon._die(null,true)
		for building in world.buildings.duplicate():
			if world.actor_alive(building) and building.special.get("head_games_wing", -1) == wing:
				var occupants: Array = building.special.get("occupants", [])
				var keep: bool = occupants.all(func(u): return not world.actor_alive(u) or (u.embarked_in==building and int(u.special.get("head_games_wing",-1))==wing))
				AlliedAbilities.change_side(building, "ally", false, keep)
		for unit in world.units.duplicate():
			if world.actor_alive(unit) and unit.special.get("head_games_wing", -1) == wing:
				AlliedAbilities.change_side(unit, "ally", false)
				unit.order_stop()
				unit.hold_position = false
		Events.emit_message("苏军基地已解除控制。" if wing == 0 else "盟军基地已解除控制。", Color.LIGHT_GREEN)
	if released:
		AlliedAbilities.refresh_after_side_changes(world)
		if castle_alive and not world.allied_state.has("head_brief_stage"):
			announce_objective_marks(world)
	if not castle_alive:
		var timeline:Array=Orders.DRIVERS.finish
		if now>=float(world.allied_state.get("s07_cheer_due",0)):
			for u in world.units:
				if world.actor_alive(u) and u.side=="ally" and u._seq.has("Cheer"):u.special.cheer_elapsed=0.0
			world.allied_state.s07_cheer_due=now+float(timeline[3].delay) if timeline[1].enable.has(timeline[3].id) else INF
		if timeline[1].enable.has(timeline[2].id) and now-float(world.allied_state.s07_castle_down)>=float(timeline[1].delay)+float(timeline[2].delay):world.end_battle(true)

