extends RefCounted
## Fixed blade geometry is uploaded once. Only the projection rotates each frame.
static var cached:ArrayMesh

static func mesh() -> ArrayMesh:
	if cached!=null:return cached
	var vertices:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	var shapes:=[
		[Vector2(5,-1),Vector2(57,-3),Vector2(59,3),Vector2(15,3)],
		[Vector2(17,-2.3),Vector2(55,-3.1),Vector2(55,-1.9),Vector2(17,-1.1)],
		[Vector2(55,-1.2),Vector2(58,-1.2),Vector2(58,1.2),Vector2(55,1.2)],
	]
	var palette:=[Color(.24,.27,.31,.9),Color(.52,.58,.65,.8),Color(.75,.6,.36,1)]
	for blade in 4:
		for part in shapes.size():
			var first:=vertices.size()
			for point:Vector2 in shapes[part]:vertices.append(point.rotated(blade*PI*.5));colors.append(palette[part])
			indices.append_array(PackedInt32Array([first,first+1,first+2,first,first+2,first+3]))
	var surface:=[];surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX]=vertices;surface[Mesh.ARRAY_COLOR]=colors;surface[Mesh.ARRAY_INDEX]=indices
	cached=ArrayMesh.new();cached.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface)
	return cached

static func draw(actor,center:Vector2,angle:float,factor:float,alpha:float) -> void:
	var forward:=Iso.dir(Vector2.from_angle(angle))*factor
	var side:=Iso.dir(Vector2.from_angle(angle+PI*.5))*factor
	actor.draw_mesh(mesh(),null,Transform2D(forward,side,center),Color(1,1,1,alpha))
	actor.draw_circle(center,2.3*factor,Color(.44,.45,.46,alpha),true,-1,true)
