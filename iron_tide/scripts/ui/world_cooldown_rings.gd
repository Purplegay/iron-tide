extends MultiMeshInstance2D
var used := 0
func _init() -> void:
 var mat := ShaderMaterial.new()
 mat.shader = preload("res://scripts/ui/world_cooldown_rings.gdshader")
 material=mat
 multimesh=MultiMesh.new()
 multimesh.transform_format=MultiMesh.TRANSFORM_2D
 multimesh.use_colors=true
 multimesh.use_custom_data=true
 multimesh.mesh=QuadMesh.new()
 multimesh.instance_count=1024
 multimesh.visible_instance_count=0
func begin(canvas:Node2D) -> void:
 used=0
 transform=canvas.get_global_transform_with_canvas().affine_inverse()
func append(center:Vector2,radius:float,info:Dictionary) -> bool:
 if used>=multimesh.instance_count:return false
 var extent:=2.0*(radius+2.5)
 multimesh.set_instance_transform_2d(used,Transform2D(Vector2(extent,0),Vector2(0,extent),center))
 var inactive:bool=info.get("inactive",false)
 multimesh.set_instance_color(used,info.color.darkened(0.55) if inactive else info.color)
 multimesh.set_instance_custom_data(used,Color(radius,info.fraction,1.0 if info.left<=0 else 0.0,1.0 if inactive else 0.0))
 used+=1
 return true
func finish() -> void:
 multimesh.visible_instance_count=used
