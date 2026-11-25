extends RefCounted
## A world-owned cast pool survives its caster; recipients only carry a stable pool ID.
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"
const POOLS:="water_relays"
const SHIELD:="water_relay_shield"
const CARRIERS:="water_relay_carriers"
const CARD:="ap_escort_water"

static func begin(unit,targets:Array) -> int:
	var world=R.world(unit)
	var id:=int(world.allied_state.get("water_relay_next",0))+1
	world.allied_state.water_relay_next=id
	world.allied_state.get_or_add(POOLS,{})[id]={"side":unit.side,"targets":targets.duplicate(),"left":R.value(unit,CARD,"duration"),
		"stored":0.0,"cap":unit.max_hp*R.value(unit,CARD,"relay_cap"),"shield_duration":R.value(unit,CARD,"relay_duration")}
	return id

static func pool(unit,id:int) -> Dictionary:
	var world=R.world(unit)
	return world.allied_state.get(POOLS,{}).get(id,{}) if world!=null else {}

static func reduction(packet:Dictionary,defended:float,warhead:String) -> float:
	var fraction:float=packet.get("defense",0)
	if not packet.has("relay") or defended<=0 or fraction<=0 or fraction>=1:return 0.0
	# All post-water modifiers up to this point scale damage/reference together.
	# Compare both quantized amounts, so fractional reductions cannot invent reserves.
	var without:=defended/(1.0-fraction)
	return maxf(0,without-defended) if warhead in ["RA3_PRISM","RA3_EXPANSION"] else maxf(0,Ra2Damage.quantize(without)-Ra2Damage.quantize(defended))

static func record(unit,packet:Dictionary,saved:float) -> void:
	if saved<=0 or not packet.has("relay"):return
	var row:=pool(unit,int(packet.relay))
	if row.is_empty() or row.left<=0 or row.side!=unit.side or not row.targets.has(unit):return
	row.stored=minf(float(row.cap),float(row.stored)+saved)
	unit.queue_redraw()

static func valid_recipient(unit,side:String) -> bool:
	return AlliedAbilities.alive(unit) and unit is Unit and unit.side==side and unit.embarked_in==null and unit.is_naval and not unit.is_air_target() and not NavalContact.underwater_type(unit)

static func world_tick(world,dt:float) -> void:
	var carriers:Array=world.allied_state.get(CARRIERS,[])
	for unit in carriers.duplicate():
		if not AlliedAbilities.alive(unit) or amount(unit)<=0:carriers.erase(unit);continue
		tick(unit,dt)
		if amount(unit)<=0:carriers.erase(unit)
	if carriers.is_empty():world.allied_state.erase(CARRIERS)
	var pools:Dictionary=world.allied_state.get(POOLS,{})
	for id in pools.keys():
		var row:Dictionary=pools[id]
		row.targets=row.targets.filter(func(target):return valid_recipient(target,row.side))
		row.left-=dt
		if row.left>.000001 and not row.targets.is_empty() and not world.house_defeated(row.side):continue
		# Remove the pool before transfer; no recipient or repeated tick can settle it twice.
		pools.erase(id)
		for target in row.targets:
			var state:Dictionary=target.special.get(KEY,{})
			if state.has("water_guards"):
				state.water_guards=state.water_guards.filter(func(guard):return guard.get("relay",-1)!=id)
				if state.water_guards.is_empty():state.erase("water_guards")
			target.queue_redraw()
		if row.targets.is_empty() or world.house_defeated(row.side) or row.stored<=0:continue
		var chosen=row.targets[0]
		for target in row.targets:
			if target.hp/maxf(1,target.max_hp)<chosen.hp/maxf(1,chosen.max_hp):chosen=target
		var remaining:=maxf(0,float(row.shield_duration)+minf(0,float(row.left)))
		if remaining<=0:continue
		if not grant(chosen,float(row.stored),remaining):continue
		if world.actor_visible_to("ally",chosen):
			for target in row.targets:
				if target!=chosen and world.actor_visible_to("ally",target):Effects.spawn_beam(Effects.hit_position(target),Effects.hit_position(chosen),Color.CYAN,"laser",1.5,.25)
			Effects.spawn_text(Effects.hit_position(chosen),"余波接力 +"+HpBar.shield_number(row.stored),Color.CYAN)
	if pools.is_empty():world.allied_state.erase(POOLS)

static func grant(unit,amount:float,duration:float) -> bool:
	var state:Dictionary=unit.special.get_or_add(KEY,{"side":unit.side})
	var current:Dictionary=state.get(SHIELD,{})
	if amount<=float(current.get("hp",0)):return false
	state[SHIELD]={"hp":amount,"maximum":amount,"left":duration}
	var world=R.world(unit)
	if world!=null:
		var carriers:Array=world.allied_state.get_or_add(CARRIERS,[])
		if not carriers.has(unit):carriers.append(unit)
	unit.queue_redraw()
	return true

static func tick(unit,dt:float) -> void:
	var state:Dictionary=unit.special.get(KEY,{})
	if not state.has(SHIELD):return
	state[SHIELD].left-=dt
	if state[SHIELD].left<=.000001:state.erase(SHIELD)
	unit.queue_redraw()

static func amount(unit) -> float:
	if not unit.special.has(KEY):return 0.0
	var state:Dictionary=unit.special[KEY]
	return float(state[SHIELD].hp) if state.has(SHIELD) and state.get("side",unit.side)==unit.side else 0.0

static func absorb(unit,damage:float) -> float:
	if damage<=0 or amount(unit)<=0:return damage
	var state:Dictionary=unit.special[KEY]
	var taken:=minf(damage,amount(unit))
	state[SHIELD].hp-=taken
	if state[SHIELD].hp<=0:state.erase(SHIELD)
	unit.queue_redraw()
	return damage-taken

static func draw_bar(unit,canvas,rect:Rect2) -> void:
	if amount(unit)<=0:return
	var shield:Dictionary=unit.special[KEY][SHIELD]
	var bar:=Rect2(rect.position+Vector2(0,-5),Vector2(rect.size.x,3))
	canvas.draw_rect(bar,Color(.04,.15,.2,.9))
	bar.size.x*=clampf(amount(unit)/maxf(1,float(shield.maximum)),0,1)
	canvas.draw_rect(bar,Color(.2,1,.9))
