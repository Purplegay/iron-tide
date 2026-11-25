extends RefCounted
## Official Uprising node XML + SHA-pinned retail DamageSphereUpdate CPU trace.
## See docs/RA3_UPHEAVAL_FULL_AUDIT.md; geometry remains a cross-engine adapter.
const HZ:=15.0 # Retail 0xccce90, initialized into the time conversion at 0xbc5580.
const UNPACK_FRAME:=20 # trunc(1.35 * 15), native constructor 0x7a82f4.
const MIN_RADIUS:=25.0
const MAX_RADIUS:=180.0
const STEP:=125.0/HZ
const SCALE:=1.5
const EXPANSION_TICKS:=19 # ceil((180-25)/(125/15)); query THEN increment/clamp/stop.
const PRE_INTERVAL:=3.0/HZ # FireInterval .25s -> trunc(.25 * 15) native frames.

static func radius_at(tick: int) -> float:
	return (MIN_RADIUS+clampi(tick,0,EXPANSION_TICKS-1)*STEP)*SCALE

static func intersects(target, point: Vector2, radius: float) -> bool:
	# Native partition query mode 3 uses XYZ distance and the target bounding sphere.
	# IronTide uses its own actor radius/footprint; it does not have SAGE geometry.
	if target is Building:return Ra3Expansion.RIOT.point_distance(target,point)<=radius
	var height:=0.0
	if target.is_air_target() and target.flight!=null:
		height=target.flight.height*target.flight.HEIGHT_PIXEL*target.logistics.air_lift
	return target.position.distance_squared_to(point)+height*height<=pow(radius+target.radius,2)

static func pulse(shot, world, radius: float) -> void:
	for target in world.units+world.buildings:
		if not AlliedAbilities.alive(target) or target.side==shot.owner_side:continue
		if target is Unit and target.embarked_in!=null:continue
		if intersects(target,shot.target_point,radius):
			Ra3Expansion.hit(shot,target,10.0*(1.0 if AlliedAbilities.infantry(target) else 0.25),"NEUTRON")

static func tick(shot, world, previous: float) -> void:
	var state: Dictionary=shot.splinters
	shot.position=shot.target_point
	if not bool(state.get("neutron_direct",true)):
		state.neutron_direct=true
		Ra3Expansion.hit(shot,shot.target,0.1,"NEUTRON")
	# Cursors live in the existing serializable payload. Legacy saves resume at
	# their current age; never replay historic damage after loading.
	var pre:=int(state.get("neutron_pre",floori(previous/PRE_INTERVAL+0.000001)+1))
	while pre*PRE_INTERVAL<UNPACK_FRAME/HZ and pre*PRE_INTERVAL<=float(state.age)+0.000001:
		pulse(shot,world,0.0) # IncrementalWeapon has no Radius; FireWeaponUpdate is point damage.
		pre+=1
	state.neutron_pre=pre
	var next:=int(state.get("neutron_tick",maxi(0,floori(previous*HZ-UNPACK_FRAME+0.000001)+1)))
	while next<EXPANSION_TICKS and (UNPACK_FRAME+next)/HZ<=float(state.age)+0.000001:
		pulse(shot,world,radius_at(next))
		next+=1
	state.neutron_tick=next
	# LifetimeUpdate owns cleanup only. DamageSphereUpdate returns sleep-forever
	# at maximum radius; it does not keep pulsing for the rest of these six seconds.
	if float(state.age)>=6.0:shot.queue_free()
