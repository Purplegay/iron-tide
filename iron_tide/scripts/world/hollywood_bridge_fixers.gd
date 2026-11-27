extends RefCounted

const Damage = preload("res://scripts/world/bridge_damage.gd")
const Drop = preload("res://scripts/world/american_paradrop.gd")
# ALL02UMD: break CellTag, repair hut waypoint, engineer drop waypoint.
const RETAIL = preload("res://data/maps/hollywood_drivers.json").data.bridges
# Historical indices retained for the bridge test fixtures and existing snapshots.
const CHAINS := [[[112,155],[102,157],[94,155]], [[112,150],[102,148],[94,150]], [[130,61],[123,63],[119,63]], [[131,56],[124,52],[119,50]]]

static func point(pair:Array) -> Vector2:
	return (Vector2(206-int(pair[1]),int(pair[0])-12)+Vector2.ONE*0.5)*55.0

static func tick(world, state:Dictionary, elapsed:float) -> void:
	var jobs:Dictionary=state.get_or_add("bridge_fixers",{})
	for i in RETAIL.size():
		var key:=str(i)
		var row:Dictionary=RETAIL[i]
		var section:=Damage.section_at(world,point(row.section))
		if not section.has_area():continue
		var hut=null
		var distance:=90.0
		for b in world.buildings:
			if not world.actor_alive(b) or b.building_id!="CABHUT":continue
			var d:float=b.position.distance_to(point(row.hut))
			if d<distance:hut=b;distance=d
		if Damage.health(world,section)>0.0:
			if jobs.has(key):
				var serial:int=jobs[key].serial
				for u in world.units:
					if not world.actor_alive(u) or u.special.get("hollywood_bridge_fixer",0)!=serial:continue
					u.special.erase("hollywood_bridge_target")
					if u.special.get("action")=="allied_bridge":u.order_stop(false)
			jobs.erase(key)
			continue
		if not jobs.has(key):
			state.bridge_fixer_serial=int(state.get("bridge_fixer_serial",0))+1
			jobs[key]={"left":float(row.delay),"sent":false,"serial":state.bridge_fixer_serial,"trigger":row.fixer}
		var job:Dictionary=jobs[key]
		if not job.sent:
			job.left=maxf(0.0,float(job.left)-elapsed)
			if job.left>0 or hut==null:continue
			var landing:=Drop.open_ground(world,point(row.landing))
			if not landing.is_finite():continue
			if Drop._start_drop(world,"enemy",landing,row.crew[1],int(row.crew[0]),{"hollywood_bridge_fixer":job.serial}):job.sent=true
		if hut==null:continue
		for u in world.units:
			if not world.actor_alive(u) or u.unit_id!="ENGINEER" or u.side!="enemy" or u.special.get("hollywood_bridge_fixer",0)!=job.serial or u.special.has("para_height"):continue
			u.special.hollywood_bridge_target=hut
			if u.special.get("target")==null:u.order_interaction("allied_bridge",hut,false)
