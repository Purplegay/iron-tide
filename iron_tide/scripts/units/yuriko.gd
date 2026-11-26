extends RefCounted

const ID := "YURIKO"
const ART := "res://assets/ra3/yuriko/"
const SKINS := ["实验服 · I","校服 · II","校服 · III","婚纱 · 同一站下车"]
const PORTRAITS := ["Portrait_Japan_Yuriko_01","Portrait_Japan_Yuriko_03","Portrait_Japan_Yuriko_02","Portrait_Yuriko_Wedding"]
const COLORS := [Color("#94df72"),Color("#ac9cff"),Color("#f48a56"),Color("#f3d6ac")]
const THROW_RADIUS := 37.5
const BASE_DURATION := 180
const GUARD_OFFSETS := [Vector2(60,0),Vector2(45,45),Vector2(45,-45),Vector2(30,60),Vector2(30,-60)]
const REACH := 375.0 # SAGE world units are scaled by 1.5 here.
const COLOR := Color("#ec94ef")
const NAMES := {"Shield":"灵能护盾","Lure":"心灵控制","Slam":"念力投掷","Speed":"移动速度","Health":"生命上限","AttackDamage":"攻击力"}
const FX = preload("res://scripts/units/yuriko_power_fx.gd")
const Audio = preload("res://scripts/units/yuriko_audio.gd")
const Rules = preload("res://scripts/units/expansion_rules.gd")
static var template: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/yuriko.json")).tree

static func training(world) -> Dictionary:
	if not world.allied_state.has("yuriko_training"):
		var state:=preload("res://scripts/units/yuriko_school.gd").snapshot()
		var carried:Dictionary=preload("res://scripts/expedition/rules.gd").context().get("yuriko_training",{})
		for id in carried.get("learned",[]):
			if id not in state.learned:state.learned.append(id)
		world.allied_state.yuriko_training=state
	return world.allied_state.yuriko_training

static func skin(world) -> int:
	return preload("res://scripts/units/yuriko_school.gd").usable_outfit(int(training(world).get("skin",0)))

static func dress(world,index:int) -> void:
	if world.ended or not preload("res://scripts/units/yuriko_school.gd").outfit_unlocked(index):return
	training(world).skin=index
	var u=hero(world)
	if u!=null:
		u.special.yuriko_skin=index
		u.yuriko_model.set_skin(index)
		u.queue_redraw()

static func hero(world):
	for u in world.units:
		if world.actor_alive(u) and u.unit_id == ID and u.side == "ally": return u
	return null

static func rank(world, branch: String) -> int:
	var level := 0
	var learned: Array = training(world).learned
	for def in template:
		if def.branch == branch and def.id in learned: level = maxi(level,def.rank)
	return level

static func apply_upgrade(u, branch: String) -> void:
	match branch:
		"Speed": u._base_speed *= 1.15
		"Health":
			u._base_max_hp *= 1.15
			u.max_hp *= 1.15
			u.hp *= 1.15
		"AttackDamage": u._base_atk *= 1.25
	u._recompute_bonuses()

static func summon(world) -> bool:
	if world.ended or world.paused or not BattleRequest.extensions_enabled() or world.allied_state.get("yuriko_summoned",false) or hero(world) != null: return false
	var expedition = preload("res://scripts/expedition/rules.gd")
	if expedition.active() and not expedition.context().get("yuriko_recruited",false): return false
	for building in world.buildings:
		if not world.actor_alive(building) or building.side != "ally" or building.under_construction or building.building_id not in ["GAPILE","NAHAND","YABRCK"]: continue
		var pos := ProductionExit.point(building,ID)
		if not pos.is_finite(): continue
		var u = world.spawn_unit(ID,"ally",pos,building)
		if u == null: return false
		dress(world,skin(world))
		u.special.psi_intro_anim = u.yuriko_model.duration(u.yuriko_model.entrance())
		world.allied_state.yuriko_summoned = true
		for def in template:
			if def.id in training(world).learned: apply_upgrade(u,def.branch)
		var bonuses:Dictionary=training(world).get("affinity_bonuses",{})
		var health_factor:=1.0+0.01*int(bonuses.get("health",0))
		u._base_max_hp*=health_factor
		u.max_hp*=health_factor
		u.hp*=health_factor
		u._base_atk*=1.0+0.01*int(bonuses.get("attack",0))
		u._base_speed*=1.0+0.005*int(bonuses.get("speed",0))
		u._recompute_bonuses()
		u.special.psi_cooldown_factor=1.0-0.0025*int(bonuses.get("cooldown",0))
		u.special.psi_support_left=deployment_duration(world)
		world.yuriko_support=u
		Ra2Sfx.play_voice(u.data,"created",u.global_position)
		world.focus_unit(u)
		Music.play_cue("yuriko")
		return true
	return false

static func deployment_duration(world) -> int:
	return BASE_DURATION+2*int(training(world).get("affinity_bonuses",{}).get("duration",0))

static func deployment_clock(left:float) -> String:
	var seconds:=ceili(maxf(left,0))
	return "%d:%02d"%[floori(seconds/60.0),seconds%60]

static func tick_deployment(world,dt:float) -> void:
	var u:Unit=world.yuriko_support
	if not AlliedAbilities.alive(u):
		world.yuriko_support=null
		return
	if world.paused or world.ended or world.get_tree().paused:return
	u.special.psi_support_left=maxf(0,float(u.special.psi_support_left)-dt)
	if u.special.psi_support_left>0:return
	world.yuriko_support=null
	preload("res://scripts/world/battle_music_director.gd").yuriko_departed(world)
	for guard in u.special.get("psi_guards",[]):
		if AlliedAbilities.alive(guard) and guard.special.has("psi_original_side"):release_guard(guard)
	for target in held(u):
		target.special.erase("psi_holder")
		target.special.erase("psi_lift")
		clear_lift_material(target)
	for unit in world.units:
		if not AlliedAbilities.alive(unit):continue
		if is_same(unit.special.get("psi_air_pull",{}).get("caster"),u):
			unit.special.erase("psi_air_pull")
		if is_same(unit.special.get("psi_flight",{}).get("caster"),u):
			unit.special.psi_flight.erase("caster")
	if world.allied_state.get("yuriko_field")==u:world.allied_state.erase("yuriko_field")
	if u.embarked_in is Unit:u.embarked_in.logistics.passengers.erase(u)
	elif u.embarked_in is Building:u.embarked_in.special.get("occupants",[]).erase(u)
	for group in world.control_groups.values():group.erase(u)
	if world.follow_target==u:world.follow_target=null
	if world.hover_entity==u:world.hover_entity=null
	var selected:bool=world.selected_units.has(u)
	AlliedAbilities.consume(u)
	world.units.erase(u)
	world.invalidate_ai_population()
	if selected:world._emit_selection()
	Events.emit_message("百合子的支援时间已到，已离开战场。",COLOR)

static func protected(world, target, source, kind: String) -> bool:
	if kind in ["radiation","healing"] or not BattleRequest.friendly("ally",target.side): return false
	var owner = world.allied_state.get("yuriko_field")
	if not AlliedAbilities.alive(owner) or owner.embarked_in != null or not owner.special.has("psi_shield"):
		world.allied_state.erase("yuriko_field")
		return false
	if owner.position.distance_squared_to(Rules.point(owner,target)) > 36.0*36.0: return false
	var gun = Rules.owner(source)
	if is_instance_valid(gun) and gun.position.distance_squared_to(owner.position)<=36.0*36.0:return false
	var event:="FX_YurikoShieldHitSmallMinor" if kind in ["bullet","cannon","laser","pierce","kinetic"] else "FX_YurikoShieldHitSmallMajor"
	var heading:Vector2=owner.position.direction_to(gun.position) if is_instance_valid(gun) else Vector2.RIGHT
	if not owner.special.has("psi_shield_fx_delay"):
		FX.show_fx(world,owner.position,event,owner,Vector2.ZERO,heading)
		owner.special.psi_shield_fx_delay=.1
	return true

static func cooldown_duration(actor, key: String, level := 1) -> float:
	var factor:=float(actor.special.get("psi_cooldown_factor",1.0))
	match key:
		"burst", "Lure": return 30.0*factor
		"Shield": return 15.0*factor
		"Slam": return (6.0-level)*factor
	return 0.0

static func ready(u, key: String) -> bool:
	return AlliedAbilities.alive(u) and u.embarked_in == null and u._stun_timer <= 0 and not AlliedAbilities.frozen(u) and not u._battle_world().ended and not u._battle_world().paused and not u.special.has("psi_cd_"+key)

static func burst(u) -> bool:
	if not ready(u,"burst"): return false
	u.special.psi_cast_anim = 2.0
	u.special.psi_cd_burst = cooldown_duration(u,"burst")
	u.special.psi_burst_delay = 0.4
	if u.yuriko_model.outfit>0:u.special.psi_ray_delay=u.yuriko_model.blast_ray_delay()
	var world=u._battle_world()
	u.special.psi_burst_origin=u.position
	Ra2Sfx.play_voice(u.data,"burst_yell",u.global_position)
	FX.show_fx(world,u.position,"FX_JapanCommandoSecondaryFire")
	for t in world.units+world.buildings:
		if not burst_target(world,u,t):continue
		var distance:float=Rules.point(u,t).distance_to(u.position)
		if t is Unit and AlliedAbilities.infantry(t) and distance<300 and not t.special.has("psi_holder") and not t.special.has("psi_flight"):
			var direction:Vector2=u.position.direction_to(t.position)
			var strength:=89.0*1.5*(1-distance/300.0)
			t.special.psi_burst_push={"age":0.0,"velocity":direction*strength,"height":strength*.25}
		elif distance<=187.5:
			if t is Building and "civilian" not in t.data.get("tags",[]):
				t.special.chrono_left=maxf(t.special.get("chrono_left",0),4.0)
			elif t is Unit and not AlliedAbilities.infantry(t):t.stun(4)
	return true

static func burst_target(world,u,t) -> bool:
	return world.actor_alive(t) and (Rules.enemy(u,t) or t.side=="neutral") and not (t is Unit and (t.is_air_target() or t.embarked_in!=null))

static func advance_push(t,dt:float) -> void:
	var push:Dictionary=t.special.psi_burst_push
	var previous:=float(push.age)
	push.age=minf(.45,previous+dt)
	var step:float=(push.age-previous)*(1.0-(push.age+previous)/.9)
	var next:Vector2=t.position+Vector2(push.velocity)*step
	var world=t._battle_world()
	if Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).has_point(next) and not world.path_service.is_blocked(next,t.is_naval):
		t.position=next
	if push.age>=.45:t.special.erase("psi_burst_push")
	t.queue_redraw()

static func area_radius(key: String, level: int) -> float:
	return ([60,90,120][clampi(level-1,0,2)] if key == "Lure" else [15,20,25][clampi(level-1,0,2)]) * 1.5

static func shield(u) -> bool:
	var world = u._battle_world()
	var level := rank(world,"Shield")
	if level == 0 or not ready(u,"Shield"): return false
	u.special.psi_cast_anim = 2.0
	u.special.psi_cd_Shield = cooldown_duration(u,"Shield")
	u.special.psi_shield = 3.0+2.0*level
	world.allied_state.yuriko_field = u
	Audio.start(u,"Shield")
	return true

static func valid_point(u, p: Vector2) -> bool:
	var world = u._battle_world()
	return p.is_finite() and Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).has_point(p) and world.position_explored_by(u.side,p)

static func order_power(u, key: String, p: Vector2) -> bool:
	if key not in ["Lure","Slam","Throw"] or not ready(u,key) or not valid_point(u,p): return false
	var level := rank(u._battle_world(),"Slam" if key=="Throw" else key)
	if level == 0 or (key == "Throw" and held(u).is_empty()): return false
	if u.position.distance_to(p) <= REACH: return cast_at(u,key,p,level)
	var goal := cast_position(u,p)
	if not goal.is_finite(): return false
	u.order_move(goal)
	u.special.psi_order = {"key":key,"point":p,"goal":goal}
	return true

static func cast_position(u, p:Vector2) -> Vector2:
	if u.position.distance_to(p)<=REACH: return u.position
	var nav = u._battle_world().path_service
	var direction: Vector2 = p.direction_to(u.position)
	for offset in [0,.35,-.35,.7,-.7,1.3,-1.3,PI]:
		var goal: Vector2 = p+direction.rotated(offset)*(REACH-24.0)
		if not Rect2(Vector2.ZERO,Vector2.ONE*u._battle_world().map_size).has_point(goal):continue
		var reachable:Vector2=nav.nearest_reachable(goal,u.position,false,2,true)
		if reachable.is_finite() and reachable.distance_to(p)<=REACH and not nav.is_blocked(reachable,false,true):return reachable
	return Vector2.INF

static func held(u) -> Array:
	return u.special.get("psi_held",[]).filter(func(t): return AlliedAbilities.alive(t) and t.special.get("psi_holder")==u)

static func cast_at(u,key: String,p:Vector2,level:int) -> bool:
	var world = u._battle_world()
	if not ready(u,key): return false
	if key == "Throw":
		var objects := held(u)
		if objects.is_empty(): return false
		for target in objects:
			target.special.erase("psi_holder")
			target.special.psi_flight = {"height":lift_height(target),"from":target.position,"to":p,"age":0.0,"duration":maxf(.12,target.position.distance_to(p)/(1.5*(775+25*level))),"caster":u}
		u.special.erase("psi_held")
		Audio.stop(u,"Slam")
		Ra2Sfx.play("JAP_Yuriko_PsychicSlamImpactCursor",p)
		return true
	if key=="Slam" and not held(u).is_empty(): return false
	var targets: Array = []
	for t in world.units:
		if not world.actor_alive(t) or t.unit_id==ID or t.embarked_in!=null or t.is_air_target() or NavalContact.submerged(t) or t.special.has("psi_holder") or t.special.has("psi_flight") or not world.actor_visible_to(u.side,t): continue
		if key=="Lure" and (not Rules.enemy(u,t) or not AlliedAbilities.infantry(t)): continue
		if t.position.distance_to(p)<=area_radius(key,level): targets.append(t)
	if targets.is_empty(): return false
	targets.sort_custom(func(a,b): return a.position.distance_squared_to(p)<b.position.distance_squared_to(p))
	if Rules.enemy(u,targets[0]):world.reveal_attack(u,targets[0])
	if key == "Lure":
		for t in u.special.get("psi_guards",[]):
			if AlliedAbilities.alive(t) and t.special.has("psi_original_side"): release_guard(t)
		targets.resize(mini(targets.size(),1+2*level))
		var offsets:=GUARD_OFFSETS.duplicate()
		if level==3:offsets=[Vector2(80,45),Vector2(80,-45)]+offsets
		for index in targets.size():
			var t=targets[index]
			t.special.psi_guard_offset=offsets[index]*1.5
			t.special.psi_original_side = t.side
			AlliedAbilities.change_side(t,u.side)
			t.set_fire_stance("free")
			guard_marker(world,t,u)
		Ra2Sfx.play("JAP_Yuriko_PsychicDomination2",p)
		u.special.psi_guards = targets
		u.special.psi_cast_anim = 2.0
		u.special.psi_cd_Lure = cooldown_duration(u,"Lure")
	else:
		for t in targets:
			t.order_stop()
			t.special.psi_holder = u
			apply_lift_material(t)
			FX.show_fx(world,t.position,"JapanPsyonic_End",t)
			t.special.psi_lift = 20.0
		Ra2Sfx.play("JAP_Yuriko_PsychicSlamLiftStart",p)
		Audio.start(u,"Slam")
		u.special.psi_held = targets
		u.special.psi_cd_Slam = cooldown_duration(u,"Slam",level)
	return true

static func guard_marker(world,t,caster=null) -> void:
	if not is_instance_valid(caster):
		for candidate in world.units:
			if AlliedAbilities.alive(candidate) and candidate.unit_id == ID and t in candidate.special.get("psi_guards", []):
				caster = candidate
				break
	if t.has_node("YurikoGuardMarker"):
		if is_instance_valid(caster):t.get_node("YurikoGuardMarker").caster_ref=weakref(caster)
		return
	var marker=FX.show_fx(world,t.position,"Lure",t,Vector2.ZERO,Vector2.RIGHT,caster if is_instance_valid(caster) else hero(world))
	if is_instance_valid(marker):
		marker.reparent(t)
		marker.top_level=true
		marker.position=t.art_center()
		marker.name="YurikoGuardMarker"

static func release_guard(t) -> void:
	var original: String = t.special.psi_original_side
	var marker=t.get_node_or_null("YurikoGuardMarker")
	if marker!=null:
		t.remove_child(marker)
		marker.queue_free()
	t.special.erase("psi_original_side")
	t.special.erase("psi_guard_offset")
	t.order_stop()
	AlliedAbilities.change_side(t,original)

static func crush(u,target) -> void:
	var airborne: bool = target is Unit and target.is_air_target()
	var weapon: Dictionary = u._weapon_for_target(target)
	var react := "FIRING_A"
	if target is Building: react = "FIRING_A REACT_3"
	elif target is Unit: react = "FIRING_A REACT_1" if airborne or AlliedAbilities.infantry(target) else "FIRING_A REACT_2"
	u.special.psi_fire_react = react
	if not airborne and (not u.has_node("YurikoAudioPrimary") or u.get_meta("psi_fx_target",0)!=target.get_instance_id()):
		Ra2Sfx.play("JAP_YurikoOmega_PsyonicVehicleLiftStart",u.global_position)
	Audio.start(u,"Primary")
	u.special.psi_fire_anim = maxf(.3, float(weapon.cooldown))
	var world=u._battle_world()
	if not u.special.has("psi_shot_fx_delay") or u.get_meta("psi_fx_target",0)!=target.get_instance_id():
		u.set_meta("psi_fx_target",target.get_instance_id())
		u.special.psi_shot_fx_delay=.22
		FX.show_fx(world,u.position,"JapanPsyonic_Start",u,RA2Art.art_dir(u.yuriko_model.head_offset()))
		var contact:Vector2=target.art_center()
		FX.show_fx(world,contact,"JapanPsyonic_End",target)
		if not target is ForceFirePoint:
			FX.show_fx(world,contact,"FX_JapanPsyonicMindInfantry" if target is Unit and AlliedAbilities.infantry(target) else "FX_JapanPsyonicMind",target)
	if target is ForceFirePoint:
		target.receive_hit(weapon.damage,"energy",{},u)
		return
	if airborne:
		if target.unit_id == "R3HARBINGER":
			target.receive_hit(float(weapon.damage)*u.bonuses.attack_bonus,"explosive",{},u)
			if AlliedAbilities.alive(target): target.add_buff("electric_slow",1.0,.5,"念动力")
		elif not target.special.has("iron_left"):
			if not target.special.has("psi_air_pull"):
				target.special.psi_air_pull={"height":maxf(target._visual_lift(),12.0),"caster":u}
			target.special.psi_air_pull.left=5.0
		return
	var damage:float=target.max_hp*float(weapon.max_health_fraction)*u.bonuses.attack_bonus
	target.receive_hit(damage,"energy",{},u)
	if target is Unit and target._dead and AlliedAbilities.infantry(target):FX.show_fx(world,target.position,"FX_JapanInfantryPsyonicDeath")
	if target is Unit and AlliedAbilities.alive(target) and not target.special.has("iron_left"):
		target.stun(.2)
		if not target.special.has("psi_holder") and not target.special.has("psi_flight"):
			var lift:Dictionary=target.special.get_or_add("psi_crush",{"height":0.0,"left":0.0})
			lift.left=.2

static func crush_pose(t,dt:float) -> void:
	var lift:Dictionary=t.special.psi_crush
	lift.left-=dt
	var rising:bool=lift.left>0 and not t.special.has("iron_left")
	lift.height=clampf(float(lift.height)+dt*(45.0 if rising else -95.0),0,112.5)
	if lift.height<=0 and not rising:t.special.erase("psi_crush")
	t.queue_redraw()

static func apply_lift_material(t) -> void:
	if t.has_meta("psi_lift_material"):return
	var original:Material=t.material
	var mat: ShaderMaterial
	if original is ShaderMaterial and original.shader == HouseColor.shader_res():
		mat = original.duplicate()
		mat.set_shader_parameter("psi_lift", true)
	else:
		mat = ShaderMaterial.new()
		mat.shader = preload("res://shaders/yuriko_lift.gdshader")
	t.set_meta("psi_lift_material",mat)
	if original!=null:t.set_meta("psi_previous_material",original)
	t.material=mat

static func clear_lift_material(t) -> void:
	if not t.has_meta("psi_lift_material"):return
	if t.material==t.get_meta("psi_lift_material"):t.material=t.get_meta("psi_previous_material",null) if t.has_meta("psi_previous_material") else null
	t.remove_meta("psi_lift_material")
	if t.has_meta("psi_previous_material"):t.remove_meta("psi_previous_material")

static func lift_height(t) -> float:
	if t.special.has("psi_flight"):
		var f:Dictionary=t.special.psi_flight
		var progress:=clampf(float(f.age)/f.duration,0,1)
		return lerpf(float(f.get("height",18)),0,progress)+30*sin(PI*progress)
	return clampf((20.0-float(t.special.get("psi_lift",20.0)))*30*4,0,90)*1.5*sqrt(.75)

static func carried_tick(t,dt:float) -> bool:
	if t._dead: return false
	if t.special.has("psi_burst_push"):
		advance_push(t,dt)
		return true
	if t.special.has("psi_air_pull"):
		var pull:Dictionary=t.special.psi_air_pull
		pull.height=maxf(0.0,float(pull.height)-dt*45.0)
		pull.left-=dt
		t.queue_redraw()
		if pull.height<=0:
			t.special.erase("psi_air_pull")
			var caster=pull.get("caster")
			var w=t._battle_world()
			for victim in w.units+w.buildings:
				if victim==t or not w.actor_alive(victim) or (victim is Unit and (victim.is_air_target() or victim.embarked_in!=null)): continue
				var distance:float=t.position.distance_to(Rules.point(t,victim))
				if distance<=75.0:
					var hit:=lerpf(500,200,distance/75.0)
					victim.receive_hit(hit*(.5 if BattleRequest.friendly(t.side,victim.side) else 1.0),"explosive",{},caster)
			t._die(caster)
		elif pull.left<=0 or t.special.has("iron_left"):
			t.special.erase("psi_air_pull")
		return true
	if t.special.has("psi_flight"):
		apply_lift_material(t)
		var f:Dictionary = t.special.psi_flight
		f.age += dt
		var fraction := clampf(float(f.age)/f.duration,0,1)
		t.position = f.from.lerp(f.to,fraction)
		t.queue_redraw()
		if fraction>=1:
			t.special.erase("psi_flight")
			clear_lift_material(t)
			var caster = f.get("caster")
			var world=t._battle_world()
			if not AlliedAbilities.infantry(t):
				for victim in world.units+world.buildings:
					if victim==t or not world.actor_alive(victim):continue
					if victim is Unit and (victim.unit_id==ID or victim.embarked_in!=null or victim.is_air_target()):continue
					if Rules.point(t,victim).distance_squared_to(t.position)<=THROW_RADIUS*THROW_RADIUS:
						victim.receive_hit(400,"explosive",{},caster)
			t._die(caster)
		return true
	if t.special.has("psi_holder"):
		apply_lift_material(t)
		t.special.psi_lift -= dt
		if t.special.psi_lift <= 0 or not AlliedAbilities.alive(t.special.psi_holder):
			t.special.erase("psi_holder")
			t.special.erase("psi_lift")
			clear_lift_material(t)
		t.queue_redraw()
		return true
	return false

static func update_guard(world: Battle, hero: Unit, guard: Unit) -> void:
	if guard.embarked_in != null: return
	var slot := hero.position + Vector2(guard.special.psi_guard_offset).rotated(hero.hull_angle)
	var radius := maxf(guard.sight, guard.attack_range)
	var distance_to_slot := guard.position.distance_to(slot)
	var regroup := distance_to_slot > radius
	if guard.hold_position:
		guard.cancel_stance()
		guard.set_fire_stance("free")
	var target = guard.attack_target
	if not regroup and Rules.enemy(guard, target) and world.actor_visible_to(guard.side, target, guard):
		var contact := Rules.point(guard, target)
		if slot.distance_to(contact) <= radius and guard.attack_domain_valid(target):
			if guard.attack_ordered or guard._weapon_target_valid(target): return
			guard.order_target(target, false, false)
			return
	if guard.attack_ordered: guard.order_stop(false)
	var attack_move := not regroup
	if distance_to_slot > 32 and (not guard.has_move_order or guard.move_target.distance_to(slot) > 24 or guard.attack_move != attack_move):
		guard.order_move(slot, attack_move, null, PackedVector2Array(), false)

static func tick(u,dt:float) -> void:
	var world = u._battle_world()
	if world == null or world.ended or u._dead: return
	for key in ["psi_hurt_voice_left","psi_guard_check","psi_shot_fx_delay","psi_shield_fx_delay","psi_cd_burst","psi_cd_Shield","psi_cd_Lure","psi_cd_Slam","psi_shield","psi_fire_anim","psi_cast_anim","psi_intro_anim"]:
		Rules.timer(u.special,key,dt)
	Audio.sync(u)
	if u.embarked_in != null: return
	if u.special.has("psi_guards") and not u.special.has("psi_guard_check"):
		u.special.psi_guard_check=.45
		for guard in u.special.psi_guards:
			if not AlliedAbilities.alive(guard) or not guard.special.has("psi_original_side"):continue
			update_guard(world,u,guard)
			guard_marker(world,guard,u)
	if u.special.has("psi_ray_delay"):
		u.special.psi_ray_delay-=dt
		if u.special.psi_ray_delay<=0:
			u.special.erase("psi_ray_delay")
			FX.show_fx(world,u.position,"FX_JapanCommandoBlast")
	if u.special.has("psi_burst_delay"):
		u.special.psi_burst_delay -= dt
		if u.special.psi_burst_delay<=0:
			u.special.erase("psi_burst_delay")
			var origin:Vector2=u.special.get("psi_burst_origin",u.position)
			u.special.erase("psi_burst_origin")
			for t in world.units+world.buildings:
				if not burst_target(world,u,t):continue
				var point:Vector2=t.closest_footprint_point(origin) if t is Building else t.position
				if point.distance_squared_to(origin)>187.5*187.5:continue
				world.reveal_attack(u,t)
				t.receive_hit(500*u.bonuses.attack_bonus,"energy",{},u)
				if t is Unit and t._dead and AlliedAbilities.infantry(t):FX.show_fx(world,point,"FX_JapanInfantryPsyonicBlastDeath")
	if u.special.has("psi_order"):
		var req: Dictionary = u.special.psi_order
		if u.has_move_order and u.move_target.distance_to(req.goal)>6 or not ready(u,req.key):
			u.special.erase("psi_order")
		elif u.position.distance_to(req.point)<=REACH:
			u.special.erase("psi_order")
			u.order_stop()
			cast_at(u,req.key,req.point,rank(world,"Slam" if req.key=="Throw" else req.key))
		elif not u.has_move_order: u.special.erase("psi_order")
	u.queue_redraw()

static func draw(u) -> void:
	if u.yuriko_model == null: return
	u.draw_texture_rect(u.yuriko_model.get_texture(),Rect2(-51,-62.7,102,102),false)
	var top:float=minf(-28,u.yuriko_model.head_offset().y-8)
	u._body_bounds = Rect2(-12,top,24,2-top)
