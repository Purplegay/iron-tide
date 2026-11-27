extends MultiMeshInstance2D
## Shared draw for ordinary world bars; hit flashes/alerts use the original painter.
const CAPACITY := 256
var used := 0
# Compare the payload at each batch slot, not the entity: visible order may
# change every frame. Keep hidden slots' payloads for when they are reused.
var _written := 0
var _visible := 0
var _rects: Array[Rect2] = []
var _fills := PackedColorArray()
var _states := PackedColorArray()
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
 multimesh.instance_count = CAPACITY
 multimesh.visible_instance_count = 0
 _rects.resize(CAPACITY)
 _fills.resize(CAPACITY)
 _states.resize(CAPACITY)
func begin() -> void:
 used = 0
 transform = Transform2D(Iso.eff_angle(), Iso.up(), 0.0, Vector2.ZERO)
 material.set_shader_parameter("clock_ms", float(Time.get_ticks_msec()))
func append(rect:Rect2, frac:float, fill:Color, ghost:float, rim:Color) -> bool:
 if used >= CAPACITY: return false
 var first_write := used >= _written
 if first_write or _rects[used] != rect:
  _rects[used] = rect
  var size := rect.size + Vector2(4,4)
  multimesh.set_instance_transform_2d(used, Transform2D(Vector2(size.x,0),Vector2(0,size.y),rect.get_center()))
 if first_write or _fills[used] != fill:
  _fills[used] = fill
  multimesh.set_instance_color(used,fill)
 var hp := clampf(frac,0,1)
 var state := Color(rect.size.x,rect.size.y,hp,clampf(ghost,hp,1)+(2.0 if rim.a>0 else 0.0))
 if first_write or _states[used] != state:
  _states[used] = state
  multimesh.set_instance_custom_data(used,state)
 if first_write: _written = used + 1
 used += 1
 return true
func finish() -> void:
 if used != _visible:
  _visible = used
  multimesh.visible_instance_count = used
