extends RefCounted
## HARV and NAREFN can be equipped independently. Ramp coordinates are native SHP pixels.
const ID := "night_shift"
const NAME := "夜班矿务"
const AMBER := Color("#ffbb49")
const STANDBY := Color("#447882")
const GUIDE := Color("#9ff3ed")
const HALO := Color(1.0, 0.63, 0.16, 0.26)

static func lamps(canvas:CanvasItem,start:Vector2,step:Vector2,lit:int,scale:float) -> void:
	var end := start + step * 3
	canvas.draw_line(start, end, Color("#254954"), 3.6 * scale)
	for marker in [start - step * 0.78, end + step * 0.78]:
		canvas.draw_circle(marker, 2.5 * scale, Color(0.34, 0.92, 0.90, 0.24))
		canvas.draw_circle(marker, 1.15 * scale, GUIDE)
	for i in 4:
		var p := start + step * i
		canvas.draw_circle(p, 1.9 * scale, STANDBY)
		if i < lit:
			canvas.draw_circle(p, 3.2 * scale, HALO)
			canvas.draw_circle(p, 1.75 * scale, AMBER)
			canvas.draw_circle(p, 0.85 * scale, Color("#fff3bc"))

# HARV.VXL cargo roof at (-14, 0, 25.697); the padded 32-facing atlas has
# its model origin at (36, 38). Use the actual hull frame, independent of the turret.
static func roof_pixel(frame:int,facings:int) -> Vector2:
	var azimuth:=PI/4-frame*TAU/facings
	return Vector2(36+14*sin(azimuth),38-7*cos(azimuth)-25.697*sqrt(3.0)/2.0)

static func truck(unit,base:Vector2,frame:int,facings:int,scale:float) -> void:
	var roof:Vector2=base+roof_pixel(frame,facings)*scale
	if unit._rock_t>0:
		roof=unit.rocking_pose()*roof
		Iso.begin(unit)
	var middle:=roof+Vector2.UP*2.0*scale
	for side in [-1,1]:
		var foot:Vector2=roof+Vector2.RIGHT*side*4.5*scale
		unit.draw_line(foot,foot+Vector2.UP*2.0*scale,Color("#39484a"),1.45*scale)
	var step:=Vector2.RIGHT*3.4*scale
	var lit:=ceili(4*clampf(float(unit.cargo)/maxf(1,unit.cargo_cap),0,1))
	lamps(unit,middle-step*1.5,step,lit,0.72*scale)

static func ramp(canvas:CanvasItem,base:Vector2,scale:float,remaining:float) -> void:
	var lit:=ceili(clampf(remaining,0,1)*4)
	for start in [Vector2(145,157),Vector2(161,149)]:
		lamps(canvas,base+start*scale,Vector2(-4,-2)*scale,lit,scale)
