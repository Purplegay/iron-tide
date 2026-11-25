extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const ID="ap_mirror_fork"
static var SHIELD_SECONDS:float:
	get:return P.number("mechanic/ap_mirror_fork","shield_seconds")

static func living(unit) -> Array:
	var mirrors:Array=[]
	for mirror in unit.special.get(R.KEY,{}).get("mirrors",[]):
		if AlliedAbilities.alive(mirror) and float(mirror.special.get("expansion_temporary",{}).get("left",0))>0:
			mirrors.append(mirror)
	return mirrors

static func target(unit):
	var selected=null
	for mirror in living(unit):
		if selected==null or mirror.hp>selected.hp:selected=mirror
	return selected

static func cast(unit,ab) -> bool:
	var chosen=target(unit)
	var s:=R.state(unit)
	if chosen!=null:
		if unit.special.has("parasite") or chosen.embarked_in!=null:return false
		var origin:Vector2=unit.position
		var shield:float=chosen.hp
		unit.position=chosen.position
		unit.order_stop()
		s.mirror_shield={"hp":shield,"maximum":shield,"left":SHIELD_SECONDS}
		var mirrors:=living(unit)
		s.erase("mirrors")
		for mirror in mirrors:detonate(mirror)
		Effects.spawn_beam(origin,unit.position,Color.CYAN,"laser",2,.3)
		R.label(unit,"折光转移 · 护盾 %.0f"%shield)
		return true
	if not ab.ready():return false
	var mirrors:Array=[]
	for index in P.count("mechanic/ap_mirror_fork","count"):
		var angle:float=0.0 if P.count("mechanic/ap_mirror_fork","count")==1 else lerpf(-PI/4,PI/4,float(index)/(P.count("mechanic/ap_mirror_fork","count")-1))
		var direction:=Vector2.from_angle(unit.hull_angle+angle)
		var mirror=R.summon(unit,"MGTK",unit.position+direction*25,"mirror",R.value(unit,ID,"life"),R.value(unit,ID,"hp"),R.value(unit,ID,"damage"))
		if mirror==null:continue
		mirror._base_atk=float(unit.bonuses.get("attack_bonus",unit._base_atk))*R.value(unit,ID,"damage")
		mirror._ra2_weapon_override={}
		mirror.veteran_level=0
		mirror.fire_stance="defend"
		mirror.order_move(mirror.position+direction*P.number("mechanic/ap_mirror_fork","move_range")*R.CELL)
		R.state(mirror).speed_bonus=R.value(unit,ID,"speed")
		R.state(mirror).speed_left=P.number("mechanic/ap_mirror_fork","speed_seconds")
		mirror._recompute_bonuses()
		mirror._refresh_weapon_derived()
		mirrors.append(mirror)
	if mirrors.is_empty():return false
	s.mirrors=mirrors
	s.speed_bonus=R.value(unit,ID,"speed");s.speed_left=P.number("mechanic/ap_mirror_fork","speed_seconds")
	ab.trigger_cooldown();unit._recompute_bonuses()
	R.label(unit,"折光岔路 · W 转移")
	return true

static func detonate(mirror) -> void:
	if not is_instance_valid(mirror):return
	var temp:Dictionary=mirror.special.get("expansion_temporary",{})
	if temp.get("ended",false):return
	temp.ended=true
	var owner=temp.get("owner")
	var at:Vector2=mirror.position
	R.dissolve(mirror)
	if not AlliedAbilities.alive(owner) or mirror.special.get("house_eliminated",false):return
	var radius:float=R.value(owner,ID,"radius")*R.CELL
	R.area(owner,at,radius,R.value(owner,ID,"blast"))
	Effects.spawn_impact(at,Color(.45,.85,1),radius)

static func clear(unit) -> void:
	var s:Dictionary=unit.special.get(R.KEY,{})
	for mirror in s.get("mirrors",[]):R.dissolve(mirror)
	s.erase("mirrors");s.erase("mirror_shield")

static func tick(unit,delta:float) -> void:
	var s:Dictionary=unit.special.get(R.KEY,{})
	if s.has("mirrors"):
		s.mirrors=living(unit)
		if s.mirrors.is_empty():s.erase("mirrors")
	if s.has("mirror_shield"):
		s.mirror_shield.left-=delta
		if s.mirror_shield.left<=0:s.erase("mirror_shield")

static func absorb(unit,damage:float) -> float:
	var s:Dictionary=unit.special.get(R.KEY,{})
	if damage<=0 or not s.has("mirror_shield"):return damage
	var used:=minf(damage,float(s.mirror_shield.hp))
	s.mirror_shield.hp-=used
	if s.mirror_shield.hp<=0:s.erase("mirror_shield")
	if used>0:R.label(unit,"折光护盾 -%.0f"%used)
	return damage-used
