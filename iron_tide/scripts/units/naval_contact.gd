class_name NavalContact
extends RefCounted

# Sensors=yes / SensorsSight in the installed YR rulesmd.ini (expandmd01.mix).
# Distances use the same world-cell scale as weapon reach.
const SENSOR_CELLS := {"DEST": 8, "DLPH": 8, "SUB": 7, "SQD": 8, "BSUB": 8, "CDEST": 8}

static func underwater_type(actor) -> bool:
	return is_instance_valid(actor) and actor is Unit and actor.unit_id in ["DLPH", "SUB", "SQD", "BSUB"]

static func grip_host(squid):
	if not (is_instance_valid(squid) and squid is Unit and squid.unit_id=="SQD"):return null
	var host=squid.embarked_in
	return host if AlliedAbilities.alive(host) and is_same(host.special.get("squid"),squid) else null

static func visible_grip(world,observer:String,squid) -> bool:
	var host=grip_host(squid)
	return host!=null and world.actor_visible_to(observer,host)

static func submerged(actor) -> bool:
	return underwater_type(actor) and not actor.special.has("dive_remaining")

const RISE_SECONDS := 0.5
const DIVE_DEPTH_PIXELS := 7.0
const DOLPHIN_BREACH_SECONDS := 0.85

static func surface(sub) -> void:
	if sub.unit_id in ["SUB","DLPH"]:
		var depth:=dive_fraction(sub)
		if sub.unit_id=="DLPH" and depth>0.0 and not sub.special.has("rise_depth"):
			sub.special.dolphin_breach_start=sub._anim
		sub.special.rise_depth=depth
	sub.special.dive_remaining = dive_delay()
	sub.queue_redraw()

static func dive_delay() -> float:
	return float(preload("res://scripts/core/yr_death_rules.gd").data().general.cloakdelay) * 60.0

static func tick(sub, delta: float) -> void:
	if sub.special.has("dolphin_breach_start"):
		if sub._anim-sub.special.dolphin_breach_start>=DOLPHIN_BREACH_SECONDS:
			sub.special.erase("dolphin_breach_start")
		sub.queue_redraw()
	if grip_host(sub) != null or AlliedAbilities.alive(sub.special.get("squid")): return
	if not sub.special.has("dive_remaining"): return
	if sub.special.has("rise_depth"):
		var depth := maxf(0.0, float(sub.special.rise_depth) - delta / RISE_SECONDS)
		if depth > 0.0: sub.special.rise_depth = depth
		else: sub.special.erase("rise_depth")
		sub.queue_redraw()
	var remaining := float(sub.special.dive_remaining)
	if sub._stun_timer <= 0.0 and not sub._moving() and sub._weapon_target_valid(sub.attack_target):
		sub.special.dive_remaining = dive_delay()
		return
	remaining -= delta
	if remaining > 0.000001: sub.special.dive_remaining = remaining
	else: sub.special.erase("dive_remaining")
	sub.queue_redraw()

## Fade through the water during the final part of the dive delay.
static func dive_fraction(actor) -> float:
	if actor.unit_id not in ["SUB", "SQD", "DLPH"]: return 0.0
	return maxf(float(actor.special.get("rise_depth", 0.0)), 1.0 - smoothstep(0.0, 0.5, float(actor.special.get("dive_remaining", 0.0))))

# WAKE1 is the YR General/Wake animation. Tie the breach to actual rise progress
# and keep the water plane fixed as the dolphin moves through it.
static func draw_dolphin_wake(unit,center:Vector2,depth:float,front:bool) -> void:
	if depth>=1.0 or unit._dead:return
	var wake:=RA2Art.fx("WAKE1")
	if wake.is_empty():return
	var age:float=unit._anim-float(unit.special.get("dolphin_breach_start",-10.0))
	var breach:=age>=0.0 and age<DOLPHIN_BREACH_SECONDS
	var phase:=age/DOLPHIN_BREACH_SECONDS if breach else fposmod(unit._anim*float(wake.fps),float(wake.count))/float(wake.count)
	var frame:=RA2Art.fx_rect(wake,mini(int(phase*wake.count),wake.count-1))
	var size:Vector2=wake.cell*(1.0 if breach else 0.78)
	var dest:=Rect2(center-size*0.5,size)
	if front:
		dest.position.y+=size.y*0.5
		frame.position.y+=frame.size.y*0.5
	dest.size.y*=0.5
	frame.size.y*=0.5
	unit.draw_texture_rect_region(wake.tex,dest,frame,Color(0.8,0.95,1.0,(1.0-depth)*(0.78 if breach else 0.42)))

static func torpedo_aligned(sub, target) -> bool:
	var bearing: Vector2 = target.global_position - sub.global_position
	if bearing.is_zero_approx() or absf(angle_difference(sub.hull_angle, bearing.angle())) >= PI / 4.0: return false
	# At close range the bow must turn farther: a target inside the torpedo's
	# turning circle cannot be intercepted on its first pass.
	var gun: Dictionary = sub._weapon_for_target(target)
	var projectile := GameData.ra2_projectile(gun.ra2_projectile)
	var turn_rate := deg_to_rad(float(projectile.rot) * Projectile.ROT_DEG_PER_TICK * Projectile.ROF_FPS)
	var turn_radius := float(gun.projectile_speed) / turn_rate
	var offset: Vector2 = target.global_position - sub._weapon_muzzle()
	var lateral := absf(Vector2.from_angle(sub.hull_angle).cross(offset))
	return offset.length_squared() >= 2.0 * turn_radius * lateral or offset.length() <= target.radius

static func sensor_range(unit) -> float:
	if Unit.TankHero.rank(unit)>=0:return unit.attack_range
	return float(SENSOR_CELLS.get(unit.unit_id, 0)) * 55.0

static func sensor_group(side: String) -> StringName:
	return &"allied_sonar_sensors" if side == "ally" else &"enemy_sonar_sensors"

static func detected(world, observer: String, target) -> bool:
	var point:Vector2=target.global_position
	var sensors := sensor_group(observer)
	var tree: SceneTree = world.get_tree()
	if tree.has_group(&"psychic_sensors") and preload("res://scripts/world/yuri_support.gd").reveals(world,observer,point): return true
	if not tree.has_group(sensors): return false
	for scout in tree.get_nodes_in_group(sensors):
		if scout.side != observer or not world.is_ancestor_of(scout): continue
		if scout.embarked_in!=null or not world.actor_alive(scout):
			continue
		var radius := sensor_range(scout)
		if scout.global_position.distance_squared_to(point)<=radius*radius:
			return true
	return false

static func weapon_allows(unit: Unit, target, known_underwater_type = null) -> bool:
	# Hero sonar changes only submerged-type eligibility. Ordinary ground/air
	# targets need neither a hero-rank lookup nor a second type test.
	var underwater: bool = underwater_type(target) if known_underwater_type == null else known_underwater_type
	if not underwater: return unit.unit_id != "ASW"
	if Unit.TankHero.rank(unit)>=0:return unit.position.distance_squared_to(target.position)<=unit.attack_range*unit.attack_range
	return GameData.unit_naval_targeting(unit.unit_id) in [1, 2, 3, 4, 5, 7]
