extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Event-scoped Soviet cards. Persistent state remains in the battle snapshot.
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"

static func state(unit) -> Dictionary:
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func eligible(unit) -> bool:
	return unit.unit_id=="SHK" and unit.passive.get("id")=="ps_polar_link"

static func endpoint(unit,target) -> bool:
	return R.enemy(unit,target) and target is Unit and not target.is_air_target() and not target.is_naval and target.embarked_in==null

static func tick(unit,dt:float) -> void:
	if unit.unit_id not in ["SHK","HTK"]:return
	var s:Dictionary=unit.special.get(KEY,{})
	for key in ["polar_cd","polar_window","flak_arm"]:R.timer(s,key,dt)
	if s.has("flak_arm") and s.flak_arm<=.000001:s.erase("flak_arm")
	if not s.has("polar_window"):s.erase("polar_first")
	if s.has("polar_first") and not endpoint(unit,s.polar_first):s.erase("polar_first");s.erase("polar_window")
	if not s.has("polar_link"):return
	var chain:Dictionary=s.polar_link
	if not endpoint(unit,chain.a) or not endpoint(unit,chain.b) or chain.a.position.distance_to(chain.b.position)>P.number("mechanic/soviet_v2","break_range")*R.CELL:
		s.erase("polar_link");unit.queue_redraw();return
	chain.elapsed+=dt
	while chain.ticks<P.count("mechanic/soviet_v2","ticks") and chain.elapsed+.000001>=float(chain.ticks+1)*P.number("mechanic/soviet_v2","tick_seconds"):
		chain.ticks+=1
		var world=R.world(unit)
		if world!=null and world.actor_visible_to("ally",chain.a) and world.actor_visible_to("ally",chain.b):
			Effects.spawn_beam(Effects.hit_position(chain.a),Effects.hit_position(chain.b),Color.SKY_BLUE,"tesla",2,.18)
		pulse(unit,chain.a,chain);pulse(unit,chain.b,chain)
		if not endpoint(unit,chain.a) or not endpoint(unit,chain.b):break
	if chain.elapsed>=P.count("mechanic/soviet_v2","ticks")*P.number("mechanic/soviet_v2","tick_seconds")-.000001 or not endpoint(unit,chain.a) or not endpoint(unit,chain.b):s.erase("polar_link")
	unit.queue_redraw()

static func pulse(unit,target,chain:Dictionary) -> void:
	if not endpoint(unit,target):return
	var weapon:Dictionary=chain.weapon
	var bonus:Dictionary=chain.bonus
	var damage:=CombatMath.full_damage(weapon,target.armor,bonus,null,target.ra2_armor,0.0,target)
	target.receive_hit(damage,str(weapon.get("attack_type","electric")),bonus,unit,str(weapon.get("ra2_warhead","")))

static func shot(unit,bonus:Dictionary) -> void:
	if not R.active(unit) or unit.unit_id!="HTK" or not unit.special.get(KEY,{}).has("flak_arm"):return
	# Save the actually fired domain weapon; a later target change must not turn flak into ground fire.
	bonus.expansion_flak_weapon=unit._active_weapon().duplicate(true)

static func primary(source,target,bonus:Dictionary) -> bool:
	if bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false):return false
	if not bonus.has("expansion_origin"):return false
	return not source is Projectile or source.target==target

static func damaged(unit,target,source,amount:float,bonus:Dictionary) -> void:
	if not unit is Unit or not R.active(unit) or not eligible(unit) or not primary(source,target,bonus) or not endpoint(unit,target):return
	# Called before HP subtraction: a fatal hit cannot become a live chain endpoint.
	if amount<=0 or amount>=target.hp:return
	var s:=state(unit)
	if s.has("polar_cd") or s.has("polar_link"):return
	var first=s.get("polar_first")
	var world=R.world(unit)
	if endpoint(unit,first) and first!=target and first.position.distance_to(target.position)<=P.number("mechanic/soviet_v2","link_range")*R.CELL and world!=null and world.actor_visible_to(unit.side,first,unit):
		# Snapshot ordinary attack, excluding reserve/primary-hit multipliers on the triggering shot.
		var weapon:Dictionary=unit._active_weapon().duplicate(true)
		weapon.damage=float(weapon.damage)*R.value(unit,"ps_polar_link","damage")*P.number("mechanic/soviet_v2","tick_seconds")
		var packet:Dictionary=unit.bonuses.duplicate(true)
		packet.expansion_extra=true;packet.reference_weapon=weapon.duplicate(true)
		s.polar_link={"a":first,"b":target,"elapsed":0.0,"ticks":0,"weapon":weapon,"bonus":packet}
		s.polar_cd=P.number("mechanic/soviet_v2","cooldown");s.erase("polar_first");s.erase("polar_window")
		unit.queue_redraw()
	else:
		s.polar_first=target;s.polar_window=P.number("mechanic/soviet_v2","window")

static func impact(unit,target,source,amount:float,bonus:Dictionary) -> void:
	if amount<=0 or not unit is Unit or not R.active(unit) or unit.unit_id!="HTK" or not source is Projectile:return
	if not primary(source,target,bonus) or not bonus.has("expansion_flak_weapon") or not R.enemy(unit,target) or not target is Unit or not target.is_air_target() or target.embarked_in!=null:return
	var s:Dictionary=unit.special.get(KEY,{})
	if not s.has("flak_arm") or source.splinters.has("expansion_flak_burst"):return
	var weapon:Dictionary=bonus.expansion_flak_weapon.duplicate(true)
	if not CombatMath.can_hit_air(weapon):return
	weapon.damage=float(weapon.damage)*R.value(unit,"ap_flak_fan","damage")
	var packet:Dictionary=bonus.duplicate(true)
	packet.erase("expansion_flak_weapon");packet.expansion_extra=true;packet.reference_weapon=weapon.duplicate(true)
	source.splinters.expansion_flak_burst={"point":target.position,"visual":Effects.hit_position(target),"weapon":weapon,"bonus":packet}

static func finish_projectile(projectile) -> void:
	if not projectile.splinters.has("expansion_flak_burst"):return
	var blast:Dictionary=projectile.splinters.expansion_flak_burst
	projectile.splinters.erase("expansion_flak_burst")
	var actor=projectile.shooter()
	if not is_instance_valid(actor) or not actor is Unit:return
	var world=R.world(actor)
	if world==null:return
	# The main hit has now finished. This added blast cannot recursively produce another.
	for target in world.units.duplicate():
		if not R.enemy(actor,target) or not target.is_air_target() or target.embarked_in!=null:continue
		if target.position.distance_to(blast.point)>P.number("mechanic/soviet_v2","flak_radius")*R.CELL or not actor._weapon_domain_valid(target,false,blast.weapon):continue
		var damage:=CombatMath.full_damage(blast.weapon,target.armor,blast.bonus,null,target.ra2_armor,0,target)
		target.receive_hit(damage,str(blast.weapon.get("attack_type","bullet")),blast.bonus,projectile,str(blast.weapon.get("ra2_warhead","")))
	if world.position_visible_to("ally",blast.point):Effects.spawn_impact(blast.visual,Color.GOLD,P.number("mechanic/soviet_v2","flak_radius")*R.CELL)

static func entries(unit) -> Array:
	if unit.unit_id not in ["SHK","HTK"]:return []
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	const V=preload("res://scripts/units/expansion_visual.gd")
	for item in [["polar_cd","两极串联冷却"],["polar_window","两极串联 · 第二目标窗口"],["flak_arm","高射扇幕 · 持续防空溅射"]]:
		if s.has(item[0]):out.append(V.row(item[1],s[item[0]],false,"electric"))
	if s.has("polar_link"):out.append(V.row("两极串联 · 双端电击",maxf(0,P.count("mechanic/soviet_v2","ticks")*P.number("mechanic/soviet_v2","tick_seconds")-float(s.polar_link.elapsed)),false,"electric"))
	return out

static func draw(unit) -> void:
	if unit.unit_id not in ["SHK","HTK"]:return
	var s:Dictionary=unit.special.get(KEY,{})
	if s.has("flak_arm"):unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+7,0,TAU,24,Color.GOLD,1.5,true)
	if not s.has("polar_link"):return
	var chain:Dictionary=s.polar_link
	if not endpoint(unit,chain.a) or not endpoint(unit,chain.b):return
	var world=R.world(unit)
	if world==null or not world.actor_visible_to("ally",chain.a) or not world.actor_visible_to("ally",chain.b):return
	unit.draw_line(Iso.dir(chain.a.position-unit.position),Iso.dir(chain.b.position-unit.position),Color(.4,.8,1,.75),2,true)
