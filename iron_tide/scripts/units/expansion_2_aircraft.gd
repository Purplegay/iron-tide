extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Ordinary aircraft cycle cards. Hero airborne reloading calls the same explicit ammo events.
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"
const LAST:="ps_last_calibration"
const BURN:="ps_burning_payload"
const FIRST:="full_sortie"
const FIELDS:="expansion_burning_fields"

static func state(unit) -> Dictionary:
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func burning_limit(unit) -> int:
	return int(R.value(unit,BURN,"hits"))

static func eligible(unit) -> bool:
	return unit.unit_id in ["ORCA","BEAG"] and R.active(unit) and (unit.passive.get("id")==BURN or (unit.unit_id=="ORCA" and (unit.passive.get("id")==LAST or R.talent_rank(unit,FIRST)>=0)))

static func new_cycle(unit) -> void:
	var s:=state(unit)
	s.air_cycle=int(s.get("air_cycle",0))+1;s.air_first=true;s.air_last=true;s.air_spent=false
	s.erase("air_pending");s.erase("air_shot");unit.queue_redraw()

static func refill_complete(unit,before:int,after:int,capacity:int) -> void:
	if not eligible(unit) or capacity<=0 or before>=capacity or after!=capacity or after<=before or unit.logistics.ammo!=after:return
	var s:=state(unit)
	if s.has("air_cycle") and not s.get("air_spent",false):return
	new_cycle(unit)

static func ground(target) -> bool:
	if not AlliedAbilities.alive(target) or R.temporary(target):return false
	if target is Unit:return not target.is_air_target() and target.embarked_in==null and not NavalContact.submerged(target)
	return target is Building

static func normal_missile(unit) -> bool:
	# The adapter calls Maverick damage 'flak'; the native projectile identifies the missile.
	return unit._active_weapon().get("ra2_projectile","")=="AirToGroundMissile"

static func ground_ammo_spent(unit,before:int,after:int,normal:bool,target=null) -> void:
	if not eligible(unit) or before<=after or before<=0:return
	var s:=state(unit)
	if s.get("side",unit.side)!=unit.side:return
	# New aircraft start full; restoring an existing cycle never goes through this initialization.
	if not s.has("air_cycle"):
		if before==unit.logistics.ammo_max:new_cycle(unit)
		else:s.air_cycle=0;s.air_first=false;s.air_last=false
	var damage:=0.0
	var first:bool=s.get("air_first",false)
	var last:bool=s.get("air_last",false) and after==0
	if normal and ground(target) and normal_missile(unit):
		if unit.unit_id=="ORCA":
			if first and R.talent_rank(unit,FIRST)>=0:damage+=R.talent(unit,FIRST,"damage")
			if last and unit.passive.get("id")==LAST:damage+=R.value(unit,LAST,"damage")
		s.air_pending={"damage":damage,"first":first,"last":last}
	else:s.erase("air_pending");s.erase("air_shot")
	s.air_first=false
	if after==0:s.air_last=false
	s.air_spent=true;unit.queue_redraw()

static func firing(unit) -> void:
	if not eligible(unit):return
	var s:=state(unit)
	s.air_shot=s.get("air_pending",{});s.erase("air_pending")

static func shot(unit,target,bonus:Dictionary) -> void:
	if bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false):return
	if not eligible(unit) or not ground(target) or not normal_missile(unit):return
	var s:=state(unit)
	var packet:Dictionary=s.get("air_shot",{})
	bonus.attack_bonus=float(bonus.get("attack_bonus",1.0))+float(packet.get("damage",0))
	if not packet.is_empty():bonus.expansion_air_cycle={"cycle":s.get("air_cycle",0),"first":packet.first,"last":packet.last}
	if unit.passive.get("id")==BURN:bonus.expansion_burning=R.value(unit,BURN,"damage")

static func hit(target,source,amount:float,bonus:Dictionary) -> void:
	if amount<=0 or not source is Projectile or source.target!=target or not bonus.has("expansion_burning") or not ground(target):return
	if bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false) or source.splinters.get("burning_contact",false):return
	if target.side=="neutral" or BattleRequest.friendly(source.owner_side,target.side):return
	source.splinters.burning_contact=true
	var unit=source.shooter()
	if not is_instance_valid(unit) or not unit is Unit or unit.side!=source.owner_side:return
	var s:=state(unit)
	if s.get("side",unit.side)!=unit.side:return
	s.burning_hits=int(s.get("burning_hits",0))+1
	if s.burning_hits>=burning_limit(unit):s.burning_hits=0;source.splinters.burning_create=true
	unit.queue_redraw()

static func finish(projectile) -> void:
	if not projectile.splinters.get("burning_create",false):return
	projectile.splinters.erase("burning_create")
	var unit=projectile.shooter()
	if not is_instance_valid(unit) or unit.side!=projectile.owner_side:return
	var world=R.world(unit)
	if world==null or world.house_defeated(projectile.owner_side):return
	var fields:Array=world.allied_state.get_or_add(FIELDS,[])
	for field:Dictionary in fields.duplicate():
		if is_same(field.owner,unit):fields.erase(field)
	var weapon:Dictionary={"damage":projectile.base_damage*float(projectile.attacker_bonus.expansion_burning)*P.number("mechanic/ps_burning_payload","tick_seconds"),"attack_type":"explosive"}
	var packet:Dictionary=projectile.attacker_bonus.duplicate(true)
	for key in ["expansion_burning","expansion_air_cycle","expansion_origin","expansion_volley","hit_reference_damage"]:packet.erase(key)
	packet.expansion_extra=true;packet.damage_owner_side=projectile.owner_side;packet.reference_weapon=weapon.duplicate(true)
	fields.append({"owner":unit,"side":projectile.owner_side,"point":projectile.target_point,"age":0.0,"next":P.number("mechanic/ps_burning_payload","tick_seconds"),"weapon":weapon,"bonus":packet})

static func world_tick(world,dt:float) -> void:
	var fields:Array=world.allied_state.get(FIELDS,[])
	for field:Dictionary in fields.duplicate():
		if world.house_defeated(field.side):fields.erase(field);continue
		field.age+=dt
		while field.age+.000001>=field.next and field.next<=P.number("mechanic/ps_burning_payload","duration")+.000001:
			pulse(world,field);field.next+=P.number("mechanic/ps_burning_payload","tick_seconds")
		if field.age>=P.number("mechanic/ps_burning_payload","duration")-.000001:fields.erase(field)
	if fields.is_empty():world.allied_state.erase(FIELDS)

static func pulse(world,field:Dictionary) -> void:
	var owner=field.owner
	if not AlliedAbilities.alive(owner) or owner.side!=field.side:owner=null
	for target in world.units.duplicate()+world.buildings.duplicate():
		if not ground(target) or target.side=="neutral" or BattleRequest.friendly(field.side,target.side):continue
		var point:Vector2=target.closest_footprint_point(field.point) if target is Building else target.position
		if point.distance_to(field.point)>P.number("mechanic/ps_burning_payload","radius")*R.CELL:continue
		var damage:=CombatMath.full_damage(field.weapon,target.armor,field.bonus,null,target.ra2_armor,0,target)
		target.receive_hit(damage,"explosive",field.bonus,owner)
	if world.position_visible_to("ally",field.point):Effects.spawn_impact(field.point,Color(1,.45,.1),P.number("mechanic/ps_burning_payload","radius")*R.CELL)

static func entries(unit) -> Array:
	if not eligible(unit):return []
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	if unit.passive.get("id")==BURN:
		var row:=V.row("燃烧挂载 · 累计普通导弹直击",0,false,"explosive");row.stacks=int(s.get("burning_hits",0));row.limit=burning_limit(unit);out.append(row)
	if unit.unit_id=="ORCA":
		if R.talent_rank(unit,FIRST)>=0:out.append(V.row("满载首航 · 首发准备" if s.get("air_first",unit.logistics.ammo==unit.logistics.ammo_max) else "满载首航 · 等待完整补弹",0,false,"attack"))
		if unit.passive.get("id")==LAST:out.append(V.row("末弹校准 · 末发准备" if s.get("air_last",unit.logistics.ammo==unit.logistics.ammo_max) else "末弹校准 · 等待完整补弹",0,false,"attack"))
	return out

static func draw_fields(canvas,world) -> void:
	for field:Dictionary in world.allied_state.get(FIELDS,[]):
		if not world.position_visible_to("ally",field.point):continue
		var points:=PackedVector2Array()
		for i in 33:points.append(Iso.dir(field.point+Vector2.from_angle(TAU*i/32)*P.number("mechanic/ps_burning_payload","radius")*R.CELL))
		canvas.draw_colored_polygon(points,Color(1,.25,.05,.15));canvas.draw_polyline(points,Color(1,.55,.1,.7),1.5,true)
		canvas.draw_string(ThemeDB.fallback_font,Iso.dir(field.point),"燃烧 %.1fs"%maxf(0,3-float(field.age)),HORIZONTAL_ALIGNMENT_CENTER,-1,12,Color.ORANGE)
