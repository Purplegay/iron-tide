extends RefCounted
## Exhaust and hull share one texture and one draw submission. No particles or extra viewport.
static var indices:=PackedInt32Array([0,1,2,0,2,3,4,5,6,4,6,7,8,9,10,8,10,11])
static var corners:=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
var geometry:Dictionary={}
var meshes:Dictionary={}

func visible(actor,fold:float) -> bool:
	return not actor._dead and actor.embarked_in==null and not actor.powered_unit.offline and fold<.95

func vertices(frame:int,factor:float,hub:Vector2,roots:Array=[]) -> PackedVector2Array:
	var key:=Vector3(frame,hub.x,hub.y)
	if not geometry.has(key):
		var angle:=frame*TAU/32.0
		var aft:=Vector2(-cos(angle),-sin(angle)*.55)
		var across:=Vector2(-sin(angle),cos(angle)*.55)
		var points:=PackedVector2Array()
		for index in 2:
			var side:=index*2-1
			var root:Vector2=Vector2(roots[index][0],roots[index][1])*factor if roots.size()==2 else hub+(aft*9+across*side*16+Vector2(0,24))*factor
			var tail:Vector2=root+aft*28*factor
			var width:=aft.orthogonal().normalized()*4.5*factor
			points.append_array(PackedVector2Array([root-width,tail-width*1.6,tail+width*1.6,root+width]))
		geometry[key]=points
	return geometry[key]

func draw(actor,rig,frame:int,fold:float,tint:Color,factor:float) -> void:
	var data:Dictionary=rig.model()
	var key:Vector2i=Vector2i(rig.body_source.position)
	var texture:Texture2D=rig.asset(rig.body_key).tex
	if not meshes.has(key):
		var hub:Vector2=rig.rotor_center(frame)*factor
		var pose:=int(rig.body_source.position.y/float(data.texture_tile))/4
		var points:=vertices(frame,factor,hub,data.exhaust_roots[pose*32+frame]).duplicate()
		var uv:=PackedVector2Array()
		for i in 8:uv.append(Vector2(data.exhaust_uv[0],data.exhaust_uv[1])+corners[i%4]*Vector2(data.exhaust_uv[2],data.exhaust_uv[3]))
		for corner in corners:
			points.append(corner*rig.body_rect.size)
			uv.append((rig.body_source.position+corner*rig.body_source.size)/Vector2(texture.get_size()))
		for i in points.size():points[i]+=rig.body_rect.position
		meshes[key]={"points":points,"uv":uv,"origin":rig.body_rect.position,"colors":PackedColorArray(),"tint":Color(-1,-1,-1,-1),"plume":-1.0}
	var mesh:Dictionary=meshes[key]
	if mesh.origin!=rig.body_rect.position:
		var shift:Vector2=rig.body_rect.position-mesh.origin
		var points:PackedVector2Array=mesh.points
		for i in points.size():points[i]+=shift
		mesh.points=points;mesh.origin=rig.body_rect.position
	var plume:float=tint.a*(1-fold) if visible(actor,fold) else 0.0
	if mesh.tint!=tint or mesh.plume!=plume:
		var colors:=PackedColorArray();colors.resize(12)
		colors.fill(Color(.731,.987,.997,plume))
		for i in range(8,12):colors[i]=tint
		mesh.colors=colors;mesh.tint=tint;mesh.plume=plume
	RenderingServer.canvas_item_add_triangle_array(actor.get_canvas_item(),indices,mesh.points,mesh.colors,mesh.uv,PackedInt32Array(),PackedFloat32Array(),texture.get_rid())
