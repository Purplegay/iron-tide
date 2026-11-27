extends RefCounted
const Campaign=preload("res://scripts/expedition/campaign.gd")
const Market=preload("res://scripts/expedition/market.gd")
const Relics=preload("res://scripts/expedition/relics.gd")
const Attention=preload("res://scripts/expedition/attention.gd")

static func run(t) -> void:
	for stage in [15,16,25,26,30]:
		t.new_ready("美国",stage)
		var next:Dictionary=Expedition.state.duplicate(true)
		next.phase="reward";next.reward_round="main";next.trait_buffs={};next.tracked_traits=["infantry","fortify"]
		next.relics={};next.buffs={};next.offers=Market.rewards(next)
		var expected_rounds:int=3 if stage>=26 else 2 if stage>=16 else 1
		var expected_choices:int=4 if stage>=16 else 3
		t.check(next.offers.size()==expected_choices,"main choice breadth at boundary "+str(stage))
		var with_compass:Dictionary=next.duplicate(true);with_compass.relics.choice_compass=true
		t.check(Market.rewards(with_compass).size()==expected_choices+1 and Market.bonus_rewards(with_compass).size()==expected_choices+1,"compass expands both late reward pools "+str(stage))
		t.check(Expedition.commit(next),"save late reward fixture "+str(stage))
		var main_token:=Expedition.reward_token()
		t.check(Expedition.choose(0,"",main_token),"claim main before bonus rounds "+str(stage))
		for number in range(1,expected_rounds+1):
			var expected_id:String="buff" if number==1 else "buff_%d"%number
			var pending:Dictionary=Expedition.state.duplicate(true)
			var token:=Expedition.reward_token()
			t.check(pending.phase=="reward" and pending.reward_round==expected_id and pending.offers.size()==expected_choices,"all promised bonus rounds have full choices %d:%d"%[stage,number])
			t.check(Attention.reward(pending) and Attention.summary(pending).contains("额外 Buff"),"extra round retains reward reminder %d:%d"%[stage,number])
			t.check(Expedition.load_run() and Expedition.state==pending and Market.bonus_rewards(pending)==pending.offers,"reload preserves late offers and deterministic round salt %d:%d"%[stage,number])
			t.check(not Expedition.choose(0,"",main_token) and not Expedition.launch(0) and not Expedition.resolve_event(0) and Expedition.state==pending,"pending bonus cannot be skipped or claimed by stale main callback %d:%d"%[stage,number])
			var directions:Array=[]
			for item:Dictionary in pending.offers:
				if item.kind=="trait_buff":directions.append(item.id)
			t.check("infantry" in directions and "fortify" in directions,"both marked builds remain available %d:%d"%[stage,number])
			t.check(Expedition.choose(0,"",token),"claim distinct bonus round %d:%d"%[stage,number])
			var claimed:Dictionary=Expedition.state.duplicate(true)
			t.check(not Expedition.choose(0,"",token) and Expedition.state==claimed,"double click cannot consume next bonus %d:%d"%[stage,number])
		t.check(Expedition.state.phase=="event" and Expedition.resolve_event(0,Expedition.event_token()) and Expedition.state.phase=="ready","only final bonus opens event then camp "+str(stage))
		t.check(Expedition.state.shop.size()==6 and Expedition.shop_stage(stage),"sixth chapter shop supports every new stage "+str(stage))
	# Focused choices can now complete both marked nine-layer builds during chapter four/five.
	t.new_ready("美国",16)
	var next:Dictionary=Expedition.state.duplicate(true)
	next.tracked_traits=["infantry","fortify"];next.trait_buffs={};next.relics={}
	for stage in range(16,25):
		next.stage=stage;next.phase="reward";next.reward_round="main";next.offers=[{"kind":"supplies","id":"bonus","amount":100}]
		Expedition.commit(next);Expedition.choose(0,"",Expedition.reward_token())
		for direction:String in ["infantry","fortify"]:
			if int(Expedition.state.trait_buffs.get(direction,0))==9:
				var fallback:=-1
				for index in Expedition.state.offers.size():
					var item:Dictionary=Expedition.state.offers[index]
					t.check(item.kind!="trait_buff" or item.id!=direction,"maxed direction excluded from pending choices")
					if item.kind!="trait_buff" or item.id not in next.tracked_traits:fallback=index
				t.check(fallback>=0 and Expedition.choose(fallback,"",Expedition.reward_token()),"claim an alternative when the target is complete")
				continue
			var found:=-1
			for index in Expedition.state.offers.size():
				var item:Dictionary=Expedition.state.offers[index]
				if item.kind=="trait_buff" and item.id==direction:found=index
			t.check(found>=0 and Expedition.choose(found,"",Expedition.reward_token()),"targeted build progresses each late reward %d:%s"%[stage,direction])
		next=Expedition.state.duplicate(true)
	t.check(next.trait_buffs.get("infantry",0)==9 and next.trait_buffs.get("fortify",0)==9,"two focused nine-layer builds complete before final chapter")
	for item:Dictionary in Market.bonus_rewards(next):
		t.check(item.kind!="trait_buff" or item.id not in ["infantry","fortify"],"completed builds stop occupying extra choice slots")
