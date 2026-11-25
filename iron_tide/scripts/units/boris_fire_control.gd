extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY="commando_hero_v2"
const ACTIVE="ap_boris_corridor"
const PASSIVE="ps_boris_receipt"
const EVENTS="boris_corridors"
const Contracts=preload("res://scripts/rules/expansion_contracts.gd")

static func active(unit) -> bool:
	return is_instance_valid(unit) and unit is Unit and unit.special.get("academy_hero")=="BORIS" and unit.special.has(KEY) and R.active(unit)

static func calling(unit) -> bool:
	return unit.special.get(KEY,{}).has("corridor_call")

static func ready(unit,ab) -> bool:
	return active(unit) and ab.id==ACTIVE and ab.ready() and not calling(unit) and unit.embarked_in==null and unit._stun_timer<=0 and not AlliedAbilities.frozen(unit)

static func points(unit,at:Vector2) -> Array:
	var direction:Vector2=unit.position.direction_to(at)
	if direction.is_zero_approx():direction=Vector2.from_angle(unit.hull_angle)
	var result:Array=[]
	for i in P.count("mechanic/ap_boris_corridor","count"):result.append(at+direction*P.number("mechanic/ap_boris_corridor","spacing")*i*R.CELL)
	return result

static func legal(unit,at:Vector2) -> bool:
	if not at.is_finite() or unit.position.distance_to(at)>P.number("mechanic/ap_boris_corridor","range")*R.CELL:return false
	var world=R.world(unit)
	if not world.position_visible_to(unit.side,at):return false
	for point in points(unit,at):
		if not Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).has_point(point) or world.in_water_world(point) or not world.position_explored_by(unit.side,point):return false
	return true

static func cast(unit,ab,at:Vector2) -> bool:
	if not ready(unit,ab) or unit.has_move_order or unit.velocity.length_squared()>1 or not legal(unit,at):return false
	unit._cancel_burst()
	unit.special[KEY].corridor_call={"left":P.number("mechanic/ap_boris_corridor","call_seconds"),"origin":unit.position,"points":points(unit,at),"side":unit.side}
	preload("res://scripts/units/boris_radio.gd").started(unit)
	unit.queue_redraw()
	return true

static func preview(unit) -> Dictionary:
	var count:=int(unit.special.get(KEY,{}).get("receipt_count",0)) if unit.passive.get("id")==PASSIVE else 0
	return {"count":count,"damage":1.0+count*R.value(unit,PASSIVE,"damage"),"radius":1.0+count*R.value(unit,PASSIVE,"radius")}

static func consume(unit) -> Dictionary:
	var receipt:=preview(unit)
	unit.special[KEY].erase("receipt_count")
	unit.queue_redraw()
	return receipt

static func tick(unit,dt:float) -> void:
	if not active(unit):return
	var s:Dictionary=unit.special[KEY]
	R.timer(s,"receipt_cd",dt)
	if s.has("receipt_quiet"):
		R.timer(s,"receipt_quiet",dt)
		if not s.has("receipt_quiet"):s.erase("receipt_count")
	if not calling(unit):return
	var call:Dictionary=s.corridor_call
	if unit.side!=call.side or unit.has_move_order or unit.position.distance_squared_to(call.origin)>.01 or unit.embarked_in!=null or unit._stun_timer>0 or AlliedAbilities.frozen(unit):
		s.erase("corridor_call");unit.queue_redraw();return
	call.left-=dt
	if call.left>0:return
	s.erase("corridor_call")
	var index:=UnitSkillLayout.find(unit,ACTIVE)
	if index<0:return
	var ab:Ability=unit.ability_at(index)
	if not ab.ready():return
	var receipt:=consume(unit)
	var primary:Dictionary=unit._weapon_for_target(null)
	var raw:=float(primary.get("damage",0))*R.value(unit,ACTIVE,"damage")
	var bonus:Dictionary=unit.bonuses.duplicate(true)
	bonus.expansion_extra=true;bonus.reference_weapon={"damage":raw,"attack_type":"explosive"}
	R.world(unit).allied_state.get_or_add(EVENTS,[]).append({"points":call.points,"next":P.number("mechanic/ap_boris_corridor","warning_seconds"),"index":0,"owner":unit,"side":unit.side,"raw":raw,"damage":CombatMath.with_offense(raw,bonus)*float(receipt.damage),"radius":P.number("mechanic/ap_boris_corridor","base_radius")*R.CELL*float(receipt.radius),"bonus":bonus,"receipt":receipt})
	ab.trigger_cooldown();unit.queue_redraw();R.world(unit).queue_redraw()

static func damaged(target,source,amount:float,bonus:Dictionary) -> void:
	if amount<=0 or R.temporary(target):return
	var actor=R.owner(source)
	var side:String=source.owner_side if source is Projectile else (actor.side if is_instance_valid(actor) else "")
	if active(target) and not side.is_empty() and side!="neutral" and not BattleRequest.friendly(side,target.side):target.special[KEY].receipt_quiet=P.number("mechanic/ps_boris_receipt","quiet_seconds")
	if not active(actor) or not R.enemy(actor,target):return
	var s:Dictionary=actor.special[KEY]
	s.receipt_quiet=P.number("mechanic/ps_boris_receipt","quiet_seconds")
	if actor.passive.get("id")!=PASSIVE or s.has("receipt_cd") or bonus.get("expansion_extra",false) or bonus.get("expansion_scatter",false) or bonus.get("equipment_secondary",false):return
	if source is Projectile and source.target!=target:return
	var weapon:=str(bonus.get("impact_weapon","")).trim_prefix("YR_CAP_").trim_prefix("YR_SOV_")
	if weapon not in ["AKM","AKME"]:return
	s.receipt_count=mini(P.count("mechanic/ps_boris_receipt","stack_cap"),int(s.get("receipt_count",0))+1);s.receipt_cd=P.number("mechanic/ps_boris_receipt","stack_interval")
	actor.queue_redraw()

static func dispatched(unit,jets:Array) -> void:
	if not active(unit) or jets.is_empty():return
	preload("res://scripts/units/boris_command.gd").dispatched(unit,jets)
	var receipt:=consume(unit)
	for jet in jets:
		jet.special.strike_run.boris_hero=true
		jet.special.strike_run.boris_receipt=receipt.duplicate()

static func sortie_fired(jet) -> void:
	var run:Dictionary=jet.special.strike_run
	if run.get("boris_hero",false):run.boris_dropped=true
	if not run.get("boris_hero",false) or run.get("boris_counted",false):return
	for member in run.get("wing",[jet]):
		if is_instance_valid(member):member.special.strike_run.boris_counted=true
	var world=R.world(jet)
	if jet.side=="ally" and Contracts.eligible(world,"BORIS") and BattleRequest.combat_context.get("expedition",{}).is_empty():
		var p:=Contracts.progress(world,"BORIS");p.sorties=int(p.get("sorties",0))+1

static func prepare_mig(shot,jet) -> void:
	var run:Dictionary=jet.special.strike_run
	if not run.get("boris_hero",false):return
	shot.attacker_bonus.boris_mig=true
	shot.attacker_bonus.boris_receipt=run.get("boris_receipt",{}).duplicate()
	preload("res://scripts/units/boris_command.gd").prepare_mig(shot,jet)
	var scale:float=run.get("boris_receipt",{}).get("radius",1.0)
	if shot.aoe>0:shot.aoe*=scale;shot.splinters.spread_scale=scale

static func impact(target,amount:float,bonus:Dictionary) -> float:
	return amount*float(bonus.get("boris_receipt",{}).get("damage",1.0)) if target is Building and bonus.get("boris_mig",false) else amount

static func world_tick(world,dt:float) -> void:
	preload("res://scripts/units/boris_radio.gd").world_tick(world,dt)
	preload("res://scripts/units/boris_command.gd").world_tick(world)
	if not world.allied_state.has(EVENTS):return
	var events:Array=world.allied_state[EVENTS]
	for event in events.duplicate():
		if world.house_defeated(event.side):events.erase(event);continue
		event.next-=dt
		while event.next<=0 and event.index<event.points.size():
			var at:Vector2=event.points[event.index]
			event.index+=1;event.next+=P.number("mechanic/ap_boris_corridor","strike_interval")
			explode(world,event,at)
		if event.index>=event.points.size():events.erase(event)
	if events.is_empty():world.allied_state.erase(EVENTS)
	world.queue_redraw()

static func explode(world,event:Dictionary,at:Vector2) -> void:
	for target in world.units.duplicate()+world.buildings.duplicate():
		if not AlliedAbilities.alive(target) or target.side=="neutral" or BattleRequest.friendly(event.side,target.side):continue
		if target is Unit and (target.is_air_target() or target.embarked_in!=null or NavalContact.submerged(target)):continue
		var point:Vector2=target.closest_footprint_point(at) if target is Building else target.position
		if point.distance_to(at)>float(event.radius):continue
		var armor:=preload("res://scripts/units/tanya_breach.gd").armor_factor(target)
		var bonus:Dictionary=event.bonus.duplicate()
		bonus.hit_reference_damage=float(event.raw)*armor*float(bonus.get("veteran_attack",1.0))
		var owner=event.owner if is_instance_valid(event.owner) else null
		target.receive_hit(float(event.damage)*armor,"explosive",bonus,owner)
	Effects.spawn_impact(at,Color(1,.35,.15),event.radius)

static func draw_world(world) -> void:
	preload("res://scripts/units/boris_radio.gd").draw_world(world)
	for event in world.allied_state.get(EVENTS,[]):
		for i in range(int(event.index),3):
			var point:Vector2=event.points[i]
			if event.side!="ally" and not world.position_visible_to("ally",point):continue
			Iso.outline(world,Iso.ground_circle(point,event.radius),Color(1,.25,.12,.7),1.5)

static func draw_preview(world,unit,point:Vector2) -> void:
	var color:=Color(1,.5,.2,.8) if legal(unit,point) else Color(1,.15,.15,.55)
	var radius:=P.number("mechanic/ap_boris_corridor","base_radius")*R.CELL*float(preview(unit).radius)
	for at in points(unit,point):Iso.outline(world,Iso.ground_circle(at,radius),color,2.0)
	Iso.outline(world,Iso.ground_circle(unit.position,P.number("mechanic/ap_boris_corridor","range")*R.CELL),Color(1,.5,.2,.3),1.0)

static func entries(unit) -> Array:
	if not active(unit):return []
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special[KEY]
	var rows:Array=[]
	if unit.passive.get("id")==PASSIVE:
		var receipt:=preview(unit)
		rows.append(V.row("校射回执 · %d/3 · 增伤%d%% / 扩圈%d%%"%[receipt.count,roundi((receipt.damage-1)*100),roundi((receipt.radius-1)*100)],float(s.get("receipt_quiet",0)),false,"focus"))
	if calling(unit):rows.append(V.row("红色走廊 · 静止呼叫",s.corridor_call.left,false,"hourglass"))
	return rows
