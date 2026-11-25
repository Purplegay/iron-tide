extends RefCounted
## Independent continuous-map adapter for the YR DMisl rules. Positions and lift use world pixels.
const Native = preload("res://scripts/world/special_rules.gd")
const TICKS := 15.0
const SMOKE_FRAME := 3 # V3TRAIL has three bright frames followed by cooling smoke.
const LEPTON := Ra2Damage.PX_PER_CELL / 256.0
# artmd.ini [DRED] PrimaryFireFLH, with alternate port/starboard rails.
const RAIL := Vector3(30, 43, 92)

static func mount(ship, rail: float) -> Vector2:
	var forward := Vector2.from_angle(ship.hull_angle)
	if ship.unit_id == "V3": return ship.position - forward * 160.0 * LEPTON # V3.PrimaryFireFLH=-160,0,75
	return ship.position + (forward * RAIL.x + forward.orthogonal() * rail * RAIL.y) * LEPTON

# Pick a reachable firing position on water, even when the ordered target is on land.
static func firing_position(ship, target) -> Vector2:
	var world = ship._battle_world()
	if world == null or world.path_service == null: return Vector2.INF
	var reach := OpenTopped.command_range(ship, target)
	var original: float = ship.position.distance_to(target.position)
	var nearest := Vector2.INF
	var best := INF
	var axis: float = target.position.direction_to(ship.position).angle()
	var pad := PathService.CELL
	for radius in [clampf(original,ship.min_range + pad,reach - pad), (reach + ship.min_range) * 0.5]:
		for i in 32:
			var point: Vector2 = target.position + Vector2.from_angle(axis + i * TAU / 32.0) * float(radius)
			if point.x < 0 or point.y < 0 or point.x >= world.map_size or point.y >= world.map_size or not world.on_water(point): continue
			var d: float = ship.position.distance_squared_to(point)
			if d < best and world.path_service.same_zone(ship.position,point,true):
				best = d
				nearest = point
	return nearest

static func prepare(missile, ship, rail: float) -> void:
	var state: Dictionary = missile.special.flight
	state.rail = rail
	state.phase = "rack"
	var v3: bool = missile.unit_id == "V3ROCKET"
	state.pitch = deg_to_rad(90.0 * Native.general("V3RocketPitchInitial" if v3 else "DMislPitchInitial",0))
	state.speed = 0.0
	missile.hull_angle = ship.hull_angle
	if v3:state.rail_heading=ship.hull_angle
	missile.logistics.air_lift = (75.0 if v3 else RAIL.z) * LEPTON

static func advance(missile, state: Dictionary, delta: float) -> bool:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(61)
	var v3: bool = missile.unit_id == "V3ROCKET"
	var prefix := "V3Rocket" if v3 else "DMisl"
	var row: Dictionary = GameData.ra2_source_units[missile.unit_id]
	var pause := Native.general(prefix+"PauseFrames",20)
	var tilt := Native.general(prefix+"TiltFrames",60)
	var launch_pitch := deg_to_rad(90.0 * Native.general(prefix+"PitchFinal",0.5))
	var acceleration := Native.general(prefix+"Acceleration",0.8) * LEPTON
	# Missile locomotor Speed is a percentage of a cell per tick. Acceleration
	# and BodyLength are already in leptons (ObjectRules / MissileLocomotor).
	var top_speed := minf(100.0, float(row.speed)) * Ra2Damage.PX_PER_CELL / 100.0
	var yaw_rate := deg_to_rad(float(row.extra.ROT))
	var pitch_rate := Native.general(prefix+"TurnRate",0.08)
	var nose := Native.general(prefix+"BodyLength",128) * LEPTON * 0.5
	var previous_tick := floori(state.elapsed * TICKS / 2.0)
	var ticks := delta * TICKS
	while ticks > 0.00001:
		preload("res://scripts/world/battle_call_counters.gd").iterations(61, 1)
		var step := minf(1.0, ticks)
		ticks -= step
		state.elapsed += step / TICKS
		if state.phase == "rack":
			if not AlliedAbilities.alive(state.source):
				AlliedAbilities.consume(missile)
				return false
			var raised := clampf(state.elapsed * TICKS - pause, 0.0, tilt)
			missile.position = mount(state.source,state.rail)
			missile.hull_angle = state.source.hull_angle
			state.pitch = lerpf(deg_to_rad(90.0 * Native.general(prefix+"PitchInitial",0)), launch_pitch, raised / tilt)
			missile.logistics.air_lift = ((75.0 if v3 else RAIL.z) + raised * Native.general(prefix+"RaiseRate",1)) * LEPTON
			if raised >= tilt:
				state.phase = "boost"
				Ra2Sfx.play("V3Attack" if v3 else "DreadnoughtAttack", missile.position)
				if v3:
					state.rail_heading=missile.hull_angle
					state.release_lift=missile.logistics.air_lift
					missile.hull_angle = missile.position.direction_to(state.aim).angle()
			continue
		var to_aim: Vector2 = state.aim - missile.position
		var height: float = missile.logistics.air_lift
		state.speed = minf(top_speed, state.speed + acceleration * step)
		if state.phase == "boost" and height >= float(state.altitude):
			if v3:
				state.phase = "curve"
				state.curve_start = missile.position
				state.curve_height = height
				state.curve_pitch = state.pitch
				state.curve_t = 0.0
			else: state.phase = "cruise"
		if state.phase == "curve":
			if advance_curve(missile, state, state.speed * step, nose): return true
			continue
		if state.phase == "cruise" and to_aim.length() <= height: state.phase = "dive"
		if state.phase != "boost":
			missile.hull_angle = rotate_toward(missile.hull_angle, to_aim.angle(), yaw_rate * step)
			var desired := -atan2(height,to_aim.length()) if state.phase == "dive" else 0.0
			state.pitch = move_toward(state.pitch, desired, pitch_rate * step)
		var travel: float = state.speed * step
		if state.phase == "dive" and Vector2(to_aim.length(),height).length() <= nose + travel:
			missile.position = state.aim
			missile.logistics.air_lift = 0.0
			return true
		missile.position += Vector2.from_angle(missile.hull_angle) * cos(state.pitch) * travel
		missile.logistics.air_lift = maxf(0.1, height + sin(state.pitch) * travel)
	if state.phase != "rack" and floori(state.elapsed * TICKS / 2.0) > previous_tick:
		var world = missile._battle_world()
		if world != null and world.position_visible_to("ally",missile.position):
			if state.get("weapon_look")=="reentry":
				var exhaust:=exhaust_offset(missile)
				Effects.Looks.Signature.spawn(world.effects_root,missile.position,"meteor_smoke",0.0,exhaust)
				return false
			var smoke = Ra2Fx.play(world.effects_root, missile.position, "V3TRAIL")
			if smoke != null:
				smoke.z_index = DepthLayers.AIR - 1
				smoke.draw_offset = exhaust_offset(missile)
				smoke.start_at_frame(SMOKE_FRAME)
	return false

# V3RocketLazyCurve uses a smooth terminal arc, tangent to the boost leg.
# Work in the vertical plane through the aim; persist only scalar/vector state.
static func advance_curve(missile, state: Dictionary, travel: float, nose: float) -> bool:
	var start: Vector2 = state.curve_start
	var range_px := start.distance_to(state.aim)
	var a := Vector2(0, state.curve_height)
	var b := a + Vector2(range_px / 3.0, range_px / 3.0 * tan(state.curve_pitch))
	var c := Vector2(range_px * 0.85, b.y)
	var end := Vector2(range_px, 0)
	var t: float = state.curve_t
	t = minf(1.0, t + travel / maxf(1.0, a.bezier_derivative(b,c,end,t).length()))
	state.curve_t = t
	var p := a.bezier_interpolate(b,c,end,t)
	var tangent := a.bezier_derivative(b,c,end,t)
	state.pitch = tangent.angle()
	missile.position = start + start.direction_to(state.aim) * p.x
	missile.logistics.air_lift = p.y
	if end.distance_to(p) > nose: return false
	missile.position = state.aim
	missile.logistics.air_lift = 0
	return true

static func pose(missile, lift: float) -> Transform2D:
	var pitch: float = missile.special.get("flight",{}).get("pitch",0.0)
	var flat := Iso.dir(Vector2.from_angle(missile.hull_angle))
	var angle := flat.angle_to(flat * cos(pitch) + Vector2.UP * sin(pitch))
	var pivot := Vector2(0,-lift)
	var transform:=Transform2D(angle,pivot - pivot.rotated(angle))
	if missile.unit_id!="V3ROCKET":return transform
	var state:Dictionary=missile.special.get("flight",{})
	if state.get("phase","") not in ["rack","boost"]:return transform
	# Attach the visible nozzle to its position on the loaded V3 voxel. The
	# missile and the vehicle use different canvas sizes and bottom anchors.
	var source=state.get("source")
	var on_rail:bool=state.phase=="rack"
	var heading:float=source.hull_angle if on_rail and AlliedAbilities.alive(source) else state.get("rail_heading",missile.hull_angle)
	var radius:float=source.radius if AlliedAbilities.alive(source) else GameData.get_unit("V3").radius
	var socket:=tail_pixel(missile,RA2Art.art("V3"),radius,heading)
	var rail_ground:=Iso.dir(-Vector2.from_angle(heading)*160.0*LEPTON)
	var nozzle:=tail_pixel(missile,missile._ra2,missile.radius,missile.hull_angle)+pivot
	var bind_lift:float=lift if on_rail else state.get("release_lift",(75.0+Native.general("V3RocketTiltFrames",60)*Native.general("V3RocketRaiseRate",1))*LEPTON)
	var rise:=maxf(0,lift-bind_lift)
	var correction:=1.0-smoothstep(0.0,Native.general("V3RocketBodyLength",256)*LEPTON,rise)
	transform.origin+=(socket-rail_ground+Vector2.UP*rise-transform*nozzle)*correction
	return transform

# Draw the flame with the missile on every redraw, including between smoke puffs.
static func draw_exhaust(missile) -> void:
	var state:Dictionary = missile.special.get("flight", {})
	if state.get("phase","rack") == "rack": return
	if state.get("weapon_look")=="reentry" and state.phase in ["curve","dive"]:
		var heat:=smoothstep(0.0,0.42,-float(state.pitch))
		if heat>0:
			var tail:=exhaust_offset(missile)
			var lift:float=missile.logistics.air_lift
			var nose:=pose(missile,lift)*(end_pixel(missile,missile._ra2,missile.radius,missile.hull_angle,true)+Vector2.UP*lift)
			Effects.Looks.Signature.missile_heat(missile,nose,tail.direction_to(nose),heat,state.elapsed)
	var trail := RA2Art.fx("V3TRAIL")
	if trail.is_empty(): return
	var frame := floori(float(state.elapsed) * float(trail.fps)) % SMOKE_FRAME
	var size:Vector2 = trail.cell
	missile.draw_texture_rect_region(trail.tex, Rect2(exhaust_offset(missile) - size * 0.5, size), RA2Art.fx_rect(trail,frame))

static func exhaust_offset(missile) -> Vector2:
	var lift:float=missile.logistics.air_lift
	return pose(missile,lift)*(tail_pixel(missile,missile._ra2,missile.radius,missile.hull_angle)+Vector2.UP*lift)

# On the loaded truck only the remapped missile fins identify the rail. On
# a free missile the dark nozzle extends beyond those fins: use its silhouette.
static func tail_pixel(missile,art:Dictionary,radius:float,heading:float) -> Vector2:
	return end_pixel(missile,art,radius,heading)

static func end_pixel(missile,art:Dictionary,radius:float,heading:float,nose:=false) -> Vector2:
	if art.is_empty():return Vector2.ZERO
	var count:=int(art.facings)
	var frame:int=missile._sprite_facing(art,heading)
	var cache:Dictionary=art.get_or_add("missile_nose_pixels" if nose else "v3_tail_pixels",{})
	if cache.has(frame):return cache[frame]
	var rect:=RA2Art.draw_rect(art,radius,range(count),0.0,Unit.RA2_SPRITE_SCALE)
	var src:=Rect2i(RA2Art.src_rect(art,frame))
	var img:Image=art.get("img")
	if img==null:return rect.get_center()
	var az:=PI*0.25-(frame-int(art.get("facing_offset",0)))*TAU/count
	var forward:=Vector2(sin(az),-0.5*cos(az)).normalized()
	if nose:forward=-forward
	var loaded_truck:bool=art.get("key")=="V3"
	var aft:=INF
	var marked:=PackedVector2Array()
	for y in src.size.y:
		for x in src.size.x:
			var c:=img.get_pixel(src.position.x+x,src.position.y+y)
			if c.a<0.5:continue
			if loaded_truck and (c.b<=c.r*1.2 or c.b<=c.g*1.05):continue
			var pt:=Vector2(x+0.5,y+0.5)
			aft=minf(aft,pt.dot(forward))
			marked.append(pt)
	var sum:=Vector2.ZERO
	var n:=0
	for pt in marked:
		if pt.dot(forward)<=aft+2.0:
			sum+=pt;n+=1
	cache[frame]=rect.position+sum/float(n)*Unit.RA2_SPRITE_SCALE if n>0 else rect.get_center()
	return cache[frame]
