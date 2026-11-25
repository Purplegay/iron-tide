extends RefCounted
const Attention=preload("res://scripts/expedition/attention.gd")
const Army=preload("res://scripts/expedition/army.gd")

static func buttons(root:Node,part:String) -> Array:
	var result:Array=[]
	for node in root.get_children():
		if node is Button and part in node.text:result.append(node)
		result.append_array(buttons(node,part))
	return result

static func dotted(button:Control) -> bool:
	var dot=button.get_node_or_null("AttentionDot")
	return button.get_meta("attention_active",false) and dot!=null and dot.mouse_filter==Control.MOUSE_FILTER_IGNORE

static func inspect(t) -> void:
	var run:Dictionary=Expedition.state
	if run.is_empty():return
	if Attention.reward(run):
		var choices:=buttons(t.camp,"选取奖励")
		t.check(choices.size()==run.offers.size() and choices.all(dotted),"all unclaimed reward buttons have nonblocking red dots")
		var tabs:=buttons(t.camp,"战后奖励 · 待领取")
		t.check(tabs.size()==1 and dotted(tabs[0]),"pending reward tab stays marked until claimed")
	if Attention.event(run):
		var tabs:=buttons(t.camp,"战后事件 · 待选择")
		t.check(tabs.size()==1 and dotted(tabs[0]),"unresolved post-battle event tab is marked")
		for choice in buttons(t.camp,"选择 ·"):t.check(dotted(choice)==not choice.disabled,"only actionable event choices have red dots")
	if run.phase=="ready":
		var free:=not Attention.free_units(run).is_empty()
		var tabs:=buttons(t.camp,"军团与天赋")
		t.check(tabs.size()==1 and dotted(tabs[0])==(free or not Attention.free_refills(run).is_empty()),"army tab reflects usable free upgrade even when selected")
		t.check(buttons(t.camp,"待领取").is_empty(),"claimed rewards leave no stale reward tab")
		for upgrade in buttons(t.camp,"攻防强化 +1"):
			t.check(dotted(upgrade)==(free and not upgrade.disabled),"upgrade button matches actual usable free chance")

static func lifecycle(t) -> void:
	var original:Dictionary=Expedition.state.duplicate(true)
	t.camp.change_tab(2)
	inspect(t)
	t.check(Expedition.load_run(),"attention state reload after using free upgrade")
	t.camp.build();inspect(t)
	t.check(not Attention.any(Expedition.state),"consumed reward and free upgrade clear aggregate reminder")
	var next:Dictionary=original.duplicate(true);next.stage+=1
	t.check(Expedition.commit(next),"prepare next stage free upgrade")
	t.camp.build();inspect(t)
	t.check(not Attention.free_units(next).is_empty(),"next stage restores available free upgrade reminder")
	lobby(t,true)
	for id:String in Army.available(next):next.unit_growth[id]={"atk":5,"def":5}
	Expedition.commit(next);t.camp.build();inspect(t)
	t.check(not Attention.any(next),"all units capped suppress unspendable free upgrade red dot")
	lobby(t,false)
	next.repair_coupon=true
	next.survivors=[]
	next.reinforcements=[]
	next.special_squads=[]
	var unit_id:String=Army.available(original)[0]
	Army.add_unit(next,unit_id,1)
	Expedition.commit(next);t.camp.change_tab(2)
	var refills:=buttons(t.camp,"补员 +")
	t.check(refills.size()==1 and dotted(refills[0]),"free personnel refill marks eligible unit")
	inspect(t);lobby(t,true)
	var balance:int=Expedition.state.supplies
	t.check(Expedition.service("refill",unit_id) and Expedition.state.supplies==balance,"redeem free personnel refill")
	t.camp.build();inspect(t);lobby(t,false)
	next=original.duplicate(true);next.stage+=1
	for id:String in Army.available(next):
		for track in ["atk","def"]:next.frozen.expedition_growth_disabled[id+":"+track]=true
	t.check(not Attention.free_units(next).is_empty(),"legacy disabled tracks can use free upgrades")
	for phase in ["battle","complete","failed"]:
		next=original.duplicate(true);next.stage+=1;next.phase=phase
		t.check(not Attention.any(next),"inactive camp phase suppresses free upgrade reminder "+phase)
	Expedition.commit(original);t.camp.build()

static func lobby(t,expected:bool) -> void:
	var menu=load("res://scenes/main.tscn").instantiate();t.stage.add_child(menu)
	var entries:=buttons(menu,"肉鸽远征")
	t.check(entries.size()==1 and dotted(entries[0])==expected,"main menu expedition entry aggregates pending actions "+str(expected))
	menu.free()
