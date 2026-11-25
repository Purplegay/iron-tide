extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"
const CARD:="ps_impact_calibration"
const ZONES:="expansion_calibration"

static func deployed(unit) -> bool:
	return unit is Unit and unit.unit_id=="SCHP" and R.active(unit) and unit._deployed and not unit.is_air_target() and not unit.special.has("siege_progress") and unit.embarked_in==null

static func equipped(unit) -> bool:
	return unit.unit_id=="SCHP" and R.active(unit) and unit.passive.get("id")==CARD

static func tick(unit,dt:float) -> void:
	R.timer(unit.special.get(KEY,{}),"calibration_cd",dt)

static func shot(unit,bonus:Dictionary) -> void:
	if deployed(unit):bonus.expansion_deployed_cannon=true

static func cannon(unit,source,bonus:Dictionary) -> bool:
	if bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false):return false
	if source is Projectile:return bonus.get("expansion_deployed_cannon",false)
	# Existing deployed-cannon W uses R.hit with the actual weapon reference.
	var weapon:Dictionary=bonus.get("reference_weapon",{})
	return source==unit and bonus.get("expansion_extra",false) and not weapon.is_empty() and weapon.get("ra2_weapon_id","")==unit.deployed_weapon().get("ra2_weapon_id","invalid")

static func bonus_at(world,side:String,target) -> float:
	if world.house_defeated(side):return 0.0
	var amount:=0.0
	for zone:Dictionary in world.allied_state.get(ZONES,[]):
		if float(zone.left)<=0 or side!=str(zone.side):continue
		var point:Vector2=target.closest_footprint_point(zone.point) if target is Building else target.position
		if point.distance_to(zone.point)<=P.number("mechanic/ps_impact_calibration","radius")*R.CELL:amount=maxf(amount,float(zone.damage))
	return amount

static func impact(target,source,amount:float,bonus:Dictionary) -> float:
	var unit=R.owner(source)
	if amount<=0 or not is_instance_valid(unit) or not deployed(unit) or not R.enemy(unit,target) or not cannon(unit,source,bonus):return amount
	var world=R.world(unit)
	if world==null:return amount
	var multiplier:=1.0+bonus_at(world,unit.side,target)
	if source is Projectile and source.target==target and equipped(unit) and bonus.has("expansion_origin") and not bonus.get("expansion_extra",false):
		source.splinters.expansion_calibration={"owner":unit,"point":source.target_point}
	return amount*multiplier

static func finish(projectile) -> void:
	if not projectile.splinters.has("expansion_calibration"):return
	var pending:Dictionary=projectile.splinters.expansion_calibration
	projectile.splinters.erase("expansion_calibration")
	var unit=pending.owner
	if not is_instance_valid(unit) or not deployed(unit) or not equipped(unit):return
	var s:Dictionary=unit.special.get_or_add(KEY,{"side":unit.side})
	if s.get("side",unit.side)!=unit.side or s.has("calibration_cd"):return
	var world=R.world(unit)
	var zones:Array=world.allied_state.get_or_add(ZONES,[])
	for zone:Dictionary in zones.duplicate():
		if is_same(zone.get("owner"),unit):zones.erase(zone)
	zones.append({"owner":unit,"side":unit.side,"point":pending.point,"left":P.number("mechanic/ps_impact_calibration","duration"),"damage":R.value(unit,CARD,"damage")})
	s.calibration_cd=P.number("mechanic/ps_impact_calibration","cooldown");unit.queue_redraw()

static func world_tick(world,dt:float) -> void:
	var zones:Array=world.allied_state.get(ZONES,[])
	for zone:Dictionary in zones.duplicate():
		if world.house_defeated(zone.side):zones.erase(zone);continue
		zone.left-=dt
		if zone.left<=.000001:zones.erase(zone)
	if zones.is_empty():world.allied_state.erase(ZONES)

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special.get(KEY,{})
	return [V.row("弹着校射生成冷却",s.calibration_cd,false,"focus")] if s.has("calibration_cd") else []

static func draw_fields(canvas,world) -> void:
	for zone:Dictionary in world.allied_state.get(ZONES,[]):
		if not world.position_visible_to("ally",zone.point):continue
		var points:=PackedVector2Array()
		for i in 33:points.append(Iso.dir(zone.point+Vector2.from_angle(TAU*i/32)*P.number("mechanic/ps_impact_calibration","radius")*R.CELL))
		canvas.draw_polyline(points,Color(.3,.85,1,.65),1.5,true)
		canvas.draw_string(ThemeDB.fallback_font,Iso.dir(zone.point),"校射 +%d%% · %.1fs"%[roundi(float(zone.damage)*100),zone.left],HORIZONTAL_ALIGNMENT_CENTER,-1,12,Color.CYAN)
