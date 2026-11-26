extends RefCounted
const Native = preload("res://scripts/world/native_maps.gd")
const BRIEFING_SIGHT := 7.0 * Native.CELL
const Film = preload("res://scripts/ui/hollywood_film.gd")
const CASH_CRATE := preload("res://assets/maps/yr/field_crate.png")
const ID := "yr_hollywood"
const ResidentQueue = preload("res://scripts/world/hollywood_queue.gd")
const FACTORIES := [Vector2i(104,127),Vector2i(128,78),Vector2i(193,102),Vector2i(151,69)]
const VISITS := [["克林特",157,123,"xa2ev05","CLNT"],["阿诺",107,131,"xa2ar01","ARND"],["史泰龙",156,74,"xa2sl01","STLN"],["医院",64,129,"cevau92",""],["机械维修厂",171,91,"cevau93",""]]

static func cell(x:int,y:int) -> Vector2:
	return (Vector2(206-y,x-12)+Vector2.ONE*0.5)*Native.CELL

static func configure_facility(site) -> void:
	if site.building_id == "CAMACH":
		site.display_name = "机械维修厂"
		site.data.name = site.display_name
		site.data.unsellable = true
		return
	if site.building_id not in ["CALA05", "CATHOSP"] or site.battle.mission.get("id") != ID: return
	var airport:bool = site.building_id == "CALA05"
	site.display_name = "洛杉矶国际机场" if airport else "科技医院"
	site.data.name = site.display_name
	site.data.capturable = true
	site.data.unsellable = true
	if airport:
		site.data.base_normal = true
		site.data.erase("garrison_slots")
		site.data.erase("garrison_weapons")
		site.superweapon = {"type":"ParaDrop", "ui_name":"机场伞兵援助", "recharge_seconds":240, "count":6, "infantry":"E1"}

static func hospital_heal(site, delta:float) -> void:
	if site.side == "neutral" or not site.is_operational() or site.battle.paused or site.battle.ended or site.get_tree().paused: return
	var rules:Dictionary = preload("res://scripts/core/yr_death_rules.gd").data().general
	var period := float(rules.selfhealinfantryframes) / BattleClock.RULE_TICKS_PER_SECOND
	var elapsed := float(site.special.get("hospital_elapsed", 0.0)) + delta
	var pulses := floori(elapsed / period)
	site.special.hospital_elapsed = elapsed - pulses * period
	if pulses == 0: return
	for u in site.battle.units:
		if site.battle.actor_alive(u) and u.side == site.side and AlliedAbilities.infantry(u) and u.hp < u.max_hp:
			u.heal(float(rules.selfhealinfantryamount) * pulses)

static func transmit(w,clip:String,who:String) -> void:
	w.hud.show_field_transmission(who,preload("res://scripts/world/hollywood_dialogue.gd").LINES[clip],"")
	if clip != "": Ra2Sfx.play_hollywood_line(clip)

static func place(w,id:String,p:Vector2,house:String):
	var site := Native.find_base_site(w,p,id)
	if not site.is_finite(): return null
	var b=w._place_building(id,"enemy",site,true)
	if b:
		b.special.hollywood_house=house
		# This bunker is already built when its starting garrison arrives.
		if id == "NATBNK": b._buildup_play = -1.0
	return b

static func spawn(w,id:String,side:String,p:Vector2):
	var ground:Vector2=w.path_service.nearest_reachable(p,p,false,8)
	return w.spawn_unit(id,side,ground) if ground.is_finite() else null

static func move(w,u,p:Vector2) -> void:
	var route:PackedVector2Array=w.path_for_unit(u,p)
	u.order_move(p,false,null,route)

static func setup(w) -> void:
	var s := {"remaining":4,"phase":1,"poll":0.,"briefing":true,"intro":0.,"shot":0,"rescued":0,"lost":0,"plants":{},"crates":[],"visited":{},"crowd":5.,"patrol":12.,"reinforced":false,"cheer":4.,"taunted":false}
	w.allied_state.hollywood=s
	for i in FACTORIES.size():
		var tile:Vector2i=FACTORIES[i]
		var b=place(w,"YAGRND",cell(tile.x,tile.y),"Yuri3")
		if b:
			b.special.hollywood_plant=str(i)
			b.display_name="部队回收厂（%d号）" % (i+1)
			s.plants[str(i)]=b.position
	var bases:Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/hollywood_sites.json"))
	for row in bases:
		place(w,row[0],cell(row[1],row[2]),row[3])
	var bases_script = preload("res://scripts/world/hollywood_bases.gd")
	bases_script.populate(w)
	bases_script.assign_guards(w,int(BattleRequest.skirmish_config.get("difficulty",1)))
	for row in VISITS:
		if str(row[4])=="": continue
		var hero=spawn(w,row[4],"neutral",cell(row[1],row[2]))
		if hero:
			hero.special.hollywood_star=row[0]
			hero.display_name=row[0]
			hero.fire_stance="none"
	center_briefing(w,s)
	Film.show_clip(w,"A02_F00E",func(): transmit(w,"xa2ev01","伊娃"))

static func start_patrols(w) -> void:
	w.allied_state.hollywood.patrols_started = true
	if int(BattleRequest.skirmish_config.get("difficulty",1))==2:
		for route in [[139,108,135,108],[132,113,135,116]]:
			var goal:=cell(route[2],route[3])
			for i in 4:
				var guard=spawn(w,"INIT","enemy",cell(route[0],route[1])+Vector2(i*18,0))
				if guard:
					guard.special.hollywood_house="YuriCountry"
					guard.order_move(goal,true,null,w.path_for_unit(guard,goal))
	for u in w.units:
		if not w.actor_alive(u) or u.side != "enemy" or u.embarked_in != null or not u.special.has("hollywood_patrol"): continue
		var anchor:Vector2 = u.special.hollywood_patrol
		var outward:Vector2 = anchor.direction_to(u.position)
		var end:Vector2 = w.path_service.nearest_reachable(u.position + outward * 220, u.position)
		if end.distance_to(u.position) > u.ARRIVE_EPS: u.order_patrol(end)
	# StudioPatrol_Script alternates original waypoints 31 and 30 with two Lashers.
	for lane in [-45.0, 45.0]:
		var offset := Vector2(float(lane), 0.0)
		var tank = spawn(w,"LTNK","enemy",cell(126,142) + offset)
		if tank == null: continue
		var end:Vector2 = w.path_service.nearest_reachable(cell(146,141) + offset,tank.position)
		tank.special.hollywood_studio_patrol = true
		tank.order_patrol(end)

# ALL02UMD Tank_Cheese, Hard_Cheese and Lame_Cheese_Tank teams.
const STANDARD_ATTACKS := [["LTNK","LTNK","LTNK","LTNK"],["LTNK","LTNK","LTNK","YTNK"],["LTNK","LTNK","LTNK","YTNK","YTNK"],["INIT","INIT","INIT","INIT","INIT","YURI"],["LTNK","LTNK","YTNK","YTNK","YTNK"],["INIT","INIT","INIT","YURI","YURI"]]
const ATTACK_ENTRIES := [Vector2i(23,102),Vector2i(103,22),Vector2i(64,69)]

const EASY_ATTACKS := [["LTNK","LTNK","LTNK"],["YTNK","LTNK"],["INIT","INIT","INIT","YURI"],["INIT","INIT","INIT","INIT"],["LTNK","INIT","INIT","INIT"]]

static func difficulty_attacks(w,s:Dictionary,elapsed:float) -> void:
	var level:=int(BattleRequest.skirmish_config.get("difficulty",1))
	var teams:Array=EASY_ATTACKS if level==0 else STANDARD_ATTACKS
	if not s.has("attack_left"):
		if level==2:
			if not w.buildings.any(func(b):return w.actor_alive(b) and b.side=="ally" and b.building_id=="GAWEAP"): return
		elif not s.visited.has("克林特"): return
		s.attack_left=180.0 if level==2 else 330.0
		return
	s.attack_left=maxf(0,float(s.attack_left)-elapsed)
	if s.attack_left>0: return
	if w.buildings.any(func(b):return w.actor_alive(b) and b.side=="ally" and b.building_id=="GASPYSAT"): return
	var index:=int(s.get("attack_index",0))
	var entry:Vector2i=ATTACK_ENTRIES[index%3]
	var goal:Vector2=w._player_target()
	var n:=0
	for id in teams[index]:
		var u=spawn(w,id,"enemy",cell(entry.x,entry.y)+Vector2.RIGHT.rotated(n*2.4)*(n*24))
		n+=1
		if u:
			u.special.hollywood_house="Yuri2"
			u.order_move(goal,true,null,w.path_for_unit(u,goal))
	s.attack_index=(index+1)%teams.size()
	s.attack_left=180.0 if level==2 else 420.0 if level==0 and s.attack_index!=0 else 240.0

static func intro(w,s:Dictionary,dt:float) -> void:
	var resume_clip: String = s.get("resume_briefing_clip", "")
	if not resume_clip.is_empty():
		s.erase("resume_briefing_clip")
		match resume_clip:
			"A02_F00E": Film.show_clip(w, resume_clip, func(): transmit(w,"xa2ev01","伊娃"))
			"A02_P01E": Film.show_clip(w, resume_clip)
			"A02_P02E": Film.show_clip(w, resume_clip, func(): transmit(w,"xa2ev02","伊娃"))
		return
	s.intro+=dt
	if s.shot == 0 and not s.get("airport_report",false) and not w.has_node("HollywoodFilm"):
		s.airport_report = true
		Film.show_clip(w,"A02_P01E")
	if s.shot==0 and s.intro>=7 and not w.has_node("HollywoodFilm"):
		s.shot=1
		flash_buildings(w,"YAGRND",90)
		center_briefing(w,s)
		Film.show_clip(w,"A02_P02E",func(): transmit(w,"xa2ev02","伊娃"))
		crowd(w,s)
	if s.shot==1 and w.has_node("HollywoodFilm"):return
	if s.shot==1 and s.intro>=12:
		s.shot=3
		transmit(w,"cevau54","伊娃")
	if s.shot in [1,3] and s.intro>=15:
		s.shot=2
		s.briefing=false
		start_patrols(w)
		var home:Vector2=w.player_start()
		var mcv=spawn(w,"AMCV","ally",home)
		for i in 6: spawn(w,"E1","ally",home+Vector2.RIGHT.rotated(i*TAU/6)*155.)
		for i in 2: spawn(w,"MTNK","ally",home+Vector2(180,i*120))
		w.fog.rebuild()
		w.center_on(home)
		if mcv: w.select_unit(mcv,false); w._emit_selection()
		Ra2Sfx.play_player_eva(w,"EVA_BattlefieldControlOnline")
		w.hud.show_field_transmission("伊娃","战场控制系统已上线。","")
		Events.emit_message("机场车队已抵达。选中基地车，按 J 展开。派工程师占领洛杉矶国际机场，即可获得伞兵援助。")

static func crowd(w,s:Dictionary) -> void:
	var streets := {"0":cell(109,124),"1":cell(136,79),"2":cell(201,105)}
	for plant in w.buildings:
		if not w.actor_alive(plant): continue
		var key:String=plant.special.get("hollywood_plant","")
		if key not in ResidentQueue.ROUTES or not s.plants.has(key): continue
		var points:=ResidentQueue.slots(w,plant,streets[key])
		if points.is_empty(): continue
		var count:int=w.units.filter(func(u):return w.actor_alive(u) and u.special.get("hollywood_civilian")==key).size()
		for i in range(count,ResidentQueue.LENGTH):
			var u=spawn(w,["CIV1","CIV2","CIV3"][(int(key)+i)%3],"neutral",points[i+1])
			if u:
				u.special.hollywood_civilian=key
				u.display_name="被控制的居民"
				u.fire_stance="none"
				move(w,u,points[i])

static func proximity(units:Array,p:Vector2,radius:float) -> bool:
	return units.any(func(u):return u.position.distance_squared_to(p)<radius*radius)

# ALL02UMD Find_Dino uses the perimeter CellTags, event 59 (entered or overflown).
static func discover_dinosaur(w, s:Dictionary) -> void:
	if s.get("rexy_triggered", false): return
	for scout in w.get_tree().get_nodes_in_group("allies"):
		if not scout is Unit or scout.side != "ally" or not w.actor_alive(scout) or scout.embarked_in != null: continue
		var tile := Vector2i((scout.position / Native.CELL).floor())
		var x := tile.y + 12
		var y := 206 - tile.x
		if not ((x in [128,144] and y >= 125 and y <= 138) or (y in [125,138] and x >= 128 and x <= 144)): continue
		s.rexy_triggered = true
		s.visited["恐龙片场"] = true
		transmit(w,"xa2ev04","伊娃")
		var rules:Dictionary = preload("res://scripts/core/yr_death_rules.gd").data().general
		w.fog._reveal("ally", cell(140,134), float(rules.revealtriggerradius) * Native.CELL)
		for rex in w.units:
			if not w.actor_alive(rex) or rex.unit_id != "DNOA" or rex.side != "neutral" or rex.special.get("hollywood_house") != "Neutral": continue
			# Rexy_Script changes ownership to house 0, then assigns mission 11.
			AlliedAbilities.change_side(rex,"ally")
			rex.set_fire_stance("free")
			rex.special.rexy_guard_origin = rex.position
			Events.emit_message("片场的霸王龙已加入你的部队。")
			break
		return

static func discover(w,s:Dictionary,allies:Array) -> void:
	for row in VISITS:
		var place_name:String=row[0]
		var p:=cell(row[1],row[2])
		if not proximity(allies,p,320):continue
		if not s.visited.has(place_name):
			s.visited[place_name]=true
			if place_name in ["医院","机械维修厂"]:
				flash_buildings(w,"CATHOSP" if place_name=="医院" else "CAMACH",40)
				Events.emit_radar_ping(p,"campaign_discovery")
			elif place_name=="阿诺": Events.emit_radar_ping(p,"campaign_discovery")
			var text: String="已找到%s。" % place_name
			for u in w.units:
				if w.actor_alive(u) and u.special.get("hollywood_star")==place_name:
					AlliedAbilities.change_side(u,"ally")
					u.special.studio_rescued=true
					u.set_fire_stance("free")
					text="%s已经加入你的部队。" % place_name
			if place_name=="医院": text="发现科技医院。派工程师占领后，己方步兵会自动恢复生命。"
			if place_name=="机械维修厂": text="发现机械维修厂。受损的车辆可以在这里维修。"
			Events.emit_message(text)
			transmit(w,row[3],place_name if row[3] in ["xa2ar01","xa2sl01"] else "伊娃")
		if place_name=="机械维修厂":
			for u in allies:
				if u.position.distance_to(p)<320 and not AlliedAbilities.infantry(u):u.heal(4.)

static func plants_tick(w,s:Dictionary,allies:Array,elapsed:float) -> void:
	var spawned_crates := []
	var active:Dictionary={}
	for b in w.buildings:
		if w.actor_alive(b) and b.side=="enemy" and b.special.has("hollywood_plant") and not b.special.get("hollywood_infiltrated",false):active[b.special.hollywood_plant]=b
	for key in s.plants.keys():
		if active.has(key):continue
		spawned_crates.append(s.plants[key])
		s.crates.append(s.plants[key])
		s.plants.erase(key)
		if key=="0":transmit(w,"xs3yu05","尤里")
		if key in ["0","2"]:transmit(w,"xa2gg01","重装大兵")
		Events.emit_message("%d号回收厂已停运。让地面部队走到资金箱上，领取 500 资金。" % (int(key)+1))
	var lines:Dictionary={}
	for u in w.units.duplicate():
		if not w.actor_alive(u) or not u.special.has("hollywood_civilian"):continue
		var key:String=u.special.hollywood_civilian
		if not s.plants.has(key):
			u.special.erase("hollywood_civilian")
			u.special.hollywood_rescued=true
			u.display_name="获救的居民"
			u.order_stop(false)
			s.rescued+=1
		else:
			lines.get_or_add(key,[]).append(u)
	for key in lines:
		ResidentQueue.advance(w,active[key],lines[key],elapsed)
	for unit in allies:
		var tile := Vector2i((unit.position / Native.CELL).floor())
		if unit.special.get("hollywood_crate_underfoot") == tile:
			continue
		unit.special.erase("hollywood_crate_underfoot")
		for p in s.crates:
			if Vector2i((p / Native.CELL).floor()) != tile:
				continue
			if spawned_crates.has(p):
				unit.special.hollywood_crate_underfoot = tile
			else:
				s.crates.erase(p)
				w.add_funds(500)
				Events.emit_message("已回收 500 资金。")
			break
	s.remaining=s.plants.size()

static func radar_online(w) -> bool:
	return w.allied_state.get("hollywood",{}).get("radar",false)

static func update_radar(w,s:Dictionary,elapsed:=0.0) -> void:
	var online:bool=w.buildings.any(func(b):return w.actor_alive(b) and b.side=="ally" and b.building_id in ["GAAIRC","AMRADR","GASPYSAT","NARADR"] and b.is_operational() and not w.side_power_low("ally"))
	if online != radar_online(w):
		s.radar=online
		s.radar_ping_left=0.0
		Events.emit_message("雷达已上线，黄色标记指示仍在运转的回收厂。" if online else "雷达离线。恢复供电或重建空指部。")
		w.hud.minimap.queue_redraw()
	if online and s.remaining>0:
		s.radar_ping_left=float(s.get("radar_ping_left",0.0))-elapsed
		if s.radar_ping_left<=0:
			w.hud.minimap.clear_objective_flashes()
			for point in s.plants.values(): Events.emit_radar_ping(point,"campaign_site")
			s.radar_ping_left=120.0

static func briefing_point(s:Dictionary) -> Vector2:
	return cell(116,180) if s.shot == 0 else s.plants["0"]

static func center_briefing(w,s:Dictionary) -> void:
	w.fog.rebuild()
	w.center_on(briefing_point(s))

static func markers(w, radar := true) -> Array:
	var s: Dictionary = w.allied_state.hollywood
	var result := []
	var online := radar_online(w)
	if w.ended or s.phase == 3 or (radar and not online): return result
	for b in w.buildings:
		if not w.actor_alive(b) or b.side != "enemy": continue
		var p: Vector2 = b.position
		var key: String = b.special.get("hollywood_plant", "")
		if s.phase == 1 and s.plants.has(key) and not b.special.get("hollywood_infiltrated", false):
			if online or w.position_explored_by("ally", p):
				result.append({"position":p,"actor":b,"status":"active","title":"部队回收厂","color":Color.GOLD})
		elif s.phase == 2 and w.position_explored_by("ally", p) and b.special.get("hollywood_house") in ["YuriCountry","Yuri2"]:
			result.append({"position":p,"actor":b,"status":"active","title":"摧毁" + b.display_name,"color":Color.TOMATO})
	for p in s.get("crates", []):
		if radar or w.position_explored_by("ally", p):
			result.append({"position":p,"status":"active","title":"资金箱","color":Color.LIME_GREEN,"optional":true})
	return result

static func flash_buildings(w,id:String,frames:int) -> void:
	for b in w.buildings:
		if not w.actor_alive(b) or b.building_id!=id:continue
		if id=="YAGRND" and not b.special.has("hollywood_plant"):continue
		b.special.campaign_flash_left=float(frames)/BattleClock.RULE_TICKS_PER_SECOND

static func draw_supplies(w) -> void:
	var s:Dictionary=w.allied_state.hollywood
	if s.briefing and s.shot==0:
		var arrow:=RA2Art.fx("ARRWW")
		if not arrow.is_empty():
			var frame:=int(float(s.intro)*7.5)%int(arrow.count)
			var src:=RA2Art.fx_rect(arrow,frame)
			var size:=src.size*1.5
			w.hp_overlay.draw_texture_rect_region(arrow.tex,Rect2(Iso.dir(cell(113,177))-size/2,size),src)
	for p in w.allied_state.hollywood.get("crates",[]):
		if not w.position_visible_to("ally",p):continue
		var pos:=Iso.dir(p)
		var size := CASH_CRATE.get_size()
		var top_left := pos - Vector2(size.x * 0.5, size.y - 10.0)
		w.hp_overlay.draw_texture(CASH_CRATE, top_left)
		w.hp_overlay.draw_string(ThemeDB.fallback_font,Vector2(pos.x - 25, top_left.y - 4),"资金箱")

static func tick(w,dt:float) -> void:
	var s:Dictionary=w.allied_state.hollywood
	if not s.has("plants"):return
	if s.get("cameo_left",0.)>0: s.cameo_left=maxf(0.,s.cameo_left-dt)
	if s.briefing:intro(w,s,dt);return
	if s.phase==3:
		s.cheer-=dt
		if s.cheer<=0:w.end_battle(true)
		return
	discover_dinosaur(w,s)
	s.poll-=dt
	if s.poll>0:return
	var elapsed:=0.5-float(s.poll)
	s.poll=.5
	difficulty_attacks(w,s,elapsed)
	if not s.get("patrols_started",false): start_patrols(w)
	var allies:Array=w.units.filter(func(u):return w.actor_alive(u) and u.side=="ally" and not u.is_air and u.embarked_in==null)
	if allies.is_empty() and not w.units.any(func(u):return w.actor_alive(u) and u.side=="ally") and not w.buildings.any(func(b):return w.actor_alive(b) and b.side=="ally"):
		w.end_battle(false);return
	preload("res://scripts/world/hollywood_bases.gd").tick(w,s,elapsed)
	plants_tick(w,s,allies,elapsed)
	update_radar(w,s,elapsed)
	discover(w,s,allies)
	s.crowd-=elapsed
	if s.crowd<=0:s.crowd=5.;crowd(w,s)
	s.patrol-=elapsed
	if s.patrol<=0:
		s.patrol=20.
		for hut in w.buildings:
			if w.actor_alive(hut) and hut.building_id=="CABHUT" and hut.special.has("bridge_span") and not hut.special.bridge_repaired:
				var assigned:bool=w.units.any(func(u):return w.actor_alive(u) and u.special.get("target")==hut)
				if not assigned:
					var eng=spawn(w,"ENGINEER","enemy",hut.position+Vector2(290,55))
					if eng:AlliedAbilities.use(eng,"allied_bridge",hut)
	if not s.taunted and w.buildings.any(func(b):return w.actor_alive(b) and b.side=="ally" and b.building_id in ["GADEPT","NADEPT"]):
		s.taunted=true;transmit(w,"xa2yu01","尤里")
	s.fortress_elapsed=float(s.get("fortress_elapsed",0))+elapsed
	if not s.reinforced and s.fortress_elapsed>=5 and w.buildings.any(func(b):return w.actor_alive(b) and b.side=="ally" and b.building_id=="GATECH"):
		s.reinforced=true
		var fortress=spawn(w,"BFRT","ally",w.player_start()+Vector2(250,0))
		if fortress:
			for id in ["GGI","GGI","GGI","E1","E1"]:
				var passenger = spawn(w,id,"ally",fortress.position)
				if passenger and passenger.logistics.request_board(fortress): passenger.logistics.tick(0)
			Events.emit_radar_ping(fortress.position,"campaign_discovery")
		s.cameo_left=120.0/BattleClock.RULE_TICKS_PER_SECOND
		w.hud.select_prod_tab("vehicle")
		transmit(w,"cevau71","伊娃")
		Ra2Sfx.play_player_eva(w,"EVA_ReinforcementsHaveArrived")
		w.hud.show_field_transmission("伊娃","增援部队已抵达。","")
		Events.emit_message("战斗要塞已抵达机场。")
	if s.remaining==0 and s.phase==1:
		s.phase=2
		w.hud.minimap.clear_objective_flashes()
		transmit(w,"xa2ev06","伊娃")
		Events.emit_message("回收厂已全部停运。摧毁尤里两处基地的剩余建筑。")
	elif s.phase==2 and not w.buildings.any(func(b):return w.actor_alive(b) and b.side=="enemy" and b.special.get("hollywood_house") in ["YuriCountry","Yuri2"]):
		s.phase=3
		for resident in w.units:
			if w.actor_alive(resident) and resident.special.get("hollywood_rescued",false) and resident._seq.has("Cheer"):
				resident.special.cheer_elapsed=0.0
				resident.queue_redraw()
		Events.emit_message("洛杉矶已解放！获救的居民正在街头欢呼。")
