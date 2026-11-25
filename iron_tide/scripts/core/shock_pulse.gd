extends Node2D
## Cosmetic only. Raw world coordinates prevent double isometric projection.
const LIFE:=1.8
const EXPAND:=0.95
var radius:=275.0
var age:=0.0
var detail:=true

static func spawn(actor,reach:float) -> void:
	var world=actor.battle if actor is Building else actor._battle_world()
	if world==null or not world.actor_visible_to("ally",actor):return
	var fx=load("res://scripts/core/shock_pulse.gd").new()
	fx.position=actor.global_position;fx.radius=reach
	# Burst casts retain waves but limit the number of detailed spark layers.
	fx.detail=world.get_tree().get_nodes_in_group("shock_pulse_fx").size()<8
	fx.add_to_group("shock_pulse_fx")
	world.effects_root.add_child(fx)

func _process(delta:float) -> void:
	age+=delta
	if age>=LIFE:queue_free();return
	queue_redraw()

func wave_fraction(delay:float=0.0) -> float:
	var t:=clampf((age-delay)/EXPAND,0,1)
	return 1.0-pow(1.0-t,2.0)

func fade() -> float:
	return 1.0-smoothstep(EXPAND,LIFE,age)

func _draw() -> void:
	var alpha:=fade()
	if alpha<=0:return
	# Broad soft rim, thin white-blue core, then a delayed inner wave.
	for i in 3:
		var delay:=float(i)*0.16
		if age<delay:continue
		var r:=radius*wave_fraction(delay)*(1.0-float(i)*0.055)
		if r<1:continue
		var strength:=alpha*(1.0-float(i)*0.25)
		var ring:=Iso.ground_circle(Vector2.ZERO,r)
		Iso.outline(self,ring,Color(0.12,0.5,1.0,strength*0.09),14.0)
		Iso.outline(self,ring,Color(0.2,0.75,1.0,strength*0.32),5.5)
		Iso.outline(self,ring,Color(0.65,0.96,1.0,strength*0.85),1.6)
	# Small concentric source coils dissipate; no full-screen flash or lighting changes.
	var core:=maxf(0,1.0-age/0.65)
	if core>0:
		for i in 2:
			Iso.outline(self,Iso.ground_circle(Vector2.ZERO,12+float(i)*10+age*22,48),Color(0.35,0.85,1,core*0.7),3.0)
	if not detail:return
	var front:=radius*wave_fraction()
	# Six brief branching discharges connect the expanding fronts, fading before
	# the lingering rim. One node and a fixed line budget even in a mass cast.
	var discharge:=alpha*(1.0-smoothstep(0.45,1.05,age))
	if discharge>0 and front>12:
		for i in 6:
			var angle:=float(i)*TAU/6.0+0.24
			var direction:=Vector2.from_angle(angle)
			var side:=direction.orthogonal()
			var bolt:=PackedVector2Array()
			for j in 7:
				var distance:=front*lerpf(0.24,0.96,float(j)/6.0)
				var jitter:=sin(float(i*17+j*13)+floorf(age*14)*2.3)*minf(9,front*0.06)
				bolt.append(direction*distance+side*jitter)
			draw_polyline(bolt,Color(0.12,0.4,1,discharge*0.12),10,true)
			draw_polyline(bolt,Color(0.2,0.75,1,discharge*0.45),3.2,true)
			draw_polyline(bolt,Color(0.75,0.95,1,discharge*0.8),1.1,true)
	# Discontinuous electricity travels around the front, bounded to the real radius.
	for i in 8:
		var points:=PackedVector2Array()
		for j in 9:
			var angle:=float(i)*TAU/8.0+float(j)*0.026+age*0.32
			var ripple:=sin(float(i*11+j*7)+floorf(age*18)*1.7)*3.0
			points.append(Vector2.from_angle(angle)*clampf(front+ripple,0,radius))
		draw_polyline(points,Color(0.25,0.65,1,alpha*0.22),5,true)
		draw_polyline(points,Color(0.75,0.98,1,alpha*0.9),1.2,true)
	# A small, fixed spark budget: no per-particle nodes or gameplay RNG use.
	for i in 16:
		var direction:=Vector2.from_angle(float(i)*TAU/16.0+float(i%3)*0.11)
		var spark:=direction*front*(0.84+0.01*float(i%7))
		var tail:=spark-direction*(4.0+float(i%4)*2.0)
		var intensity:=alpha*(0.4+0.3*sin(age*9+float(i)*1.8))
		draw_line(tail,spark,Color(0.5,0.9,1,intensity),1.6,true)
