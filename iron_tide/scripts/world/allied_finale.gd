extends RefCounted
## Playable preview of Brain Dead. Retail scripted milestones; combat roster/AI still incomplete.
const ID := "yr_allied_finale"
const MAP := "yr_all07smd"
const Field = preload("res://data/ra2/allied_finale_field.json")
const Scenery = preload("res://data/ra2/allied_finale_scenery.json")
const Driver = preload("res://scripts/world/allied_retail_script.gd")
const Places = preload("res://scripts/world/native_maps.gd")
const Orders = preload("res://scripts/units/allied_abilities.gd")
const Film = preload("res://scripts/ui/hollywood_film.gd")
const AI = preload("res://scripts/world/allied_finale_ai.gd")
const Branches = preload("res://scripts/world/allied_finale_branches.gd")
const OpeningDrop = preload("res://scripts/world/american_paradrop.gd")
const CASH_CRATE = preload("res://assets/maps/yr/field_crate.png")
const SOLO_CRATE_MONEY := 5000 # Retail rulesmd.ini General.SoloCrateMoney.
const WarpRing = preload("res://scripts/world/chrono_miner_fx.gd")
const ENEMIES := ["YuriCountry", "Yuri2", "Yuri3"]
const RETAIL_MUTATOR_RECHARGE := 600.0 # ALL07SMD [GeneticConverterSpecial] RechargeTime=10.

static func position(u: float, v: float) -> Vector2:
	return Vector2(u, v) * Places.CELL

static func note(world, text: String) -> void:
	world.hud.show_field_transmission("战场指挥系统", text, "")

static func setup(world) -> void:
	var scenery := Node2D.new()
	scenery.name = "AlliedFinaleScenery"
	world.add_child(scenery)
	var textures := {}
	for row in Scenery.data.props:
		var id: String = row[0]
		# Ore-producing trees are represented by the native ore drill system.
		if id.begins_with("TIBTRE"): continue
		if not textures.has(id): textures[id] = load("res://assets/maps/yr/allied_finale/%s.png" % id)
		var sprite := Sprite2D.new()
		sprite.texture = textures[id]
		sprite.position = position(row[1],row[2])
		sprite.offset.y = -sprite.texture.get_height()*0.5
		sprite.transform = Transform2D(Iso.eff_angle(),Iso.up()*1.30,0,sprite.position)
		sprite.z_index = DepthLayers.entity_z(sprite.position,world.map_size)
		scenery.add_child(sprite)
	if not BattleSaves.pending.is_empty(): return
	var d := Driver.new()
	d.start(MAP, int(BattleRequest.skirmish_config.get("difficulty", 1)))
	d.enable("0a57f46c")
	world.allied_state.allied_finale = {"script": d.snapshot(), "phase": 0, "missing": [], "unsupported": {}, "elapsed": 0.0, "base_defense_driver": true}
	for row in Field.data.structures:
		if not row[8]: continue
		var house: String = row[1]
		var id: String = row[2]
		if house not in ENEMIES and house != "Special": continue
		var def := GameData.get_building(id)
		if def.is_empty():
			record_missing(world, id)
			continue
		var at := position(row[4], row[5])
		var dims := str(def.get("foundation", "1x1")).split("x")
		if dims.size() == 2: at += Vector2(1-int(dims[1]), int(dims[0])-1)*Places.CELL*0.5
		var b = world._place_building(id, "neutral" if house == "Special" else "enemy", at, true)
		if b == null: continue
		b.hp = b.max_hp * float(row[3])/256.0
		b._buildup_play = -1.0 # Retail preplaced facilities open already built.
		b.special.allied_finale_room = house
		if house==Branches.THIRD and str(row[7]).to_upper()=="08CBA4FC": b.special.finale_yuri3_yard_tag=true
		if house=="Special": b.special.finale_opening_tag = str(row[7]).to_upper()
		b.refresh_house_color()
	# NativeMaps creates scenery before mission setup, without the Structures health field.
	for row in Field.data.structures:
		if not row[8] or row[1]!="Neutral": continue
		var origin := position(row[4],row[5])
		var def: Dictionary = Places.data(MAP).site_types.get(row[2],{})
		var dims := str(def.get("foundation","1x1")).split("x")
		if dims.size()==2: origin += Vector2(1-int(dims[1]),int(dims[0])-1)*Places.CELL*0.5
		for site in world.buildings:
			if site.side=="neutral" and site.building_id==row[2] and site.position.is_equal_approx(origin):
				site.hp=site.max_hp*float(row[3])/256.0
				break
	for list in [Field.data.units, Field.data.infantry]:
		for row in list:
			if not row[8] or row[1] not in ENEMIES: continue
			var id: String = row[2]
			if GameData.get_unit(id).is_empty():
				record_missing(world, id)
				continue
			var u = world.spawn_unit(id, "enemy", position(row[4], row[5]))
			if u == null: continue
			u.special.allied_finale_room = row[1]
			u.refresh_house_color()
			u.hp = u.max_hp * float(row[3])/256.0
			if not u.is_harvester:
				u.order_stop()
				u.hold_position = row[7] != "Area Guard"
				if not u.hold_position: u.special.campaign_area_guard = u.global_position
	world.center_on(AI.waypoint(world,79))
	if world.fog!=null: world.fog.rebuild()
	world.allied_state.allied_finale.raid_driver = true
	world.allied_state.allied_finale.opening_driver = true
	world.allied_state.allied_finale.opening_drop_pending = true
	world.allied_state.allied_finale.media_stage = 1
	resume_media(world)

static func resume_media(world) -> void:
	var s: Dictionary = world.allied_state.get("allied_finale", {})
	if s.is_empty() or world.get_node_or_null("HollywoodFilm") != null: return
	if s.get("opening_driver",false) and int(s.get("media_stage",0))!=1: return
	match int(s.get("media_stage",0)):
		1:
			Film.show_clip(world, "A07_F00E", func():
				s.media_stage = 2)
		2:
			if s.get("opening_drop_pending",false):
				var zone := OpeningDrop.open_ground(world,AI.waypoint(world,107))
				if not zone.is_finite() or not OpeningDrop.launch_story(world,zone,"ENGINEER",5,AI.waypoint(world,104),{"finale_opening_engineer":true}):
					return
				s.opening_drop_pending=false
				world.center_on(AI.waypoint(world,78))
			Film.show_clip(world, "A07_P01E", func():
				s.media_stage = 3 if s.has("opening_drop_pending") else 0)
		3:
			var flight_active: bool = world.units.any(func(u):return world.actor_alive(u) and (int(u.special.get("para_left",0))>0 or (u.special.get("finale_opening_engineer",false) and u.special.has("para_height"))))
			if flight_active: return
			s.media_stage = 0
			world.center_on(AI.waypoint(world,107))
			speech(world,"ceva120","战场控制已上线。分别占领苏军建造场和磁能反应炉。")

static func speech(world, sample: String, text: String, speaker := "伊娃") -> void:
	world.hud.show_field_transmission(speaker, text, "")
	var file := "res://assets/ra2/sfx/allied_finale/%s.wav" % sample
	var voice := AudioStreamPlayer.new()
	voice.stream = load(file) as AudioStream
	if voice.stream == null:
		voice.free()
		return
	voice.set_meta("allied_finale_voice",sample)
	world.add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

static func marks(world, radar: bool) -> Array:
	var s: Dictionary = world.allied_state.get("allied_finale", {})
	if s.is_empty() or int(s.get("media_stage",0)) != 0: return []
	var phase := int(s.phase)
	if phase >= 3 and dominator_gone(world, s): return cleanup_marks(world)
	var marks: Array = []
	for b in world.buildings:
		if not world.actor_alive(b): continue
		var title := ""
		if phase <= 1 and b.building_id == "NACNST" and b.special.get("allied_finale_room") == "Special":
			title = "接管苏军建造场" if phase == 0 else objective(world).title
		elif phase == 2 and b.building_id == "NARADR" and b.side == "ally": title = "雷达已上线，等待超时空增援"
		elif phase >= 3 and b.building_id == "YAPPET" and b.side == "enemy": title = "摧毁心灵控制器"
		elif phase >= 3 and b.building_id == "YACNST" and b.side == "enemy" and world.actor_visible_to("ally", b): title = "摧毁尤里建造场"
		if not title.is_empty():
			var mark := {"position": b.position, "title": title, "actor": b, "color": Color("ffda59"), "status": "active"}
			if phase <= 2: mark.keep_over_building = true
			marks.append(mark)
	if phase >= 3 and not radar:
		for u in world.units:
			if world.actor_alive(u) and u.side=="ally" and u.unit_id=="AMCV":
				marks.append({"position":u.position,"title":"展开盟军基地车","actor":u,"color":Color("ffda59"),"status":"active"})
	for p in s.get("cash_crates",{}).values():
		if not world.position_visible_to("ally",p): continue
		var mark: Dictionary = world.CampaignMarks.entry(p,"资金箱",null,Color.LIME_GREEN)
		mark.optional=true
		marks.append(mark)
	return marks

static func record_missing(world, id: String) -> void:
	var missing: Array = world.allied_state.allied_finale.missing
	if id not in missing: missing.append(id)

static func objective(world) -> Dictionary:
	var s: Dictionary = world.allied_state.get("allied_finale", {})
	var phase := int(s.get("phase",0))
	var title := "接管火地岛苏军基地"
	var progress := ""
	if int(s.get("media_stage",0)) != 0:
		if int(s.media_stage) != 3 or world.has_node("HollywoodFilm"):
			title = "战前简报 · 火地岛"
			progress = "可按右下角的「跳过简报」"
		elif s.get("opening_drop_pending",false) or opening_flight_active(world):
			title = "工程师正在空降"
			progress = "落地后可指挥工程师接管基地"
		else:
			title = "正在交还战场控制"
	elif phase == 1:
		title = "建造苏军雷达站" if "NAREFN" in world.owned_building_ids() else "先建造苏军矿石精炼场"
	elif phase == 2:
		title = "守住基地，等待超时空增援"
		var script: Dictionary = s.get("script",{})
		var enabled: Dictionary = script.get("enabled",{})
		var now := float(script.get("time",0.0))
		# Show the running trigger's timer, not a sum of independent script delays.
		if enabled.has("0964b13c"): progress = "增援抵达倒计时 %d 秒" % ceili(maxf(0.0,15.0+float(enabled["0964b13c"])-now))
		elif enabled.has("0967d33c"): progress = "增援通报倒计时 %d 秒" % ceili(maxf(0.0,120.0+float(enabled["0967d33c"])-now))
	elif phase >= 3:
		if dominator_gone(world,s):
			title = "清剿尤里的剩余部队和建筑"
			var subs := remaining_boomers(world)
			if subs > 0 and not world.buildings.any(func(b): return cleanup_target(world,b,ENEMIES)) and not world.units.any(func(u): return cleanup_target(world,u,ENEMIES) and u.unit_id != "BSUB"):
				title = "搜歼剩余雷鸣潜艇（%d 艘）" % subs
				progress = "用声呐舰艇搜索海峡"
		elif world.units.any(func(u): return world.actor_alive(u) and u.side=="ally" and u.unit_id=="AMCV") and "GACNST" not in world.owned_building_ids():
			title = "展开盟军基地车"
		else: title = "摧毁南极的心灵控制器"
	return {"title":title,"progress":progress,"detail":"当前：%s%s\n01 接管火地岛苏军基地，建造雷达站。\n02 接收超时空增援，展开盟军基地车。\n03 摧毁心灵控制器，清剿尤里的剩余部队和建筑。" % [title," · "+progress if not progress.is_empty() else ""]}

static func cleanup_target(world, actor, rooms: Array) -> bool:
	if not world.actor_alive(actor) or actor.side != "enemy": return false
	return Branches.actor_room(actor) in rooms

static func remaining_boomers(world) -> int:
	var count := 0
	for u in world.units:
		if cleanup_target(world,u,ENEMIES) and u.unit_id == "BSUB": count += 1
	return count

static func cleanup_marks(world) -> Array:
	var result: Array = []
	# Like Hollywood, known buildings stay marked through fog. Mobile targets
	# only show while detected; this does not expose their movement or submarines.
	for b in world.buildings:
		if cleanup_target(world, b, ENEMIES) and (world.position_explored_by("ally", b.position) or world.actor_visible_to("ally", b)):
			result.append(world.CampaignMarks.entry(b.position, "摧毁" + b.display_name, b, Color.TOMATO))
	var hidden_boomers := 0
	for u in world.units:
		if not cleanup_target(world,u,ENEMIES): continue
		if u.embarked_in == null and world.actor_visible_to("ally",u):
			result.append(world.CampaignMarks.entry(u.position, "消灭" + u.display_name, u, Color.TOMATO))
		elif u.unit_id == "BSUB": hidden_boomers += 1
	if hidden_boomers > 0:
		# Fixed reconnaissance area in the retail starting submarine corridor,
		# independent of enemy positions; never grants vision or a unit target.
		result.append(world.CampaignMarks.entry(position(85.5,86.5),"搜索海峡：用声呐定位雷鸣潜艇"))
	return result

static func dominator_gone(world, s: Dictionary) -> bool:
	return bool(s.get("dominator_placed", false)) and not world.buildings.any(func(b):
		return world.actor_alive(b) and b.building_id == "YAPPET" and b.special.get("allied_finale_room") == "YuriCountry")

static func query(world, s: Dictionary, row: Dictionary, event: Array) -> bool:
	match int(event[0]):
		9:
			if int(s.phase) < 3: return false
			var room := Branches.room(event[2])
			if room.is_empty(): return false
			# 07CA72BC names only 9 and 14. Third-house survivors remain an explicit
			# local clearance safeguard until original House semantics are ported.
			var rooms := [room,Branches.THIRD] if room==Branches.SECOND else [room]
			for group in [world.units, world.buildings]:
				for actor in group:
					if cleanup_target(world, actor, rooms): return false
			return true
		11:
			if row.id=="079b37cc":
				return not (world.units+world.buildings).any(func(a): return Branches.belongs(world,a,"Confederation"))
			return not world.has_surviving_assets("ally")
		1:
			if row.id in ["0be87edc","0be87b9c"]:
				var id := "NACNST" if row.id=="0be87edc" else "NAPOWR"
				return world.buildings.any(func(b):return world.actor_alive(b) and b.side=="ally" and b.building_id==id and b.special.get("allied_finale_room")=="Special")
			if row.id in ["0930a91c","093138dc"]:
				var site = Branches.oil(world,43 if row.id=="0930a91c" else 44)
				return site!=null and Branches.belongs(world,site,Branches.THIRD)
		4:
			if row.id in ["078f6e5c","078f692c"]: return Branches.oil_found(world,43 if row.id=="078f6e5c" else 44)
		15:
			var original := 0
			for site in Field.data.structures:
				if site[8] and site[1] == row.house.replace("2Country","2"): original+=1
			var left: int = world.buildings.filter(func(b):return Branches.belongs(world,b,row.house.replace("2Country","2"))).size()
			return original-left >= int(event[2])
		19:
			var building: String = {"0462be5c":"GAYARD","0960df3c":"NAHAND","0c028afc":"GAWEAP"}.get(row.id,"")
			return not building.is_empty() and building in world.owned_building_ids("ally")
		32:
			var id: String = {"0988e66c":"GACNST","0f22154c":"GACNST","046336ec":"NAWEAP","0b8152bc":"NAYARD","08e97bec":"GACSPH"}.get(row.id,"NARADR")
			return id in world.owned_building_ids("ally")
		57:
			if event[2] == "2":
				return not world.buildings.any(func(b): return world.actor_alive(b) and b.side=="ally" and b.building_id=="GACNST")
			var id: String = {"300":"YACNST","302":"YAPOWR","303":"YABRCK","71":"CAOILD"}.get(event[2],"")
			return not id.is_empty() and not world.buildings.any(func(b):return Branches.belongs(world,b,row.house.replace("2Country","2").replace("3Country","3")) and b.building_id==id)
		60:
			return event[3] == "GATECH" and "GATECH" in world.owned_building_ids("ally")
		61:
			if event[3] == "NACNST":
				return not world.buildings.any(func(b): return world.actor_alive(b) and b.building_id == "NACNST" and b.special.get("allied_finale_room") == "Special")
			if event[3] == "AMCV":
				return int(s.phase)>=3 and not world.units.any(func(u):return world.actor_alive(u) and u.side=="ally" and u.unit_id=="AMCV")
			if event[3] == "YAPPET":
				return dominator_gone(world, s)
			if event[3]=="YAGNTC":
				return int(s.phase)>=3 and not world.buildings.any(func(b):return Branches.belongs(world,b,Branches.MAIN) and b.building_id=="YAGNTC")
	return false

static func tick(world, delta: float) -> void:
	if world.paused or world.ended or not world.allied_state.has("allied_finale"): return
	var s: Dictionary = world.allied_state.allied_finale
	var stage := int(s.get("media_stage",0))
	if stage==1 or (stage!=0 and not s.get("opening_driver",false)):
		resume_media(world)
		return
	if not s.get("retail_superweapons_applied", false):
		# Older saves serialized the inherited rules. Keep elapsed charge.
		for site in world.buildings:
			if Branches.belongs(world, site, Branches.MAIN): configure_superweapon(site, s)
		s.retail_superweapons_applied = true
	s.elapsed = float(s.elapsed) + delta
	if float(s.elapsed) < 0.12: return
	var d := Driver.new()
	if not d.restore(s.script): return
	if not s.has("finale_branches_version"):
		# Do not retroactively fire new optional discovery/construction branches
		# in saves already clearing the last enemies.
		s.skip_retroactive_branches = dominator_gone(world,s)
		s.finale_branches_version = 1
	if int(s.phase)>=3:
		# Old snapshots predate these rows. Restore the same enable links without
		# replaying the original insertion or resetting timers already running.
		d.enable("0908b62c")
		d.enable("078bff3c")
		d.enable("0988e66c")
		d.enable("078c04bc")
		d.enable("078c00bc")
		if s.get("dominator_placed",false): d.enable("0780a03c")
	# Prior snapshots lack these initially-enabled rows. Fired latches prevent replay.
	for id in ["0901606c","08cb932c","08cbabbc","08cbef3c","08cba88c"]:
		d.enable(id)
	# New runs arm this at launch. Older runs lack the row; do not backfill
	# free cash into a battle that has already passed the original event.
	if not s.get("skip_retroactive_branches",false):
		for id in ["0462be5c","0b8152bc","078f6e5c","078f692c","0930a91c","093138dc"]: d.enable(id)
	if int(s.phase)==0:
		d.enable("0be87edc")
	d.enable("0be87b9c")
	if s.has("confed_clear_clock") and not d.state.fired.has("079b37cc"):
		d.set_local(27,false)
		d.enable("079b37cc")
	if int(s.phase) == 1 and "NARADR" in world.owned_building_ids("ally"):
		s.phase = 2
		note(world, "雷达已上线。守住基地，等待超时空增援。")
	AI.prepare_raid_driver(world,s,d)
	AI.queue_returns(world,d)
	var elapsed := float(s.elapsed)
	var gate := func(r):
		if OPENING_ROWS.has(r.id):
			if not s.get("opening_driver",false) or int(s.media_stage)==0: return false
			if r.id=="0bb2e0fc": return not world.has_node("HollywoodFilm") and not opening_flight_active(world)
			return true
		if r.id in ["0960ee5c","04f32afc","090ad17c"]: return s.get("base_defense_driver",false)
		if int(s.get("media_stage",0))!=0: return false
		if not AI.is_raid_row(r.id): return true
		if not s.get("raid_driver",false): return false
		return r.house!="Arabs" or not s.get("opening_driver",false) or s.get("arabs_hostile",false)
	# In the port the clip and the actual landing are the completion gates.
	# Do not stack the retail 25 + 38 second timers on top of them.
	var opening_delays := {"094e805c": 10.0, "0bb2e0fc": 0.0} if stage!=0 and s.get("opening_driver",false) else {}
	var command := d.advance(elapsed, func(r,e): return query(world,s,r,e),gate,opening_delays)
	s.elapsed = 0.0
	for i in range(64):
		if command.is_empty(): break
		if not apply(world, s, d, command): break
		d.acknowledge(int(command.token))
		if world.ended: break
		command = d.advance(0.0, func(r,e): return query(world,s,r,e),gate,opening_delays)
	s.script = d.snapshot()
	if not world.ended and int(s.get("media_stage",0))==0:
		AI.tick(world,s,elapsed)
		if int(s.phase) >= 3: AI.fire_superweapons(world)
		Branches.oil_orders(world)
		Branches.defense_orders(world)
		Branches.third_build(world)
		pick_crates(world,s)
		extra_dialogue(world,s)

static func configure_superweapon(site, s: Dictionary) -> void:
	if site.building_id not in ["YAGNTC", "YAPPET"]: return
	site.powered = true # Retail rulesmd.ini marks both facilities Powered=true.
	var overrides: Dictionary = s.get("retail_sw_recharge", {})
	if site.building_id != "YAGNTC" and not overrides.has(site.building_id): return
	site.superweapon = site.superweapon.duplicate(true)
	site.superweapon.recharge_seconds = float(overrides.get(site.building_id, RETAIL_MUTATOR_RECHARGE))

static func extra_dialogue(world,s: Dictionary) -> void:
	if int(s.phase)<3: return
	for child in world.get_children():
		if child.has_meta("allied_finale_voice") and child.playing: return
	var done: Dictionary = s.get_or_add("extra_dialogue",{})
	# Retail recordings without a direct ALL07SMD action. These are adaptation cues.
	if not done.has("yuri"):
		for b in world.buildings:
			if not cleanup_target(world,b,ENEMIES) or b.building_id!="YAPPET" or not world.actor_visible_to("ally",b): continue
			# Strategic broadcasting alone must not count as a player reaching the base.
			if not world.units.any(func(u):return world.actor_alive(u) and u.side=="ally" and u.embarked_in==null and u.position.distance_squared_to(b.position)<=660.0**2): continue
			done.yuri=true
			speech(world,"xa7yu01","你终于找到我了？那就做个了结吧。","尤里")
			Events.emit_radar_ping(b.position,"alert")
			return
	if not done.has("boomer"):
		for u in world.units:
			if not cleanup_target(world,u,ENEMIES) or u.unit_id!="BSUB" or not world.actor_visible_to("ally",u): continue
			done.boomer=true
			speech(world,"xa7ev01","警报：发现尤里的雷鸣潜艇。用声呐舰艇追踪并摧毁它们。")
			Events.emit_radar_ping(u.position,"alert")
			return

static func pick_crates(world, s: Dictionary) -> void:
	var crates: Dictionary = s.get("cash_crates",{})
	if crates.is_empty(): return
	for u in world.units:
		if not world.actor_alive(u) or u.side!="ally" or u.is_air or u.is_naval or u.embarked_in!=null: continue
		var tile := Vector2i((u.position/Places.CELL).floor())
		if not crates.has(tile): continue
		var point: Vector2 = crates[tile]
		crates.erase(tile)
		Ra2Fx.play(world.effects_root, point, "MONEY")
		world.add_funds(SOLO_CRATE_MONEY)
		Events.emit_message("拾取资金箱：+%d 资金" % SOLO_CRATE_MONEY)
		if crates.is_empty(): return

static func draw_cash_crates(world) -> void:
	var crates: Dictionary = world.allied_state.allied_finale.get("cash_crates",{})
	var size := CASH_CRATE.get_size()
	for p in crates.values():
		if not world.position_visible_to("ally",p): continue
		world.hp_overlay.draw_texture(CASH_CRATE,Iso.dir(p)-Vector2(size.x*0.5,size.y-10.0))

const OPENING_ROWS := ["0de26e5c","0de1124c","06c3397c","0de086ac","094e805c","0bb2e0fc","0e6533ec"]

static func opening_flight_active(world) -> bool:
	return world.units.any(func(u):return world.actor_alive(u) and ((int(u.special.get("para_left",0))>0 and u.special.get("para_story_tags",{}).get("finale_opening_engineer",false)) or (u.special.get("finale_opening_engineer",false) and u.special.has("para_height"))))

static func opening_action(world,s: Dictionary,command: Dictionary) -> bool:
	var fields: Array = command.fields
	match int(command.opcode):
		112,17,48:
			var wp: int = int(fields[2]) if int(command.opcode)!=48 else 78
			if int(command.opcode)==112 or int(command.opcode)==48 or wp==78: world.center_on(AI.waypoint(world,wp))
			if int(command.opcode)==17 and world.fog!=null:
				world.fog._reveal("ally",AI.waypoint(world,wp),110.0,10.0)
		46: s.media_stage=3
		100:
			if fields[2]!="28": return false
			Film.show_clip(world,"A07_P01E")
		7:
			if fields[2]!="0B1DF85C": return false
			var zone := OpeningDrop.open_ground(world,AI.waypoint(world,107))
			if not zone.is_finite() or not OpeningDrop.launch_story(world,zone,"ENGINEER",5,AI.waypoint(world,104),{"finale_opening_engineer":true}): return false
			s.opening_drop_pending=false
		36:
			# Original changes Special's existing objects to the opening trigger owner.
			# Preserve the mission's neutral repair/engineer handoff until entry.
			s.opening_house_switch_seen=true
		21:
			if fields[2]=="EVA_BattlefieldControlOnline":
				speech(world,"ceva120","战场控制已上线。分别占领苏军建造场和磁能反应炉。")
			elif fields[2]=="EVA_EstablishBattlefieldControl": Ra2Sfx.play_player_eva(world,fields[2],0)
			# A07_p01 is supplied by the radar clip's separate retail audio.
		47:
			s.media_stage=0
			world.center_on(AI.waypoint(world,107))
		_: return false
	return true

static func optional_gi_drop(world,d,command: Dictionary) -> bool:
	var spawn: Dictionary = d.resolve_spawn(command)
	if spawn.is_empty(): return false
	var origin: String = spawn.team.team.get("transportwaypoint", "")
	var wp := 0
	for letter in origin: wp = wp*26 + letter.unicode_at(0)-64
	if wp<=0: return false
	var manifest: Array[String] = []
	var i := 0
	while spawn.team.task_force.has(str(i)):
		var fields: PackedStringArray = str(spawn.team.task_force[str(i)]).split(",")
		for n in int(fields[0]): manifest.append(fields[1])
		i+=1
	var zone := OpeningDrop.open_ground(world,position(spawn.waypoint.uv[0],spawn.waypoint.uv[1]))
	return OpeningDrop.launch_story_manifest(world,zone,manifest,AI.waypoint(world,wp-1),{"finale_start_gis":true})

static func apply(world, s: Dictionary, d, command: Dictionary) -> bool:
	if command.trigger in OPENING_ROWS: return opening_action(world,s,command)
	match int(command.opcode):
		1, 2:
			world.end_battle(command.opcode == 1)
		11:
			var message: String = {"MISSION:StopYuri":"心灵控制器已摧毁。消灭尤里的剩余部队和建筑。", "MISSION:Radar":"接管火地岛基地，建造苏军雷达站。"}.get(command.fields[2],"前往南极，摧毁尤里的心灵控制器。")
			note(world,message)
		19:
			# CHRONOTG already plays ChronosphereMove at the landing point.
			if command.trigger != "0964b13c" or command.fields[2] != "ChronosphereMove":
				Ra2Sfx.play(str(command.fields[2]))
		21:
			var label: String = command.fields[2]
			var subtitles := {"Mis_xA7_EvaMCVInbound":["xa7ev04","盟军基地车正在准备进入战场。"], "Mis_A12_EvaCountdown":["macev02","超时空增援即将抵达。五、四、三、二、一。"], "EVA_CriticalStrucureLost":["ceva021","火地岛建造场已失守。"]}
			subtitles.merge({"EVA_PsychicDominatorDetected":["ceva125","警报：侦测到心灵控制器。"],"EVA_GeneticMutatorDetected":["ceva128","警报：侦测到基因突变器。"]})
			subtitles.merge({"Mis_xA7_EvaBuildUpQuickly":["xa7ev03","盟军建造场已展开。抓紧建设基地，稳住南极阵地。"],"Mis_xA7_EvaUnholyAlliance":["xa7ev05","盟军战车工厂已就绪。现在可以用苏军和盟军的部队合力进攻。"]})
			if label=="Mis_xS4_YuriTacticsTaunt": speech(world,"xs4yu02","我知道你打的什么主意，将军。告诉你吧，这招不会奏效。","尤里")
			elif subtitles.has(label): speech(world, subtitles[label][0], subtitles[label][1])
			else: s.unsupported[label] = true
		4, 7:
			if command.trigger=="0955dd2c" and int(command.opcode)==7: return optional_gi_drop(world,d,command)
			if int(command.opcode)==7 and AI.is_raid_row(command.trigger): return AI.drive_raid(world,s,command.trigger,d)
			if AI.dispatch_return(world,command.trigger): return true
			return Branches.dispatch(world,command,d)
		6:
			Branches.hunt(world,Branches.room(str(command.fields[2])))
		9:
			Branches.fire_sale(world,Branches.room(str(command.fields[2])))
		14:
			if command.trigger == "0be87edc":
				s.phase=1
				d.enable("08ed7a3c")
				note(world,"苏军建造场已接管。恢复电力并建造雷达站。")
			elif command.trigger == "08e89b1c":
				for b in world.buildings:
					if not world.actor_alive(b) or b.side!="neutral" or b.special.get("allied_finale_room")!="Special": continue
					if b.special.get("finale_opening_tag","")=="08E8965C" or (not b.special.has("finale_opening_tag") and b.building_id=="NALASR"):
						Orders.change_side(b,"ally",false)
				Orders.refresh_after_side_changes(world)
			elif command.trigger == "0be87b9c":
				pass # Actual engineer entry has already transferred this reactor.
			elif command.trigger in ["08cba88c","08cba40c"]:
				if command.trigger=="08cba40c": Branches.transfer_tagged_third_base(world)
				# 08cba88c has no attached actors in Structures/Units; not a whole-house transfer.
			else: s.unsupported["%s:14"%command.trigger]=true
		38:
			if command.trigger=="04e8103c": s.arabs_hostile=true # This house has no placed actors; arm its scripted raids.
			elif command.trigger=="04f32afc": s.africa_hostile=true # Second-house factory AI additionally needs the southern AI switch.
			elif not command.trigger in ["0930a91c","093138dc"]: s.unsupported["%s:38"%command.trigger]=true
		113:
			note(world,"尤里的部队已被击溃。")
		3, 74:
			if command.trigger == "0988e66c": s.south_ai_enabled = true
			elif command.trigger in ["0930a91c","093138dc"] and str(command.fields[2])=="15":
				Branches.enable_third(world,int(command.opcode))
			else: s.unsupported["%s:%s" % [command.trigger,command.opcode]] = true
		132:
			var id := {"7":"YAPPET","9":"YAGNTC"}.get(str(command.fields[2]), "") as String
			if command.trigger=="0ee0857c" and not id.is_empty():
				# This optional row can run before the mission places the two sites.
				s.get_or_add("retail_sw_recharge",{})[id]=float(str(command.fields[7]).to_int())/BattleClock.RULE_TICKS_PER_SECOND
			var frames := str(command.fields[7]).to_int()
			if not id.is_empty() and frames > 0:
				for site in world.buildings:
					if cleanup_target(world,site,[command.house]) and site.building_id == id:
						site.superweapon = site.superweapon.duplicate(true)
						site.superweapon.recharge_seconds = float(frames)/BattleClock.RULE_TICKS_PER_SECOND
		108:
			if command.fields[2]=="0" and d.definition.waypoints.has(command.fields[7]):
				var uv: Array = d.definition.waypoints[command.fields[7]].uv
				var p := position(uv[0],uv[1])
				s.get_or_add("cash_crates",{})[Vector2i((p/Places.CELL).floor())]=p
			else: s.unsupported["%s:108"%command.trigger]=true
		107, 125:
			var spawn: Dictionary = d.resolve_spawn(command)
			if spawn.is_empty(): return false
			var at := position(spawn.waypoint.uv[0], spawn.waypoint.uv[1])
			if spawn.kind == "building":
				var b = world._place_building(spawn.type, "enemy", at, true)
				if b == null: return false
				b.special.allied_finale_room = spawn.house
				if spawn.house == Branches.MAIN: configure_superweapon(b, s)
				b.refresh_house_color()
				if spawn.type == "YAPPET": s.dominator_placed = true
				# Script creation is instant, so it does not emit a construction-complete alert itself.
				# Visibility and countdown come from the common path; the retail
				# Detect_PD / Detect_GM chain now owns the two delayed voices.
				world.strategic_site_completed(b, false)
				Events.emit_radar_ping(b.position,"alert")
			else:
				var key := 0
				while spawn.team.task_force.has(str(key)):
					var fields: PackedStringArray = str(spawn.team.task_force[str(key)]).split(",")
					for i in range(int(fields[0])):
						var unit = world.spawn_unit(fields[1], "ally", at + Vector2(i*22,0))
						if unit == null: return false
						if spawn.chrono:
							WarpRing.spawn(world, unit.global_position, "WARPIN")
					key += 1
				if command.trigger in ["0964b13c","098dc46c"]:
					s.phase = 3
					world.center_on(at)
					if world.fog != null: world.fog.rebuild()
					if Ra2Fx.play(world.effects_root, at, "CHRONOTG") == null:
						Ra2Sfx.play("ChronosphereMove", at)
					note(world, "替代基地车已抵达南极。尽快展开建造场。" if command.trigger=="098dc46c" else "盟军基地车已抵达南极。展开建造场，集结联军进攻。")
		_:
			# Preview retains blocked/unimplemented world actions as evidence, not as completed fidelity.
			s.unsupported["%s:%s" % [command.trigger, command.opcode]] = true
	return true
