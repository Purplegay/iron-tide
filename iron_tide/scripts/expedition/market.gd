extends RefCounted
const SHOP_SIZE:=6
const UNIT_PRICE:=35
const EVENT_UNIT_PRICE:=30
const Army=preload("res://scripts/expedition/army.gd")
const Campaign=preload("res://scripts/expedition/campaign.gd")
const Growth=preload("res://scripts/expedition/growth.gd")
const Relics=preload("res://scripts/expedition/relics.gd")
const QUALITIES := [[70,30,0,0],[50,40,10,0],[30,45,25,0],[15,40,35,10],[0,30,45,25],[0,20,40,40]]
const NATIVE_PRICES := [100,80,120,180]
const TRAINING_KINDS := ["training","native","specialization"]
const TRAINING_DISCOUNTS := [50,60,70]
const STOCK_DISCOUNTS := [20,30,40,50]
const RA3_RECRUIT_WEIGHT := 0.5
const EVENT_NAMES := ["军火拍卖","伤员转移","旧工厂","战地实验室","情报交易","失联小队","佣兵营地","过载电站","军医交换","训练教官"]

static func rng(run:Dictionary,salt:String) -> RandomNumberGenerator:
	var result:=RandomNumberGenerator.new()
	result.seed=hash(str(run.seed)+":"+str(run.stage)+":"+salt)
	return result

static func talent_item(run:Dictionary,id:String) -> Dictionary:
	if Army.Talents.options(id).is_empty():return {}
	var rank:=Army.native_rank(run,id)
	if rank>=3:
		if Campaign.chapter(int(run.stage))<3 or run.specializations.has(id) or id not in ["E1","GGI","DESO","SCHP"]:return {}
		return {"kind":"specialization","id":id,"branch":"a","price":200}
	var next:=rank+1
	return {"kind":"native","id":id,"rank":next,"talent_targets":Army.Talents.targets(run,id),"price":NATIVE_PRICES[next]}

static func unit_pool(run:Dictionary) -> Array:
	var result:Array=[]
	for id:String in run.catalog:
		if id.begins_with("R3"):continue
		var row:=GameData.get_unit(id)
		if id in ["AMCV","SMCV","CMIN","HARV"]:continue
		if float(row.get("cost",0))>[1200,1800,2500,100000,100000,100000][Campaign.chapter(int(run.stage))]:continue
		if int(run.stage)<6 and GameData.unit_production_category(row) in ["air","naval"]:continue
		result.append({"kind":"unit","id":id,"price":UNIT_PRICE})
	return result

static func offer_available(run:Dictionary,item:Dictionary) -> bool:
	if str(item.get("id","")).begins_with("R3"):return false
	match str(item.kind):
		"blueprint":return false
		"unit":return true
		"reinforce":return Army.room(run,item.id)>0
		"special_unit":return special_useful(run,item.id,int(item.tier))
		"buff":return int(run.buffs.get(item.id,0))<3
		"trait_buff":return int(run.get("trait_buffs",{}).get(item.id,0))<9
		"training":return Growth.can_upgrade(run,item.id)
		"native":return Army.Talents.can_gain(run,item)
		"specialization":return not run.specializations.has(item.id)
		"relic":return Relics.can_gain(run,item.id)
		"hero":
			var heroes=preload("res://scripts/expedition/heroes.gd")
			return item.id in heroes.available(run)
	return true

static func reward_item(run:Dictionary,item:Dictionary) -> Dictionary:
	return item if offer_available(run,item) else {"kind":"supplies","id":"bonus","amount":100,"converted":true}

static func recruit_fits(run:Dictionary,item:Dictionary) -> bool:
	match item.kind:
		"unit":return Army.room(run,item.id)>=preload("res://scripts/expedition/catalog.gd").squad_size(item.id)
		"special_unit":return Army.room(run,item.id)>=int(item.get("count",1))
	return true

static func lock_available(run:Dictionary,item:Dictionary) -> bool:
	if item.get("sold",false) or item.kind=="supplies" or not recruit_fits(run,item):return false
	match item.kind:
		"unit","reinforce":return true
		"special_unit":return special_useful(run,item.id,int(item.tier))
	return offer_available(run,item)

static func keep_locked(run:Dictionary,item:Dictionary) -> bool:
	return item.get("locked",false) and lock_available(run,item)

static func buff_pool(run:Dictionary) -> Array:
	var result:Array=[]
	var catalog=load("res://scripts/expedition/catalog.gd")
	for id:String in catalog.BUFFS:
		if int(run.buffs.get(id,0))>=3 or int(run.get("stage",1))<int(catalog.BUFFS[id].get("min_stage",1)):continue
		var category:String=catalog.BUFFS[id].group
		if category!="all" and not catalog.has_group(run,category):continue
		result.append({"kind":"buff","id":id,"levels":1,"price":180 if catalog.BUFFS[id].get("core",false) else 120})
	return result

static func native_pool(run:Dictionary) -> Array:
	var result:Array=[]
	for id:String in run.licenses:
		var item:=talent_item(run,id)
		if not item.is_empty() and offer_available(run,item):result.append(item)
	return result

static func trait_pool(run:Dictionary) -> Array:
	var result:Array=[]
	var available:Array=[]
	for id:String in run.licenses:
		for tag:String in Army.tags(id,run):
			if tag not in available:available.append(tag)
	for key:String in available:
		if int(run.get("stage",1)) < int(Army.TRAITS[key].get("min_stage",1)):continue
		if int(run.get("trait_buffs",{}).get(key,0))<9:
			result.append({"kind":"trait_buff","id":key,"levels":1,"price":80})
	return result

static func bonus_rewards(run:Dictionary) -> Array:
	var random:=rng(run,"bonus_trait_reward:"+str(run.get("reward_round","buff")))
	var traits:=trait_pool(run)
	var result:Array=[]
	# Keep both marked directions available so a focused build can reach nine stacks.
	for key:String in run.tracked_traits:
		for item:Dictionary in traits.duplicate():
			if item.id==key:result.append(item);traits.erase(item);break
	while result.size()<2 and not traits.is_empty():
		result.append(traits.pop_at(random.randi_range(0,traits.size()-1)))
	var pool:Array=buff_pool(run)+traits+relic_pool(run)
	while result.size()<Relics.reward_choices(run) and not pool.is_empty():
		var picked:=choose_from(pool,random)
		result.append(picked)
		pool.erase(picked)
	var candidates:=trait_pool(run).filter(func(it):return int(run.get("trait_buffs",{}).get(it.id,0)) in range(1,9))
	if not candidates.is_empty() and random.randf()<0.12:
		var preferred:=candidates.filter(func(it):return int(run.trait_buffs[it.id])<=7)
		if not preferred.is_empty():candidates=preferred
		var first:=random.randi_range(0,candidates.size()-1)
		for n in mini(2,candidates.size()):
			var manual:Dictionary=candidates[(first+n)%candidates.size()].duplicate()
			manual.manual=true;manual.levels=mini(2,9-int(run.trait_buffs[manual.id]))
			result=result.filter(func(it):return it.kind!="trait_buff" or it.id!=manual.id)
			result.append(manual)
	return result if not result.is_empty() else [{"kind":"supplies","id":"bonus","amount":100}]

static func relic_pool(run:Dictionary) -> Array:
	var result:Array=[]
	var units:Array=run.licenses.duplicate()
	for squad:Dictionary in run.get("special_squads",[]):
		if squad.id not in units:units.append(squad.id)
	for id:String in Relics.ITEMS:
		if Relics.grade(id)=="典藏":continue
		if not Relics.can_gain(run,id):continue
		var row:Dictionary=Relics.ITEMS[id]
		if int(run.stage)<int(row.get("min_stage",1)):continue
		var available:bool=not row.has("units") and not row.has("tag")
		for unit_id:String in units:
			if Relics.applies(id,unit_id,Army.tags(unit_id,run)):available=true;break
		if available:result.append({"kind":"relic","id":id,"price":int(row.price)})
	return result

static func ultimate_pool(pool:Array) -> Array:
	var result:Array=[]
	for item:Dictionary in pool:
		if item.kind=="relic" and Relics.ITEMS[item.id].family=="究极构筑":result.append(item)
	return result

static func without_relics(pool:Array,excluded:Array) -> Array:
	var result:Array=[]
	for item:Dictionary in pool:
		if item.kind!="relic" or item.id not in excluded:result.append(item)
	return result

static func shop_key(item:Dictionary) -> String:
	var key:=str(item.get("kind",""))+":"+str(item.get("id",""))
	if item.kind=="native":key+=":"+str(item.get("rank",0))
	elif item.kind=="special_unit":key+=":"+str(item.get("tier",0))
	return key

static func growth_pool(run:Dictionary) -> Array:
	var result:Array=[]
	for id:String in run.licenses:
		if Growth.can_upgrade(run,id):result.append({"kind":"training","id":id,"price":Growth.PRICE})
	return result

static func item_grade(run:Dictionary,item:Dictionary) -> String:
	if item.kind=="relic":return Relics.grade(item.id)
	if item.get("manual",false) or int(item.get("levels",1))>=2:return "史诗"
	var grades:=["普通","优质","稀有","史诗"]
	if item.has("quality"):return grades[clampi(int(item.quality),0,3)]
	if item.kind=="special_unit":return grades[clampi(int(item.tier),0,3)]
	if item.kind=="hero":return "传说"
	if item.kind in ["supplies","repair_kit","empty"]:return "普通"
	# Old and new reward offers share a private deterministic roll. Never consume the loot RNG.
	var salt:="offer_grade:%s:%s"%[item.kind,item.id]
	return grades[quality(run,rng(run,salt))]

static func quality(run:Dictionary,random:RandomNumberGenerator) -> int:
	var roll:=random.randi_range(1,100)
	var total:=0
	for i in 4:
		total+=int(QUALITIES[Campaign.chapter(int(run.stage))][i])
		if roll<=total:return i
	return 0

static func special_gain(run:Dictionary,id:String,tier:int) -> int:
	var gain:=0
	for track:String in Growth.TRACKS:
		gain=maxi(gain,Growth.special_level(tier)-Growth.level(run,id,track))
	return gain

static func special_useful(run:Dictionary,id:String,tier:int) -> bool:
	return not Army.Talents.all_unlocked(run,id) and special_gain(run,id,tier)>0

static func special_price(run:Dictionary,id:String,tier:int) -> int:
	return UNIT_PRICE + maxi(0, special_gain(run,id,tier) - 1)

static func special_item(run:Dictionary,id:String,level:int) -> Dictionary:
	var rank:=clampi(level,1,3)
	if Campaign.chapter(int(run.stage))<3:rank=mini(rank,2)
	if Campaign.chapter(int(run.stage))<1:rank=1
	if not special_useful(run,id,rank):return {"kind":"unit","id":id,"price":UNIT_PRICE}
	return {"kind":"special_unit","id":id,"tier":rank,"native_rank":-1,"count":1,"price":special_price(run,id,rank)}

static func choose_from(pool:Array,random:RandomNumberGenerator) -> Dictionary:
	if pool.is_empty():return {"kind":"empty","id":""}
	return pool[draw_index(pool,random)].duplicate(true)

static func draw_weight(item:Dictionary) -> float:
	if item.kind=="relic":return maxf(0.01,float(Relics.ITEMS.get(item.id,{}).get("drop_weight",1.0)))
	if item.kind in ["unit","special_unit","reinforce"] and str(item.id).begins_with("R3"):return RA3_RECRUIT_WEIGHT
	return 1.0

static func draw_index(pool:Array,random:RandomNumberGenerator) -> int:
	var total:=0.0
	for item:Dictionary in pool:total+=draw_weight(item)
	var roll:=random.randf()*total
	for i in pool.size():
		roll-=draw_weight(pool[i])
		if roll<0.0:return i
	return pool.size()-1

static func shop(run:Dictionary,refresh:int) -> Array:
	var random:=rng(run,"market_"+str(refresh))
	var catalog_units:=unit_pool(run)
	var units:=catalog_units.filter(func(item):return recruit_fits(run,item))
	var buffs:=buff_pool(run)+trait_pool(run)+relic_pool(run)
	var native:=native_pool(run)
	var result:Array=[]
	var reserved:Array=[]
	var reserved_items:={}
	for old:Dictionary in run.get("shop",[]):
		if keep_locked(run,old):
			reserved_items[shop_key(old)]=true
			if old.kind=="relic":reserved.append(old.id)
	for index in SHOP_SIZE+int(preload("res://scripts/expedition/research.gd").rank(run,"supply")>=3):
		var rarity:=quality(run,random)
		var slot_units:=units
		if index in [1,5] and rarity>=2:
			slot_units=[]
			for unit:Dictionary in catalog_units:
				var recruit:=special_item(run,unit.id,rarity)
				if recruit_fits(run,recruit):slot_units.append(recruit)
		var pool:Array=slot_units if index in [0,1] else native if index==2 else buffs if index==3 else slot_units+buffs+native
		# A dedicated relic slot makes build-defining finds frequent enough to pursue.
		if index==5 and not without_relics(relic_pool(run),reserved).is_empty():pool=relic_pool(run)
		pool=without_relics(pool,reserved)
		pool=unique_shop_pool(pool,reserved_items)
		if index==5 and refresh==0 and not ultimate_pool(pool).is_empty():pool=ultimate_pool(pool)
		if pool.is_empty():pool=unique_shop_pool(slot_units+buffs+native+growth_pool(run),reserved_items)
		var item:=choose_from(pool,random)
		if item.kind=="relic":reserved.append(item.id)
		if item.kind!="supplies":reserved_items[shop_key(item)]=true
		item.quality=rarity
		item.sold=false
		item.locked=false
		result.append(item)
	# Guarantee a useful selection, and bias one slot toward the player's declared build.
	var wanted:Array=run.get("tracked_traits",[])
	var matches:Array=[]
	var other_shop_items:={}
	for index in result.size():
		if index!=4 and result[index].kind!="supplies":other_shop_items[shop_key(result[index])]=true
	for item:Dictionary in units:
		if other_shop_items.has(shop_key(item)):continue
		for tag:String in Army.tags(item.id,run):
			if tag in wanted:matches.append(item);break
	if not matches.is_empty():
		var targeted:=choose_from(matches,random)
		targeted.merge({"quality":1,"sold":false,"locked":false,"targeted":true})
		result[4]=targeted
	var growth:=growth_pool(run)
	var growth_available:Array=[]
	for item:Dictionary in growth:
		if item.id!=result[0].get("id","") and item.id!=result[1].get("id","") and item.id!=result[3].get("id","") and item.id!=result[4].get("id","") and item.id!=result[5].get("id",""):growth_available.append(item)
	if not growth_available.is_empty() and native.is_empty():
		result[2]=choose_from(growth_available,random)
		result[2].merge({"quality":0,"sold":false,"locked":false})
	# Restore locked stock first, then remove duplicates without losing item metadata.
	if refresh==0:
		var lock_slot:=0
		for old:Dictionary in run.get("shop",[]):
			if keep_locked(run,old) and lock_slot<result.size():result[lock_slot]=old.duplicate(true);lock_slot+=1
	else:
		for index in mini(SHOP_SIZE+int(preload("res://scripts/expedition/research.gd").rank(run,"supply")>=3),run.shop.size()):
			if keep_locked(run,run.shop[index]):result[index]=run.shop[index].duplicate(true)
	var seen:={}
	for index in result.size():
		var item:Dictionary=result[index]
		if item.kind=="supplies":continue
		var key:=shop_key(item)
		if seen.has(key):
			var replacement_pool:=units.duplicate()
			if item.kind=="trait_buff":replacement_pool=buffs.duplicate()
			elif item.kind=="native":replacement_pool=native.duplicate()
			var replacement:=unique_shop_pool(replacement_pool,seen)
			if replacement.is_empty():item={"kind":"empty","id":""}
			else:
				item=choose_from(replacement,random)
				var replacement_quality:=quality(run,random)
				if index in [1,5] and item.kind=="unit" and replacement_quality>=2:item=special_item(run,item.id,replacement_quality)
				item.quality=replacement_quality
				item.sold=false;item.locked=false
			result[index]=item
			key=shop_key(item)
		seen[key]=true
	result=result.filter(func(item):return item.kind not in ["empty","supplies"])
	roll_shop_prices(result,rng(run,"shop_discounts_"+str(refresh)))
	for item:Dictionary in result:
		item.fresh_stock = refresh > 0 and not item.get("locked", false)
	return result

static func unique_shop_pool(pool:Array,reserved:Dictionary) -> Array:
	var result:Array=[]
	for item:Dictionary in pool:
		if reserved.has(shop_key(item)):continue
		result.append(item)
	return result

static func roll_shop_prices(stock:Array,random:RandomNumberGenerator) -> void:
	var candidates:Array[Dictionary]=[]
	var ordinary_deals:=random.randi_range(2,3)
	for item:Dictionary in stock:
		if item.get("sold",false):continue
		var training:bool=item.kind in TRAINING_KINDS
		if not item.has("sale_percent"):
			item.sale_percent=50 if training else 0
			if not item.get("locked",false):
				if training:item.sale_percent=TRAINING_DISCOUNTS[random.randi_range(0,TRAINING_DISCOUNTS.size()-1)]
				elif int(item.get("price",0))>1:candidates.append(item)
		if not training and int(item.sale_percent)>0:ordinary_deals-=1
	var tiers:=STOCK_DISCOUNTS.duplicate()
	for i in mini(ordinary_deals,candidates.size()):
		var item:Dictionary=candidates.pop_at(random.randi_range(0,candidates.size()-1))
		item.sale_percent=tiers.pop_at(random.randi_range(0,tiers.size()-1))
	for item:Dictionary in stock:apply_shop_price(item)

static func apply_shop_price(item:Dictionary) -> void:
	if item.get("sold",false):return
	var base:=int(item.get("original_price",item.get("price",0)))
	match item.kind:
		"unit":base=UNIT_PRICE
		"training":base=Growth.PRICE
		"native":base=int(NATIVE_PRICES[clampi(int(item.get("rank",1)),0,3)])
		"specialization":base=200
	var rate:=int(item.get("sale_percent",50 if item.kind in TRAINING_KINDS else 0))
	item.original_price=base
	item.discounted=rate>0 and base>1
	item.price=maxi(1,floori(base*(100-rate)/100.0)) if item.discounted else base

static func normalize_shop(run:Dictionary,upgrade_saved_prices:=false) -> void:
	var stock:Array=[]
	for item:Dictionary in run.get("shop",[]):
		if not item.get("sold",false):
			if item.kind in ["supplies","blueprint"] or str(item.id).begins_with("R3") or not recruit_fits(run,item):continue
			if item.kind=="relic" and not Relics.ITEMS.has(item.id):continue
			if item.kind=="hero" and not MetaProgress.Academy.HEROES.has(item.id):continue
			if not lock_available(run,item):
				item.locked=false
			elif item.kind=="special_unit":
				item.original_price=special_price(run,item.id,int(item.tier))
		stock.append(item)
	if upgrade_saved_prices and stock.any(func(item):return not item.get("sold",false) and not item.has("sale_percent")):
		roll_shop_prices(stock,rng(run,"shop_discounts_"+str(run.get("shop_roll",0))))
	else:
		for item:Dictionary in stock:apply_shop_price(item)
	run.shop=stock
	for choice:Dictionary in run.get("event",{}).get("choices",[]):
		if choice.item.kind!="special_unit":continue
		if not offer_available(run,choice.item):
			choice.merge({"label":"转领补给 · 获得 100 补给","cost":0,"item":{"kind":"supplies","id":"bonus","amount":100}},true)
		else:
			choice.cost=special_price(run,choice.item.id,int(choice.item.tier))
			choice.item.price=choice.cost
			choice.label="精锐雇佣 · %d 补给，%s"%[choice.cost,title(choice.item)]

	normalize_event_choices(run.get("event",{}).get("choices",[]))

static func medical_reward() -> Dictionary:
	return {"label":"医疗物资 · 获得 2 个维修包","cost":0,"item":{"kind":"repair_kit","id":"repair_kit","amount":2}}

static func normalize_event_choices(choices:Array) -> void:
	for i in choices.size():
		var choice:Dictionary=choices[i]
		if choice.item.kind=="repair_kit" and int(choice.get("cost",0))==20:
			choices[i]=medical_reward()
			continue
		if choice.item.kind=="unit" and int(choice.get("cost",0))>0:
			choice.cost=EVENT_UNIT_PRICE
			choice.label="折价增援 · %d 补给"%EVENT_UNIT_PRICE
		if choice.item.kind=="refresh_token":choice.label=INTEL_LABEL
	if choices.size()!=2:return
	if choices[0].item.kind!="supplies" or choices[1].item.kind!="supplies":return
	if int(choices[0].get("kit_cost",0))!=0 or int(choices[0].get("cost",0))!=0:return
	choices[0]={"label":INTEL_LABEL,"cost":0,"item":{"kind":"refresh_token","id":"refresh_token"}}

const INTEL_LABEL:="战区情报 · 首件商品免费＋额外免费刷新 1 次"

static func rewards(run:Dictionary) -> Array:
	var random:=rng(run,"reward_v2")
	var completed:int=int(run.stage)-1
	var pool:Array=unit_pool(run)+buff_pool(run)+trait_pool(run)+native_pool(run)+growth_pool(run)+relic_pool(run)
	if completed==3:
		var native:=native_pool(run)
		if not native.is_empty():pool=native
	if completed in [13,18]:
		pool=[]
		for unit:Dictionary in unit_pool(run):pool.append(special_item(run,unit.id,2 if completed==13 else 3))
	if completed%5==0 and completed>0:
		pool=buff_pool(run)+trait_pool(run)+native_pool(run)+relic_pool(run)
	var result:Array=[]
	while not pool.is_empty() and result.size()<Relics.reward_choices(run):
		var picked:=choose_from(pool,random)
		result.append(picked)
		pool.erase(picked)
	if result.is_empty():result=[{"kind":"supplies","id":"bonus","amount":100}]
	if completed not in [3,13,18] and completed%5!=0 and not Army.available(run).is_empty():
		var id:String=Army.available(run)[0]
		result[0]=reward_item(run,{"kind":"unit","id":id,"price":UNIT_PRICE})
	if completed>=5:
		var heroes=preload("res://scripts/expedition/heroes.gd")
		var available:Array=heroes.available(run)
		if not available.is_empty() and random.randf()<0.25:
			result[result.size()-1]={"kind":"hero","id":available[random.randi_range(0,available.size()-1)]}
	if completed>0 and completed%5==0:
		var relics:=relic_pool(run)
		var ultimates:=ultimate_pool(relics)
		if completed>=15 and not ultimates.is_empty():relics=ultimates
		var has_relic:=false
		for item:Dictionary in result:
			if item.kind=="relic" and (completed<15 or ultimates.is_empty() or Relics.ITEMS[item.id].family=="究极构筑"):has_relic=true
		if not has_relic and not relics.is_empty():
			var slot:=result.size()-1
			if result[slot].kind=="hero":slot-=1
			if slot<0:result.append(choose_from(relics,random))
			else:result[slot]=choose_from(relics,random)
	if completed in [15,20,25] and Relics.can_gain(run,"chrono_decree") and rng(run,"archive_drop").randf()<0.01:
		result.append({"kind":"relic","id":"chrono_decree"})
	return result

static func title(item:Dictionary) -> String:
	var unit:=Army.training_name(str(item.get("id","")))
	match str(item.kind):
		"trait_buff":return ("史诗 · 双联教范 · " if item.get("manual",false) else "")+str(Army.TRAITS[item.id].name)+" · 羁绊 +%d 层"%int(item.get("levels",1))
		"native":return unit+" · 全部天赋 +1 级"
		"specialization":return unit+" · 天赋专精 "+("阵地" if item.get("branch","a")=="a" else "机动")
		"training":return unit+" · 攻防强化 +1 级"
		"relic":return Relics.grade(item.id)+" · "+str(Relics.ITEMS.get(item.id,{}).get("name","未知藏品"))+" · 持续藏品"
		"special_unit":return unit+" · 特装 "+["","I","II","III"][int(item.tier)]
	return ""

static func specialization_description(id:String,branch:String) -> String:
	if branch=="b":return "机动：收起部署后，4 秒内移速 +15%、受到的伤害降低 15%；下一次有效直击伤害 +20%（命中后消耗）。"
	var detail:="阵地：部署并停稳 3 秒，获得最大生命 8% 的护盾，每 20 秒可触发一次。"
	if id=="DESO":detail+="辐射工兵部署且 3 秒未受伤时，每秒再恢复 0.5% 最大生命。"
	return detail

static func description(item:Dictionary) -> String:
	match str(item.kind):
		"trait_buff":
			var spec:Dictionary=Army.TRAITS[item.id]
			return "每层都能提升部队，最多叠加 9 层，可与战术装备同时生效。\n%s\n达到 3 层　%s\n达到 6 层　%s\n达到 9 层　%s\n搭配建议　%s"%[Army.Progress.growth_description(item.id),Army.Progress.OPENINGS[item.id],spec.desc[3],spec.desc[4],Army.Progress.BUILDS[item.id]]
		"native":return "同时提升该兵种的全部天赋，各 +1 级，最高 3 级；已满的保留。局外已点等级直接带入，未点的默认 0 级生效。本轮所有同兵种及后续招募共享，不消耗局外资源，也不写回局外。"
		"specialization":return "天赋 3 级后的额外能力，覆盖本轮全部同兵种及后续招募。每种兵种阵地／机动二选一，本轮不能更换，不影响其他兵种的选择。\n"+specialization_description(item.id,str(item.get("branch","a")))
		"training":return "该兵种攻击、防御各 +1 肉鸽等级（相当于局外各 +4 级），最高 5 级；已满的属性不再增加。不回写局外。"
		"relic":return Relics.description(item.id)
		"special_unit":return "立即招募 %d 个特装 %s 单位，个体攻击、防御至少 %d / 5 级，已有更高等级保留。招募后即可在本轮生产和补员，全部天赋与同兵种共享。"%[item.get("count",1),["","I","II","III"][int(item.tier)],Growth.special_level(int(item.tier))]
	return ""

static func event(run:Dictionary) -> Dictionary:
	if int(run.stage)<=1:return {}
	var random:=rng(run,"event")
	var index:=random.randi_range(0,EVENT_NAMES.size()-1)
	var army:Array=Army.available(run)
	var id:String
	if army.is_empty():id=run.licenses[0]
	else:
		if index in [0,2,5,6]:
			var recruits:Array=[]
			for unit_id:String in army:recruits.append({"kind":"unit","id":unit_id})
			id=recruits[draw_index(recruits,random)].id
		else:id=army[random.randi_range(0,army.size()-1)]
	var choices:Array=[{"label":"接受补给 · 获得 60 补给","cost":0,"item":{"kind":"supplies","id":"bonus","amount":60}}, {"label":"强化%s · 20 补给，攻防各 +1 级"%Army.training_name(id),"cost":20,"item":{"kind":"training","id":id}}]
	if not Growth.can_upgrade(run,id):choices[1]=medical_reward()
	match index:
		0,2:choices[1]={"cost":EVENT_UNIT_PRICE,"item":{"kind":"unit","id":id}}
		1,8:choices[1]=medical_reward()
		3:
			var item:=talent_item(run,id)
			if not item.is_empty():choices[1]={"label":"实验训练 · 60 补给","cost":60,"item":item}
		4:choices[1]={"label":INTEL_LABEL,"cost":0,"item":{"kind":"refresh_token","id":"refresh_token"}}
		5:choices[1]={"label":"接应失联部队 · 免费增援，无训练收益","cost":0,"item":{"kind":"reinforce","id":id}}
		6:
			var recruit:=special_item(run,id,1)
			if recruit.kind=="special_unit":choices[1]={"label":"精锐雇佣 · %d 补给，%s"%[recruit.price,title(recruit)],"cost":recruit.price,"item":recruit}
		7:choices[1]={"label":"接收战略储备 · 维修包换 100 补给","cost":0,"kit_cost":1,"item":{"kind":"supplies","id":"bonus","amount":100}}
	if not offer_available(run,choices[1].item):
		choices[1]={"label":"转领补给 · 获得 100 补给","cost":0,"item":{"kind":"supplies","id":"bonus","amount":100}}
	normalize_event_choices(choices)
	return {"name":EVENT_NAMES[index],"completed_stage":int(run.stage)-1,"choices":choices,"resolved":false}
