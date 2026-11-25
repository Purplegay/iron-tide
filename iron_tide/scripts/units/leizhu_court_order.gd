extends RefCounted
const Cards=preload("res://scripts/units/leizhu_cards.gd")
const KEY="leizhu_court_order"

static func request(unit,point:Vector2) -> bool:
	var slot:=UnitSkillLayout.find(unit,Cards.ACTIVE)
	if slot<0 or not unit.ability_ready(slot) or not Cards.selectable(unit,point):return false
	unit.order_stop(false)
	if Cards.placement(unit,point):return unit.use_ability(slot,point)
	# Normal ground navigation owns paths, obstacles and movement; stop upon entering range.
	unit.order_move(point)
	if not unit.has_move_order:return false
	unit.special[KEY]={"point":point,"side":unit.side}
	return true

static func tick(unit) -> void:
	var order:Dictionary=unit.special[KEY]
	var point:Vector2=order.point
	var slot:=UnitSkillLayout.find(unit,Cards.ACTIVE)
	if order.side!=unit.side or slot<0 or not unit.ability_ready(slot) or not Cards.selectable(unit,point):
		unit.order_stop(false)
		return
	if Cards.placement(unit,point):
		unit.order_stop(false)
		unit.use_ability(slot,point)
	elif not unit.has_move_order:
		unit.special.erase(KEY)
