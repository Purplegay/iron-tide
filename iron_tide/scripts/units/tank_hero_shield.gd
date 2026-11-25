extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Numeric state only, persisted by the existing actor.special snapshot.
const KEY := "hero_stationary_shield"
static var INITIAL:float:
	get:return P.number("hero/tank/shield","initial")
static var GROWTH:float:
	get:return P.number("hero/tank/shield","growth")
static var LIMIT:float:
	get:return P.number("hero/tank/shield","limit")
static var DELAY:float:
	get:return P.number("hero/tank/shield","delay")
static var DURATION:float:
	get:return P.number("hero/tank/shield","duration")
static var RADIUS:float:
	get:return P.number("hero/tank/shield","radius")
static var DAMAGE:float:
	get:return P.number("hero/tank/shield","damage")
const COLOR := Color(0.3,0.85,1.0)
const LAST_HIT := &"hero_shield_last_hit"
const Wave = preload("res://scripts/core/shield_break_wave.gd")
const PREVIEW_DURATION := 24.0
const PREVIEW_BREAK := 18.0
const DESCRIPTION := "无护盾时，连续静止、不普攻且未受击满 3 秒，获得最大生命 15% 的护盾；未受损时继续保持，每 1 秒追加 5%，上限 50%。护盾一旦受损，残盾不能恢复或继续增长，直到破碎或自然到期清零后才能重新积攒。移动、普攻或受击会打断蓄盾计时；释放技能本身不打断。每次实际加盾刷新 120 秒持续时间，受损后不刷新。受击破盾对周围 2 格敌人造成主炮攻击力 110% 的伤害（正常护甲结算）；自然到期不爆炸"

static func maximum(unit) -> float:
	if unit.special.has("furnace_prone"):
		return unit.max_hp * float(GameData.get_skill("ap_furnace_bastion").shield_by_rank[unit.special.furnace_prone.rank])
	return unit.max_hp*LIMIT

static func amount(unit) -> float:
	if unit.special.has("furnace_prone"):return float(unit.special.furnace_prone.hp)
	if not unit.special.has(KEY):return 0.0
	return float(unit.special[KEY].get("hp",0))

static func record_hit(unit,before:float,health_damage:float,source,warhead:String) -> float:
	var absorbed:=maxf(0.0,before-amount(unit))
	if before>0 and absorbed>0:
		var attacker=source.shooter() if source is Projectile else source
		var name:=str(attacker.get("display_name")) if is_instance_valid(attacker) and attacker.get("display_name")!=null else "环境／来源已离场"
		unit.set_meta(LAST_HIT,{"absorbed":absorbed,"health_damage":maxf(0,health_damage),"source":name,"warhead":warhead})
	return absorbed

static func hit_caption(absorbed:float,health_damage:float,side: String = "ally") -> String:
	var text := "护盾 -" + HpBar.shield_number(absorbed) if side == "ally" else "护盾受击"
	if health_damage>0:text+=" · 生命 -"+HpBar.shield_number(health_damage)
	return text

static func describe(unit) -> String:
	if not Unit.TankHero.active(unit) or unit.special.has("hero_wreck"):return ""
	var state:Dictionary=unit.special.get(KEY,{})
	var current:=amount(unit)
	if unit.side != "ally": return "静止蓄盾：%d%%" % roundi(100.0 * current / maxf(unit.max_hp * LIMIT,1.0))
	var text:="静止蓄盾：%s / %s（最大生命的 50%%）"%[HpBar.shield_number(current),HpBar.shield_number(unit.max_hp*LIMIT)]
	if current>0:
		text+=" · 剩余 %.1f 秒"%maxf(0,float(state.get("left",0)))
		if bool(state.get("damaged",false)) or int(state.get("rules",0))<3:
			text+=" · 残盾不能恢复，清零后重新积攒"
		elif current>=unit.max_hp*LIMIT-0.000001:text+=" · 已满盾"
		else:text+=" · 每秒蓄盾 5%" if bool(state.get("growing",false)) else " · 保持静止、不普攻、未受击 %.1f 秒后加盾 15%%" % maxf(0,DELAY-float(state.get("charge",0)))
	else:text+=" · 静止、不普攻、未受击满 3 秒开始蓄盾"
	if unit.has_meta(LAST_HIT):
		var hit:Dictionary=unit.get_meta(LAST_HIT)
		text+="\n最近一次护盾受击：吸收 %s，生命扣除 %s；来源 %s%s"%[HpBar.shield_number(hit.absorbed),HpBar.shield_number(hit.health_damage),hit.source," · "+str(hit.warhead) if not str(hit.warhead).is_empty() else ""]
	return text

static func preview(seconds:float) -> Dictionary:
	var time:=maxf(0,seconds)
	if time<DELAY:return {"fraction":0.0,"label":"静止蓄盾 · 还需 %.1f 秒" % (DELAY-time)}
	if time<11:
		var fraction:=minf(LIMIT,INITIAL+floorf(time-DELAY)*GROWTH)
		return {"fraction":fraction,"label":"护盾 %d%% / 50%% · 加盾刷新 120 秒" % roundi(fraction*100)}
	if time<PREVIEW_BREAK:return {"fraction":0.3,"label":"受击后剩余 30% · 残盾不能恢复，等待破碎或到期"}
	if time<PREVIEW_BREAK+1:return {"fraction":0.0,"label":"受击破盾 · 周围 2 格 · 110% 攻击力"}
	if time<PREVIEW_BREAK+DELAY:return {"fraction":0.0,"label":"护盾清零 · 重新静止蓄盾，剩余 %.1f 秒"%(PREVIEW_BREAK+DELAY-time)}
	return {"fraction":minf(LIMIT,INITIAL+floorf(time-PREVIEW_BREAK-DELAY)*GROWTH),"label":"清零后开始新一轮蓄盾 · 未受击可继续增长"}

static func clear(unit) -> void:
	unit.special.erase(KEY)
	unit.queue_redraw()

# Old rules cannot prove whether a surviving shield took damage; preserve it locked.
static func recovery_state(unit) -> Dictionary:
	var state:Dictionary=unit.special.get_or_add(KEY,{"hp":0.0,"left":0.0,"charge":0.0,"point":unit.global_position})
	if int(state.get("rules",0))!=3:
		state.rules=3;state.growing=false;state.charge=0.0
		state.damaged=float(state.get("hp",0))>0
	return state

static func interrupt_recovery(unit) -> void:
	if not Unit.TankHero.active(unit) or unit._dead or unit.special.has("hero_wreck"):return
	var state:=recovery_state(unit)
	state.charge=0.0;state.growing=false

static func tick(unit,delta:float) -> void:
	if unit.special.has("hero_wreck") or unit._dead or unit.embarked_in!=null:
		if unit.special.has(KEY):clear(unit)
		return
	var state:=recovery_state(unit)
	var moving:bool=unit.velocity.length_squared()>1.0 or unit.global_position.distance_squared_to(state.point)>0.01
	state.point=unit.global_position
	if moving:interrupt_recovery(unit)
	var remaining:=maxf(0,delta)
	var old_hp:=float(state.hp)
	state.hp=minf(state.hp,unit.max_hp*LIMIT)
	while remaining>0.000001:
		var has_shield:bool=state.hp>0
		var can_grow:bool=not moving and not bool(state.get("damaged",false)) and state.hp<unit.max_hp*LIMIT-0.000001
		var threshold:=P.number("hero/tank/shield","growth_interval") if state.growing else DELAY
		var growth_in:=maxf(0,threshold-float(state.charge)) if can_grow else INF
		var expiry_in:=maxf(0,float(state.left)) if has_shield else INF
		var step:=minf(remaining,minf(growth_in,expiry_in))
		remaining-=step
		if has_shield:state.left-=step
		if can_grow:state.charge+=step
		if has_shield and state.left<=0.000001:
			state.hp=0.0;state.left=0.0;state.charge=0.0;state.growing=false
			state.damaged=false
		elif can_grow and state.charge>=threshold-0.000001:
			var gain:float=GROWTH if state.growing else INITIAL
			state.hp=minf(unit.max_hp*LIMIT,float(state.hp)+unit.max_hp*gain)
			state.left=DURATION;state.charge=0.0;state.growing=true
			if gain==INITIAL:unit.queue_redraw()
	if not is_equal_approx(old_hp,state.hp):unit.queue_redraw()

static func absorb(unit,damage:float) -> float:
	if unit.special.has("furnace_prone"):return preload("res://scripts/units/furnace_legend.gd").absorb(unit,damage)
	if damage>0:interrupt_recovery(unit)
	var shield:=amount(unit)
	if damage<=0 or shield<=0:return damage
	var absorbed:=minf(shield,damage)
	var state:Dictionary=unit.special[KEY]
	state.hp=maxf(0,shield-absorbed)
	state.damaged=true
	state.charge=0.0
	unit.queue_redraw()
	if state.hp<=0:
		state.left=0.0;state.charge=0.0;state.growing=false
		state.damaged=false
		# Snapshot before a lethal remainder turns the hero into a weaponless wreck.
		var weapon:Dictionary=unit._active_weapon().duplicate(true)
		var reference_weapon:=weapon.duplicate(true)
		weapon.damage=float(weapon.get("damage",0))*DAMAGE
		var bonus:Dictionary=unit.bonuses.duplicate()
		if CombatMath.FinalDamage.active():bonus.reference_weapon=reference_weapon
		bonus.equipment_secondary=true
		# Avoid recursive receive_hit while the triggering damage is still resolving.
		burst.call_deferred(unit,unit._battle_world(),unit.global_position,unit.side,weapon,bonus)
	return damage-absorbed

static func burst(source,world,center:Vector2,side:String,weapon:Dictionary,bonus:Dictionary) -> void:
	if not is_instance_valid(world):return
	Wave.spawn(world,center,RADIUS)
	Effects.spawn_impact(center,COLOR,24.0)
	Effects.spawn_sparks(center,12,COLOR)
	Effects.spawn_text(center,"破盾",COLOR)
	var attacker=source if is_instance_valid(source) else null
	for target in world.units+world.buildings:
		if not AlliedAbilities.alive(target) or not BattleRequest.is_house(target.side) or BattleRequest.friendly(target.side,side):continue
		if target is Unit and target.embarked_in!=null:continue
		var point:Vector2=target.closest_footprint_point(center) if target is Building else target.global_position
		if point.distance_squared_to(center)>RADIUS*RADIUS:continue
		var damage:=CombatMath.full_damage(weapon,target.armor,bonus,null,target.ra2_armor,0.0,target)
		target.receive_hit(damage,"explosion",bonus,attacker,str(weapon.get("ra2_warhead","")))

static func draw(unit) -> void:
	if amount(unit)<=0:return
	var strength:=clampf(amount(unit)/maxf(1,maximum(unit)),0,1)
	var bounds:Rect2=unit._body_bounds
	var center:Vector2=bounds.get_center() if bounds.has_area() else Iso.dir(unit.art_center()-unit.global_position)
	var extent:=Vector2(maxf(unit.radius,bounds.size.x*0.55)+6,maxf(unit.radius*0.5,bounds.size.y*0.55)+6)
	var points:=PackedVector2Array()
	for i in 33:
		var a:=TAU*i/32.0
		points.append(center+Vector2(cos(a),sin(a))*extent)
	unit.draw_colored_polygon(points,Color(COLOR,0.035+strength*0.04))
	unit.draw_polyline(points,Color(COLOR,0.3+strength*0.35),1.4,true)

static func draw_bar(unit,ci:CanvasItem,rect:Rect2) -> void:
	var current := amount(unit)
	if current<=0:return
	var bar:=Rect2(rect.position+Vector2(0,-5),Vector2(rect.size.x,3))
	ci.draw_rect(bar,Color("#122b42"))
	bar.size.x*=clampf(current/maxf(1,maximum(unit)),0,1)
	ci.draw_rect(bar,COLOR)
