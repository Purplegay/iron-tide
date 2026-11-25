extends RefCounted
## Per-tank cosmetic state; the shader never changes the house-colour ramp.
const CHARGE_SECONDS := 8.0
const FADE_SECONDS := 4.0
const WALL_SECONDS := 0.55
var skin:int
var age:=0.0
var last_pos:=Vector2.INF
var dust:=0.0
var wall:=0.0
var glitter_left:=0.0
var next_glitter:=0.0
var glitter_angle:=0.0
var crystal_material:Material
var crystal_value:=-1.0
var rng:=RandomNumberGenerator.new()
const Dust = preload("res://scripts/units/tank_finish_dust.gd")

func _init(id:int) -> void:
	skin=id
	next_glitter=rng.randf_range(0.2,1.2)

func tick(actor,dt:float,showcase:=false) -> void:
	var pos:Vector2=actor.global_position
	var step:=pos.distance_to(last_pos) if last_pos.is_finite() else 0.0
	last_pos=pos
	if actor._dead or actor.embarked_in!=null:return
	var moving:=showcase or (step>0.01 and step<maxf(12,actor.move_speed*dt*2.5))
	age+=dt
	if skin==4:
		var charge:float=actor.special.get("cobalt_travel",0.0)
		var previous:=charge
		charge=move_toward(charge,1.0 if moving else 0.0,dt/(CHARGE_SECONDS if moving else FADE_SECONDS))
		if charge!=previous:actor.special.cobalt_travel=charge
		if actor.material is ShaderMaterial and (actor.material!=crystal_material or charge!=crystal_value):
			actor.material.set_shader_parameter("crystal_growth",charge)
			crystal_material=actor.material
			crystal_value=charge
		var had_glitter:=glitter_left>0
		glitter_left=maxf(0,glitter_left-dt)
		next_glitter-=dt
		if next_glitter<=0:
			glitter_left=0.48
			glitter_angle=rng.randf_range(0,TAU)
			next_glitter=rng.randf_range(0.75,2.2)
		# Growth lives in the shader: changing a uniform does not require rebuilding sprites.
		if glitter_left>0 or had_glitter:
			if preload("res://scripts/units/grizzly_visual_refresh.gd").refresh(actor) or (had_glitter and glitter_left==0):actor.queue_redraw()
	else:
		var was_active:=dust>0 or wall>0
		var previous_wall:=wall
		dust=move_toward(dust,1 if moving else 0,dt*2.6)
		wall=maxf(0,wall-dt)
		if actor.material is ShaderMaterial and wall!=previous_wall:actor.material.set_shader_parameter("armor_flash",wall/WALL_SECONDS)
		if was_active or dust>0:actor.queue_redraw()

func shell_hit() -> void:
	if skin==5:wall=WALL_SECONDS

func draw_on(actor,behind:bool) -> void:
	if actor._dead or actor.embarked_in!=null:return
	var r:float=actor.radius
	var center:=Vector2(0,-r*0.48)
	if skin==4:
		if behind or glitter_left<=0:return
		var alpha:=sin(glitter_left/0.48*PI)
		for i in 2:
			var ray:=Vector2.from_angle(glitter_angle+i*2.4)
			var at:=center+ray*Vector2(r*1.86,r*1.12)+Vector2.UP*(1-glitter_left/0.48)*4
			var w:=2.8*alpha*(1-i*0.28)
			if w<0.08:continue
			var gem:=PackedVector2Array([at+Vector2.UP*w*1.7,at+Vector2.RIGHT*w,at+Vector2.DOWN*w*1.7,at+Vector2.LEFT*w])
			actor.draw_colored_polygon(gem,Color(Color("#72e3ff"),alpha))
			actor.draw_line(gem[0],gem[2],Color(Color.WHITE,alpha),1,true)
			actor.draw_line(at-Vector2.RIGHT*w*1.8,at+Vector2.RIGHT*w*1.8,Color(Color("#d5fcff"),alpha),1,true)
		return
	if dust>0:
		# Far arc goes behind the hull; the near arc passes in front of its tracks.
		actor.draw_mesh(Dust.mesh(r,age,behind),null,Transform2D(0,center),Color(1,1,1,dust))
	if behind or wall<=0:return
	var t:=1-wall/WALL_SECONDS
	var alpha:=sin(sqrt(t)*PI)
	for i in 7:
		var a:=PI*(0.05+0.9*i/6)
		var at:=center+Vector2(cos(a)*r*1.06,sin(a)*r*0.51)-Vector2.DOWN*t*5
		var edge:=Vector2(3.8,1.8*cos(a))
		var up:=Vector2.UP*(4+3*alpha)
		var plate:=PackedVector2Array([at+up,at+edge,at-up,at-edge])
		actor.draw_colored_polygon(plate,Color(Color("#b4d1df"),alpha*0.76))
		actor.draw_line(plate[3],plate[0],Color(Color("#ffffff"),alpha),1.5,true)
