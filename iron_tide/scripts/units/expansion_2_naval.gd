extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Ship support is fixed at cast time; reload changes only newly started weapon cycles.
const R=preload("res://scripts/units/expansion_rules.gd")
const Relay=preload("res://scripts/units/water_relay.gd")
const KEY:="progression_v2"
const WATER:="ap_escort_water"
const BALLAST:="ap_gun_ballast"
const ACTIVE:=[WATER,BALLAST]
const RANGED:=["bullet","shell","missile","laser","electric","sniper","torpedo","sonic"]

static func state(unit) -> Dictionary:
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func surface(unit) -> bool:
	return AlliedAbilities.alive(unit) and unit is Unit and unit.is_naval and not unit.is_air_target() and not NavalContact.underwater_type(unit) and unit.embarked_in==null and not R.temporary(unit) and unit.logistics.capacity==0 and (not unit.weapon.is_empty() or unit.unit_id=="CARRIER")

static func ready(unit,id:String) -> bool:
	if not surface(unit):return false
	return unit.unit_id=="DEST" if id==WATER else unit.unit_id in ["DEST","HYD","AEGIS"] and not unit.special.get(KEY,{}).has("ballast_left")

static func companions(unit) -> Array:
	var rows:Array=[]
	for target in R.world(unit).units:
		if target!=unit and surface(target) and unit.side==target.side and unit.position.distance_to(target.position)<=R.value(unit,WATER,"radius")*R.CELL:rows.append(target)
	rows.sort_custom(func(a,b):
		var da:float=unit.position.distance_squared_to(a.position);var db:float=unit.position.distance_squared_to(b.position)
		if not is_equal_approx(da,db):return da<db
		if (a.hp<a.max_hp)!=(b.hp<b.max_hp):return a.hp<a.max_hp
		return a.get_instance_id()<b.get_instance_id())
	return rows.slice(0,int(R.value(unit,WATER,"targets")))

static func cast(unit,ab) -> bool:
	if ab.id==WATER:
		var targets:=companions(unit);targets.push_front(unit)
		var relay:=Relay.begin(unit,targets)
		for target in targets:
			state(target).get_or_add("water_guards",[]).append({"left":R.value(unit,WATER,"duration"),"defense":R.value(unit,WATER,"defense"),"relay":relay})
			target.queue_redraw()
	else:
		var s:=state(unit);s.ballast_left=P.number("mechanic/ap_gun_ballast","duration");s.ballast_reload=R.value(unit,BALLAST,"reload")
		unit._recompute_bonuses();unit.queue_redraw()
	ab.trigger_cooldown()
	return true

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	R.timer(s,"water_hit",dt)
	if s.has("water_guards"):
		var rows:Array=s.water_guards
		for row:Dictionary in rows.duplicate():
			row.left-=dt
			if row.left<=.000001:rows.erase(row)
		if rows.is_empty():s.erase("water_guards")
		unit.queue_redraw()
	if s.has("ballast_left"):
		s.ballast_left=maxf(0,float(s.ballast_left)-dt)
		if s.ballast_left<=.000001:
			s.erase("ballast_left");s.erase("ballast_reload");unit._recompute_bonuses()
		unit.queue_redraw()

static func attacker_side(source) -> String:
	if not is_instance_valid(source):return ""
	if source is Projectile:return source.owner_side
	return source.side if source is Unit or source is Building else ""

static func damaged(unit,source,amount:float) -> void:
	if amount<=0 or not unit is Unit or unit.unit_id!="DEST" or not R.active(unit):return
	var side:=attacker_side(source)
	if not side.is_empty() and side!="neutral" and not BattleRequest.friendly(side,unit.side):state(unit).water_hit=P.number("mechanic/ap_gun_ballast","water_combat_window")

static func guard(unit) -> float:
	return float(strongest(unit).get("defense",0))

static func strongest(unit) -> Dictionary:
	var selected:Dictionary={}
	for row:Dictionary in unit.special.get(KEY,{}).get("water_guards",[]):
		if float(row.left)>0 and float(row.defense)>float(selected.get("defense",0)):selected=row
	return selected

static func defend(unit,amount:float,kind:String,bonus:Dictionary,source,packet:Dictionary={}) -> float:
	if amount<=0 or not R.active(unit) or not unit.special.has(KEY):return amount
	var s:Dictionary=unit.special[KEY]
	if s.get("side",unit.side)!=unit.side or kind not in RANGED or bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false):return amount
	var side:=attacker_side(source)
	if side.is_empty() or side=="neutral" or BattleRequest.friendly(side,unit.side):return amount
	var selected:=strongest(unit)
	packet.merge(selected,true)
	return amount*(1.0-float(selected.get("defense",0)))*(P.number("mechanic/ap_gun_ballast","damage_taken") if s.has("ballast_left") else 1.0)

static func speed(unit) -> float:
	var s:Dictionary=unit.special.get(KEY,{})
	return P.number("mechanic/ap_gun_ballast","speed") if s.get("side",unit.side)==unit.side and s.has("ballast_left") else 1.0

static func reload_time(unit,seconds:float) -> float:
	var s:Dictionary=unit.special.get(KEY,{})
	return seconds*(1.0-float(s.get("ballast_reload",0))) if s.get("side",unit.side)==unit.side and s.has("ballast_left") and unit.unit_id in ["DEST","HYD","AEGIS"] else seconds

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	if s.has("water_guards"):
		var left:=0.0
		for row:Dictionary in s.water_guards:left=maxf(left,float(row.left))
		out.append(V.row("护航水幕 · 远程减伤 %d%%"%roundi(guard(unit)*100),left,false,"guard"))
		var pool:=Relay.pool(unit,int(strongest(unit).get("relay",-1)))
		if not pool.is_empty():
			var reserve:=V.row("余波接力 · 共享储量",pool.left,false,"guard");reserve.text="实际减免储量 %.0f / %.0f"%[pool.stored,pool.cap];out.append(reserve)
	if Relay.amount(unit)>0:
		var shield:=V.row("余波接力护盾",s[Relay.SHIELD].left,false,"guard");shield.text="剩余护盾 "+HpBar.shield_number(Relay.amount(unit));out.append(shield)
	if s.has("ballast_left"):out.append(V.row("重炮压舱 · 装填 -%d%% / 航速 -15%% / 受伤 +5%%"%roundi(float(s.ballast_reload)*100),s.ballast_left,false,"reload"))
	return out

static func draw(unit) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	if s.has("water_guards"):unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+8,0,TAU,24,Color(.2,.8,1,.75),2,true)
	if Relay.amount(unit)>0:unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+11,0,TAU,24,Color(.3,1,.9,.85),2.5,true)
	if s.has("ballast_left"):unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+4,PI*.15,PI*.85,16,Color.GOLD,2,true)
