extends RefCounted

const LEPTON := Ra2Damage.PX_PER_CELL / 256.0
const HEIGHT := preload("res://scripts/units/unit_flight.gd").HEIGHT_PIXEL
const RATE := BattleClock.RULE_TICKS_PER_SECOND

# FLH moves on the ground with the barrel. Height stays upright in every camera view.
static func offset(flh:Array,heading:float) -> Vector2:
	return Vector2(float(flh[0]),float(flh[1])).rotated(heading)*LEPTON + RA2Art.art_dir(Vector2.UP*float(flh[2])*HEIGHT)

static func muzzle(unit,secondary:=false) -> Vector2:
	var fx:Dictionary=unit.data.hollywood_fx
	var flh:Array=fx.secondary if secondary else fx.primary
	var heading:float=unit.turret_angle if not unit._ra2_tur.is_empty() else unit.hull_angle
	return unit.global_position+offset(flh,heading)

static func deposit(site) -> void:
	# A second delivery extends the current emission instead of stacking a second set of vents.
	var fx:Dictionary=site.data.hollywood_fx
	if not site.special.has("ore_smoke_left"):
		var ages:Array=site.special.get("ore_smoke_puffs",[])
		ages.append(0.0)
		if ages.size()>int(fx.particle_cap): ages.pop_front()
		site.special.ore_smoke_puffs=ages
		site.special.ore_smoke_next=float(fx.spawn_ticks)
	site.special.ore_smoke_left=float(fx.smoke_ticks)/RATE
	site.queue_redraw()

static func advance_smoke(site,dt:float) -> void:
	var fx:Dictionary=site.data.hollywood_fx
	var ticks:=dt*RATE
	var ages:Array=site.special.ore_smoke_puffs
	for i in ages.size(): ages[i]+=ticks
	if site.special.has("ore_smoke_left"):
		var emitting:float=site.special.ore_smoke_left*RATE
		var next:float=site.special.ore_smoke_next
		while next<=ticks and next<emitting:
			ages.append(ticks-next)
			next+=float(fx.spawn_ticks)
		if ticks>=emitting:
			site.special.erase("ore_smoke_left")
			site.special.erase("ore_smoke_next")
		else:
			site.special.ore_smoke_next=next-ticks
			site.special.ore_smoke_left-=dt
	while not ages.is_empty() and (ages.front()>=float(fx.particle_ticks) or ages.size()>int(fx.particle_cap)):
		ages.pop_front()
	if ages.is_empty(): site.special.erase("ore_smoke_puffs")
	site.queue_redraw()

static func draw_smoke(site) -> void:
	var fx:Dictionary=site.data.hollywood_fx
	var art:=RA2Art.fx(fx.smoke_image)
	if art.is_empty(): return
	for age:float in site.special.ore_smoke_puffs:
		var progress:=clampf(age/float(fx.particle_ticks),0,1)
		var frame:=mini(floori(age/float(fx.frame_ticks)),mini(int(fx.end_frame),int(art.count)-1))
		var rect:=RA2Art.fx_rect(art,frame)
		var size:Vector2=art.cell*lerpf(0.45,0.8,progress)
		for vent in fx.vents:
			var rise:float=(fx.velocity*age-0.5*fx.deceleration*age*age)*HEIGHT
			var point:=Iso.dir(offset(vent,0))+Vector2.UP*rise
			site.draw_texture_rect_region(art.tex,Rect2(point-size*0.5,size),rect,Color(1,1,1,float(fx.smoke_opacity)*(1-progress)))
