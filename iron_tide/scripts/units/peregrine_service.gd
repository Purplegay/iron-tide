extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const D=preload("res://scripts/units/peregrine_defense.gd")
const KEY="peregrine"
static var REPAIR_SECONDS:float:
	get:return P.number("hero/ORCA/survival","repair_seconds")

static func busy(unit) -> bool:
	return unit.special.has("hero_wreck") or unit.special.get(KEY,{}).has("maintenance")

static func ground_clear(unit,point:Vector2) -> bool:
	var world=R.world(unit)
	if world==null or not unit.logistics.landing_clear(world,point,unit.radius):return false
	for other in world.units:
		if other==unit or not AlliedAbilities.alive(other) or other.embarked_in!=null or other.is_air_target():continue
		if point.distance_to(other.position)<unit.radius+other.radius+3:return false
	return true

static func airport_valid(unit,airport) -> bool:
	return AlliedAbilities.alive(airport) and airport is Building and airport.side==unit.side and airport.building_id in ["GAAIRC","AMRADR"] and not airport.under_construction and airport.is_operational() and not R.world(unit).side_power_low(unit.side) and unit.position.distance_to(airport.closest_footprint_point(unit.position))<=P.number("hero/ORCA/survival","airport_radius")*R.CELL

static func airport_near(unit):
	var world=R.world(unit)
	if world==null:return null
	for airport in world.buildings:
		if airport_valid(unit,airport):return airport
	return null

static func toggle_ready(unit) -> bool:
	return D.rank(unit)>=4 and not unit.special.has("hero_wreck") and unit._stun_timer<=0 and not AlliedAbilities.frozen(unit) and unit.embarked_in==null and (unit.special[KEY].has("maintenance") or airport_near(unit)!=null and ground_clear(unit,unit.position))

static func toggle(unit) -> bool:
	if not toggle_ready(unit):return false
	if unit.special[KEY].has("maintenance"):
		leave(unit);return true
	unit.order_stop();unit.velocity=Vector2.ZERO
	unit.special[KEY].maintenance={"airport":airport_near(unit),"descent":P.number("hero/ORCA/survival","descent_seconds"),"descent_total":P.number("hero/ORCA/survival","descent_seconds"),"lift":unit.logistics.air_lift,"quiet":0.0,"side":unit.side}
	unit.queue_redraw()
	return true

static func leave(unit) -> void:
	if not unit.special.has(KEY):return
	var s:Dictionary=unit.special[KEY]
	s.erase("maintenance");s.erase("maintenance_shield")
	sync_collision(unit);unit.queue_redraw()

static func sync_collision(unit) -> void:
	if unit._dead or unit.embarked_in!=null:return
	unit.collision_layer=8 if unit.is_air_target() else 1
	unit.collision_mask=8 if unit.is_air_target() else 7

static func restore(unit) -> void:
	var s:Dictionary=unit.special[KEY]
	if unit.special.has("hero_wreck"):
		var wreck:Dictionary=unit.special.hero_wreck
		unit.logistics.air_lift=float(wreck.lift)*(float(wreck.descent)/float(wreck.get("descent_total",1))) if float(wreck.get("descent",0))>0 else 0.0
		unit.velocity=Vector2.ZERO
	elif s.has("maintenance"):
		unit.logistics.air_lift=float(s.maintenance.lift)*(float(s.maintenance.descent)/float(s.maintenance.get("descent_total",1)))
		unit.velocity=Vector2.ZERO
	sync_collision(unit)

static func tick(unit,dt:float) -> bool:
	if not AlliedAbilities.alive(unit):return true
	var s:Dictionary=unit.special[KEY]
	var prior_cd:float=s.get("maintenance_cd",0)
	R.timer(s,"maintenance_cd",dt)
	if unit.special.has("hero_wreck"):
		wreck_tick(unit,maxf(0,dt));return true
	if not s.has("maintenance"):sync_collision(unit);return false
	var m:Dictionary=s.maintenance
	if not airport_valid(unit,m.airport) or m.side!=unit.side or not ground_clear(unit,unit.position):leave(unit);return false
	unit.velocity=Vector2.ZERO
	if unit._stun_timer>0 or AlliedAbilities.frozen(unit):
		tick_shield(s,maxf(0,dt));return false
	var remaining:=maxf(0,dt)
	if float(m.descent)>0:
		var step:=minf(remaining,float(m.descent));m.descent-=step;remaining-=step
		unit.logistics.air_lift=float(m.lift)*float(m.descent)/float(m.get("descent_total",1))
		if m.descent<=0.000001:
			m.descent=0.0;unit.logistics.air_lift=0.0
			if prior_cd<=step+0.000001:
				s.maintenance_shield={"hp":unit.max_hp*P.number("hero/ORCA/survival","maintenance_shield"),"left":P.number("hero/ORCA/survival","maintenance_duration")};s.maintenance_cd=maxf(0,P.number("hero/ORCA/survival","maintenance_cooldown")-remaining)
				if s.maintenance_cd<=0:s.erase("maintenance_cd")
	if m.descent==0:
		var old_quiet:float=m.quiet;m.quiet+=remaining
		var heal_time:=maxf(0,float(m.quiet)-P.number("hero/ORCA/survival","maintenance_quiet"))-maxf(0,old_quiet-P.number("hero/ORCA/survival","maintenance_quiet"))
		if heal_time>0:unit.heal(unit.max_hp*P.number("hero/ORCA/survival","maintenance_heal")*heal_time)
	tick_shield(s,remaining)
	sync_collision(unit);unit.queue_redraw()
	return false

static func tick_shield(s:Dictionary,dt:float) -> void:
	if s.has("maintenance_shield"):
		s.maintenance_shield.left-=dt
		if s.maintenance_shield.left<=0:s.erase("maintenance_shield")

static func damaged(unit,source,amount:float) -> void:
	if amount<=0 or not unit.special[KEY].has("maintenance"):return
	var attacker=R.owner(source)
	if R.enemy(unit,attacker):unit.special[KEY].maintenance.quiet=0.0

static func absorb(unit,amount:float) -> float:
	var s:Dictionary=unit.special[KEY]
	if amount<=0 or not s.has("maintenance_shield"):return amount
	var used:=minf(amount,float(s.maintenance_shield.hp));s.maintenance_shield.hp-=used
	if s.maintenance_shield.hp<=0:s.erase("maintenance_shield")
	return amount-used

static func nearest_ground(unit,origin:Vector2=Vector2.INF) -> Vector2:
	if not origin.is_finite():origin=unit.position
	if ground_clear(unit,origin):return origin
	for ring in 8:
		var radius:float=(ring+1)*R.CELL*P.number("hero/ORCA/survival","landing_radius")/8.0
		for i in 32:
			var point:Vector2=origin+Vector2.from_angle(TAU*i/32)*radius
			if ground_clear(unit,point):return point
	return Vector2.INF

static func before_damage(unit,amount:float,kind:String,bonus:Dictionary,source) -> float:
	if kind in ["crush","erase","execute"] or bonus.get("force_execute",false):return amount
	if amount<unit.hp or amount<=0 or D.rank(unit)<5 or unit.special.has("hero_wreck") or Unit.TankHero.revival_used(unit) or unit.special.get("house_eliminated",false):return amount
	var point:=nearest_ground(unit)
	if not point.is_finite():return amount
	unit.order_stop();leave(unit);Unit.TankHero.mark_revival_used(unit)
	var s:Dictionary=unit.special[KEY]
	for field in ["rearm_shield","empty_speed","steady_left","decoy_flash"]:s.erase(field)
	s.progress=0.0;s.hits=false;s.normal_hit=false
	unit.logistics.ammo=0
	unit.special.hero_wreck={"left":P.number("hero/ORCA/survival","repair_seconds"),"descent":P.number("hero/ORCA/survival","descent_seconds"),"descent_total":P.number("hero/ORCA/survival","descent_seconds"),"lift":unit.logistics.air_lift,"origin":unit.position,"point":point,"health":unit.max_hp,"name":unit.display_name,"side":unit.side,"repair_elapsed":0.0,"killer":source}
	unit.max_hp=float(unit.special.hero_wreck.health)*P.number("hero/ORCA/survival","wreck_health")
	unit.hp=unit.max_hp
	unit.velocity=Vector2.ZERO;unit.queue_redraw()
	return 0.0

static func engineer_allowed(engineer,unit) -> bool:
	return AlliedAbilities.alive(engineer) and AlliedAbilities.alive(unit) and unit is Unit and unit.special.has(KEY) and unit.special.has("hero_wreck") and float(unit.special.hero_wreck.get("descent",0))<=0 and engineer.unit_id in ["ENGINEER","SENGINEER"] and engineer.side==unit.side and engineer.embarked_in==null and engineer._stun_timer<=0 and not AlliedAbilities.frozen(engineer)

static func engineer_in_range(engineer,unit) -> bool:
	if not engineer_allowed(engineer,unit) or engineer.special.get("action")!="allied_engineer" or engineer.special.get("target")!=unit:return false
	return engineer.position.distance_to(unit.position)<=engineer.radius+unit.radius+24 and R.world(unit).path_service.line_walkable(engineer.position,AlliedAbilities.approach(engineer,unit),R.world(unit).path_service.cost)

static func engineer_tick(engineer,unit,dt:float) -> bool:
	var wreck:Dictionary=unit.special.hero_wreck
	if not engineer_in_range(engineer,unit):
		if wreck.get("engineer")==engineer:wreck.erase("engineer");wreck.repair_elapsed=0.0
		engineer._go_to(AlliedAbilities.approach(engineer,unit),dt,4.0);engineer._face_if_moving();engineer._move_water_safe();return true
	engineer.velocity=Vector2.ZERO;engineer.has_move_order=false
	var current=wreck.get("engineer")
	if is_instance_valid(current) and current!=engineer and engineer_in_range(current,unit):return true
	if current!=engineer:wreck.repair_elapsed=0.0
	wreck.engineer=engineer;wreck.repair_elapsed+=maxf(0,dt)
	if wreck.repair_elapsed>=P.number("hero/ORCA/survival","engineer_seconds")-0.000001:
		recover(unit);AlliedAbilities.cancel(engineer)
	unit.queue_redraw()
	return true

static func wreck_tick(unit,dt:float) -> void:
	if not AlliedAbilities.alive(unit):return
	var wreck:Dictionary=unit.special.hero_wreck
	unit.velocity=Vector2.ZERO
	if unit.special.get("house_eliminated",false) or R.world(unit).house_defeated(unit.side):unit._die(null,true);return
	var remaining:=dt
	if float(wreck.descent)>0:
		var retry:float=maxf(0,float(wreck.get("landing_retry",0))-dt)
		wreck.landing_retry=retry
		if retry>0:return
		if remaining>=float(wreck.descent) and not ground_clear(unit,wreck.point):
			var origin:Vector2=wreck.get_or_add("landing_origin",wreck.origin)
			var point:=nearest_ground(unit,origin)
			if not point.is_finite():
				wreck.landing_retry=.25
				return
			wreck.origin=unit.position;wreck.point=point;wreck.lift=unit.logistics.air_lift
			wreck.descent=maxf(.25,float(wreck.descent));wreck.descent_total=wreck.descent
		var step:=minf(remaining,float(wreck.descent));wreck.descent-=step;remaining-=step
		unit.position=Vector2(wreck.origin).lerp(wreck.point,1-float(wreck.descent)/float(wreck.get("descent_total",1)))
		unit.logistics.air_lift=float(wreck.lift)*float(wreck.descent)/float(wreck.get("descent_total",1))
		if wreck.descent<=0.000001:
			wreck.descent=0.0;unit.logistics.air_lift=0.0
			unit.display_name=String(wreck.name)+" · 迫降机体"
	if float(wreck.descent)<=0:
		var engineer=wreck.get("engineer")
		if not is_instance_valid(engineer) or not engineer_in_range(engineer,unit):wreck.erase("engineer");wreck.repair_elapsed=0.0
		wreck.left=maxf(0,float(wreck.left)-remaining)
		if wreck.left<=0.000001:recover(unit);return
	sync_collision(unit);unit.queue_redraw()

static func recover(unit) -> void:
	if not AlliedAbilities.alive(unit) or not unit.special.has("hero_wreck"):return
	var wreck:Dictionary=unit.special.hero_wreck
	unit.max_hp=wreck.health;unit.hp=unit.max_hp;unit.display_name=wreck.name
	unit.special.erase("hero_wreck")
	var s:Dictionary=unit.special[KEY]
	s.erase("rearm_shield");s.erase("maintenance_shield");s.progress=0.0;s.hits=false;s.normal_hit=false
	unit.logistics.ammo=0;unit.logistics.air_lift=0
	unit.order_stop();unit._recompute_bonuses();unit._refresh_weapon_derived();sync_collision(unit)
	unit.queue_redraw()

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special[KEY];var rows:Array=[]
	if s.has("maintenance"):
		var m:Dictionary=s.maintenance
		rows.append(V.row("停机维护 · "+("下降中" if m.descent>0 else "待脱战" if m.quiet<3 else "每秒回复 2%"),float(m.descent) if m.descent>0 else maxf(0,3-float(m.quiet)),false,"heart"))
	if s.has("maintenance_shield"):
		var row:=V.row("停机护罩",s.maintenance_shield.left,false,"guard");row.text="维护盾 %.0f"%s.maintenance_shield.hp;rows.append(row)
	if s.has("maintenance_cd"):rows.append(V.row("停机护罩触发间隔",s.maintenance_cd,false,"guard"))
	if unit.special.has("hero_wreck"):
		var w:Dictionary=unit.special.hero_wreck
		rows.append(V.row("迫降返修 · "+("下降中，可受伤" if w.descent>0 else "机体耐久 1000%% · 工程师 %.1f/5 秒"%float(w.repair_elapsed)),float(w.descent) if w.descent>0 else float(w.left),false,"heart"))
	elif D.rank(unit)>=5:rows.append(V.row("迫降返修 · "+("本局已用" if Unit.TankHero.revival_used(unit) else "本局可用一次"),0,false,"heart"))
	return rows
