extends RefCounted
## Isolated workload at real selection/order dispatch boundaries. Raw input
## routing is covered separately by selection/formation/cursor regressions.
static var next_order:=0.0
static var frame:=0
static var orders:=0
static var counts:Dictionary={"hover":0,"box":0,"move":0,"attack":0,"selected_peak":0}

static func tick(world) -> void:
	frame+=1
	if world.units.is_empty():return
	var actor=world.units[frame%world.units.size()]
	if world.actor_alive(actor):
		world.command_cursor.sample_pointer(actor.art_center())
		counts.hover+=1
	if world.fog.sight_clock<next_order:return
	next_order=world.fog.sight_clock+5.0
	world._apply_selection(Vector2.ZERO,false,Rect2(Vector2(-100000,-100000),Vector2(200000,200000)))
	counts.box+=1
	counts.selected_peak=maxi(counts.selected_peak,world.selected_units.size())
	if world.selected_units.is_empty():return
	orders+=1
	if orders%2==0:
		for target in world.units:
			if world.actor_alive(target) and not BattleRequest.friendly("ally",target.side) and world.actor_visible_to("ally",target):
				world.force_attack(target)
				counts.attack+=1
				return
	var unit=world.selected_units[0]
	var target:Vector2=(unit.position+Vector2(120,120) if orders%4<2 else unit.position-Vector2(120,120)).clamp(Vector2.ONE*100,Vector2.ONE*(world.map_size-100))
	world._command_move(target)
	counts.move+=1
