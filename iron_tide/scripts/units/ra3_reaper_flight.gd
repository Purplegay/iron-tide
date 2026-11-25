extends RefCounted
## The XML specifies the curve controls. The flat battlefield projects altitude onto its isometric canvas.
const Pose=preload("res://scripts/units/ra3_reaper_pose.gd")
const RoundVisual=preload("res://scripts/units/ra3_reaper_round.gd")
const Particles=preload("res://scripts/units/ra3_reaper_particles.gd")

static func spec(state:Dictionary) -> Dictionary:
	return Pose.definitions.rounds.rocket if state.soviet_round=="rocket" else Pose.definitions.rounds.grenade

static func event(state:Dictionary,kind:String) -> String:
	return spec(state)[("hero_" if state.get("reaper_heroic",false) else "")+kind]

static func launch(shot,unit) -> void:
	var s:Dictionary=shot.splinters
	var rule:=spec(s)
	s.reaper_heroic=unit.veteran_level>=3
	s.reaper_color=unit._col
	s.reaper_drift=randf_range(-1.0,1.0)*float(rule.curve.get("SidewaysDrift",0))*1.5
	s.duration=maxf(0.025,shot.position.distance_to(shot.target_point)/(randf_range(rule.speed_min,rule.speed_max)*1.5))
	update(shot,0.0)
	Particles.show_event(unit._battle_world(),shot.position,event(s,"launch"),s.reaper_yaw)

static func update(shot,t:float) -> void:
	var s:Dictionary=shot.splinters
	var curve:Dictionary=spec(s).curve
	var start:Vector2=s.start
	var chord:Vector2=shot.target_point-start
	var drift:=chord.normalized().orthogonal()*clampf(float(s.get("reaper_drift",0)),-chord.length()/2,chord.length()/2)
	var a:Vector2=start+chord*float(curve.FirstPercentIndent)/100+drift
	var b:Vector2=start+chord*float(curve.SecondPercentIndent)/100
	var ground:=start.bezier_interpolate(a,b,shot.target_point,t)
	var flatten:=minf(1,chord.length()/maxf(1.0,float(curve.get("CurveFlattenMinDist",0))*1.5))
	var h1:=float(curve.FirstHeightMin)*1.5*flatten
	var h2:=float(curve.SecondHeightMin)*1.5*flatten
	var lift:=bezier_interpolate(0,h1,h2,0,t)+float(s.get("target_height",0))*t
	var tangent:=start.bezier_derivative(a,b,shot.target_point,t)
	s.reaper_yaw=tangent.angle()
	s.reaper_pitch=atan2(bezier_derivative(0,h1,h2,0,t)+float(s.get("target_height",0)),tangent.length())
	shot.position=ground+RA2Art.art_dir(Vector2(0,-lift))
	var world=shot.get_parent().get_parent()
	var frame:=floori(minf(s.age,s.duration)*30.0)
	var trail_interval:=3 if world.projectiles_root.get_child_count()>=6 else 1
	var smoke:bool=s.soviet_round=="rocket" and frame-int(s.get("reaper_frame",0))>=trail_interval
	if smoke:s.reaper_frame=frame
	shot.visible=world.position_visible_to("ally",ground)
	if not shot.visible or DisplayServer.get_name()=="headless" or not shot.get_viewport_rect().grow(100).has_point(shot.get_global_transform_with_canvas().origin):return
	if t<1.0:
		var visual=RoundVisual.attach(shot)
		if visual!=null:visual.sync(s)
		if smoke:Particles.show_event(world,shot.position,"SovietRocketSmokeTrail",s.reaper_yaw)
