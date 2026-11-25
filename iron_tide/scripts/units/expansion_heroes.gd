extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const ACTIVE=["ap_watch_posts","ap_north_twin","ap_spine_crown"]

static func cast(unit,ab,at:Vector2) -> bool:
	var s:=R.state(unit)
	if ab.id=="ap_north_twin" and AlliedAbilities.alive(s.get("twin")):
		var twin=s.twin
		if s.has("swap_cd") or twin._stun_timer>0 or AlliedAbilities.frozen(twin) or twin.embarked_in!=null or unit.special.has("parasite") or twin.special.has("parasite") or unit.position.distance_to(twin.position)>P.number("mechanic/hero_cards_legacy","swap_range")*R.CELL:return false
		var battle=R.world(unit)
		if not battle.path_service.line_walkable(unit.position,twin.position,battle.path_service.cost):return false
		var origin:Vector2=unit.position
		unit.position=twin.position;twin.position=origin
		var heading:float=unit.hull_angle
		unit.hull_angle=twin.hull_angle;twin.hull_angle=heading
		unit.order_stop();twin.order_stop()
		unit.reset_physics_interpolation();twin.reset_physics_interpolation()
		s.swap_cd=R.value(unit,ab.id,"swap")
		s.swap_flash=.25;R.state(twin).swap_flash=.25
		Effects.spawn_beam(origin,unit.position,Color(.6,.9,1),"laser",2,.25)
		R.label(unit,"双星易位")
		return true
	if not ab.ready():return false
	match ab.id:
		"ap_watch_posts":
			var posts:Array=[]
			for i in P.count("mechanic/hero_cards_legacy","posts"):
				var pos:Vector2=unit.position+Vector2.from_angle(unit.hull_angle+TAU*i/P.count("mechanic/hero_cards_legacy","posts"))*R.CELL*P.number("mechanic/hero_cards_legacy","post_radius")
				var post=R.summon(unit,"E1",pos,"post",R.value(unit,ab.id,"life"),R.value(unit,ab.id,"hp"),R.value(unit,ab.id,"damage"))
				if post!=null:
					post.display_name="哨位 %d"%(posts.size()+1)
					posts.append(post)
			if posts.is_empty():return false
			unit.set_deployed(true,false)
			unit.set_fire_stance("free")
			unit._refresh_target()
			for post in posts:
				# Snapshot the owner's deployed weapon, including rank and hero range.
				post.weapon=unit._active_weapon().duplicate(true)
				post.data.deployed_weapon=post.weapon.duplicate(true)
				post.data.elite_deployed_weapon=post.weapon.duplicate(true)
				post._deploy_atk=unit._deploy_atk
				post._base_atk=float(unit.bonuses.attack_bonus)*R.value(unit,ab.id,"damage")/maxf(.001,post._deploy_atk)
				post.set_deployed(true,false)
				post.set_fire_stance("free")
				post._refresh_target()
			for old in s.get("posts",[]):R.dissolve(old)
			s.posts=posts
			R.label(unit,"哨队展开 %d/3"%posts.size())
		"ap_north_twin":
			var twin=R.summon(unit,"MTNK",unit.position+Vector2(65,0),"twin",R.value(unit,ab.id,"life"),R.value(unit,ab.id,"hp"),R.value(unit,ab.id,"damage"))
			if twin==null:return false
			s.twin=twin
			follow_owner_target(twin)
		"ap_spine_crown":
			if not at.is_finite() or unit.position.distance_to(at)>P.number("mechanic/hero_cards_legacy","crown_range")*R.CELL:return false
			var battle=R.world(unit)
			if battle.fog!=null and not battle.fog.is_visible_at(unit.side,at):return false
			var count:int=1+s.get("scrap",[]).size()
			s.scrap=[]
			s.crown={"point":at,"count":count,"left":P.number("mechanic/hero_cards_legacy","crown_warning"),"id":ab.id,"radius":R.value(unit,ab.id,"radius"),"life":R.value(unit,ab.id,"life"),"slow":R.value(unit,ab.id,"slow"),"damage":R.value(unit,ab.id,"damage")}
			R.label(unit,"发射 %d 枚"%count)
	ab.trigger_cooldown()
	return true

static func pending_death(unit) -> bool:
	if unit.special.get("academy_hero")!="E1" or unit.passive.get("id")!="ps_watch_succession":return false
	var s:=R.state(unit)
	if s.get("succession_used",false):return false
	var candidates:Array=[]
	for post in s.get("posts",[]):
		if AlliedAbilities.alive(post) and post.position.distance_to(unit.position)<=P.number("mechanic/hero_cards_legacy","succession_range")*R.CELL:candidates.append(post)
	if candidates.is_empty():return false
	s.succession_used=true
	s.succession={"candidates":candidates,"left":P.number("mechanic/hero_cards_legacy","succession_seconds"),"origin":unit.position,"chosen":candidates.pick_random()}
	unit.hp=1;unit.visible=false
	unit.order_stop()
	R.label(s.succession.chosen,"继任 2s")
	return true

static func tick(unit,delta:float) -> bool:
	var s:=R.state(unit)
	R.timer(s,"swap_cd",delta);R.timer(s,"swap_flash",delta);R.timer(s,"echo_cd",delta);R.timer(s,"rebirth_lock",delta)
	if s.has("succession"):
		var process:Dictionary=s.succession
		if not AlliedAbilities.alive(process.chosen):
			process.candidates.erase(process.chosen)
			process.candidates=process.candidates.filter(AlliedAbilities.alive)
			if process.candidates.is_empty():
				s.erase("succession");unit.visible=true;unit.hp=0;unit._die();return true
			process.chosen=process.candidates.pick_random();process.left=P.number("mechanic/hero_cards_legacy","succession_seconds")
			R.label(process.chosen,"继任转移 → "+process.chosen.display_name)
		process.left-=delta
		if process.left<=0:
			unit.position=process.chosen.position
			unit.reset_physics_interpolation()
			unit.hp=unit.max_hp*R.value(unit,"ps_watch_succession","hp")
			unit.visible=true;s.rebirth_lock=R.value(unit,"ps_watch_succession","lock")
			s.erase("succession")
			for post in s.get("posts",[]):R.dissolve(post)
			s.posts=[];R.label(unit,"继任已用")
		return true
	if s.has("echoes"):
		for echo in s.echoes.duplicate():
			echo.age+=delta
			var target=echo.target
			if not AlliedAbilities.alive(target) or echo.age>=P.number("mechanic/hero_cards_legacy","echo_retention"):
				s.echoes.erase(echo);continue
			if echo.age<P.number("mechanic/hero_cards_legacy","echo_delay") or s.has("echo_release_cd"):continue
			var battle=R.world(unit)
			if not battle.actor_visible_to(unit.side,target) or echo.origin.distance_to(R.point(unit,target))>float(echo.weapon.range):continue
			R.hit(unit,target,R.value(unit,"ps_north_echo","damage"),echo.origin,echo.weapon)
			s.echoes.erase(echo);s.echo_release_cd=P.number("mechanic/hero_cards_legacy","echo_release")
			R.label(unit,"昨日炮击")
	R.timer(s,"echo_release_cd",delta)
	if s.has("crown"):
		var c:Dictionary=s.crown;c.left-=delta
		while c.left<=0 and c.count>0:
			R.area(unit,c.point,P.number("mechanic/hero_cards_legacy","crown_blast")*R.CELL,c.damage)
			Effects.spawn_impact(c.point,Color.ORANGE,30)
			c.count-=1;c.left+=P.number("mechanic/hero_cards_legacy","crown_interval")
		if c.count<=0:
			R.world(unit).allied_state.get_or_add("expansion_zones",[]).append({"kind":"scrap","owner":unit,"point":c.point,"radius":c.radius*R.CELL,"left":c.life,"slow":c.slow})
			s.erase("crown")
	if unit.passive.get("id")=="ps_spine_scrap":
		s.scrap_idle=float(s.get("scrap_idle",0))+delta
		if float(s.scrap_idle)>R.value(unit,"ps_spine_scrap","idle"):
			s.scrap_drop=float(s.get("scrap_drop",0))+delta
			if s.scrap_drop>=P.number("mechanic/hero_cards_legacy","scrap_drop"):
				s.scrap_drop=0
				if not s.get("scrap",[]).is_empty():s.scrap.pop_front()
	return false

static func hit(unit,target,extra:bool,shot_weapon:Dictionary={}) -> void:
	if extra or not R.active(unit) or not R.enemy(unit,target):return
	var s:=R.state(unit)
	s.scrap_idle=0;s.scrap_drop=0
	if unit.passive.get("id")!="ps_north_echo" or s.has("echo_cd"):return
	if target is Unit and (target.is_air_target() or target.is_naval or AlliedAbilities.infantry(target)):return
	var echoes:Array=s.get_or_add("echoes",[])
	if echoes.size()>=P.count("mechanic/hero_cards_legacy","echo_capacity"):return
	echoes.append({"target":target,"origin":s.get("shot_origin",unit.position),"age":0.0,"weapon":(R.weapon(unit) if shot_weapon.is_empty() else shot_weapon).duplicate(true)})
	s.echo_cd=R.value(unit,"ps_north_echo","interval")

static func injured(unit) -> void:
	var s:=R.state(unit)
	s.scrap_idle=0;s.scrap_drop=0
	if unit.passive.get("id")!="ps_watch_succession" or unit.hp<=0 or unit.hp>unit.max_hp*P.number("mechanic/hero_cards_legacy","reserve_threshold") or s.get("reserve_used",false):return
	for post in s.get("posts",[]):
		if AlliedAbilities.alive(post):return
	var post=R.summon(unit,"E1",unit.position-Vector2.from_angle(unit.hull_angle)*R.CELL,"reserve",P.number("mechanic/hero_cards_legacy","reserve_life"),P.number("mechanic/hero_cards_legacy","reserve_hp"),0)
	if post!=null:s.reserve_used=true;s.posts=[post]

static func absorb(unit,damage:float) -> float:
	damage=preload("res://scripts/units/mirror_fork.gd").absorb(unit,damage)
	var s:=R.state(unit)
	var scrap:Array=s.get("scrap",[])
	while damage>0 and not scrap.is_empty():
		var used:=minf(damage,float(scrap[0]))
		damage-=used;scrap[0]-=used
		if scrap[0]<=0:scrap.pop_front()
	return damage

static func owner_target(unit):
	var temporary:Dictionary=unit.special.get("expansion_temporary",{})
	if temporary.get("kind")!="twin" or unit.attack_ordered or unit.fire_stance=="none":return null
	var owner=temporary.get("owner")
	if not AlliedAbilities.alive(owner) or not AlliedAbilities.alive(owner.attack_target):return null
	return owner.attack_target

static func follow_owner_target(unit) -> bool:
	var target=owner_target(unit)
	if target==null:return false
	# A live owner target reserves the twin's focus even when it cannot shoot it.
	unit.attack_target=target if R.enemy(unit,target) and unit.attack_domain_valid(target) else null
	return true

static func temporary_tick(unit,delta:float) -> bool:
	var state:Dictionary=unit.special.expansion_temporary
	state.left-=delta
	var owner=state.owner
	if not AlliedAbilities.alive(owner):R.dissolve(unit);return true
	if state.left<=0:
		if state.kind=="mirror":preload("res://scripts/units/mirror_fork.gd").detonate(unit)
		else:R.dissolve(unit)
		return true
	var s:=R.state(owner)
	var origin:Vector2=s.succession.origin if s.has("succession") else owner.position
	if state.kind in ["post","reserve","bait","ink","nest"]:
		if not unit.special.has("convoy_projection") and state.kind in ["post","reserve"] and unit.position.distance_to(origin)>P.number("mechanic/hero_cards_legacy","succession_range")*R.CELL:
			R.label(unit,"哨位离距消失");R.dissolve(unit);return true
		unit.has_move_order=false;unit.velocity=Vector2.ZERO
		if not unit.attack_ordered and AlliedAbilities.alive(owner.attack_target):unit.attack_target=owner.attack_target
	if state.kind=="twin":
		follow_owner_target(unit)
		unit.modulate=Color(.45,.8,1,.65)
		state.trail_clock=float(state.get("trail_clock",0))+delta
		if state.trail_clock>=.12:
			state.trail_clock=fmod(state.trail_clock,.12)
			var trail:Array=state.get_or_add("trail",[])
			trail.push_front(unit.position)
			if trail.size()>3:trail.pop_back()
	if state.kind=="mirror" and unit.position.distance_to(state.origin)>=P.number("mechanic/ap_mirror_fork","move_range")*R.CELL:unit.order_stop()
	unit.queue_redraw()
	return false
