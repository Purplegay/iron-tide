extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY="leizhu"
const GROUP="leizhu_detectors"

static func eligible(world,unit) -> bool:
	if not is_instance_valid(unit) or not unit is Unit or not world.is_ancestor_of(unit) or not R.active(unit):return false
	if unit.special.get("academy_hero")!="TTNK" or int(unit.special.get("hero_command_rank",0))<5 or not unit.special.has(KEY):return false
	if unit.embarked_in!=null or unit._stun_timer>0 or AlliedAbilities.frozen(unit) or float(unit.special[KEY].get("shutdown_left",0))>0 or world.house_defeated(unit.side):return false
	for building in world.buildings:
		if not AlliedAbilities.alive(building) or building.side!=unit.side or building.under_construction:continue
		if building.building_id not in ["GACNST","NACNST",world.roster_id("GACNST",unit.side)]:continue
		if unit.position.distance_to(building.position)<=P.number("hero/TTNK/command","power_radius")*R.CELL:return true
	return false

static func amount(world,side:String,produced:float,drain:float) -> float:
	if produced>=drain-.001 or not BattleRequest.extensions_enabled():return 0
	var output:=0.0
	for unit in world.get_tree().get_nodes_in_group(GROUP):
		if unit.side==side and eligible(world,unit):output+=P.count("hero/TTNK/command","power_output")
	return output

static func update(world,grids:Dictionary) -> void:
	var totals:Dictionary={}
	for unit in world.get_tree().get_nodes_in_group(GROUP):
		if not world.is_ancestor_of(unit) or not unit.special.has(KEY):continue
		var previous:bool=unit.special[KEY].get("power_active",false)
		var grid:Dictionary=grids.get(unit.side,{})
		var on:bool=not grid.is_empty() and float(grid.produced)<float(grid.drain)-.001 and eligible(world,unit)
		unit.special[KEY].power_active=on
		if previous!=on:unit.queue_redraw()
		if on:totals[unit.side]=float(totals.get(unit.side,0))+P.count("hero/TTNK/command","power_output")
	# All decisions use building-only power, before any hero contribution is added.
	for side in totals:grids[side].produced+=totals[side]
	if totals.is_empty():world.allied_state.erase("leizhu_power")
	else:world.allied_state.leizhu_power=totals

static func blocked(world,origin:Vector2,end:Vector2,unit,target) -> bool:
	var steps:=maxi(1,ceili(origin.distance_to(end)/8.0))
	for i in range(1,steps+1):
		var p:=origin.lerp(end,float(i)/steps)
		if world.in_water_world(p) or world.path_service.is_blocked(p):return true
	var ray:=PhysicsRayQueryParameters2D.create(origin,end,1,[unit.get_rid(),target.get_rid()])
	return not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

static func prepare(unit,target,bonus:Dictionary) -> void:
	if int(unit.special.get("hero_command_rank",0))<4 or not R.enemy(unit,target):return
	var state:Dictionary=unit.special[KEY]
	if float(state.get("quiet",0))<P.number("hero/TTNK/command","pierce_quiet")-.000001 or float(state.get("pierce_cd",0))>0:return
	if target is Unit and (target.is_air_target() or target.is_naval or target.embarked_in!=null):return
	var weapon:Dictionary=unit._weapon_for_target(null).duplicate(true);weapon.damage=float(weapon.get("damage",0))*P.number("hero/TTNK/command","pierce_damage")
	var extra:Dictionary=unit.bonuses.duplicate(true);extra.expansion_extra=true;extra.leizhu_pierce=true;extra.reference_weapon=weapon.duplicate(true)
	bonus.leizhu_penetration={"origin":unit.position,"end":R.point(unit,target),"main":target,"side":unit.side,"weapon":weapon,"bonus":extra}
	state.pierce_cd=P.number("hero/TTNK/command","pierce_cooldown")

static func finish(unit,bonus:Dictionary) -> void:
	if not bonus.has("leizhu_penetration"):return
	var event:Dictionary=bonus.leizhu_penetration;bonus.erase("leizhu_penetration")
	if not is_instance_valid(unit) or not R.active(unit) or unit.side!=event.side or not unit.special.has(KEY):return
	var world=R.world(unit);var choices:Array=[]
	for target in world.units:
		if is_same(target,event.main) or not R.enemy(unit,target) or R.temporary(target) or target.is_air_target() or target.is_naval or target.embarked_in!=null:continue
		if not world.actor_visible_to(unit.side,target) or AlliedAbilities.concealed(target,unit.side):continue
		var nearest:=Geometry2D.get_closest_point_to_segment(target.position,event.origin,event.end)
		if nearest.distance_to(target.position)>target.radius:continue
		var axis:Vector2=event.end-event.origin
		var projection:float=(target.position-event.origin).dot(axis)/maxf(.001,axis.length_squared())
		if projection<=0 or projection>=1 or blocked(world,event.origin,nearest,unit,target):continue
		choices.append(target)
	choices.sort_custom(func(a,b):return a.position.distance_squared_to(event.origin)<b.position.distance_squared_to(event.origin))
	var hit_points:Array=[]
	for target in choices.slice(0,P.count("hero/TTNK/command","pierce_targets")):
		preload("res://scripts/units/leizhu_cards.gd").damage(unit,target,event.weapon,event.bonus)
		hit_points.append(target.position)
	unit.special[KEY].pierce_flash={"origin":event.origin,"points":hit_points,"left":.3}
	unit.queue_redraw()
