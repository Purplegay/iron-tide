extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Ordinary infantry talents. Primary hits carry their provenance to the actual death event.
const R=preload("res://scripts/units/expansion_rules.gd")
const Native=preload("res://scripts/units/expansion_2_soviet.gd")
const KEY:="progression_v2"
const SHARDS:="expansion_follow_shards"
const TALENTS:={"SNIPE":"sniper_relocate","E2":"alternate_advance","SHK":"reserve_transfer","FLAKT":"following_shard"}

static func state(unit) -> Dictionary:
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func eligible(unit) -> bool:
	return TALENTS.has(unit.unit_id) and R.talent_rank(unit,TALENTS[unit.unit_id])>=0

static func timer(s:Dictionary,key:String,dt:float) -> void:
	if not s.has(key):return
	s[key]=maxf(0,float(s[key])-dt)
	if s[key]<=.000001:s.erase(key)

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	var speed_before:bool=s.has("relocate_left")
	var advance_before:bool=s.has("advance_left")
	var marked:bool=s.has("following_mark")
	for key in ["relocate_left","relocate_cd","advance_left","advance_cd","shard_cd","following_mark"]:timer(s,key,dt)
	if marked:
		if not aircraft(unit):s.erase("following_mark")
		unit.queue_redraw()
	if speed_before and not s.has("relocate_left"):unit._recompute_bonuses();unit.queue_redraw()
	if advance_before and not s.has("advance_left"):unit._recompute_bonuses();unit.queue_redraw()
	if unit.unit_id!="E2" or not eligible(unit):return
	var previous:Vector2=s.get("advance_position",unit.position)
	s.advance_position=unit.position
	var available:bool=unit.embarked_in==null and not AlliedAbilities.frozen(unit) and unit._stun_timer<=0
	var moving:bool=available and previous.distance_squared_to(unit.position)>.0001
	if moving:
		s.advance_moving=minf(P.number("mechanic/infantry_v2","advance_prepare"),float(s.get("advance_moving",0))+dt)
	else:
		if available and float(s.get("advance_moving",0) )>=P.number("mechanic/infantry_v2","advance_prepare")-.000001 and not s.has("advance_cd"):
			s.advance_left=P.number("mechanic/infantry_v2","advance_duration");s.advance_cd=P.number("mechanic/infantry_v2","advance_cooldown");unit._recompute_bonuses();unit.queue_redraw()
		s.advance_moving=0.0

static func advancing(unit) -> bool:
	var s:Dictionary=unit.special.get(KEY,{})
	return unit.unit_id=="E2" and eligible(unit) and s.get("side",unit.side)==unit.side and float(s.get("advance_left",0))>0

static func attack(unit) -> float:
	return 1.0+R.talent(unit,"alternate_advance","attack") if advancing(unit) else 1.0

static func modify_reload(unit,seconds:float) -> float:
	if not advancing(unit):return seconds
	return seconds*(1.0-R.talent(unit,"alternate_advance","reload"))

static func speed(unit) -> float:
	return 1.0+R.talent(unit,"sniper_relocate","speed") if unit.unit_id=="SNIPE" and unit.special.get(KEY,{}).has("relocate_left") else 1.0

static func discharge(unit,natural:float) -> float:
	if not eligible(unit):return natural
	var s:=state(unit)
	var carried:float=float(s.get("transfer_damage",0))
	s.transfer_shot={"extra":maxf(0,natural-1.0),"reused":carried>0}
	s.erase("transfer_damage")
	return 1.0+maxf(natural-1.0,carried)

static func shot(unit,bonus:Dictionary) -> void:
	if not eligible(unit):return
	if unit.unit_id=="SHK":bonus.expansion_transfer=state(unit).get("transfer_shot",{}).duplicate(true)
	if unit.unit_id=="FLAKT":bonus.expansion_shard_weapon=unit._active_weapon().duplicate(true)

static func damaged(unit,target,source,amount:float,bonus:Dictionary) -> void:
	if target is Unit:target.special.get(KEY,{}).erase("infantry_lethal")
	if not unit is Unit or not eligible(unit) or not R.enemy(unit,target) or not target is Unit or R.temporary(target) or not Native.primary(source,target,bonus):return
	if unit.unit_id=="FLAKT" and amount>0:attach(unit,target,bonus)
	if amount<target.hp or unit.unit_id not in ["SNIPE","SHK"]:return
	if unit.unit_id=="SNIPE" and not AlliedAbilities.infantry(target):return
	if unit.unit_id=="SHK" and (not target.is_in_group("combatants") or target.unit_id in ["V3ROCKET","DMISL"]):return
	state(target).infantry_lethal={"owner":unit,"source":source,"transfer":bonus.get("expansion_transfer",{}).duplicate(true)}

static func killed(world,target,source) -> void:
	if target is Unit:
		# Capture the last airborne position before the death animation moves/removes the actor.
		for shard:Dictionary in world.allied_state.get(SHARDS,[]).duplicate():
			if is_same(shard.target,target):
				if not target.is_air_target():world.allied_state[SHARDS].erase(shard);continue
				shard.point=target.position;shard.visual=Effects.hit_position(target);shard.target=null
	var packet:Dictionary=target.special.get(KEY,{}).get("infantry_lethal",{})
	target.special.get(KEY,{}).erase("infantry_lethal")
	if packet.is_empty() or not is_same(packet.source,source):return
	var unit=packet.owner
	if not AlliedAbilities.alive(unit) or not eligible(unit) or BattleRequest.friendly(unit.side,target.side):return
	var s:=state(unit)
	if unit.unit_id=="SNIPE" and not s.has("relocate_cd"):
		s.relocate_left=P.number("mechanic/infantry_v2","relocate_duration");s.relocate_cd=P.number("mechanic/infantry_v2","relocate_cooldown");unit._recompute_bonuses();R.label(unit,"转移阵位")
	elif unit.unit_id=="SHK" and not packet.transfer.get("reused",false):
		var extra:float=float(packet.transfer.get("extra",0))
		if extra>0:
			s.transfer_damage=extra*R.talent(unit,"reserve_transfer","damage")
			R.label(unit,"蓄电转储")

static func aircraft(target) -> bool:
	return AlliedAbilities.alive(target) and target is Unit and target.is_air_target() and target.embarked_in==null and not R.temporary(target) and target.unit_id not in ["V3ROCKET","DMISL"]

static func attach(unit,target,bonus:Dictionary) -> void:
	var s:=state(unit)
	if s.has("shard_cd") or not aircraft(target) or not bonus.has("expansion_shard_weapon"):return
	var weapon:Dictionary=bonus.expansion_shard_weapon.duplicate(true)
	if not CombatMath.can_hit_air(weapon):return
	weapon.damage=float(weapon.damage)*R.talent(unit,"following_shard","damage")
	var packet:Dictionary=bonus.duplicate(true)
	packet.erase("expansion_shard_weapon");packet.expansion_extra=true;packet.reference_weapon=weapon.duplicate(true);packet.damage_owner_side=unit.side
	R.world(unit).allied_state.get_or_add(SHARDS,[]).append({"target":target,"point":target.position,"visual":Effects.hit_position(target),"left":P.number("mechanic/infantry_v2","shard_delay"),"owner":unit,"side":unit.side,"weapon":weapon,"bonus":packet})
	s.shard_cd=P.number("mechanic/infantry_v2","shard_cooldown")
	state(target).following_mark=P.number("mechanic/infantry_v2","shard_delay");target.queue_redraw()

static func world_tick(world,dt:float) -> void:
	if not world.allied_state.has(SHARDS):return
	var rows:Array=world.allied_state[SHARDS]
	for shard:Dictionary in rows.duplicate():
		if world.house_defeated(shard.side):rows.erase(shard);continue
		var target=shard.target
		if AlliedAbilities.alive(target):
			if not aircraft(target) or BattleRequest.friendly(shard.side,target.side):rows.erase(shard);continue
			shard.point=target.position;shard.visual=Effects.hit_position(target)
		shard.left-=dt
		if shard.left>.000001:continue
		rows.erase(shard)
		var owner=shard.owner
		if not AlliedAbilities.alive(owner) or owner.side!=shard.side:owner=null
		for victim in world.units.duplicate():
			if not aircraft(victim) or victim.side=="neutral" or BattleRequest.friendly(shard.side,victim.side) or victim.position.distance_to(shard.point)>P.number("mechanic/infantry_v2","shard_radius")*R.CELL:continue
			var damage:=CombatMath.full_damage(shard.weapon,victim.armor,shard.bonus,null,victim.ra2_armor,0,victim)
			victim.receive_hit(damage,"bullet",shard.bonus,owner,str(shard.weapon.get("ra2_warhead","")))
		if world.position_visible_to("ally",shard.point):Effects.spawn_impact(shard.visual,Color.GOLD,P.number("mechanic/infantry_v2","shard_radius")*R.CELL)
	if rows.is_empty():world.allied_state.erase(SHARDS)

static func entries(unit) -> Array:
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	const V=preload("res://scripts/units/expansion_visual.gd")
	for row in [["relocate_left","转移阵位 · 加速"],["relocate_cd","转移阵位冷却"],["advance_cd","交替推进冷却"],["shard_cd","追身破片冷却"]]:
		if s.has(row[0]):out.append(V.row(row[1],s[row[0]],false,"attack"))
	if float(s.get("transfer_damage",0))>0:out.append(V.row("蓄电转储 · 永久储存至下一发 · +%.1f%%"%(float(s.transfer_damage)*100),0,false,"electric"))
	if s.has("advance_left"):out.append(V.row("交替推进 · 装填加速/攻击提升",s.advance_left,false,"attack"))
	elif float(s.get("advance_moving",0))>0:out.append(V.row("交替推进 · 移动蓄势",P.number("mechanic/infantry_v2","advance_prepare")-s.advance_moving,false,"move"))
	if s.has("following_mark"):out.append(V.row("追身破片 · 即将引爆",s.following_mark,true,"attack"))
	return out

static func draw(unit) -> void:
	if unit.special.get(KEY,{}).has("advance_left"):
		unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+5,0,TAU,24,Color.GOLD,1.5,true)
	if unit.special.get(KEY,{}).has("following_mark"):
		unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+7,0,TAU,24,Color.GOLD,2,true)
