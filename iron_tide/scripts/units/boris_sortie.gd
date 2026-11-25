extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY="commando_hero_v2"

static func rank(unit) -> int:
	if not is_instance_valid(unit) or not unit is Unit or unit.special.get("academy_hero")!="BORIS" or not unit.special.has(KEY) or not R.active(unit):return -1
	return clampi(int(unit.special.get("hero_command_rank",0)),0,5)

static func independent(unit) -> bool:
	return rank(unit)>=3

static func occupied(unit) -> bool:
	# The wing key stays until the native reload transition, even if its final jet just died.
	return unit.special.has("airstrike_wing")

static func legal(unit,target,visible:=false) -> bool:
	if not is_instance_valid(target) or not target is Building or not R.enemy(unit,target):return false
	if target.special.get("expedition_protected",false) or target.special.has("iron_left") or float(target.special.get("force_shield_left",0))>0:return false
	if AlliedAbilities.alive(target.special.get("temporal_by")) or target.ignores_warhead("") or (target.side=="ally" and GM.god_mode):return false
	return not visible or R.world(unit).actor_visible_to(unit.side,target)

static func secondary(unit,primary,center:Vector2):
	var best=null
	var distance:=P.number("hero/BORIS/command","secondary_radius")*R.CELL
	for candidate in R.world(unit).buildings:
		if is_same(candidate,primary) or not legal(unit,candidate,true):continue
		var gap:float=center.distance_to(candidate.position)
		if gap<=distance and (best==null or gap<distance):best=candidate;distance=gap
	return best

static func targets(unit,primary,count:int) -> Array:
	var result:Array=[]
	for i in count:result.append(primary)
	if rank(unit)<5:return result
	var other=secondary(unit,primary,primary.position)
	if other!=null:
		for i in floori(count*P.number("hero/BORIS/command","extra_planes_ratio")):result.append(other)
	return result

static func configure(unit,primary,jets:Array) -> void:
	if not independent(unit):return
	for jet in jets:
		var run:Dictionary=jet.special.strike_run
		run.boris_independent=true
		run.boris_primary=primary
		run.boris_center=primary.position
		run.boris_secondary=not is_same(run.target,primary)

static func update_target(jet) -> void:
	var run:Dictionary=jet.special.strike_run
	if run.outbound or not run.get("boris_independent",false):return
	var unit=run.spotter
	if not AlliedAbilities.alive(unit) or unit.side!=jet.side or R.world(jet).house_defeated(jet.side):run.outbound=true;return
	if legal(unit,run.target):return
	if not run.boris_secondary:run.outbound=true;return
	var next=secondary(unit,run.get("boris_primary"),run.boris_center)
	# Retarget the secondary group together; never increase the main building's allocation.
	for member in run.get("wing",[jet]):
		if not AlliedAbilities.alive(member):continue
		var other:Dictionary=member.special.strike_run
		if other.outbound or not other.get("boris_secondary",false):continue
		if next==null:other.outbound=true
		else:other.target=next

static func mark_locked(unit,target,mark:Dictionary) -> bool:
	return AlliedAbilities.alive(unit) and unit.side==mark.get("boris_side",unit.side) and legal(unit,target)
