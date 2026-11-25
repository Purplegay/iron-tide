extends MultiMeshInstance2D
## Shared draw for ordinary world bars; hit flashes/alerts use the original painter.
var used := 0
func _init() -> void:
 show_behind_parent = true
 var mat := ShaderMaterial.new()
 mat.shader = preload("res://scripts/ui/world_health_bars.gdshader")
 material = mat
 multimesh = MultiMesh.new()
 multimesh.transform_format = MultiMesh.TRANSFORM_2D
 multimesh.use_colors = true
 multimesh.use_custom_data = true
 multimesh.mesh = QuadMesh.new()
 multimesh.instance_count = 256
 multimesh.visible_instance_count = 0
func begin() -> void:
 used = 0
 transform = Transform2D(Iso.eff_angle(), Iso.up(), 0.0, Vector2.ZERO)
 material.set_shader_parameter("clock_ms", float(Time.get_ticks_msec()))
func append(rect:Rect2, frac:float, fill:Color, ghost:float, rim:Color) -> bool:
 if used >= multimesh.instance_count: return false
 var size := rect.size + Vector2(4,4)
 multimesh.set_instance_transform_2d(used, Transform2D(Vector2(size.x,0),Vector2(0,size.y),rect.get_center()))
 multimesh.set_instance_color(used,fill)
 multimesh.set_instance_custom_data(used,Color(rect.size.x,rect.size.y,clampf(frac,0,1),clampf(ghost,clampf(frac,0,1),1)+(2.0 if rim.a>0 else 0.0)))
 used += 1
 return true
func finish() -> void:
 multimesh.visible_instance_count = used
