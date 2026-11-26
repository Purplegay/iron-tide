extends RefCounted

const ID := "yr_head_games"
const CASTLE := "CATRAN03"
const BEACON := "SOV07_BEACON"

const Orders = preload("res://scripts/world/head_games_orders.gd")
const FIELD = preload("res://data/head_games_field.json")

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
	preload("res://scripts/world/head_games_sites.gd").overlay_walls(world)
	for row in FIELD.data.sites:
		var id := BEACON if row[0] == "NAPSYB" else str(row[0])
		var definition := GameData.get_building(id)
		if definition.is_empty(): continue
		var dims := str(definition.get("foundation", "1x1")).split("x")
		var origin := point(row)
		if dims.size() == 2: origin += Vector2(1-int(dims[1]),int(dims[0])-1)*27.5
		var building = world._place_building(id,"enemy",origin,true)
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
		if int(row[3]) >= 0: assign_wing(unit,int(row[3]))
		if not unit.is_harvester:
			unit.order_stop()
			unit.hold_position = row[4] != "Area Guard"
			if not civilian and not unit.hold_position:
				unit.set_fire_stance("free")
				unit.special.campaign_area_guard = unit.global_position
	var hard := int(BattleRequest.skirmish_config.get("difficulty",1)) == 2
	team(world,1,1,{"MTNK":3,"MGTK":2} if hard else {"GGI":4,"MTNK":3})
	team(world,1,44,{"GHOST":4,"DOG":2} if hard else {"E1":5,"DOG":2})
	team(world,0,58,{"HTNK":2,"APOC":1,"DRON":2} if hard else {"SHK":3,"HTNK":2})
	team(world,0,49,{"E2":3,"FLAKT":2,"SOV_DOG":2,"SHK":2} if hard else {"E2":5,"FLAKT":2,"SOV_DOG":2})

static func arrive(world) -> void:
	if not BattleSaves.pending.is_empty(): return
	var n := 0
	for row in FIELD.data.landing:
		for i in int(row[3]):
			var goal := point(row) + Vector2.RIGHT.rotated(n*2.4)*float(24+n*3)
			var start := goal.move_toward(Vector2(43.5,148.5)*55.0,200)
			if world.path_service.is_blocked(start): start=point(row)
			if world.path_service.is_blocked(goal): goal=point(row)
			var unit = world.spawn_unit("SOV_DOG" if row[0]=="DOG" else row[0],"ally",start)
			unit.order_move(goal,false,null,world.path_for_unit(unit,goal))
			n+=1
	world.allied_state.head_brief_stage = 0
	world.allied_state.head_brief_left = 0.0

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
	Film.show_clip(world, "S07_F00E", func():
		Ra2Sfx.play_head_games_line("csof016")
		start_radio.call_deferred(world))

static func start_radio(world) -> void:
	Film.show_clip(world, "S07_P01E", func():
		world.allied_state.head_intro_done = true)

static func line(world,id:String,speaker:String,text:String) -> void:
	world.hud.show_field_transmission(speaker,text,"")
	Ra2Sfx.play_head_games_line(id)

static func briefing(world,delta:float) -> void:
	if world.has_node("HollywoodFilm"): return
	var state: Dictionary = world.allied_state
	var resume_clip: String = state.get("head_resume_clip", "")
	if resume_clip == "S07_F00E" or resume_clip == "S07_P01E":
		state.erase("head_resume_clip")
		if resume_clip == "S07_F00E": start_film(world)
		else: start_radio(world)
		return
	if not state.get("head_intro_done", true): return
	state.head_brief_left-=delta
	if state.head_brief_left>0: return
	var stage:=int(state.head_brief_stage)
	if stage<3:
		var cell:Array=FIELD.data.briefing_points[stage]
		var p:=Vector2(cell[0],cell[1])*55
		world.center_on(p)
		if world.fog!=null: world.fog._reveal("ally",p,410,4.0)
		Events.emit_message(["尤里的城堡在这里。摧毁它，就能结束这场战役。","这座心灵信标控制着盟军。摧毁它，盟军基地就会加入我方。","苏军基地也被控制了。摧毁这座信标，解放我们的同志。"][stage])
		state.head_brief_stage=stage+1
		state.head_brief_left=3.0
		announce_objective_marks(world)
	else:
		state.erase("head_brief_stage")
		state.erase("head_brief_left")
		world.center_on(world.player_start())
		Ra2Sfx.play_head_games_line("csof120")
		Events.emit_message("部队已抵达，选中基地车，按 J 展开建造场。")

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
	media_events(world)
	Orders.tick(world,float(state.get("head_media_clock",0)))
	if not state.has("head_hello"):
		for unit in world.units:
			if world.actor_alive(unit) and unit.side=="ally" and Vector2i((unit.position/55).floor())==Vector2i(68,107):
				state.head_hello=true
				Events.emit_message("KBO AEO")
				break
	if not state.has("head_backdoor"):
		for u in world.units:
			if not world.actor_alive(u) or u.side!="ally" or u.is_air_target(): continue
			var cell:Vector2i=Vector2i((u.position/55).floor())
			if not FIELD.data.backdoor_cells.any(func(p):return cell==Vector2i(p[0],p[1])): continue
			state.head_backdoor=true
			var p:Array=FIELD.data.backdoor_reveal
			world.fog._reveal("ally",(Vector2(p[0],p[1])+Vector2.ONE*0.5)*55,275,4.0)
			line(world,"xs7so02","索菲亚","侦察部队发现了一条通往城堡后方的小路。")
			break
	for b in world.buildings:
		if not is_instance_valid(b) or not b.special.has("head_grinder"):continue
		var area:String=b.special.head_grinder
		if world.actor_alive(b) and b.side=="enemy" and world.actor_visible_to("ally",b) and not state.has("head_seen_"+area):
			state["head_seen_"+area]=true
			team(world,-1,15 if area=="sw" else 22,{"BRUTE":3,"VIRUS":1,"YURI":1,"INIT":4})
		elif b.side!="enemy" and not state.has("head_grinder_lost_"+area): grinder_lost(world,area)

# SOV07 event 19 (Build Building Type), indices 24 and 54 in BuildingTypes.
static func superweapon_built(world, site:Building) -> void:
	if site.side != "ally" or site.building_id not in ["NAIRON","NAMISL"]: return
	if int(BattleRequest.skirmish_config.get("difficulty",1)) == 0: return
	var state:Dictionary = world.allied_state
	if state.has("head_super_start"): return
	state.head_super_start = float(state.get("head_media_clock",0))
	if not (state.has("head_games_freed_0") and state.has("head_games_freed_1")):
		line(world,"xs7yu01","尤里","好主意，指挥官。我看我的傀儡也该学学你，建造他们自己的超级武器。")

static func media_events(world) -> void:
	var s:Dictionary=world.allied_state
	var now := float(s.get("head_media_clock",0))
	var difficulty := int(BattleRequest.skirmish_config.get("difficulty",1))
	if not s.has("head_volunteers") and world.fog.is_visible_at("ally",Vector2(91.5,179.5)*55):
		s.head_volunteers=now
		line(world,"xs7so04","索菲亚","指挥官，当地志愿军愿意加入我们的部队。")
		for row in [["TERROR",190,110],["TERROR",190,112],["TERROR",191,111],["DTRUCK",193,110],["DTRUCK",193,107]]:
			world.spawn_unit(row[0],"ally",Vector2(201.5-int(row[2]),int(row[1])-10.5)*55)
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
	var dom:=300 if difficulty==2 else 445
	for cue in [[280 if difficulty==2 else 205,"csof001",0],[290 if difficulty==2 else 325,"csof010",1],[dom,"csof125",-1],[dom+205,"csof128",-1]]:
		var clip:String=cue[1]
		if since<int(cue[0]) or s.has(clip):continue
		s[clip]=true
		if s.has("s07_no_yard_%d"%int(cue[2])):continue
		if int(cue[2])>=0 and s.has("head_games_freed_%d"%int(cue[2])):continue
		preload("res://scripts/world/head_games_sites.gd").super_site(world,clip)
		if clip=="csof128":
			Film.show_clip(world,"S07_P02E",func():Ra2Sfx.play_head_games_line("csof128"))
		else: Ra2Sfx.play_head_games_line(clip)

static func grinder_lost(world,area:String) -> void:
	if world.allied_state.has("head_grinder_lost_"+area):return
	world.allied_state["head_grinder_lost_"+area]=true
	if area=="sw":
		team(world,-1,62,{"MIND":1,"YTNK":2},true)
		if not world.allied_state.has("head_games_freed_1"):team(world,1,63,{"E1":5,"GGI":3},true)
		if not world.allied_state.has("head_games_freed_0"):team(world,0,64,{"HTK":1,"HTNK":2,"TTNK":1},true)
	elif int(BattleRequest.skirmish_config.get("difficulty",1))>0: team(world,-1,68,{"YTNK":2,"LTNK":3},true)

static func attackers(world,delta:float) -> void:
	var s:Dictionary=world.allied_state
	s.head_media_clock=float(s.get("head_media_clock",0))+delta
	if s.get("head_attack_done",false): return
	var elapsed:=float(s.get("head_scenario_time",0))+delta
	s.head_scenario_time=elapsed
	if not s.has("head_deployed"):
		if world._player_hq()!=null: s.head_deployed=elapsed
		elif elapsed>=120:
			line(world,"xs7yu02","尤里","我已经等得不耐烦了。无论你在哪里建立基地，我和我控制的盟军、苏军都会找到你。")
			for wing in 3: attack_team(world,wing)
			s.head_attack_done=true
		if not s.has("head_deployed"): return
	var since:=elapsed-float(s.head_deployed)
	var level:=int(BattleRequest.skirmish_config.get("difficulty",1))
	var stage:=int(s.get("head_attack_stage",0))
	var delays:=[45,75,90,165 if level==2 else 255]
	while stage<delays.size() and since>=int(delays[stage]):
		if stage==3:
			for wing in 3: attack_team(world,wing)
		else: attack_team(world,[1,0,2][stage])
		stage+=1
		s.head_attack_stage=stage
		if stage==4 or (level==0 and stage==3):
			s.head_attack_done=true
			break

static func attack_team(world,wing:int) -> void:
	team(world,wing if wing<2 else -1,65+wing,ATTACKERS[wing],true)

static func objectives(world) -> void:
	var active := [false,false]
	var castle_alive := false
	for building in world.buildings:
		if not world.actor_alive(building): continue
		if building.building_id == CASTLE:
			castle_alive = true
			if building.hp < building.max_hp and not world.allied_state.has("castle_alert"):
				world.allied_state.castle_alert = true
				Ra2Sfx.play("NukeSiren")
				for row in FIELD.data.castle_guards:
					var wing := int(row[4])
					var owner := "ally" if wing >= 0 and world.allied_state.has("head_games_freed_%d" % wing) else "enemy"
					for i in int(row[3]):
						var guard = world.spawn_unit(row[0],owner,point(row)+Vector2(i*30,0))
						if guard!=null and row[0]=="YENGINEER":guard.order_interaction("allied_engineer",building,false)
						if guard != null and wing >= 0: assign_wing(guard,wing)
				Events.emit_message("城堡拉响了警报，守军正在集结。")
		if building.special.has("head_games_beacon"): active[int(building.special.head_games_beacon)] = true
	var now:=float(world.allied_state.get("head_media_clock",0))
	if not castle_alive:
		if not world.allied_state.has("s07_castle_down"):
			world.allied_state.s07_castle_down = now
			world.hud.minimap.clear_objective_flashes()
		if now-float(world.allied_state.s07_castle_down)<3:return
	var released := false
	for wing in 2:
		var key := "head_games_freed_%d" % wing
		if (castle_alive and active[wing]) or world.allied_state.has(key): continue
		world.allied_state[key] = true
		released = true
		for building in world.buildings.duplicate():
			if world.actor_alive(building) and building.special.get("head_games_wing", -1) == wing:
				AlliedAbilities.change_side(building, "ally", false)
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
		if now>=float(world.allied_state.get("s07_cheer_due",0)):
			for u in world.units:
				if world.actor_alive(u) and u.side=="ally" and u._seq.has("Cheer"):u.special.cheer_elapsed=0.0
			world.allied_state.s07_cheer_due=now+3
		if now-float(world.allied_state.s07_castle_down)>=12:world.end_battle(true)

