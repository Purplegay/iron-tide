extends Node
const Market=preload("res://scripts/expedition/market.gd")
const Growth=preload("res://scripts/expedition/growth.gd")
var failures:=0
var checks:=0
func check(ok:bool,text:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(text)
func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation") and not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):get_tree().quit(2);return
	var plan=preload("res://scripts/expedition/reinforcement_plan.gd")
	var initial:=[{"id":"E1","due":10.0},{"id":"MTNK","due":30.0},{"id":"E2","due":50.0}]
	var queued:=initial.slice(1).duplicate(true)
	var copies:Array=plan.radio_copies(queued,initial,20.0)
	check(copies.size()==2 and copies[0].due==30 and copies[1].due==50,"radio copies every pending batch without advancing it")
	queued.append_array(copies)
	check(plan.radio_copies(queued,initial,21.0).is_empty(),"radio cannot recursively copy a marked batch")
	var replay:Array=plan.radio_copies([],initial,90.0)
	check(replay.size()==3 and replay[0].due==100 and replay[1].due==120 and replay[2].due==140,"completed roster replays on a new clock")
	check_camp_audio()
	check_shelf_discounts()
	check_purchase_at_population_limit()
	check_bulk_discounts()
	check_recruit_weights()
	check_special_recruits()
	check_targeted_recruits()
	var random:=RandomNumberGenerator.new()
	for kind:String in ["training","native","specialization"]:
		for rank in [1,2,3]:
			var item:Dictionary={"kind":kind,"id":"E1","rank":rank,"price":999,"shop_price_applied":true}
			Market.roll_shop_prices([item],random)
			check(int(item.price)<int(item.original_price),"shop strictly cheaper including old price markers")
			var price:int=item.price
			Market.apply_shop_price(item)
			check(item.price==price,"discount is idempotent")
	var run:Dictionary={"seed":1,"stage":16,"licenses":["E1"],"special_squads":[],"specializations":{},"native_talents":{},"native_levels":{},"frozen":{},"unit_growth":{"E1":{"atk":5,"def":5}},"shop":[{"kind":"training","id":"E1","price":25,"locked":true,"sold":false}]}
	check(not Growth.can_upgrade(run,"E1"),"full growth cannot upgrade")
	check(Market.growth_pool(run).is_empty(),"full growth excluded from generation")
	check(not Market.keep_locked(run,run.shop[0]),"lock cannot preserve full growth")
	Market.normalize_shop(run)
	check(run.shop.size()==1 and not run.shop[0].locked and not Expedition.item_problem(run,run.shop[0]).is_empty(),"maxed training stays visible and unlocked until refresh")
	run.shop=[{"kind":"supplies","id":"bonus","amount":60,"price":80,"locked":true,"sold":false},{"kind":"relic","id":"removed_relic"},{"kind":"hero","id":"removed_hero"},{"kind":"unit","id":"R3MIRAGE"},{"kind":"blueprint","id":"E1"}]
	for kit_cost in [0,1]:
		run.event={"choices":[{"cost":0,"item":{"kind":"supplies","amount":60}},{"cost":0,"kit_cost":kit_cost,"item":{"kind":"supplies","amount":100}}]}
		Market.normalize_shop(run)
		check(run.shop.is_empty(),"retired shelf entries still removed even when locked")
		check(run.event.choices[0].item.kind=="refresh_token" and run.event.choices[1].item.amount==100 and run.event.choices[1].kit_cost==kit_cost,"distinct event choices preserve exchange cost")
	var medical:=[{"cost":20,"item":{"kind":"repair_kit","id":"repair_kit"}}]
	Market.normalize_event_choices(medical)
	check(medical[0]==Market.medical_reward() and medical[0].cost==0,"old medical offer becomes free")
	var inventory:={"kits":0}
	Expedition.grant(inventory,medical[0].item)
	check(inventory.kits==2,"medical reward grants two kits")
	Expedition.grant(inventory,{"kind":"repair_kit"})
	check(inventory.kits==3,"individual purchase grants one kit")
	run.unit_growth.E1.def=4
	check(Market.growth_pool(run).size()==1,"one incomplete track remains eligible")
	for talent:String in Market.Army.Talents.options("E1"):
		run.get_or_add("native_levels",{}).get_or_add("E1",{})[talent]=3
	check(not Market.offer_available(run,{"kind":"native","id":"E1","rank":3}),"maxed talents unavailable")
	for item:Dictionary in Market.native_pool(run):check(item.kind!="native","maxed native not generated")
	print("SHOP_PRICING checks=",checks," failed=",failures)
	get_tree().quit(0 if failures==0 else 1)

func check_bulk_discounts() -> void:
	check(Expedition.start("美国","",5186) and Expedition.choose(0),"open bulk purchase camp")
	var run:=Expedition.state.duplicate(true)
	run.research.bargain=1
	run.shop=[{"kind":"buff","id":"armor","price":100,"sale_percent":20,"sold":false},{"kind":"buff","id":"health","price":120,"sale_percent":50,"sold":false},{"kind":"unit","id":"FV","price":35,"sale_percent":0,"sold":false}]
	run.supplies=60
	run.free_purchase_stage=run.stage
	check(Expedition.commit(run) and Expedition.lock_discounts(),"level one locks deals")
	check(Expedition.state.shop[0].locked and Expedition.state.shop[1].locked and not Expedition.state.shop[2].get("locked",false) and not Expedition.lock_discounts(),"only discounted shelf locked once")
	check(Expedition.plan_discount_purchases(Expedition.state.duplicate(true)).count==0,"level one has no bulk purchase")
	run=Expedition.state.duplicate(true)
	run.research.bargain=2
	check(Expedition.commit(run),"enable second level")
	var quote:=Expedition.plan_discount_purchases(Expedition.state.duplicate(true))
	check(quote.count==2 and quote.cost==60,"free first purchase then exact discount")
	var camp=load("res://scenes/expedition.tscn").instantiate()
	add_child(camp)
	camp.change_tab(1)
	var buttons:Array=camp.find_children("*","Button",true,false)
	var batch_index:=buttons.find_custom(func(b):return b.is_visible_in_tree() and b.text=="一键购买打折商品 · 2 件 · 60 补给")
	check(batch_index>=0,"shop presents exact batch cost and count")
	if batch_index>=0:
		var batch:Button=buttons[batch_index]
		check(not batch.disabled and batch.icon!=null,"batch has supply icon and is actionable")
		batch.pressed.emit()
	camp.free()
	check(Expedition.load_run(),"reload UI purchase")
	check(Expedition.state.supplies==0 and Expedition.state.shop[0].sold and Expedition.state.shop[1].sold and not Expedition.state.shop[2].sold and not Expedition.buy_discounts(quote),"only purchased deals charged once")

func check_shelf_discounts() -> void:
	check(Expedition.start("美国","",5186) and Expedition.choose(0),"open camp for discounts")
	var run:=Expedition.state.duplicate(true)
	var slots:={}
	var rates:={}
	var card=preload("res://scripts/expedition/shop_card.gd")
	for roll in 30:
		var stock:=Market.shop(run,roll)
		var ordinary:=0
		var distinct:={}
		for i in stock.size():
			var item:Dictionary=stock[i]
			if not item.discounted:continue
			slots[i]=true
			if item.kind in Market.TRAINING_KINDS:
				check(item.sale_percent in Market.TRAINING_DISCOUNTS,"training discount is at least half")
			else:
				ordinary+=1
				distinct[item.sale_percent]=true
				rates[item.sale_percent]=true
			check(card.discount_percent(item)==roundi(100.0*(item.original_price-item.price)/item.original_price),"badge matches actual rounded price")
		check(ordinary in [2,3] and distinct.size()==ordinary,"two or three separately priced regular offers on a full restock")
	check(slots.size()==Market.SHOP_SIZE and rates.size()==Market.STOCK_DISCOUNTS.size(),"discounts cover every slot and regular tier across restocks")
	var expanded:=run.duplicate(true)
	expanded.research={"supply":3}
	var extra_deal:=false
	for roll in 30:
		var stock:=Market.shop(expanded,roll)
		if stock.size()==7 and stock[6].discounted:
			extra_deal=true
			break
	check(extra_deal,"seventh researched shelf slot participates in discounts")
	var index:int=run.shop.find_custom(func(item):return item.kind not in Market.TRAINING_KINDS and item.discounted)
	check(index>=0,"opening store has regular discount")
	if index<0:return
	var deal:Dictionary=run.shop[index].duplicate(true)
	check(Expedition.lock_shop(index) and Expedition.refresh_shop() and Expedition.load_run(),"lock, refresh and reload discount")
	var locked:Dictionary=Expedition.state.shop[index]
	check(locked.id==deal.id and locked.sale_percent==deal.sale_percent and locked.price==deal.price,"locked deal retains actual price")
	var balance:int=Expedition.state.supplies
	check(Expedition.buy(index) and Expedition.state.supplies==balance-int(deal.price),"discounted regular item charges displayed price")
	run.shop=[{"kind":"unit","id":"MTNK","price":35,"locked":false},{"kind":"unit","id":"FV","price":35,"locked":true},{"kind":"training","id":"E1","price":12,"sold":true}]
	Market.normalize_shop(run,true)
	var saved:Array=run.shop.duplicate(true)
	Market.normalize_shop(run,true)
	check(run.shop==saved and run.shop[0].price<35 and run.shop[1].price==35 and run.shop[2].price==12,"old camp gains deals once; locked and sold prices survive")

func check_purchase_at_population_limit() -> void:
	check(Expedition.start("美国","",573) and Expedition.choose(0),"open camp for last population slots")
	var run:=Expedition.state.duplicate(true)
	run.survivors=[]
	run.special_squads=[]
	run.reinforcements=[{"id":"E1","count":8},{"id":"GGI","count":8},{"id":"MTNK","count":4},{"id":"FV","count":2}]
	run.supplies=500
	run.shop=[
		{"kind":"unit","id":"GHOST","price":35,"sale_percent":20,"sold":false,"locked":true},
		{"kind":"unit","id":"FV","price":35,"sale_percent":0,"sold":false,"locked":false},
		{"kind":"buff","id":"armor","price":120,"sale_percent":30,"sold":false,"locked":true},
		{"kind":"unit","id":"JUMPJET","price":35,"sale_percent":0,"sold":false,"locked":false},
		{"kind":"buff","id":"health","price":120,"sale_percent":0,"sold":false,"locked":false},
		{"kind":"trait_buff","id":"infantry","price":80,"sale_percent":0,"sold":false,"locked":false}
	]
	check(Expedition.commit(run) and Expedition.purchase_problem(Expedition.state,0).is_empty(),"neighbor available before last recruits")
	var before:Array=Expedition.state.shop.duplicate(true)
	check(Expedition.buy(1) and Expedition.state.supplies==465,"buy two vehicles into the last two places")
	var stock:Array=Expedition.state.shop
	check(stock.size()==before.size(),"another recruit stays in its slot when population fills")
	if stock.size()!=before.size():return
	check(stock[1].sold and stock[0].id==before[0].id and stock[0].price==before[0].price and stock[2]==before[2],"capped recruit and adjacent goods keep their positions")
	check(stock.slice(3)==before.slice(3) and Expedition.purchase_problem(Expedition.state,3).is_empty(),"another recruit can still join the reserves")
	check(stock[0].locked and Expedition.lock_shop(0) and not Expedition.state.shop[0].locked and Expedition.lock_shop(0),"full deployment retains locks on available recruits")
	check(not Expedition.buy(1) and Expedition.state.supplies==465,"a capped type cannot be purchased again")
	var expected:Dictionary=stock[0].duplicate(true)
	expected.fresh_stock=false
	for roll in [1,0]:
		var carried:=Market.shop(Expedition.state,roll)
		check(carried[0]==expected,"full-capacity locked card survives refresh and new shop")
	check(Expedition.load_run() and Expedition.state.shop==stock,"reload keeps the exact shelf")
	check(Expedition.dismiss("FV",1) and not Expedition.buy(1),"dismissing a unit does not reopen the recruit")

func check_special_recruits() -> void:
	check(Expedition.start("美国","",1414) and Expedition.choose(0),"open recruiting camp")
	var run:Dictionary=Expedition.state.duplicate(true)
	run.shop=[{"kind":"unit","id":"SREF","price":120,"locked":true,"sold":false},{"kind":"unit","id":"SREF","price":120,"sold":true}]
	run.event={"choices": [{"cost":60,"item":{"kind":"unit","id":"SREF"}}]}
	Market.normalize_shop(run)
	check(run.shop.size()==2 and run.shop[0].sold and not run.shop[0].locked and run.shop[1].sold and run.camp_recruits_bought==["SREF"],"legacy sold recruit closes prior duplicate and removes its lock")
	run.erase("camp_recruits_bought")
	check(run.event.choices[0].cost==30 and run.event.choices[0].label.contains("30"),"legacy discounted recruit matches displayed price")
	run.stage=16
	run.frozen.expedition_unlocked_talents={}
	run.frozen.unit_talents={}
	run.unit_growth.E1={"atk":0,"def":0}
	check(Market.special_price(run,"E1",3)==39,"five useful levels stay below manual refill")
	var item:=Market.special_item(run,"E1",2)
	check(item.kind=="special_unit" and item.price==37 and item.count==1,"tier II recruits one with a three-level floor for 37")
	run.unit_growth.E1={"atk":3,"def":2}
	check(Market.special_item(run,"E1",2).price==35,"one level of benefit costs 35")
	run.event={"choices":[{"item":item.duplicate(true),"cost":76,"label":"old"}]}
	Market.normalize_shop(run)
	var offer:Dictionary=run.event.choices[0]
	check(offer.cost==35 and offer.item.price==35 and offer.label.contains("35 补给"),"special hire label and cost follow actual gain")
	run.unit_growth.E1.def=3
	check(Market.special_item(run,"E1",2).kind=="unit","no effective stat gain returns ordinary recruit")
	run.unit_growth.E1.def=0
	run.frozen.expedition_unlocked_talents.E1=Market.Army.Talents.options("E1").keys()
	check(Market.special_item(run,"E1",2).kind=="unit","all talents unlocked even at rank zero suppress special recruit")
	run.shop=[item.duplicate(true)]
	run.shop[0].merge({"sold":false,"locked":true,"price":260},true)
	run.event={"choices":[{"item":item,"cost":120,"label":"old"}]}
	Market.normalize_shop(run)
	check(run.shop.size()==1 and not run.shop[0].locked and run.event.choices[0].item.kind=="supplies" and run.event.choices[0].cost==0,"obsolete special stays visible until refresh and event converts to supplies")
	check(Market.reward_item(run,item).kind=="supplies" and not Expedition.item_problem(run,item).is_empty(),"obsolete reward and purchase guarded")
	run.frozen.expedition_unlocked_talents.E1=[]
	run.event={}
	run.supplies=500
	run.unit_growth.E1={"atk":2,"def":1}
	run.reinforcements=[]
	run.survivors=[]
	run.special_squads=[]
	run.shop=[item.duplicate(true)]
	run.shop[0].merge({"price":260,"sold":false,"locked":true,"quality":2},true)
	check(Expedition.commit(run) and Expedition.load_run() and Expedition.state.shop[0].price==36,"current camp reprices existing locked stock on disk")
	check(Expedition.buy(0) and Expedition.state.supplies==464 and Expedition.state.special_squads.back().tier==2,"shop charges the displayed price for one tier II recruit")
	check(not Expedition.buy(0) and Expedition.state.supplies==464 and Expedition.state.special_squads.size()==1,"same special card cannot hire again")
	var quantity:=Market.Army.quantity(Expedition.state,"E1")
	check(Expedition.service("refill","E1") and Market.Army.quantity(Expedition.state,"E1")>quantity and Expedition.state.special_squads.size()==1,"ordinary refill service still recruits regular forces")

func check_targeted_recruits() -> void:
	check(Expedition.start("美国","",1414) and Expedition.choose(0),"open separate camp for cross-card limit")
	var run:Dictionary=Expedition.state.duplicate(true)
	run.stage=11
	run.supplies=1000
	run.reinforcements=[]
	run.survivors=[]
	run.special_squads=[]
	if "SREF" not in run.catalog:run.catalog.append("SREF")
	run.tracked_traits=Market.Army.tags("SREF",run).slice(0,2)
	var card:={"kind":"unit","id":"SREF","price":35,"sold":false,"locked":true,"targeted":true}
	var alternate:={"kind":"special_unit","id":"SREF","tier":2,"count":1,"price":35,"sold":false,"locked":true}
	var legacy:=run.duplicate(true)
	legacy.targeted_recruits_bought=["SREF"]
	legacy.shop=[alternate.duplicate(true)]
	Market.normalize_shop(legacy)
	check(legacy.camp_recruits_bought==["SREF"] and legacy.shop[0].sold and not legacy.shop[0].locked,"old targeted history blocks alternate stock")
	card.sale_percent=20
	alternate.sale_percent=20
	run.research.bargain=2
	run.shop=[card.duplicate(true),alternate.duplicate(true)]
	var committed:=Expedition.commit(run)
	var quote:=Expedition.plan_discount_purchases(Expedition.state.duplicate(true))
	check(committed and quote.count==1,"bulk discount quote cannot include two forms of the same recruit")
	var purchased:=committed and Expedition.buy_discounts(quote)
	check(purchased,"targeted prism tank can be bought once: "+Expedition.error)
	if not purchased:return
	var saved:Dictionary=Expedition.state.duplicate(true)
	check(saved.shop[0].sold and not saved.shop[0].locked and saved.camp_recruits_bought==["SREF"] and Market.Army.quantity(saved,"SREF")==1,"targeted purchase records one tank and closes its card")
	check(not Expedition.buy(0) and not Expedition.can_lock_shop(0) and not Expedition.buy(1) and not Expedition.can_lock_shop(1) and saved.shop[1].sold and Expedition.state==saved,"repeat click, alternate tier or lock cannot spend or recruit")
	check(Expedition.load_run() and not Expedition.buy(0) and Expedition.state.shop[0].sold,"reloading does not reopen a sold targeted card")
	var unblocked:=false
	var control:Dictionary=Expedition.state.duplicate(true)
	control.erase("camp_recruits_bought")
	control.shop=[]
	var no_repeat:=true
	for roll in range(1,16):
		unblocked=Market.shop(control,roll).any(func(item):return Market.is_recruit(item) and item.id=="SREF") or unblocked
		var refreshed:=Expedition.refresh_shop()
		no_repeat=refreshed and not Expedition.state.shop.any(func(item):return Market.is_recruit(item) and item.id=="SREF") and no_repeat
	check(unblocked,"without purchase history the same seed can draw a targeted prism tank")
	check(no_repeat and Expedition.load_run() and Expedition.state.get("camp_recruits_bought",[])==["SREF"],"fifteen refreshes and reload preserve the targeted limit despite room")
	var next:Dictionary=Expedition.state.duplicate(true)
	next.stage+=1
	Expedition.ready(next)
	check(not next.has("camp_recruits_bought"),"new camp resets the recruitment purchase history")
	next.shop=[card.duplicate(true)]
	check(Expedition.commit(next) and Expedition.buy(0) and Market.Army.quantity(Expedition.state,"SREF")==2,"the same targeted recruit is eligible in a new camp")

func check_recruit_weights() -> void:
	for kind in ["unit","special_unit","reinforce"]:
		check(Market.draw_weight({"kind":kind,"id":"R3MIRAGE"})==0.5,"RA3 recruitment weight for "+kind)
		check(Market.draw_weight({"kind":kind,"id":"MGTK"})==1.0,"original mirage tank recruitment weight for "+kind)
	check(Market.draw_weight({"kind":"training","id":"R3APOC"})==1.0,"owned RA3 training uses normal weight")
	check(Market.draw_weight({"kind":"relic","id":"chrono_anchor"})==0.15,"legendary relic uses its configured weight")
	var only_ra3:=[{"kind":"special_unit","id":"R3TESLA","tier":2}]
	check(Market.choose_from(only_ra3,Market.rng({"seed":7,"stage":14},"reward"))==only_ra3[0],"a sole eligible RA3 recruit can still appear")

func check_camp_audio() -> void:
	check(Expedition.start("美国","",801) and Expedition.choose(0),"open the expedition shop")
	Ra2Sfx.stop_all()
	var plays:=Ra2Sfx.a_plays
	for i in Expedition.state.shop.size():Expedition.lock_shop(i)
	var locked:=Expedition.state.duplicate(true)
	check(Expedition.refresh_slots()==0 and not Expedition.refresh_shop() and Expedition.state==locked and Ra2Sfx.a_plays==plays,"full lock spends neither free refresh nor supplies")
	Expedition.lock_shop(2)
	check(Expedition.refresh_slots()==1,"only unlocked slot will roll")
	for price in [0,10]:
		check(Expedition.refresh_price()==price and Expedition.refresh_shop(),"refresh accepted at "+str(price))
		plays+=1
		check(Ra2Sfx.a_plays==plays and last_sound()=="ucredup.wav","one coin sound per refresh")
	var next:=Expedition.state.duplicate(true)
	next.supplies=0
	Expedition.commit(next)
	check(not Expedition.refresh_shop() and Ra2Sfx.a_plays==plays,"unaffordable refresh is silent")
	for stacks in [1,2,5,8]:
		next=Expedition.state.duplicate(true)
		next.trait_buffs.infantry=stacks
		next.shop=[{"kind":"trait_buff","id":"infantry","price":80,"sold":false,"locked":false}]
		next.supplies=80
		Expedition.commit(next)
		check(Expedition.buy(0),"purchase at "+str(stacks)+" stacks")
		plays+=1
		check(Ra2Sfx.a_plays==plays and last_sound()=="ubonus_shop_1s.wav","single money crate cue on purchase at "+str(stacks+1))
		var stream:=Ra2Sfx._global_pool[posmod(Ra2Sfx._global_cursor-1,Ra2Sfx.POOL_SIZE)].stream
		check(stream!=null and is_equal_approx(stream.get_length(),1.0),"purchase plays exactly one second")
		check(not Expedition.buy(0) and Expedition.load_run() and Ra2Sfx.a_plays==plays,"sold item and reload are silent")
	next=Expedition.state.duplicate(true)
	next.trait_buffs.infantry=5
	next.phase="reward"
	next.offers=[{"kind":"trait_buff","id":"infantry"}]
	Expedition.commit(next)
	check(Expedition.choose(0) and Ra2Sfx.a_plays==plays+1 and last_sound()=="ubonus.wav","reward milestone plays only bonus")

func last_sound() -> String:
	var index:=posmod(Ra2Sfx._global_cursor-1,Ra2Sfx.POOL_SIZE)
	var stream:=Ra2Sfx._global_pool[index].stream
	return stream.resource_path.get_file() if stream!=null else ""
