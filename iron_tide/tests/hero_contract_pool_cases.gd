extends RefCounted
const Pool=preload("res://scripts/rules/hero_contract_pool.gd")
const A=preload("res://scripts/rules/academy.gd")

class FailedSave:
	extends RefCounted
	const Academy=preload("res://scripts/rules/academy.gd")
	var academy:Dictionary={"card_shards":7,"tickets":2}
	var currency:Dictionary={"diamonds":100000}
	var unlocked_skills:Array=[]
	func save() -> bool:return false
	func balance(id:String) -> float:return float(currency.get(id,0))
	func skill_draw_enabled() -> bool:return true
	func skill_draw_rules() -> Dictionary:return GameData.skill_draw_rules()
	func skill_draw_candidates() -> Array[Dictionary]:return MetaProgress.skill_draw_candidates()
	func skill_draw_cost() -> float:return MetaProgress.skill_draw_cost()
	func skill_unlocked(id:String) -> bool:return unlocked_skills.has(id)

static func run(t) -> void:
	var config:=Pool.rules()
	var original_chance:float=config.chance
	var count:=Pool.entries().size()
	t.check(is_equal_approx(original_chance,.0035) and count>=4 and Pool.reward_count()==count*2,"configured shared 0.35 percent pool includes two rewards per contract")
	var seeds:Dictionary={}
	for n in 30000:
		seed(n)
		if randf()>=original_chance:continue
		var row:Dictionary=Pool.entries().pick_random()
		if not seeds.has(row.id):seeds[row.id]=n
		if seeds.size()==count:break
	t.check(seeds.size()==count,"all configured contract candidates reachable from shared probability gate")
	for row in Pool.entries():
		if not seeds.has(row.id):continue
		MetaProgress.reset_save()
		seed(int(seeds[row.id]))
		var result:=A.draw(MetaProgress,1,true)
		t.check(result.size()==1 and result[0].id==row.id and Pool.owned(MetaProgress,row),"real free draw awards configured contract "+row.id)
		t.check(MetaProgress.academy.card_shards==1 and MetaProgress.unlocked_skills.is_empty(),"drawing a contract gives one shard without granting task rewards "+row.id)
		t.check(Pool.candidates(MetaProgress).size()==count-1 and Pool.description(MetaProgress,row.id).contains("不再参与"),"owned contract excluded and explanation refreshes "+row.id)
		MetaProgress.load_save()
		t.check(Pool.owned(MetaProgress,row) and not A.daily_draw_available(MetaProgress,A.day()),"contract and daily draw survive reload "+row.id)
	MetaProgress.reset_save()
	# Guaranteed miss: use a known seed whose first roll is above the threshold.
	var miss_seed:=0
	for n in 100:
		seed(n)
		if randf()>=original_chance:miss_seed=n;break
	seed(miss_seed)
	var ordinary:=A.draw(MetaProgress,1,true)
	t.check(ordinary.size()==1 and Pool.entry(ordinary[0].id).is_empty() and Pool.owned_count(MetaProgress)==0,"shared gate miss falls back to exactly one ordinary card")
	MetaProgress.reset_save()
	config.chance=1.0
	MetaProgress.academy.tickets=2
	MetaProgress.currency.diamonds=8*MetaProgress.skill_draw_cost()
	var ten:=A.draw(MetaProgress,10)
	var received:Array=[]
	for row in ten:
		if not Pool.entry(row.id).is_empty():received.append(row.id)
	t.check(ten.size()==10 and received.size()==count and Pool.owned_count(MetaProgress)==count,"ten draw refreshes candidates after every award and falls back after all contracts")
	for row in Pool.entries():t.check(received.count(row.id)==1,"ten draw never repeats owned contract "+row.id)
	t.check(MetaProgress.balance("diamonds")==0 and MetaProgress.academy.tickets==0 and MetaProgress.academy.card_shards>=10,"ten draw preserves ticket diamond and shard accounting")
	t.check(MetaProgress.unlocked_skills.size()<=10-count and Pool.summary(MetaProgress).contains("已全部获得"),"full collection keeps contract rewards locked until tasks and explains no remaining candidates")
	config.chance=original_chance
	await interface(t)
	await gallery(t)
	MetaProgress.reset_save()
	MetaProgress.academy.furnace_contract=true
	MetaProgress.academy.furnace_complete=true
	MetaProgress.academy.hero_contracts={"E1":{"first":23.0,"second":12.0,"win":false,"complete":false},"MTNK":{"first":20.0,"second":25.0,"win":true,"complete":true}}
	t.check(Pool.candidates(MetaProgress).size()==count-3 and Pool.candidates(MetaProgress).any(func(row):return row.hero_id=="HTNK") and not Pool.candidates(MetaProgress).any(func(row):return row.hero_id in ["E1","E2","MTNK"]),"legacy furnace and expansion progress exclude only already acquired contracts")
	t.check(not Pool.grant(MetaProgress,"watch_contract") and MetaProgress.academy.hero_contracts.E1.first==23,"repeated grant cannot reset existing task progress")
	MetaProgress.academy.card_shards=Pool.cost()
	t.check(Pool.purchase(MetaProgress,"spine_contract") and MetaProgress.academy.card_shards==0 and Pool.candidates(MetaProgress).size()==count-4 and not Pool.candidates(MetaProgress).any(func(row):return row.hero_id=="HTNK"),"exchange uses the same acquisition and exclusion state as draws")
	config.chance=1.0
	var failed:=FailedSave.new()
	var before:Dictionary=failed.academy.duplicate(true)
	var wallet:Dictionary=failed.currency.duplicate(true)
	t.check(A.draw(failed,10).is_empty() and failed.academy==before and failed.currency==wallet and failed.unlocked_skills.is_empty(),"failed ten draw save rolls back contracts wallet shards tickets and cards atomically")
	failed.academy.card_shards=Pool.cost()
	before=failed.academy.duplicate(true)
	t.check(not Pool.purchase(failed,"watch_contract") and failed.academy==before,"failed exchange save rolls back contract and shards")
	config.chance=original_chance
	MetaProgress.reset_save()

static func interface(t) -> void:
	var ui=load("res://scenes/meta.tscn").instantiate();t.add_child(ui)
	ui.training_group="英雄";ui._set_page("pool")
	var ordinary:int=MetaProgress.skill_draw_candidates().size()
	var count:=Pool.entries().size()
	t.check(ui.pool_body.get_node("PoolCollection").text.contains("/ %d"%(ordinary+count)) and ui.pool_body.get_node("PoolCollection").text.contains("英雄契约 %d/%d"%[count,count]),"collection totals include regular cards and all acquired contracts")
	var groups:OptionButton=ui.pool_body.get_node("TrainingGroup")
	for i in groups.item_count:
		if groups.get_item_metadata(i)=="英雄":t.check(groups.get_item_text(i).contains("%d 个契约 · %d 张奖励卡"%[count,count*2]),"hero category dynamically displays contract and reward counts")
	var original:Array=Pool.entries().duplicate(true)
	Pool.rules().entries=original.slice(0,3)
	ui._refresh_pool()
	t.check(ui.pool_body.get_node("PoolCollection").text.contains("/ %d"%(ordinary+3)) and not ui.pool_body.has_node("HeroContract_HTNK"),"removing catalog entry updates total and panels without UI changes")
	groups=ui.pool_body.get_node("TrainingGroup")
	for i in groups.item_count:
		if groups.get_item_metadata(i)=="英雄":t.check(groups.get_item_text(i).contains("3 个契约 · 6 张奖励卡"),"reward count derives from catalog after configuration change")
	Pool.rules().entries=original
	ui.free()
	await t.get_tree().process_frame

static func gallery(t) -> void:
	var original:Array=Pool.entries().duplicate(true)
	var view=preload("res://scripts/ui/faction_card_gallery.gd").new();t.add_child(view)
	var listed:Array=[]
	var headings:Array=[]
	for i in view.picker.item_count:
		if view.picker.get_popup().is_item_separator(i):headings.append(view.picker.get_item_text(i))
		else:listed.append(view.picker.get_item_metadata(i))
	t.check(headings.size()==original.size(),"gallery generates one section for each configured hero")
	for contract in original:
		t.check(headings.has("英雄 · "+str(contract.name).trim_suffix("契约")),"gallery hero section uses contract name "+contract.id)
		for id in contract.cards:
			t.check(listed.count(id)==1,"hero reward appears once in gallery "+id)
			if id in view.HeroDemo.TABS:continue
			for i in view.picker.item_count:
				if view.picker.get_item_metadata(i)!=id:continue
				view.picker.item_selected.emit(i)
				t.check(view.stage.card==id and view.picker.selected==i,"grouped hero option routes to correct demo "+id)
				view.levels.item_selected.emit(3)
				t.check(view.stage.preview_rank==3 and view.picker.get_item_metadata(view.picker.selected)==id,"rank change preserves grouped skill selection "+id)
	for id in [view.ids[0],"ap_mirror_fork"]:
		view.select_card(view.ids.find(id),1)
		t.check(view.picker.get_item_metadata(view.picker.selected)==id,"direct demo selection maps card index past separators "+id)
	view.free()
	var modified:Array=original.filter(func(row):return row.hero_id in ["E2","E1","MTNK","HTNK"]).duplicate(true)
	modified.reverse();modified[0].name="测试改名契约"
	modified=modified.slice(0,3)
	modified.append({"id":"test_catalog_contract","hero_id":"E1","name":"新增测试契约","cards":["ap_smoke"]})
	Pool.rules().entries=modified
	view=preload("res://scripts/ui/faction_card_gallery.gd").new();t.add_child(view)
	headings=[];listed=[]
	for i in view.picker.item_count:
		if view.picker.get_popup().is_item_separator(i):headings.append(view.picker.get_item_text(i))
		else:listed.append(view.picker.get_item_metadata(i))
	t.check(headings==["英雄 · 测试改名","英雄 · 北辰","英雄 · 守望者","英雄 · 新增测试"],"gallery follows configured order rename removal and addition")
	t.check(not listed.has("furnace_contract") and not listed.has("ap_furnace_bastion") and listed.count("ap_smoke")==1,"removed hero disappears and added hero skill is not duplicated in ordinary list")
	for i in view.picker.item_count:
		if view.picker.get_item_metadata(i)=="ap_smoke":
			view.picker.item_selected.emit(i)
			t.check(view.stage.card=="ap_smoke" and view.picker.selected==i,"new catalog group opens skill without hardcoded hero branch")
	view.free();Pool.rules().entries=original
	await t.get_tree().process_frame
