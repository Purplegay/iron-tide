extends RefCounted
## Single transaction for a selected talent: reuse paid slots and existing points first.
static func quote(meta,unit_id:String,talent:String) -> Dictionary:
	if (not GameData.unit_index.has(unit_id) and unit_id!="NABNKR") or not meta.talent_options(unit_id).has(talent):return {}
	var selected:Array=meta.selected_talents(unit_id,meta.unit_talents)
	if selected.has(talent) or selected.size()>=meta.available_talent_slots(unit_id):return {}
	var new_slot:int=selected.size()+1 if selected.size()>=meta.talent_capacity(unit_id) else 0
	var need_point:bool=meta.unassigned_talent_points()<1
	var slot_cost:int=meta.talent_slot_price(new_slot) if new_slot>0 else 0
	var point_cost:int=meta.talent_shop_price() if need_point else 0
	if (new_slot>0 and slot_cost<=0) or (need_point and point_cost<=0):return {}
	return {"cost":slot_cost+point_cost,"currency":meta.talent_shop_currency(),"new_slot":new_slot,"need_point":need_point,"slot_cost":slot_cost,"point_cost":point_cost}

static func purchase(meta,unit_id:String,talent:String,expected_cost:int) -> bool:
	var offer:=quote(meta,unit_id,talent)
	if offer.is_empty() or int(offer.cost)!=expected_cost:return false
	var cur:String=offer.currency
	var previous:float=meta.balance(cur)
	if previous<float(offer.cost):return false
	var had_currency:bool=meta.currency.has(cur)
	var old_slots:Variant=meta.talent_slots.get(unit_id)
	var old_talents:Variant=meta.unit_talents.get(unit_id)
	var old_points:int=meta.owned_talent_points
	var ranks:Dictionary={}
	for id in meta.selected_talents(unit_id,meta.unit_talents):ranks[id]=meta.talent_rank(unit_id,id,meta.unit_talents)
	ranks[talent]=0
	meta.currency[cur]=previous-float(offer.cost)
	if offer.new_slot>0:meta.talent_slots[unit_id]=int(offer.new_slot)
	if offer.need_point:meta.owned_talent_points+=1
	meta.unit_talents[unit_id]=ranks
	if not meta.save():
		if had_currency:meta.currency[cur]=previous
		else:meta.currency.erase(cur)
		if old_slots==null:meta.talent_slots.erase(unit_id)
		else:meta.talent_slots[unit_id]=old_slots
		if old_talents==null:meta.unit_talents.erase(unit_id)
		else:meta.unit_talents[unit_id]=old_talents
		meta.owned_talent_points=old_points
		return false
	Events.meta_changed.emit()
	return true
