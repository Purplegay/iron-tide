extends RefCounted
## Decoration reads flight/service state; it never advances repair or reload clocks.
var clock:=0.0

static func handles(unit) -> bool:
	return unit.unit_id=="ORCA" and unit.special.get("academy_hero")=="ORCA" and unit.special.has("peregrine") and not unit._dead and unit.embarked_in==null

static func install_preview(unit) -> void:
	unit.special.academy_hero="ORCA"
	unit.special.peregrine={}
	unit.logistics.air_lift=1.0
	unit.peregrine_fx=new()
	unit.refresh_house_color()

func tick(unit,delta:float) -> void:
	if not handles(unit):return
	clock=fposmod(clock+maxf(0,delta),60.0)
	unit.queue_redraw()

static func state(unit) -> Dictionary:
	var wreck:Dictionary=unit.special.get("hero_wreck",{})
	var maintenance:Dictionary=unit.special.get("peregrine",{}).get("maintenance",{})
	var altitude:=clampf(float(unit.logistics.air_lift),0,1)
	var broken:=not wreck.is_empty()
	return {"gear":1.0-smoothstep(0.0,.8,altitude),
		"thrust":0.0 if broken else smoothstep(0.0,.3,altitude),
		"broken":broken,"repair":float(wreck.get("repair_elapsed",0))>0,
		"healing":not maintenance.is_empty() and float(maintenance.get("descent",1))==0 and float(maintenance.get("quiet",0))>=3 and unit.hp<unit.max_hp}

func draw_under(unit) -> void:
	if not handles(unit):return
	var s:=state(unit)
	var center:=Vector2(0,-unit._visual_lift())
	var forward:=Vector2.from_angle(unit.hull_angle)
	var spread:=Iso.dir(forward.orthogonal()*unit.radius*.65)
	var rear:=Iso.dir(-forward*unit.radius*.25)
	if s.thrust>0:
		var mounts:Array[Vector2]=[center+rear-spread+Vector2.DOWN*3,center+rear+spread+Vector2.DOWN*3]
		if unit.hero_art!=null:mounts=preload("res://scripts/units/peregrine_art.gd").engine_mounts(unit)
		for index in mounts.size():
			var root:Vector2=mounts[index]
			var length:float=(10+2*sin(clock*19+index*2-1))*s.thrust
			unit.draw_colored_polygon(PackedVector2Array([root+Vector2(-2.8,0),root+Vector2(2.8,0),root+Vector2(0,length)]),Color(.2,.65,1,.35*s.thrust))
			unit.draw_line(root,root+Vector2(0,length*.65),Color(.7,.94,1,.85*s.thrust),1.4,true)
	if s.gear>0:
		var mounts:Array[Vector2]=[rear+spread,rear-spread,Iso.dir(forward*unit.radius*.6)]
		for mount in mounts:
			var root:Vector2=center+mount
			var foot:Vector2=root+Vector2(0,6*s.gear)
			unit.draw_line(root,foot,Color(.48,.55,.62),1.7,true)
			unit.draw_line(foot-Vector2(2.5,0),foot+Vector2(2.5,0),Color(.19,.23,.28),2,true)

func draw_over(unit) -> void:
	if not handles(unit):return
	var s:=state(unit)
	var center:=Vector2(0,-unit._visual_lift())
	if s.broken:
		# Two bounded smoke puffs, no emitters, pooled nodes or lifetime bookkeeping.
		for index in 2:
			var phase:=fposmod(clock*.45+index*.5,1.0)
			unit.draw_circle(center+Vector2(3+phase*5,-4-phase*15),2+phase*3,Color(.2,.23,.27,(1-phase)*.35))
	if s.repair or s.healing:
		var point:=center+Vector2(5,-3)
		var bright:=.55+.35*sin(clock*22)
		var color:=Color(.6,.9,1,bright) if s.repair else Color(.3,1,.6,bright)
		unit.draw_line(point-Vector2(3,0),point+Vector2(3,0),color,1.5,true)
		unit.draw_line(point-Vector2(0,3),point+Vector2(0,3),color,1.5,true)
