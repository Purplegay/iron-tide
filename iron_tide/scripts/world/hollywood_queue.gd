extends RefCounted

const ROUTES := ["0","1","2"]
const SPACING := 46.0
const LENGTH := 4
const INTERVAL := 5.0

static func slots(world, plant, street:Vector2) -> Array:
	if plant.special.has("civilian_queue_slots"): return plant.special.civilian_queue_slots
	var direction:Vector2 = plant.position.direction_to(street)
	for turn in [0,1,-1,2,-2,3,-3,4]:
		var axis := direction.rotated(float(turn)*PI/4)
		var gate:Vector2 = plant.position + axis*(plant.footprint_clearance(axis)+30.0)
		var points:Array = []
		for i in LENGTH+1:
			var point := gate+axis*SPACING*i
			if world.path_service.is_blocked(point,false): break
			points.append(point)
		if points.size()==LENGTH+1:
			plant.special.civilian_queue_slots=points
			return points
	return []

static func advance(world,plant,line:Array,elapsed:float) -> void:
	var points:Array=plant.special.get("civilian_queue_slots",[])
	if points.is_empty(): return
	var wait:=maxf(0,float(plant.special.get("civilian_queue_wait",INTERVAL))-elapsed)
	# World.units retains creation order, including on restore.
	for i in line.size():
		var u=line[i]
		var goal:Vector2=points[mini(i,points.size()-1)]
		if u.position.distance_to(goal)>18:
			if not u.has_move_order or u.move_target.distance_to(goal)>10:
				u.order_move(goal,false,null,world.path_for_unit(u,goal))
		elif i==0 and wait<=0:
			wait=INTERVAL
			plant.play_special()
			world.allied_state.hollywood.lost+=1
			world.credit_side("enemy",100)
			AlliedAbilities.consume(u)
	plant.special.civilian_queue_wait=wait
