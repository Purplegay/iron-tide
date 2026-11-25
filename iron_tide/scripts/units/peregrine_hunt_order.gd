extends RefCounted
const Cards=preload("res://scripts/units/peregrine_cards.gd")
const Service=preload("res://scripts/units/peregrine_service.gd")
const KEY="peregrine_hunt_order"

static func selected(world,point:Vector2) -> int:
	var source=world.selected_skill_unit()
	if not is_instance_valid(source):return 0
	var target=world._pick_at(point,false)
	if target==null:target=Cards.pick(source,point,false)
	var count:=0
	for unit in world.selected_units:
		if not AlliedAbilities.alive(unit) or unit.side!="ally":continue
		var ab=unit.ability_at(UnitSkillLayout.find(unit,Cards.ACTIVE))
		if request(unit,ab,target):count+=1
	return count

static func request(unit,ab,target) -> bool:
	if ab==null or not Cards.ready(unit,ab) or not Cards.selectable(unit,target):return false
	unit.order_stop(false)
	Service.leave(unit)
	if Cards.target_in_range(unit,target):return Cards.cast_target(unit,ab,target)
	unit.special[KEY]={"target":target,"side":unit.side}
	unit.has_move_order=true
	unit.move_target=target.position
	return true

static func tick(unit,dt:float) -> void:
	var order:Dictionary=unit.special[KEY]
	var target=order.get("target")
	var ab=unit.ability_at(UnitSkillLayout.find(unit,Cards.ACTIVE))
	if order.side!=unit.side or ab==null or not Cards.ready(unit,ab) or not Cards.selectable(unit,target):
		unit.order_stop(false)
		return
	if Cards.target_in_range(unit,target):
		unit.order_stop(false)
		Cards.cast_target(unit,ab,target)
		return
	var point:Vector2=Cards.R.point(unit,target)
	var weapon:Dictionary=unit._weapon_for_target(null)
	var reach:=maxf(float(weapon.get("min_range",0))+12.0,float(weapon.get("range",0))*.8)
	var away:Vector2=point.direction_to(unit.position)
	if away.is_zero_approx():away=Vector2.RIGHT
	unit.move_target=point+away*reach
	unit.flight.travel(unit.move_target,dt)
	unit._limit_turn(dt)
