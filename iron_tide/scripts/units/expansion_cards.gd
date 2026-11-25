extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const ACTIVE=["ap_tracer_mark","ap_tidal_decoy","ap_seismic_anchor","ap_bomb_nests","ap_ink_mine","ap_mirror_fork"]

static func passive(actor) -> String:
	return str(BattleRequest.unit_loadout(actor.building_id).get("passive","")) if actor is Building and actor.side=="ally" else str(actor.passive.get("id","")) if actor is Unit else ""

static func cast(unit,ab,at:Vector2) -> bool:
	if ab.id=="ap_mirror_fork":return preload("res://scripts/units/mirror_fork.gd").cast(unit,ab)
	var s:=R.state(unit)
	var world=R.world(unit)
	match ab.id:
		"ap_tracer_mark":s.tracer_arm=P.number("mechanic/cards_legacy","tracer_arm");R.label(unit,"曳光待发 6s")
		"ap_tidal_decoy":
			var bait=R.summon(unit,"SUB",unit.position-Vector2.from_angle(unit.hull_angle)*R.CELL*P.number("mechanic/cards_legacy","bait_offset"),"bait",R.value(unit,ab.id,"life"),R.value(unit,ab.id,"hp"),0)
			if bait==null:return false
			s.dive=R.value(unit,ab.id,"dive");s.speed_bonus=R.value(unit,ab.id,"speed");s.speed_left=s.dive
			unit.special.erase("dive_remaining")
			var targets:Array=[]
			for enemy in world.units:
				if R.enemy(unit,enemy) and enemy.position.distance_to(bait.position)<=R.value(unit,ab.id,"radius")*R.CELL and enemy._weapon_domain_valid(bait):targets.append(enemy)
			targets.sort_custom(func(a,b):return a.position.distance_squared_to(bait.position)<b.position.distance_squared_to(bait.position))
			for i in mini(P.count("mechanic/cards_legacy","bait_targets"),targets.size()):
				R.state(targets[i]).taunt=bait;targets[i].attack_target=bait;targets[i].attack_ordered=true
				R.label(targets[i],"嘲讽 · 命中一次解除")
		"ap_seismic_anchor":
			if not unit._deployed or not at.is_finite() or unit.position.distance_to(at)>unit.attack_range or not world.position_visible_to(unit.side,at):return false
			var life:=R.value(unit,ab.id,"life")
			zones(world).append({"kind":"seismic","owner":unit,"point":at,"radius":P.number("mechanic/cards_legacy","seismic_radius")*R.CELL,"left":P.number("mechanic/cards_legacy","seismic_warning")+life,"end":P.number("mechanic/cards_legacy","seismic_warning")+life,"next":P.number("mechanic/cards_legacy","seismic_warning"),"age":0.0,"pulse":0,"damage":R.value(unit,ab.id,"damage"),"tick":R.value(unit,ab.id,"pulse"),"slow":R.value(unit,ab.id,"slow")})
		"ap_bomb_nests":s.nests={"left":0.0,"count":0,"origin":unit.position,"heading":unit.hull_angle}
		"ap_ink_mine":
			if AlliedAbilities.alive(unit.special.get("squid")) or unit.embarked_in!=null:return false
			if mine(unit,unit.position,"ink",P.number("mechanic/cards_legacy","ink_arm"))==null:return false
	ab.trigger_cooldown();unit._recompute_bonuses();R.label(unit,ab.display_name)
	return true

static func zones(world) -> Array:
	return world.allied_state.get_or_add("expansion_zones",[])

static func mine(unit,point:Vector2,kind:String,delay:float):
	var id:="ap_ink_mine" if kind=="ink" else "ap_bomb_nests"
	var bomb=R.summon(unit,"SQD" if kind=="ink" else "E1",point,kind,R.value(unit,id,"life")+delay,P.number("mechanic/cards_legacy","mine_health"),0)
	if bomb!=null:
		bomb.special.expansion_temporary.arm=delay
		if kind=="nest":
			preload("res://scripts/units/expansion_2_air.gd").firing(unit)
			bomb.special.expansion_temporary.drop_height=maxf(24.0,unit._visual_lift())
			bomb.display_name="空投弹巢"
		bomb.special.expansion_temporary.damage=R.value(unit,id,"damage")
	return bomb

static func tick(unit,dt:float) -> void:
	preload("res://scripts/units/mirror_fork.gd").tick(unit,dt)
	var s:=R.state(unit)
	for key in ["tracer_arm","relay_cd","relay_left","arc_idle","deck_cd","drone_cd","dive","speed_left"]:R.timer(s,key,dt)
	if not s.has("speed_left"):s.erase("speed_bonus")
	if not s.has("arc_idle"):s.arc_count=0;s.erase("arc_target")
	if s.has("mark"):
		s.mark.left-=dt
		if s.mark.left<=0 or s.mark.charges<=0:s.erase("mark")
	if s.has("taunt"):
		if not AlliedAbilities.alive(s.taunt):s.erase("taunt")
		elif not unit.has_move_order:unit.attack_target=s.taunt
	if s.has("crystals"):
		for i in s.crystals.size():s.crystals[i]-=dt
		s.crystals=s.crystals.filter(func(left):return left>0)
	if s.has("nests"):
		if unit._stun_timer>0 or AlliedAbilities.frozen(unit):s.erase("nests");return
		var n:Dictionary=s.nests;n.left-=dt
		while n.left<=0 and n.count<P.count("mechanic/cards_legacy","nests"):
			var at:Vector2=unit.position if unit._moving() else n.origin+Vector2.from_angle(n.heading)*(P.number("mechanic/cards_legacy","nest_spacing")*R.CELL*(n.count-(P.count("mechanic/cards_legacy","nests")-1)*.5))
			mine(unit,at,"nest",P.number("mechanic/cards_legacy","nest_arm"));n.count+=1;n.left+=P.number("mechanic/cards_legacy","nest_interval")
		if n.count>=P.count("mechanic/cards_legacy","nests"):s.erase("nests")

static func world_tick(world,dt:float) -> void:
	if world.allied_state.has("water_relays") or world.allied_state.has("water_relay_carriers"):preload("res://scripts/units/water_relay.gd").world_tick(world,dt)
	if world.allied_state.has("leizhu_courts"):preload("res://scripts/units/leizhu_cards.gd").world_tick(world,dt)
	preload("res://scripts/units/expansion_2_infantry.gd").world_tick(world,dt)
	preload("res://scripts/units/expansion_2_calibration.gd").world_tick(world,dt)
	preload("res://scripts/units/expansion_2_aircraft.gd").world_tick(world,dt)
	preload("res://scripts/units/expansion_2_overload.gd").world_tick(world,dt)
	preload("res://scripts/units/expansion_2_tractor.gd").world_tick(world,dt)
	if (world.allied_state.has("leizhu_courts") or world.allied_state.has("expansion_zones") or world.allied_state.has("expansion_scraps") or world.allied_state.has("expansion_calibration") or world.allied_state.has("expansion_burning_fields") or world.allied_state.has("expansion_overload_targets") or world.allied_state.has("expansion_tractor_fields")) and not world.has_node("ExpansionFields"):
		var visual=preload("res://scripts/units/expansion_field_visual.gd").new()
		visual.name="ExpansionFields";visual.world=world;world.add_child(visual)
	for tower in world.buildings:
		if tower.special.has(R.KEY):
			var state:=R.state(tower)
			R.timer(state,"arc_idle",dt)
			if not state.has("arc_idle"):state.arc_count=0;state.erase("arc_target")
	var list:Array=world.allied_state.get("expansion_zones",[])
	for zone in list.duplicate():
		zone.left-=dt
		var owner=zone.owner
		if not AlliedAbilities.alive(owner):list.erase(zone);continue
		if zone.kind=="scrap":R.area(owner,zone.point,zone.radius,0,zone.slow,P.number("mechanic/cards_legacy","slow_linger"))
		elif zone.kind=="seismic":
			zone.age+=dt
			# Older saves keep their original four-second field; new casts carry their end time.
			var ending:float=zone.get("end",4.0)
			while zone.age>=zone.next and zone.next<=ending:
				R.area(owner,zone.point,zone.radius,zone.damage if zone.pulse==0 else zone.tick,zone.slow,P.number("mechanic/cards_legacy","slow_linger"))
				Effects.spawn_impact(zone.point,Color("#d7b384"),zone.radius)
				zone.pulse+=1;zone.next+=P.number("mechanic/cards_legacy","seismic_interval")
			if zone.age>=P.number("mechanic/cards_legacy","seismic_warning") and zone.age<ending:R.area(owner,zone.point,zone.radius,0,zone.slow,P.number("mechanic/cards_legacy","slow_linger"))
		if zone.left<=0:list.erase(zone)
	var scraps:Array=world.allied_state.get("expansion_scraps",[])
	for piece in scraps.duplicate():
		piece.left-=dt
		if piece.left<=0:scraps.erase(piece);continue
		for collector in world.units:
			if not R.active(collector) or passive(collector)!="ps_spine_scrap" or not piece.sides.has(collector.side) or collector.position.distance_to(piece.point)>P.number("mechanic/cards_legacy","scrap_collect")*R.CELL:continue
			var armor:Array=R.state(collector).get_or_add("scrap",[])
			if armor.size()>=int(R.value(collector,"ps_spine_scrap","count")):continue
			armor.append(collector.max_hp*R.value(collector,"ps_spine_scrap","hp"));scraps.erase(piece)
			R.label(collector,"废铁装甲 %d"%armor.size());break

static func mine_tick(unit,dt:float) -> bool:
	var t:Dictionary=unit.special.expansion_temporary
	if t.kind not in ["ink","nest"]:return false
	if t.kind=="nest" and unit.display_name!="空投弹巢":unit.display_name="空投弹巢"
	t.arm-=dt
	if t.arm>0:return true
	var owner=t.owner
	for target in R.world(unit).units:
		if not R.enemy(unit,target) or target.is_air_target() or target.embarked_in!=null:continue
		if t.kind=="ink" and (not target.is_naval or NavalContact.submerged(target)):continue
		if target.position.distance_to(unit.position)>(P.number("mechanic/cards_legacy","ink_trigger")*R.CELL if t.kind=="ink" else P.number("mechanic/cards_legacy","nest_trigger")*R.CELL):continue
		R.area(owner,unit.position,P.number("mechanic/cards_legacy","mine_radius")*R.CELL,t.damage,P.number("mechanic/cards_legacy","ink_slow") if t.kind=="ink" else 0,P.number("mechanic/cards_legacy","ink_slow_seconds"))
		Effects.spawn_impact(unit.position,Color.ORANGE,35);R.dissolve(unit);return true
	return true

static func impact(actor,target,damage:float,extra:bool) -> float:
	if not R.active(actor) or not R.enemy(actor,target) or extra:return damage
	var s:=R.state(actor)
	var victim:=R.state(target)
	if victim.has("mark") and actor is Unit and not AlliedAbilities.infantry(actor) and not actor.is_air_target() and victim.mark.charges>0 and actor.side==victim.mark.side:
		damage*=1.0+victim.mark.value;victim.mark.charges-=1;R.label(target,"破甲 %d/3"%victim.mark.charges)
	if s.has("tracer_arm") and target is Unit and not AlliedAbilities.infantry(target) and not target.is_air_target():
		var strength:=R.value(actor,"ap_tracer_mark","damage")
		if victim.has("mark"):victim.mark.left=P.number("mechanic/cards_legacy","mark_seconds");victim.mark.value=maxf(strength,victim.mark.value)
		else:victim.mark={"left":P.number("mechanic/cards_legacy","mark_seconds"),"charges":P.count("mechanic/cards_legacy","mark_charges"),"value":strength,"side":actor.side}
		s.erase("tracer_arm");R.label(target,"破甲 3/3 · 4s")
	if passive(actor)=="ps_zero_arc":
		if not is_same(s.get("arc_target"),target):s.arc_count=0
		s.arc_target=target;s.arc_idle=P.number("mechanic/cards_legacy","arc_window");s.arc_count=int(s.get("arc_count",0))+1
		R.label(actor,"零点放电 %d/3"%s.arc_count)
		if s.arc_count>=P.count("mechanic/cards_legacy","arc_hits"):
			s.arc_count=0
			var nearest=null;var distance:float=P.number("mechanic/cards_legacy","arc_radius")*R.CELL
			for other in R.world(actor).units:
				if other==target or not R.enemy(actor,other) or other.is_air_target() or not R.world(actor).actor_visible_to(actor.side,other):continue
				var gap:float=target.position.distance_to(other.position)
				if gap<=distance:nearest=other;distance=gap
			if nearest!=null:R.hit(actor,nearest,R.value(actor,"ps_zero_arc","damage"),target.position)
	if actor is Unit and actor.unit_id=="DRON" and passive(actor)=="ps_drone_trip":
		s.bites=int(s.get("bites",0))+1
		if s.bites%P.count("mechanic/cards_legacy","trip_hits")==0 and not s.has("drone_cd"):
			victim.move_lock=R.value(actor,"ps_drone_trip","lock");s.drone_cd=P.number("mechanic/cards_legacy","trip_cooldown");R.label(target,"断电 · 定身")
	return damage

static func modify_reload(unit,seconds:float) -> float:
	var s:=R.state(unit)
	s.volley=int(s.get("volley",0))+1;s.prism_damage=0.0
	if s.has("relay_left"):
		seconds*=1.0-R.value(unit,"ps_field_relay","reload");s.erase("relay_left")
	if passive(unit)=="ps_prism_recycle" and not s.get("crystals",[]).is_empty():
		s.crystals.pop_front();seconds*=1.0-R.value(unit,"ps_prism_recycle","reload")
		s.prism_damage=R.value(unit,"ps_prism_recycle","damage")
	return seconds

static func killed(world,target,source) -> void:
	if R.temporary(target):return
	var actor=R.owner(source)
	if is_instance_valid(actor) and not R.temporary(actor) and passive(actor)=="ps_prism_recycle" and not BattleRequest.friendly(actor.side,target.side):
		var s:=R.state(actor)
		if s.get("crystal_volley",-1)!=s.get("volley",0):
			s.crystal_volley=s.get("volley",0)
			var crystals:Array=s.get_or_add("crystals",[])
			if crystals.size()<P.count("mechanic/cards_legacy","crystals"):crystals.append(P.number("mechanic/cards_legacy","crystal_seconds"));R.label(actor,"晶体 %d/3"%crystals.size())
	if AlliedAbilities.infantry(target):
		for ally in world.units:
			if R.active(ally) and passive(ally)=="ps_field_relay" and ally.side==target.side and ally.position.distance_to(target.position)<=P.number("mechanic/cards_legacy","relay_radius")*R.CELL and not R.state(ally).has("relay_cd"):
				R.state(ally).relay_cd=P.number("mechanic/cards_legacy","relay_cooldown");R.state(ally).relay_left=P.number("mechanic/cards_legacy","relay_window");R.label(ally,"战地接力 · 下次填弹")
	if preload("res://scripts/rules/expansion_contracts.gd").vehicle(target):
		var sides:Array=[]
		for unit in world.units:
			if R.active(unit) and passive(unit)=="ps_spine_scrap" and not BattleRequest.friendly(unit.side,target.side) and unit.position.distance_to(target.position)<=P.number("mechanic/cards_legacy","scrap_spawn")*R.CELL and not sides.has(unit.side):sides.append(unit.side)
		if not sides.is_empty():
			world.allied_state.get_or_add("expansion_scraps",[]).append({"point":target.position,"left":P.number("mechanic/cards_legacy","scrap_seconds"),"sides":sides})
			Effects.spawn_text(target.position,"废铁 · 12s",Color.ORANGE)

static func recover(carrier,plane) -> void:
	R.state(plane).erase("afterburn");R.state(plane).erase("afterburn_used")
	plane._recompute_bonuses()
	var s:=R.state(carrier)
	if passive(carrier)!="ps_deck_rotation" or s.has("deck_cd"):return
	var changed:=false
	for slot in carrier.logistics.squadron:
		if slot.unit!=plane and is_instance_valid(slot.unit) and slot.unit.embarked_in==carrier and slot.timer>0:
			slot.timer*=1.0-R.value(carrier,"ps_deck_rotation","reload");changed=true
	if changed:s.deck_cd=P.number("mechanic/cards_legacy","deck_cooldown");R.label(carrier,"甲板轮换")
