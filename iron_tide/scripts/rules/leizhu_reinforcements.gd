extends RefCounted
const L=preload("res://scripts/units/leizhu.gd")
const KEY="leizhu_reinforcements"

static func produced(world,factory,unit) -> void:
	if unit.unit_id!="TTNK" or L.R.temporary(unit) or unit.special.has("leizhu_production_counted"):return
	unit.special.leizhu_production_counted=true
	if not MetaProgress.Academy.reinforcement_unlocked("TTNK",unit.side):return
	var row:Dictionary=world.allied_state.get_or_add(KEY,{}).get_or_add(unit.side,{"count":0,"pending":false,"retry":0.0})
	row.count+=1
	if row.count!=3:return
	row.pending=true;row.factory=factory;row.origin=unit.position
	tick(world,0)

static func tick(world,dt:float) -> void:
	if not BattleRequest.extensions_enabled():return
	for side:String in world.allied_state.get(KEY,{}):
		var row:Dictionary=world.allied_state[KEY][side]
		if not row.pending:continue
		if not MetaProgress.Academy.reinforcement_unlocked("TTNK",side):row.pending=false;continue
		if world.house_defeated(side) or world.allied_state.get("leizhu_deployed",{}).has(side):row.pending=false;continue
		row.retry=maxf(0,float(row.retry)-dt)
		if row.retry>0:continue
		row.retry=.25
		var factory=row.get("factory")
		var at:Vector2=factory._spawn_point("TTNK") if AlliedAbilities.alive(factory) and factory.side==side else Vector2.INF
		if not clear(world,at):at=point(world,row.origin)
		if not at.is_finite():continue
		var hero=world.spawn_unit("TTNK",side,at)
		if hero==null:continue
		L.promote(MetaProgress,world,hero);row.pending=false;hero.order_stop()

static func point(world,origin:Vector2) -> Vector2:
	for ring in range(1,9):
		for i in 16:
			var at:Vector2=origin+Vector2.from_angle(TAU*i/16)*ring*28
			if clear(world,at):return at
	return Vector2.INF

static func clear(world,at:Vector2) -> bool:
	if not at.is_finite():return false
	var radius:float=GameData.get_unit("TTNK").get("radius",12)
	for i in 9:
		var sample:Vector2=at if i==0 else at+Vector2.from_angle(TAU*(i-1)/8)*radius
		if sample.x<0 or sample.y<0 or sample.x>=world.map_size or sample.y>=world.map_size or world.path_service.is_blocked(sample) or world.in_water_world(sample):return false
	for other in world.units:
		if AlliedAbilities.alive(other) and other.embarked_in==null and not other.is_air_target() and at.distance_to(other.position)<radius+other.radius+3:return false
	return true
