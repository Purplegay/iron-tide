extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Low-rarity naval/air cards. Timers stay in serializable unit.special.
const REPAIR="ap_bilge_repair"
const ANCHOR="ps_anchor_reload"
const GUARD="ap_wing_guard"
const SCOUT="ps_cruise_scout"
const ACTIVE=[REPAIR,GUARD]
const PASSIVE=[ANCHOR,SCOUT]
const STATE="domain_card"
static var CHARGE_SECONDS:float:
	get:return P.number("mechanic/domain","prepare")

static func eligible(unit) -> bool:
	return AlliedAbilities.alive(unit) and unit.embarked_in==null and not unit.special.has("hero_wreck")

static func ready(unit,id:String) -> bool:
	if not eligible(unit) or unit._stun_timer>0 or AlliedAbilities.frozen(unit):return false
	if not preload("res://scripts/rules/skill_scope.gd").compatible(unit.unit_id,GameData.get_skill(id)):return false
	return unit.hp<unit.max_hp if id==REPAIR else unit.is_air_target()

static func cast(unit,ab:Ability) -> bool:
	if not ready(unit,ab.id):return false
	var state:Dictionary=unit.special.get_or_add(STATE,{})
	state.active=ab.id;state.left=ab.duration;state.duration=ab.duration;state.value=ab.value
	return true

static func tick(unit,dt:float) -> void:
	var state:Dictionary=unit.special.get_or_add(STATE,{})
	if not eligible(unit):
		unit.special.erase(STATE)
		return
	if state.has("active"):
		var id:String=state.active
		var left:=maxf(0,float(state.left))
		if id==REPAIR and unit._stun_timer<=0 and not AlliedAbilities.frozen(unit):
			unit.heal(unit.max_hp*float(state.value)*minf(left,dt)/maxf(.01,float(state.duration)),unit,true)
		state.left=maxf(0,left-dt)
		if state.left<=0 or (id==GUARD and not unit.is_air_target()):
			state.erase("active")
			for skill in unit.skills:
				if skill.id==id:skill.active_left=0
		unit.queue_redraw()
	var id:String=str(unit.passive.get("id",""))
	if id in PASSIVE:
		var previous:Vector2=state.get("position",unit.position)
		var translated:=not previous.is_equal_approx(unit.position)
		var valid:bool=unit._stun_timer<=0 and not AlliedAbilities.frozen(unit) and not unit.repairing
		var charging:bool=valid and (not unit._moving() and not translated if id==ANCHOR else unit.is_air_target() and unit._moving() and translated)
		var was_ready:bool=float(state.get("charge",0))>=CHARGE_SECONDS
		state.charge=minf(CHARGE_SECONDS,float(state.get("charge",0))+dt) if charging else 0.0
		state.position=unit.position
		if was_ready!=(state.charge>=CHARGE_SECONDS):unit.queue_redraw()
	else:
		state.erase("charge");state.erase("position")
	if not state.has("active") and id not in PASSIVE:unit.special.erase(STATE)

static func passive_bonus(unit,id:String) -> float:
	if not eligible(unit) or unit.passive.get("id")!=id:return 0.0
	if unit._stun_timer>0 or AlliedAbilities.frozen(unit) or unit.repairing:return 0.0
	if id==ANCHOR and unit._moving():return 0.0
	if id==SCOUT and (not unit.is_air_target() or not unit._moving()):return 0.0
	var state:Dictionary=unit.special.get(STATE,{})
	return float(unit.passive.value) if float(state.get("charge",0))>=CHARGE_SECONDS else 0.0

static func defend(unit,damage:float) -> float:
	if damage<=0:return damage
	var state:Dictionary=unit.special.get(STATE,{})
	if state.get("active")==GUARD and float(state.get("left",0))>0 and eligible(unit) and unit.is_air_target():
		return damage*(1.0-clampf(float(state.value),0,P.number("mechanic/domain","defense_cap")))
	return damage

static func draw(unit) -> void:
	if not eligible(unit):return
	var state:Dictionary=unit.special.get(STATE,{})
	var center:Vector2=unit._body_bounds.get_center()
	var radius:=maxf(12,minf(36,unit._body_bounds.size.x*.42))
	var phase:=float(state.get("duration",0))-float(state.get("left",0))
	match str(state.get("active","")):
		REPAIR:
			var color:=Color(.35,1,.8,.6)
			for i in 3:
				var at:=center+Vector2((i-1)*radius*.65,-fmod(phase*12+i*7,24))
				unit.draw_line(at-Vector2(3,0),at+Vector2(3,0),color,1.5,true)
				unit.draw_line(at-Vector2(0,3),at+Vector2(0,3),color,1.5,true)
		GUARD:
			for sign_x in [-1,1]:
				var start:=center+Vector2(sign_x*radius,-6)
				unit.draw_arc(start,8,-1.2,1.2,12,Color(.6,.9,1,.75),2,true)
	if passive_bonus(unit,ANCHOR)>0:
		unit.draw_arc(center,radius,-.4,.4,12,Color(.5,.85,1,.65),1.5,true)
		unit.draw_arc(center,radius,PI-.4,PI+.4,12,Color(.5,.85,1,.65),1.5,true)
