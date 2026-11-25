extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const ID := "ap_tanya_breach"
const PAYLOAD := "tanya_breach_charge"
const R=preload("res://scripts/units/expansion_rules.gd")
const HERO_KEY="commando_hero_v2"
const GROUND=preload("res://scripts/world/american_paradrop.gd")

static func ready(unit,ab) -> bool:
	if preload("res://scripts/units/tanya_talents.gd").locked(unit):return false
	if ab.id!=ID or unit.special.get("academy_hero","")!="TANY" or not R.active(unit) or unit.embarked_in!=null or unit._stun_timer>0 or AlliedAbilities.frozen(unit):return false
	var s:Dictionary=unit.special.get(HERO_KEY,{})
	return ab.ready() and not s.has("breach_throw") and not s.get("breach_charges",[]).any(AlliedAbilities.alive)

static func cast(unit,ab,point:Vector2) -> bool:
	if not ready(unit,ab):return false
	var world=R.world(unit)
	if world==null or not point.is_finite() or unit.position.distance_to(point)>P.number("mechanic/ap_tanya_breach","cast_range")*R.CELL or not world.position_visible_to(unit.side,point) or not GROUND.valid_zone(world,point):return false
	var direction:Vector2=unit.position.direction_to(point)
	if direction.is_zero_approx():direction=Vector2.from_angle(unit.hull_angle)
	var axis:=direction.orthogonal()
	var points:Array=[point]
	for i in range(1,P.count("mechanic/ap_tanya_breach","count")):
		points.append(point+axis*P.number("mechanic/ap_tanya_breach","spacing")*R.CELL*ceili(i/2.0)*(-1 if i%2 else 1))
	var s:Dictionary=unit.special[HERO_KEY]
	s.breach_charges=[]
	s.breach_throw={"points":points,"next":P.number("mechanic/ap_tanya_breach","throw_interval"),"index":1}
	preload("res://scripts/units/tanya_talents.gd").attacking(unit)
	throw_charge(unit,point,0.0)
	ab.trigger_cooldown()
	return true

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special.get(HERO_KEY,{})
	if not s.has("breach_throw"):return
	if not AlliedAbilities.alive(unit) or unit.embarked_in!=null or unit._stun_timer>0 or AlliedAbilities.frozen(unit) or preload("res://scripts/units/tanya_talents.gd").locked(unit):s.erase("breach_throw");return
	var pending:Dictionary=s.breach_throw
	pending.next-=dt
	while pending.next<=0 and pending.index<pending.points.size():
		throw_charge(unit,pending.points[pending.index],maxf(0.0,-float(pending.next)))
		pending.index+=1;pending.next+=P.number("mechanic/ap_tanya_breach","throw_interval")
	if pending.index>=pending.points.size():s.erase("breach_throw")

static func throw_charge(unit,point:Vector2,age:float) -> void:
	var world=R.world(unit)
	if not GROUND.valid_zone(world,point):return
	# Always the ordinary primary bullet, never a vehicle C4 secondary or burst total.
	var primary:=CommandoCombat.weapon_for(unit,null)
	var factor:=R.value(unit,ID,"damage")
	var raw:=float(primary.get("damage",0))*factor
	var bonus:Dictionary=unit.bonuses.duplicate(true)
	bonus.expansion_extra=true
	bonus.commando_effect="breach"
	bonus.reference_weapon={"damage":raw,"attack_type":"explosive"}
	var bomb=world.spawn_unit("E1",unit.side,point)
	if bomb==null:return
	var delay:=P.number("mechanic/ap_tanya_breach","detonation_delay")
	bomb.special.expansion_temporary={"kind":"breach","owner":unit,"left":delay+1.0}
	bomb.special[PAYLOAD]={"owner":unit,"hero":"TANY","side":unit.side,"age":age,"detonation_delay":delay,"origin":unit.position,"point":point,"raw":raw,"damage":CombatMath.with_offense(raw,bonus),"bonus":bonus}
	bomb.special.erase("academy_hero")
	bomb.display_name="三点破门炸药"
	bomb.skills.clear();bomb.passive={};bomb.buffs.clear();bomb.weapon={}
	bomb.data=bomb.data.duplicate(true);bomb.data.cost=0;bomb.data.immune_to_psionics=true
	bomb.max_hp=unit.max_hp*P.number("mechanic/ap_tanya_breach","bomb_health");bomb.hp=bomb.max_hp;bomb._base_max_hp=bomb.max_hp
	bomb.bonuses={};bomb._base_def=1;bomb._base_atk=0;bomb._base_speed=0;bomb.move_speed=0
	bomb.sight=0;bomb.radius=7;bomb._vet_value=0;bomb.veteran_level=0
	bomb.fire_stance="none";bomb.collision_layer=0;bomb.collision_mask=0
	bomb.logistics.capacity=0
	unit.special[HERO_KEY].breach_charges.append(bomb)
	bomb.queue_redraw()

static func charge_tick(bomb,dt:float) -> void:
	if not AlliedAbilities.alive(bomb):bomb.queue_free();return
	var state:Dictionary=bomb.special[PAYLOAD]
	state.age+=dt
	if not GROUND.valid_zone(R.world(bomb),state.point):R.dissolve(bomb);return
	if state.age>=float(state.get("detonation_delay",P.number("mechanic/ap_tanya_breach","detonation_delay"))):
		# Mark spent before damage so nested callbacks cannot detonate twice.
		if not state.get("spent",false):state.spent=true;detonate(bomb,state)
		R.dissolve(bomb)
	else:bomb.queue_redraw()

static func armor_factor(target) -> float:
	if target is Building:return P.number("mechanic/hero_explosive_armor","building")
	if AlliedAbilities.infantry(target):return P.number("mechanic/hero_explosive_armor","infantry")
	return P.number("mechanic/hero_explosive_armor","light_medium") if GameData.to_engine_armor(target.armor) in ["light","medium"] else P.number("mechanic/hero_explosive_armor","heavy")

static func detonate(bomb,state:Dictionary) -> void:
	var world=R.world(bomb)
	for target in world.units.duplicate()+world.buildings.duplicate():
		if not R.enemy(bomb,target):continue
		if target is Unit and (target.is_air_target() or target.embarked_in!=null or NavalContact.submerged(target)):continue
		var point:Vector2=target.closest_footprint_point(state.point) if target is Building else target.position
		if point.distance_to(state.point)>P.number("mechanic/ap_tanya_breach","radius")*R.CELL:continue
		var factor:=armor_factor(target)
		var bonus:Dictionary=state.bonus.duplicate()
		bonus.hit_reference_damage=float(state.raw)*factor*float(bonus.get("veteran_attack",1.0))
		target.receive_hit(float(state.damage)*factor,"explosive",bonus,bomb)
	Effects.spawn_impact(state.point,Color(1,.66,.25),P.number("mechanic/ap_tanya_breach","radius")*R.CELL)

static func draw(bomb) -> void:
	var s:Dictionary=bomb.special[PAYLOAD]
	var fraction:=clampf(float(s.age)/.4,0,1)
	var offset:Vector2=Iso.dir(Vector2(s.origin).lerp(s.point,fraction)-bomb.position)
	offset.y-=sin(fraction*PI)*35
	bomb._body_bounds=Rect2(offset-Vector2(8,8),Vector2(16,16))
	bomb.draw_circle(Vector2.ZERO,7,Color(0,0,0,.3))
	bomb.draw_rect(Rect2(offset-Vector2(7,5),Vector2(14,10)),Color("#414d55"))
	bomb.draw_line(offset-Vector2(4,4),offset+Vector2(-4,4),Color("#c59e61"),2)
	bomb.draw_line(offset-Vector2(-4,4),offset+Vector2(4,4),Color("#c59e61"),2)
	bomb.draw_circle(offset,2,Color.RED if int(float(s.age)*8)%2 else Color.ORANGE)
	if bomb.selected or bomb.hovered:bomb.draw_arc(offset,11,0,TAU,20,Color.YELLOW,1)
