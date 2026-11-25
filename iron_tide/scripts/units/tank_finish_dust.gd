extends RefCounted
## Shared orbital dust geometry. One retained mesh per hull side replaces 24
## circle tessellations and 24 individual line commands on every moving tank.
## Visual clock only: movement, combat and the skin's fade envelope stay live.
const FRAMES := 96
const PARTICLES := 24
const SIDES := 16
const SPEED := 1.85
const MAX_RADII := 8
static var cache:Dictionary={}

static func frame(age:float) -> int:
	return posmod(int(floor(age*SPEED/TAU*FRAMES)),FRAMES)

static func mesh(radius:float,age:float,behind:bool) -> ArrayMesh:
	var radius_key:=roundi(radius*100.0)
	if not cache.has(radius_key):
		# Unit radii are fixed, but workshop/custom units must not grow this forever.
		if cache.size()>=MAX_RADII:cache.erase(cache.keys()[0])
		cache[radius_key]={}
	var frames:Dictionary=cache[radius_key]
	var index:=frame(age)*2+int(behind)
	if not frames.has(index):frames[index]=build(radius_key/100.0,frame(age),behind)
	return frames[index]

static func build(radius:float,index:int,behind:bool) -> ArrayMesh:
	var points:=PackedVector2Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	for i in PARTICLES:
		var a:=float(index)*TAU/FRAMES+i*TAU/PARTICLES
		if (sin(a)<0)!=behind:continue
		var spread:=2.05+0.12*sin(i*9.1)
		var at:=Vector2(cos(a)*radius*spread,sin(a)*radius*0.62).rotated(-0.29)
		var previous:=Vector2(cos(a-0.14)*radius*spread,sin(a-0.14)*radius*0.62).rotated(-0.29)
		var normal:=(at-previous).normalized().orthogonal()
		var start:=points.size()
		# Solid 1.5px trail with a transparent fringe instead of per-line AA calls.
		for width in [-1.25,-0.75,0.75,1.25]:
			var color:=Color("#c08c55")
			color.a=0.53 if absf(width)<1 else 0.0
			points.append(previous+normal*width);points.append(at+normal*width)
			colors.append(color);colors.append(color)
		for strip in 3:
			var j:=start+strip*2
			indices.append_array(PackedInt32Array([j,j+1,j+2,j+1,j+3,j+2]))
		var size:=0.8+0.7*(i%3)
		var color:=Color("#ddb783") if i%2 else Color("#947152")
		color.a=0.83
		start=points.size()
		points.append(at);colors.append(color)
		for ring in 2:
			for vertex in SIDES:
				points.append(at+Vector2.from_angle(vertex*TAU/SIDES)*(size+ring*0.5))
				colors.append(color if ring==0 else Color(color,0))
		for vertex in SIDES:
			var j:=start+1+vertex
			var next:=start+1+(vertex+1)%SIDES
			indices.append_array(PackedInt32Array([start,j,next,j,j+SIDES,next,next,j+SIDES,next+SIDES]))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=points
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var result:=ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
