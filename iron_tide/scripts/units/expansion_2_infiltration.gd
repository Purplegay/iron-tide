extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Ordinary commando cards; hero talent state stays in its own modules.
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"
const SHORE:="ps_shore_reserve"
const ESCORT:="ps_evacuation_escort"

static func equipped(unit,id:String) -> bool:
	return unit is Unit and unit.passive.get("id")==id and unit.unit_id in (["GHOST"] if id==SHORE else ["GHOST","TANY","BORIS"]) and R.active(unit)

static func eligible(unit) -> bool:
	return equipped(unit,SHORE) or equipped(unit,ESCORT)

static func state(unit) -> Dictionary:
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func hidden(unit) -> bool:
	return equipped(unit,SHORE) and unit.embarked_in==null and unit.special.get(KEY,{}).get("side",unit.side)==unit.side and float(unit.special.get(KEY,{}).get("shore_cloak",0))>0

static func attacking(unit) -> void:
	if not unit.special.has(KEY):return
	if unit.special[KEY].erase("shore_cloak"):unit.queue_redraw()

static func stowed(unit) -> void:
	attacking(unit)
	var s:Dictionary=unit.special.get(KEY,{})
	s.erase("shore_ready");s.erase("shore_water");s.erase("shore_age");s.erase("shore_position")

static func escort_speed(unit) -> float:
	var amount:=0.0
	for row:Dictionary in unit.special.get(KEY,{}).get("escort_buffs",[]):
		if row.left>0 and row.side==unit.side:amount=maxf(amount,float(row.speed))
	return amount

static func speed(unit) -> float:
	var s:Dictionary=unit.special.get(KEY,{})
	return (P.number("mechanic/infiltration_v2","shore_speed") if float(s.get("shore_speed",0))>0 else 1.0)*(1.0+escort_speed(unit))

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	var before:=speed(unit)
	var was_hidden:=hidden(unit)
	for key in ["shore_speed","shore_cloak","escort_cd"]:R.timer(s,key,dt)
	var rows:Array=s.get("escort_buffs",[])
	for row:Dictionary in rows.duplicate():
		row.left-=dt
		if row.left<=.000001 or row.side!=unit.side:rows.erase(row)
	if rows.is_empty():s.erase("escort_buffs")
	if equipped(unit,SHORE):
		var world=R.world(unit)
		var water:bool=world!=null and world.in_water_world(unit.position)
		var previous:Vector2=s.get("shore_position",unit.position)
		var was_water:bool=s.get("shore_water",water)
		var available:bool=unit.embarked_in==null and unit._stun_timer<=0 and not AlliedAbilities.frozen(unit)
		if unit.embarked_in!=null:stowed(unit)
		elif was_hidden:
			s.shore_age=0.0;s.erase("shore_ready")
		elif water and was_water and available:
			if previous.distance_squared_to(unit.position)>.0001:
				s.shore_age=minf(P.number("mechanic/infiltration_v2","shore_prepare"),float(s.get("shore_age",0))+dt)
				if s.shore_age>=P.number("mechanic/infiltration_v2","shore_prepare")-.000001:s.shore_ready=true
			elif not s.get("shore_ready",false):s.shore_age=0.0
		elif not water:
			if was_water and s.get("shore_ready",false):
				s.shore_speed=R.value(unit,SHORE,"speed_time");s.shore_cloak=R.value(unit,SHORE,"cloak")
			s.erase("shore_ready")
			s.shore_age=0.0
		else:s.shore_age=0.0
		s.shore_water=water;s.shore_position=unit.position
	if not is_equal_approx(before,speed(unit)):unit._recompute_bonuses()
	if was_hidden or hidden(unit) or before!=1.0 or speed(unit)!=1.0:unit.queue_redraw()

static func recipient(unit,other) -> bool:
	return other!=unit and other is Unit and R.active(other) and AlliedAbilities.infantry(other) and not other.is_air_target() and other.embarked_in==null and unit.side==other.side and str(other.special.get("academy_hero","")).is_empty() and other.unit_id not in ["TANY","BORIS"]

static func damaged(unit,amount:float) -> void:
	if amount<=0 or not equipped(unit,ESCORT) or unit.embarked_in!=null:return
	var threshold:float=unit.max_hp*P.number("mechanic/infiltration_v2","threshold")
	# This callback sees final health damage immediately before subtraction, including hero death prevention.
	if unit.hp<threshold or unit.hp-amount>=threshold or unit.hp-amount<=0:return
	var s:=state(unit)
	if s.has("escort_cd"):return
	var world=R.world(unit)
	if world==null:return
	var targets:Array=[]
	for other in world.neighborhood.nearby(unit.position,P.number("mechanic/infiltration_v2","radius")*R.CELL,true):
		if recipient(unit,other) and unit.position.distance_to(other.position)<=P.number("mechanic/infiltration_v2","radius")*R.CELL:targets.append(other)
	targets.sort_custom(func(a,b):return unit.position.distance_squared_to(a.position)<unit.position.distance_squared_to(b.position))
	s.escort_cd=P.number("mechanic/infiltration_v2","cooldown")
	for i in mini(P.count("mechanic/infiltration_v2","targets"),targets.size()):
		var other=targets[i]
		state(other).get_or_add("escort_buffs",[]).append({"side":other.side,"speed":R.value(unit,ESCORT,"speed"),"left":P.number("mechanic/infiltration_v2","duration")})
		other._recompute_bonuses();other.queue_redraw()
	unit.queue_redraw()

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	for row in [["shore_speed","潜行余量 · 移速+20%","speed"],["shore_cloak","潜行余量 · 隐身","smoke"],["escort_cd","撤离护送冷却","reload"]]:
		if s.has(row[0]):out.append(V.row(row[1],s[row[0]],false,row[2]))
	if s.get("shore_ready",false):out.append(V.row("潜行余量 · 上岸准备完成",0,false,"smoke"))
	elif float(s.get("shore_age",0))>0:out.append(V.row("潜行余量 · 水中实际移动",P.number("mechanic/infiltration_v2","shore_prepare")-float(s.shore_age),false,"speed"))
	if escort_speed(unit)>0:
		var left:=0.0
		for row:Dictionary in s.get("escort_buffs",[]):
			if is_equal_approx(float(row.speed),escort_speed(unit)):left=maxf(left,float(row.left))
		out.append(V.row("撤离护送 · 移速+%d%%"%roundi(escort_speed(unit)*100),left,false,"speed"))
	return out

static func draw(unit) -> void:
	if speed(unit)>1:unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+4,0,TAU,24,Color(.3,.95,.8,.7),1.5,true)
