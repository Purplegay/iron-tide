extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const CARD:="ap_overload_seal"
const KEY:="overload_seal"
const TARGETS:="expansion_overload_targets"
const EVENTS:="expansion_overload_bursts"
const CASTERS:=["SHK","TTNK","R3TESLA"]

static func combat_target(target) -> bool:
	if not AlliedAbilities.alive(target) or R.temporary(target):return false
	if target is Building:return not target.weapon.is_empty() and float(target.weapon.get("damage",0))>0
	return preload("res://scripts/units/expansion_2_convoy.gd").vehicle(target) and float(target._active_weapon().get("damage",0))>0

static func available(unit,target) -> bool:
	if not R.enemy(unit,target) or not combat_target(target):return false
	var world=R.world(unit)
	return world!=null and world.actor_visible_to(unit.side,target) and R.point(unit,target).distance_to(unit.position)<=P.number("mechanic/ap_overload_seal","range")*R.CELL and float(target.special.get(KEY,{}).get("left",0))<=0

static func pick(unit,point:Vector2):
	var world=R.world(unit)
	if world==null:return null
	if not point.is_finite():return unit.attack_target if available(unit,unit.attack_target) else null
	var target=world.support_target_from_pick(point,world._pick_at(point,false))
	return target if available(unit,target) else null

static func cast(unit,ab,point:Vector2) -> bool:
	var target=pick(unit,point)
	if target==null:return false
	var weapon:Dictionary={"damage":float(unit._active_weapon().get("damage",0))*R.value(unit,CARD,"damage"),"attack_type":"tesla"}
	var bonus:Dictionary=unit.bonuses.duplicate(true)
	bonus.expansion_extra=true;bonus.damage_owner_side=unit.side;bonus.reference_weapon=weapon.duplicate(true)
	target.special[KEY]={"left":R.value(unit,CARD,"duration"),"cooldown":0.0,"remaining":P.count("mechanic/ap_overload_seal","count"),"owner":unit,"side":unit.side,"target_side":target.side,"weapon":weapon,"bonus":bonus}
	var targets:Array=R.world(unit).allied_state.get_or_add(TARGETS,[])
	if not targets.has(target):targets.append(target)
	ab.trigger_cooldown();target.queue_redraw()
	return true

static func valid(actor,state:Dictionary) -> bool:
	return not state.is_empty() and BattleRequest.extensions_enabled() and combat_target(actor) and not R.world(actor).house_defeated(state.side) and actor.side==state.target_side and not BattleRequest.friendly(state.side,actor.side) and actor.side!="neutral"

static func cast_selected(world,point:Vector2) -> int:
	var used:=0
	for unit in world.selected_units:
		if AlliedAbilities.alive(unit) and unit.use_ability(UnitSkillLayout.find(unit,CARD),point):used+=1
	return used

static func fired(actor) -> void:
	if not actor.special.has(KEY):return
	var state:Dictionary=actor.special[KEY]
	if not valid(actor,state) or state.left<=0 or state.cooldown>0.000001 or state.remaining<=0:return
	state.remaining-=1;state.cooldown=P.number("mechanic/ap_overload_seal","interval")
	# Queue after the ordinary shot. Death or a later order cannot undo an already fired volley.
	R.world(actor).allied_state.get_or_add(EVENTS,[]).append({"point":actor.position,"primary":actor,"side":state.side,"owner":state.owner,"weapon":state.weapon.duplicate(true),"bonus":state.bonus.duplicate(true)})
	actor.queue_redraw()

static func ground(target) -> bool:
	if not AlliedAbilities.alive(target) or R.temporary(target):return false
	return target is Building or (target is Unit and not target.is_air_target() and not target.is_naval and target.embarked_in==null)

static func explode(world,event:Dictionary) -> void:
	var source=event.owner
	if not AlliedAbilities.alive(source) or source.side!=event.side:source=null
	for target in world.units.duplicate()+world.buildings.duplicate():
		if not ground(target) or target.side=="neutral" or BattleRequest.friendly(event.side,target.side):continue
		var point:Vector2=target.closest_footprint_point(event.point) if target is Building else target.position
		if not is_same(target,event.primary) and point.distance_to(event.point)>P.number("mechanic/ap_overload_seal","radius")*R.CELL:continue
		var damage:=CombatMath.full_damage(event.weapon,target.armor,event.bonus,null,target.ra2_armor,0,target)
		target.receive_hit(damage,"tesla",event.bonus,source)
		if world.actor_visible_to("ally",target):Effects.spawn_beam(event.point,Effects.hit_position(target),Color.CYAN,"electric",2,.2)
	if world.position_visible_to("ally",event.point):Effects.spawn_impact(event.point,Color.CYAN,P.number("mechanic/ap_overload_seal","radius")*R.CELL)

static func world_tick(world,dt:float) -> void:
	var events:Array=world.allied_state.get(EVENTS,[])
	world.allied_state.erase(EVENTS)
	for event:Dictionary in events:
		if not world.house_defeated(event.side):explode(world,event)
	var targets:Array=world.allied_state.get(TARGETS,[])
	for actor in targets.duplicate():
		if not is_instance_valid(actor):targets.erase(actor);continue
		var state:Dictionary=actor.special.get(KEY,{})
		if valid(actor,state):
			state.left-=dt;state.cooldown=maxf(0,float(state.cooldown)-dt)
		if not valid(actor,state) or state.left<=.000001 or state.remaining<=0:
			actor.special.erase(KEY);targets.erase(actor)
		actor.queue_redraw()
	if targets.is_empty():world.allied_state.erase(TARGETS)

static func entries(actor) -> Array:
	var state:Dictionary=actor.special.get(KEY,{})
	if not valid(actor,state) or state.left<=0:return []
	var row:=preload("res://scripts/units/expansion_visual.gd").row("过载封条",state.left,true,"spark")
	row.text="普通开火触发电爆 · 剩余 %d / 3 · 最快每秒一次"%state.remaining
	row.stacks=state.remaining;row.limit=P.count("mechanic/ap_overload_seal","count")
	return [row]

static func draw_fields(canvas,world) -> void:
	for actor in world.allied_state.get(TARGETS,[]):
		if not AlliedAbilities.alive(actor) or not world.actor_visible_to("ally",actor):continue
		var state:Dictionary=actor.special.get(KEY,{})
		if not valid(actor,state):continue
		var center:Vector2=Iso.dir(actor.position)+Vector2(0,-actor.radius-14)
		canvas.draw_line(center+Vector2(-12,-9),center+Vector2(12,9),Color.CYAN,3)
		canvas.draw_line(center+Vector2(12,-9),center+Vector2(-12,9),Color.CYAN,3)
		canvas.draw_string(ThemeDB.fallback_font,center+Vector2(-32,-13),"过载 %d/3 %.1fs"%[state.remaining,maxf(0,state.left)],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.CYAN)
