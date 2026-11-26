extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const Quests=preload("res://scripts/rules/peregrine_contracts.gd")
const KEY="peregrine"
const ACTIVE="ap_peregrine_hunt"
const PASSIVE="ps_peregrine_rearm"
const EVENTS="peregrine_hunters"

static func active(unit) -> bool:
	return is_instance_valid(unit) and unit is Unit and unit.special.get("academy_hero")=="ORCA" and unit.special.has(KEY) and R.active(unit)

static func protected_target(target) -> bool:
	return target.ignores_warhead("") or target.special.has("iron_left") or float(target.special.get("force_shield_left",0))>0 or target.special.get("expedition_protected",false) or AlliedAbilities.alive(target.special.get("temporal_by")) or (target.side=="ally" and GM.god_mode)

static func legal(side:String,target) -> bool:
	if not AlliedAbilities.alive(target) or not (target is Unit or target is Building) or target.side=="neutral" or BattleRequest.friendly(side,target.side) or protected_target(target):return false
	return not (target is Unit and (target.is_air_target() or target.is_naval or target.embarked_in!=null))

static func selectable(unit,target) -> bool:
	if not active(unit) or not legal(unit.side,target):return false
	return R.world(unit).actor_visible_to(unit.side,target) and not (target is Unit and AlliedAbilities.concealed(target,unit.side))

static func target_in_range(unit,target) -> bool:
	if not selectable(unit,target):return false
	var distance:float=unit.position.distance_to(R.point(unit,target))
	var primary:Dictionary=unit._weapon_for_target(null)
	return distance<=float(primary.get("range",0)) and distance>=float(primary.get("min_range",0))

static func pick(unit,at:Vector2,in_range:=true):
	if not at.is_finite():return null
	var best=null;var distance:=INF
	for target in R.world(unit).units+R.world(unit).buildings:
		if not selectable(unit,target) or (in_range and not target_in_range(unit,target)):continue
		var point:Vector2=target.closest_footprint_point(at) if target is Building else target.position
		var gap:=point.distance_to(at)
		if gap<=maxf(18,target.radius) and gap<distance:best=target;distance=gap
	return best

static func ready(unit,ab) -> bool:
	return active(unit) and ab.id==ACTIVE and ab.ready() and unit.logistics.ammo>=P.count("mechanic/ap_peregrine_hunt","ammo_cost") and unit._stun_timer<=0 and not AlliedAbilities.frozen(unit) and unit.embarked_in==null and not unit.special.has("hero_wreck") and not preload("res://scripts/units/peregrine_defense.gd").silent(unit)

static func cast(unit,ab,at:Vector2) -> bool:
	if unit.special.has("peregrine_hunt_order"):return false
	if not ready(unit,ab):return false
	var target=pick(unit,at)
	if target==null:return false
	return cast_target(unit,ab,target)

static func cast_target(unit,ab,target) -> bool:
	if not ready(unit,ab) or not target_in_range(unit,target):return false
	var raw:=float(unit._weapon_for_target(null).get("damage",0))*R.value(unit,ACTIVE,"damage")
	var bonus:Dictionary=unit.bonuses.duplicate(true)
	bonus.expansion_extra=true;bonus.peregrine_hunt=true;bonus.peregrine_side=unit.side;bonus.reference_weapon={"damage":raw,"attack_type":"explosive"}
	var axis:Vector2=unit.position.direction_to(target.position).orthogonal()
	var missiles:Array=[]
	for i in P.count("mechanic/ap_peregrine_hunt","missiles"):
		missiles.append({"target":target,"last":target.position,"point":unit.position,"origin":unit.position,"spread":unit.position+axis*(30.0+12.0*(i/2))*(-1 if i%2==0 else 1),"age":0.0,"delay":i*P.number("mechanic/ap_peregrine_hunt","launch_interval"),"lift":unit._visual_lift()})
	R.world(unit).allied_state.get_or_add(EVENTS,[]).append({"owner":unit,"side":unit.side,"raw":raw,"damage":CombatMath.with_offense(raw,bonus),"bonus":bonus,"radius":R.value(unit,ACTIVE,"radius")*R.CELL,"missiles":missiles})
	unit.logistics.spend_ammo(P.count("mechanic/ap_peregrine_hunt","ammo_cost"),false,target)
	ab.trigger_cooldown();unit.queue_redraw();R.world(unit).queue_redraw()
	return true

static func parked(unit) -> bool:
	var world=R.world(unit)
	if world==null or world.side_power_low(unit.side):return false
	for airport in world.buildings:
		if not AlliedAbilities.alive(airport) or airport.side!=unit.side or airport.under_construction or not airport.is_operational() or airport.building_id not in ["GAAIRC","AMRADR"]:continue
		for plane in UnitLogistics.home_members(airport):
			if not AlliedAbilities.alive(plane) or plane.side!=unit.side or not plane.is_air or R.temporary(plane) or plane.special.has(KEY) or plane.special.has("hero_wreck") or plane.logistics.carrier_owner!=null:continue
			if plane.logistics.home==airport and plane.logistics.dock_slot>=0 and plane.logistics.air_state in ["parked","rearming"] and plane.logistics.air_lift<=.001:return true
	return false

static func reload_factor(unit) -> float:
	return 1.0-R.value(unit,PASSIVE,"reload") if unit.passive.get("id")==PASSIVE and parked(unit) else 1.0

static func filled(unit) -> void:
	if not active(unit) or unit.passive.get("id")!=PASSIVE:return
	var s:Dictionary=unit.special[KEY]
	s.rearm_shield=minf(unit.max_hp*R.value(unit,PASSIVE,"cap"),float(s.get("rearm_shield",0))+unit.max_hp*R.value(unit,PASSIVE,"shield"))
	unit.queue_redraw()

static func absorb(unit,amount:float) -> float:
	if amount<=0 or not active(unit) or unit.passive.get("id")!=PASSIVE:return amount
	var s:Dictionary=unit.special[KEY]
	if s.get("side",unit.side)!=unit.side:return amount
	var used:=minf(amount,float(s.get("rearm_shield",0)))
	s.rearm_shield=float(s.get("rearm_shield",0))-used
	if s.rearm_shield<=0:s.erase("rearm_shield")
	return amount-used

static func world_tick(world,dt:float) -> void:
	var events:Array=world.allied_state.get(EVENTS,[])
	for event:Dictionary in events.duplicate():
		if world.house_defeated(event.side):events.erase(event);continue
		for missile:Dictionary in event.missiles.duplicate():
			var previous:float=missile.age;missile.age+=dt
			if legal(event.side,missile.target):missile.last=missile.target.position
			else:missile.target=null
			var flight:float=missile.age-float(missile.delay)
			if flight<0:continue
			if flight<.25:
				missile.point=missile.origin.lerp(missile.spread,flight/.25);continue
			if previous<float(missile.delay)+.25:missile.point=missile.spread
			var step:=minf(dt,flight-.25)
			var speed:float=maxf(P.number("mechanic/ap_peregrine_hunt","speed"),missile.target.velocity.length()+P.number("mechanic/ap_peregrine_hunt","chase_margin")) if missile.target is Unit else P.number("mechanic/ap_peregrine_hunt","speed")
			missile.point=missile.point.move_toward(missile.last,speed*step)
			missile.lift=move_toward(float(missile.lift),0,180*step)
			if missile.point.distance_to(missile.last)>.01:continue
			event.missiles.erase(missile)
			explode(world,event,missile)
		if event.missiles.is_empty():events.erase(event)
	if events.is_empty():world.allied_state.erase(EVENTS)
	if not events.is_empty():world.queue_redraw()

static func explode(world,event:Dictionary,missile:Dictionary) -> void:
	for target in world.units.duplicate()+world.buildings.duplicate():
		if not legal(event.side,target):continue
		var point:Vector2=target.closest_footprint_point(missile.last) if target is Building else target.position
		if point.distance_to(missile.last)>float(event.radius):continue
		var main:bool=is_same(target,missile.target)
		var armor:=preload("res://scripts/units/tanya_breach.gd").armor_factor(target)
		var factor:=1.0 if main else P.number("mechanic/ap_peregrine_hunt","splash_damage")
		var bonus:Dictionary=event.bonus.duplicate(true)
		bonus.peregrine_direct=main
		bonus.hit_reference_damage=float(event.raw)*factor*armor*float(bonus.get("veteran_attack",1))
		var owner=event.owner if is_instance_valid(event.owner) else null
		if main:
			Quests.contact(world,event.side,target)
			if active(owner) and owner.side==event.side and Quests.combat_target(target):owner.special[KEY].hits=true
		target.receive_hit(float(event.damage)*factor*armor,"explosive",bonus,owner)
	if world.position_visible_to("ally",missile.last):Effects.spawn_impact(missile.last,Color(.4,.85,1),event.radius)

static func draw_world(world) -> void:
	for event in world.allied_state.get(EVENTS,[]):
		for missile in event.missiles:
			if not world.position_visible_to("ally",missile.point):continue
			world.draw_set_transform(missile.point,Iso.eff_angle(),Iso.up())
			var at:=Vector2(0,-float(missile.lift))
			var direction:Vector2=Iso.dir(missile.point.direction_to(missile.last)).normalized()
			world.draw_line(at-direction*13,at,Color(.3,.85,1,.8),2,true)
			world.draw_circle(at,3,Color(.9,.95,1))
	world.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

static func draw(unit) -> void:
	preload("res://scripts/units/peregrine_defense.gd").draw(unit)
