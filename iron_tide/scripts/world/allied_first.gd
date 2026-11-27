extends RefCounted
## Allied Time Lapse; mission state is independent from the Soviet Time Shift.
const ID := "yr_allied_first"
const MAP := "yr_all01umd"
const Field = preload("res://data/ra2/allied_first_field.json")
const Overlays = preload("res://data/ra2/allied_first_overlays.json")
const Places = preload("res://scripts/world/native_maps.gd")
const Film = preload("res://scripts/ui/hollywood_film.gd")
const RetailDriver = preload("res://scripts/world/allied_retail_script.gd")

static func start_victory_driver(s: Dictionary) -> void:
	var driver := RetailDriver.new()
	if not driver.start(MAP,clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)): return
	# Only hand off the two terminal timers. The mission still owns the destruction condition.
	driver.state.enabled.clear()
	driver.enable("089ecdec")
	driver.enable("089ec79c")
	s.retail_victory = driver.snapshot()

static func tick_victory_driver(world,s: Dictionary,delta: float) -> void:
	var driver := RetailDriver.new()
	if not driver.restore(s.retail_victory):
		push_error("ALL01UMD: invalid retail victory state")
		return
	var command := driver.advance(delta)
	while not command.is_empty():
		if command.trigger=="089ecdec" and command.opcode==113:
			s.victory_cheer = true
			for u in world.units:
				if world.actor_alive(u) and u.side=="ally" and u._seq.has("Cheer"): u.special.cheer_elapsed = 0.0
		elif command.trigger=="089ec79c" and command.opcode==1:
			driver.acknowledge(command.token)
			s.retail_victory = driver.snapshot()
			world.end_battle(true)
			return
		else:
			push_error("ALL01UMD: unexpected retail victory action %s" % command)
			break
		driver.acknowledge(command.token)
		command = driver.advance(0.0)
	s.retail_victory = driver.snapshot()

static func side(house: String) -> String:
	if house in ["Americans", "Alliance", "British"]: return "ally"
	if house in ["PowerHouse", "BridgeHouse", "Neutral"]: return "neutral"
	return "enemy"

const Assault=preload("res://scripts/world/allied_first_assault.gd")
const Sites = preload("res://data/ra2/allied_first_sites.json")

static func place_scenery(world) -> void:
	var root := Node2D.new()
	root.name = "AlliedFirstScenery"
	world.add_child(root)
	var textures := {}
	for row in Sites.data.props:
		var id: String = row[0]
		if id.begins_with("TIBTRE"): continue # Native ore installs the drill at this cell.
		if not textures.has(id): textures[id] = load(Sites.data.textures[id])
		var sprite := Sprite2D.new()
		sprite.texture = textures[id]
		var at := Vector2(row[1],row[2])*Places.CELL
		sprite.offset.y = -sprite.texture.get_height()*0.5
		sprite.transform = Transform2D(Iso.eff_angle(),Iso.up()*1.30,0,at)
		sprite.z_index = DepthLayers.entity_z(at,world.map_size)
		root.add_child(sprite)

static func setup(world) -> void:
	place_scenery(world)
	if not BattleSaves.pending.is_empty(): return
	world.allied_state.allied_first = {"phase":0, "map_field_rows":true, "map_assault_rows":true, "map_closing_rows":true, "missing":[], "original_reactor_registered":true}
	var layout := Places.data(MAP)
	for row in Field.data.structures:
		if not row[8] or int(row[3]) <= 0: continue
		var id: String = row[2]
		var def := GameData.get_building(id)
		# Native scenery without a gameplay definition is placed by NativeMaps.
		if def.is_empty():
			record_missing(world,id)
			continue
		var dims := str(def.get("foundation", "1x1")).split("x")
		var at := Vector2(row[4],row[5])*Places.CELL
		if dims.size()==2: at += Vector2(1-int(dims[1]),int(dims[0])-1)*Places.CELL*.5
		var b = world._place_building(id, side(row[1]), at, true)
		if b == null: continue
		b.special.allied_first_room = row[1]
		b.special.allied_first_index = row[0]
		b.special.allied_first_tag = str(row[7]).to_lower()
		b.refresh_house_color()
		if id=="GTGCAN": b.special.no_crew = true
		b.hp = b.max_hp*float(row[3])/256.0
	for rows in [Field.data.units, Field.data.infantry]:
		for row in rows:
			if not row[8]: continue
			var id: String = row[2]
			if GameData.get_unit(id).is_empty():
				record_missing(world,id)
				continue
			var u = world.spawn_unit(id,side(row[1]),Vector2(row[4],row[5])*Places.CELL)
			if u == null: continue
			u.special.allied_first_room = row[1]
			u.special.allied_first_index = row[0]
			u.refresh_house_color()
			u.hp = u.max_hp*float(row[3])/256.0
			if not u.is_harvester:
				u.order_stop()
				u.hold_position = true
	install_overlay_walls(world,world.allied_state.allied_first)
	world.center_on(Vector2(layout.starts[0][1],layout.starts[0][2])*Places.CELL)
	# Fog setup ran before the retail roster existed. Publish the field before either clip pauses simulation.
	if world.fog != null: world.fog.rebuild()
	world._update_power()
	resume_media(world)

static func install_overlay_walls(world,s: Dictionary) -> void:
	if s.is_empty() or s.get("overlay_walls_installed",false): return
	s.overlay_walls_installed = true
	for row in Overlays.data.rows:
		var id: String = row[2]
		if id not in ["CAFNCP","CAFNCB","GAWALL"]: continue
		var p := (Vector2(row[0],row[1])+Vector2(0.5,0.5))*Places.CELL
		var wall = world._place_building(id,"neutral",p,true)
		if wall != null:
			wall.special.native_wall_pitch = Places.CELL
			wall.special.allied_first_overlay = true
			wall.queue_redraw()
	world._refresh_pathing()
	if world.fog != null: world.fog.rebuild()

static func resume_media(world) -> void:
	var s: Dictionary = world.allied_state.get("allied_first",{})
	install_overlay_walls(world,s)
	sync_smudges(world,s)
	if s.get("phase") == 0:
		Film.show_clip(world,"A01_F00E",func():
			s.phase = -1
			world.hud._refresh_timer()
			var previous = world.get_node_or_null("HollywoodFilm")
			if previous!=null:
				# Completing inside VideoStreamPlayer's frame can leave the old name
				# occupied until queue_free runs. Mount the radio only after it exits.
				previous.tree_exited.connect(resume_media.bind(world),CONNECT_ONE_SHOT|CONNECT_DEFERRED)
			else:
				resume_media.call_deferred(world))
	elif s.get("phase") == -1 and not world.has_node("HollywoodFilm"):
		Film.show_clip(world,"A01_P01E",func(): open_orders(world))
	else:
		# Restored objectives must be visible even if the loaded battle is paused.
		world.hud._refresh_timer()

	if s.get("phase")==2 and s.get("power_movie_pending",false) and not world.has_node("HollywoodFilm"):
		Film.show_clip(world,"A01_P02E",func(): s.power_movie_pending = false)
	if s.get("phase") == 3:
		world.TimeShift.sync_crossing_visual(world,s)
	if s.get("phase") == 4 and s.get("past_report",false) and not world.has_node("HollywoodFilm"):
		Film.show_clip(world,s.get("past_clip","A01_P02E"),func():
			s.past_report = false
			# Older saves could have queued the clip after Tanya had already arrived.
			if not s.get("awaiting_tanya",false): tanya_brief(world))

static func record_missing(world, id: String) -> void:
	var missing: Array = world.allied_state.allied_first.missing
	if not id in missing: missing.append(id)

static func open_orders(world) -> void:
	world.allied_state.allied_first.phase = 1
	if world.allied_state.allied_first.get("map_assault_rows",false): world.allied_state.allied_first.assault_radio_delivered=true
	world.allied_state.allied_first.power_sequence_new = true
	world.allied_state.allied_first.ggi_intro_left = 1.0
	world.allied_state.allied_first.opening_from_table = true
	if world.allied_state.allied_first.get("map_assault_rows",false): tick_opening_ggi(world,world.allied_state.allied_first,0.0)
	else: Ra2Sfx.play_player_eva(world,"EVA_EstablishBattlefieldControl",0)
	world.hud.show_field_transmission("伊娃", "派工程师占领发电厂，为时光机恢复供电。", "")
	for mark in marks(world,true):
		Events.emit_radar_ping(mark.position,"campaign_site")
	world.hud._refresh_timer()

static func send_opening_attack(world,s: Dictionary) -> void:
	s.ggi_attack_sent = true
	# Flash_GGI enables 089F2AAC, which creates team 09F3BC1C at AP.
	for i in range(5):
		var infantry = world.spawn_unit("INIT","enemy",wp(41)+Vector2((i%3-1)*25,(i/3)*25))
		if infantry==null: continue
		infantry.special.allied_first_room = "YuriCountry"
		infantry.special.allied_first_team = "09F3BC1C"
		infantry.order_move(wp(14),true)

# Camera_GGI -> Flash_GGI. Use the already placed allied team near N.
static func tick_opening_ggi(world,s: Dictionary,delta: float) -> void:
	if s.get("opening_from_table",false):
		var opening = world.get_meta("first_opening_driver") if world.has_meta("first_opening_driver") else null
		if opening==null:
			opening = preload("res://scripts/world/allied_first_opening.gd").new()
			if not opening.initialize(s,clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)):
				push_error("Invalid ALL01 opening-team state")
				return
			world.set_meta("first_opening_driver",opening)
		if s.get("map_assault_rows",false):
			var driver=assault_driver(world,s)
			if driver!=null: driver.run(world,s,delta,opening)
		else: opening.run(world,s,delta)
		return
	if s.has("ggi_attack_left"):
		s.ggi_attack_left = float(s.ggi_attack_left)-delta
		if s.ggi_attack_left<=0.0:
			s.erase("ggi_attack_left")
			send_opening_attack(world,s)
	if not s.has("ggi_intro_left"): return
	s.ggi_intro_left = float(s.ggi_intro_left)-delta
	if s.ggi_intro_left>0.0: return
	s.erase("ggi_intro_left")
	var at := wp(13)
	var group: Array = world.units.filter(func(u):return world.actor_alive(u) and u.unit_id=="GGI" and u.side=="ally" and u.position.distance_to(at)<Places.CELL*3.0)
	if group.is_empty(): return
	s.ggi_intro_shown = true
	# Recruit the two pre-placed V tanks, rather than spawn duplicates.
	for u in world.units:
		if not world.actor_alive(u) or u.side!="enemy" or u.unit_id!="LTNK" or u.special.get("allied_first_index", "") not in ["0","14"]: continue
		u.hold_position = false
		u.special.allied_first_team = "0BF1048C"
		u.order_move(wp(22))
	s.ggi_attack_left = 5.0 # GGI_to_GGI_Flash (3), Flash_GGI (1), Attack_Tanya (1).
	speech(world,"伊娃","这是重装大兵。部署后可用导弹打击装甲和飞机。","cevau75")
	Events.emit_radar_ping(at,"campaign_site")

const Orders = preload("res://scripts/units/allied_abilities.gd")
const GlobalAI = preload("res://scripts/world/allied_first_ai.gd")
const PowerSequence = preload("res://scripts/world/allied_first_power.gd")
const CHARGE_SECONDS := 29.0 # HUD fallback before the power sequence is initialized.
# ALL01UMD 087C0E4C / 087C0F3C / 087C0D5C. Raw fields are mapped to project simulation seconds.
const Armor = preload("res://scripts/world/allied_first_armor.gd")
const TANYA_DELAY := 5.0

static func armor_delay(difficulty: int) -> float:
	return Armor.delay(difficulty)

static func wp(id: int) -> Vector2:
	var row: Array = Places.data(MAP).waypoints[str(id)]
	return Vector2(row[0],row[1])*Places.CELL

static func site(world, id: String):
	for b in world.buildings:
		if world.actor_alive(b) and b.building_id == id: return b
	return null

static func plants(world) -> int:
	var count := 0
	for b in world.buildings:
		if world.actor_alive(b) and b.side=="ally" and b.building_id.begins_with("CAPOWR0"): count += 1
	return count

static func grid_ready(world) -> bool:
	return plants(world)>0 and not world._side_power("ally").low

static func speech(world, who: String, text: String, sample := "") -> void:
	world.hud.show_field_transmission(who,text,"")
	if sample.is_empty(): return
	var path := "res://assets/ra2/allied_first/"+sample+".wav"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else (AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else null)
	if stream==null: return
	var previous = world.get_node_or_null("AlliedFirstVoice")
	if previous != null:
		previous.stop()
		previous.queue_free()
	var voice := AudioStreamPlayer.new()
	voice.name = "AlliedFirstVoice"
	voice.stream = stream
	world.add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

static func objective(world) -> Dictionary:
	var s: Dictionary = world.allied_state.get("allied_first",{})
	var grid: Dictionary = world._side_power("ally")
	var power := "已占领 %d/8 座 · 供电 %d / 需求 %d" % [plants(world),int(grid.produced),int(grid.drain)]
	var title := "占领任务发电厂，为时光机供电"
	var progress := power
	var detail := "派工程师占领发电厂，直到供电满足基地需求。"
	match int(s.get("phase",0)):
		-1,0:
			title = "战前简报 · 旧金山"
			progress = "简报结束后可下令"
			detail = "正在播放战前简报。按右下角的「跳过简报」可继续。\n接下来的任务：派工程师占领发电厂。"
		1:
			if s.get("assault_input_locked",false):
				title = "正在标出时光机和发电厂"
				progress = "标记完成后可指挥工程师"
				detail = "派工程师占领任务发电厂，为时光机恢复供电。\n"+power
		2:
			title = "保护时光机，等待充能"
			progress = "充能剩余 %d 秒" % ceili(float(s.get("charge",CHARGE_SECONDS))) if not grid.low else "供电不足，充能已暂停"
			detail = "守住时光机和已占领的电厂。失去供电时，夺回发电厂即可继续充能。\n"+power
		3:
			title = "时光机正在运转"
			progress = "穿越时空"
			detail = "等待时间转移完成。"
		4:
			if s.get("awaiting_tanya",false):
				if not s.get("armor_sent",false):
					title = "守住旧金山，准备迎击装甲部队"
					progress = "敌军预计 %d 秒后进入战区" % ceili(float(s.armor_left))
				else:
					title = "击退装甲部队，掩护谭雅入场"
					var remaining := armor_remaining(world)
					if s.get("map_field_rows",false) and remaining==0 and world.units.any(func(u):return world.actor_alive(u) and u.special.get("allied_first_room","") in ["Special","Soviet2House"]):
						return {"title":"清除剩余苏军，掩护谭雅入场","progress":"仍有苏军作战单位在场","detail":"击退剩余部队，包括基洛夫空艇。"}
					progress = "剩余敌军装甲：%d 辆" % remaining if remaining > 0 else "谭雅正在赶来"
				return {"title":title,"progress":progress,"detail":"%s\n%s" % [title,progress]}
			title = "摧毁恶魔岛的心灵控制器"
			progress = "用航母攻击恶魔岛" if s.get("carriers",false) else "派谭雅游泳登岛；围栏挡路时，先开火打出缺口"
			detail = progress
		5:
			title = "心灵控制器已摧毁"
			progress = "即将完成任务"
			detail = "等待战斗结算。"
	return {"title":title,"progress":progress,"detail":"%s\n%s" % [detail,progress]}

static func marks(world, _radar: bool) -> Array:
	var phase: int = world.allied_state.allied_first.phase
	var result: Array = []
	for b in world.buildings:
		if not world.actor_alive(b): continue
		if (phase == 1 or (phase == 2 and world.power_low)) and b.building_id.begins_with("CAPOWR0") and b.side != "ally":
			result.append(world.CampaignMarks.entry(b.position,"占领任务发电厂",b))
		if phase == 2 and b.building_id == "CATIME01":
			result.append(world.CampaignMarks.entry(b.position,"保护时光机",b))
		if phase == 1 and world.allied_state.allied_first.get("hospital_found",false) and b.building_id=="CATHOSP" and b.side=="neutral":
			result.append(world.CampaignMarks.entry(b.position,"可占领：科技医院",b))
		if phase == 4 and not world.allied_state.allied_first.get("awaiting_tanya",false) and b.special.get("allied_first_dominator",false):
			result.append(world.CampaignMarks.entry(b.position,"摧毁心灵控制器",b))
	return result

# 0691357C / TEAM_Nuke_Repair (0DC53EFC), BG -> nuclear reactor at 364.
static func dispatch_reactor_engineer(world,s: Dictionary) -> void:
	if s.get("reactor_engineer_sent",false): return
	var reactor = site(world,"NANRCT")
	if reactor == null or reactor.side != "enemy" or reactor.hp >= reactor.max_hp: return
	if world.fog != null: world.fog._reveal("enemy",reactor.position,world.fog.CELL,world.fog.FIRE_REVEAL_SECONDS)
	var engineer = world.spawn_unit("ENGINEER","enemy",wp(58))
	if engineer == null: return
	s.reactor_engineer_sent = true
	engineer.special.allied_first_room = "Confederation"
	engineer.refresh_house_color()
	if not Orders.use(engineer,"allied_engineer",reactor):
		engineer.order_move(Orders.approach(engineer,reactor))

# Project adaptation: deliver real engineer orders after capture. The retail
# per-plant trigger graph tracks changes, but this is not a retail spawn action.
static func contest_plants(world,s: Dictionary,delta: float) -> void:
	var tickets: Dictionary = s.get("plant_contests",{})
	for plant in world.buildings:
		if not world.actor_alive(plant) or not plant.building_id.begins_with("CAPOWR0"): continue
		var id: String = plant.building_id
		if plant.side != "ally":
			tickets.erase(id)
			continue
		var previous := float(tickets.get(id,18.0))
		if previous < 0.0: continue
		var left := previous-delta
		if left > 0.0:
			tickets[id] = left
			continue
		if world.units.any(func(u):return world.actor_alive(u) and u.special.get("allied_first_retake")==id): continue
		# Start near an existing enemy patrol, not next to the plant or inside its footprint.
		var post = null
		var best := INF
		for u in world.units:
			if not world.actor_alive(u) or u.side!="enemy" or u.special.get("allied_first_room")!="YuriCountry" or u.unit_id!="INIT": continue
			var distance: float = u.position.distance_squared_to(plant.position)
			if distance < best: best=distance; post=u
		if post == null:
			tickets[id] = -1.0
			continue
		var engineer = world.spawn_unit("ENGINEER","enemy",post.position+Vector2(32,0))
		if engineer != null:
			engineer.special.allied_first_room = "YuriCountry"
			engineer.special.allied_first_retake = id
			Orders.use(engineer,"allied_engineer",plant)
		tickets[id] = -1.0
	s.plant_contests = tickets

static func tick_power_sequence(world,s: Dictionary,delta: float) -> void:
	var sequence = world.get_meta("allied_first_power_sequence",null) if world.has_meta("allied_first_power_sequence") else null
	if sequence==null:
		sequence = PowerSequence.new()
		if not sequence.initialize(world,s):
			push_error("ALL01UMD: invalid power sequence")
			return
		world.set_meta("allied_first_power_sequence",sequence)
	sequence.step(world,s,delta)

static func begin_charge(world,s: Dictionary,machine,duration: float) -> void:
	s.phase = 2
	s.charge = duration
	s.machine_hp = machine.hp
	world.hud._refresh_timer()
	speech(world,"伊娃","电力已恢复。保护时光机，直到充能完成。","xa1ev06")
	Events.emit_radar_ping(machine.position,"campaign_site")

static func armor_remaining(world) -> int:
	var count := 0
	for u in world.units:
		if world.actor_alive(u) and u.side == "enemy" and u.special.get("allied_first_raid",false): count += 1
	return count

static func direct_armor(world) -> void:
	for u in world.units:
		if not world.actor_alive(u) or u.side!="enemy" or not u.special.get("allied_first_raid",false): continue
		if u.has_move_order or world.actor_alive(u.attack_target): continue
		var target = null
		var best := INF
		for actor in world.units + world.buildings:
			if not world.actor_alive(actor) or actor.side!="ally" or not u.attack_domain_valid(actor): continue
			if not world.actor_visible_to("enemy",actor): continue
			var distance: float = u.position.distance_squared_to(actor.position)
			if distance < best:
				best = distance
				target = actor
		if target != null: u.order_target(target,false,false)

static func begin_crossing(world,s: Dictionary,machine) -> void:
	s.phase = 3
	s.crossing_era = 1
	s.crossing_time = 0.0
	s.crossing_swapped = false
	world.cancel_pointer_gestures()
	world.clear_selection()
	world._emit_selection()
	world.hud.minimap.clear_radar_events()
	world.center_on(machine.position)
	world.TimeShift.sync_crossing_visual(world,s)

static var naval_orders: Dictionary = {}

static func spawn_naval_group(world,trigger: String,only_team := "") -> bool:
	var spawned := false
	for row in RetailDriver.DATA.data[MAP].naval_fleet[trigger]:
		if not only_team.is_empty() and row.id!=only_team: continue
		var ship = world.spawn_unit(row.unit,side(row.house),wp(int(row.waypoint)))
		if ship==null: return false
		spawned = true
		ship.special.allied_first_team = row.id
		ship.special.allied_first_room = row.house
		ship.refresh_house_color()
		var steps: Array = row.steps
		if int(steps[0][0])==42:
			# Script direction uses compass octants, increasing clockwise from north.
			var heading := Vector2.UP.rotated((int(steps[0][1])+1)*PI/4.0)
			ship.hull_angle = heading.angle()
			ship._face(ship.position+heading)
		if row.unit=="HYD":
			var route := []
			for step in steps:
				if int(step[0])==3: route.append(int(step[1]))
			ship.special.allied_first_patrol_route = route
			ship.special.allied_first_patrol_step = 0
		elif row.unit=="DRED":
			ship.special.allied_first_dread_step = 0
		else:
			ship.order_stop()

	return spawned

static func dread_route(id: String) -> Array:
	if naval_orders.is_empty():
		for group in RetailDriver.DATA.data[MAP].naval_fleet.values():
			for row in group:
				if row.unit=="DRED": naval_orders[row.id] = row.steps.slice(1)
	return naval_orders.get(id,[])

# DX / 0955BB7C: 46,131138 = 0x00020042, building type 66 (NANRCT).
# Track the retail room even though both houses currently share the enemy combat side.
static func tick_dx_order(world,ship,launched: Dictionary) -> void:
	if ship.special.get("allied_first_dx_done",false): return
	var reactor = null
	for b in world.buildings:
		if world.actor_alive(b) and b.building_id=="NANRCT" and b.special.get("allied_first_room")=="Confederation":
			reactor = b
			break
	if reactor == null:
		ship.order_stop()
		ship.special.allied_first_dx_done = true
		return
	if launched.get(ship)==reactor.position:
		ship.order_stop()
		ship.special.allied_first_dx_done = true
		return
	if ship.attack_ordered and ship.attack_target==reactor: return
	ship.order_target(reactor,true,false)

static func tick_dread_orders(world, state: Dictionary, delta: float) -> void:
	state.dread_order_left = float(state.get("dread_order_left",0.0))-delta
	if state.dread_order_left > 0.0: return
	state.dread_order_left = 0.2
	var launched := {}
	for missile in world.units:
		if not world.actor_alive(missile) or missile.unit_id!="DMISL": continue
		var flight: Dictionary = missile.special.get("flight",{})
		var launcher = flight.get("source")
		if world.actor_alive(launcher): launched[launcher] = flight.get("aim",Vector2.INF)
	for ship in world.units:
		if not world.actor_alive(ship) or ship.side!="enemy" or ship.unit_id!="DRED": continue
		if ship.special.get("allied_first_team")=="0955BB7C":
			tick_dx_order(world,ship,launched)
			continue
		var route: Array = dread_route(ship.special.get("allied_first_team",""))
		if route.is_empty(): continue
		var cursor := int(ship.special.get("allied_first_dread_step",0))
		if cursor >= route.size(): continue
		var row: Array = route[cursor]
		if row[0]==6:
			# The facing instruction was executed on spawn and occupies retail line 1.
			ship.special.allied_first_dread_step = maxi(0,int(row[1])-2)
			continue
		var at := wp(row[1])
		if row[0]==3:
			if ship.position.distance_to(at)<Places.CELL:
				ship.special.allied_first_dread_step = cursor+1
			elif not ship.has_move_order or not ship.move_target.is_equal_approx(at):
				ship.order_move(at)
			continue
		if launched.get(ship)==at:
			ship.order_stop()
			ship.special.allied_first_dread_step = cursor+1
			continue
		if ship.attack_ordered and ship.attack_target is ForceFirePoint and ship.attack_target.position==at: continue
		var point := ForceFirePoint.new()
		point.global_position = at
		point.side = "ally"
		ship.order_target(point,true,false)

# 067DD9FC / 089D5A8C: use action-80 waypoints (not the TeamType defaults).
static func deploy_followup_fleet(world,s: Dictionary) -> void:
	if s.get("followup_fleet_sent",false): return
	s.followup_fleet_sent = true
	spawn_naval_group(world,"067dd9fc")
	var city = city_driver(world,s)
	if city!=null:
		city.enable(city.FLEET)
		city.run(world,s,0.0)

# Kill_Sounds3 (04C24A8C) creates these five teams in the past.
static func deploy_past_harbor(world,s: Dictionary) -> void:
	if s.get("past_harbor_sent",false): return
	s.past_harbor_sent = true
	if s.get("map_field_rows",false):
		var field=field_driver(world,s)
		if field!=null:
			field.run(world,s,0.0)
		return
	spawn_naval_group(world,"04c24a8c")

static func tick_scorpion_patrols(world) -> void:
	for ship in world.units:
		if not world.actor_alive(ship) or ship.side!="enemy" or not ship.special.has("allied_first_patrol_step"): continue
		var route: Array = ship.special.get("allied_first_patrol_route",[63,64,65,66,67,68,69,513])
		if ship.has_move_order or (world.actor_alive(ship.attack_target) and ship.position.distance_to(ship.attack_target.position)<=ship.attack_range): continue
		var index := int(ship.special.allied_first_patrol_step)%route.size()
		if ship.position.distance_to(wp(route[index]))<Places.CELL:
			index = (index+1)%route.size()
			ship.special.allied_first_patrol_step = index
		ship.order_move(wp(route[index]),true)

# 0693BF3C includes RestoreStartingBuildings for BridgeHouse (16).
# Preserve the source's 0-HP break rather than unconditionally repairing every piece.
static func restore_bridge_house(world,s: Dictionary) -> void:
	if s.get("bridge_house_restored",false): return
	s.bridge_house_restored = true
	for row in Field.data.structures:
		if row[1]!="BridgeHouse" or not row[8] or int(row[3])<=0: continue
		var id: String = row[2]
		var b = site(world,id)
		if b == null:
			var dims := str(GameData.get_building(id).get("foundation","1x1")).split("x")
			var at := (Vector2(row[4],row[5])+Vector2(1-int(dims[1]),int(dims[0])-1)*0.5)*Places.CELL
			b = world._place_building(id,"neutral",at,true)
		if b != null:
			b.special.allied_first_room = "BridgeHouse"
			b.special.allied_first_index = row[0]
			b.special.allied_first_tag = str(row[7]).to_lower()
			b.refresh_house_color()
			b.hp = b.max_hp*float(row[3])/256.0
			b.queue_redraw()

static func restore_past_defenses(world,s: Dictionary) -> void:
	if s.get("past_defenses_restored",false): return
	s.past_defenses_restored = true
	spawn_naval_group(world,"085159ec")

static func present_controller(world):
	for b in world.buildings:
		if world.actor_alive(b) and b.building_id=="YAPPET" and b.special.get("allied_first_index","")=="1028463": return b
	return null

static func enter_past(world,s: Dictionary) -> void:
	s.crossing_swapped = true
	s.dominator_established = false
	# The protected machine represents the present; remove it without a combat death in the past.
	var machine = site(world,"CATIME01")
	if machine != null:
		world.buildings.erase(machine)
		machine.queue_free()
		world.invalidate_building_membership()
		world._refresh_pathing()
	# Replace the present-time controller with the past-time objective using separate identity.
	var old = present_controller(world)
	var at: Vector2 = old.position if old != null else Vector2(87.5,29.5)*Places.CELL
	# Build_Dom enables Confederation production. The only retail base-plan
	# node is YAPPPT at 46,69; its construction yard is outside the playable map.
	s.confederation_production = false
	# Off-map retail structure 1028503 / tag 045CE63C. Keep its script ownership
	# without creating an unreachable factory, vision source or combat target.
	s.offmap_yard_room = "Confederation"
	s.past_controller_site = [at.x,at.y]
	if not s.get("map_closing_rows",false):
		restore_past_defenses(world,s)
		s.followup_fleet_left = 1.0
	s.awaiting_tanya = true
	s.apocs_sent = false
	# Legacy saves in the middle of the vortex may already contain the old charge-time raid.
	s.armor_sent = world.units.any(func(u):return world.actor_alive(u) and u.side=="enemy" and u.special.get("allied_first_team") in ["0925E45C","0925FDEC"])
	s.armor_left = armor_delay(int(BattleRequest.skirmish_config.get("difficulty",1)))
	s.tanya_left = TANYA_DELAY
	world.invalidate_building_membership()
	world._refresh_pathing()
	world._update_power()
	world.hud.minimap.clear_radar_events()
	if world.fog != null: world.fog.reset_exploration("ally")

static func start_controller_production(world,s: Dictionary,cmd: Dictionary,driver) -> bool:
	if cmd.trigger!="0b8a090c" or cmd.opcode!=3 or driver.definition.houses.get(cmd.fields[2])!="Confederation": return false
	if not s.has("past_controller_site"): return s.get("dominator_established",false)
	var xy: Array = s.past_controller_site
	var at := Vector2(xy[0],xy[1])
	var target = world._place_building("YAPPPT","enemy",at,true)
	if target == null:
		return false
	target.special.allied_first_room = "Confederation"
	target.refresh_house_color()
	target.special.allied_first_dominator = true
	s.dominator_established = true
	s.dominator_check_left = 50.0 # Legacy recovery seed; the exported row owns the new timer.
	# Use the ordinary construction update without charging the shared enemy wallet.
	target.under_construction = true
	target.build_total = 1.0
	target.build_elapsed = 0.0
	target.build_cost = 0.0
	target.hp = target.max_hp*0.15
	s.confederation_production = true
	s.erase("past_controller_site")
	return true

static func tanya_brief(world) -> void:
	speech(world,"谭雅","游到恶魔岛，把那台心灵控制器炸掉！","xa1ta01")

static func release_tanya(world,s: Dictionary,target) -> void:
	s.awaiting_tanya = false
	var city = city_driver(world,s)
	if city!=null: city.enable(city.TANYA_REMINDER)
	var tanya = world.spawn_unit("TANY","ally",wp(420))
	if tanya != null:
		tanya.special.allied_first_tanya = true
		tanya._grant_veteran(2,false)
		world.center_on(tanya.position)
		world.select_unit(tanya,false)
		world._emit_selection()
	if world.fog != null: world.fog.rebuild()
	if target != null: Events.emit_radar_ping(target.position,"campaign_site")
	tanya_brief(world)

static func send_carriers(world, s: Dictionary) -> void:
	s.carriers = true
	s.carrier_waves = int(s.get("carrier_waves",0))+1
	for i in range(3):
		var ship = world.spawn_unit("CARRIER","ally",wp(68)+Vector2(i*34,0))
		if ship != null:
			ship.special.allied_first_carrier = true
			ship.order_move(wp(417)+Vector2(i*34,0))
	if s.carrier_waves==1:
		world.center_on(wp(68))
		speech(world,"伊娃","谭雅已阵亡。航母正赶往恶魔岛附近，派舰载机摧毁心灵控制器。")

static func tick_carriers(world,s: Dictionary,delta: float) -> void:
	# 0BA104BC -> 089B1CCC -> 0898812C -> 0792B79C.
	if not s.get("carriers",false):
		send_carriers(world,s)
		s.carrier_follow_left = 1.0
		return
	if s.has("carrier_follow_left"):
		s.carrier_follow_left = float(s.carrier_follow_left)-delta
		if s.carrier_follow_left<=0.0:
			s.erase("carrier_follow_left")
			send_carriers(world,s)
			s.carrier_ping_left = 20.0
		return
	if s.has("carrier_ping_left"):
		s.carrier_ping_left = float(s.carrier_ping_left)-delta
		if s.carrier_ping_left>0.0: return
		s.erase("carrier_ping_left")
		Ra2Sfx.play_player_eva(world,"EVA_ReinforcementsHaveArrived",0)
		Events.emit_radar_ping(wp(417),"campaign_site")
	if world.units.any(func(u):return world.actor_alive(u) and u.side=="ally" and u.unit_id=="CARRIER"): return
	s.carrier_follow_left = 1.0

static func tick_engineer_rescue(world,s: Dictionary,delta: float) -> void:
	# Barracks_Gone -> Engineer_Check -> Engineers_Arrived. Do not reissue while a plane carries engineers.
	if world.buildings.any(func(b):return world.actor_alive(b) and b.building_id=="GAPILE" and b.side=="ally") or world.units.any(func(u):return world.actor_alive(u) and u.side=="ally" and (u.unit_id=="ENGINEER" or (u.special.get("para_infantry")=="ENGINEER" and int(u.special.get("para_left",0))>0))):
		s.erase("engineer_rescue_left")
		return
	s.engineer_rescue_left = float(s.get("engineer_rescue_left",30.0))-delta
	if s.engineer_rescue_left>0.0: return
	if preload("res://scripts/world/american_paradrop.gd").launch_story(world,wp(142),"ENGINEER",4):
		s.erase("engineer_rescue_left")
		s.engineer_drop_pending = true

static func announce_engineer_rescue(world,s: Dictionary) -> void:
	if not s.get("engineer_drop_pending",false): return
	if not world.units.any(func(u):return world.actor_alive(u) and u.side=="ally" and u.unit_id=="ENGINEER" and not u.special.has("para_height")): return
	s.erase("engineer_drop_pending")
	Ra2Sfx.play_player_eva(world,"EVA_ReinforcementsHaveArrived",0)
	Events.emit_radar_ping(wp(142),"campaign_site")

# Find_Hospital 0462B74C / CellTag 0462CD1C. The tagged cells form the perimeter.
static func check_hospital_discovery(world,s: Dictionary) -> void:
	if int(s.get("phase",0))!=1 or s.has("charge") or s.get("hospital_found",false): return
	var hospital = site(world,"CATHOSP")
	if hospital == null: return
	for u in world.units:
		if not world.actor_alive(u) or u.side!="ally" or u.is_air or u.is_naval or u.embarked_in!=null or u.special.has("para_height"): continue
		var cell := Vector2i(u.position/Places.CELL)
		if not Rect2i(74,84,6,10).has_point(cell): continue
		if cell.x not in [74,79] and cell.y not in [84,93]: continue
		s.hospital_found = true
		world.hud.show_field_transmission("伊娃","发现科技医院。派工程师占领，可让己方步兵缓慢恢复生命。","")
		Ra2Sfx.play_hollywood_line("cevau92")
		Events.emit_radar_ping(wp(56),"campaign_site")
		if world.fog != null:
			world.fog._reveal("ally",hospital.position,Places.CELL*3.0,world.fog.FIRE_REVEAL_SECONDS)
			world.fog.rebuild()
		return

# Latch actual destruction separately from temporarily losing ownership.
static func update_plant_losses(world,s: Dictionary) -> void:
	var gone: Dictionary = s.get("destroyed_plants",{})
	for i in range(1,9):
		var id := "CAPOWR%02d" % i
		if site(world,id)==null: gone[id] = true
	s.destroyed_plants = gone

static func sync_offmap_yard(s: Dictionary,target) -> void:
	# 045CEF3C is armed by New_Dom_Up and requires the controller to exist.
	if not s.get("new_dominator_check",false) or target==null: return
	if not target.special.get("allied_first_dominator",false): return
	if s.get("offmap_yard_room","Confederation")!="Confederation": return
	s.offmap_yard_room = "BridgeHouse"
	s.confederation_production = false

static func tick_dominator_driver(world,s: Dictionary,target,delta: float) -> bool:
	var driver := RetailDriver.new()
	if s.has("retail_dominator"):
		if not driver.restore(s.retail_dominator):
			push_error("ALL01UMD: invalid retail dominator state")
			return false
	else:
		if not driver.start(MAP,clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)): return false
		driver.state.enabled.clear()
		driver.enable("089ec19c")
		if s.has("past_controller_site"):
			driver.enable("0951879c")
		elif s.get("new_dominator_check",false):
			driver.enable("0bd6117c")
			driver.enable("045cef3c")
		else:
			driver.enable("0bd650ac")
			driver.state.time = clampf(50.0-float(s.get("dominator_check_left",50.0)),0.0,50.0)
	var predicate := func(row: Dictionary,_event: Array) -> bool:
		if row.id=="045cef3c":
			return target!=null and target.special.get("allied_first_dominator",false) and s.get("offmap_yard_room","Confederation")=="Confederation"
		if s.get("awaiting_tanya",false) or target!=null or not s.get("dominator_established",true): return false
		if row.id=="089ec19c": return not driver.state.fired.has("0bd650ac") and not s.get("new_dominator_check",false)
		return row.id=="0bd6117c"
	# Sell the tagged present-time structure before starting the one-second production clock.
	if driver.state.enabled.has("0951879c"):
		var sale := driver.advance(0.0,predicate)
		if sale.get("trigger")!="0951879c" or sale.get("opcode")!=60: return false
		var old = present_controller(world)
		if old!=null:
			var refund: float = GameData.ra2_refund(int(old.data.get("cost",0)))+old.total_production_paid()
			var owner: String = old.side
			old.retire_sold()
			world.buildings.erase(old)
			world.rally_points.erase(old.get_instance_id())
			world.invalidate_building_membership()
			world._refresh_pathing()
			world._update_power()
			world.credit_side(owner,refund)
		driver.acknowledge(sale.token)
		driver.advance(0.0,predicate)
	# During the vortex this adapter owns only Build_Dom. The stage-4 clock resumes its downstream timer.
	if s.has("past_controller_site") and driver.state.enabled.has("0b8a090c"):
		var due := float(driver.state.enabled["0b8a090c"])+float(driver.rows["0b8a090c"].events[0][2])
		delta=minf(delta,maxf(0.0,due-float(driver.state.time)))
	var command := driver.advance(delta,predicate)
	while not command.is_empty():
		if command.trigger=="0b8a090c":
			if not start_controller_production(world,s,command,driver):
				push_error("ALL01UMD: controller production action failed")
				break
			driver.acknowledge(command.token)
			command = driver.advance(0.0,predicate)
			continue
		if command.trigger!="045cef3c" or command.opcode!=14 or int(command.fields[2])!=16:
			push_error("ALL01UMD: unexpected controller action %s"%command)
			break
		s.new_dominator_check = true
		sync_offmap_yard(s,target)
		driver.acknowledge(command.token)
		command = driver.advance(0.0,predicate)
	s.new_dominator_check = s.get("new_dominator_check",false) or driver.state.fired.has("0bd650ac")
	s.retail_dominator = driver.snapshot()
	for id in ["089ec19c","0bd6117c"]:
		if driver.state.fired.has(id):
			s.victory_trigger = id.to_upper()
			return true
	return false

static func tick_past_auxiliary_power(world,s: Dictionary,delta: float) -> void:
	if int(BattleRequest.skirmish_config.get("difficulty",1))!=0: return
	s.auxiliary_poll = float(s.get("auxiliary_poll",0.0))-delta
	if s.auxiliary_poll>0: return
	s.auxiliary_poll = 0.5
	# Only reevaluate after a capture, recapture or destruction. The power objective
	# and its loss announcements have already finished by this time.
	var signature := ""
	var gone: Dictionary = s.get_or_add("destroyed_plants",{})
	for i in range(1,9):
		var id := "CAPOWR%02d"%i
		var b = site(world,id)
		if b==null: gone[id]=true
		signature += "x" if b==null else ("a" if b.side=="ally" else "-")
	if s.get("auxiliary_late_signature","")==signature: return
	tick_plant_driver(world,s,0.0,signature)
	s.auxiliary_late_signature=signature

static func tick_plant_driver(world,s: Dictionary,delta: float,late_plants := "") -> void:
	var driver := RetailDriver.new()
	if s.has("retail_power_loss"):
		if not driver.restore(s.retail_power_loss):
			push_error("ALL01UMD: invalid plant trigger state")
			return
	else:
		if not driver.start(MAP,clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)): return
		driver.state.enabled.clear()
		for row in driver.definition.triggers:
			if row.name.begins_with("Start_PP") or row.name.begins_with("Change_House_PP"): driver.enable(row.id)
		s.plant_pair_driver_initialized = true
		driver.enable("04ec206c")
	if not s.get("plant_pair_driver_initialized",false):
		for row in driver.definition.triggers:
			if row.name.begins_with("PP") and row.name.ends_with("_Entered"):
				var plant_id := "CAPOWR%02d" % int(row.name.get_slice("_",0).trim_prefix("PP"))
				if not s.destroyed_plants.has(plant_id): driver.enable(row.id)
		var deferred: Dictionary = s.get("plant_external_links",{})
		for id in deferred.keys():
			if not driver.rows.has(id): continue
			if deferred[id]: driver.enable(id)
			else: driver.state.enabled.erase(id)
			deferred.erase(id)
		s.plant_external_links = deferred
		s.plant_pair_driver_initialized = true
	if not s.get("plant_attack_rows_ready",false):
		for row in driver.definition.triggers:
			if row.name.ends_with("_PlayerAttack"): driver.enable(row.id)
		s.plant_attack_rows_ready = true
	if not s.get("auxiliary_rows_ready",false):
		for row in driver.definition.triggers:
			if row.name.begins_with("GivePower"): driver.enable(row.id)
		s.auxiliary_rows_ready = true
	for i in late_plants.length():
		if late_plants[i] in ["a","x"]: driver.set_local(6+i,true)
		if late_plants[i]=="x": driver.set_local(18+i,true)
	driver.set_local(47,int(s.get("phase",0))>=2)
	for id in s.get("assault_plant_links",{}): driver.enable(id)
	s.erase("assault_plant_links")
	var gone: Dictionary = s.destroyed_plants
	var predicate := func(row: Dictionary,event: Array) -> bool:
		if event[0]=="57" and row.name=="TakePower8":
			var eighth = site(world,"CAPOWR08")
			return eighth==null or eighth.side!="ally"
		if event[0]=="44":
			return s.get("player_hit_plants",{}).has("CAPOWR%02d" % int(row.name.get_slice("_",0).trim_prefix("PP")))
		if event.size()==4 and event[0]=="61": return gone.has(event[3])
		if event[0]=="1" and row.name.ends_with("_Entered"):
			var b = site(world,"CAPOWR%02d" % int(row.name.get_slice("_",0).trim_prefix("PP")))
			return b!=null and b.side=="ally"
		return false
	var gate := func(row: Dictionary) -> bool:
		var name: String = row.name
		if not late_plants.is_empty(): return name.begins_with("GivePower") or name.begins_with("TakePower")
		if not name.begins_with("Losing"): return true
		var step := int(name.trim_prefix("LosingPP").trim_suffix("_Easy")) if name.ends_with("_Easy") else int(name.get_slice("_",2))
		return gone.size() >= step
	var command := driver.advance(delta,predicate,gate)
	while true:
		if command.is_empty():
			# The paired Lost watcher was disabled by Losing before the local edge.
			# Re-arm only the watcher for a local that actually latched in this slice.
			if not late_plants.is_empty(): break
			var rearmed := false
			for row in driver.definition.triggers:
				if not (row.name.begins_with("Lost_Power_") or row.name.begins_with("LostPP")): continue
				if driver.state.enabled.has(row.id) or driver.state.fired.has(row.id): continue
				if driver.state.locals.get(row.events[0][2],false) and driver.enable(row.id): rearmed = true
			if not rearmed: break
			command = driver.advance(0.0,predicate,gate)
			continue
		match int(command.opcode):
			2:
				if command.trigger!="06178d0c":
					push_error("ALL01UMD: unexpected plant defeat")
					break
				if not late_plants.is_empty() or grid_ready(world):
					driver.acknowledge(command.token)
					command = driver.advance(0.0,predicate,gate)
					continue
				driver.acknowledge(command.token)
				s.retail_power_loss = driver.snapshot()
				s.failure_trigger = "06178D0C"
				speech(world,"伊娃","可用的任务发电厂已不足，时光机无法充能。")
				world.end_battle(false)
				return
			11:
				if command.fields[2]!="MISSION:Attack3": return
				world.hud.show_field_transmission("伊娃","警告：不要攻击发电厂！","")
			14:
				var row: Dictionary = driver.rows[command.trigger]
				if row.name.begins_with("GivePower") or row.name.begins_with("TakePower"):
					var number: String = row.name.right(1)
					var record: Dictionary = driver.definition.auxiliary_plants[number]
					var owners: Dictionary = s.get_or_add("auxiliary_plant_owners",{})
					owners[record.index] = driver.definition.houses[command.fields[2]]
					s.auxiliary_power = owners.values().count("Americans")*int(GameData.get_building(record.kind).power)
					world._update_power()
					driver.acknowledge(command.token)
					command = driver.advance(0.0,predicate,gate)
					continue
				var plant = site(world,"CAPOWR%02d" % int(row.name.trim_prefix("Change_House_PP")))
				if plant!=null:
					var room: String = driver.definition.houses[command.fields[2]]
					Orders.change_side(plant,side(room))
					plant.special.allied_first_room = room
					plant.refresh_house_color()
			17:
				var point := wp(int(command.fields[2]))
				var reveals: Dictionary = s.get("plant_reveals",{})
				reveals[str(command.fields[2])] = true
				s.plant_reveals = reveals
				if world.fog != null:
					world.fog._reveal("ally",point,Places.CELL*4.0,world.fog.FIRE_REVEAL_SECONDS)
					world.fog.rebuild()
			19:
				Ra2Sfx.play(str(command.fields[2]))
			21:
				if command.trigger=="0617d71c": Ra2Sfx.play_hollywood_line("xa1ev05")
				elif command.trigger=="0c9733cc":
					if not s.get("more_power_reported",false) and not grid_ready(world):
						s.more_power_reported = true
						speech(world,"伊娃","还需要更多电力。继续占领任务发电厂。","xa1ev04")
				else: Ra2Sfx.play_player_eva(world,str(command.fields[2]),0)
			55:
				var code: String = command.fields[7]
				var waypoint := 0
				for i in code.length(): waypoint = 26*waypoint+code.unicode_at(i)-64
				Events.emit_radar_ping(wp(waypoint-1),"campaign_site")
				s.plant_last_ping = code
			53,54:
				# The remaining plant pair, capture and briefing branches are outside this slice.
				var deferred: Dictionary = s.get("plant_external_links",{})
				deferred[str(command.fields[2]).to_lower()] = command.opcode==53
				s.plant_external_links = deferred
			_:
				push_error("ALL01UMD: unknown plant command %s"%command)
				break
		driver.acknowledge(command.token)
		command = driver.advance(0.0,predicate,gate)
	s.retail_power_loss = driver.snapshot()

static func city_driver(world,s: Dictionary):
	if world.has_meta("all01_city_driver"): return world.get_meta("all01_city_driver")
	var driver = preload("res://scripts/world/allied_first_city.gd").new()
	if not driver.initialize(s):
		push_error("ALL01UMD invalid city driver state")
		return null
	world.set_meta("all01_city_driver",driver)
	return driver

static func sync_smudges(world,s: Dictionary) -> void:
	var layer=world.get_node_or_null("AlliedFirstSmudges")
	if not s.get("map_closing_rows",false) or s.get("closing_smudges_cleared",false):
		if layer!=null: layer.hide()
		return
	if layer!=null: return
	layer=Sprite2D.new()
	layer.name="AlliedFirstSmudges"
	layer.centered=false
	layer.texture=preload("res://assets/maps/yr/yr_all01umd_smudges.png")
	layer.scale=Vector2.ONE*world.map_size/layer.texture.get_width()
	layer.z_index=DepthLayers.DECAL
	world.add_child(layer)

static func closing_driver(world,s: Dictionary):
	if world.has_meta("all01_closing_driver"): return world.get_meta("all01_closing_driver")
	var d=preload("res://scripts/world/allied_first_closing.gd").new()
	if not d.initialize(s,clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)):
		push_error("Invalid ALL01 closing state")
		return null
	world.set_meta("all01_closing_driver",d)
	return d

static func assault_driver(world,s: Dictionary):
	if world.has_meta("all01_assault_driver"): return world.get_meta("all01_assault_driver")
	var d=Assault.new()
	if not d.initialize(s,clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)): return null
	world.set_meta("all01_assault_driver",d)
	return d

static func field_driver(world,s: Dictionary):
	if world.has_meta("all01_field_driver"): return world.get_meta("all01_field_driver")
	var driver=preload("res://scripts/world/allied_first_field_driver.gd").new()
	if not driver.initialize(s,clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)):
		push_error("Invalid ALL01 field state")
		return null
	world.set_meta("all01_field_driver",driver)
	return driver

static func tick(world, delta: float) -> void:
	var s: Dictionary = world.allied_state.get("allied_first",{})
	if world.paused or world.ended or s.is_empty(): return
	if int(s.get("phase",0)) in [1,2,3,4]:
		if s.get("map_closing_rows",false) and int(s.phase)!=3:
			var closing=closing_driver(world,s)
			if closing!=null: closing.run(world,s,delta)
		var city = city_driver(world,s)
		if city!=null: city.run(world,s,delta)
		if s.get("map_field_rows",false):
			var field=field_driver(world,s)
			if field!=null: field.run(world,s,delta)
	if int(s.get("phase",0)) in [3,4]:
		tick_past_auxiliary_power(world,s,delta)
		if s.get("map_assault_rows",false):
			var d=assault_driver(world,s)
			if d!=null: d.run(world,s,delta,null)
	match int(s.get("phase",0)):
		1,2:
			tick_opening_ggi(world,s,delta)
			if not world.has_surviving_assets("ally"):
				world.end_battle(false)
				return
			update_plant_losses(world,s)
			tick_plant_driver(world,s,delta)
			if world.ended: return
			var machine = site(world,"CATIME01")
			tick_power_sequence(world,s,delta)
			if world.ended or s.phase==3: return
			if machine == null or machine.side != "ally":
				# Separate the loss report from settlement. The retail post-warp
				# predicate is not reachable with this pre-warp machine loss.
				if not s.has("machine_failure_left"):
					s.machine_failure_left = 3.0
					if machine != null: speech(world,"伊娃","我们失去了时光机的控制权。")
				else:
					s.machine_failure_left = maxf(0.0,float(s.machine_failure_left)-delta)
					if s.machine_failure_left<=0.0: world.end_battle(false)
				return
			s.erase("machine_failure_left")
			if not s.get("map_field_rows",false):
				tick_engineer_rescue(world,s,delta)
				announce_engineer_rescue(world,s)
			contest_plants(world,s,delta)
			if not s.has("charge"):
				if not s.get("map_field_rows",false): check_hospital_discovery(world,s)
				return
			if not s.get("map_field_rows",false) and machine.hp < float(s.get("machine_hp",machine.hp)) and not s.get("warned",false):
				s.warned = true
				speech(world,"伊娃","时光机正遭到攻击，保护它！","xa1ev06")
			s.machine_hp = machine.hp
		3:
			tick_power_sequence(world,s,delta)
			if world.ended: return
			var half: float = world.TimeShift.CROSSING_DURATION*0.5
			if s.get("crossing_swapped",false):
				var since_swap := float(s.retail_power_sequence.time)-float(s.transition_swap_clock)
				if s.has("past_controller_site"):
					tick_dominator_driver(world,s,null,maxf(0.0,since_swap-float(s.get("controller_warmup",0.0))))
					if s.has("past_controller_site"): s.controller_warmup = since_swap
					else: s.erase("controller_warmup")
				s.crossing_time = half+since_swap
			else:
				s.crossing_time = minf(half,float(s.crossing_time)+delta)
			world.TimeShift.sync_crossing_visual(world,s)
			if s.crossing_time>=world.TimeShift.CROSSING_DURATION:
				s.phase = 4
				s.erase("crossing_era")
				s.erase("crossing_time")
				world.TimeShift.sync_crossing_visual(world,s)
				world.hud._refresh_timer()
				if s.get("past_report",false): resume_media.call_deferred(world)
		4:
			var transition: Dictionary = s.get("retail_power_sequence",{})
			if not s.get("retail_bridge_rows",false) or transition.get("enabled",{}).has(PowerSequence.CONNECTOR) or transition.get("enabled",{}).has(PowerSequence.CENTER) or transition.get("enabled",{}).has("0993f7bc") or s.get("machine_death_era",-1)==1 or transition.get("enabled",{}).has(PowerSequence.ARRIVAL) or transition.get("enabled",{}).has(PowerSequence.KIROV) or s.get("power_external_links",{}).get(PowerSequence.KIROV,false):
				tick_power_sequence(world,s,delta)
				if world.ended: return
			if s.get("past_report",false) or transition.get("enabled",{}).has(PowerSequence.ARRIVAL): return
			GlobalAI.tick(world,s,delta)
			if s.has("followup_fleet_left"):
				s.followup_fleet_left = float(s.followup_fleet_left)-delta
				if s.followup_fleet_left<=0.0:
					s.erase("followup_fleet_left")
					deploy_followup_fleet(world,s)
					deploy_past_harbor(world,s)
			if float(s.get("dread_order_left",0.0))<=delta: tick_scorpion_patrols(world)
			tick_dread_orders(world,s,delta)
			var target = site(world,"YAPPPT")
			var victory_ready := tick_dominator_driver(world,s,target,delta)
			if s.get("awaiting_tanya",false):
				s.orders_left = float(s.get("orders_left",0.0))-delta
				if s.orders_left <= 0.0:
					s.orders_left = 0.5
					direct_armor(world)
				if not world.has_surviving_assets("ally"):
					world.end_battle(false)
					return
				if not s.get("armor_sent",false):
					if s.get("map_field_rows",false) and not s.get("field_past_links",{}).get(Armor.SEND[clampi(int(BattleRequest.skirmish_config.get("difficulty",1)),0,2)],false): return
					Armor.tick_column(world,s,delta)
					return
				if s.get("map_field_rows",false) or armor_remaining(world) > 0: return
				s.tanya_left = maxf(0.0,float(s.tanya_left)-delta)
				if s.tanya_left <= 0.0: release_tanya(world,s,target)
				return
			# A missing definition or failed placement must not count as destroying the objective.
			# Old stage-4 saves predate the explicit latch; their existing target establishes it.
			if target != null and target.special.get("allied_first_dominator",false): s.dominator_established = true
			if victory_ready:
				s.phase = 5
				s.finish_left = 10.0 # Fallback for older snapshots; new victories use the retail driver.
				s.retail_victory = s.retail_dominator
				s.erase("retail_dominator")
				speech(world,"伊娃","心灵控制器已经摧毁。")
				return
			if not world.units.any(func(u):return world.actor_alive(u) and u.side=="ally" and u.special.get("allied_first_tanya",false)):
				if not s.get("map_field_rows",false): tick_carriers(world,s,delta)
		5:
			if s.has("retail_victory"):
				tick_victory_driver(world,s,delta)
				return
			s.finish_left = maxf(0.0,float(s.finish_left)-delta)
			if s.finish_left <= 7.0 and not s.get("victory_cheer",false):
				s.victory_cheer = true
				for u in world.units:
					if world.actor_alive(u) and u.side=="ally" and u._seq.has("Cheer"): u.special.cheer_elapsed = 0.0
			if s.finish_left <= 0.0: world.end_battle(true)
