extends RefCounted
const Army=preload("res://scripts/expedition/army.gd")

static func soldier(id:String,rank:int=0,hero:String="") -> Dictionary:
	return {"id":id,"hp":0.5,"rank":rank,"xp":float(rank*10),"hero":hero,"variant":""}

static func run(t) -> void:
	t.new_ready("美国",1)
	var next:Dictionary=Expedition.state.duplicate(true)
	next.survivors=[soldier("E1",2),soldier("E1",3,"E1")]
	next.reinforcements=[];next.special_squads=[];next.active_roster=["E1"]
	Expedition.grant(next,{"kind":"special_unit","id":"E1","tier":3,"native_rank":3,"count":1})
	next.reinforcements=[{"id":"E1","count":9}]
	var balance:int=next.supplies
	t.check(Expedition.commit(next) and Army.quantity(Expedition.state,"E1")==8 and Expedition.state.supplies==balance+15,"auto-sale removes three ordinary excess infantry and pays fifteen")
	var veterans:=0
	var heroes:=0
	for row:Dictionary in Expedition.state.survivors:
		if row.rank==2:veterans+=1
		if row.hero=="E1":heroes+=1
	t.check(veterans==1 and heroes==1 and Expedition.state.special_squads[0].count==1,"auto-sale preserves veteran special and hero")
	var saved:Dictionary=Expedition.state.duplicate(true)
	t.check(Expedition.load_run() and Expedition.state==saved and Expedition.commit(saved.duplicate(true)) and Expedition.state==saved,"reload and repeated commit do not repay automatic sale")
	# A current-format camp save may already contain excess units before this change.
	next=saved.duplicate(true);next.reinforcements=[{"id":"E1","count":2}]
	var payload:=var_to_bytes(next)
	var file:=FileAccess.open(Expedition.FILE,FileAccess.WRITE)
	file.store_var({"version":Expedition.VERSION,"sha":BattleSaves.digest(payload),"payload":payload});file.close()
	t.check(Expedition.load_run() and Army.quantity(Expedition.state,"E1")==8 and Expedition.state.supplies==balance+25,"opening current camp save sells existing excess atomically")
	saved=Expedition.state.duplicate(true)
	t.check(Expedition.load_run() and Expedition.state==saved,"normalized camp save cannot pay again")
	# A full special squad is trimmed only when no ordinary unit can be removed.
	next=saved.duplicate(true);next.survivors=[];next.reinforcements=[];next.special_squads=[]
	Expedition.grant(next,{"kind":"special_unit","id":"E1","tier":3,"native_rank":3,"count":6})
	Expedition.grant(next,{"kind":"special_unit","id":"E1","tier":2,"native_rank":2,"count":4})
	# Simulate an overfull battle/save roster; recruitment itself now caps arrivals.
	next.special_squads[1].count=4;next.special_squads[1].max_count=4
	balance=next.supplies
	t.check(Expedition.commit(next) and Army.quantity(Expedition.state,"E1")==8 and Expedition.state.supplies==balance+10,"special-only excess pays actual removal count")
	t.check(Army.inventory(Expedition.state).size()==8,"special squad counts cannot recreate sold units")
	# Total population is enforced after per-type limits; vehicles are retained.
	next=Expedition.state.duplicate(true);next.special_squads=[];next.survivors=[];next.reinforcements=[]
	for id:String in ["E1","GGI","MTNK","FV","GHOST"]:
		for n in (8 if id in ["E1","GGI"] else 2 if id=="GHOST" else 4):next.survivors.append(soldier(id,0 if id=="E1" else 2))
	balance=next.supplies
	t.check(Expedition.commit(next) and Army.inventory(Expedition.state).size()==24 and Army.quantity(Expedition.state,"E1")==6 and Expedition.state.supplies==balance+10,"global population excess sells only two lowest-rank infantry")
	t.check(Army.quantity(Expedition.state,"MTNK")==4 and Army.quantity(Expedition.state,"FV")==4,"automatic infantry sale retains vehicles")
	next=Expedition.state.duplicate(true);next.repair_coupon=true;Expedition.commit(next)
	saved=Expedition.state.duplicate(true)
	t.check(not Expedition.service("refill","E1") and Expedition.state==saved,"global full roster refuses refill without charging or consuming coupon")
	Expedition.dismiss("E1",1)
	balance=Expedition.state.supplies
	t.check(Expedition.refill_count(Expedition.state,"E1")==1 and Expedition.service("refill","E1") and Army.quantity(Expedition.state,"E1")==6 and Army.inventory(Expedition.state).size()==24 and Expedition.state.supplies==balance and not Expedition.state.repair_coupon,"one population vacancy consumes one free refill and adds exactly one")
	# Per-type room also caps paid refills and direct event reinforcement grants.
	next=Expedition.state.duplicate(true);next.survivors=[];next.reinforcements=[{"id":"E1","count":7},{"id":"MTNK","count":3}];next.active_roster=["E1","MTNK"];Expedition.commit(next)
	balance=Expedition.state.supplies
	t.check(Expedition.service("refill","E1") and Army.quantity(Expedition.state,"E1")==8 and Expedition.state.supplies==balance-40,"paid refill fills only one infantry vacancy for displayed price")
	saved=Expedition.state.duplicate(true)
	t.check(not Expedition.service("refill","E1") and Expedition.state==saved,"per-type full roster cannot charge for empty paid refill")
	t.check(Expedition.service("refill","MTNK") and Army.quantity(Expedition.state,"MTNK")==4,"vehicle refill respects four-unit cap")
	next=Expedition.state.duplicate(true);Expedition.grant(next,{"kind":"reinforce","id":"E1"})
	t.check(Army.quantity(next,"E1")==8,"direct reinforcement grant never overfills")
	next.reinforcements.append({"id":"MTNK","count":2});balance=next.supplies;Expedition.commit(next)
	t.check(Army.quantity(Expedition.state,"MTNK")==6 and Expedition.state.supplies==balance and not Expedition.launch(0),"excess vehicles require manual choice and are not automatically sold")
	t.check(not Expedition.service("refill","MTNK"),"already overfull vehicles cannot refill")
	var count:=Army.inventory(Expedition.state).size()
	t.check(Expedition.repair() and Army.inventory(Expedition.state).size()==count,"whole-army repair never adds troops")
	# Real battle checkpoint and victory consume the same sale path as camp actions.
	t.new_ready("美国",1)
	next=Expedition.state.duplicate(true);next.routes[0].elite=false;Expedition.commit(next)
	t.check(Expedition.launch(0),"automatic sale battle fixture launches")
	if t.instantiate_battle():
		var field_count:=0
		for unit in t.battle.units:
			if t.battle.actor_alive(unit) and unit.unit_id=="E1" and unit.side=="ally":field_count+=1
		for n in maxi(0,15-field_count):t.battle.spawn_unit("E1","ally",t.battle.player_start()+Vector2(400+n*30,100))
		var roster_before:=Army.quantity(Expedition.state,"E1")
		balance=Expedition.state.supplies
		t.check(Expedition.checkpoint(t.battle) and Army.quantity(Expedition.state,"E1")==roster_before and Expedition.state.supplies==balance,"battle checkpoint preserves camp roster and balance until settlement")
		t.check(Expedition.load_run() and Army.quantity(Expedition.state,"E1")==roster_before and Expedition.state.supplies==balance,"battle checkpoint reload does not sell units mid-fight")
		var collectable:=0
		for row:Dictionary in Expedition.collect(t.battle):
			if row.id=="E1" and row.hero=="":collectable+=1
		t.check(collectable==15,"battle fixture has fifteen live carryable infantry",collectable)
		t.screen.expedition_runtime.tasks.finish(true)
		t.check(Expedition.state.phase=="reward" and Army.quantity(Expedition.state,"E1")==8 and Expedition.state.supplies==balance+180+35,"real victory pays reward plus seven excess infantry refunds",{"phase":Expedition.state.phase,"count":Army.quantity(Expedition.state,"E1"),"delta":Expedition.state.supplies-balance,"sale":Expedition.state.get("last_auto_sale",{})})
		t.check(Expedition.state.history.back().supplies==180,"victory history separates battle reward from automatic sale")
		saved=Expedition.state.duplicate(true)
		t.check(not Expedition.settle(t.battle,true) and Expedition.load_run() and Expedition.state==saved,"repeated victory and reopen cannot repeat sale payout")
	await t.finish()
