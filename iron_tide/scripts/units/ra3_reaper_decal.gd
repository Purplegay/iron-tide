extends Sprite2D
## DynamicDecal from FX_SovietSickleLand, drawn on the terrain plane.
var battle:Battle
var age:=0.0
var hold:float
var duration:float

static func spawn(world:Battle,point:Vector2,attrs:Dictionary) -> void:
	if world.in_water_world(point):return
	var mark=load("res://scripts/units/ra3_reaper_decal.gd").new()
	mark.battle=world
	mark.texture=load("res://assets/ra3/soviet/reaper_fx/"+str(attrs.Decal)+".png")
	mark.scale=Vector2.ONE*float(attrs.Size)*1.5/mark.texture.get_width()
	mark.hold=float(str(attrs.OpacityPeakTime).trim_suffix("s"))
	mark.duration=float(str(attrs.Lifetime).trim_suffix("s"))
	mark.position=point
	mark.z_as_relative=false
	mark.z_index=DepthLayers.DECAL
	world.add_child(mark)
	mark.add_to_group("reaper_particles")

func _process(delta:float) -> void:
	if battle.paused:return
	age+=delta
	visible=battle.position_visible_to("ally",position)
	modulate.a=clampf((duration-age)/(duration-hold),0.0,1.0)
	if age>=duration:queue_free()
