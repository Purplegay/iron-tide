extends RefCounted
const Army=preload("res://scripts/expedition/army.gd")
const Campaign=preload("res://scripts/expedition/campaign.gd")
const Market=preload("res://scripts/expedition/market.gd")
const Rules=preload("res://scripts/expedition/rules.gd")
var t

func run(test) -> void:
 t=test
 await starters()
 await native_disabled()
 await hero_lifecycle()
 roster_and_store()
 await equipment_collection()
 await boss_protection()
 dismissal_refunds()
 await preload("res://tests/expedition_capacity_cases.gd").run(t)
 preload("res://tests/expedition_offer_capacity_cases.gd").run(t)

func dismissal_refunds() -> void:
 for pair in [["E1",5],["MTNK",15],["GHOST",30]]:
  t.check(preload("res://scripts/expedition/catalog.gd").dismissal_value(pair[0])==pair[1],"per-unit dismissal compensation "+pair[0])
 for id:String in GameData.unit_index:
  var catalog=preload("res://scripts/expedition/catalog.gd")
  t.check(catalog.dismissal_value(id)>0 and catalog.dismissal_value(id)*catalog.squad_size(id)<=30,"paid refill cannot profit through dismissal "+id)
 t.new_ready("美国",16)
 var next:Dictionary=Expedition.state.duplicate(true)
 next.reinforcements=[{"id":"E1","count":2}];next.survivors=[{"id":"E1","hp":0.5,"rank":2,"xp":20.0,"hero":"","variant":""}];next.special_squads=[];next.active_roster=["E1"]
 Expedition.grant(next,{"kind":"special_unit","id":"E1","tier":3,"native_rank":3,"count":1})
 var balance:int=next.supplies
 Expedition.commit(next)
 t.check(Expedition.dismiss("E1",1) and Expedition.state.supplies==balance+5 and Army.quantity(Expedition.state,"E1")==3,"dismiss adds compensation and removes exactly one")
 var ordinary_veteran:=false
 for row:Dictionary in Expedition.state.survivors:
  if row.variant=="" and row.rank==2:ordinary_veteran=true
 t.check(ordinary_veteran and Expedition.state.special_squads[0].count==1,"dismiss preserves veteran and special before ordinary recruit")
 t.check(Expedition.load_run() and Expedition.state.supplies==balance+5 and Army.quantity(Expedition.state,"E1")==3,"dismiss compensation and roster persist atomically")
 t.check(Expedition.dismiss("E1",100) and Expedition.state.supplies==balance+20 and Army.quantity(Expedition.state,"E1")==0,"oversized dismissal pays actual removed count only")
 t.check(Expedition.state.special_squads[0].count==0 and not "E1" in Expedition.state.active_roster,"special dismissal updates special count and active roster")
 var empty:Dictionary=Expedition.state.duplicate(true)
 t.check(not Expedition.dismiss("E1",1) and not Expedition.dismiss("unknown",1) and not Expedition.dismiss("E1",0) and not Expedition.dismiss("E1",-1) and Expedition.state==empty,"empty repeated and invalid dismissals never grant supplies")
 next=empty.duplicate(true);next.survivors=[{"id":"E1","hp":1.0,"rank":0,"xp":0.0,"hero":"E1","variant":""}]
 Expedition.commit(next)
 t.check(not Expedition.dismiss("E1",1) and Expedition.state.supplies==next.supplies and Expedition.state.survivors==next.survivors,"hero-only roster cannot be dismissed for supplies")
 t.new_ready("美国",16)
 next=Expedition.state.duplicate(true);next.repair_coupon=true;next.reinforcements=[{"id":"E1","count":2}];next.survivors=[];next.active_roster=["E1"];Expedition.commit(next)
 balance=Expedition.state.supplies
 var before:=Army.quantity(Expedition.state,"E1")
 t.check(Expedition.service("refill","E1") and not Expedition.state.repair_coupon and Expedition.state.supplies==balance,"free refill consumes its one coupon")
 t.check(Expedition.dismiss("E1",6) and Army.quantity(Expedition.state,"E1")==before and Expedition.state.supplies==balance+30,"free reinforcements may be converted once")
 balance=Expedition.state.supplies
 for cycle in 3:
  t.check(Expedition.service("refill","E1") and Expedition.dismiss("E1",6) and Expedition.state.supplies==balance-10*(cycle+1),"paid refill dismissal cycle loses supplies "+str(cycle))
 next=Expedition.state.duplicate(true);next.phase="battle";Expedition.commit(next)
 t.check(not Expedition.dismiss("E1",1) and Expedition.state==next,"battle cannot dismiss or grant compensation")

func equipment_collection() -> void:
 t.new_ready("美国",1)
 var next:Dictionary=Expedition.state.duplicate(true)
 var catalog=preload("res://scripts/expedition/catalog.gd")
 next.supplies=10000;Expedition.commit(next)
 var ids:Array=catalog.BUFFS.keys()
 for index in ids.size():
  var id:String=ids[index]
  next=Expedition.state.duplicate(true)
  next.shop=[{"kind":"buff","id":id,"price":120,"sold":false,"locked":false}]
  Expedition.commit(next)
  var before:int=next.supplies
  t.check(Expedition.buy(0) and Expedition.state.buffs.size()==index+1,"first chapter accepts equipment without capacity gate "+id)
  t.check(Expedition.state.supplies==before-120,"equipment purchase charges only its own price "+id)
 t.check(Expedition.load_run() and Expedition.state.buffs.size()==24,"entire equipment collection survives reload")
 next=Expedition.state.duplicate(true)
 next.shop=[{"kind":"buff","id":"firepower","price":120,"sold":false,"locked":false}];Expedition.commit(next)
 t.check(Expedition.buy(0,"armor") and Expedition.state.buffs.firepower==2 and Expedition.state.buffs.has("armor"),"obsolete replacement argument cannot discard owned gear")
 next=Expedition.state.duplicate(true);next.stage=13;Expedition.open_event(next)
 for option:Dictionary in next.event.choices:t.check(option.item.kind!="equipment_slot","late event offers no paid capacity upgrade")
 next.event.choices.append({"label":"旧扩容选项","cost":80,"item":{"kind":"equipment_slot","id":"equipment_slot"}})
 Expedition.commit(next)
 var balance:int=Expedition.state.supplies
 t.check(not Expedition.resolve_event(next.event.choices.size()-1) and Expedition.state.supplies==balance,"stale expansion option cannot charge")
 t.check(Expedition.resolve_event(0) and Expedition.state.buffs.size()==24,"post-battle event preserves full collection")
 next=Expedition.state.duplicate(true);next.routes[0].map="exp_plain";Expedition.commit(next)
 t.check(Expedition.launch(0),"full equipment collection launches")
 if t.instantiate_battle():
  for id:String in ids:t.check(Rules.rank(id)==int(Expedition.state.buffs[id]),"battle consumes collected equipment "+id)
  t.check(Expedition.checkpoint(t.battle),"full collection battle checkpoint")
 await t.finish()
 t.check(Expedition.load_run() and Expedition.state.buffs.size()==24,"battle save retains all equipment")
 t.new_ready("美国",1)
 next=Expedition.state.duplicate(true)
 for id:String in ids.slice(0,7):next.buffs[id]=1
 next.phase="reward";next.reward_round="main";next.offers=[{"kind":"buff","id":ids[7]}];Expedition.commit(next)
 t.check(Expedition.choose(0,"armor",Expedition.reward_token()) and Expedition.state.buffs.size()==8 and Expedition.state.buffs.has("armor"),"eighth equipment reward keeps every existing item")

func starters() -> void:
 for country:String in Campaign.STARTERS:
  for preset:Dictionary in Campaign.STARTERS[country]:
   t.check(Expedition.start(country,"",91,preset.units),"preset start "+preset.name)
   Expedition.choose(0)
   var next:Dictionary=Expedition.state.duplicate(true);next.routes[0].map="exp_plain";Expedition.commit(next)
   Expedition.launch(0)
   if t.instantiate_battle():
    for id:String in preset.units:
     var factory=null
     for building in t.battle.buildings:
      if building.side=="ally" and id in building.buildable:factory=building;break
     t.check(factory!=null,"preset has factory "+id)
     if factory!=null:
      t.check(factory.unit_prereqs_ok(id),"preset has consumed prerequisites "+id,factory.queue_block_reason(id))
      t.battle.funds=100000
      var count_before:int=t.battle.units.size()
      t.check(factory.enqueue(id),"preset real production accepts "+id,factory.queue_block_reason(id))
      for tick in 100:factory._tick_unit_queues(1.0)
      t.check(t.battle.units.size()>count_before,"preset real production delivers "+id)
      # This fixture disables physics. Clear delivered units from the factory door,
      # as normal movement would, before checking the next unit in the same queue.
      for unit in t.battle.units.slice(count_before):
       var target:Vector2=t.battle.player_start()+Vector2(650,100+40*t.battle.units.find(unit))
       var at:Vector2=t.battle.path_service.nearest_reachable(target,unit.position,false,40)
       if at.is_finite():unit.position=at
   await t.finish()

func native_disabled() -> void:
 MetaProgress.unit_talents={"E1":{"native_deploy_def":3}}
 for key:String in Army.Talents.options("E1"):MetaProgress.unit_talents.E1[key]=3
 MetaProgress.disabled_effects={"talent/E1/native_deploy_def":true}
 t.new_ready("美国")
 var item:=Market.talent_item(Expedition.state,"E1")
 t.check(item.is_empty(),"owned rank three requires no unlock purchase",[item,Expedition.state.frozen.unit_talents.get("E1"),MetaProgress.unit_talents,Army.Talents.options("E1")])
 t.check(Army.native_rank(Expedition.state,"E1")==3,"expedition defaults all talents on and inherits purchased ranks")
 t.check(not Expedition.service("native","E1") and Army.native_rank(Expedition.state,"E1")==3,"capped inherited talents cannot charge")
 t.check(MetaProgress.disabled_effects.has("talent/E1/native_deploy_def"),"permanent opt-out remains")
 MetaProgress.unit_talents={};MetaProgress.disabled_effects={}

func hero_lifecycle() -> void:
 MetaProgress.academy.hero_builds={}
 for country in ["美国","苏俄"]:
  t.new_ready(country)
  var next:Dictionary=Expedition.state.duplicate(true)
  var ids:Array=["E1","MTNK"] if country=="美国" else ["E2","HTNK"]
  for id:String in ids:t.check(preload("res://scripts/expedition/heroes.gd").recruit(next,id),"local hero recruit "+id)
  Expedition.commit(next);Expedition.launch(0)
  if t.instantiate_battle():
   var found:Array=[]
   for unit in t.battle.units:
    if unit.special.has("academy_hero"):found.append(unit.special.academy_hero)
   t.check(found.size()==2,"both different heroes deployed "+country)
   for unit in t.battle.units.duplicate():
    if unit.special.get("academy_hero","")==ids[0]:unit._die()
   t.screen.expedition_runtime.tasks.finish(true)
   t.check(ids[0] in Expedition.state.wounded_heroes and ids[1] not in Expedition.state.wounded_heroes,"hero casualties tracked independently")
  await t.finish()
  Expedition.choose(0,str(Expedition.state.buffs.keys()[0]) if not Expedition.state.buffs.is_empty() else "")
  t.check(Expedition.state.phase=="reward" and Expedition.state.reward_round=="buff","hero battle grants extra buff round")
  Expedition.choose(0,str(Expedition.state.buffs.keys()[0]) if not Expedition.state.buffs.is_empty() else "")
  t.check(Expedition.resolve_event(0,Expedition.event_token()),"hero battle post-event completes before rescue")
  var before:int=Expedition.state.supplies
  t.check(Expedition.rescue_hero(ids[0]) and Expedition.state.supplies==before-60,"hero rescue real transaction")
  t.check(MetaProgress.academy.hero_builds.is_empty(),"local heroes do not unlock permanent profile")

func roster_and_store() -> void:
 t.new_ready("美国",16)
 var next:Dictionary=Expedition.state.duplicate(true)
 var before:Dictionary=Army.counts(next)
 Expedition.grant(next,{"kind":"special_unit","id":"E1","tier":3,"native_rank":3,"count":1})
 t.check(Army.counts(next)==before,"special recruitment does not grant trait stacks")
 next.heroes=["E1"];t.check(Army.counts(next)==before,"hero recruitment does not grant trait stacks")
 next.heroes=[]
 next.reinforcements.append({"id":"E1","count":20})
 var before_sale:int=next.supplies
 var excess:=Army.quantity(next,"E1")-8
 Expedition.commit(next)
 var quantity:=Army.quantity(Expedition.state,"E1")
 t.check(quantity==8 and Expedition.state.supplies==before_sale+excess*5,"excess infantry automatically sold with exact compensation")
 t.check(Expedition.dismiss("E1",quantity-2) and Army.quantity(Expedition.state,"E1")==2,"explicit demobilization retains requested amount")
 var emblem_balance:int=Expedition.state.supplies
 t.check(not Expedition.service("emblem","E1","energy") and Expedition.state.supplies==emblem_balance,"removed emblem service cannot charge supplies")
 t.check("energy" not in Army.tags("E1",Expedition.state) and "energy" in Army.tags("SREF",Expedition.state),"fixed unit roles determine buff recipients")
 var market:Dictionary=Expedition.state.duplicate(true)
 market.buffs={"firepower":1,"armor":1,"health":1,"engines":1};market.shop=[{"kind":"buff","id":"crossfire","sold":false,"locked":false,"price":180}]
 Expedition.commit(market)
 var supplies:int=Expedition.state.supplies
 t.check(Expedition.buy(0,"armor") and Expedition.state.supplies==supplies-180,"additional equipment purchase has no capacity rejection")
 t.check(Expedition.state.buffs.has("armor") and Expedition.state.buffs.has("crossfire"),"new equipment retains existing equipment")
 t.check(Expedition.sell_equipment("crossfire") and Expedition.state.supplies<supplies,"buy sell cannot create supplies")
 # Rarity and hero rewards are deterministic and respect chapter/ownership.
 var refresh:Dictionary=Expedition.state.duplicate(true)
 refresh.free_refresh=1
 Expedition.commit(refresh)
 var roll:int=Expedition.state.get("shop_roll",0)
 var before_refresh:int=Expedition.state.supplies
 t.check(Expedition.refresh_shop() and Expedition.state.shop_roll==roll+1 and Expedition.state.supplies==before_refresh,"event free refresh advances persisted random stream")
 var hero_hits:=0
 market=Expedition.state.duplicate(true);market.stage=6
 for seed_value in 256:
  market.seed=seed_value
  var offers:=Market.rewards(market)
  t.check(offers==Market.rewards(market),"deterministic reward seed "+str(seed_value))
  var relic_hits:=0
  for item:Dictionary in offers:
   if item.kind=="hero":hero_hits+=1
   if item.kind=="relic":relic_hits+=1
  t.check(relic_hits>0,"boss relic candidate coexists with hero chance "+str(seed_value))
 t.check(hero_hits>35 and hero_hits<100,"hero reward branch frequency",hero_hits)

func boss_protection() -> void:
 t.new_ready("美国",5);Expedition.launch(0)
 if t.instantiate_battle():
  var tasks=t.screen.expedition_runtime.tasks
  var command=tasks.actor("command")
  var soldier=t.battle.spawn_unit("E1","ally",command.position+Vector2(100,0))
  var chrono=t.battle.spawn_unit("CLEG","ally",command.position+Vector2(140,0))
  var engineer=t.battle.spawn_unit("ENGINEER","ally",command.position+Vector2(180,0))
  t.check(is_zero_approx(Rules.impact(command,soldier,100,"bullet")),"boss shield blocks damage until node counterplay")
  t.check(not AlliedAbilities.valid_weapon_target(chrono,command,chrono._active_weapon()),"boss shield rejects temporal bypass")
  t.battle.fog=null
  t.check(not AlliedAbilities.can_order(engineer,command,"allied_engineer"),"boss shield rejects engineer bypass")
  for unit in t.battle.units.duplicate():
   if t.battle.actor_alive(unit) and unit.side=="ally" and unit.unit_id=="MTNK":unit._die()
  tasks.actor("node0")._die();tasks.actor("node1")._die();tasks.tick(1.0)
  t.check(Rules.impact(command,soldier,100,"bullet")>0,"node removal opens normal damage")
  command._die();tasks.tick(1.0)
  t.check("MTNK" not in Expedition.state.active_roster,"dead type removed after consuming deployed reinforcements")
 await t.finish()
