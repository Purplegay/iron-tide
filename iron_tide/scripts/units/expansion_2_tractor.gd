extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const CARD:="ap_tractor_warhead"
const KEY:="progression_v2"
const ARM:="tractor_arm"
const PAYLOAD:="expansion_tractor"
const FIELDS:="expansion_tractor_fields"

static func posture(unit) -> bool:
	return unit.unit_id in ["V3","DRED"] or (unit.unit_id=="SCHP" and unit._deployed and not unit.special.has("siege_progress") and unit.logistics.air_lift<=.001)

static func ready(unit) -> bool:
	return posture(unit) and not unit.special.get(KEY,{}).has(ARM)

static func cast(unit,ab) -> bool:
	unit.special.get_or_add(KEY,{"side":unit.side})[ARM]=P.number("mechanic/ap_tractor_warhead","arm_seconds")
	ab.trigger_cooldown();unit.queue_redraw()
	return true

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	if not s.has(ARM):return
	R.timer(s,ARM,dt)
	if not posture(unit):s.erase(ARM)
	unit.queue_redraw()

static func take(unit,damage:float,bonus:Dictionary) -> Dictionary:
	if not R.active(unit) or not posture(unit) or bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false):return {}
	var s:Dictionary=unit.special.get(KEY,{})
	if s.get("side",unit.side)!=unit.side or float(s.get(ARM,0))<=0:return {}
	s.erase(ARM);unit.queue_redraw()
	var weapon:Dictionary={"damage":damage*R.value(unit,CARD,"damage"),"attack_type":"explosive"}
	var packet:=bonus.duplicate(true)
	packet.expansion_extra=true;packet.damage_owner_side=unit.side;packet.reference_weapon=weapon.duplicate(true)
	return {"owner":unit,"side":unit.side,"radius":R.value(unit,CARD,"radius")*R.CELL,"weapon":weapon,"bonus":packet}

static func rocket_created(unit,missile) -> void:
	var flight:Dictionary=missile.special.flight
	var payload:=take(unit,float(flight.damage),flight.bonus)
	if not payload.is_empty():flight[PAYLOAD]=payload

static func projectile_created(projectile) -> void:
	var unit=projectile.shooter()
	if not is_instance_valid(unit) or not unit is Unit or unit.unit_id!="SCHP" or projectile.attacker_bonus.get("impact_weapon","") not in ["YR_SOV_160mm","YR_SOV_160mmE"]:return
	var payload:=take(unit,projectile.base_damage,projectile.attacker_bonus)
	if not payload.is_empty():projectile.splinters[PAYLOAD]=payload

static func landed(world,point:Vector2,payload:Dictionary) -> void:
	if payload.is_empty() or not BattleRequest.extensions_enabled():return
	if world.house_defeated(payload.side):return
	var field:=payload.duplicate(true)
	field.point=point;field.left=P.number("mechanic/ap_tractor_warhead","duration")
	world.allied_state.get_or_add(FIELDS,[]).append(field)

static func rocket_landed(missile) -> void:
	var flight:Dictionary=missile.special.flight
	var payload:Dictionary=flight.get(PAYLOAD,{})
	flight.erase(PAYLOAD)
	if not payload.is_empty():landed(R.world(missile),missile.position,payload)

static func projectile_landed(projectile) -> void:
	var payload:Dictionary=projectile.splinters.get(PAYLOAD,{})
	projectile.splinters.erase(PAYLOAD)
	if not payload.is_empty():landed(projectile.get_parent().get_parent(),projectile.target_point,payload)

static func ground(actor) -> bool:
	if not AlliedAbilities.alive(actor) or R.temporary(actor):return false
	return actor is Building or (actor is Unit and not actor.is_air_target() and not actor.is_naval and actor.embarked_in==null and not actor.special.has("para_height"))

static func enemy(actor,field:Dictionary) -> bool:
	return ground(actor) and actor.side!="neutral" and not BattleRequest.friendly(actor.side,field.side)

static func movable(unit) -> bool:
	return ground(unit) and unit is Unit and not unit.is_air and not unit.is_deployed() and not AlliedAbilities.frozen(unit) and unit.move_speed>0 and not unit.special.get("displacement_immune",false) and not unit.special.has("hero_wreck")

static func pull(world,unit,center:Vector2,distance:float) -> void:
	var remaining:=minf(distance,unit.position.distance_to(center))
	# Sample terrain at small intervals; the native body sweep handles walls and actors.
	while remaining>.000001:
		var motion:Vector2=unit.position.direction_to(center)*minf(4.0,remaining)
		var next:Vector2=unit.position+motion
		if next.x<unit.radius or next.y<unit.radius or next.x>world.map_size-unit.radius or next.y>world.map_size-unit.radius:return
		if not unit._domain_ok(next) or (world.path_service!=null and world.path_service.is_blocked(next,false,unit.is_amphibious,false)):return
		var before:Vector2=unit.position
		var collision=unit.move_with_traffic_exceptions(motion)
		var travelled:float=before.distance_to(unit.position)
		remaining-=travelled
		if collision!=null or travelled<=.000001:return
	unit.queue_redraw()

static func burst(world,field:Dictionary) -> void:
	var source=field.owner
	if not AlliedAbilities.alive(source) or source.side!=field.side:source=null
	for target in world.units.duplicate()+world.buildings.duplicate():
		if not enemy(target,field):continue
		var point:Vector2=target.closest_footprint_point(field.point) if target is Building else target.position
		if point.distance_to(field.point)>field.radius:continue
		var damage:=CombatMath.full_damage(field.weapon,target.armor,field.bonus,null,target.ra2_armor,0,target)
		target.receive_hit(damage,"explosive",field.bonus,source)
	if world.position_visible_to("ally",field.point):Effects.spawn_impact(field.point,Color(.6,.8,1),field.radius)

static func world_tick(world,dt:float) -> void:
	var fields:Array=world.allied_state.get(FIELDS,[])
	for field:Dictionary in fields.duplicate():
		if world.house_defeated(field.side):fields.erase(field)
	if fields.is_empty():world.allied_state.erase(FIELDS);return
	for unit in world.units:
		if not movable(unit):continue
		var nearest:Dictionary={};var gap:=INF
		for field:Dictionary in fields:
			if field.left<=0 or not enemy(unit,field):continue
			var d:float=unit.position.distance_to(field.point)
			if d<=field.radius and d<gap:nearest=field;gap=d
		if not nearest.is_empty():pull(world,unit,nearest.point,P.number("mechanic/ap_tractor_warhead","speed")*R.CELL*minf(dt,nearest.left))
	for field:Dictionary in fields.duplicate():
		field.left=maxf(0,float(field.left)-dt)
		if field.left<=.000001:fields.erase(field);burst(world,field)
	if fields.is_empty():world.allied_state.erase(FIELDS)

static func entries(unit) -> Array:
	var left:=float(unit.special.get(KEY,{}).get(ARM,0))
	return [preload("res://scripts/units/expansion_visual.gd").row("牵引弹头 · 下一枚主弹",left,false,"explosive")] if left>0 else []

static func draw_fields(canvas,world) -> void:
	for field:Dictionary in world.allied_state.get(FIELDS,[]):
		if not world.position_visible_to("ally",field.point):continue
		var ring:=PackedVector2Array()
		for i in 33:ring.append(Iso.dir(field.point+Vector2.from_angle(TAU*i/32)*field.radius))
		canvas.draw_colored_polygon(ring,Color(.2,.55,.9,.12));canvas.draw_polyline(ring,Color(.4,.8,1,.8),2,true)
		var radius:float=field.radius*fposmod(float(field.left)*2,1)
		for i in 8:
			var direction:=Vector2.from_angle(TAU*i/8)
			canvas.draw_line(Iso.dir(field.point+direction*radius),Iso.dir(field.point+direction*maxf(0,radius-12)),Color(.5,.85,1,.7),2)
		canvas.draw_string(ThemeDB.fallback_font,Iso.dir(field.point),"牵引 %.1fs"%field.left,HORIZONTAL_ALIGNMENT_CENTER,-1,12,Color.CYAN)
