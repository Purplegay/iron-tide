extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const REVERSE:="grizzly_reverse"
const BOOK:="chrono_bookmark"
const SPLIT:="rhino_split"
const GROWTH:="deso_expansion"
const CELL:=Ra2Damage.PX_PER_CELL
const Feedback=preload("res://scripts/units/ra3_reaper_heat.gd")

static func enabled(unit,id:String) -> bool:
	return BattleRequest.has_unit_talent(unit.unit_id,id,unit.side)

static func value(unit,id:String) -> float:
	var upgrade:=BattleRequest.talent_upgrade(unit.unit_id,id,unit.side)
	return float(upgrade.value) if not upgrade.is_empty() else float(MetaProgress.talent_options(unit.unit_id)[id].base)

# Use the frozen battle loadout, including the unlocked rank-zero talent.
static func cooldown_multiplier(unit) -> float:
	if unit.unit_id!="CLEG" or not enabled(unit,BOOK):return 1.0
	var rank:=MetaProgress.talent_rank(unit.unit_id,BOOK,BattleRequest.combat_context.get("unit_talents",{}))
	var reductions:Array=MetaProgress.talent_options(unit.unit_id)[BOOK].cooldown_reduction
	return 1.0-float(reductions[rank])*0.01

static func reverse_ready(unit) -> bool:
	return AlliedAbilities.alive(unit) and unit.unit_id=="MTNK" and unit.embarked_in==null and not unit.repairing and unit._stun_timer<=0 and not AlliedAbilities.frozen(unit) and enabled(unit,REVERSE)

static func reverse_end(unit,point:Vector2) -> Vector2:
	var offset:Vector2=point-unit.position
	if not point.is_finite() or offset.length()<4:return Vector2.INF
	var end:Vector2=unit.position+offset.limit_length(P.number("mechanic/yr_talents","reverse_range")*CELL)
	var world=unit._battle_world()
	if not Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).has_point(end) or not unit._domain_ok(end):return Vector2.INF
	if world.path_service!=null and not world.path_service.line_walkable(unit.position,end,world.path_service.cost):return Vector2.INF
	return end

static func start_reverse(unit,point:Vector2) -> bool:
	if not reverse_ready(unit):return false
	var end:=reverse_end(unit,point)
	if not end.is_finite():return false
	unit.clear_queue()
	unit.has_move_order=false
	unit.velocity=Vector2.ZERO
	unit.patrolling=false
	unit.special.erase("formation_heading")
	unit.special["reverse_heal_triggered"]=unit.special.has("reverse_heal_left")
	unit.special.erase("reverse_attack")
	unit.special[REVERSE]=end
	return true

static func end_reverse(unit) -> void:
	unit.special.erase(REVERSE)
	unit.special.erase("reverse_heal_triggered")

static func tick_reverse_heal(unit,dt:float) -> void:
	var left:float=unit.special.reverse_heal_left
	var elapsed:=minf(left,dt)
	if unit.hp<unit.max_hp: unit.heal(unit.max_hp*P.number("mechanic/yr_talents","reverse_heal")*elapsed,unit,true)
	left-=elapsed
	if left<=0.000001: unit.special.erase("reverse_heal_left")
	else: unit.special.reverse_heal_left=left

static func reverse_tick(unit,dt:float) -> void:
	var step:Vector2=unit.special[REVERSE]-unit.position
	if step.length()<0.01:
		end_reverse(unit);unit.velocity=Vector2.ZERO;return
	# Aim the rear at the requested route using the native hull ROT. Do not
	# translate or start the heal while the tank is still pivoting.
	var heading:=(-step).angle()
	var rate:=deg_to_rad(float(unit._mv("rot",0.0)))
	unit.hull_angle=rotate_toward(unit.hull_angle,heading,rate*maxf(0,dt)) if rate>0 else heading
	unit._drive_heading=unit.hull_angle
	if unit._weapon_target_valid(unit.attack_target):unit._face(unit.attack_target.global_position)
	else:unit.turret_angle=heading
	if absf(angle_difference(unit.hull_angle,heading))>0.001:
		unit.velocity=Vector2.ZERO
		return
	var speed:float=unit.move_speed*value(unit,REVERSE)*0.01
	var motion:=step.limit_length(speed*dt)
	var start:Vector2=unit.position
	var blocked:bool=not unit._domain_ok(start+motion)
	if not blocked: blocked=unit.move_with_traffic_exceptions(motion)!=null
	var traveled:float=start.distance_to(unit.position)
	unit.velocity=(unit.position-start)/dt if dt>0 else Vector2.ZERO
	if traveled>0.001 and not unit.special.get("reverse_heal_triggered",false):
		unit.special.reverse_heal_triggered=true
		var rank:=MetaProgress.talent_rank(unit.unit_id,REVERSE,BattleRequest.combat_context.get("unit_talents",{}))
		unit.special.reverse_heal_left=float(MetaProgress.talent_options(unit.unit_id)[REVERSE].heal_seconds[rank])
		tick_reverse_heal(unit,dt)
	if blocked or unit.position.distance_to(unit.special[REVERSE])<0.01:
		end_reverse(unit)
		unit.velocity=Vector2.ZERO
	if unit._weapon_target_valid(unit.attack_target):unit._face(unit.attack_target.global_position)

static func paint_reverse(canvas,world) -> void:
	if world.command_mode!=REVERSE:return
	var point:Vector2=world.get_global_mouse_position()
	for unit in world.selected_units:
		if not reverse_ready(unit):continue
		var end:=reverse_end(unit,point)
		var valid:=end.is_finite()
		if not valid:end=unit.position+(point-unit.position).limit_length(P.number("mechanic/yr_talents","reverse_range")*CELL)
		var color:=Color.AQUAMARINE if valid else Color.INDIAN_RED
		canvas.draw_dashed_line(unit.position,end,color,2,7)
		canvas.draw_circle(end,5,color,false,2)
		var front:Vector2=end.direction_to(unit.position)
		canvas.draw_line(end,end+front*18,color,2)
		canvas.draw_line(end+front*18,end+front.rotated(0.45)*10,color,2)
		canvas.draw_line(end+front*18,end+front.rotated(-0.45)*10,color,2)

static func remember(unit,target) -> void:
	if unit.unit_id!="CLEG" or not AlliedAbilities.alive(unit) or not enabled(unit,BOOK):return
	var work:float=unit.special.get("temporal_work",0.0)
	if work<=0 or work>=target.max_hp:return
	unit.special[BOOK]={"target":target,"left":value(unit,BOOK),"work":work*P.number("mechanic/yr_talents","bookmark_work")}

static func paint_bookmark(canvas,world,owner) -> void:
	var book:Dictionary=owner.special[BOOK]
	var target=book.target
	if not AlliedAbilities.alive(target) or not world.actor_visible_to("ally",target):return
	var p:=Iso.dir(Effects.hit_position(target))+Vector2(0,-18)
	var shape:=PackedVector2Array([p+Vector2(-6,-8),p+Vector2(6,-8),p+Vector2(-6,8),p+Vector2(6,8),p+Vector2(-6,-8)])
	canvas.draw_polyline(shape,Color("#182335"),4,true)
	canvas.draw_polyline(shape,Color.SKY_BLUE,2,true)
	canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(-4,6),p+Vector2(4,6),p+Vector2(0,2)]),Color.SKY_BLUE)

static func building_gap(a,b) -> float:
	var best:=INF
	for pair in [[a,b],[b,a]]:
		for corner:Vector2 in pair[0].footprint_poly():
			var p:Vector2=pair[0].position+corner
			best=minf(best,p.distance_to(pair[1].closest_footprint_point(p)))
	return best

static func split_hit(shot) -> void:
	var target=shot.target
	if not AlliedAbilities.alive(target) or not target is Building or target.side!="enemy":return
	var world=target.battle
	var hits:Array=[]
	for other in world.buildings:
		if other==target or not AlliedAbilities.alive(other) or other.side!=target.side:continue
		if target.position.distance_to(other.position)>target.footprint_radius()+other.footprint_radius()+P.number("mechanic/yr_talents","split_radius")*CELL:continue
		var gap:=building_gap(target,other)
		if gap<=P.number("mechanic/yr_talents","split_radius")*CELL+0.001:hits.append([gap,other])
	hits.sort_custom(func(a,b):return a[0]<b[0] if a[0]!=b[0] else a[1].get_instance_id()<b[1].get_instance_id())
	for i in mini(P.count("mechanic/yr_talents","split_targets"),hits.size()):
		var other=hits[i][1]
		if not AlliedAbilities.alive(other):continue
		var base:float=shot.base_damage*shot.splinters[SPLIT]
		var dmg:=CombatMath.with_offense(Ra2Damage.target_damage(base,shot.ra2_warhead,other,0.0),shot.attacker_bonus)
		if dmg<=0:continue
		if world.actor_visible_to("ally",other):Feedback.on_hit(world,other,true)
		other.receive_hit(dmg,shot.attack_type,shot.hit_modifiers(other),shot,shot.ra2_warhead)
