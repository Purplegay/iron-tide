extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const C=preload("res://scripts/rules/expansion_contracts.gd")
const CELL=55.0
const CREW="ap_convoy_crew"
const PRESS="ap_convoy_press"
const PRESS_RANGE := 5 * CELL
const APPROACH := "convoy_press_order"
const MIRROR="ps_convoy_mirror"
const HEAT="ps_convoy_heat"

static func options(u) -> Array:
	var ids:Array=[]
	for b in u._battle_world().buildings:
		if not AlliedAbilities.alive(b) or b.side!=u.side or not b.is_operational():continue
		for id:String in b.buildable:
			var row:Dictionary=GameData.get_unit(id)
			if id in ids or id in ["BORIS","TANY","YURIPR"] or row.get("role","")!="infantry":continue
			var size=GameData.ra2_source_units.get(id,{}).get("size",1)
			if not b.unit_prereqs_ok(id) or (size!=null and int(size)>u.logistics.size_limit):continue
			if u.logistics.passengers.is_empty() or u.logistics.passengers[0].unit_id!=id:ids.append(id)
	return ids

static func choose(u,ab,id:String) -> bool:
	if not AlliedAbilities.alive(u) or u.special.get("academy_hero")!="FV" or not ab.ready() or id not in options(u):return false
	var w=u._battle_world()
	var p=w.spawn_unit(id,u.side,u.position)
	if p==null:return false
	if not u.logistics.passengers.is_empty():u.logistics.unload_one()
	if not u.logistics.can_board(p):
		R.dissolve(p);return false
	p.special.convoy_loan=true
	u.logistics.passengers.append(p);p.set_stowed(u)
	u._cancel_burst();AlliedAbilities.release_control(u);AlliedAbilities.release_temporal(u)
	u._refresh_weapon_derived();AlliedAbilities.refresh_ifv_art(u)
	preload("res://scripts/units/convoy_heroes.gd").boarded(u)
	u.special.convoy.crew_flash=1.1
	ab.trigger_cooldown()
	return true

static func picker(u,ab) -> bool:
	if u.special.get("academy_hero")!="FV" or not ab.ready():return false
	var w=u._battle_world()
	var panel:PopupMenu=w.get_node_or_null("ConvoyCrewMenu")
	if panel!=null:panel.queue_free();panel.name="ClosingCrewMenu"
	panel=PopupMenu.new();panel.name="ConvoyCrewMenu";w.add_child(panel)
	var choices:=options(u)
	if choices.is_empty():panel.add_item("暂无符合当前科技的乘员");panel.set_item_disabled(0,true)
	for id:String in choices:panel.add_item(GameData.get_unit(id).name)
	panel.index_pressed.connect(func(i:int):if is_instance_valid(u) and i<choices.size():choose(u,ab,choices[i]))
	panel.popup_hide.connect(panel.queue_free)
	panel.position=Vector2i(w.get_viewport().get_mouse_position())
	panel.popup()
	return true

static func mode(u) -> String:
	if u.logistics.passengers.is_empty():return "empty"
	return str(AlliedAbilities.source(u.logistics.passengers[0]).get("IFVMode",0))

static func work(u,target,repair:bool,bonus:Dictionary) -> void:
	if R.temporary(target):return
	var s:Dictionary=u.special.convoy
	var w=u._battle_world()
	var id:String=u.unit_id
	if id=="HARV" and C.eligible(w,id) and u.side=="ally":
		var p:=C.progress(w,id)
		if u.cargo>=s.base_hold*.25:
			p.first+=1
		if u.cargo>0 and C.vehicle(target):
			if not target.special.has("convoy_haul_id"):
				w.allied_state.convoy_haul_serial=int(w.allied_state.get("convoy_haul_serial",0))+1
				target.special.convoy_haul_id=w.allied_state.convoy_haul_serial
			p.get_or_add("haul_targets",{})[str(target.special.convoy_haul_id)]=true
		if s.has("pair_left") and s.get("pair_target")!=target:p.second+=1;s.erase("pair_left")
		else:s.pair_left=3.0;s.pair_target=target
		return
	if id!="FV":return
	var current:=mode(u)
	if not repair and bonus.has("convoy_volley"):
		if s.get("worked_volley",-1)==bonus.convoy_volley:return
		s.worked_volley=bonus.convoy_volley
	if C.eligible(w,id) and u.side=="ally":
		var p:=C.progress(w,id)
		var flag:="repaired" if repair else "armed"
		if (repair or current!="empty") and not p.get(flag,false):p[flag]=true;p.first+=1
		if not repair and current!="empty":p.get_or_add("armed_modes",{})[current]=true
		if s.get("quest_mode")!=current:s.quest_chain=0
		s.quest_mode=current;s.quest_chain=int(s.get("quest_chain",0))+1
		if s.quest_chain>=3:p.second+=1;s.quest_chain=0
	if u.passive.get("id")!=MIRROR or s.has("projection_cd"):return
	s.work=int(s.get("work",0))+1
	if s.work<3:return
	var weapon:Dictionary=u._active_weapon().duplicate(true)
	if float(weapon.get("damage",0))==0:return
	var post=R.summon(u,"FV",u.position+Vector2.from_angle(u.hull_angle+PI/2)*CELL,"post",6,.2,.5+.1*R.rank(u,MIRROR))
	if post==null:return
	post.special.convoy_projection=weapon.duplicate(true)
	post.special.convoy_repair_ratio=.5+.1*R.rank(u,MIRROR)
	post._ra2_tur=u._ra2_tur
	if u.special.get("hero_skin",false) and u.hero_art!=null:
		post.special.convoy_projected_skin=true
		post.special.convoy_projected_head=u.hero_art.head_pose(u)
		post.refresh_house_color()
	post.weapon=weapon;post.display_name="双机联映 · 副炮塔";post._refresh_weapon_derived()
	post._cd_timer=float(weapon.get("cooldown",1))
	s.work=0;s.projection_cd=18.0

static func repair_projection(post,dt:float) -> void:
	var elapsed:float=float(post.special.get("convoy_repair_clock",0))-dt
	post.special.convoy_repair_clock=elapsed
	if elapsed>0:return
	var best=null
	for target in post._battle_world().neighborhood.nearby(post.position,post.attack_range,true):
		if target==post or not AlliedAbilities.alive(target) or not target is Unit or target.side!=post.side or target.hp>=target.max_hp or target.embarked_in!=null or target.is_air or AlliedAbilities.infantry(target):continue
		if post.position.distance_to(target.position)>post.attack_range:continue
		if best==null or target.hp/target.max_hp<best.hp/best.max_hp:best=target
	if best!=null:
		var gun:Dictionary=post.special.convoy_projection
		best.heal(absf(gun.damage)*float(post.special.convoy_repair_ratio),post)
		post.special.convoy_repair_clock=gun.cooldown
		Effects.spawn_beam(post.position,best.position,Color.LIGHT_CYAN,"tesla",1.4,.25)

static func fired(u) -> void:
	u.special.convoy.quiet=0.0
	if u.passive.get("id")!=HEAT:return
	var s:Dictionary=u.special.convoy
	if s.has("heat_gap"):
		var span:float=s.get("shot_age",0)
		s.heat=minf(4,float(s.get("heat",0))+minf(span,float(s.heat_window)))
	s.shot_age=0.0
	s.heat_window=float(u._active_weapon().get("cooldown",1))/rate(u)
	s.heat_gap=float(s.heat_window)+.1

static func rate(u) -> float:
	var heat:float=u.special.convoy.get("heat",0)
	return 1.6 if heat>=3.999 else (1.3 if heat>=1.999 else 1.0)

static func tick(u,dt:float) -> void:
	var s:Dictionary=u.special.convoy
	R.timer(s,"pair_left",dt)
	if u.special.has(APPROACH):
		tick_approach(u,dt)
		# A newly started windup begins at arrival.
		if s.has("press"):return
	if u.passive.get("id")==HEAT:
		s.shot_age=float(s.get("shot_age",0))+dt
		if s.has("heat_gap"):
			s.keep=1+.5*R.rank(u,HEAT);R.timer(s,"heat_gap",dt)
		elif float(s.get("keep",0))>0:s.keep=maxf(0,s.keep-dt)
		else:s.heat=maxf(0,float(s.get("heat",0))-dt)
	if s.has("press"):
		var call:Dictionary=s.press
		if u.has_move_order or u._stun_timer>0 or not selectable(u,call.target):
			s.erase("press");return
		call.left-=dt
		if call.left<=0:
			s.erase("press")
			var index:=UnitSkillLayout.find(u,PRESS)
			if index>=0:release(u,u.ability_at(index),call.point)

static func cast_press(u,ab,at:Vector2) -> bool:
	if not at.is_finite():return false
	return request_press(u,ab,pick_press(u,at))

static func pick_press(u,at:Vector2):
	var w=u._battle_world()
	var picked=w._pick_at(at,false)
	if selectable(u,picked):return picked
	for t in w.neighborhood.nearby(at,CELL):
		if not selectable(u,t):continue
		if (t is Building and t.closest_footprint_point(at).distance_to(at)<12) or t.position.distance_to(at)<=t.radius+12:
			return t
	return null

static func selectable(u,target) -> bool:
	return legal(u,target) and u._battle_world().actor_visible_to(u.side,target)

static func firing_path(u,at:Vector2) -> PackedVector2Array:
	var away:=at.direction_to(u.position)
	for angle in [0,45,-45,90,-90,135,-135,180]:
		var goal:=at+away.rotated(deg_to_rad(angle))*(PRESS_RANGE-18.0)
		var path:PackedVector2Array=u._path_for(goal)
		if path.size()>=2 and path[-1].distance_to(at)<=PRESS_RANGE:return path
	return PackedVector2Array()

static func firing_route(path:PackedVector2Array,at:Vector2) -> PackedVector2Array:
	var route:=PackedVector2Array([path[0]])
	for i in range(1,path.size()):
		var cut:=Geometry2D.segment_intersects_circle(path[i-1],path[i],at,PRESS_RANGE)
		route.append(path[i-1].lerp(path[i],cut) if cut>=0 else path[i])
		if cut>=0:break
	return route

static func request_press(u,ab,target,auto:=false) -> bool:
	if u.special.get("academy_hero")!="HARV" or ab==null or not ab.ready() or u.special.convoy.has("press") or not selectable(u,target):return false
	if u.embarked_in!=null or u.repairing or u._stun_timer>0 or AlliedAbilities.frozen(u):return false
	var at:=R.point(u,target)
	if u.position.distance_to(at)<=PRESS_RANGE:
		if auto and not auto_shot_clear(u,u.position,at):return false
		u.order_stop(false)
		u.special.convoy.press={"target":target,"point":at,"left":.6}
		return true
	var path:=firing_path(u,at)
	if path.is_empty():return false
	if auto and not auto_shot_clear(u,firing_route(path,at)[-1],at):return false
	u.order_move(path[-1],false,null,path)
	if not u.has_move_order:return false
	u.special[APPROACH]={"target":target,"side":u.side,"aim":at,"retry":0.4,"last":u.position,"stuck":0.0,"auto":auto}
	return true

static func tick_approach(u,dt:float) -> void:
	var order:Dictionary=u.special[APPROACH]
	var target=order.get("target")
	var slot:=UnitSkillLayout.find(u,PRESS)
	if u.side!=order.side or slot<0 or not u.ability_ready(slot) or u.repairing or not selectable(u,target):
		u.order_stop(false)
		return
	var ab=u.ability_at(slot)
	var at:=R.point(u,target)
	if u.position.distance_to(at)<=PRESS_RANGE:
		if not request_press(u,ab,target,order.auto):u.order_stop(false)
		return
	order.retry-=dt
	if order.retry<=0 and at.distance_to(order.aim)>CELL*.5:
		if not request_press(u,ab,target,order.auto):u.order_stop(false)
		return
	if not u.has_move_order:
		u.order_stop(false)
		return
	if u.position.distance_to(order.last)>6.0:
		order.last=u.position
		order.stuck=0.0
	else:
		order.stuck+=dt
		if order.stuck>=5.0:u.order_stop(false)

static func draw_press_preview(canvas,u,at:Vector2,aiming:bool) -> void:
	var tint:=Color("#ffd16a") if u.cargo>=u.special.convoy.base_hold*.25 else Color("#a5e8ff")
	Iso.outline(canvas,Iso.ground_circle(u.position,PRESS_RANGE),Color(tint,.55),2)
	var target=null
	if aiming:
		var pick:Dictionary=u.get_meta("press_preview_pick",{})
		if pick.is_empty() or at.distance_to(pick.at)>2.0 or Time.get_ticks_msec()>=int(pick.until):
			pick={"at":at,"target":pick_press(u,at),"until":Time.get_ticks_msec()+100}
			u.set_meta("press_preview_pick",pick)
		if selectable(u,pick.target):target=pick.target
	var end:=R.point(u,target) if target!=null else at
	var origin:Vector2=u.position
	if origin.distance_to(end)>PRESS_RANGE:
		if target==null:
			end=origin.move_toward(end,PRESS_RANGE)
		else:
			# Route queries stay off the per-frame draw path while the pointer rests.
			var cached:Dictionary=u.get_meta("press_preview_route",{})
			if cached.is_empty() or end.distance_to(cached.at)>8 or origin.distance_to(cached.origin)>8 or Time.get_ticks_msec()>=int(cached.until):
				cached={"at":end,"origin":origin,"path":firing_path(u,end),"until":Time.get_ticks_msec()+350}
				u.set_meta("press_preview_route",cached)
			var path:PackedVector2Array=cached.path
			if path.is_empty():
				Iso.outline(canvas,Iso.ground_circle(end,14),Color.SALMON,3)
				return
			var route:=firing_route(path,end)
			for i in range(1,route.size()):canvas.draw_dashed_line(route[i-1],route[i],Color.AQUAMARINE,3,10,true)
			origin=route[-1]
			Iso.outline(canvas,Iso.ground_circle(origin,9),Color.AQUAMARINE,2)
	canvas.draw_line(origin,end,tint,3,true)
	Iso.outline(canvas,Iso.ground_circle(end,12),tint,2)
	if target!=null and u.cargo>=u.special.convoy.base_hold*.25:
		var road:=road_segment(u._battle_world(),origin,end)
		if road[0]!=road[1]:canvas.draw_line(road[0],road[1],Color(tint,.25),CELL,true)

static func legal(u,t) -> bool:
	return R.enemy(u,t) and (t is Building or (t is Unit and not t.is_air_target() and not t.is_naval and not AlliedAbilities.infantry(t) and t.embarked_in==null))

static func line_distance(p:Vector2,start:Vector2,end:Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p,start,end))

static func automatic(u,ab) -> bool:
	if u.special.has(APPROACH) or (u.has_move_order and not u.attack_ordered):return false
	var target=u.attack_target
	if not legal(u,target) or u.special.get("convoy_delivery",false) or u.harvest_state in ["to_node","harvesting","unloading"]:return false
	return request_press(u,ab,target,true)

static func auto_shot_clear(u,origin:Vector2,at:Vector2) -> bool:
	if u.cargo>=.25*u.special.convoy.base_hold:
		var count:=0
		for t in u._battle_world().units+u._battle_world().buildings:
			if t==u or not AlliedAbilities.alive(t) or (t is Unit and (t.embarked_in!=null or t.is_air_target())):continue
			var p:Vector2=t.closest_footprint_point(origin) if t is Building else t.position
			if line_distance(p,origin,at)>.5*CELL:continue
			if t is Unit and BattleRequest.friendly(u.side,t.side):return false
			if legal(u,t):count+=1
		if count<2:return false
	return true

static func release(u,ab,at:Vector2) -> void:
	if not ab.ready():return
	var w=u._battle_world()
	var start:Vector2=u.position
	var direction:=start.direction_to(at)
	if direction.is_zero_approx():return
	var cost:float=.25*u.special.convoy.base_hold
	var hot:bool=u.cargo>=cost
	if hot:preload("res://scripts/units/convoy_heroes.gd").spend(u,cost)
	u.special.convoy.press_recoil=.32
	ab.trigger_cooldown()
	var factor:=2.0/maxf(.05,float(u.weapon.get("cooldown",1)))*(2 if hot else 1)
	w.allied_state.get_or_add("convoy_slugs",[]).append({"source":u,"start":start,"at":at,"point":start,"direction":direction,"hot":hot,"factor":factor,"side":u.side,"hit":false,"max_range":start.distance_to(at)})
	if hot:lay_road(w,u,start,at,factor)
	w.queue_redraw()

static func slugs_tick(w,dt:float) -> void:
	var shots:Array=w.allied_state.convoy_slugs
	for i in range(shots.size()-1,-1,-1):
		var shot:Dictionary=shots[i]
		var u=shot.source
		if not is_instance_valid(u):
			shots.remove_at(i);continue
		var start:Vector2=shot.point
		var finish:Vector2=shot.start+shot.direction*float(shot.max_range)
		var end:=start.move_toward(finish,dt*8*CELL)
		var hits:Array=[]
		for target in w.units+w.buildings:
			if not legal(u,target) or is_same(target,shot.get("first")):continue
			var p:Vector2=target.closest_footprint_point(start) if target is Building else target.position
			if shot.direction.dot(p-start)<-target.radius or line_distance(p,start,end)>maxf(10,target.radius):continue
			hits.append([start.distance_squared_to(p),target,p])
		hits.sort_custom(func(a,b):return a[0]<b[0])
		var done:=false
		for entry in hits:
			var target=entry[1]
			if shot.hit and shot.start.distance_to(entry[2])>float(shot.max_range)+target.radius:break
			var first_hit:bool=not shot.hit
			if first_hit and shot.hot and not target is Building:
				shot.hit=true;shot.first=target;shot.max_range=shot.start.distance_to(entry[2])+CELL
			else:done=true
			R.hit(u,target,float(shot.factor)*(1 if first_hit else .5))
			if done:break
		shot.point=end
		if done or shot.start.distance_to(end)>=float(shot.max_range)-.01:shots.remove_at(i)
	if shots.is_empty():w.allied_state.erase("convoy_slugs")
	w.queue_redraw()

static func lay_road(w,u,start:Vector2,at:Vector2,factor:float) -> void:
	var road:=road_segment(w,start,at)
	var road_start:=road[0]
	var road_end:=road[1]
	if road_start.distance_to(road_end)<1:return
	for t in w.units+w.buildings:
		if not R.enemy(u,t) or (t is Unit and (t.embarked_in!=null or t.is_air_target())):continue
		var p:Vector2=t.closest_footprint_point(start) if t is Building else t.position
		if line_distance(p,road_start,road_end)<=.5*CELL:R.hit(u,t,factor*.3)
	w.allied_state.get_or_add("convoy_roads",[]).append({"start":road_start,"end":road_end,"left":5.0})
	w._refresh_pathing()

static func road_segment(w,start:Vector2,at:Vector2) -> PackedVector2Array:
	var road_end:=at
	for step in range(1,ceili(start.distance_to(at)/12)+1):
		var p:=start.move_toward(at,step*12)
		if w.path_service.is_blocked_before_roads(p) or w.in_water_world(p):
			road_end=start.move_toward(at,maxi(0,step-1)*12);break
	var road_start:=start.move_toward(road_end,CELL)
	return PackedVector2Array([road_start,road_end])

static func roads_tick(w,dt:float) -> void:
	var roads:Array=w.allied_state.convoy_roads
	var changed:=false
	for i in range(roads.size()-1,-1,-1):
		roads[i].left-=dt
		if roads[i].left<=0:roads.remove_at(i);changed=true
	if roads.is_empty():w.allied_state.erase("convoy_roads")
	if changed:w._refresh_pathing()


static func draw_world(w) -> void:
	for road in w.allied_state.get("convoy_roads",[]):
		w.draw_line(road.start,road.end,Color(.58,.29,.12,.32),CELL)
		w.draw_dashed_line(road.start,road.end,Color(.95,.56,.2,.72),4,9)
	for shot in w.allied_state.get("convoy_slugs",[]):
		var p:Vector2=shot.point
		w.draw_rect(Rect2(p-Vector2(5,5),Vector2(10,10)),Color.ORANGE if shot.hot else Color.SLATE_GRAY)
	for u in w.get_tree().get_nodes_in_group("convoy_lamps"):
		if not AlliedAbilities.alive(u) or u._battle_world()!=w or not u.special.convoy.has("lamp"):continue
		var lamp:Dictionary=u.special.convoy.lamp
		if u.side!="ally" and not w.position_visible_to("ally",lamp.point):continue
		var ink:=Color(.5,.93,1,.65)
		Iso.outline(w,Iso.ground_circle(lamp.point,4*CELL),ink,2)
		w.draw_circle(lamp.point,6,ink)
		w.draw_string(ThemeDB.fallback_font,lamp.point+Vector2(10,0),"#%d  %ds"%[lamp.serial,ceili(lamp.left)],HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)

static func blocks_step(w,from:Vector2,to:Vector2) -> bool:
	for band in w.allied_state.convoy_roads:
		var before:=line_distance(from,band.start,band.end)
		var after:=line_distance(to,band.start,band.end)
		if before<=CELL*.5:
			if after+.01<before:return true
		elif after<=CELL*.5 or Geometry2D.segment_intersects_segment(from,to,band.start,band.end)!=null:return true
	return false
