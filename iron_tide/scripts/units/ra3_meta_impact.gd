extends RefCounted
## Source impulse/radius/taper; bounded horizontal Godot collision adapter.
static var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_completion_rules.json"))

static func apply(world, origin: Vector2, weapon: Dictionary) -> void:
	var native: Dictionary={}
	for child: Dictionary in weapon.children:
		if child.type=="Nuggets":
			for n: Dictionary in child.children:
				if n.type=="MetaImpactNugget":native=n.attrs
	if native.is_empty():return
	var radius:=float(native.ShockWaveRadius)*1.5
	var inner:=float(native.get("ShockWaveTaperOff",0.0))*1.5
	for unit in world.units:
		if not AlliedAbilities.alive(unit) or unit.is_air_target() or unit.embarked_in!=null or unit.repairing or unit._stun_timer>0.0 or AlliedAbilities.frozen(unit):continue
		if unit.special.has("ra3_impulse"):continue # Native excludes already-flailing actors.
		var offset: Vector2=unit.position-origin
		if offset.length()>=radius:continue
		var taper:=1.0-clampf((offset.length()-inner)/maxf(0.001,radius-inner),0,1)
		var direction:=offset.normalized() if offset.length_squared()>0.01 else Vector2.RIGHT
		# Game weights are not SAGE masses. Keep the conversion explicit and bounded.
		var weight:=maxf(1.0,float(unit._mv("weight",1.0)))
		unit.special.ra3_impulse=direction*float(native.ShockWaveAmount)*1.5*taper/weight
		unit.special.ra3_impulse_left=float(rules.adapter.impulse_decay_seconds)*4.0

static func tick(unit, delta: float) -> void:
	if not unit.special.has("ra3_impulse"):return
	var velocity: Vector2=unit.special.ra3_impulse
	var decay:=float(rules.adapter.impulse_decay_seconds)
	var step:=velocity*decay*(1.0-exp(-delta/decay))
	var next: Vector2=unit.position+step
	if unit._domain_ok(next):unit.move_with_traffic_exceptions(step)
	unit.special.ra3_impulse=velocity*exp(-delta/decay)
	unit.special.ra3_impulse_left=float(unit.special.ra3_impulse_left)-delta
	if float(unit.special.ra3_impulse_left)<=0.0 or velocity.length()<0.1:
		unit.special.erase("ra3_impulse");unit.special.erase("ra3_impulse_left")
