extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Ground progression shares the snapshot-owned v2 state; no temporary actors.
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"

static func state(unit) -> Dictionary:
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func eligible(unit) -> bool:
	return unit.passive.get("id")=="ps_mirage_gap" or (unit.unit_id=="GGI" and R.talent_rank(unit,"armor_ranging")>=0) or (unit.unit_id=="SREF" and R.talent_rank(unit,"prism_guard")>=0)

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	for key in ["mirage_guard","mirage_gap_cd","prism_guard_cd"]:R.timer(s,key,dt)
	if s.has("ranging_left"):
		R.timer(s,"ranging_left",dt)
		if not s.has("ranging_left"):s.erase("ranging_target");s.ranging_hits=0
	if s.has("ranging_target") and (not unit.is_deployed() or not R.enemy(unit,s.ranging_target) or not is_same(unit.attack_target,s.ranging_target)):
		s.erase("ranging_left");s.erase("ranging_target");s.ranging_hits=0
	if s.has("prism_shield"):
		s.prism_shield.left-=dt
		if s.prism_shield.left<=0:s.erase("prism_shield")
	if s.has("prism_cross"):
		if unit.embarked_in!=null or unit._stun_timer>0 or AlliedAbilities.frozen(unit):
			s.erase("prism_cross");return
		var cross:Dictionary=s.prism_cross
		cross.next-=dt
		while cross.next<=.000001 and cross.pulses<P.count("mechanic/ground_v2","cross_pulses"):
			pulse(unit,cross);cross.pulses+=1;cross.next+=P.number("mechanic/ground_v2","cross_interval")
		if cross.pulses>=P.count("mechanic/ground_v2","cross_pulses"):s.erase("prism_cross")

static func cast_cross(unit,ab,point:Vector2) -> bool:
	var world=R.world(unit)
	if not point.is_finite() or world==null or unit.position.distance_to(point)>unit.attack_range or not world.position_visible_to(unit.side,point):return false
	if not Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).has_point(point):return false
	if state(unit).has("prism_cross"):return false
	var weapon:Dictionary=unit._active_weapon().duplicate(true)
	weapon.damage=float(weapon.get("damage",0))*R.value(unit,ab.id,"damage")
	var bonus:Dictionary=unit.bonuses.duplicate(true)
	bonus.expansion_extra=true;bonus.reference_weapon=weapon.duplicate(true)
	state(unit).prism_cross={"point":point,"axis":Vector2.from_angle(unit.hull_angle),"next":P.number("mechanic/ground_v2","cross_interval"),"pulses":0,"weapon":weapon,"bonus":bonus}
	ab.trigger_cooldown();unit.queue_redraw()
	return true

static func in_cross(point:Vector2,center:Vector2,axis:Vector2) -> bool:
	var delta:=point-center
	var a:=absf(delta.dot(axis));var b:=absf(delta.dot(axis.orthogonal()))
	return (a<=P.number("mechanic/ground_v2","cross_length")*R.CELL and b<=P.number("mechanic/ground_v2","cross_width")*R.CELL) or (b<=P.number("mechanic/ground_v2","cross_length")*R.CELL and a<=P.number("mechanic/ground_v2","cross_width")*R.CELL)

static func pulse(unit,cross:Dictionary) -> void:
	var world=R.world(unit)
	if world==null:return
	for axis:Vector2 in [cross.axis,cross.axis.orthogonal()]:
		Effects.spawn_beam(cross.point-axis*P.number("mechanic/ground_v2","cross_length")*R.CELL,cross.point+axis*P.number("mechanic/ground_v2","cross_length")*R.CELL,Color.CYAN,"laser",3,.24)
	for target in world.units+world.buildings:
		if not R.enemy(unit,target) or not unit._weapon_domain_valid(target,false,cross.weapon):continue
		if target is Unit and (target.is_air_target() or target.embarked_in!=null):continue
		if not in_cross(R.point(unit,target) if target is Unit else target.closest_footprint_point(cross.point),cross.point,cross.axis):continue
		var weapon:Dictionary=cross.weapon
		var damage:=CombatMath.full_damage(weapon,target.armor,cross.bonus,null,target.ra2_armor,0.0,target)
		target.receive_hit(damage,str(weapon.get("attack_type","laser")),cross.bonus,unit,str(weapon.get("ra2_warhead","")))

static func before_reveal(unit) -> void:
	if not R.active(unit) or unit.unit_id!="MGTK" or unit.passive.get("id")!="ps_mirage_gap":return
	if not AlliedAbilities.mirage_at_rest(unit) or float(unit.special.get("reveal",0))>0 or not unit.special.has("mirage_tree"):return
	var s:=state(unit)
	if s.has("mirage_gap_cd"):return
	s.mirage_guard=P.number("mechanic/ground_v2","mirage_guard");s.mirage_gap_cd=P.number("mechanic/ground_v2","mirage_cooldown")

static func shot(unit,target,bonus:Dictionary) -> void:
	if not R.active(unit):return
	if unit.unit_id=="SREF" and R.talent_rank(unit,"prism_guard")>=0:
		var s:=state(unit)
		s.prism_volley=int(s.get("prism_volley",0))+1;s.prism_victims=[]
		bonus.expansion_prism_volley=s.prism_volley
	if unit.unit_id=="GGI" and unit.special.has(KEY):
		var s:Dictionary=unit.special[KEY]
		if s.has("ranging_target") and not is_same(s.ranging_target,target):
			s.erase("ranging_target");s.erase("ranging_left");s.ranging_hits=0

static func impact(unit,target,amount:float,extra:bool) -> float:
	if extra or amount<=0 or not unit is Unit or unit.unit_id!="GGI" or R.talent_rank(unit,"armor_ranging")<0:return amount
	if not unit.is_deployed() or not R.enemy(unit,target) or not target is Unit or target.is_air_target() or target.is_naval or AlliedAbilities.infantry(target):return amount
	if not is_same(unit.attack_target,target):return amount
	var s:=state(unit)
	if not is_same(s.get("ranging_target"),target):s.ranging_target=target;s.ranging_hits=0;s.erase("ranging_left")
	if s.has("ranging_left"):return amount*(1.0+R.talent(unit,"armor_ranging","damage"))
	s.ranging_hits=int(s.get("ranging_hits",0))+1
	if s.ranging_hits>=P.count("mechanic/ground_v2","ranging_hits"):s.ranging_left=P.number("mechanic/ground_v2","ranging_duration")
	return amount

static func damaged(unit,target,bonus:Dictionary,source) -> void:
	if not unit is Unit or unit.unit_id!="SREF" or R.talent_rank(unit,"prism_guard")<0 or not R.enemy(unit,target):return
	if not source is Projectile or bonus.get("expansion_extra",false) or not bonus.has("expansion_prism_volley"):return
	var s:=state(unit)
	if s.has("prism_guard_cd") or bonus.expansion_prism_volley!=s.get("prism_volley",-1):return
	var victims:Array=s.get_or_add("prism_victims",[])
	if victims.has(target):return
	victims.append(target)
	if victims.size()<P.count("mechanic/ground_v2","prism_targets"):return
	var hp:float=unit.max_hp*R.talent(unit,"prism_guard","shield")
	s.prism_shield={"hp":hp,"maximum":hp,"left":P.number("mechanic/ground_v2","prism_shield_seconds")};s.prism_guard_cd=P.number("mechanic/ground_v2","prism_cooldown")
	unit.queue_redraw()

static func defend(unit,amount:float,kind:String,bonus:Dictionary,source) -> float:
	if amount<=0 or unit.unit_id!="MGTK" or not R.active(unit) or not unit.special.get(KEY,{}).has("mirage_guard"):return amount
	if bonus.get("expansion_extra",false) or kind not in ["bullet","shell","missile","laser","electric","sniper"]:return amount
	var attacker=R.owner(source)
	if not is_instance_valid(attacker) or not (attacker is Unit or attacker is Building) or BattleRequest.friendly(unit.side,attacker.side):return amount
	if source is Projectile and not is_same(source.target,unit):return amount
	return amount*(1.0-R.value(unit,"ps_mirage_gap","defense"))

static func absorb(unit,amount:float) -> float:
	var s:Dictionary=unit.special.get(KEY,{})
	if not s.has("prism_shield"):return amount
	var used:=minf(amount,float(s.prism_shield.hp));s.prism_shield.hp-=used
	if s.prism_shield.hp<=0:s.erase("prism_shield")
	return amount-used

static func entries(unit) -> Array:
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	const V=preload("res://scripts/units/expansion_visual.gd")
	for item in [["ranging_left","反甲校距 · 同一目标增伤"],["mirage_guard","伪装间隙 · 远程减伤"],["mirage_gap_cd","伪装间隙冷却"],["prism_guard_cd","余光护镜冷却"]]:
		if s.has(item[0]):out.append(V.row(item[1],s[item[0]],false,"guard"))
	if s.has("prism_cross"):out.append(V.row("棱镜十字 · 下一轮",s.prism_cross.next,false,"laser"))
	if s.has("prism_shield"):
		var row:=V.row("余光护镜",s.prism_shield.left,false,"guard");row.text="剩余护盾 %.0f"%s.prism_shield.hp;out.append(row)
	return out

static func draw(unit) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	if s.has("prism_shield") or s.has("mirage_guard"):unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+7,0,TAU,32,Color(.35,.85,1,.7),1.5,true)
	if s.has("prism_cross"):
		var cross:Dictionary=s.prism_cross
		for axis:Vector2 in [cross.axis,cross.axis.orthogonal()]:
			unit.draw_dashed_line(Iso.dir(cross.point-unit.position-axis*P.number("mechanic/ground_v2","cross_length")*R.CELL),Iso.dir(cross.point-unit.position+axis*P.number("mechanic/ground_v2","cross_length")*R.CELL),Color(.3,.9,1,.55),1.5,8)
