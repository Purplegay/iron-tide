class_name Ra3Expansion
extends RefCounted
## Uprising XML authority; continuous-world adapters are documented in RA3_PORTING.md.
static var tesla_balance:Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_gameplay_balance.json")).tesla_tank
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_expansion_rules.json"))
static var damage_rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra3/expansion/damage/rules.json"))
const RIOT := preload("res://scripts/units/ra3_riot.gd")
const FUTURE := "R3FUTURE"
const HARBINGER := "R3HARBINGER"
const BEAM := "allied_ra3_riot"
const TOGGLE := "allied_ra3_gunship"
static var laser_texture: Texture2D = load("res://assets/ra3/expansion/fx/FXAlliedFutureLaser.png")
static var shell_texture: Texture2D = load("res://assets/ra3/expansion/fx/FXAlliedProtonColliderHitCoreDiffuse.png")

static func handles(actor) -> bool:
	return actor is Unit and actor.unit_id in [FUTURE,HARBINGER]

static func voice_kind(actor, kind: String) -> String:
	if kind=="select":
		if float(actor.special.get("ra3_under_fire",0.0))>0.0:return "select_under_fire"
		if AlliedAbilities.alive(actor.attack_target):return "select_battle"
	if kind=="move" and actor.attack_move:return "move_attack"
	if kind=="attack":
		if actor.unit_id==HARBINGER and actor.special.get("ra3_gun_mode",false):return "attack_special"
		if actor.unit_id==FUTURE and (actor.special.has("ra3_riot_point") or preload("res://scripts/units/ra3_future_state.gd").pending(actor)):return "attack_beam"
	return kind

static func damaged_speed_factor(actor) -> float:
	if not handles(actor) or actor.hp/maxf(1,actor.max_hp)>float(damage_rules.thresholds.MaxHealthDamagedPercentage):return 1.0
	# ActiveBody DAMAGED threshold + locomotor override. Gunship inherits 100%.
	var value: String=rules.objects[actor.unit_id].locomotor.get("MaxSpeedDamaged","100%")
	return float(value.trim_suffix("%"))/100.0

static func rank_requirement(actor) -> float:
	if actor.veteran_level>=3:return 0.0
	var steps: Array=actor.data.soviet_ra3.experience if actor.data.has("soviet_ra3") else rules.objects[actor.unit_id].experience
	if actor.unit_id=="R3TESLA":steps=tesla_balance.promotion_thresholds
	return float(steps[actor.veteran_level])-float(steps[actor.veteran_level-1] if actor.veteran_level>0 else 0)

static func rank_status(actor) -> Dictionary:
	var needed:=rank_requirement(actor)
	return {"enabled":true,"rank":actor.veteran_level,"level":actor.veteran_level+1,"name":["新兵","老兵","精英","英雄"][actor.veteran_level],"maxed":actor.veteran_level>=3,"current":actor._vet_kills,"required":needed,"progress":1.0 if needed==0 else actor._vet_kills/needed}

static func credit_kill(actor, value: float, side: String) -> void:
	if side==actor.side or not AlliedAbilities.alive(actor) or actor.veteran_level>=3:return
	actor._vet_kills+=maxf(0.0,value)
	while actor.veteran_level<3 and actor._vet_kills>=rank_requirement(actor):
		actor._vet_kills-=rank_requirement(actor)
		actor._grant_veteran(actor.veteran_level+1,true)

static func apply_veterancy(actor, announce: bool) -> void:
	var fraction: float=actor.hp/maxf(1.0,actor.max_hp)
	actor._clear_veteran_bonuses()
	actor._vet_self_heal=0.0
	if actor.veteran_level<3:actor.special.erase("ra3_heal_remaining")
	elif not actor.special.has("ra3_heal_remaining"):actor.special.ra3_heal_remaining=1.0
	# Uprising uses shared Rank2/3/4 modifiers; no YR ROF or speed bonus.
	actor.bonuses.veteran_attack=1.25 if actor.veteran_level>=1 else 1.0
	actor.max_hp=actor._base_max_hp*(1.25 if actor.veteran_level>=2 else 1.0)
	actor.hp=actor.max_hp*fraction
	actor.sight=float(actor.data.sight)*(1.25 if actor.veteran_level>=3 else 1.0)
	actor.weapon=actor.data.weapon.duplicate(true)
	if actor.unit_id==HARBINGER and actor.special.get("ra3_gun_mode",false):
		actor.weapon.range=450.0;actor.weapon.cooldown=0.1;actor.weapon.damage=12.0;actor.weapon.min_range=0.0
		for modifier: Dictionary in rules.objects[HARBINGER].gun_mode_modifier.modifiers:
			if modifier.Type=="VISION":actor.sight*=float(str(modifier.Value).trim_suffix("%"))/100.0
	if actor.veteran_level>=3:
		actor.weapon.range*=1.25;actor.weapon.cooldown/=1.2
	if actor.unit_id=="R3APOC" and actor.special.get("soviet_mode",false):
		actor.weapon.range*=2.0;actor.sight*=1.65
	actor._ra2_weapon_override={}
	actor._vet_need=rank_requirement(actor)
	actor._vet_value=float(actor.data.soviet_ra3.experience_award[actor.veteran_level]) if actor.data.has("soviet_ra3") else float(rules.objects[actor.unit_id].experience_award[actor.veteran_level])
	actor._refresh_weapon_derived()
	if announce:preload("res://scripts/ui/veterancy_indicator.gd").promote(actor)

static func info(actor) -> Dictionary:
	var future: bool = actor.unit_id == FUTURE
	var left:=float(actor.special.get("ra3_riot_cd",0.0))
	var gun: bool = actor.special.get("ra3_gun_mode",false)
	return {"id":BEAM if future else TOGGLE,"name":"暴乱光束" if future else ("切换对撞炮" if gun else "切换机炮"),
		"desc":("指定地面位置，准备后双束交叉扫射，冷却%s秒。对建筑伤害降至原来的%d%%。" % [Ability.cooldown_text(RIOT.cooldown() / Unit.Training.timing_scale(actor)), roundi(float(RIOT.balance.structure_damage_multiplier)*100.0)]) if future else "切换两门对地对撞炮与前部机炮；不能防空。",
		"ready":AlliedAbilities.alive(actor) and not AlliedAbilities.frozen(actor) and actor._stun_timer<=0.0 and actor.embarked_in==null and left<=0.0 and not actor.special.has("ra3_riot_point") and not actor.special.has("ra3_riot_approach"),
		"cd_left":left,"cooldown":RIOT.cooldown() / Unit.Training.timing_scale(actor) if future else 0.0,"cd_frac":left / (RIOT.cooldown() / Unit.Training.timing_scale(actor)),"toggle":not future,"active":gun,"glyph":"attack",
		"icon":"res://assets/ra3/expansion/future/ability.png" if future else "res://assets/ra3/expansion/harbinger/button.png"}

static func use(actor, point: Vector2) -> bool:
	if not info(actor).ready:return false
	if actor.unit_id==HARBINGER:
		preload("res://scripts/units/ra3_gunship_mounts.gd").states(actor)
		actor.special.ra3_gun_mode=not bool(actor.special.get("ra3_gun_mode",false))
		preload("res://scripts/units/ra3_gunship_mounts.gd").refresh_display(actor)
		actor.special.ra3_fire_anim=0.0
		for mount in actor.special.ra3_mounts.values():mount.flash=0.0
		actor._cancel_burst()
		actor.weapon=actor.data.weapon.duplicate(true)
		actor.weapon.range=450.0 if actor.special.ra3_gun_mode else 600.0
		actor.weapon.cooldown=0.1 if actor.special.ra3_gun_mode else 2.0
		actor.weapon.damage=12.0 if actor.special.ra3_gun_mode else 100.0
		actor._refresh_weapon_derived()
		apply_veterancy(actor,false)
		Ra2Sfx.play("RA3_EXP_ALL_Gunship_Weapon%dToggleMS" % (2 if actor.special.ra3_gun_mode else 1),actor.position)
		return true
	return RIOT.request(actor,point)

static func tick(actor, delta: float) -> void:
	if not handles(actor):return
	actor.special.ra3_under_fire=maxf(0.0,float(actor.special.get("ra3_under_fire",0.0))-delta)
	if actor.unit_id==HARBINGER and not AlliedAbilities.frozen(actor) and actor._stun_timer<=0.0:
		preload("res://scripts/units/ra3_gunship_mounts.gd").tick(actor,delta)
	preload("res://scripts/units/ra3_future_state.gd").tick(actor,delta)
	actor.special.ra3_fire_anim=maxf(0.0,float(actor.special.get("ra3_fire_anim",0.0))-delta)
	if actor.veteran_level>=3:Ra3Mirage.tick_heroic_heal(actor,delta)
	tick_passive_heal(actor,delta)
	actor.special.ra3_riot_cd=maxf(0.0,float(actor.special.get("ra3_riot_cd",0.0))-delta)
	RIOT.approach_tick(actor,delta)
	if not actor.special.has("ra3_riot_point"):return
	if AlliedAbilities.frozen(actor) or actor._stun_timer>0.0:return
	actor.special.ra3_riot_time=float(actor.special.ra3_riot_time)+delta
	actor.turret_angle=actor.position.direction_to(actor.special.ra3_riot_point).angle()
	actor.velocity=Vector2.ZERO
	var unpack:=float(actor.special.get("ra3_riot_unpack",1.0))
	if float(actor.special.ra3_riot_time)>=unpack and not actor.special.ra3_riot_fired:
		actor.special.ra3_riot_fired=true
		var shot:=make_shot(actor,null,actor.special.ra3_riot_point,"riot")
		shot.splinters.origin=actor.position
		shot.splinters.muzzles=riot_muzzles(actor)
		preload("res://scripts/units/ra3_future_beam.gd").spawn(shot)
		Ra2Sfx.play("RA3_EXP_ALL_FutureTank_DeathRayWeaponFire",actor.position)
	if float(actor.special.ra3_riot_time)>=unpack+RIOT.duration()+RIOT.seconds(RIOT.rules.beam.PackTime):
		actor.special.erase("ra3_riot_point")

static func tick_passive_heal(actor, delta: float) -> void:
	# Both Uprising units declare Upgrade_PassiveHeal, a separate module
	# from BaseVehicle/Upgrade_HeroicHeal. Both run in combat, even at full health.
	if not handles(actor) or not AlliedAbilities.alive(actor) or AlliedAbilities.frozen(actor):return
	var rule: Dictionary=rules.objects[actor.unit_id].passive_heal
	var left: float=float(actor.special.get("ra3_passive_heal_remaining",RIOT.seconds(rule.StartHealingDelay)))-delta
	while left<=0.000001:
		actor.heal(float(rule.HealingAmount))
		left+=RIOT.seconds(rule.HealingDelay)
	actor.special.ra3_passive_heal_remaining=left

static func make_shot(actor, target, point: Vector2, mode: String) -> Projectile:
	var shot:=Projectile.new()
	shot.owner_side=actor.side;shot._credit_source=weakref(actor);shot.target=target;shot.target_point=point
	shot.attacker_bonus=actor.bonuses.duplicate(true);shot.ra2_warhead="RA3_EXPANSION"
	shot.position=actor._weapon_muzzle()
	shot.splinters={"ra3_expansion":mode,"age":0.0,"pulse":0.0,"start":shot.position,"ground_start":actor.position}
	if mode=="neutron":
		var primary_factor:float=actor.FactionCards.primary_shot(actor,target,shot.attacker_bonus)
		if primary_factor>1.0:shot.splinters.phase_factor=primary_factor
		shot.splinters.neutron_pre=0;shot.splinters.neutron_tick=0;shot.splinters.neutron_direct=false
		preload("res://scripts/units/ra3_neutron_flight.gd").setup(shot,actor)
	if mode=="riot":shot.splinters.riot_hz=float(RIOT.rules.adapter.continuous_damage_hz)
	shot.splinters.heroic=actor.veteran_level>=3
	actor._battle_world().projectiles_root.add_child(shot)
	return shot

static func riot_muzzles(actor) -> Array[Vector2]:
	if actor._ra3_model!=null:
		actor._ra3_model.sync_pose()
		return [actor._ra3_model.bone_world("FX_WEAPON_01"),actor._ra3_model.bone_world("FX_WEAPON_02")]
	return [actor._weapon_muzzle(),actor._weapon_muzzle()]

static func riot_endpoints(shot) -> Array[Vector2]:
	return RIOT.endpoints(shot,float(shot.splinters.age))

static func shoot(actor, target) -> void:
	if actor.special.has("ra3_riot_point") or actor.special.has("ra3_riot_approach"):return
	actor.special.ra3_fire_anim=0.5
	var world=actor._battle_world()
	if world!=null:world.reveal_attack(actor,target)
	actor.special.ra3_barrel=int(actor.special.get("ra3_barrel",0))+1
	var point: Vector2=target.position
	if actor.unit_id==FUTURE:
		preload("res://scripts/units/ra3_future_state.gd").fired(actor)
		make_shot(actor,target,point,"neutron")
		Ra2Sfx.play("RA3_EXP_ALL_FutureTank_Weapon1FireMS",actor.position)
	else:
		preload("res://scripts/units/ra3_gunship_mounts.gd").fire_direct(actor,target)

static func raw_damage(amount: float, kind: String, target) -> float:
	if target is ForceFirePoint:return 0.0
	if target is Unit and target.data.has("soviet_ra3"):return amount*float(target.data.soviet_ra3.armor.get(kind,1.0))
	if handles(target):return amount*float(rules.objects[target.unit_id].armor.get(kind,1.0))
	if Ra3Mirage.handles(target):return amount # Mirage's native vehicle armor is 100% for these damage types.
	var id: String=target.building_id if target is Building else target.unit_id
	var profiles: Dictionary=rules.target_profiles
	var category: String="building" if target is Building else ("naval" if target.is_naval else ("infantry" if AlliedAbilities.infantry(target) else "vehicle"))
	var row: Dictionary=profiles.profiles[profiles.mapping.get(id,profiles.fallback[category])]
	return amount*float(row.multipliers.get(kind,1.0))*float(target.data.get("hp",row.hp))/float(row.hp)

static func hit(shot, target, amount: float, kind: String, reference_amount:float=-1.0) -> void:
	if not AlliedAbilities.alive(target) or target is ForceFirePoint:return
	if reference_amount<0:reference_amount=amount
	var source=shot._credit_source.get_ref() if shot._credit_source!=null else null
	var modifiers:Dictionary=shot.attacker_bonus
	if shot.splinters.has("phase_factor"):
		if is_same(target,shot.target):
			amount*=float(shot.splinters.phase_factor)
		else:
			modifiers=modifiers.duplicate()
			modifiers.erase("phase_layers")
	var damage:=CombatMath.with_offense(raw_damage(amount,kind,target),modifiers)
	if CombatMath.FinalDamage.active():modifiers=CombatMath.FinalDamage.packet(modifiers,raw_damage(reference_amount,kind,target)*float(modifiers.get("veteran_attack",1.0)))
	target.receive_hit(damage,"cannon",modifiers,source,"RA3_EXPANSION")

static func tick_shot(shot, delta: float) -> void:
	var state: Dictionary=shot.splinters
	var world=shot.get_parent().get_parent()
	if not world is Battle:shot.queue_free();return
	if state.ra3_expansion=="crash":
		preload("res://scripts/units/ra3_gunship_crash.gd").tick(shot,delta);return
	if state.ra3_expansion=="neutron" and state.get("neutron_stage","node")=="flight":
		var remainder:=preload("res://scripts/units/ra3_neutron_flight.gd").advance(shot,delta)
		shot.visible=world.position_visible_to("ally",shot.position)
		if remainder<0.0:
			if DisplayServer.get_name()!="headless" and not shot.has_node("NativeFlightFx"):
				var flight=preload("res://scripts/units/ra3_neutron_projectile.gd").new()
				flight.name="NativeFlightFx";shot.add_child(flight);flight.setup(shot)
			shot.queue_redraw();return
		if shot.has_node("NativeFlightFx"):shot.get_node("NativeFlightFx").free()
		delta=remainder # Impact owns a fresh node clock, including the rest of this step.
	if state.ra3_expansion=="riot":
		var source=shot._credit_source.get_ref() if shot._credit_source!=null else null
		if not AlliedAbilities.alive(source):
			# The native beam update belongs to its caster, unlike an independent
			# shell/node. Drain only endpoint events already fired before death.
			state.riot_stopped=true
			state.riot_stop_count=int(state.get("riot_next",0))
		state.riot_suspended=AlliedAbilities.alive(source) and (AlliedAbilities.frozen(source) or source._stun_timer>0.0)
		if state.riot_suspended:return
	var previous:=float(state.age)
	if state.ra3_expansion=="riot" and not state.has("riot_previous"):state.riot_previous=state.age
	state.age=float(state.age)+delta
	var mode:=str(state.ra3_expansion)
	# Projectiles belong to Battle.projectiles_root; their payload survives save/load.
	shot.visible=world.position_visible_to("ally",shot.target_point)
	if mode in ["shell","neutron"] and DisplayServer.get_name()!="headless" and not shot.has_node("NativeFx"):
		var visual=preload("res://scripts/units/ra3_future_particles.gd").new() if mode=="neutron" else preload("res://scripts/units/ra3_expansion_fx.gd").new()
		visual.name="NativeFx";shot.add_child(visual);visual.setup(shot)
	if mode=="shell":
		if preload("res://scripts/units/ra3_gunship_shell.gd").advance(shot,delta):
			preload("res://scripts/units/ra3_gunship_impact.gd").spawn(world,shot.target_point,bool(state.get("heroic",false)))
			for target in world.units+world.buildings:
				if not AlliedAbilities.alive(target) or (target is Unit and target.is_air_target()):continue
				var distance: float=target.position.distance_to(shot.target_point)
				if distance<=75.0:
					var scale:=1.0 if AlliedAbilities.infantry(target) else 0.5
					hit(shot,target,100.0*scale*(1.0-clampf((distance-45.0)/30.0,0.0,1.0)),"EXPLOSIVE")
			preload("res://scripts/units/ra3_meta_impact.gd").apply(world,shot.target_point,preload("res://scripts/units/ra3_gunship_shell.gd").rules.shell_warhead)
			shot.queue_free()
	elif mode=="gun":
		if float(state.age)>=0.03:
			if AlliedAbilities.alive(shot.target):
				# DamageFX SOVIET_MACHINEGUN: ordinary hit plus separate heroic tracer FX.
				# Capture the position before lethal damage can remove the target.
				var now:=Time.get_ticks_msec()
				if now-int(shot.target.get_meta("ra3_gun_hit_time",-1000))>=50:
					shot.target.set_meta("ra3_gun_hit_time",now)
					load("res://scripts/units/ra3_gunship_bullet_hit.gd").spawn(world,shot.target.position,shot.target.position-(state.start as Vector2))
				hit(shot,shot.target,12.0*(1.0 if shot.target is Building else 0.5),"AUTO_CANNON")
			shot.queue_free()
	elif mode=="neutron":
		preload("res://scripts/units/ra3_neutron.gd").tick(shot,world,previous)
	elif mode=="riot":
		if not state.has("muzzles"):
			var old: Vector2=state.get("muzzle",state.get("origin",shot.position))
			state.muzzles=[old,old]
		if not shot.has_meta("ra3_beam_started"):preload("res://scripts/units/ra3_future_beam.gd").spawn(shot)
		RIOT.tick_shot(shot,world)
	shot.queue_redraw()

static func draw_shot(shot) -> void:
	var mode:=str(shot.splinters.ra3_expansion)
	if mode=="riot":return # Battle-owned dual LaserState renderer and residual glows.
	if mode=="neutron" and shot.splinters.get("neutron_stage","node")=="flight":return
	if mode in ["shell","neutron"] and shot.has_node("NativeFx"):return
	if mode=="shell":
		Iso.begin(shot)
		shot.draw_texture_rect(shell_texture,Rect2(-7,-14,14,28),false,Color(0.65,0.7,1.0,0.9))
	elif mode=="gun":
		pass # Native TracerModelDraw is owned by the battle, beyond the instant hit.
	elif mode=="neutron":
		if float(shot.splinters.age)>=(20.0+19.0)/15.0:return
		var radius:=clampf(25.0+maxf(0.0,float(shot.splinters.age)-1.35)*125.0,25.0,180.0)*1.5
		var points:=PackedVector2Array()
		for i in 65:points.append(Vector2.from_angle(TAU*i/64.0)*radius)
		shot.draw_polyline(points,Color(0.35,0.85,1,0.35),2.0,true)
