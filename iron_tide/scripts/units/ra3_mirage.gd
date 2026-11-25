class_name Ra3Mirage
extends RefCounted
## RA3 SDK rules adapted to IronTide's continuous 2D battlefield.
static var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_mirage_balance.json"))
static var model_conditions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ra3/mirage/damage/conditions.json"))
const ID := "R3MIRAGE"
const SOURCE_GROUP := &"ra3_mirage_field_sources"
const SKILL := "allied_ra3_field"
const WORLD_SCALE := 1.5 # Matches the model's 96-pixel frame / 64-unit camera.
const FIELD_RADIUS := 175.0 * WORLD_SCALE
const CloakVisual = preload("res://scripts/units/ra3_cloak_visual.gd")

static func handles(unit) -> bool:
	return unit is Unit and unit.unit_id == ID

static func aim_tolerance(unit) -> float:
	var weapon_id:="AlliedAntiVehicleVehicleTech3PrismCannon"+ ("_Veteran" if unit.veteran_level>=3 else "")
	for weapon:Dictionary in balance.raw.weapons:
		if weapon.id==weapon_id:return deg_to_rad(float(str(weapon.AcceptableAimDelta).trim_suffix("d")))
	return 0.0 # Missing source never grants unrestricted fire.

static func damage_state(unit) -> int:
	if unit.hp <= 0: return 0
	var fraction: float = unit.hp / maxf(1.0, unit.max_hp)
	if fraction <= float(model_conditions.thresholds.MaxHealthReallyDamagedPercentage): return 2
	if fraction <= float(model_conditions.thresholds.MaxHealthDamagedPercentage): return 1
	return 0

static func damaged_speed_factor(unit) -> float:
	return float(model_conditions.damaged_speed_factor) if damage_state(unit) > 0 else 1.0

static func field_active(unit) -> bool:
	return handles(unit) and AlliedAbilities.alive(unit) and unit.embarked_in == null \
		and unit.special.get("ra3_field", false) and not AlliedAbilities.frozen(unit) and unit._stun_timer <= 0.0

static func disguised(unit) -> bool:
	return handles(unit) and AlliedAbilities.alive(unit) and not unit.special.get("ra3_field", false) \
		and unit.velocity.length() < 1.0 and not unit.has_move_order and float(unit.special.get("reveal", 0)) <= 0.0

static func info(unit) -> Dictionary:
	var left := float(unit.special.get("ra3_field_cd", 0.0))
	var active := bool(unit.special.get("ra3_field", false))
	return {"id": SKILL, "name": "关闭幻影场" if active else "开启幻影场", "toggle": true, "active": active,
		"desc": "Q 切换幻影场：停止开炮，隐藏范围内友方地面步兵和载具；不隐藏自身或其他开场坦克。友军开火、受伤或被反隐侦测时暴露。关闭后恢复棱镜炮。切换冷却 2 秒。",
		"ready": AlliedAbilities.alive(unit) and unit.embarked_in == null and not unit.repairing and unit._stun_timer <= 0.0 and not AlliedAbilities.frozen(unit) and left <= 0.0,
		"cd_left": left, "cooldown": 2.0, "cd_frac": left / 2.0, "glyph": "guard", "icon": "res://assets/ra3/mirage/presentation/" + ("field_off.png" if active else "field_on.png")}

static func toggle(unit) -> bool:
	if not handles(unit) or not info(unit).ready: return false
	unit.special.ra3_field = not bool(unit.special.get("ra3_field", false))
	unit.special.ra3_field_cd = 2.0
	Ra3MirageAudio.ensure(unit).toggled()
	unit.special.reveal = 2.0
	unit._cancel_burst()
	unit._refresh_weapon_derived()
	unit.queue_redraw()
	return true

static func tick(unit, delta: float) -> void:
	CloakVisual.tick(unit, delta)
	if not handles(unit): return
	preload("res://scripts/units/ra3_mirage_extras.gd").disguise_id(unit)
	unit.special.ra3_under_fire = maxf(0.0, float(unit.special.get("ra3_under_fire", 0.0)) - delta)
	unit.special.ra3_field_cd = maxf(0.0, float(unit.special.get("ra3_field_cd", 0.0)) - delta)
	tick_heroic_heal(unit,delta)
	Ra3MirageAudio.ensure(unit).advance(delta)
	if unit.selected or field_active(unit): unit.queue_redraw()

static func tick_heroic_heal(unit, delta: float) -> void:
	if unit.veteran_level<3 or not AlliedAbilities.alive(unit) or AlliedAbilities.frozen(unit): return
	# BaseVehicle permits heroic healing both in combat and under attack.
	var remaining: float = float(unit.special.get("ra3_heal_remaining",balance.heal.start_delay))-delta
	while remaining<=0.000001:
		unit.heal(float(balance.heal.amount))
		remaining+=float(balance.heal.delay)
	unit.special.ra3_heal_remaining=remaining

static func field_conceals(unit, observer: String) -> bool:
	if not is_instance_valid(unit) or not unit is Unit or not unit.is_inside_tree(): return false
	var tree: SceneTree = unit.get_tree()
	if not tree.has_group(SOURCE_GROUP): return false
	if not AlliedAbilities.alive(unit) or unit.side == observer or unit.embarked_in != null \
		or unit.is_air_target() or float(unit.special.get("reveal", 0.0)) > 0.0 or field_active(unit): return false
	var world = unit._battle_world()
	if world == null: return false
	var covered := false
	for source in tree.get_nodes_in_group(SOURCE_GROUP):
		if source != unit and world.is_ancestor_of(source) and source.side == unit.side and field_active(source) \
			and source.global_position.distance_squared_to(unit.global_position) <= pow(FIELD_RADIUS * Unit.Training.scale(source), 2):
			covered = true
			break
	if not covered: return false
	for detector in tree.get_nodes_in_group("disguise_detectors"):
		if detector.side == observer and detector.embarked_in == null and AlliedAbilities.alive(detector) and world.is_ancestor_of(detector) \
			and detector.global_position.distance_squared_to(unit.global_position) <= detector.sight * detector.sight:
			return false
	return true

static func shoot(unit, target, weapon: Dictionary, damage: float, bonuses: Dictionary) -> void:
	Ra3WeaponFx.spawn(unit, target, unit._weapon_muzzle())
	Ra3MirageAudio.ensure(unit).fire()
	var primary_bonus:=bonuses.duplicate()
	var factor:float=unit.FactionCards.primary_shot(unit,target,primary_bonus)
	schedule_hit(unit, target, weapon, damage*factor, primary_bonus)
	preload("res://scripts/units/ra3_scatter.gd").fire(unit, target, weapon, bonuses)

static func draw_field(unit) -> void:
	if not handles(unit) or not field_active(unit) or not unit.selected: return
	var points := PackedVector2Array()
	for i in 65: points.append(Iso.dir(Vector2.RIGHT.rotated(TAU * i / 64.0) * FIELD_RADIUS * Unit.Training.scale(unit)))
	unit.draw_polyline(points, Color(0.35, 0.8, 1.0, 0.45 if unit.selected else 0.16), 1.5, true)

static func voice_kind(unit, kind: String) -> String:
	if kind == "select":
		if float(unit.special.get("ra3_under_fire", 0.0)) > 0: return "select_under_fire"
		if field_active(unit): return "select_mirage"
		if is_instance_valid(unit.attack_target): return "select_battle"
	if kind == "move":
		if field_active(unit): return "move_special"
		if unit.attack_move: return "move_attack"
	return kind

static func rank_status(unit) -> Dictionary:
	var maxed: bool = unit.veteran_level >= 3
	var required: float = rank_requirement(unit.veteran_level)
	return {"enabled": true, "rank": unit.veteran_level, "level": unit.veteran_level+1,
		"name": ["新兵","老兵","精英","英雄"][clampi(unit.veteran_level,0,3)], "maxed": maxed,
		"current": 0.0 if maxed else unit._vet_kills, "required": required,
		"progress": 1.0 if maxed else clampf(unit._vet_kills/maxf(1.0,required),0.0,1.0)}

static func rank_requirement(rank: int) -> float:
	if rank >= 3: return 0.0
	return float(balance.promotions[rank].experience)-(float(balance.promotions[rank-1].experience) if rank>0 else 0.0)

static func credit_kill(unit, value: float, defeated_side: String) -> void:
	if not AlliedAbilities.alive(unit) or defeated_side==unit.side or unit.veteran_level>=3: return
	unit._vet_kills+=maxf(0.0,value)
	while unit.veteran_level<3 and unit._vet_kills>=rank_requirement(unit.veteran_level):
		unit._vet_kills-=rank_requirement(unit.veteran_level)
		unit._grant_veteran(unit.veteran_level+1,true)
	unit._vet_need=rank_requirement(unit.veteran_level)

static func apply_veterancy(unit, announce: bool) -> void:
	var fraction: float = unit.hp/maxf(1.0,unit.max_hp)
	unit._clear_veteran_bonuses()
	unit._vet_self_heal=0.0
	if unit.veteran_level<3: unit.special.erase("ra3_heal_remaining")
	elif not unit.special.has("ra3_heal_remaining"): unit.special.ra3_heal_remaining=float(balance.heal.start_delay)
	var modifiers := {}
	for i in mini(unit.veteran_level,3): modifiers.merge(balance.promotions[i].modifiers,true)
	unit.bonuses.veteran_attack=float(modifiers.get("DAMAGE_MULT",1.0))
	unit.max_hp=unit._base_max_hp*float(modifiers.get("HEALTH_MULT",1.0))
	unit.hp=clampf(unit.max_hp*fraction,0.0,unit.max_hp)
	unit.sight=float(unit.data.sight)*float(modifiers.get("SHROUD_CLEARING",1.0))
	var weapon: Dictionary=unit.data.elite_weapon.duplicate(true) if unit.veteran_level>=3 else unit.data.weapon.duplicate(true)
	# Adapter applies native RATE_OF_FIRE to the firing phase; fixed reload stays explicit.
	# SDK XML does not include the SAGE scheduler implementation.
	weapon.firing_seconds=float(weapon.firing_seconds)/float(modifiers.get("RATE_OF_FIRE",1.0))
	weapon.cooldown=float(weapon.firing_seconds)+float(weapon.reload_seconds)
	weapon.range=float(weapon.range)*float(modifiers.get("RANGE",1.0))
	unit._ra2_weapon_override=weapon
	unit._vet_need=rank_requirement(unit.veteran_level)
	unit._refresh_weapon_derived()
	unit.queue_redraw()
	if announce: preload("res://scripts/ui/veterancy_indicator.gd").promote(unit)

static func schedule_hit(unit, target, weapon: Dictionary, damage: float, bonuses: Dictionary) -> void:
	# Use the existing serialized projectile queue, not an unsaved SceneTreeTimer.
	var shot := Projectile.new()
	shot.damage=damage; shot.attacker_bonus=bonuses.duplicate(true)
	if not shot.attacker_bonus.has("hit_reference_damage"):
		shot.attacker_bonus=CombatMath.FinalDamage.packet(shot.attacker_bonus,CombatMath.FinalDamage.weapon_reference(weapon,target,bonuses))
	shot.attack_type="tesla"; shot.ra2_warhead=str(weapon.get("ra2_warhead",""))
	shot.target=target; shot.target_point=target.global_position
	shot.owner_side=unit.side; shot._credit_source=weakref(unit)
	shot.splinters={"ra3_hit_delay":float(weapon.get("damage_delay",0.1))}
	shot.base_damage = float(weapon.get("damage", damage))
	if ForceFire.active(unit, target): shot.splinters["force_fire"] = true
	shot.visible=false
	unit._battle_world().projectiles_root.add_child(shot)

static func tick_impact(shot, delta: float) -> void:
	shot.splinters.ra3_hit_delay=float(shot.splinters.ra3_hit_delay)-delta
	if float(shot.splinters.ra3_hit_delay)>0.000001: return
	if is_instance_valid(shot.target) and shot.target is ForceFirePoint:
		shot._explode()
		return
	if not shot._detonated and AlliedAbilities.alive(shot.target):
		shot._detonated=true
		var source=shot._credit_source.get_ref() if shot._credit_source!=null else null
		shot.target.receive_hit(shot.damage,shot.attack_type,shot.attacker_bonus,source,shot.ra2_warhead)
	shot.queue_free()

static func restore_native_rules(unit) -> void:
	# Old snapshots serialize their unit definitions AND derived Yuri bonuses.
	# Migrate this unit only; new native snapshots retain exact in-flight state.
	if not handles(unit): return
	var old_native: bool = unit.data.get("veteran",{}).get("native_ra3",false)
	if old_native and int(unit.data.veteran.get("adapter_revision",0)) >= 2: return
	var current: Dictionary = GameData.get_unit(ID)
	var old_cycle: float = maxf(0.05,unit.cooldown*float(unit.bonuses.get("veteran_rof",1.0)))
	var remaining_cycle: float = maxf(0.0,unit._cd_timer)/old_cycle
	var progress: float = clampf(unit._vet_kills/maxf(1.0,unit._vet_need),0.0,1.0)
	var speed_multiplier: float = unit._base_speed/maxf(1.0,unit.base_speed)
	var health_multiplier: float = unit._base_max_hp/maxf(1.0,unit.base_hp)
	for key in ["cost","build_time","production_seconds_native","hp","speed","sight","move","weapon","elite_weapon","veteran"]:
		unit.data[key]=current[key].duplicate(true) if current[key] is Dictionary else current[key]
	unit.base_speed=float(current.speed); unit._base_speed=unit.base_speed*speed_multiplier
	unit.base_hp=float(current.hp); unit._base_max_hp=unit.base_hp*health_multiplier
	unit.weapon=unit.data.weapon; unit._vet_cfg=unit.data.veteran; unit._vet_elite_weapon=unit.data.elite_weapon
	unit._mv_cache.clear()
	# Preserve an already earned top rank rather than demoting a legacy elite.
	if not old_native and unit.veteran_level>=2: unit.veteran_level=3
	apply_veterancy(unit,false)
	unit._vet_kills=progress*rank_requirement(unit.veteran_level)
	unit._cd_timer=remaining_cycle*unit.cooldown
	unit._recompute_bonuses()

## Canvas draw commands retain a texture RID, not a strong Resource reference.
## Keep the three native badges alive even when no selection HUD owns them.
static func rank_texture(rank: int) -> Texture2D:
	return HpBar.rank_texture(rank, {"id": ID, "faction": "allied"})
