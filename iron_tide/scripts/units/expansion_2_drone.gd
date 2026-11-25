extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Reuse native contact, parasite damage and physical pounce; never clone a drone.
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY:="progression_v2"
const TALENT:="host_hunt"
const TOGGLE:="drone_auto_hunt"
const ACTIVE:="ap_lure_pounce"

static func state(unit) -> Dictionary:
	return unit.special.get_or_add(KEY,{"side":unit.side})

static func enabled(unit) -> bool:
	return unit.unit_id=="DRON" and R.talent_rank(unit,TALENT)>=0

static func automatic(unit) -> bool:
	return enabled(unit) and bool(unit.special.get(KEY,{}).get("hunt_auto",true))

static func legal(unit,target) -> bool:
	return R.enemy(unit,target) and target is Unit and not AlliedAbilities.infantry(target) and target.embarked_in==null and not target.special.has("iron_left") and unit.SovietWeapons.can_infest(target) and R.world(unit).actor_visible_to(unit.side,target,unit)

static func ready(unit) -> bool:
	return unit.unit_id=="DRON" and legal(unit,unit.attack_target) and not state(unit).has("pounce_left")

static func cast(unit,ab) -> bool:
	if not ready(unit):return false
	var s:=state(unit)
	s.pounce_left=P.number("mechanic/drone_v2","pounce_duration");s.pounce_target=unit.attack_target;s.pounce_pending=true
	s.pounce_speed=R.value(unit,ACTIVE,"speed")
	s.pounce_guard_seconds=R.value(unit,ACTIVE,"guard")
	s.pounce_reload=R.value(unit,ACTIVE,"reload")
	activate_guard(unit)
	ab.trigger_cooldown();unit._recompute_bonuses();unit.queue_redraw()
	return true

static func activate_guard(unit) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	if not s.get("pounce_pending",false):return
	var target=s.get("pounce_target")
	if unit.embarked_in!=null or not is_same(unit.attack_target,target) or not legal(unit,target):
		s.pounce_pending=false;return
	if unit.position.distance_to(target.position)<=P.number("mechanic/drone_v2","guard_range")*R.CELL:
		s.pounce_guard=float(s.pounce_guard_seconds);s.pounce_pending=false
		unit.queue_redraw()

static func invulnerable(unit) -> bool:
	return unit.unit_id=="DRON" and R.active(unit) and unit.embarked_in==null and float(unit.special.get(KEY,{}).get("pounce_guard",0))>0

static func speed(unit) -> float:
	var s:Dictionary=unit.special.get(KEY,{})
	return 1.0+float(s.get("pounce_speed",0)) if unit.unit_id=="DRON" and s.has("pounce_left") else 1.0

static func timer(s:Dictionary,key:String,dt:float) -> void:
	if not s.has(key):return
	s[key]=maxf(0,float(s[key])-dt)
	if s[key]<=.000001:s.erase(key)

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	if s.has("hunt_tears"):tick_tears(unit,s,dt)
	if unit.unit_id!="DRON":return
	var boosted:=s.has("pounce_left")
	for key in ["pounce_left","pounce_guard","pounce_burrow","hunt_cd"]:timer(s,key,dt)
	if boosted and not s.has("pounce_left"):
		s.erase("pounce_pending");s.erase("pounce_target");unit._recompute_bonuses()
	if s.has("pounce_left"):activate_guard(unit)
	if s.has("pounce_guard") or boosted:unit.queue_redraw()

static func entered(unit,host) -> void:
	if not R.active(unit):return
	if not enabled(unit) and not unit.special.has(KEY):return
	var s:=state(unit)
	if s.has("pounce_left") and is_same(s.get("pounce_target"),host):s.pounce_burrow=P.number("mechanic/drone_v2","burrow_duration")
	for key in ["pounce_left","pounce_pending","pounce_target","pounce_guard"]:s.erase(key)
	if enabled(unit):s.hunt_host=host;s.hunt_hits=0;s.erase("hunt_previous")
	unit._recompute_bonuses()

static func parasite_interval(unit,seconds:float) -> float:
	if not R.active(unit):return seconds
	var s:Dictionary=unit.special.get(KEY,{})
	return seconds*(1.0-float(s.get("pounce_reload",0))) if s.has("pounce_burrow") else seconds

static func parasite_hit(unit,host,previous_hp:float) -> void:
	if not enabled(unit) or not R.enemy(unit,host) or unit.embarked_in!=host or host.hp>=previous_hp:return
	var s:=state(unit)
	if not is_same(s.get("hunt_host"),host):s.hunt_host=host;s.hunt_hits=0
	s.hunt_hits=mini(P.count("mechanic/drone_v2","hits"),int(s.get("hunt_hits",0))+1)
	try_hunt(unit)

static func try_hunt(unit) -> bool:
	if not automatic(unit) or AlliedAbilities.frozen(unit) or unit._stun_timer>0:return false
	var s:=state(unit)
	var host=unit.embarked_in
	if s.has("hunt_cd") or int(s.get("hunt_hits",0))<P.count("mechanic/drone_v2","hits") or not R.enemy(unit,host) or not host is Unit or host.special.get("parasite")!=unit:return false
	if host.hp>host.max_hp*P.number("mechanic/drone_v2","threshold"):return false
	var reach:float=R.talent(unit,TALENT,"range")*R.CELL
	var best=null;var distance:=INF
	for candidate in R.world(unit).units:
		if candidate==host or candidate==s.get("hunt_previous") or not legal(unit,candidate):continue
		var d:float=host.position.distance_to(candidate.position)
		if d<=reach and (d<distance or (is_equal_approx(d,distance) and candidate.get_instance_id()<best.get_instance_id())):
			best=candidate;distance=d
	if best==null:return false
	leave_tear(unit,host)
	# Release the same actor through the native path; preserve its HP and W cooldown.
	unit.SovietWeapons.release_drone(host)
	for key in ["pounce_left","pounce_guard","pounce_pending","pounce_target","pounce_burrow"]:s.erase(key)
	s.hunt_cd=P.number("mechanic/drone_v2","cooldown");s.hunt_hits=0;s.hunt_previous=host;s.erase("hunt_host")
	unit._recompute_bonuses()
	unit.order_target(best,false,false)
	var leap=load("res://scripts/units/dog_pounce.gd")
	if leap.start(unit,best,unit.weapon):
		var contact:float=unit.radius+best.radius+2.0
		unit.special.pounce.hunt_speed=maxf(unit.move_speed*2,(maxf(0,distance-contact)+1.0)/leap.LEAP_SECONDS)
		unit.special.pounce.hunt_from=host
	return true

static func cancel_leap(unit) -> void:
	if unit.special.get("pounce",{}).has("hunt_from"):unit.special.erase("pounce")

static func exit_host(unit,motion:Vector2,existing:Array):
	var host=unit.special.get(KEY,{}).get("hunt_previous")
	if not AlliedAbilities.alive(host) or existing.has(host):return null
	var distance:float=unit.position.distance_squared_to(host.position)
	if distance>=pow(unit.radius+host.radius+2.0,2) or (unit.position+motion).distance_squared_to(host.position)<=distance:return null
	unit.add_collision_exception_with(host)
	return host

static func leave_tear(unit,host) -> void:
	var weapon:Dictionary=unit.weapon.duplicate(true)
	weapon.damage=float(weapon.damage)*R.talent(unit,TALENT,"damage")
	var bonus:Dictionary=unit.bonuses.duplicate(true)
	bonus.expansion_extra=true;bonus.reference_weapon=weapon.duplicate(true)
	state(host).get_or_add("hunt_tears",[]).append({"owner":unit,"side":unit.side,"weapon":weapon,"bonus":bonus,"elapsed":0.0,"ticks":0})

static func tick_tears(host,s:Dictionary,dt:float) -> void:
	var rows:Array=s.hunt_tears
	for tear:Dictionary in rows.duplicate():
		if BattleRequest.friendly(tear.side,host.side):rows.erase(tear);continue
		tear.elapsed+=dt
		while tear.ticks<P.count("mechanic/drone_v2","tear_ticks") and tear.elapsed+.000001>=float(tear.ticks+1)*P.number("mechanic/drone_v2","tear_interval") and AlliedAbilities.alive(host):
			tear.ticks+=1
			var owner=tear.owner
			if not AlliedAbilities.alive(owner) or owner.side!=tear.side:owner=null
			var damage:=CombatMath.full_damage(tear.weapon,host.armor,tear.bonus,null,host.ra2_armor,0,host)
			host.receive_hit(damage,"melee",tear.bonus,owner,str(tear.weapon.get("ra2_warhead","")))
		if tear.ticks>=P.count("mechanic/drone_v2","tear_ticks"):rows.erase(tear)
	if rows.is_empty():s.erase("hunt_tears")

static func toggle(unit) -> bool:
	if not enabled(unit):return false
	state(unit).hunt_auto=not automatic(unit)
	unit.queue_redraw()
	return true

static func info(unit) -> Dictionary:
	return {"id":TOGGLE,"name":"自动跳宿："+("开" if automatic(unit) else "关"),"desc":"三次有效寄生跳伤且宿主生命不高于40%时自动跳向附近合法新宿主。按Q切换，不改变当前攻击指令。","ready":enabled(unit),"cooldown":0.0,"cd_left":0.0,"cd_frac":0.0,"active":automatic(unit),"toggle":true,"glyph":"attack"}

static func entries(unit) -> Array:
	var s:Dictionary=unit.special.get(KEY,{})
	var out:Array=[]
	const V=preload("res://scripts/units/expansion_visual.gd")
	for item in [["pounce_left","诱导跃扑 · 加速"],["pounce_guard","诱导跃扑 · 无敌"],["pounce_burrow","诱导跃扑 · 寄生加速"],["hunt_cd","跳宿猎杀冷却"]]:
		if s.has(item[0]):out.append(V.row(item[1],s[item[0]],false,"attack"))
	if enabled(unit):
		var row:=V.row("跳宿猎杀 · 自动"+("开" if automatic(unit) else "关"),0,false,"attack")
		row.stacks=int(s.get("hunt_hits",0));row.limit=P.count("mechanic/drone_v2","hits");out.append(row)
	if s.has("hunt_tears"):
		var left:=0.0
		for tear:Dictionary in s.hunt_tears:left=maxf(left,P.count("mechanic/drone_v2","tear_ticks")*P.number("mechanic/drone_v2","tear_interval")-float(tear.elapsed))
		out.append(V.row("跳宿残留撕裂",left,true,"attack"))
	return out

static func draw(unit) -> void:
	if invulnerable(unit):unit.draw_arc(Vector2(0,-unit._visual_lift()),unit.radius+8,0,TAU,28,Color.GOLD,2,true)
