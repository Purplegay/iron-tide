extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const D=preload("res://scripts/units/leizhu_defense.gd")
const KEY="leizhu"
const GROUP="leizhu_protectors"

static func install(unit) -> void:
	if D.rank(unit)>=4 and not unit.is_in_group(GROUP):unit.add_to_group(GROUP)

static func stopped(unit) -> bool:
	return float(unit.special.get(KEY,{}).get("shutdown_left",0))>0

static func ordinary(kind:String,bonus:Dictionary) -> bool:
	return kind not in ["crush","erase","execute"] and not bonus.get("force_execute",false) and not bonus.get("leizhu_transfer",false)

static func available(unit) -> bool:
	if D.rank(unit)<4 or unit.embarked_in!=null or unit._stun_timer>0 or AlliedAbilities.frozen(unit) or stopped(unit):return false
	var world=R.world(unit)
	return world!=null and not world.house_defeated(unit.side)

static func vehicle(target) -> bool:
	return preload("res://scripts/units/leizhu_command.gd").ground_vehicle(target) and not target.is_harvester and not target.special.has("academy_hero") and not target._active_weapon().is_empty() and not AlliedAbilities.frozen(target)

static func protected(unit):
	if not available(unit):return null
	var nearest=null;var distance:=pow(P.number("hero/TTNK/survival","protect_radius")*R.CELL,2)
	for target in R.world(unit).units:
		if not vehicle(target) or target.side!=unit.side:continue
		var gap:float=unit.position.distance_squared_to(target.position)
		if gap<=distance and (nearest==null or gap<distance):nearest=target;distance=gap
	return nearest

static func divert(target,amount:float,kind:String,bonus:Dictionary,source) -> float:
	if amount<=0 or not ordinary(kind,bonus):return amount
	var world=R.world(target)
	if world==null or not world.get_tree().has_group(GROUP) or not vehicle(target):return amount
	var hero=null;var nearest:=INF
	for candidate in world.get_tree().get_nodes_in_group(GROUP):
		if not world.is_ancestor_of(candidate) or candidate.side!=target.side or not available(candidate):continue
		var gap:float=candidate.position.distance_squared_to(target.position)
		if gap>pow(P.number("hero/TTNK/survival","protect_radius")*R.CELL,2) or gap>=nearest or protected(candidate)!=target:continue
		hero=candidate;nearest=gap
	if hero==null:return amount
	transfer(hero,amount*P.number("hero/TTNK/survival","transfer_ratio")*(1.0-P.number("hero/TTNK/survival","transfer_defense")),source)
	return amount*(1.0-P.number("hero/TTNK/survival","transfer_ratio"))

static func transfer(unit,amount:float,source) -> void:
	# Final transferred damage: shield consumers only, never the ordinary offense/defense or hit-trigger pipeline.
	var before:float=unit.hp
	amount=preload("res://scripts/expedition/rules.gd").absorb(unit,amount)
	# This hero never inherits legacy tank/Furnace shields or their break attacks.
	amount=preload("res://scripts/units/expansion_heroes.gd").absorb(unit,amount)
	amount=preload("res://scripts/units/progression_expansion_2.gd").absorb(unit,amount)
	if unit.special.has("boris_radio_shield"):amount=preload("res://scripts/units/boris_radio.gd").absorb(unit,amount)
	amount=preload("res://scripts/units/leizhu_command.gd").absorb(unit,amount)
	amount=preload("res://scripts/units/leizhu.gd").absorb(unit,amount)
	amount=D.absorb(unit,amount)
	amount=absorb(unit,amount)
	amount=before_damage(unit,amount,"transfer",{})
	unit.hp=maxf(0,unit.hp-amount)
	unit.special[KEY].transfer_flash=.25
	if unit.hp<=0:unit._die(source);return
	if unit.hp<before:unit._hp_ghost=maxf(unit._hp_ghost,before/unit.max_hp);unit._hp_flash=1.0
	unit.queue_redraw()

static func absorb(unit,amount:float) -> float:
	var s:Dictionary=unit.special.get(KEY,{})
	if amount<=0 or not s.has("emergency_shield"):return amount
	var used:=minf(amount,float(s.emergency_shield));s.emergency_shield-=used
	if s.emergency_shield<=0:s.erase("emergency_shield")
	unit.queue_redraw();return amount-used

static func before_damage(unit,amount:float,kind:String,bonus:Dictionary) -> float:
	if D.rank(unit)<5 or amount<=0 or amount<unit.hp or not ordinary(kind,bonus) or unit.special.get("house_eliminated",false):return amount
	var s:Dictionary=unit.special[KEY]
	if s.get("shutdown_used",false):return amount
	s.shutdown_used=true;s.shutdown_left=P.number("hero/TTNK/survival","shutdown_seconds");s.emergency_shield=unit.max_hp*P.number("hero/TTNK/survival","shutdown_shield")
	unit.order_stop();unit._cancel_burst();unit.velocity=Vector2.ZERO
	var world=R.world(unit)
	if world!=null:
		preload("res://scripts/units/leizhu_cards.gd").clear_owner(world,unit)
		world._update_power();world.queue_redraw()
	unit.queue_redraw()
	return maxf(0,unit.hp-P.number("hero/TTNK/survival","shutdown_keep_hp"))

static func tick(unit,dt:float) -> void:
	if not R.active(unit):return
	var s:Dictionary=unit.special[KEY]
	R.timer(s,"transfer_flash",maxf(0,dt))
	if not stopped(unit):return
	s.shutdown_left=maxf(0,float(s.shutdown_left)-maxf(0,dt))
	if s.shutdown_left<=.000001:
		s.erase("shutdown_left")
		unit.hp=maxf(unit.hp,unit.max_hp*P.number("hero/TTNK/survival","shutdown_health"))
		var world=R.world(unit)
		if world!=null:world._update_power()
	unit.queue_redraw()

static func entries(unit) -> Array:
	if D.rank(unit)<4:return []
	const V=preload("res://scripts/units/expansion_visual.gd")
	var rows:Array=[];var s:Dictionary=unit.special[KEY];var target=protected(unit)
	rows.append(V.row("分流保护 · "+target.display_name if target!=null else "分流保护 · 当前无有效保护目标",0,false,"guard"))
	if D.rank(unit)>=5:rows.append(V.row("紧急停堆 · 本局已用" if s.get("shutdown_used",false) else "紧急停堆 · 本局可用",0,false,"guard"))
	if stopped(unit):rows.append(V.row("停堆 · 禁止移动／攻击／施法／供电／分流",s.shutdown_left,true,"electric"))
	if s.has("emergency_shield"):rows.append(V.row("停堆应急盾 · %.0f"%s.emergency_shield,0,false,"guard"))
	return rows

static func draw(unit) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	if unit.selected:
		var target=protected(unit)
		if target!=null:unit.draw_line(Vector2.ZERO,Iso.dir(target.position-unit.position),Color(.35,.9,.65,.65),2,true)
	if s.has("emergency_shield"):unit.draw_arc(Vector2.ZERO,unit.radius+22,0,TAU,32,Color(.4,1,.7,.8),2,true)
	if stopped(unit):unit.draw_arc(Vector2.ZERO,unit.radius+26,-PI*.5,-PI*.5+TAU*float(s.shutdown_left)/3,32,Color.ORANGE,3,true)
	if s.has("transfer_flash"):unit.draw_arc(Vector2.ZERO,unit.radius+20,0,TAU,24,Color(.35,.9,.65,float(s.transfer_flash)*4),3,true)
