extends Node2D
## Project the two intersecting GPU muzzle quads around the firing axis.
const P=preload("res://scripts/units/ra3_gunship_impact.gd")
var battle:Battle
var heading:float
var data:Dictionary
var texture:Texture2D
var flashes:Array[Dictionary]=[]
var age:=0.0

func setup(world:Battle,point:Vector2,angle:float,emitter:Dictionary,folder:String) -> void:
	battle=world;position=point;heading=angle;data=emitter
	texture=load(folder+str(data.attrs.ParticleTexture)+".png")
	var mat:=CanvasItemMaterial.new();mat.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=mat
	var update:=P.child(data,"Update/RenderObject")
	for i in int(P.range_value(P.child(data,"BurstCount"),1)):
		flashes.append({"start":P.range_value(P.child(data,"InitialDelay")),"life":P.range_value(P.child(data,"Lifetime")),"roll":P.range_value(P.child(update,"AngleX")),"size":P.xyz(P.child(update,"StartSize")).abs(),"rate":P.xyz(P.child(update,"SizeRate")),"damping":P.xyz(P.child(update,"SizeDamping"),1).abs(),"color_scale":P.range_value(P.child(P.child(data,"Colors"),"ColorScale"),1)})
		# xyz converts positions into Godot space. Restore the sign of native Y for size rates.
		flashes.back().rate.z=-flashes.back().rate.z
	world.effects_root.add_child(self);add_to_group("reaper_particles")

func _process(dt:float) -> void:
	if battle.paused:return
	age+=dt*30
	if not flashes.any(func(f):return age<f.start+f.life):queue_free();return
	visible=battle.position_visible_to("ally",position)
	queue_redraw()

func _draw() -> void:
	Iso.begin(self)
	var direction:=Vector2.from_angle(heading)
	var side:=Iso.dir(direction.orthogonal())
	var forward:=Iso.dir(direction)
	var uv:=PackedVector2Array([Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)])
	for f in flashes:
		var t:float=age-f.start
		if t<=0 or t>=f.life:continue
		var size_:Vector3=f.size
		for axis in 3:size_[axis]=maxf(0.01,size_[axis]+f.rate[axis]*P.integral(t,f.damping[axis]))
		var color:=P.color_at(data,t/f.life*100.0)*float(f.color_scale)
		color.a=P.alpha_at(data,t/f.life*100.0)
		var start:=forward*-7.5
		var end:=start+forward*size_.x*1.5
		for n in 2:
			var roll:float=f.roll+PI*n/2
			var span:Vector2=(side*cos(roll)*size_.z+Vector2.UP*sin(roll)*size_.y*sqrt(0.75))*0.75
			if absf(span.cross(end-start))<0.01:continue
			draw_polygon(PackedVector2Array([start-span,start+span,end+span,end-span]),PackedColorArray([color]),uv,texture)
