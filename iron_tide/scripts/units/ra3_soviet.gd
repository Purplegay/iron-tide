extends RefCounted
## Soviet SDK and EP1 HeavyWalker weapon sets, seconds and native distance x1.5.
const Split=preload("res://scripts/units/ra3_reaper_split.gd")
const Leap=preload("res://scripts/units/ra3_reaper_leap.gd")
const ReaperFlight=preload("res://scripts/units/ra3_reaper_flight.gd")
const TankFX=preload("res://scripts/units/ra3_tank_fx.gd")
const TankPose=preload("res://scripts/units/ra3_tank_presentation.gd")
const LABELS := {"R3TESLA":"短路放电","R3APOC":"磁力鱼叉","R3REAPER":"跳跃部署"}

static func ability(unit) -> Dictionary:
	var mode: bool=unit.special.get("soviet_mode",false)
	var ready: bool=AlliedAbilities.alive(unit) and unit.embarked_in==null and not AlliedAbilities.frozen(unit) and unit._stun_timer<=0 and not unit.special.has("walker_jump") and not unit.special.get("walker_deployed",false)
	return {"id":"allied_soviet_"+unit.unit_id.to_lower(),"name":LABELS[unit.unit_id],"desc":unit.data.desc,"ready":ready,"toggle":unit.unit_id!="R3REAPER","active":mode,"cd_left":0.0,"cooldown":0.0,"cd_frac":0.0,"glyph":"attack","icon":"res://assets/ra3/soviet/"+unit.unit_id+("/q_off.png" if mode else "/q.png")}

static func use(unit,point: Vector2) -> bool:
	if not ability(unit).ready:return false
	if unit.unit_id=="R3REAPER":
		var world=unit._battle_world()
		if not point.is_finite() or not Rect2(Vector2.ZERO,Vector2.ONE*world.map_size).has_point(point):return false
		point=Leap.landing_position(unit,point,unit.position)
		if not point.is_finite():return false
		var distance:float=unit.position.distance_to(point)
		if distance<30:return false
		if distance>300:
			var path: PackedVector2Array=unit._path_for(point+point.direction_to(unit.position)*275.0)
			if path.size()<2 or path[-1].distance_to(point)>300.0:return false
			unit.order_move(path[-1],false,null,path)
			unit.special.walker_approach=point
			return true
		unit.order_stop()
		unit.special.walker_jump=Leap.create(unit.position,point)
		return true
	unit.order_stop()
	if unit.unit_id=="R3APOC":
		unit.special.erase("twin_pending")
		unit.special.erase("twin_left")
		unit.special.erase("twin_target")
	if unit.unit_id=="R3APOC" and not unit.special.has("door_phase"):unit.special.door_phase=1.0 if unit.special.get("soviet_mode",false) else 0.0
	unit.special.soviet_mode=not unit.special.get("soviet_mode",false)
	unit.special.erase("harpoon_target")
	if unit.unit_id=="R3TESLA":unit._deployed=unit.special.soviet_mode
	else:
		unit.weapon.range=float(unit.data.weapon.range)*(1.25 if unit.veteran_level>=3 else 1.0)*(2.0 if unit.special.soviet_mode else 1.0)
		unit._refresh_weapon_derived()
		unit.sight=float(unit.data.sight)*(1.25 if unit.veteran_level>=3 else 1.0)*(1.65 if unit.special.soviet_mode else 1.0)
	return true

static func weapon_hit(source,target,amount: float,kind: String,attack_type: String="cannon") -> void:
	if not AlliedAbilities.alive(target):return
	var damage:=CombatMath.with_offense(Ra3Expansion.raw_damage(amount,kind,target),source.bonuses)
	var packet:Dictionary=source.bonuses
	if CombatMath.FinalDamage.active():packet=CombatMath.FinalDamage.packet(source.bonuses,Ra3Expansion.raw_damage(amount,kind,target)*float(source.bonuses.get("veteran_attack",1.0)))
	target.receive_hit(damage,attack_type,packet,source,"RA3_EXPANSION")

static func tick(unit,dt: float) -> void:
	if not AlliedAbilities.alive(unit) or unit.embarked_in!=null or AlliedAbilities.frozen(unit) or unit._stun_timer>0:
		unit.special.erase("tesla_charge_up")
		unit.special.erase("tesla_clip_target")
		return
	if unit.special.has("tesla_charge_up"):
		var charge:Dictionary=unit.special.tesla_charge_up
		var t=unit.attack_target
		if not AlliedAbilities.alive(t) or t!=charge.target or unit.special.get("soviet_mode",false) or not unit._weapon_target_valid(t) or not unit._weapon_aligned(t):
			unit.special.erase("tesla_charge_up")
		else:charge.age=minf(Ra3Expansion.tesla_balance.heroic_charge_seconds,float(charge.age)+dt)
	if unit.unit_id=="R3APOC":TankPose.tick(unit,dt)
	if unit.veteran_level==3:Ra3Mirage.tick_heroic_heal(unit,dt)
	if unit.special.has("split_enemy"):Split.secondary(unit)
	var mounts: Dictionary=unit.special.get("soviet_mounts",{})
	for mount in mounts.values():mount.left=maxf(0.0,float(mount.left)-dt)
	if unit.special.has("walker_approach"):
		var destination: Vector2=unit.special.walker_approach
		if unit.position.distance_to(destination)<=300:
			unit.special.erase("walker_approach")
			use(unit,destination)
		elif not unit.has_move_order:unit.special.erase("walker_approach")
	if unit.special.has("walker_jump"):
		var jump: Dictionary=unit.special.walker_jump
		jump.age+=dt
		if Leap.move(unit,jump):
			unit.special.erase("walker_jump");unit.special.erase("walker_height")
			var landing:=Leap.landing_position(unit,jump.end,jump.start,true)
			if not landing.is_finite():
				unit.position=unit._battle_world().path_service.nearest_reachable(jump.start,jump.start)
				unit.order_stop()
				return
			unit.position=landing
			unit.order_stop();unit._deployed=true;unit.special.walker_deployed=true;unit.velocity=Vector2.ZERO
			var frac: float=unit.hp/unit.max_hp
			unit._base_max_hp=900.0;unit.max_hp=900.0*(1.25 if unit.veteran_level>=2 else 1.0);unit.hp=unit.max_hp*frac
			var world=unit._battle_world()
			ReaperFlight.Particles.show_event(world,unit.position,"FX_SOV_ProtoSickle_MoveLand")
			ReaperFlight.Particles.show_event(world,unit.position,"FX_SovietSickleLand")
			for t in world.units+world.buildings:
				if not AlliedAbilities.alive(t) or BattleRequest.friendly(t.side,unit.side) or (t is Unit and (t.is_air_target() or t.embarked_in!=null)):continue
				var d: float=unit.position.distance_to(t.position)
				var leap_radius := 75.0 * Unit.Training.scale(unit)
				if d<=leap_radius:weapon_hit(unit,t,lerpf(120,40,d/leap_radius),"MELEE")
				if d<=22.5 and t is Unit and not AlliedAbilities.infantry(t):weapon_hit(unit,t,999999,"CRUSH")
			var building=world._place_building("R3REAPERTURRET",unit.side,landing,true)
			if building!=null:
				building.special=unit.special.duplicate(true)
				for round_node in world.projectiles_root.get_children():
					if round_node is Projectile and is_same(round_node.splinters.get("heat_owner"),unit):
						round_node.splinters.heat_owner=building
				building.special.walker_landing_age=maxf(0,jump.age-Leap.takeoff_seconds(jump)-jump.flight)
				building.special.walker_touch_frame=fposmod(jump.flight*30.0,31.0)
				building.special.walker_rank=unit.veteran_level
				building.special.walker_xp=unit._vet_kills
				building.special.walker_heading=unit.hull_angle
				building.max_hp=unit.max_hp;building.hp=unit.hp
				preload("res://scripts/buildings/ra3_reaper_emplacement.gd").mount(building)
				var keep_selection:bool=unit.side=="ally" and world.selected_units.size()==1 and world.selected_units.has(unit)
				world.units.erase(unit);world.selected_units.erase(unit)
				for group in world.control_groups:world.control_groups[group].erase(unit)
				unit.queue_free()
				if keep_selection:world.select_building(building)
				world._emit_selection()
		return
	if unit.unit_id=="R3TESLA" and unit.special.get("soviet_mode",false):
		unit.special.emp_left=float(unit.special.get("emp_left",0))-dt
		if unit.special.emp_left<=0:
			unit.special.emp_left=1.0
			for t in unit._battle_world().units:
				if not AlliedAbilities.alive(t) or BattleRequest.friendly(t.side,unit.side) or t.embarked_in!=null or AlliedAbilities.infantry(t) or t.is_air_target():continue
				if unit.position.distance_to(t.position)<=75.0 * Unit.Training.scale(unit):
					t.stun(1.1,"tesla_emp")
	if unit.unit_id=="R3APOC" and unit.special.has("harpoon_target"):
		var t=unit.special.harpoon_target
		if not AlliedAbilities.alive(t) or t!=unit.attack_target or not unit._weapon_target_valid(t) or not unit.special.get("soviet_mode",false):
			unit.special.erase("harpoon_target");return
		if not unit._weapon_aligned(t):
			unit.special.erase("crush_contact")
			return
		var distance:=preload("res://scripts/units/ra3_riot.gd").point_distance(t,unit.position)
		var gap:=maxf(0.0,distance-unit.radius-10.0)
		if t is Unit:t._stun_timer=maxf(t._stun_timer,0.1)
		if gap>2.0:
			var mover=t if t is Unit else unit
			var dest:Vector2=unit.position if t is Unit else t.position
			var step:=minf(gap,60.0*Unit.Training.scale(unit)*dt)
			mover.move_with_traffic_exceptions(mover.position.direction_to(dest)*step)
			unit.special.erase("crush_contact")
			return

		# GrapplingHookUpdate uses a continuous grinder plus a delayed single crush.
		var elapsed:float=unit.special.get("crush_contact",0.0)
		var next:=elapsed+dt
		if t is Unit and elapsed<1.0:next=minf(next,1.0)
		var pulses:=floori((next+0.000001)/0.25)-floori((elapsed+0.000001)/0.25)
		unit.special.crush_contact=next
		for i in pulses:
			TankFX.event(unit._battle_world(),TankFX.hit_point(t),"FX_Sov_TB_Grinder",unit.hull_angle)
			weapon_hit(unit,t,50,"EXPLOSIVE")
			if not AlliedAbilities.alive(t):return
		if t is Unit and elapsed<1.0 and next>=1.0:weapon_hit(unit,t,999999,"CRUSH","crush")

static func align_reaper(unit,dt:float) -> void:
	var target=unit.attack_target
	if not AlliedAbilities.alive(target) or (target is Unit and target.is_air_target()):return
	if unit.has_move_order or not unit.velocity.is_zero_approx() or unit.repairing or unit.special.has("walker_jump"):return
	if not BattleRequest.has_unit_talent(unit.unit_id,"reaper_fire_control",unit.side):return
	var world=unit._battle_world()
	if (world.command_mode==Split.ID and world.split_gunner==unit) or Split.secondary(unit)!=null:return
	if not unit._weapon_target_valid(target):return
	var direction:Vector2=target.global_position-unit.global_position
	if direction.is_zero_approx() or not ReaperFlight.Pose.in_range(ReaperFlight.Pose.definitions.rounds.grenade,direction.length(),float(unit.special.get("hero_range_aura",0))):return
	# The forward bearing lies in the intersection of the three native arcs
	# (0, +90 and -90 degrees, each with 90 degrees of traverse on both sides).
	unit.hull_angle=rotate_toward(unit.hull_angle,direction.angle(),deg_to_rad(float(unit._mv("rot",0)))*dt)

static func fire(unit) -> bool:
	var target=unit.attack_target
	if unit.special.has("walker_jump") or not unit._weapon_target_valid(target) or not unit._weapon_aligned(target):return false
	if unit.special.get("soviet_mode",false):
		if unit.unit_id=="R3TESLA":return false
		if unit.special.get("harpoon_target")!=target:
			unit.special.erase("crush_contact")
			weapon_hit(unit,target,1,"CANNON")
			Ra2Sfx.play("RA3_TANK_SOV_Apocalypse_WeaponHarpoon",unit.position)
		unit.special.harpoon_target=target
		return true
	if not unit.special.has("soviet_mounts"):unit.special.soviet_mounts={}
	var fired:=false
	if unit.unit_id=="R3REAPER":
		var offset:Vector2=target.global_position-unit.global_position
		var distance:=offset.length()
		var rocket:Dictionary=ReaperFlight.Pose.definitions.rounds.rocket
		if ReaperFlight.Pose.in_range(rocket,distance,float(unit.special.get("hero_range_aura",0))):
			fired=volley(unit,target,"rocket",rocket.clip_size,rocket.shot_interval,rocket.reload_seconds,7,375)
		var grenade:Dictionary=ReaperFlight.Pose.definitions.rounds.grenade
		var secondary=Split.secondary(unit)
		var cover:=Split.ground_cover(unit,target)
		var mounts:Array=ReaperFlight.Pose.definitions.grenade_mounts
		for i in mounts.size():
			var aim=target
			var automatic:=false
			if secondary!=null and unit.special.split_side_index==i:
				aim=secondary
			elif not cover.is_empty():
				automatic=true
				aim=cover[i]
				if not AlliedAbilities.alive(aim) or aim.is_air_target() or not unit._weapon_target_valid(aim) or not Split.covers(unit,aim,mounts[i]):continue
			elif not Split.covers(unit,target,mounts[i]):continue
			fired=volley(unit,aim,"grenade"+str(i+1),grenade.clip_size,grenade.shot_interval,grenade.reload_seconds,15,450,automatic) or fired
	else:
		fired=volley(unit,target,unit.unit_id,2,float(unit.weapon.burst_delay),float(unit.data.weapon.cooldown),float(unit.data.weapon.damage),1500)
	if fired:unit._muzzle=0.09;unit.special.reveal=2.0;unit.queue_redraw()
	return fired

static func volley(unit,target,key:String,count:int,interval:float,reload:float,amount:float,speed:float,automatic:bool=false) -> bool:
	var mounts: Dictionary=unit.special.soviet_mounts
	if not mounts.has(key):mounts[key]={"used":0,"left":0.0}
	var m: Dictionary=mounts[key]
	var heroic_tesla:bool=key=="R3TESLA" and unit.veteran_level==3
	if heroic_tesla and (int(m.used)==0 or unit.special.get("tesla_clip_target")!=target):
		var windup:float=Ra3Expansion.tesla_balance.heroic_charge_seconds
		if m.left>windup:return false
		var charge:Dictionary=unit.special.get("tesla_charge_up",{})
		if charge.is_empty() or charge.target!=target:
			unit.special.tesla_charge_up={"target":target,"age":0.0}
			return false
		if float(charge.age)+0.000001<windup:return false
	if m.left>0.000001:return false
	if key=="R3TESLA":unit.special.erase("tesla_charge_up")
	unit.special.ra3_barrel=int(m.used)%2
	var starts_clip:bool=int(m.used)==0
	if key=="rocket":unit.special.soviet_muzzle="FX_ROCKET%02d"%(int(m.used)%8+1)
	elif key.begins_with("grenade"):unit.special.soviet_muzzle=ReaperFlight.Pose.definitions.grenade_mounts[int(key.right(1))-1].bone
	m.used=(int(m.used)+1)%count
	if heroic_tesla:
		if m.used==0:unit.special.erase("tesla_clip_target")
		else:unit.special.tesla_clip_target=target
	m.left=(reload if m.used==0 else interval)/(1.2 if unit.veteran_level>=3 else 1.0)/(1.0+unit.buff_value("red_alert_haste"))
	m.duration=m.left # Snapshot this interval even if rank changes in flight.
	unit._cd_timer=m.left
	if key!="R3TESLA" or m.used==1:Ra2Sfx.play("RA3_SOV_FIRE_"+("grenade" if key.begins_with("grenade") else key),unit.position)
	var muzzle: Vector2=unit._weapon_muzzle()
	if key=="R3TESLA":
		TankPose.Beam.spawn(unit,target,false)
		TankFX.event(unit._battle_world(),TankFX.hit_point(target),TankFX.impact_id(target,unit.turret_angle,true))
		weapon_hit(unit,target,amount,"TESLA")
	else:
		var shot:=Projectile.new()
		shot.owner_side=unit.side;shot.attacker_bonus=unit.bonuses.duplicate(true);shot._credit_source=weakref(unit)
		shot.position=muzzle;shot.target=target;shot.target_point=target.position
		if key.begins_with("grenade"):
			shot.target_point+=Vector2.from_angle(randf()*TAU)*sqrt(randf())*30.0
		var heroic: bool=unit.veteran_level>=3
		var radius: float=(15.0 if heroic else 0.0) if key=="R3APOC" else (10.0 if key=="rocket" else 20.0)
		shot.splinters={"soviet_round":key,"start":muzzle,"age":0.0,"duration":maxf(0.025,unit.position.distance_to(target.position)/speed),"amount":125 if key=="R3APOC" and heroic else amount,"radius":radius*1.5,"kind":"ROCKET" if key=="rocket" else ("CANNON" if key=="R3APOC" and not heroic else "EXPLOSIVE")}
		shot.splinters.reference_amount=shot.splinters.amount
		if unit.unit_id=="R3REAPER" and not automatic:Split.apply_shot_talents(unit,shot)
		unit._battle_world().projectiles_root.add_child(shot)
		if key=="R3APOC":
			if not unit.special.has("barrel_age"):unit.special.barrel_age=[1.0,1.0]
			unit.special.barrel_age[int(unit.special.ra3_barrel)]=0.0
			shot.splinters.heroic_shell=heroic
			var barrel:=int(unit.special.ra3_barrel)
			shot.splinters.cannon_index=barrel
			if barrel==0 and unit.special.has("twin_pending"):
				unit.special.twin_left=unit.special.twin_pending
				var ability:Ability=unit.ability_at(UnitSkillLayout.find(unit,"ap_twin"))
				if ability!=null: ability.trigger_cooldown(maxf(0.6,Unit.Training.card_scale(unit)))
				unit.special.erase("twin_pending")
			if unit.special.has("twin_left"):
				if barrel==0:
					unit.special.twin_pair=int(unit.special.get("twin_pair",0))+1
					unit.special.erase("twin_target")
				shot.splinters.twin_pair=unit.special.get("twin_pair",0)
			if Effects.Looks.current(unit)==Effects.Looks.BlueArc.ID:
				shot.splinters.weapon_look=Effects.Looks.BlueArc.ID
				if target is Building:
					shot.splinters.blue_foundation = target.closest_footprint_point(unit.global_position)
				Effects.Looks.BlueArc.battle_event(unit._battle_world(),muzzle,true,unit.turret_angle)
			else:
				TankFX.event(unit._battle_world(),muzzle,TankFX.bank.cannon.hero_fire if heroic else TankFX.bank.cannon.fire,unit.turret_angle)
		else:ReaperFlight.launch(shot,unit)
	if starts_clip:preload("res://scripts/units/expansion_2_overload.gd").fired(unit)
	return true

static func advance(shot,dt:float) -> void:
	if shot.is_queued_for_deletion():return
	var state: Dictionary=shot.splinters
	state.age+=dt
	if state.soviet_round=="rocket" and AlliedAbilities.alive(shot.target):shot.target_point=shot.target.position
	var p:=clampf(float(state.age)/float(state.duration),0,1)
	if state.soviet_round=="R3APOC":shot.position=state.start.lerp(shot.target_point,p)
	else:
		if state.soviet_round=="rocket" and AlliedAbilities.alive(shot.target):
			state.target_height=shot.target._visual_lift() if shot.target is Unit else 0.0
		ReaperFlight.update(shot,p)
	if p<1:return
	var world=shot.get_parent().get_parent()
	var blue_arc:bool=state.get("weapon_look","")==Effects.Looks.BlueArc.ID
	if state.soviet_round=="R3APOC":
		if blue_arc:
			var point:Vector2=shot.position
			var ground:Vector2=point
			var foundation := state.has("blue_foundation") or is_instance_valid(shot.target) and shot.target is Building
			if foundation:
				# A shell already in flight in an older save has no cached foundation point.
				point = state.blue_foundation if state.has("blue_foundation") else shot.target.closest_footprint_point(state.start)
				ground = point
			elif not state.get("heroic_shell",false) and AlliedAbilities.alive(shot.target) and not shot.target is ForceFirePoint:
				point=TankFX.hit_point(shot.target)
				ground=shot.target.global_position
			Effects.Looks.BlueArc.battle_event(world,point,false,0.0,ground-point,foundation)
		elif state.get("heroic_shell",float(state.radius)>0):
			TankFX.event(world,shot.position,TankFX.bank.cannon.impacts[1])
		elif not AlliedAbilities.alive(shot.target) or shot.target is ForceFirePoint:
			TankFX.event(world,shot.position,TankFX.bank.cannon.impacts[0])
	else:
		var direct:bool=AlliedAbilities.alive(shot.target) and not shot.target is ForceFirePoint and preload("res://scripts/units/ra3_riot.gd").point_distance(shot.target,shot.target_point)<=float(state.radius)
		ReaperFlight.Particles.show_event(world,shot.position,ReaperFlight.event(state,"hit" if direct else "ground"),state.reaper_yaw)
	var victims: Array=[shot.target] if state.radius==0 else world.units+world.buildings
	for t in victims:
		if not AlliedAbilities.alive(t) or t is ForceFirePoint or (t is Unit and t.embarked_in!=null):continue
		if t is Unit and t.is_air_target() and state.soviet_round!="rocket":continue
		var distance:=preload("res://scripts/units/ra3_riot.gd").point_distance(t,shot.target_point)
		if state.soviet_round=="rocket":
			var height: float=t._visual_lift() if t is Unit else 0.0
			distance=Vector2(distance,height-float(state.get("target_height",0.0))).length()
		if state.radius>0 and distance>float(state.radius):continue
		var amount: float=state.amount
		var reference_amount:float=state.get("reference_amount",amount)
		var focused:bool=is_same(t,shot.target) and state.has("focus_multiplier")
		var owner=state.get("heat_owner")
		var layers:Array=[]
		if is_same(t,shot.target) and AlliedAbilities.alive(owner):layers=Split.heat_layers(owner,t)
		var retained:=not layers.is_empty()
		if retained:amount*=1.0+layers.size()*(float(state.split_heat_multiplier)-1.0)
		elif focused:amount*=float(state.focus_multiplier)
		if state.soviet_round=="rocket":
			var falloff:=1.0-clampf(distance/float(state.radius),0,1)
			amount*=falloff
			reference_amount*=falloff
		if state.soviet_round=="R3APOC" and not blue_arc:
			var heading:float=state.start.direction_to(shot.target_point).angle()
			TankFX.event(world,TankFX.hit_point(t),TankFX.impact_id(t,heading,false),heading)
		var launcher=shot.shooter()
		var calibration:bool=state.soviet_round=="R3APOC" and is_same(t,shot.target) and AlliedAbilities.alive(launcher) and launcher.special.has("twin_left")
		# Saves from before multi-round calibration have neither a pair tag nor a quota.
		if calibration and launcher.special.has("twin_remaining"):
			calibration=state.has("twin_pair") and state.twin_pair==launcher.special.get("twin_pair",-1)
		var paired:bool=calibration and state.get("cannon_index",-1)==1 and is_same(launcher.special.get("twin_target"),t)
		if paired:amount*=1.0+float(launcher.special.twin_value)
		var hp_before:float=t.hp
		Ra3Expansion.hit(shot,t,amount,state.kind,reference_amount)
		if t.hp>=hp_before:continue
		if calibration and state.get("cannon_index",-1)==0: launcher.special.twin_target=t
		if paired:
			launcher.special.twin_remaining=int(launcher.special.get("twin_remaining",1))-1
			if launcher.special.twin_remaining<=0: launcher.special.erase("twin_left")
			launcher.special.erase("twin_target")
			Unit.FactionCards.feedback(t,"Twin")
		if retained:
			var rule:=BattleRequest.talent_upgrade("R3REAPER","reaper_fire_control",owner.side)
			if not rule.is_empty():layers.fill(float(rule.linger))
		if (focused or retained or state.get("split_boosted",false)) and world.actor_visible_to("ally",t):
			const Feedback=preload("res://scripts/units/ra3_reaper_heat.gd")
			if focused or retained:Feedback.on_hit(world,t,false,layers.size() if retained else int(state.get("focus_stacks",1)))
			if state.get("split_boosted",false):Feedback.on_hit(world,t,true)
	if state.soviet_round!="R3APOC":ReaperFlight.RoundVisual.release(shot)
	shot.queue_free()
