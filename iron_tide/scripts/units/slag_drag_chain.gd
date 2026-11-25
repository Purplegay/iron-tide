extends RefCounted
## A short cosmetic chain in map-oriented axes, measured in hull spans.
const LINKS:=9
const LENGTH:=0.054
const STEP:=1.0/60.0
const LINK_CLEARANCE:=0.024
const SHOE_CLEARANCE:=0.036
var dimensions:=Vector3.ONE
var segment_length:=LENGTH
var link_clearance:=LINK_CLEARANCE
var shoe_clearance:=SHOE_CLEARANCE

func set_dimensions(value:Vector3) -> void:
	if dimensions.is_equal_approx(value):return
	dimensions=value
	segment_length=LENGTH*value.x
	link_clearance=LINK_CLEARANCE*value.y
	shoe_clearance=SHOE_CLEARANCE*value.y
	points.clear()

var points:=PackedVector3Array()
var previous:=PackedVector3Array()
var remainder:=0.0
var root:Node3D
var rings:Array[MeshInstance3D]=[]
var shoe:MeshInstance3D

func reset(pin:Vector3,rear:Vector3) -> void:
	points.resize(LINKS+1)
	points[0]=pin
	for i in range(1,LINKS+1):
		var height:=shoe_clearance if i==LINKS else link_clearance
		var drop:=clampf(points[i-1].y-height,0.0,segment_length*0.86)
		points[i]=points[i-1]+rear*sqrt(segment_length*segment_length-drop*drop)-Vector3.UP*drop
	previous=points.duplicate()
	remainder=0.0

func advance(dt:float,pin:Vector3,rear:Vector3) -> void:
	if points.is_empty() or points[0].distance_to(pin)>1.25 or dt>0.20:
		reset(pin,rear)
		return
	remainder+=dt
	var steps:=floori((remainder+0.000001)/STEP)
	if steps<=0:return
	remainder=maxf(0.0,remainder-steps*STEP)
	var start:=points[0]
	for n in steps:
		points[0]=start.lerp(pin,float(n+1)/steps)
		for i in range(1,LINKS+1):
			var clearance:=shoe_clearance if i==LINKS else link_clearance
			var speed:=(points[i]-previous[i])*0.987
			if points[i].y<=clearance+0.0001:
				speed.x*=0.72
				speed.z*=0.72
			previous[i]=points[i]
			points[i]+=speed+Vector3.DOWN*(6.0*STEP*STEP)
		for iteration in 8:
			for i in range(1,LINKS+1):
				var segment:=points[i]-points[i-1]
				var distance:=segment.length()
				if distance>0.000001:
					var correction:=segment*((distance-segment_length)/distance)
					if i>1:
						correction*=0.5
						points[i-1]+=correction
					points[i]-=correction
			# The floor is the same y=0 plane used by the vehicle's ground shadow.
			for i in range(1,LINKS+1):
				points[i].y=maxf(points[i].y,shoe_clearance if i==LINKS else link_clearance)

func pose(local_from_map:Transform3D) -> void:
	var a:=local_from_map*points[0]
	for i in LINKS:
		var b:=local_from_map*points[i+1]
		var axis:=a.direction_to(b)
		if axis.length_squared()>0.5:
			var normal:=Vector3.FORWARD if absf(axis.z)<0.9 else Vector3.UP
			var radial:=axis.cross(normal).normalized()
			var frame:=Basis(axis,radial,axis.cross(radial)).rotated(axis,0.45 if i%2==0 else 1.75)
			rings[i].transform=Transform3D(frame.scaled_local(Vector3(1.42,1,0.78)),(a+b)*0.5)
		a=b
	shoe.transform=Transform3D(local_from_map.basis.orthonormalized(),a)
