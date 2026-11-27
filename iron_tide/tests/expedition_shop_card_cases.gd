extends RefCounted

static func cards(root:Node) -> Array:
	var result:Array=[]
	for child in root.get_children():
		if child.has_meta("shop_index"):result.append(child)
		result.append_array(cards(child))
	return result

static func inherits_tint(node:Node) -> bool:
	for child in node.get_children():
		if child.name=="DiscountOverlay":
			if child.use_parent_material or child.get_node("DiscountBadge").use_parent_material:return false
			continue
		if child is CanvasItem and child.get_class()!="Control" and not child.use_parent_material:return false
		if not inherits_tint(child):return false
	return true

static func offer(kind:String,id:String,price:int,sold:bool=false) -> Dictionary:
	return {"kind":kind,"id":id,"price":price,"sold":sold,"locked":false}

static func run(t) -> void:
	var original:Dictionary=Expedition.state.duplicate(true)
	var next:Dictionary=original.duplicate(true)
	var id:String=next.active_roster[0]
	next.supplies=100;next.buffs.armor=1;next.buffs.health=3;next.trait_buffs.infantry=9
	next.unit_growth[id]={"atk":5,"def":5}
	next.relics.field_manual=true;next.relics.erase("prism_matrix")
	next.shop=[offer("buff","armor",80),offer("buff","firepower",180),offer("buff","engines",80,true),offer("relic","field_manual",40),offer("buff","health",80),offer("trait_buff","infantry",80),offer("training",id,40),offer("relic","prism_matrix",280)]
	t.check(Expedition.commit(next),"shop card mixed-state fixture")
	var saved:Dictionary=Expedition.state.duplicate(true)
	Expedition.error=""
	t.camp.change_tab(1)
	await t.settle()
	t.check(Expedition.state==saved and Expedition.error.is_empty(),"rendering purchase eligibility does not change state or error")
	var entries:=cards(t.camp)
	t.check(entries.size()==8,"all mixed shop cards rendered")
	if entries.size()!=8:return
	var reasons:=["","补给不足","已售罄","已持有","已满 3 级","已满 9 层","攻防已满 5 级","第 16 关"]
	for index in entries.size():
		var shell:PanelContainer=entries[index]
		var box:VBoxContainer=shell.get_child(0)
		var purchase:Button=box.get_node("PurchaseButton")
		var lock_button:Button=box.get_node("LockButton")
		t.check(purchase.disabled==(index!=0),"purchase disabled matches actual eligibility "+str(index))
		t.check(lock_button.disabled==(index in [2,3,4,5,6]),"only offers eligible to carry into the next shelf can be locked "+str(index))
		var reason:String=shell.get_meta("purchase_reason")
		t.check(reason.is_empty() if index==0 else reason.contains(reasons[index]),"card explains purchase restriction "+str(index))
		if index==0:
			t.check(shell.material==null and shell.get_meta("purchase_state")=="available","available card keeps normal palette")
		else:
			t.check(shell.material is ShaderMaterial and shell.material.get_shader_parameter("sold_out")==bool(index==2),"sold grey and unavailable warm tint are distinct "+str(index))
			t.check(inherits_tint(shell),"whole card including portrait title description and buttons inherits state tint "+str(index))
			purchase.pressed.emit()
			t.check(Expedition.state==saved,"blocked UI callback cannot buy "+str(index))
			t.check(not Expedition.buy(index) and Expedition.state==saved,"authoritative purchase agrees with card restriction "+str(index))
	# These states must remain contained and readable through every existing viewport size.
	await t.inspect_sizes("mixed available unavailable and sold shop cards")
	var locked:Button=entries[1].get_child(0).get_node("LockButton")
	locked.pressed.emit()
	t.check(Expedition.state.shop[1].locked and Expedition.state.supplies==100,"insufficient-supply card still locks without spending")
	entries=cards(t.camp)
	var buy:Button=entries[0].get_child(0).get_node("PurchaseButton")
	buy.pressed.emit()
	entries=cards(t.camp)
	t.check(Expedition.state.shop[0].sold and Expedition.state.supplies==20 and entries[0].get_meta("purchase_state")=="sold" and entries[0].material.get_shader_parameter("sold_out"),"successful purchase immediately greys the whole card")
	var purchased:Dictionary=Expedition.state.duplicate(true)
	t.camp.request_item("shop",0)
	t.check(Expedition.state==purchased,"stale click on sold card cannot charge again")
	next=Expedition.state.duplicate(true);next.supplies=200;Expedition.commit(next);t.camp.build()
	entries=cards(t.camp)
	t.check(entries[1].get_meta("purchase_state")=="available" and entries[1].material==null and not entries[1].get_child(0).get_node("PurchaseButton").disabled,"supply recovery restores normal color and purchase availability")
	t.camp.request_item("shop",1)
	t.check(Expedition.state.shop[1].sold and Expedition.state.supplies==20,"newly affordable item can be bought through real UI")
	Expedition.commit(original);t.camp.build()
