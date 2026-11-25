extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Iron Tide extension cards. Weapon cadence, hardpoints and native weapon modes stay authoritative.
const Feedback = preload("res://scripts/units/ra3_reaper_heat.gd")
static var BUOY_RADIUS:float:
	get:return P.number("mechanic/faction","buoy_radius")
const BUOYS := &"faction_search_buoys"

static func twin_summary(rank:int) -> String:
	var card:=GameData.get_skill("ap_twin")
	var extra:float=card.twin_extra_chance[rank]
	var hits: int = card.twin_hits[rank]
	var text:="%s 秒 · %d 发" % [String.num(float(card.twin_windows[rank]),1),hits]
	if extra>0: text+="，第 %d 发 %d%%" % [hits+1,roundi(extra*100)]
	return text

static func cast(unit, ab, point: Vector2) -> bool:
	match ab.id:
		"ap_decoy":
			unit.special.decoy_origin = unit.position
			unit.special.echo_heading = unit.hull_angle
			unit.special.decoy_bonus = ab.value
		"ap_twin":
			if unit.special.get("soviet_mode",false): return false
			var rank:=clampi(int(BattleRequest.combat_context.get("card_ranks",{}).get(ab.id,0)),0,3)
			var card:=GameData.get_skill(ab.id)
			ab.duration=float(card.twin_windows[rank])
			unit.special.twin_pending=ab.duration
			unit.special.twin_value=ab.value
			var extra:float=card.twin_extra_chance[rank]
			unit.special.twin_remaining=int(card.twin_hits[rank])+int(extra>0 and randf()<extra)
			unit.special.erase("twin_left")
			unit.special.erase("twin_target")
		"ap_slope":
			if unit._moving(): return false
			unit.special.slope_origin = unit.position
			unit.special.slope_left = ab.duration
			unit.special.slope_value = ab.value
		"ap_buoy":
			var world = unit._battle_world()
			if world == null or not point.is_finite() or unit.position.distance_to(point)>P.number("mechanic/faction","buoy_range") or not world.on_water(point): return false
			unit.special.buoy_point = point
			unit.special.buoy_left = ab.value
			unit.add_to_group(BUOYS)
		_: return false
	return true

static func sees_buoy(world, observer: String, target, viewer) -> bool:
	if not NavalContact.submerged(target): return false
	if is_instance_valid(viewer):
		var ship = viewer.logistics.carrier_owner if viewer is Unit and viewer.unit_id=="ASW" else viewer
		return buoy_covers(ship,world,observer,target)
	for ship in world.get_tree().get_nodes_in_group(BUOYS):
		if buoy_covers(ship,world,observer,target): return true
	return false

static func buoy_covers(ship,world,observer:String,target) -> bool:
	return is_instance_valid(ship) and ship is Unit and ship.side==observer and ship.hp>0 and ship._battle_world()==world and ship.special.has("buoy_left") and target.position.distance_squared_to(ship.special.buoy_point)<=BUOY_RADIUS*BUOY_RADIUS

static func slope_speed(rank:int) -> float:
	return float(GameData.get_skill("ap_slope").speed_by_rank[clampi(rank,0,3)])

static func tick_slope(unit,dt:float) -> void:
	var s:Dictionary=unit.special
	if not s.has("slope_speed"):
		# Older battle saves have a running guard timer but no starting position.
		if not s.has("slope_origin"): s.slope_origin=unit.position
		if not unit.position.is_equal_approx(s.slope_origin):
			var rank:int=BattleRequest.combat_context.get("card_ranks",{}).get("ap_slope",0)
			s.slope_speed=slope_speed(rank)
			s.slope_left=float(GameData.get_skill("ap_slope").drive_seconds)
			s.erase("slope_origin")
			unit._recompute_bonuses()
	s.slope_left-=dt
	if s.slope_left<=0.000001:
		s.erase("slope_left")
		s.erase("slope_value")
		s.erase("slope_origin")
		if s.erase("slope_speed"): unit._recompute_bonuses()
	unit.queue_redraw()

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special
	if s.has("slope_left"): tick_slope(unit,dt)
	if s.has("echo_bonus_left"):
		s.echo_bonus_left-=dt
		if s.echo_bonus_left<=0.000001:
			s.erase("echo_bonus_left")
			s.erase("echo_bonus")
			s.erase("echo_cloaked")
			unit.queue_redraw()
	for timer in ["buoy_left","twin_left","contact_left","contact_cd","plate_flash","echo_left"]:
		if not s.has(timer): continue
		s[timer] -= dt
		if s[timer]<=0:
			s.erase(timer)
			if timer=="buoy_left": unit.remove_from_group(BUOYS)
			if timer=="contact_left": clear_contact(unit)
		unit.queue_redraw()
	if s.has("buoy_left") and not unit.is_in_group(BUOYS): unit.add_to_group(BUOYS)
	if s.has("decoy_origin") and unit.position.distance_squared_to(s.decoy_origin)>1:
		s.echo_point=s.decoy_origin
		s.erase("decoy_origin")
		s.echo_left=2.0
		if s.has("decoy_bonus"):
			s.echo_bonus=s.decoy_bonus
			s.erase("decoy_bonus")
		s.echo_cloaked=true
		s.echo_bonus_left=float(GameData.get_skill("ap_decoy").echo_seconds)
		unit.queue_redraw()
	if unit.passive.get("id")=="ps_limiter":
		var last:Vector2=s.get("limiter_position",unit.position)
		var driving:bool=unit._moving() and not last.is_equal_approx(unit.position) and unit.embarked_in==null and not s.has("walker_jump")
		s.limiter_time=minf(P.number("mechanic/faction","limiter_prepare"),float(s.get("limiter_time",0))+dt) if driving else 0.0
		s.limiter_position=unit.position
	if s.has("phase_target"):
		var previous_layers:=clampi(floori((float(s.get("phase_time",0))+0.00001)/P.number("mechanic/faction","phase_interval")),0,P.count("mechanic/faction","phase_cap"))
		var target=s.phase_target
		if unit.special.get("ra3_field",false) or unit.special.has("ra3_riot_point") or not AlliedAbilities.alive(target) or not is_same(unit.attack_target,target) or unit._moving() or unit._stun_timer>0 or not unit._weapon_target_valid(target) or not unit._weapon_aligned(target):
			s.erase("phase_target")
			s.erase("phase_time")
		else: s.phase_time=minf(P.count("mechanic/faction","phase_cap")*P.number("mechanic/faction","phase_interval"),float(s.get("phase_time",0))+dt)
		if previous_layers!=clampi(floori((float(s.get("phase_time",0))+0.00001)/P.number("mechanic/faction","phase_interval")),0,P.count("mechanic/faction","phase_cap")):unit.queue_redraw()

static func primary_shot(unit,target,bonuses:Dictionary) -> float:
	var s:Dictionary=unit.special
	var factor:=1.0
	if s.erase("echo_cloaked"):
		unit.special.reveal=2.0
		if s.has("echo_bonus") and not target is ForceFirePoint:
			bonuses.echo_hit=true
			factor+=float(s.echo_bonus)
		s.erase("echo_bonus")
		s.erase("echo_bonus_left")
	if unit.passive.get("id")=="ps_phase" and not unit._moving() and not target is ForceFirePoint:
		if not is_same(s.get("phase_target"),target):
			s.phase_target=target
			s.phase_time=0.0
		var layers:=clampi(floori((float(s.phase_time)+0.00001)/P.number("mechanic/faction","phase_interval")),0,P.count("mechanic/faction","phase_cap"))
		if layers>0:
			factor*=1.0+layers*float(unit.passive.value)
			bonuses.phase_layers=layers
	return factor

static func feedback(target,label:String,layers:=1) -> void:
	var world=target.battle if target is Building else target._battle_world()
	if world!=null and world.actor_visible_to("ally",target):
		Feedback.card_hit(world,target,label,layers)

static func contact_seconds(rank:int) -> float:
	return float(GameData.get_skill("ps_contact").contact_seconds[clampi(rank,0,3)])

static func contact_cooldown(rank:int) -> float:
	return float(GameData.get_skill("ps_contact").contact_cooldowns[clampi(rank,0,3)])

static func clear_contact(owner) -> void:
	var target=owner.special.get("contact_target")
	if is_instance_valid(target) and target.special.has("contact_reporters"):
		target.special.contact_reporters.erase(owner)
		if target.special.contact_reporters.is_empty(): target.special.erase("contact_reporters")
		target.queue_redraw()
	owner.special.erase("contact_target")
	owner.special.erase("contact_left")

static func contact_exposes(target,observer:String) -> bool:
	for owner in target.special.get("contact_reporters",[]):
		if AlliedAbilities.alive(owner) and owner.side==observer and contact_matches(owner,target):return true
	return false

static func draw_contact(target) -> void:
	if not contact_exposes(target,"ally"): return
	var point:Vector2=target._body_bounds.get_center()+Vector2(0,-target._body_bounds.size.y*0.5-6)
	var color:=Color("#71e9c7")
	target.draw_arc(point,4.0,0,TAU,16,color,1.3,true)
	target.draw_circle(point,1.35,color)

static func contact_owner(gun,target):
	if not is_instance_valid(gun):return null
	if gun is Unit and gun.unit_id=="ASW": gun=gun.logistics.carrier_owner
	if is_instance_valid(gun) and gun is Unit and AlliedAbilities.alive(gun) and gun.side!=target.side and gun.passive.get("id")=="ps_contact":
		return gun
	return null

static func contact_matches(owner,target) -> bool:
	return owner.special.has("contact_left") and is_same(owner.special.get("contact_target"),target)

static func record_contact(owner,target) -> void:
	var marked:=contact_matches(owner,target)
	var rank:int=BattleRequest.combat_context.get("card_ranks",{}).get("ps_contact",0)
	if not marked:
		if float(owner.special.get("contact_cd",0.0))>0.000001: return
		clear_contact(owner)
		owner.special.contact_cd=contact_cooldown(rank)
	owner.special.contact_target=target
	var reporters:Array=target.special.get_or_add("contact_reporters",[])
	if not reporters.has(owner):
		reporters.append(owner)
		target.queue_redraw()
	owner.special.contact_left=contact_seconds(rank)
	var world=owner._battle_world()
	if not marked and world!=null and world.fog!=null:
		world.fog.reveal_contact(owner.side,target)
	feedback(target,"Ping" if marked else "Tag")

static func impact(actor,target,damage:float,source,bonus:Dictionary) -> float:
	if damage<=0: return damage
	if bonus.get("echo_hit",false): feedback(target,"Echo")
	if bonus.has("phase_layers"): feedback(target,"Flux",int(bonus.phase_layers))
	if not is_instance_valid(actor): return damage
	if actor is Unit and actor.unit_id=="ASW": actor=actor.logistics.carrier_owner
	if not is_instance_valid(actor) or not (actor is Unit or actor is Building) or actor.side==target.side: return damage
	var passive:Dictionary=actor.passive if actor is Unit else {}
	var value:=float(passive.get("value",0)) if passive.get("id")=="ps_barrage" else 0.0
	if actor is Building and actor.side=="ally": value=float(actor.special.get("flak_card",0))
	if value>0 and (not source is Projectile or is_same(source.target,target)):
		if not (target is Unit and target.is_air_target()):
			actor.special.erase("barrage_target")
			actor.special.erase("barrage_count")
			return damage
		var count:=1
		if is_same(actor.special.get("barrage_target"),target): count+=int(actor.special.get("barrage_count",0))
		actor.special.barrage_target=target
		actor.special.barrage_count=count%3
		if count==3:
			feedback(target,"Burst")
			return damage*(1.0+value)
	return damage

static func defend(unit,damage:float,source,blast:Vector2) -> float:
	if damage<=0:return damage
	var s:Dictionary=unit.special
	var reduction:=0.0
	if unit.passive.get("id")=="ps_limiter" and float(s.get("limiter_time",0))>=P.number("mechanic/faction","limiter_prepare") and unit._moving():
		reduction=float(unit.passive.value)
	elif s.has("slope_left"):
		if is_instance_valid(source):
			var gun=source.shooter() if source is Projectile else source
			if is_instance_valid(gun):blast=gun.global_position
		if blast.is_finite() and Vector2.from_angle(unit.hull_angle).dot(unit.global_position.direction_to(blast))>=0.5:
			reduction=float(s.slope_value)
	if reduction>0:
		s.plate_flash=0.22
		if DisplayServer.get_name()!="headless" and not unit.has_node("FactionArmorFlash"):
			var overlay=preload("res://scripts/units/faction_armor_flash.gd").new()
			overlay.name="FactionArmorFlash"
			unit.add_child(overlay)
		unit.queue_redraw()
	return damage*(1.0-reduction)

static func draw(unit) -> void:
	var s:Dictionary=unit.special
	if s.has("buoy_left"):
		var p:Vector2=Iso.dir(s.buoy_point-unit.position)
		unit.draw_circle(p,3,Color("#ffe3a1"))
		Iso.outline(unit,Iso.ell(p,BUOY_RADIUS,BUOY_RADIUS),Color(0.32,0.83,0.96,0.38),1.4)
	if s.has("echo_left"):
		var art:=RA2Art.art("R3MIRAGE")
		var dest:=RA2Art.draw_rect(art,unit.radius,range(int(art.facings)),0,Unit.RA2_SPRITE_SCALE)
		dest.position+=Iso.dir(s.echo_point-unit.position)
		var tint:=Color(0.65,0.88,1,0.55*minf(1,float(s.echo_left)*2))
		for part in [art, RA2Art.art("R3MIRAGE_tur")]:
			if not part.is_empty():
				var frame:int=unit._sprite_facing(part,float(s.echo_heading))
				unit.draw_texture_rect_region(part.tex,dest,RA2Art.src_rect(part,frame),tint)
	if s.has("plate_flash") and unit.unit_id=="HTNK":
		var center:Vector2=unit._body_bounds.get_center()+Vector2.UP*14
		var ink:=Color(0.86,0.96,1.0,minf(1.0,float(s.plate_flash)*6))
		var pts:=PackedVector2Array([Vector2(-10,-4),Vector2(-7,-8),Vector2(-4,-5),Vector2(2,-5),Vector2(7,-2),Vector2(11,-9),Vector2(10,0),Vector2(7,5),Vector2(0,6),Vector2(-6,2),Vector2(-10,-4)])
		for i in pts.size():pts[i]+=center
		unit.draw_polyline(pts,ink,1.7,true)
		unit.draw_circle(center+Vector2(3,-2),1,ink)
