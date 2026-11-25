extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"
const CARD:="ps_convoy_repair"

static func eligible(unit) -> bool:
	return unit.unit_id in ["MTNK","HTNK","FV","HTK"] and R.active(unit) and unit.passive.get("id")==CARD

static func vehicle(unit) -> bool:
	return unit is Unit and AlliedAbilities.alive(unit) and not R.temporary(unit) and not unit.is_air and not unit.is_air_target() and not unit.is_naval and not unit.is_harvester and not AlliedAbilities.infantry(unit) and unit.embarked_in==null and not unit._active_weapon().is_empty()

static func companion(unit,s:Dictionary) -> bool:
	var world=R.world(unit)
	if world==null:return false
	var previous:Dictionary={}
	for row:Dictionary in s.get("convoy_peers",[]):
		if is_instance_valid(row.unit):previous[row.unit]=row.point
	var samples:Array=[];var moving:=false
	for other in world.neighborhood.nearby(unit.position,P.number("mechanic/ps_convoy_repair","radius")*R.CELL,true):
		if other==unit or not vehicle(other) or unit.side!=other.side or unit.position.distance_to(other.position)>P.number("mechanic/ps_convoy_repair","radius")*R.CELL:continue
		samples.append({"unit":other,"point":other.position})
		if previous.has(other) and previous[other].distance_squared_to(other.position)>.0001 and other._stun_timer<=0 and not AlliedAbilities.frozen(other):moving=true
	s.convoy_peers=samples
	return moving

static func tick(unit,dt:float) -> void:
	if not eligible(unit):return
	var s:Dictionary=unit.special.get_or_add(KEY,{"side":unit.side})
	R.timer(s,"convoy_cd",dt)
	var previous:Vector2=s.get("convoy_position",unit.position);s.convoy_position=unit.position
	var accompanied:=companion(unit,s)
	var moving:bool=unit.embarked_in==null and unit._stun_timer<=0 and not AlliedAbilities.frozen(unit) and previous.distance_squared_to(unit.position)>.0001
	if not moving or not accompanied:
		s.convoy_age=0.0
		if s.erase("convoy_left"):unit.queue_redraw()
		return
	if s.has("convoy_left"):
		var elapsed:=minf(dt,float(s.convoy_left))
		unit.hp=minf(unit.max_hp,unit.hp+unit.max_hp*R.value(unit,CARD,"heal")*elapsed)
		s.convoy_left-=elapsed
		if s.convoy_left<=.000001:s.erase("convoy_left");s.convoy_age=0.0
		unit.queue_redraw()
		return
	s.convoy_age=minf(P.number("mechanic/ps_convoy_repair","prepare"),float(s.get("convoy_age",0))+dt)
	if s.convoy_age>=P.number("mechanic/ps_convoy_repair","prepare")-.000001 and not s.has("convoy_cd"):
		s.convoy_left=P.number("mechanic/ps_convoy_repair","duration");s.convoy_cd=P.number("mechanic/ps_convoy_repair","cooldown");s.convoy_age=0.0;unit.queue_redraw()

static func damaged(unit,source,amount:float) -> void:
	if amount<=0 or not unit is Unit or not eligible(unit) or not is_instance_valid(source):return
	var side:String=source.owner_side if source is Projectile else (source.side if source is Unit or source is Building else "")
	if side.is_empty() or side=="neutral" or BattleRequest.friendly(unit.side,side):return
	var s:Dictionary=unit.special.get(KEY,{})
	s.convoy_age=0.0;s.erase("convoy_left");unit.queue_redraw()

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	if s.has("convoy_left"):out.append(V.row("伴行维修 · 自身持续回血",s.convoy_left,false,"heal"))
	elif float(s.get("convoy_age",0))>0:out.append(V.row("伴行维修 · 实际同行移动",maxf(0,P.number("mechanic/ps_convoy_repair","prepare")-float(s.convoy_age)),false,"heal"))
	if s.has("convoy_cd"):out.append(V.row("伴行维修冷却",s.convoy_cd,false,"reload"))
	return out

static func draw(unit) -> void:
	if unit.special.get(KEY,{}).has("convoy_left"):unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+6,0,TAU,24,Color(.3,1,.5,.8),1.5,true)
