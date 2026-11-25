extends RefCounted
## Iron Tide W card. Both forms use the sectors and magazine timers of the Uprising weapon set.
const Pose=preload("res://scripts/units/ra3_reaper_pose.gd")
const ID:="reaper_split_fire"
const LABEL:="分区射击"
const HINT:="先指定主攻击目标，再按 W 左键指定左右扇形内的另一名地面敌人，由一门侧炮攻击，右键取消。"
const SIDE_MOUNTS:=[1,2] # Uprising weapon slots 3 and 4; index 0 is the front grenade.
const COLORS:=[Color("#ffca59"),Color("#65ccff"),Color("#b8ec70")]

# Layers belong to each Reaper and target. Primary and W assignments charge independently.
static func heat_layers(actor,target) -> Array:
	var heat:Dictionary=actor.special.get("reaper_heat",{})
	var layers=heat.get(target,[])
	if layers is Array:return layers
	# Older saves stored one remaining lifetime per target.
	var rule:=BattleRequest.talent_upgrade("R3REAPER","reaper_fire_control",actor.side)
	var remaining:=minf(float(layers),float(rule.get("linger",0)))
	heat[target]=[remaining] if remaining>0.0 else []
	return heat[target]

static func advance_focus(actor,dt:float) -> void:
	var heat:Dictionary=actor.special.get("reaper_heat",{})
	for enemy in heat.keys():
		if not AlliedAbilities.alive(enemy):
			heat.erase(enemy)
			_redraw_stacks(actor)
			continue
		var layers:=heat_layers(actor,enemy)
		for i in range(layers.size()-1,-1,-1):
			layers[i]-=dt
			if layers[i]<=0.000001:
				layers.remove_at(i)
				_redraw_stacks(actor)
		if layers.is_empty():heat.erase(enemy)
	if heat.is_empty():actor.special.erase("reaper_heat")
	if not actor.special.has("reaper_focus") and not actor.special.has("split_focus"):return
	var target=actor.attack_target
	var gun=actor.get_node_or_null("ReaperMount") if actor is Building else actor
	if (not AlliedAbilities.alive(target) or gun==null or AlliedAbilities.frozen(actor)
			or (actor is Building and not actor.is_operational()) or gun.embarked_in!=null
			or gun._stun_timer>0 or gun.special.has("walker_jump") or not gun._weapon_target_valid(target)
			or not gun._weapon_aligned(target)
			or not Pose.in_range(Pose.definitions.rounds.rocket,gun.global_position.distance_to(target.global_position),float(gun.special.get("hero_range_aura",0)))):
		actor.special.erase("reaper_focus")
		actor.special.erase("split_focus")
		return
	if actor.special.has("reaper_focus"):_advance_target(actor,"reaper_focus",target,dt)
	if actor.special.has("split_focus"):
		var other=secondary(gun)
		if other!=null and is_same(actor.special.get("split_primary"),target):
			_advance_target(actor,"split_focus",other,dt)
		else:actor.special.erase("split_focus")

static func _advance_target(actor,key:String,target,dt:float) -> void:
	var focus:Dictionary=actor.special[key]
	if not focus.has("charge_left") or not is_same(focus.get("target"),target):
		actor.special.erase(key)
		return
	if not focus.has("interval"):
		var rule:=BattleRequest.talent_upgrade("R3REAPER","reaper_fire_control",actor.side)
		if rule.is_empty():return
		focus.interval=rule.charge_seconds
		focus.linger=rule.linger
		if focus.charge_left<=0 and actor.special.get("reaper_heat",{}).has(target):focus.charge_left=focus.interval
	focus.charge_left-=dt
	if focus.charge_left>0.000001:return
	var interval:=float(focus.interval)
	var lifetime:=float(focus.linger)
	var cap:=ceili(lifetime/interval)
	# A long simulation step can cross several charge or expiry boundaries.
	var gained:=1+floori((-float(focus.charge_left)+0.000001)/interval)
	focus.charge_left+=gained*interval
	var newest_left:=lifetime-(interval-float(focus.charge_left))
	var layers:=heat_layers(actor,target)
	for i in range(mini(gained,cap)-1,-1,-1):
		var left:=newest_left-i*interval
		if left<=0.000001:continue
		if layers.size()>=cap:layers.pop_front()
		layers.append(left)
	if not actor.special.has("reaper_heat"):actor.special.reaper_heat={}
	actor.special.reaper_heat[target]=layers
	_redraw_stacks(actor)

static func _redraw_stacks(actor) -> void:
	var canvas=actor.get_node_or_null("ReaperMount") if actor is Building else actor
	if is_instance_valid(canvas):canvas.queue_redraw()

static func _begin_focus(gun,key:String,target,rule:Dictionary) -> void:
	var previous:Dictionary=gun.special.get(key,{})
	if not previous.has("charge_left") or not is_same(previous.get("target"),target):
		gun.special[key]={"target":target,"charge_left":rule.charge_seconds,"interval":rule.charge_seconds,"linger":rule.linger}

static func apply_shot_talents(gun,shot) -> void:
	var rule:=BattleRequest.talent_upgrade(gun.unit_id,"reaper_fire_control",gun.side)
	if not is_same(shot.target,gun.attack_target):
		var multiplier:=damage_scale(gun)
		if multiplier>1.0:
			shot.splinters.amount*=multiplier
			shot.splinters.split_boosted=true
		if not rule.is_empty():
			if is_same(shot.target,gun.special.get("split_enemy")):
				_begin_focus(gun,"split_focus",shot.target,rule)
			var host=gun.get_parent()
			shot.splinters.heat_owner=host if host is Building else gun
			shot.splinters.split_heat_multiplier=rule.damage
		return
	if rule.is_empty():return
	if shot.target is ForceFirePoint:
		gun.special.erase("reaper_focus")
		return
	_begin_focus(gun,"reaper_focus",shot.target,rule)
	var stacks:=heat_layers(gun,shot.target).size()
	if stacks>0:
		shot.splinters.focus_stacks=stacks
		shot.splinters.focus_multiplier=1.0+stacks*(float(rule.damage)-1.0)

static func unlocked(gun) -> bool:
	if not AlliedAbilities.alive(gun) or gun.unit_id!="R3REAPER" or not BattleRequest.extensions_enabled():return false
	return UnitSkillLayout.find(gun,ID)>=0 or legacy_rank(gun)>=0

static func legacy_rank(gun) -> int:
	if gun.side!="ally" or int(BattleRequest.combat_context.get("native_training_version",4))>=4:return -1
	var selections=BattleRequest.combat_context.get("unit_talents",{}).get("R3REAPER",{})
	if selections is Dictionary and selections.has(ID):return clampi(int(selections[ID]),0,3)
	return 0 if selections is Array and selections.has(ID) else -1

static func damage_scale(gun) -> float:
	var index:=UnitSkillLayout.find(gun,ID)
	if index>=0:return gun.skills[index].value
	var rank:=legacy_rank(gun)
	return float([1.0,1.1,1.35,1.5][rank]) if rank>=0 else 1.0

static func selected(world):
	var building=world.selected_building
	if is_instance_valid(building) and building.building_id=="R3REAPERTURRET" and building.side=="ally":
		return building.get_node_or_null("ReaperMount")
	return world.selected_skill_unit()

static func covers(gun,target,mount:Dictionary) -> bool:
	if target is Unit and target.is_air_target():return false
	return covers_ground_offset(gun,target.global_position-gun.global_position,mount)

static func covers_ground_offset(gun,offset:Vector2,mount:Dictionary) -> bool:
	if not Pose.in_range(Pose.definitions.rounds.grenade,offset.length(),float(gun.special.get("hero_range_aura",0))):return false
	var bearing:float=offset.angle()-gun.hull_angle
	return absf(angle_difference(Pose.barrel_heading(mount,bearing),bearing))<=0.000001

static func has_ordered_enemy(gun) -> bool:
	var target=gun.attack_target
	if not AlliedAbilities.alive(target) or not (target is Unit or target is Building) or BattleRequest.friendly(target.side,gun.side):return false
	var host=gun.get_parent()
	if host is Building:
		return is_same(host.attack_target,target) and (is_same(host.special.get("reaper_ordered_target"),target) or ForceFire.active(host,target))
	return gun.attack_ordered

static func engaged(gun) -> bool:
	if not unlocked(gun) or not has_ordered_enemy(gun):return false
	if gun.embarked_in!=null or gun._stun_timer>0 or AlliedAbilities.frozen(gun) or gun.special.has("walker_jump"):return false
	var host=gun.get_parent()
	return (not host is Building or host.is_operational()) and gun._weapon_target_valid(gun.attack_target)

static func valid_enemy(gun,target) -> bool:
	if not AlliedAbilities.alive(target) or target==gun.attack_target or BattleRequest.friendly(target.side,gun.side):return false
	if target is Unit and (target.embarked_in!=null or target.is_air_target()):return false
	return gun._battle_world().actor_visible_to(gun.side,target)

# Transient targeting cache shared by firing and barrel animation. Rebuild once
# per acquisition interval, including when no ground contacts are available.
static func ground_cover(gun,primary) -> Array:
	if not (primary is Unit and primary.is_air_target() and unlocked(gun)):
		if gun.has_meta(&"reaper_aa_cover"):gun.remove_meta(&"reaper_aa_cover")
		return []
	var cache:Dictionary=gun.get_meta(&"reaper_aa_cover",{})
	var frame:=Engine.get_physics_frames()
	if is_same(cache.get("primary"),primary) and frame<int(cache.get("refresh",0)):
		return cache.targets
	var mounts:Array=Pose.definitions.grenade_mounts
	var targets:=[null,null,null]
	var distances:=[INF,INF,INF]
	var reach:float=Pose.definitions.rounds.grenade.max_range*1.5+float(gun.special.get("hero_range_aura",0))
	for enemy in gun.get_tree().get_nodes_in_group(BattleRequest.foes_group(gun.side)):
		if not enemy is Unit or not AlliedAbilities.alive(enemy) or enemy.is_air_target():continue
		var distance:float=gun.global_position.distance_squared_to(enemy.global_position)
		if distance>reach*reach or not gun._weapon_target_valid(enemy):continue
		for i in mounts.size():
			if distance<distances[i] and covers(gun,enemy,mounts[i]):
				targets[i]=enemy
				distances[i]=distance
	gun.set_meta(&"reaper_aa_cover",{"primary":primary,"targets":targets,"refresh":frame+maxi(1,Engine.physics_ticks_per_second/4)})
	return targets

static func choose_side(gun,target) -> int:
	var chosen:=-1
	for i:int in SIDE_MOUNTS:
		var mount:Dictionary=Pose.definitions.grenade_mounts[i]
		if covers(gun,target,mount):
			if not covers(gun,gun.attack_target,mount):return i
			if chosen<0:chosen=i
	return chosen

static func clear(actor) -> void:
	if not actor.special.has("split_enemy"):return
	for field in ["split_enemy","split_primary","split_side_index","split_mount","split_focus"]:
		actor.special.erase(field)

static func secondary(gun):
	if not gun.special.has("split_enemy"):return null
	var other=gun.special.get("split_enemy")
	if engaged(gun) and is_same(gun.special.get("split_primary"),gun.attack_target) and valid_enemy(gun,other):
		# Earlier builds numbered map sides in the opposite yaw convention.
		if gun.special.has("split_mount"):
			var legacy:int=gun.special.split_mount
			if legacy in SIDE_MOUNTS:gun.special.split_side_index=3-legacy
			gun.special.erase("split_mount")
		# Older target-only saves bind the side on first use.
		if not gun.special.has("split_side_index"):gun.special.split_side_index=choose_side(gun,other)
		var assigned:int=gun.special.split_side_index
		if assigned in SIDE_MOUNTS and covers(gun,other,Pose.definitions.grenade_mounts[assigned]):return other
	clear(gun)
	return null

static func arm(world,gun) -> void:
	if world.command_mode==ID:
		world.arm_command("")
	elif not has_ordered_enemy(gun):
		Events.emit_message("请先指定主攻击目标。")
	elif not engaged(gun):
		Events.emit_message("请等待收割者进入射程并恢复攻击。")
	else:
		world.arm_command(ID)
		world.split_gunner=gun
		Events.emit_message(HINT)

static func confirm(world,point:Vector2) -> void:
	var gun=world.split_gunner
	if not is_instance_valid(gun) or gun!=selected(world) or not engaged(gun):
		world.arm_command("")
		return
	var target=world._pick_enemy_at(point)
	if not assign(gun,target):
		Events.emit_message(HINT)
		return
	world.arm_command("")
	world._add_order_mark(target.global_position,"attack")

static func assign(gun,target) -> bool:
	if not engaged(gun):return false
	var side:=choose_side(gun,target) if valid_enemy(gun,target) else -1
	if side<0:return false
	gun.special.erase("split_mount")
	gun.special.split_side_index=side
	if not is_same(target,gun.special.get("split_enemy")):gun.special.erase("split_focus")
	gun.special.split_primary=gun.attack_target
	gun.special.split_enemy=target
	if gun._ra3_model!=null:gun._ra3_model._sample(0.0)
	return true

static func paint(canvas,world) -> void:
	if world.command_mode!=ID or not is_instance_valid(world.split_gunner):return
	var gun=world.split_gunner
	var rule:Dictionary=Pose.definitions.rounds.grenade
	for index:int in SIDE_MOUNTS:
		var mount:Dictionary=Pose.definitions.grenade_mounts[index]
		var facing:float=gun.hull_angle+Pose.natural_heading(mount)
		var lo:=facing-deg_to_rad(float(mount.anticlockwise))
		var hi:=facing+deg_to_rad(float(mount.clockwise))
		var points:=PackedVector2Array()
		for i in 33:
			points.append(gun.global_position+Vector2.from_angle(lerpf(lo,hi,i/32.0))*(float(rule.max_range)*1.5+float(gun.special.get("hero_range_aura",0))))
		for i in range(32,-1,-1):
			points.append(gun.global_position+Vector2.from_angle(lerpf(lo,hi,i/32.0))*float(rule.min_range)*1.5)
		var color:Color=COLORS[index]
		canvas.draw_colored_polygon(points,Color(color,0.17))
		points.append(points[0])
		canvas.draw_polyline(points,color,2,true)
