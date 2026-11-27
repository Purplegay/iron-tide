extends RefCounted
const Army=preload("res://scripts/expedition/army.gd")
const Market=preload("res://scripts/expedition/market.gd")
const Catalog=preload("res://scripts/expedition/catalog.gd")

static func run(t) -> void:
	t.new_ready("美国",16)
	var next:Dictionary=Expedition.state.duplicate(true)
	next.survivors=[];next.reinforcements=[{"id":"E1","count":8},{"id":"MTNK","count":4},{"id":"TANY","count":1}]
	next.special_squads=[];next.active_roster=["E1","MTNK","TANY"]
	for id:String in Catalog.BUFFS:next.buffs[id]=3
	for id:String in Army.TRAITS:next.trait_buffs[id]=9
	for id:String in next.licenses:next.unit_growth[id]={"atk":5,"def":5}
	next.heroes=["E1","MTNK"]
	t.check(Expedition.commit(next),"full offer fixture saves")
	t.check(Army.limit("TANY")==1 and Army.limit("BORIS")==1 and Army.limit("YURIPR")==1,"original unique-unit build limits govern recruitment")
	t.check(Army.room(next,"TANY")==0,"owned unique unit has no duplicate vacancy")
	for seed_value in 24:
		next.seed=seed_value
		for stage in [2,4,6,14,16,19,21,26,30]:
			next.stage=stage
			for pool:Array in [Market.unit_pool(next),Market.rewards(next),Market.bonus_rewards(next),Market.shop(next,0),Market.shop(next,1),Catalog.offer(next,"unit","victory_unit")]:
				for item:Dictionary in pool:
					t.check(Market.offer_available(next,item),"full or owned offers excluded %d:%d:%s:%s"%[seed_value,stage,item.kind,item.id])
			for choice:Dictionary in Market.event(next).choices:
				t.check(Market.offer_available(next,choice.item),"event never charges for capped reward %d:%d"%[seed_value,stage])
				if choice.item.kind=="training":
					t.check(choice.label.contains(Army.training_name(choice.item.id)),"training event names its target unit")
	next.stage=16
	next.shop=[{"kind":"unit","id":"E1","price":80,"locked":true,"sold":false},{"kind":"buff","id":"armor","price":120,"locked":true,"sold":false}]
	for refresh in [0,1]:
		for item:Dictionary in Market.shop(next,refresh):
			t.check(Market.offer_available(next,item) and not item.locked,"invalid locked offers expire on next shop or refresh")
	Expedition.commit(next)
	var saved:Dictionary=Expedition.state.duplicate(true)
	t.check(not Expedition.buy(0) and not Expedition.buy(1) and Expedition.state==saved,"stale full unit and max equipment cannot charge")
	# Recruits grant inventory, while exhausted upgrades convert into a one-time payout.
	for item:Dictionary in [{"kind":"unit","id":"E1"},{"kind":"special_unit","id":"TANY","tier":3},{"kind":"buff","id":"armor"},{"kind":"training","id":"E1"},{"kind":"hero","id":"E1"}]:
		next=saved.duplicate(true);next.phase="reward";next.reward_round="main";next.offers=[item]
		Expedition.commit(next)
		var balance:int=Expedition.state.supplies
		var token:=Expedition.reward_token()
		var display:=Market.reward_item(Expedition.state,item)
		if item.kind in ["unit","special_unit"]:
			var quantity:=Army.quantity(Expedition.state,item.id)
			t.check(display==item,"recruit reward remains available for reserves "+item.kind)
			t.check(Expedition.load_run() and Expedition.choose(0,"",token) and Expedition.state.supplies==balance and Army.quantity(Expedition.state,item.id)==quantity+Market.recruit_batch(item),"full recruit reward added to reserves "+item.kind)
		else:
			t.check(display.kind=="supplies" and display.amount==100 and Catalog.description(display).contains("改领补给"),"converted reward explains compensation "+item.kind)
			t.check(Expedition.load_run() and Expedition.choose(0,"",token) and Expedition.state.supplies==balance+100,"unavailable reward pays through real claim "+item.kind)
		var claimed:Dictionary=Expedition.state.duplicate(true)
		t.check(not Expedition.choose(0,"",token) and Expedition.load_run() and Expedition.state==claimed,"persisted reward cannot be claimed twice "+item.kind)
	# Rewards grant their full batch. Excess inventory stays in reserve.
	next=saved.duplicate(true);next.shop=[];next.heroes=[]
	next.reinforcements=[{"id":"MTNK","count":3}];next.active_roster=["MTNK"]
	var balance:int=next.supplies
	Expedition.grant(next,{"kind":"unit","id":"MTNK"})
	t.check(Army.quantity(next,"MTNK")==3+Catalog.squad_size("MTNK") and next.supplies==balance and Army.deployment(next).counts.MTNK==4,"vehicle reward keeps surplus in reserve without refund")
	next.reinforcements=[];next.special_squads=[];next.active_roster=[]
	Expedition.grant(next,{"kind":"unit","id":"TANY"})
	t.check(Army.quantity(next,"TANY")==1,"ordinary unique recruitment cannot create duplicates")
	Expedition.grant(next,{"kind":"special_unit","id":"TANY","tier":3,"count":1})
	t.check(Army.quantity(next,"TANY")==2 and Army.deployment(next).counts.TANY==1 and Army.deployment(next).reserve.size()==1,"ordinary and special variants share unique deployment capacity")
	next.reinforcements=[];next.special_squads=[]
	Expedition.grant(next,{"kind":"special_unit","id":"TANY","tier":3,"count":2})
	t.check(Army.quantity(next,"TANY")==2 and Army.room(next,"TANY")==0 and Army.deployment(next).counts.TANY==1,"special-first unique reward retains reserve and blocks shop duplication")
	# Chapter population constrains deployment while the shop still has room for new types.
	next.stage=1;next.special_squads=[];next.reinforcements=[{"id":"E1","count":8},{"id":"GGI","count":8},{"id":"MTNK","count":4},{"id":"FV","count":4}]
	next.active_roster=["E1","GGI","MTNK","FV"]
	t.check(Army.deployment(next).remaining==0 and not Market.unit_pool(next).is_empty() and Army.room(next,"TANY")==1,"full deployment leaves new types available for reserve recruitment")
	# Vacancies and equipment below max become eligible again; no permanent blacklist.
	next.reinforcements=[{"id":"E1","count":7}];next.buffs.armor=2
	t.check(Market.offer_available(next,{"kind":"unit","id":"E1"}) and Market.offer_available(next,{"kind":"buff","id":"armor"}),"vacancy and nonmax equipment are available again")
	next.heroes=["E1"]
	t.check(not Market.offer_available(next,{"kind":"hero","id":"E1"}) and Market.offer_available(next,{"kind":"hero","id":"MTNK"}),"one owned hero excludes duplicate but permits second distinct hero")
	Expedition.commit(saved)
