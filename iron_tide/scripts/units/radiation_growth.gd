extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Extension talent. Native radiation strength, cadence and decay are unchanged.
const ID := "deso_expansion"
const CLOCK := "rad_growth_clock"
const STACKS := "rad_growth_stacks"
static var LIMIT:int:
	get:return P.count("mechanic/deso_expansion","stack_cap")

static func rule(unit) -> Dictionary:
	var definition:Dictionary=MetaProgress.talent_options("DESO")[ID]
	var rank:=MetaProgress.talent_rank("DESO",ID,BattleRequest.combat_context.get("unit_talents",{}))
	return {"interval":definition.intervals[rank],"total":definition.base if rank==0 else definition.ranks[rank-1].value}

static func bonus(unit) -> float:
	return float(rule(unit).total)*Ra2Damage.PX_PER_CELL*int(unit.special.get(STACKS,0))/LIMIT

static func register(site:Dictionary,unit,base_radius:float) -> void:
	if not is_instance_valid(unit) or unit.unit_id!="DESO" or not Unit.YRTalents.enabled(unit,ID):return
	site.get_or_add("expanders",{})[unit]={"origin":unit.position,"base":base_radius,"radius":base_radius+bonus(unit)}
	refresh(site)

static func refresh(site:Dictionary) -> void:
	if not site.has("expanders"):return
	var radius:float=site.get("base_radius",site.radius)
	for unit in site.expanders.keys():
		var row:Dictionary=site.expanders[unit]
		if not AlliedAbilities.alive(unit) or not unit._deployed or unit.side!=site.side or unit.position.distance_squared_to(row.origin)>1:
			site.expanders.erase(unit)
			continue
		radius=maxf(radius,row.radius)
	site.radius=radius
	if site.expanders.is_empty():site.erase("expanders")

static func tick(unit,delta:float) -> void:
	if not Unit.YRTalents.enabled(unit,ID):return
	var interval:float=rule(unit).interval
	var previous:int=unit.special.get(STACKS,0)
	if previous>=LIMIT:return
	var elapsed:=minf(float(unit.special.get(CLOCK,0))+delta,interval*LIMIT)
	unit.special[CLOCK]=elapsed
	var stacks:=mini(LIMIT,floori((elapsed+0.000001)/interval))
	unit.special[STACKS]=stacks
	if stacks==previous:return
	unit.queue_redraw()
	var world=unit._battle_world()
	if world==null:return
	for site in world.allied_state.get("rad_sites",[]):
		if site.get("expanders",{}).has(unit):
			var row:Dictionary=site.expanders[unit]
			row.radius=float(row.base)+bonus(unit)
			refresh(site)
	unit.SovietSpecials.sync_radiation(world)

static func clear(unit) -> void:
	unit.special.erase(CLOCK)
	unit.special.erase(STACKS)
	unit.queue_redraw()
	var world=unit._battle_world()
	if world==null:return
	for site in world.allied_state.get("rad_sites",[]):
		if site.get("expanders",{}).has(unit):
			site.expanders.erase(unit)
			refresh(site)
	unit.SovietSpecials.sync_radiation(world)
