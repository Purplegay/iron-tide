extends Node
const Catalog=preload("res://scripts/expedition/catalog.gd")
const Heroes=preload("res://scripts/expedition/heroes.gd")
const FILE := "user://expedition.itrung"
const VERSION := 2
const Army=preload("res://scripts/expedition/army.gd")
const ReinforcementPlan=preload("res://scripts/expedition/reinforcement_plan.gd")
const Market=preload("res://scripts/expedition/market.gd")
const Campaign=preload("res://scripts/expedition/campaign.gd")
const Growth=preload("res://scripts/expedition/growth.gd")
const Relics=preload("res://scripts/expedition/relics.gd")
const GainJournal=preload("res://scripts/expedition/gain_journal.gd")
const Income=preload("res://scripts/expedition/income.gd")
var state:Dictionary={}
var error := ""

func _ready() -> void:
	load_run()

func load_run() -> bool:
	error=""
	if not FileAccess.file_exists(FILE):state={};return true
	var loaded:=read_file(FILE)
	if loaded.is_empty():return false
	if not loaded.has("cycle"):loaded.cycle=preload("res://scripts/expedition/cycle_letters.gd").cycle(MetaProgress.settled_matches,Catalog.TOTAL)-(1 if MetaProgress.settled_matches.has("expedition:%s:%d"%[loaded.id,Catalog.TOTAL]) else 0)
	for key in ["catalog","licenses","active_roster"]:
		loaded[key]=loaded.get(key,[]).filter(func(id):return not str(id).begins_with("R3"))
	for key in ["survivors","reinforcements","special_squads"]:
		loaded[key]=loaded.get(key,[]).filter(func(row):return not str(row.id).begins_with("R3"))
	for id:String in Army.available(loaded):
		Army.license_unit(loaded,id)
	Army.Talents.freeze_unlocks(loaded.frozen)
	if preload("res://scripts/expedition/contact_stories.gd").recover_contacts(loaded,MetaProgress.contact_transcripts):
		MetaProgress.save()
	if not loaded.has("known_dialogue"):
		loaded.known_dialogue=GainJournal.keys_of(GainJournal.dialogue(int(loaded.cycle)))
	Market.normalize_shop(loaded,true)
	state=loaded
	flush_income()
	return true

func flush_income() -> bool:
	var pending_error:="远征进度已保存，局外奖励待补发；请恢复磁盘空间或权限后重试"
	if Income.deliver(state,MetaProgress):
		if not preload("res://scripts/expedition/hero_field_stories.gd").deliver(state):
			error="远征进度已保存，英雄故事待归档；请恢复磁盘空间或权限后重试"
			return false
		if not preload("res://scripts/units/yuriko_bonds.gd").deliver(state):
			error="远征进度已保存，百合子遗物待归档"
			return false
		if error=="远征进度已保存，百合子遗物待归档":error=""
		if error.begins_with("远征进度已保存，英雄故事待归档"):error=""
		if error==pending_error:error=""
		return true
	error=pending_error
	return false

func read_file(path:String) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:error="无法读取远征存档";return {}
	if file.get_length()>128*1024*1024:error="远征存档过大";return {}
	var envelope=file.get_var(false)
	if not envelope is Dictionary or envelope.get("version",0)!=VERSION or not envelope.get("payload") is PackedByteArray:
		error="远征存档格式不兼容";return {}
	if BattleSaves.digest(envelope.payload)!=envelope.get("sha",""):error="远征存档校验失败";return {}
	var decoded=bytes_to_var(envelope.payload)
	if not valid(decoded):error="远征存档内容无效";return {}
	return decoded

func valid(value) -> bool:
	if not value is Dictionary:return false
	for key in ["id","seed","country","hero","stage","phase","supplies","buffs","licenses","catalog","frozen","reinforcements","survivors","offers","routes","shop","token","kits","refreshes"]:
		if not value.has(key):return false
	if not value.buffs is Dictionary or not value.frozen is Dictionary:return false
	for key in ["licenses","catalog","reinforcements","survivors","offers","routes","shop"]:
		if not value[key] is Array:return false
	if int(value.stage)<1 or int(value.stage)>Catalog.TOTAL or int(value.supplies)<0:return false
	if value.phase not in ["reward","event","ready","battle","failed","complete"]:return false
	if value.phase=="event":
		var pending:Variant=value.get("event",{})
		if not pending is Dictionary or pending.get("resolved",true) or not pending.get("choices") is Array or pending.choices.is_empty():return false
		if int(value.stage)<=1 or int(pending.get("completed_stage",0))!=int(value.stage)-1:return false
	if value.get("reward_round","initial") not in ["initial","main","buff","buff_2","buff_3"]:return false
	if Campaign.bonus_index(str(value.get("reward_round","initial")))>Campaign.bonus_rounds(int(value.stage)):return false
	for id in value.buffs:
		if not Catalog.BUFFS.has(id) or int(value.buffs[id])<1 or int(value.buffs[id])>3:return false
	return Army.valid(value) and Heroes.valid(value)

func commit(next:Dictionary) -> bool:
	if not flush_income():return false
	Market.normalize_shop(next)
	if not valid(next):error="远征状态无效，未保存";return false
	if not state.is_empty() and state.get("id","")==next.get("id",""):
		var delta_supplies:=int(next.supplies)-int(state.supplies)
		if delta_supplies!=0:
			var ledger:Dictionary=next.get("supply_ledger",{}).duplicate(true)
			var category:=str(next.get("supply_action","其他收入" if delta_supplies>0 else "其他支出"))
			var entry:Dictionary=ledger.get(category,{"in":0,"out":0})
			var flow:="in" if delta_supplies>0 else "out"
			entry[flow]=int(entry.get(flow,0))+absi(delta_supplies);ledger[category]=entry
			next.supply_ledger=ledger
	GainJournal.capture(state,next)
	next.erase("supply_action")
	var payload:=var_to_bytes(next)
	var file:=FileAccess.open(FILE+".tmp",FileAccess.WRITE)
	if file==null:error="远征保存失败，请检查磁盘空间或权限";return false
	file.store_var({"version":VERSION,"sha":BattleSaves.digest(payload),"payload":payload})
	file.flush()
	var written:=file.get_error()
	file.close()
	if written!=OK or read_file(FILE+".tmp").is_empty():error="远征临时存档校验失败";return false
	if FileAccess.file_exists(FILE) and DirAccess.copy_absolute(FILE,FILE+".bak")!=OK:error="无法备份远征存档";return false
	if DirAccess.rename_absolute(FILE+".tmp",FILE)!=OK:error="无法替换远征存档";return false
	state=next
	error=""
	flush_income()
	return true

func departure_cycle() -> int:
	return preload("res://scripts/expedition/cycle_letters.gd").cycle(MetaProgress.settled_matches,Catalog.TOTAL)

func start(country:String,hero:String="",seed_value:int=0,opening:Dictionary={},keepsake:Variant="") -> bool:
	if not flush_income():return false
	var gifts=preload("res://scripts/expedition/commander_keepsakes.gd")
	var selected:Array=[]
	var requested:Array=keepsake if keepsake is Array else ([] if keepsake=="" else [keepsake])
	for id:String in requested:
		if not gifts.owned(id):error="尚未获得该指挥官信物";return false
		if id not in selected:selected.append(id)
	var cycle:=departure_cycle()
	if selected.size()>gifts.slot_limit(cycle):
		error="第 %d 周目出发时最多可带 %d 件信物"%[cycle,gifts.slot_limit(cycle)]
		return false
	if opening.is_empty():opening=Campaign.STARTERS.get(country,[{"units":{}}])[0].units.duplicate()
	var opening_problem:=Campaign.opening_error(country,opening)
	if not opening_problem.is_empty():error=opening_problem;return false
	if country not in ["美国","苏俄"]:error="不支持的远征阵营";return false
	var available:=heroes(country)
	if not hero.is_empty() and not hero in available:error="英雄尚未解锁或不属于该阵营";return false
	BattleSaves.pending={}
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"country":country,"difficulty":1,"enemy_country":"苏俄"})
	BattleRequest.freeze_combat_context()
	var frozen:=BattleRequest.combat_context.duplicate(true)
	Growth.freeze(frozen)
	Army.Talents.freeze(frozen)
	frozen.expedition_hero_profile={"academy":{"hero_builds":MetaProgress.academy.get("hero_builds",{}).duplicate(),"hero_skin":MetaProgress.academy.get("hero_skin",{}).duplicate()}}
	var id:=Crypto.new().generate_random_bytes(16).hex_encode()
	var next:Dictionary={"id":id,"seed":seed_value if seed_value!=0 else hash(id),"country":country,"hero":hero,"hero_wounded":false,
		"heroes":[] if hero.is_empty() else [hero],"wounded_heroes":[],
		"stage":1,"phase":"reward","supplies":160,"buffs":{},"licenses":Catalog.basic(country),"catalog":Catalog.roster(country),"frozen":frozen,
		"reinforcements":[],"survivors":[],"offers":[],"routes":[],"shop":[],"token":"","kits":1,"refreshes":0,"reward_unit":false,"reward_buff":true,"reward_round":"initial","history":[]}
	next.research=MetaProgress.academy.get("expedition_research",{}).duplicate(true)
	next.supplies += preload("res://scripts/expedition/research.gd").opening_supplies(next)
	next.cycle=cycle
	Army.initialize(next,opening)
	next.reunion_contacts=gifts.previous_rescues(MetaProgress)
	next.keepsakes=selected
	next.licenses=["CMIN","AMCV","ENGINEER"] if country=="美国" else ["HARV","SMCV","SENGINEER"]
	for uid:String in opening:
		if int(opening[uid])<=0:continue
		if uid not in next.licenses:next.licenses.append(uid)
		next.reinforcements.append({"id":uid,"count":int(opening[uid])})
	next.offers=Catalog.offer(next,"buff","initial")
	return commit(next)

func equip_keepsake(id:String) -> bool:
	const Gifts=preload("res://scripts/expedition/commander_keepsakes.gd")
	if not Gifts.can_equip(state,id):
		error="请在本轮重逢赠礼人后，到营地携带这件信物。"
		return false
	var next:=state.duplicate(true)
	next.keepsakes=preload("res://scripts/expedition/commander_keepsakes.gd").carried(next) + [id]
	next.erase("keepsake")
	offer_partners(next)
	return commit(next)

func offer_partners(next:Dictionary) -> void:
	if int(next.stage)<11:return
	const Gifts=preload("res://scripts/expedition/commander_keepsakes.gd")
	for id:String in Gifts.carried(next):
		for partner:String in Gifts.ITEMS[id].partners:
			if partner.begins_with("R3"):continue
			if partner not in next.catalog:next.catalog.append(partner)

func heroes(country:String) -> Array:
	var result:Array=[]
	for id:String in MetaProgress.Academy.HEROES:
		if id not in MetaProgress.Academy.Stars.IDS and GameData.get_unit(id).get("faction","")!=GameData.ra2_country_side(country):continue
		if MetaProgress.Academy.hero_build_count(MetaProgress,id)>=MetaProgress.Academy.hero_requirement(id):result.append(id)
	return result

func reward_token() -> String:
	return "%s:%s:%s"%[state.get("id",""),state.get("stage",0),state.get("reward_round","initial")]

func choose(index:int,_replace_equipment:String="",expected_token:String="") -> bool:
	if state.get("phase","")!="reward" or index<0 or index>=state.offers.size():return false
	if not expected_token.is_empty() and expected_token!=reward_token():return false
	var next:=state.duplicate(true)
	var item:Dictionary=Market.reward_item(next,next.offers[index])
	if not item_valid(next,item):return false
	if item.kind=="hero" and not Heroes.recruit(next,str(item.id)):return false
	grant(next,item)
	next.reward_unit=false
	var round_id:String=next.get("reward_round","initial")
	var bonus_index:=Campaign.bonus_index(round_id)
	if round_id=="main" or bonus_index>0 and bonus_index<Campaign.bonus_rounds(int(next.stage)):
		next.reward_round="buff" if round_id=="main" else "buff_%d"%(bonus_index+1)
		next.reward_buff=true
		next.offers=Market.bonus_rewards(next)
	else:
		next.reward_buff=false
		next.offers=[]
		if bonus_index>0:open_event(next)
		else:ready(next)
	return commit_item(next,item)

func commit_item(next:Dictionary,item:Dictionary,purchased:bool=false) -> bool:
	if not commit(next):return false
	if purchased:Ra2Sfx.play("ShopPurchaseCoin")
	elif item.kind=="trait_buff" and int(state.trait_buffs[item.id]) in [3,6,9]:
		Ra2Sfx.play("Bonus")
	return true

func open_event(next:Dictionary) -> void:
	next.phase="event"
	next.event=Market.event(next)

func event_token() -> String:
	return "%s:%s:event"%[state.get("id",""),state.get("stage",0)]

func grant(next:Dictionary,item:Dictionary) -> void:
	match str(item.kind):
		"trait_buff":
			var stacks:Dictionary=next.get_or_add("trait_buffs",{})
			stacks[item.id]=mini(9,int(stacks.get(item.id,0))+clampi(int(item.get("levels",1)),1,2))
		"buff":
			next.buffs[item.id]=mini(3,int(next.buffs.get(item.id,0))+int(item.get("levels",1)))
			var paid:Dictionary=next.get_or_add("equipment_paid",{})
			paid[item.id]=int(paid.get(item.id,0))+int(item.get("paid",0))
		"unit":
			var count:=int(item.get("recruit_count",Catalog.squad_size(item.id)))
			if count>0:Army.add_unit(next,item.id,count)
		"training":Growth.upgrade(next,item.id)
		"relic":Relics.grant(next,item.id)
		"native":Army.Talents.grant(next,item)
		"specialization":next.specializations[item.id]=str(item.get("branch","a"))
		"special_unit":
			var count:=int(item.get("recruit_count",item.get("count",1)))
			if count<=0:return
			var token:=str(next.id)+":"+str(next.stage)+":"+str(next.special_squads.size())
			next.special_squads.append({"id":item.id,"token":token,"tier":item.tier,"native_rank":item.get("native_rank",-1),"count":count,"max_count":count})
			Army.license_unit(next,item.id)
			Army.auto_field(next,item.id)
		"reinforce":
			var count:=refill_count(next,item.id)
			if count>0:next.reinforcements.append({"id":item.id,"count":count})
		"refresh_token":
			next.free_refresh=int(next.get("free_refresh",0))+1
			next.free_purchase_stage=int(next.stage)
		"repair_kit":next.kits+=int(item.get("amount",1))
		"supplies":next.supplies+=int(item.get("amount",100))

func ready(next:Dictionary) -> void:
	next.phase="ready"
	offer_partners(next)
	next.routes=Catalog.routes(next)
	next.refreshes=0
	var research_level := preload("res://scripts/expedition/research.gd").rank(next,"supply")
	if research_level>=5:next.free_refresh=int(next.get("free_refresh",0))+1
	if not next.get("research_camp_seen",false):
		next.research_camp_seen=true
		next.supplies+=preload("res://scripts/expedition/research.gd").first_camp_supplies(next)
		if research_level>=10:next.free_refresh+=1
	next.erase("targeted_recruits_bought")
	next.erase("camp_recruits_bought")
	next.shop_roll=0
	next.shop=Catalog.shop(next,0)
	next.event={}
	next.repair_coupon=int(Army.levels(next).get("support",0))>=3
	if int(next.stage) in [6,11,16,21,26]:next.rebuild_coupon=true

func shop_stage(stage:int) -> bool:
	return stage>=1 and stage<=Catalog.TOTAL

func free_shelf_purchase(run:Dictionary) -> bool:
	return run.get("phase","")=="ready" and int(run.get("free_purchase_stage",-1))==int(run.stage)

func buy(index:int,_replace_equipment:String="") -> bool:
	var problem:=purchase_problem(state,index)
	if not problem.is_empty():error=problem;return false
	var next:=state.duplicate(true)
	apply_shelf_purchase(next,index)
	return commit_item(next,next.shop[index],true)

func apply_shelf_purchase(next:Dictionary,index:int) -> int:
	var item:Dictionary=next.shop[index]
	next.supply_action="商店购买"
	var paid:=0 if free_shelf_purchase(next) else Market.shelf_price(next,item)
	next.erase("free_purchase_stage")
	next.supplies-=paid
	var recruitment:=Market.is_recruit(item)
	item.sold=true
	if recruitment:
		var bought:Array=next.get_or_add("camp_recruits_bought",[])
		bought.append(item.id)
		item.locked=false
	item=item.duplicate(true)
	if recruitment:item.recruit_count=Market.recruit_count(next,item)
	item.paid=paid
	grant(next,item)
	return paid

func bargain_level() -> int:
	return preload("res://scripts/expedition/research.gd").rank(state,"bargain")

func lockable_discounts() -> Array[int]:
	var indices:Array[int]=[]
	if bargain_level()<1:return indices
	for index in state.get("shop",[]).size():
		var item:Dictionary=state.shop[index]
		if item.get("discounted",false) and not item.get("locked",false) and can_lock_shop(index):
			indices.append(index)
	return indices

func lock_discounts() -> bool:
	var indices:=lockable_discounts()
	if indices.is_empty():return false
	var next:=state.duplicate(true)
	for index in indices:next.shop[index].locked=true
	return commit(next)

func plan_discount_purchases(next:Dictionary) -> Dictionary:
	var quote:={"count":0,"cost":0,"confirm_talent":false}
	if bargain_level()<2:return quote
	for index in next.get("shop",[]).size():
		var item:Dictionary=next.shop[index]
		if not item.get("discounted",false) or not purchase_problem(next,index).is_empty():continue
		quote.cost+=apply_shelf_purchase(next,index)
		quote.count+=1
		if item.get("enable_disabled",false):quote.confirm_talent=true
	return quote

func buy_discounts(expected:Dictionary) -> bool:
	var next:=state.duplicate(true)
	var quote:=plan_discount_purchases(next)
	if quote!=expected or quote.count==0:
		error="货架已变化，请重新查看折扣商品。"
		return false
	if not commit(next):return false
	Ra2Sfx.play("ShopPurchaseCoin")
	return true

func purchase_problem(run:Dictionary,index:int) -> String:
	if run.get("phase","")!="ready":return "请先完成当前奖励或事件"
	if index<0 or index>=run.get("shop",[]).size():return "商品已变化，请重新选择"
	var item:Dictionary=run.shop[index]
	if Market.recruit_bought(run,item):return "本营地已招募过该兵种"
	if item.sold:return "已售罄"
	if not Market.recruit_fits(run,item):return "该兵种已达持有上限（%d 个）"%Army.limit(item.id)
	var key:=Market.shop_key(item)
	for other_index in run.shop.size():
		if other_index<index and Market.shop_key(run.shop[other_index])==key:return "本店已有同款商品"
	var problem:=item_problem(run,item)
	if not problem.is_empty():return problem
	if item.kind=="buff" and int(run.buffs.get(item.id,0))>=3:return "该装备已满 3 级"
	var price:=Market.shelf_price(run,item)
	if not free_shelf_purchase(run) and price>int(run.supplies):return "补给不足 · 还差 %d"%(price-int(run.supplies))
	return ""

func refresh_price() -> int:
	return 0 if int(state.get("free_refresh",0))>0 else Relics.refresh_price(state,mini(30,int(state.get("refreshes",0))*10))

func refresh_slots() -> int:
	if state.get("shop",[]).is_empty():return 0
	var locked:=0
	for item:Dictionary in state.shop:
		if Market.keep_locked(state,item):locked+=1
	if locked==state.shop.size():return 0
	return maxi(0,state.shop.size()-locked)

func refresh_shop() -> bool:
	if state.get("phase","")!="ready" or state.shop.is_empty() or int(state.supplies)<refresh_price():return false
	if refresh_slots()==0:error="商品已全部锁定";return false
	var next:=state.duplicate(true)
	next.supply_action="商店刷新"
	next.supplies-=refresh_price()
	if int(next.get("refreshes",0))>0 and int(next.get("free_refresh",0))>0:next.free_refresh-=1
	else:next.refreshes+=1
	next.shop_roll=int(next.get("shop_roll",0))+1
	next.shop=Catalog.shop(next,int(next.shop_roll))
	if not commit(next):return false
	Ra2Sfx.play("ShopRefreshCoin")
	return true

func repair_price() -> int:
	var total:=0.0
	for unit:Dictionary in state.get("survivors",[]):total+=(1.0-float(unit.hp))*8.0
	return ceili(total*(1.0-Army.Progress.value("support","discount",int(state.get("trait_buffs",{}).get("support",0)))))

func repair() -> bool:
	if state.get("phase","")!="ready" or int(state.supplies)<repair_price():return false
	var next:=state.duplicate(true)
	next.supply_action="整备全军"
	next.supplies-=repair_price()
	for unit:Dictionary in next.survivors:unit.hp=1.0
	return commit(next)

func rescue_hero(id:String="") -> bool:
	if id.is_empty():id=str(state.get("hero",""))
	if state.get("phase","")!="ready" or id not in Heroes.wounded(state) or int(state.supplies)<Heroes.RESCUE_COST:return false
	var next:=state.duplicate(true)
	next.supply_action="英雄救治"
	next.supplies-=Heroes.RESCUE_COST
	next.wounded_heroes=Heroes.wounded(next)
	next.wounded_heroes.erase(id)
	next.hero_wounded=str(next.hero) in next.wounded_heroes
	return commit(next)

func launch(index:int) -> bool:
	if state.get("phase","")!="ready" or index<0 or index>=state.routes.size():return false
	var problem:=Army.roster_error(state)
	if not problem.is_empty():error=problem;return false
	if state.routes[index].get("task","") in ["capture","control","research","rescue"]:
		var ground_force:=false
		for id:String in state.active_roster+Heroes.owned(state):
			if id in Heroes.wounded(state):continue
			if Catalog.group(id) not in ["air","naval"]:ground_force=true
		if not ground_force:error="此任务需要至少一种可出战的地面编制进行占点";return false
	var next:=state.duplicate(true)
	next.route=next.routes[index].duplicate(true)
	# Camps saved before the four-house cap may still contain a five-house offer.
	var opponents:=int(next.route.get("enemy_count",1))
	next.route.enemy_count=mini(opponents,3-next.route.get("support_contacts",[]).size())
	next.route.front_bonus=(int(next.route.enemy_count)-1)*60
	next.token=str(next.id)+":"+str(next.stage)
	next.phase="battle"
	next.erase("checkpoint")
	if not commit(next):return false
	return prepare_battle()

func prepare_battle() -> bool:
	if state.get("phase","")!="battle":return false
	if state.has("checkpoint"):
		# Older checkpoints predate the opt-out switch for army selection.
		var checkpoint = state.checkpoint
		if checkpoint is Dictionary and checkpoint.get("records") is Array:
			for record in checkpoint.records:
				if record is Dictionary and record.get("kind") == "unit" and record.get("fields") is Dictionary:
					record.fields.get_or_add("excluded_from_army_selection", false)
		var message:=BattleSaves.validate(checkpoint)
		if not message.is_empty():error=message;return false
	var route:Dictionary=state.route
	var config:Dictionary={"country":state.country,"enemy_country":route.enemy,"difficulty":Catalog.difficulty(int(state.stage)),
		"map_layout":route.map,"map_size":route.size,"starting_funds":Campaign.funds(int(state.stage)),"victory_condition":"short","fog_of_war":true,"opponents":int(route.get("enemy_count",1))}
	var houses:Array=[{"country":state.country,"team":1}]
	for index in int(route.get("enemy_count",1)):houses.append({"country":route.enemy if index%2==0 else "苏俄" if route.enemy=="美国" else "美国","team":2,"difficulty":Catalog.difficulty(int(state.stage))})
	for contact:Dictionary in route.get("support_contacts",[]):houses.append({"country":contact.country,"team":1,"commander":contact.name,"difficulty":maxi(1,Catalog.difficulty(int(state.stage))-1)})
	if houses.size()>2:config.houses=houses
	BattleRequest.configure_skirmish(MatchRules.EXTENDED,config)
	BattleRequest.freeze_combat_context()
	var context:=BattleRequest.combat_context
	for key in state.frozen:
		# Opening orders belong to this stage. A checkpoint restores its own orders below.
		if key in ["opening_orders", "opening_plan_name"]: continue
		if key not in ["enemy_logistics","enemy_unit_upgrades","ai_nuke_levels","brutal_three","final_damage_cap","final_damage_threshold","house_training","mixed_damage_caps","native_ore_map"]:
			context[key]=state.frozen[key].duplicate(true) if state.frozen[key] is Dictionary or state.frozen[key] is Array else state.frozen[key]
	context.expedition={"id":state.id,"token":state.token,"stage":state.stage,"hero":state.hero,"hero_wounded":state.hero_wounded,"buffs":state.buffs.duplicate(),
		"heroes":Heroes.owned(state),"wounded_heroes":Heroes.wounded(state),
		"licenses":state.licenses.duplicate(),"catalog":state.catalog.duplicate(),"condition":route.condition.id,"title":route.title}
	# A healthy recruited commando brings a training permit for this stage.
	for hero_id:String in context.expedition.heroes:
		if hero_id in MetaProgress.Academy.Commandos.IDS and hero_id not in context.expedition.wounded_heroes and hero_id not in context.expedition.licenses:
			context.expedition.licenses.append(hero_id)
	context.expedition.yuriko_recruited = state.get("yuriko_recruited",false) or MetaProgress.yuriko_school.get("gm_open",false)
	context.expedition.yuriko_training = state.get("yuriko_training",{}).duplicate(true)
	context.expedition.research=state.get("research",{}).duplicate(true)
	context.expedition.training_permits=state.get("training_permits",[]).duplicate()
	Army.apply_context(state,context)
	context.expedition.task=state.route.get("task",Campaign.task(int(state.stage)))
	context.expedition.keepsakes=preload("res://scripts/expedition/commander_keepsakes.gd").carried(state).duplicate()
	context.expedition.elite=state.route.get("elite",false)
	context.expedition.primary_enemy=state.route.get("primary_enemy","enemy")
	context.expedition.elite_tactic=state.route.get("elite_tactic","")
	context.expedition.support_contacts=state.route.get("support_contacts",[]).duplicate(true)
	context.expedition.opponents=int(state.route.get("enemy_count",1))
	BattleSaves.pending=state.get("checkpoint",{}).duplicate(true)
	if not BattleSaves.pending.is_empty():
		var saved_army:Dictionary=BattleSaves.pending.context.combat_context.expedition
		if MetaProgress.yuriko_school.get("gm_open",false):saved_army.yuriko_recruited=true
		for id:String in context.expedition.licenses:
			Army.license_unit(saved_army,id)
		BattleRequest.combat_context=BattleSaves.pending.context.combat_context.duplicate(true)
	return true

func owns_battle() -> bool:
	return state.get("phase","")=="battle" and str(BattleRequest.combat_context.get("expedition",{}).get("token",""))==str(state.get("token",""))

func checkpoint(world) -> bool:
	if not owns_battle() or world.ended:return false
	var codec:=BattleSaves.Snapshot.new()
	var snapshot:=codec.capture(world)
	if not codec.error.is_empty():error=codec.error;return false
	var message:=BattleSaves.validate(snapshot)
	if not message.is_empty():error=message;return false
	var next:=state.duplicate(true)
	next.checkpoint=snapshot
	return commit(next)

func settle(world,win:bool) -> bool:
	if not owns_battle():error="本场远征已经结算或不属于当前存档";return false
	var next:=state.duplicate(true)
	next.erase("checkpoint")
	next.kits=int(world.allied_state.get("expedition_kits",next.kits))
	next.red_alert_charge=clampi(int(world.allied_state.get("expedition_red_alert",{}).get("charge",0)),0,1)
	var report:=preload("res://scripts/expedition/insights.gd").snapshot(state,world,win)
	next.battle_reports=next.get("battle_reports",[]).duplicate(true)
	if not win:
		next.battle_reports.append(report)
		next.phase="failed"
		return commit(next)
	settle_legion(next,world)
	next.reinforcements=[]
	Army.synchronize(next)
	Heroes.update_wounded(next,world)
	var lost:=mini(5,int(world.allied_state.get("expedition_losses",0)))
	var reward:=Campaign.victory_supplies(int(next.stage),bool(next.route.get("elite",false)))
	reward+=Campaign.OPTIONAL_SUPPLIES if world.allied_state.get("expedition_optional",false) else 0
	reward+=30*int(next.buffs.get("supplies",0))+mini(30,lost*8*int(next.buffs.get("salvage",0)))
	reward+=Relics.victory_supplies(next)+preload("res://scripts/expedition/research.gd").supply_reward(next)
	var field:Dictionary=world.allied_state.get("expedition_field_ops",{})
	preload("res://scripts/expedition/hero_field_stories.gd").settle(next, field.get("objectives", []), report)
	preload("res://scripts/units/yuriko_bonds.gd").settle(next,field,report)
	var field_kits:=int(field.get("kits",0))
	next.kits+=field_kits
	if field_kits>0:report.field_kits=field_kits
	if field.get("wave_intel",false):
		next.intel_stage=int(next.stage)+1;report.wave_intel=true
	if field.has("engineer_map"):
		next.engineer_stage=int(next.stage)+1
		next.engineer_map=field.engineer_map
		report.engineer_map=field.engineer_map
	var lab_progress:Array=world.allied_state.get("expedition_task",{}).get("labs",[0.0,0.0])
	var lab_reward:=(1 if float(lab_progress[0])>=45.0 else 0)+(1 if float(lab_progress[1])>=45.0 else 0)
	var field_reward:=int(field.get("supplies",0))+40*lab_reward
	var front_reward:=int(next.route.get("front_bonus",0))
	reward+=field_reward+front_reward
	next.field_contacts=next.get("field_contacts",[]).duplicate(true)
	for contact:Dictionary in field.get("contacts",[]):
		var profile:Dictionary=preload("res://scripts/expedition/contact_catalog.gd").PEOPLE.get(contact.id,{})
		if profile.has("permit"):
			var unit_id:String=profile.permit
			var permits:Array=next.get_or_add("training_permits",[])
			if unit_id not in permits:
				permits.append(unit_id)
				report.get_or_add("training_permits",[]).append(unit_id)
			if unit_id not in next.catalog:next.catalog.append(unit_id)
			if unit_id not in next.licenses:next.licenses.append(unit_id)
		if not next.field_contacts.any(func(old):return old.id==contact.id and old.stage==contact.stage):next.field_contacts.append(contact.duplicate(true))
	report.reward_breakdown={"基础及精英":Campaign.victory_supplies(int(next.stage),bool(next.route.get("elite",false))),"限时目标":Campaign.OPTIONAL_SUPPLIES if world.allied_state.get("expedition_optional",false) else 0,"后勤装备":30*int(next.buffs.get("supplies",0))+mini(30,lost*8*int(next.buffs.get("salvage",0))),"藏品":Relics.victory_supplies(next)}
	report.reward_breakdown["战场支线与实验室"]=field_reward
	report.reward_breakdown["多线作战"]=front_reward
	report.field_contacts=field.get("contacts",[]).duplicate(true)
	report.labs_secured=lab_reward
	report.reward=reward
	next.battle_reports.append(report)
	next.supply_action="战斗胜利"
	next.supplies+=reward
	next.history.append({"stage":next.stage,"map":next.route.map,"difficulty":Catalog.difficulty(next.stage),"supplies":reward,"income":Income.quote(int(next.stage))})
	next.last_map=next.route.map
	next.reinforcements=[]
	if int(next.stage)==Catalog.TOTAL:next.phase="complete"
	else:
		next.stage+=1;next.phase="reward";next.reward_unit=true;next.reward_buff=true;next.reward_round="main"
		offer_partners(next)
		next.offers=Market.rewards(next)
	return commit(next)

func settle_legion(next:Dictionary,world,heal:=true) -> void:
	var survivors:=collect(world,heal)
	next.chrono_discounts=ReinforcementPlan.carry(state,world,survivors)
	var returning:Array=survivors + Army.deployment(state).reserve
	returning.append_array(collect_replacements(world,survivors,returning,heal))
	next.survivors=returning

func eligible_survivor(world,unit) -> bool:
	return world.actor_alive(unit) and unit.side=="ally" and unit.unit_id in state.catalog \
		and not (unit.special.has("expedition_mission_unit") or unit.special.has("expansion_temporary") or unit.special.has("furnace_flak_life") or unit.special.has("hero_wreck") or unit.is_harvester or unit.deploy_building_id()!="")

func survivor_row(unit,heal:bool) -> Dictionary:
	var promoted:bool = unit.special.get(preload("res://scripts/expedition/red_alert.gd").PROMOTED,false)
	return {"id":unit.unit_id,"excluded":unit.excluded_from_army_selection,"hp":minf(1.0,unit.hp/maxf(1,unit.max_hp)+(recovery(unit.unit_id) if heal else 0.0)),"rank":1 if promoted else unit.veteran_level,"xp":0.0 if promoted else unit._vet_kills,"alert_start_one":promoted,"hero":unit.special.get("academy_hero",""),"variant":unit.special.get("expedition_variant","")}

func collect_replacements(world,survivors:Array,returning:Array,heal:bool) -> Array:
	var vacancies:Dictionary={}
	for row:Dictionary in world.allied_state.get("expedition_legion_initial",[]):
		if str(row.get("hero","")).is_empty() and str(row.get("variant","")).is_empty():
			vacancies[row.id]=int(vacancies.get(row.id,0))+1
	for row:Dictionary in survivors:
		if vacancies.has(row.id) and str(row.get("hero","")).is_empty() and str(row.get("variant","")).is_empty():
			vacancies[row.id]-=1
	# The camp's excess sale counts reserves toward both limits. Backfill must
	# not create sellable excess or displace already-owned reserves.
	var counts:Dictionary={}
	var room:=Campaign.population(int(state.stage))
	for row:Dictionary in returning:
		if not str(row.get("hero","")).is_empty():continue
		counts[row.id]=int(counts.get(row.id,0))+1
		room-=1
	if room<=0:return []
	for id in vacancies:
		vacancies[id]=mini(int(vacancies[id]),Army.limit(id)-int(counts.get(id,0)))
	var candidates:Array=[]
	for unit in world.units:
		if not eligible_survivor(world,unit) or int(vacancies.get(unit.unit_id,0))<=0:continue
		if not unit.special.get(ReinforcementPlan.LOCAL_PRODUCTION,false) or unit.special.get(ReinforcementPlan.MEMBER,false) or unit.special.get("expedition_radio_copy",false):continue
		var row:=survivor_row(unit,heal)
		if str(row.hero).is_empty() and str(row.variant).is_empty():candidates.append(row)
	candidates.sort_custom(survivor_before)
	var result:Array=[]
	for row:Dictionary in candidates:
		if int(vacancies[row.id])<=0:continue
		vacancies[row.id]-=1
		result.append(row)
		if result.size()>=room:break
	return result

func collect(world,heal:=true) -> Array:
	var result:Array=[]
	for unit in world.units:
		if not eligible_survivor(world,unit) or not unit.special.get(ReinforcementPlan.MEMBER,false):continue
		result.append(survivor_row(unit,heal))
	result.sort_custom(survivor_before)
	# Queued chronoshift reinforcements never entered the battle, so they cannot
	# be dead or wounded. Carry each pending unit into the next camp intact.
	if is_instance_valid(world):
		for pending:Dictionary in world.allied_state.get("expedition_reinforcement_plan",[]):
			if pending.get("radio_copy",false) or str(pending.id).begins_with("R3"):continue
			result.append({"id":str(pending.get("id","")),"excluded":bool(pending.get("excluded",false)),"hp":float(pending.get("hp",1.0)),"alert_start_one":bool(pending.get("alert_start_one",false)),"rank":int(pending.get("rank",0)),"xp":float(pending.get("xp",0.0)),"hero":str(pending.get("hero","")),"variant":str(pending.get("variant",""))})
	return result

func survivor_before(a:Dictionary,b:Dictionary) -> bool:
	if str(a.hero).is_empty()!=str(b.hero).is_empty():return not str(a.hero).is_empty()
	if int(a.rank)!=int(b.rank):return int(a.rank)>int(b.rank)
	return float(a.hp)>float(b.hp)

func retreat(world) -> bool:
	if not owns_battle() or world.ended or state.get("retreat_used",false) or int(state.stage)%5==0 or int(state.supplies)<80:return false
	var next:=state.duplicate(true)
	var report:=preload("res://scripts/expedition/insights.gd").snapshot(state,world,false)
	report.reason="主动撤离";report.retreat=true
	next.battle_reports=next.get("battle_reports",[]).duplicate(true);next.battle_reports.append(report)
	next.supply_action="撤退"
	next.retreat_used=true;next.supplies-=80
	settle_legion(next,world,false)
	next.reinforcements=[]
	Army.synchronize(next)
	next.kits=int(world.allied_state.get("expedition_kits",next.kits))
	next.red_alert_charge=clampi(int(world.allied_state.get("expedition_red_alert",{}).get("charge",0)),0,1)
	Heroes.update_wounded(next,world)
	next.last_map=next.route.map
	next.stage+=1
	next.erase("checkpoint")
	ready(next)
	return commit(next)

func cancel_launch() -> bool:
	if not owns_battle() or state.has("checkpoint"):return false
	var next:=state.duplicate(true)
	next.phase="ready"
	return commit(next)

func recovery(id:String) -> float:
	var levels:=Army.levels(state)
	return 0.25+Army.Progress.value("support","recovery",int(state.get("trait_buffs",{}).get("support",0)))+(0.15 if int(levels.infantry)>=3 and Catalog.group(id)=="infantry" else 0.0)

func item_valid(run:Dictionary,item:Dictionary) -> bool:
	var problem:=item_problem(run,item)
	if not problem.is_empty():error=problem;return false
	return true

func item_problem(run:Dictionary,item:Dictionary) -> String:
	if str(item.get("id","")).begins_with("R3"):return "红警3兵种不参与远征"
	if item.kind=="blueprint":return "量产图纸已取消；全部天赋由同兵种共享"
	if item.kind=="special_unit" and not Market.special_useful(run,item.id,int(item.tier)):return "该兵种已解锁全部天赋或无需特装攻防加成"
	if item.kind=="buff" and int(run.buffs.get(item.id,0))>=3:return "该装备已满 3 级"
	if item.kind=="reinforce" and refill_count(run,item.id)<=0:return "该兵种已有足够人员，无需补员"
	if item.kind=="equipment_slot":return "装备数量已无限制，无需扩容，请选择其他事件选项"
	if item.kind=="trait_buff":
		if not Army.TRAITS.has(item.id) or int(run.get("trait_buffs",{}).get(item.id,0))>=9:return "该羁绊已满 9 层，请选择其他奖励或刷新商品"
	if item.kind=="native" and not Army.Talents.can_gain(run,item):return "全部天赋已达到商品等级，请刷新商品"
	if item.kind=="specialization" and run.specializations.has(item.id):return "该兵种已选择专精"
	if item.kind=="training":
		var growth_problem:=Growth.upgrade_problem(run,item.id)
		if not growth_problem.is_empty():return growth_problem
	if item.kind=="relic" and not Relics.can_gain(run,item.id):return "藏品不存在或已持有"
	if item.kind=="relic" and int(run.stage)<int(Relics.ITEMS[item.id].get("min_stage",1)):return "%s从第 %d 关起开放"%[Relics.ITEMS[item.id].name,int(Relics.ITEMS[item.id].min_stage)]
	if item.kind=="hero" and item.id not in Heroes.available(run):return "该英雄已拥有，不能重复招募"
	return ""

func formation_slots() -> Array:
	var cells:Array=[]
	cells.resize(Campaign.slots(state))
	cells.fill("")
	var saved:Array=state.get("deployment_slots",[])
	for i in mini(cells.size(),saved.size()):
		if saved[i] in state.active_roster and saved[i] not in cells:cells[i]=saved[i]
	for id:String in state.active_roster:
		if id not in cells and cells.has(""):cells[cells.find("")]=id
	return cells

func adjust_deployment(id:String,delta:int) -> bool:
	if state.get("phase","")!="ready" or id not in state.active_roster or absi(delta)!=1:return false
	var plan:=Army.deployment(state)
	var count:=int(plan.counts[id])+delta
	if count<0 or count>mini(int(plan.owned.get(id,0)),Army.limit(id)) or (delta>0 and plan.remaining<=0):return false
	var next:=state.duplicate(true)
	next.deployment_counts=plan.counts
	next.deployment_counts[id]=count
	if count==0:next.active_roster.erase(id);next.deployment_counts.erase(id)
	return commit(next)

func move_formation(id:String,target:int) -> bool:
	if state.get("phase","")!="ready" or id not in Army.available(state):return false
	var cells:=formation_slots()
	var source:=cells.find(id)
	if target < -1 or target>=cells.size() or target==source:return false
	if source>=0:cells[source]=cells[target] if target>=0 else ""
	if target>=0:cells[target]=id
	var next:=state.duplicate(true)
	next.deployment_slots=cells
	next.active_roster=cells.duplicate()
	while next.active_roster.has(""):next.active_roster.erase("")
	return commit(next)

func set_active(id:String,enabled:bool) -> bool:
	if state.get("phase","")!="ready" or id not in Army.available(state):return false
	var next:=state.duplicate(true)
	next.active_roster.erase(id)
	if enabled:
		if next.active_roster.size()>=Campaign.slots(next):error="出战编制已满";return false
		next.active_roster.append(id)
	return commit(next)

func dismiss(id:String,count:int) -> bool:
	if state.get("phase","")!="ready" or count<=0:return false
	var next:=state.duplicate(true)
	var rows:=Army.inventory(next)
	var remaining:=count
	# Explicitly remove ordinary, low-rank troops first; never remove a hero.
	rows.sort_custom(dismiss_before)
	for index in range(rows.size()-1,-1,-1):
		if remaining>0 and rows[index].id==id and str(rows[index].get("hero","")).is_empty():rows.remove_at(index);remaining-=1
	var removed:=count-remaining
	if removed<=0:return false
	next.supply_action="遣散"
	next.supplies+=removed*Catalog.dismissal_value(id)
	next.survivors=rows
	next.reinforcements=[]
	Army.synchronize(next)
	return commit(next)

func dismiss_before(a:Dictionary,b:Dictionary) -> bool:
	if str(a.get("variant","")).is_empty()!=str(b.get("variant","")).is_empty():return not str(a.get("variant","")).is_empty()
	return survivor_before(a,b)

func excess_sale(run:Dictionary) -> Dictionary:
	var rows:=Army.inventory(run)
	rows.sort_custom(dismiss_before)
	var counts:Dictionary={}
	for row:Dictionary in rows:
		if not str(row.get("hero","")).is_empty():continue
		counts[row.id]=int(counts.get(row.id,0))+1
	var sold:=0
	var refund:=0
	for index in range(rows.size()-1,-1,-1):
		var row:Dictionary=rows[index]
		if not str(row.get("hero","")).is_empty() or int(counts[row.id])<=Army.limit(row.id):continue
		counts[row.id]-=1;sold+=1
		refund+=Catalog.dismissal_value(row.id)
		rows.remove_at(index)
	return {"rows":rows,"count":sold,"supplies":refund}

func sell_excess_personnel() -> bool:
	if state.get("phase","")!="ready":return false
	var sale:=excess_sale(state)
	if int(sale.count)<=0:error="没有超过同兵种持有上限的人员";return false
	var next:=state.duplicate(true)
	next.survivors=sale.rows
	next.reinforcements=[]
	next.supplies+=int(sale.supplies)
	next.last_personnel_sale={"stage":int(next.stage),"count":int(sale.count),"supplies":int(sale.supplies)}
	Army.synchronize(next)
	return commit(next)

func refill_count(run:Dictionary,id:String) -> int:
	return mini(Catalog.squad_size(id),Army.room(run,id))

func can_lock_shop(index:int) -> bool:
	if state.get("phase","")!="ready" or index<0 or index>=state.shop.size():return false
	var item:Dictionary=state.shop[index]
	return Market.lock_available(state,item)

func lock_shop(index:int) -> bool:
	if not can_lock_shop(index):return false
	var next:=state.duplicate(true)
	next.shop[index].locked=not next.shop[index].get("locked",false)
	return commit(next)

func track_trait(id:String) -> bool:
	if state.get("phase","")!="ready" or not Army.TRAITS.has(id):return false
	var next:=state.duplicate(true)
	if id in next.tracked_traits:next.tracked_traits.erase(id)
	else:
		if next.tracked_traits.size()>=2:next.tracked_traits.pop_front()
		next.tracked_traits.append(id)
	return commit(next)

func service(kind:String,id:String="",branch:String="a",expected_price:int=-1) -> bool:
	if state.get("phase","")!="ready":return false
	var item:Dictionary={}
	match kind:
		"native":item=Market.talent_item(state,id)
		"training":
			item={"kind":"training","id":id,"price":Growth.price(state)}
		"relic":item={"kind":"relic","id":Growth.RELIC,"price":Growth.RELIC_PRICE}
		"refill":
			if id not in state.licenses:return false
			if refill_count(state,id)<=0:error="该兵种已有足够人员，无需补员";return false
			item={"kind":"reinforce","id":id,"price":0 if state.get("repair_coupon",false) else 40}
		"kit":item={"kind":"repair_kit","id":"repair_kit","price":40}
	if item.is_empty() or not item_valid(state,item):return false
	if expected_price>=0 and int(item.price)!=expected_price:error="强化价格已变化，请重新选择";return false
	if int(state.supplies)<int(item.price):error="远征补给不足";return false
	if item.kind=="specialization":item.branch=branch if branch in ["a","b"] else "a"
	var next:=state.duplicate(true)
	next.supply_action="养成与补员 · "+kind
	next.supplies-=int(item.price)
	if kind=="training" and int(item.price)==0:next.free_upgrade_stage=int(next.stage)
	if kind=="refill":next.repair_coupon=false
	grant(next,item)
	return commit_item(next,item,int(item.price)>0)

func resolve_event(index:int,expected_token:String="") -> bool:
	if state.get("phase","")!="event" or state.event.is_empty() or state.event.get("resolved",false):return false
	if not expected_token.is_empty() and expected_token!=event_token():return false
	if index<0 or index>=state.event.choices.size():return false
	var choice:Dictionary=state.event.choices[index]
	if int(state.supplies)<int(choice.cost) or int(state.kits)<int(choice.get("kit_cost",0)):error="事件所需资源不足";return false
	if not item_valid(state,choice.item):return false
	var next:=state.duplicate(true)
	next.supply_action="事件"
	next.supplies-=int(choice.cost)
	next.kits-=int(choice.get("kit_cost",0))
	grant(next,choice.item)
	next.event.resolved=true
	next.event_history.append({"stage":next.event.completed_stage,"name":next.event.name,"choice":index})
	ready(next)
	return commit_item(next,choice.item)

func sell_equipment(id:String) -> bool:
	if state.get("phase","")!="ready" or not state.buffs.has(id):return false
	var next:=state.duplicate(true)
	var paid:int=next.get("equipment_paid",{}).get(id,0)
	var refund:=floori(paid*(0.70 if next.get("rebuild_coupon",false) else 0.30)) if paid>0 else 24*int(next.buffs[id])
	if paid>0 and next.get("rebuild_coupon",false):next.rebuild_coupon=false
	next.buffs.erase(id)
	next.get_or_add("equipment_paid",{}).erase(id)
	next.supplies+=refund
	return commit(next)
