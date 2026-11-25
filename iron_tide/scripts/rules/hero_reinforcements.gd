extends RefCounted
## Only the paid production completion entry calls produced; direct spawns never count.
const KEY="hero_reinforcements"
const P=preload("res://scripts/units/peregrine.gd")

static func produced(world,factory,unit) -> void:
	if not BattleRequest.extensions_enabled() or world.gm_unit_lab or not BattleRequest.combat_context.get("expedition",{}).is_empty():return
	if not AlliedAbilities.alive(unit) or not is_instance_valid(factory) or factory.battle!=world or factory.side!=unit.side or not world.buildings.has(factory):return
	if unit.unit_id=="HARV" and not unit.special.has("convoy_paid_product"):
		unit.special.convoy_paid_product=true
		if MetaProgress.Academy.reinforcement_unlocked("HARV",unit.side):preload("res://scripts/units/convoy_heroes.gd").promote(unit,world,MetaProgress)
	preload("res://scripts/rules/leizhu_reinforcements.gd").produced(world,factory,unit)
	if not P.eligible_owner(world,unit.side):return
	if unit.special.has("hero_production_counted") or not MetaProgress.Academy.aircraft_product(unit):return
	unit.special.hero_production_counted=true
	if not MetaProgress.Academy.reinforcement_unlocked("ORCA",unit.side):return
	var houses:Dictionary=world.allied_state.get_or_add(KEY,{})
	if houses.has(unit.side):return
	houses[unit.side]={"origin":unit.position,"pending":true,"retry":0.0}
	tick(world,0)

static func point(world,origin:Vector2) -> Vector2:
	for ring in [55.0,85.0,115.0]:
		for i in 12:
			var p:Vector2=origin+Vector2.from_angle(TAU*i/12)*ring
			if p.x<30 or p.y<30 or p.x>=world.map_size-30 or p.y>=world.map_size-30:continue
			var clear:=true
			for unit in world.units:
				if AlliedAbilities.alive(unit) and unit.is_air and unit.position.distance_to(p)<unit.radius+22:clear=false;break
			if clear:return p
	return Vector2.INF

static func tick(world,dt:float) -> void:
	if not BattleRequest.extensions_enabled():return
	for side:String in world.allied_state.get(KEY,{}):
		var row:Dictionary=world.allied_state[KEY][side]
		if not row.pending:continue
		if not P.eligible_owner(world,side):row.pending=false;continue
		if not MetaProgress.Academy.reinforcement_unlocked("ORCA",side):row.pending=false;continue
		if world.house_defeated(side):row.pending=false;continue
		row.retry=maxf(0,float(row.retry)-dt)
		if row.retry>0:continue
		row.retry=.25
		var at:=point(world,row.origin)
		if not at.is_finite():continue
		var hero=world.spawn_unit("ORCA",side,at)
		if hero==null:continue
		P.promote(MetaProgress,world,hero)
		row.pending=false
		hero.order_stop()
