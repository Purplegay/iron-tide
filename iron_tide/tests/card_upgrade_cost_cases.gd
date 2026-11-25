extends RefCounted
const A=preload("res://scripts/rules/academy.gd")
const EXPECTED={"common":[60,150,240],"rare":[70,170,270],"epic":[80,190,300],"legend":[90,210,330],"ultimate":[100,230,360]}

static func run(t) -> void:
	var m=MetaProgress
	var examples:Dictionary={}
	for card in GameData.skills:
		var rarity:String=str(card.get("rarity",""))
		if not EXPECTED.has(rarity):continue
		if not examples.has(rarity):examples[rarity]=str(card.id)
		for rank in 3:t.check(A.card_upgrade_cost(str(card.id),rank)==EXPECTED[rarity][rank],"configured upgrade price "+str(card.id)+" rank "+str(rank))
	t.check(examples.size()==5,"all five upgrade rarities covered")
	for rarity in examples:
		m.reset_save()
		var id:String=examples[rarity]
		m.unlocked_skills.append(id)
		for rank in 3:
			var price:int=EXPECTED[rarity][rank]
			m.currency.cores=price-1
			t.check(not A.purchase(m,"level",id) and m.balance("cores")==price-1 and A.card_rank(m,id)==rank,"insufficient cores preserve rank and balance "+rarity+str(rank))
			m.currency.cores=price
			t.check(A.purchase(m,"level",id) and m.balance("cores")==0 and A.card_rank(m,id)==rank+1,"exact rarity price charged "+rarity+str(rank))
			m.load_save()
			t.check(A.card_rank(m,id)==rank+1 and m.balance("cores")==0,"upgrade persists without retroactive charge "+rarity+str(rank))
		m.currency.cores=1000
		t.check(not A.purchase(m,"level",id) and m.balance("cores")==1000 and A.card_upgrade_cost(id,3)==0 and A.card_upgrade_cost(id,-1)==0,"rank bounds and cap prevent charges "+rarity)
	m.reset_save()
	m.currency.cores=1000
	t.check(not A.purchase(m,"level",examples.legend) and m.balance("cores")==1000,"unowned card cannot be upgraded")
	m.unlocked_skills.append(examples.legend)
	m.save()
	var original:=FileAccess.get_file_as_bytes(m.SAVE_PATH)
	t.check(DirAccess.make_dir_absolute(m.SAVE_PATH+".tmp")==OK,"block isolated upgrade save")
	t.check(not A.purchase(m,"level",examples.legend) and m.balance("cores")==1000 and A.card_rank(m,examples.legend)==0,"failed save rolls back new rarity price and rank")
	t.check(FileAccess.get_file_as_bytes(m.SAVE_PATH)==original,"failed upgrade leaves saved profile intact")
	DirAccess.remove_absolute(m.SAVE_PATH+".tmp")
	t.check(A.purchase(m,"level",examples.legend) and m.balance("cores")==910,"upgrade recovers after save target recovers")
	t.check(A.card_upgrade_cost("missing_card",0)==0,"unknown card has no purchasable price")
	await interface(t,examples)
	m.reset_save()

static func interface(t,examples:Dictionary) -> void:
	MetaProgress.reset_save()
	MetaProgress.currency.cores=99
	for card in GameData.skills:
		if EXPECTED.has(str(card.get("rarity",""))):MetaProgress.unlocked_skills.append(str(card.id))
	var ui=load("res://scenes/meta.tscn").instantiate();t.add_child(ui)
	ui.training_group="英雄";ui._set_page("pool")
	for row in A.ContractPool.entries():
		for id in row.cards:
			var upgrade:Button=ui.pool_body.find_child("Upgrade_"+id,true,false)
			t.check(upgrade!=null and upgrade.text.contains("100 战略核心") and upgrade.disabled,"hero panel shares ultimate price and affordability "+id)
	for rarity in examples:
		ui._clear(ui.pool_body)
		ui._build_pool_training([GameData.get_skill(examples[rarity])],MetaProgress.academy)
		var action:Button=ui.pool_body.get_node("TrainingUpgrade")
		t.check(action.text.contains("%d 战略核心"%int(EXPECTED[rarity][0])) and action.disabled==(rarity=="ultimate"),"pool price and affordability match rarity "+rarity)
	ui.free()
	await t.get_tree().process_frame
