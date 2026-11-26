extends RefCounted

const Book=preload("res://scripts/units/yuriko_school.gd")
const GIFTS:={
	"cola":{
		"name":"玻璃瓶可乐","icon":"yuriko_cola",
		"first":"百合子把冰凉的瓶子贴了贴脸。「先别走。瓶盖我会开，可我想跟你碰一下瓶子。」",
		"again":"她熟练地起开瓶盖，递给你一杯。「今天这半瓶归你。」"
	},
	"uniform":{
		"name":"南汐高中制服","icon":"yuriko_uniform",
		"first":"她先去摸袖口的线脚，再把校徽端端正正地翻过来。「原来你还记得我念哪所学校。下次开放日，记得来认人。」",
		"again":"「这一套我可以带去给转来的同学。上回领制服的时候，有人记得我的尺码，我想她也能有一次。」"
	},
	"ticket":{
		"name":"旧电车纪念票","icon":"yuriko_ticket",
		"first":"她把票套举向灯光，让你看中间透亮的小孔。「这站我认得。下次路过，我请你下车吃点东西。」",
		"again":"她把两张票并在一起。「一张给去程，一张给回来。」"
	}
}
static var stories:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/yuriko_side_letters.json"))

static func attach(objectives:Array,fragment:=0) -> void:
	# A single ordinary ground-squad objective carries the finds for this battle.
	for i in range(objectives.size()-1,-1,-1):
		var o:Dictionary=objectives[i]
		if o.kind not in ["contact","intel","cache","box"]:continue
		var receipts:Dictionary=MetaProgress.yuriko_school.get("field_receipts",{})
		o.school_gift=GIFTS.keys()[receipts.size()%GIFTS.size()]
		o.school_fragment=fragment
		if fragment>0:o.school_gift=""
		return

static func loot_text(o:Dictionary) -> String:
	var gift:String=GIFTS[o.school_gift].name+"、日常日记 ×1" if GIFTS.has(o.school_gift) else ""
	for story:Dictionary in stories:
		if int(story.fragment)==int(o.school_fragment):return "破碎残章《%s》"%story.title+("、"+gift if not gift.is_empty() else "")
	return gift

static func settle(run:Dictionary,field:Dictionary,report:Dictionary) -> void:
	var reward:Dictionary={}
	if field.get("shelter_heard",false):reward.page=1
	if field.get("archive_taken",false):reward.page=int(field.archive_page)
	for o:Dictionary in field.get("objectives",[]):
		if not o.get("done",false) or o.get("failed",false) or not o.has("school_gift"):continue
		if GIFTS.has(o.school_gift):
			reward.daily_diaries=1
			reward.gift=o.school_gift
		reward.fragment=o.school_fragment
		report.school_loot=loot_text(o)
		if reward.has("daily_diaries") and field.has("school_page"):reward.page=field.school_page
		break
	var finds:Dictionary=field.get("school_finds",{})
	var names:PackedStringArray=[]
	if finds.get("diary",{}).get("taken",false):
		reward.daily_diaries=1
		reward.gift=finds.diary.gift
		names.append("日常日记 ×1、"+str(GIFTS[reward.gift].name))
		if reward.has("daily_diaries") and field.has("school_page"):reward.page=field.school_page
	if field.has("school_extra_fragment") or finds.get("fragment",{}).get("taken",false):
		reward.fragment=field.school_extra_fragment if field.has("school_extra_fragment") else finds.fragment.fragment
		for story:Dictionary in stories:
			if int(story.fragment)==int(reward.fragment):names.append("破碎残章《%s》"%story.title)
	if not names.is_empty():report.school_loot="、".join(names)
	if reward.is_empty():return
	var key:="%s/%d"%[run.id,run.stage]
	run.get_or_add("school_deliveries",{})[key]=reward
	if reward.has("page"):report.school_page=reward.page

static func deliver(run:Dictionary) -> bool:
	var state:=MetaProgress.yuriko_school
	var deliveries:Dictionary=run.get("school_deliveries",{})
	var next:Dictionary
	if run.get("yuriko_recruited",false) and not state.get("recruited_before",false):
		next=state.duplicate(true)
		next.recruited_before=true
	for key:String in deliveries:
		if state.get("claimed_school",{}).has(key):continue
		if next.is_empty():next=state.duplicate(true)
		var gift:Dictionary=deliveries[key]
		next.get_or_add("claimed_school",{})[key]=true
		if gift.has("daily_diaries"):next.daily_diaries=int(next.get("daily_diaries",0))+int(gift.daily_diaries)
		if gift.has("gift"):
			next.get_or_add("field_receipts",{})[key]=gift.gift
			var bag:Dictionary=next.get_or_add("gifts",{})
			bag[gift.gift]=int(bag.get(gift.gift,0))+1
		if int(gift.get("fragment",0))>0:next.get_or_add("fragments",{})[str(int(gift.fragment))]=true
		if gift.has("page"):next.pages=maxi(int(next.get("pages",0)),int(gift.page))
	return next.is_empty() or Book.commit(next)

const BASE_GIFT_PRICE:=500
# Change in strategic cores -> number of outcomes in one hundred.
# Premiums and discounts each contribute 500 cores in total, keeping the mean at 500.
const PRICE_CHANGE_WEIGHTS:={
	1:38, 2:33, 3:12, 5:6, 10:3, 20:1, 30:1, 250:1,
	-50:1, -75:1, -100:1, -125:1, -150:1,
}

static func price_from_roll(ticket:int) -> int:
	for change:int in PRICE_CHANGE_WEIGHTS:
		var weight:int=PRICE_CHANGE_WEIGHTS[change]
		if ticket<weight:return BASE_GIFT_PRICE+change
		ticket-=weight
	assert(false,"Gift price weights must cover the daily draw")
	return BASE_GIFT_PRICE

const REFRESH_COSTS:=[0,10,10,20,20,20,30,30,30,50,50,50,50,50,50]

static func refresh_count(day:String) -> int:
	var state:=MetaProgress.yuriko_school
	if state.get("gift_refresh_day","")!=day:return 0
	return maxi(0,int(state.get("gift_refresh_count",0)))

static func refresh_cost(count:int) -> int:
	return REFRESH_COSTS[count] if count<REFRESH_COSTS.size() else 100

static func reroll_gifts(day:String,quoted_count:int) -> String:
	if not Book.met():return "礼物商店尚未开放。"
	if day!=Time.get_date_string_from_system() or quoted_count!=refresh_count(day):
		return "礼物报价已更新，请查看当前价格。"
	var cost:=refresh_cost(quoted_count)
	var funds:=MetaProgress.balance("cores")
	if funds<cost:return "战略核心不足。"
	var next:=MetaProgress.yuriko_school.duplicate(true)
	next.gift_refresh_day=day
	next.gift_refresh_count=quoted_count+1
	MetaProgress.currency.cores=funds-cost
	if not Book.commit(next):
		MetaProgress.currency.cores=funds
		return "刷新未保存，请重试。"
	Events.meta_changed.emit()
	return ""

static func gift_price(id:String,day:String) -> int:
	var roll:=RandomNumberGenerator.new()
	var count:=refresh_count(day)
	var key:="yuriko/gift/"+day+"/"+id
	if count>0:key+="/"+str(count)
	roll.seed=key.hash()
	return price_from_roll(roll.randi_range(0,99))

static func buy_gift(id:String,quoted_day:String,quoted_count:int=0) -> String:
	if not GIFTS.has(id) or not Book.met():return "礼物商店尚未开放。"
	var today:=Time.get_date_string_from_system()
	if quoted_day!=today or quoted_count!=refresh_count(today):return "今日价格已更新，请按新价购买。"
	var price:=gift_price(id,today)
	var funds:=MetaProgress.balance("cores")
	if funds<price:return "战略核心不足。"
	var next:=MetaProgress.yuriko_school.duplicate(true)
	var bag:Dictionary=next.get_or_add("gifts",{})
	bag[id]=int(bag.get(id,0))+1
	MetaProgress.currency.cores=funds-price
	if not Book.commit(next):
		MetaProgress.currency.cores=funds
		return "购买未保存，请重试。"
	Events.meta_changed.emit()
	return ""

static func give(id:String) -> String:
	var next:=MetaProgress.yuriko_school.duplicate(true)
	var bag:Dictionary=next.get("gifts",{})
	if not Book.met() or not GIFTS.has(id) or int(bag.get(id,0))<1:return ""
	var given:Dictionary=next.get_or_add("given",{})
	var first:=not given.has(id)
	bag[id]=int(bag[id])-1
	given[id]=int(given.get(id,0))+1
	Book.add_affinity(next,2 if first else 1)
	if not Book.commit(next):return ""
	return GIFTS[id].first if first else GIFTS[id].again

static func gm_unlock() -> String:
	var next:=MetaProgress.yuriko_school.duplicate(true)
	next.gm_open=true
	if not Book.commit(next):return "百合子解锁未保存。"
	var rules=preload("res://scripts/expedition/rules.gd")
	if rules.active():rules.context().yuriko_recruited=true
	Events.meta_changed.emit()
	return "百合子栏目、主线、残章与远征召唤已解锁。"
