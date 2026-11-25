extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY="commando_hero_v2"
const SHIELD="boris_radio_shield"
const PICKUPS="boris_radio_supplies"
const EVENTS="boris_last_orders"
const WAVES="boris_command_waves"
const DEFENSE_DEFAULT = [
	"前线掩体：静止 2 秒后普通远程减伤 15%，移动后保留 0.5 秒。",
	"防爆内衬：普通爆炸类致命一击最多扣除最大生命的一半；低血仍可能阵亡，不保护米格，不限制处决或时空擦除。",
	"抗扰通讯：单次新增眩晕／冻结持续时间减半；保留已有控制，不解除持续维持型控制与时空擦除，不缩短己方增益或传送恢复。",
	"接应补给：本人米格实际投弹后正常离场，在本人附近合法地面留一份 10 秒补给；本人接触恢复最大生命 15%，满血不消耗。每编队一次，同时最多一份。",
	"电台掩护：进入原生空袭标定或 W 呼叫时，2 格内最近最多两名同方非英雄步兵获得其最大生命 10% 护盾、持续 4 秒；间隔 20 秒，取消不返资格。",
	"最后电令：每局一次，战斗阵亡时向 6 格内仍可见合法的最后伤害来源留下固定 1.5 秒预警，再落下攻击力 150% 的普通爆破，半径 1.5 格。不复活、不消耗校射或改变 W 冷却。"
]
static var DEFENSE:Array:
	get:return P.traits("hero/BORIS/survival",DEFENSE_DEFAULT)

static func rank(unit) -> int:
	if not is_instance_valid(unit) or not unit is Unit or unit.special.get("academy_hero")!="BORIS" or not unit.special.has(KEY) or not BattleRequest.extensions_enabled() or R.temporary(unit):return -1
	return clampi(int(unit.special.get("hero_survival_rank",0)),0,5)

static func tick(unit,dt:float) -> void:
	if rank(unit)>=0:R.timer(unit.special[KEY],"radio_cover_cd",dt)

static func control_duration(unit,seconds:float) -> float:
	return seconds*P.number("hero/BORIS/survival","control_factor") if rank(unit)>=2 else seconds

static func before_damage(unit,amount:float,kind:String,bonus:Dictionary) -> float:
	if rank(unit)<1 or amount<unit.hp or bonus.get("expansion_extra",false) or bonus.get("force_execute",false):return amount
	return minf(amount,unit.max_hp*P.number("hero/BORIS/survival","explosive_lethal_cap")) if kind in ["shell","missile","explosive"] else amount

static func health_hit(unit,source,amount:float) -> void:
	if rank(unit)<5 or amount<=0:return
	var s:Dictionary=unit.special[KEY]
	s.erase("radio_lethal")
	if amount<unit.hp:return
	var actor=R.owner(source)
	if not is_instance_valid(actor) or not (actor is Unit or actor is Building):return
	s.radio_lethal={"attacker":actor,"side":source.owner_side if source is Projectile else actor.side}

static func started(unit) -> void:
	if rank(unit)<4 or not AlliedAbilities.alive(unit) or unit.embarked_in!=null or unit._stun_timer>0 or AlliedAbilities.frozen(unit):return
	var s:Dictionary=unit.special[KEY]
	if s.has("radio_cover_cd"):return
	s.radio_cover_cd=P.number("hero/BORIS/survival","cover_cooldown")
	var candidates:Array=[]
	for other in R.world(unit).units:
		if not R.active(other) or other.side!=unit.side or not AlliedAbilities.infantry(other) or other.embarked_in!=null or other.special.has("academy_hero"):continue
		if other.position.distance_to(unit.position)<=P.number("hero/BORIS/survival","cover_radius")*R.CELL:candidates.append(other)
	candidates.sort_custom(func(a,b):return a.position.distance_squared_to(unit.position)<b.position.distance_squared_to(unit.position))
	for other in candidates.slice(0,P.count("hero/BORIS/survival","cover_targets")):
		other.special[SHIELD]={"hp":maxf(float(other.special.get(SHIELD,{}).get("hp",0)),other.max_hp*P.number("hero/BORIS/survival","cover_shield")),"left":P.number("hero/BORIS/survival","cover_seconds"),"side":unit.side}
		other.queue_redraw()

static func shield_tick(unit,dt:float) -> void:
	var shield:Dictionary=unit.special[SHIELD]
	shield.left-=dt
	if shield.left<=0 or shield.side!=unit.side or not BattleRequest.extensions_enabled():unit.special.erase(SHIELD)
	unit.queue_redraw()

static func absorb(unit,amount:float) -> float:
	var shield:Dictionary=unit.special[SHIELD]
	if not BattleRequest.extensions_enabled() or shield.side!=unit.side:return amount
	var used:=minf(maxf(amount,0),float(shield.hp))
	shield.hp-=used
	if shield.hp<=0:unit.special.erase(SHIELD)
	return amount-used

static func exited(jet) -> void:
	var run:Dictionary=jet.special.strike_run
	if not run.get("boris_dropped",false) or not run.has("boris_wave"):return
	var world=R.world(jet)
	for wave in world.allied_state.get(WAVES,[]):
		if wave.id!=run.boris_wave:continue
		if not wave.get("supply_enabled",false) or wave.get("supplied",false):return
		var owner=run.spotter
		if not AlliedAbilities.alive(owner) or rank(owner)<3 or owner.side!=wave.side or world.house_defeated(wave.side):return
		var supplies:Array=world.allied_state.get_or_add(PICKUPS,[])
		for item in supplies:
			if is_same(item.owner,owner):wave.supplied=true;return
		var point:=supply_point(owner)
		if not point.is_finite():return
		wave.supplied=true
		supplies.append({"owner":owner,"side":owner.side,"point":point,"left":P.number("hero/BORIS/survival","supply_seconds")})
		world.queue_redraw();return

static func supply_point(unit) -> Vector2:
	var world=R.world(unit)
	for distance in [30.0,45.0,55.0]:
		for i in 8:
			var point:Vector2=unit.position+Vector2.RIGHT.rotated(TAU*i/8.0)*distance
			if not Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).has_point(point) or world.in_water_world(point) or world.path_service.is_blocked(point):continue
			if world.path_service.line_walkable(unit.position,point,world.path_service.cost):return point
	return Vector2.INF

static func legal_attacker(unit,target) -> bool:
	if not R.enemy(unit,target):return false
	if target.ignores_warhead("") or (target.side=="ally" and GM.god_mode):return false
	if target is Unit and (target.is_air_target() or target.is_naval or target.embarked_in!=null or R.temporary(target)):return false
	if target.special.has("iron_left") or target.special.get("expedition_protected",false) or float(target.special.get("force_shield_left",0))>0 or AlliedAbilities.alive(target.special.get("temporal_by")):return false
	if unit.position.distance_to(target.position)>P.number("hero/BORIS/survival","last_range")*R.CELL or not R.world(unit).actor_visible_to(unit.side,target):return false
	return not target is Unit or not AlliedAbilities.concealed(target,unit.side)

static func dying(unit,temporal:bool) -> void:
	if rank(unit)<5:return
	var s:Dictionary=unit.special[KEY]
	var lethal:Dictionary=s.get("radio_lethal",{})
	s.erase("radio_lethal")
	if lethal.is_empty() or s.get("radio_last_used",false) or temporal or unit.embarked_in!=null or unit.special.get("house_eliminated",false):return
	s.radio_last_used=true
	var world=R.world(unit)
	var target=lethal.attacker
	if world.house_defeated(unit.side) or not is_instance_valid(target) or lethal.side!=target.side or not legal_attacker(unit,target):return
	var raw:=float(unit._weapon_for_target(null).get("damage",0))*P.number("hero/BORIS/survival","last_damage")
	var bonus:Dictionary=unit.bonuses.duplicate(true)
	bonus.expansion_extra=true;bonus.reference_weapon={"damage":raw,"attack_type":"explosive"}
	world.allied_state.get_or_add(EVENTS,[]).append({"owner":unit,"side":unit.side,"point":target.position,"left":P.number("hero/BORIS/survival","last_delay"),"raw":raw,"damage":CombatMath.with_offense(raw,bonus),"bonus":bonus})
	world.queue_redraw()

static func world_tick(world,dt:float) -> void:
	for item in world.allied_state.get(PICKUPS,[]).duplicate():
		item.left-=dt
		var owner=item.owner
		if not AlliedAbilities.alive(owner) or owner.side!=item.side or world.house_defeated(item.side) or item.left<=0:
			world.allied_state[PICKUPS].erase(item);continue
		if owner.embarked_in==null and owner.hp<owner.max_hp and owner.position.distance_to(item.point)<=owner.radius+8:
			owner.heal(owner.max_hp*P.number("hero/BORIS/survival","supply_heal"))
			world.allied_state[PICKUPS].erase(item)
	for event in world.allied_state.get(EVENTS,[]).duplicate():
		if world.house_defeated(event.side):world.allied_state[EVENTS].erase(event);continue
		event.left-=dt
		if event.left<=0:
			world.allied_state[EVENTS].erase(event)
			explode(world,event)
	for key in [PICKUPS,EVENTS]:
		if world.allied_state.has(key):
			world.queue_redraw()
			if world.allied_state[key].is_empty():world.allied_state.erase(key)

static func explode(world,event:Dictionary) -> void:
	for target in world.units.duplicate()+world.buildings.duplicate():
		if not AlliedAbilities.alive(target) or target.side=="neutral" or BattleRequest.friendly(event.side,target.side):continue
		if target is Unit and (target.is_air_target() or target.embarked_in!=null or NavalContact.submerged(target)):continue
		var point:Vector2=target.closest_footprint_point(event.point) if target is Building else target.position
		if point.distance_to(event.point)>P.number("hero/BORIS/survival","last_radius")*R.CELL:continue
		var armor:=preload("res://scripts/units/tanya_breach.gd").armor_factor(target)
		var bonus:Dictionary=event.bonus.duplicate()
		bonus.hit_reference_damage=float(event.raw)*armor*float(bonus.get("veteran_attack",1))
		target.receive_hit(float(event.damage)*armor,"explosive",bonus,event.owner if is_instance_valid(event.owner) else null)
	Effects.spawn_impact(event.point,Color(1,.35,.15),P.number("hero/BORIS/survival","last_radius")*R.CELL)

static func draw_world(world) -> void:
	for item in world.allied_state.get(PICKUPS,[]):
		if item.side!="ally" and not world.position_visible_to("ally",item.point):continue
		world.draw_set_transform(item.point,Iso.eff_angle(),Iso.up())
		world.draw_rect(Rect2(Vector2(-8,-8),Vector2(16,12)),Color(.2,.65,.3))
		world.draw_line(Vector2(-4,-2),Vector2(4,-2),Color.WHITE,2)
		world.draw_line(Vector2(0,-5),Vector2(0,1),Color.WHITE,2)
		world.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	for event in world.allied_state.get(EVENTS,[]):
		if event.side!="ally" and not world.position_visible_to("ally",event.point):continue
		Iso.outline(world,Iso.ground_circle(event.point,P.number("hero/BORIS/survival","last_radius")*R.CELL),Color(1,.35,.15,.8),2)

static func draw_shield(unit) -> void:
	unit.draw_arc(Vector2(0,-unit._visual_lift()-8),unit.radius+8,0,TAU,24,Color(.4,.8,1,.7),1.5,true)

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	var rows:Array=[]
	if unit.special.has(SHIELD):rows.append(V.row("电台掩护 · 护盾 %.0f"%unit.special[SHIELD].hp,unit.special[SHIELD].left,false,"guard"))
	if rank(unit)>=0:
		var s:Dictionary=unit.special[KEY]
		if s.has("radio_cover_cd"):rows.append(V.row("电台掩护冷却",s.radio_cover_cd,false,"reload"))
		for item in R.world(unit).allied_state.get(PICKUPS,[]):
			if is_same(item.owner,unit):rows.append(V.row("接应补给 · 本人拾取恢复 15% 生命",item.left,false,"heal"))
		if rank(unit)>=5:rows.append(V.row("最后电令 · "+("本局已用" if s.get("radio_last_used",false) else "本局可用"),0,false,"explosive"))
	return rows
