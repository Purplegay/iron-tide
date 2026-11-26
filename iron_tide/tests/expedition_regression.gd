extends "res://tests/base_recovery_regression.gd"
const Catalog=preload("res://scripts/expedition/catalog.gd")
const Rules=preload("res://scripts/expedition/rules.gd")
const Army=preload("res://scripts/expedition/army.gd")
const Campaign=preload("res://scripts/expedition/campaign.gd")
const Market=preload("res://scripts/expedition/market.gd")
const Training=preload("res://scripts/rules/skill_training.gd")
const Growth=preload("res://scripts/expedition/growth.gd")

func _ready() -> void:
 output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
 if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
 MetaProgress.reset_save()
 check_data()
 check_market()
 await check_command_vehicle()
 await preload("res://tests/expedition_income_cases.gd").run(self)
 await check_campaign()
 await check_native_and_traits()
 await check_potomac_mining()
 await check_soviet_and_maps()
 await check_failure_and_retreat()
 await check_camp()
 await preload("res://tests/expedition_v2_edges.gd").new().run(self)
 preload("res://tests/expedition_late_rewards_cases.gd").run(self)
 await preload("res://tests/expedition_talents_base_cases.gd").run(self)
 await preload("res://tests/expedition_convoy_cases.gd").run(self)
 BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"difficulty":1})
 check(not Rules.active() and Rules.production_factor("ally")==1.0 and Rules.block_reason("HTNK","ally").is_empty(),"ordinary match independent")
 FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
 print("EXPEDITION V2 checks=",checks.size()," failed=",failed)
 get_tree().quit(0 if failed==0 else 1)

func check_command_vehicle() -> void:
 for map_id:String in ["yr_hidvally","exp_plain"]:
  new_ready("苏俄",20,map_id)
  check(Expedition.launch(0),"stage 20 launch "+map_id)
  if not instantiate_battle():await finish();continue
  var tasks=screen.expedition_runtime.tasks
  var command=tasks.actor("command")
  var base:Vector2=battle.enemy_base_center
  var home:Vector2=battle.player_start()
  var destinations:Array=[]
  check(command.hold_position and not battle.skirmish_ai.Tactics.fighter(battle,command,"enemy"),"command vehicle excluded from attack waves "+map_id)
  var ordinary=battle.spawn_unit("HTNK","enemy",command.position+Vector2(80,0))
  check(battle.skirmish_ai.Tactics.fighter(battle,ordinary,"enemy") and tasks.summary().contains("摧毁指挥车即过关"),"ordinary rhino remains in army and objective explains settlement "+map_id)
  ordinary._die()
  for i in 4:
   tasks.boss_tick(30,0)
   var post:Vector2=tasks.state.command_post
   check(command.has_move_order and not command.attack_move and command.hold_position and post.distance_to(base)<home.distance_to(base)*0.2,"rear patrol order "+map_id+str(i),post)
   destinations.append(post)
   command.ai_order("move",home,true)
   check(command.move_target==post and not command.special.has("ai_dispatch_pending"),"house cannot redirect command to player "+map_id+str(i))
   command.position=post
  check(destinations[0]!=destinations[1] and destinations[0]==destinations[3],"patrol cycles through enemy posts "+map_id)
  var saved_post:Vector2=tasks.state.command_post
  check(Expedition.checkpoint(battle),"save patrol "+map_id)
  await finish()
  check(Expedition.load_run() and Expedition.prepare_battle(),"load patrol "+map_id)
  if not instantiate_battle():await finish();continue
  tasks=screen.expedition_runtime.tasks
  command=tasks.actor("command")
  check(tasks.state.command_post==saved_post and command.hold_position and not command.attack_move,"rear patrol survives checkpoint "+map_id)
  tasks.actor("node0")._die()
  tasks.boss_tick(30,0)
  check(tasks.state.relocate==50.0 and not battle.ended,"single node delays convoy "+map_id)
  tasks.actor("node1")._die()
  tasks.boss_tick(50,0)
  check(tasks.state.relocate==70.0 and not battle.ended,"both nodes delay without settling "+map_id)
  tasks.state.erase("command_post")
  command.order_move(home,true)
  check(Expedition.checkpoint(battle),"save old forward order "+map_id)
  await finish()
  check(Expedition.load_run() and Expedition.prepare_battle(),"restore stage 20 "+map_id)
  if not instantiate_battle():await finish();continue
  tasks=screen.expedition_runtime.tasks
  command=tasks.actor("command")
  check(command.hold_position and not command.attack_move and (not command.has_move_order or command.move_target.distance_to(base)<home.distance_to(base)*0.2),"restore replaces obsolete forward order "+map_id)
  command._die()
  tasks.tick(0.1)
  check(battle.ended and Expedition.state.stage==21,"attacking command still wins "+map_id)
  await finish()

func check_data() -> void:
 check(Catalog.TOTAL==30 and Catalog.BUFFS.size()==24,"30 battles and 24 tactical equipment")
 for stage in range(1,31):check(Campaign.difficulty(stage)==1+(stage-1)/5,"chapter difficulty "+str(stage))
 for chapter_index in 6:
  var normal:int=[180,220,260,300,340,380][chapter_index]
  var elite:int=[280,320,360,400,440,480][chapter_index]
  var boss:int=[380,420,460,500,540,580][chapter_index]
  for offset in range(1,6):
   var stage:int=chapter_index*5+offset
   check(Campaign.victory_supplies(stage,false)==(boss if offset==5 else normal),"chapter-scaled ordinary or boss supplies "+str(stage))
   check(Campaign.victory_supplies(stage,true)==(boss if offset==5 else elite),"elite supplies and boss precedence "+str(stage))
 check(Campaign.OPTIONAL_SUPPLIES==60,"optional objective grants sixty supplies")
 for country:String in Campaign.STARTERS:
  for starter:Dictionary in Campaign.STARTERS[country]:
   check(Campaign.opening_error(country,starter.units).is_empty(),"legal preset "+country+starter.name)
   var spent:=0
   for id:String in starter.units:spent+=int(GameData.get_unit(id).cost)*int(starter.units[id])
   check(spent==4000,"preset spends exactly 4000 "+starter.name)
 check(not Campaign.opening_error("美国",{"APOC":1}).is_empty(),"reject foreign initial unit")
 check(not Campaign.opening_error("美国",{"E1":7}).is_empty(),"reject opening quantity overflow")
 for key:String in Army.TRAITS:
  for tier in Army.TRAITS[key].steps.size():
   var amount:int=Army.TRAITS[key].steps[tier]
   check(Army.trait_level(key,amount)==tier+1 and Army.trait_level(key,amount-1)==tier,"trait threshold "+key+str(tier))
 for id:String in Campaign.NEW_MAPS:
  var native=preload("res://scripts/world/native_maps.gd")
  check(native.has(id) and not native.data(id).cells.is_empty(),"new native cells "+id)
  check(ResourceLoader.exists("res://assets/maps/yr/%s_preview.png"%id),"real map preview "+id)

func check_market() -> void:
 check(Expedition.start("美国","",12345),"start independent v2 run")
 check(Expedition.state.supplies==160 and Expedition.state.phase=="reward","opening resources")
 var offers:Array=Expedition.state.offers.duplicate(true)
 check(Expedition.load_run() and Expedition.state.offers==offers,"disk reload does not reroll")
 check(Expedition.choose(0),"initial tactical reward")
 check(Expedition.state.shop.size()==6 and not Expedition.choose(0),"one choice and six shop slots")
 for index in Expedition.state.shop.size():check(Expedition.lock_shop(index),"lock every shop slot "+str(index))
 var locked:Array=Expedition.state.shop.duplicate(true)
 check(Expedition.load_run() and Expedition.state.shop==locked,"all shop locks survive disk reload")
 var before_refresh:=Expedition.state.duplicate(true)
 check(Expedition.refresh_slots()==0 and not Expedition.refresh_shop() and Expedition.state==before_refresh,"fully locked refresh preserves goods, balance and free use")
 var following:Dictionary=Expedition.state.duplicate(true);following.stage+=1
 Expedition.ready(following)
 check(following.shop==locked,"next stage preserves every locked item beyond former two-slot cap")
 check(Expedition.commit(following) and Expedition.load_run() and Expedition.state.shop==locked,"next-stage locks persist through real save")
 check(Expedition.lock_shop(5) and not Expedition.state.shop[5].locked and Expedition.lock_shop(5),"sixth item can unlock and relock")
 var next:Dictionary=Expedition.state.duplicate(true);next.supplies=10000
 check(Expedition.commit(next) and Expedition.buy(0),"purchase offered unit")
 var balance:int=Expedition.state.supplies
 check(not Expedition.buy(0) and Expedition.state.supplies==balance,"purchase once")
 var duplicate_shop:Dictionary=Expedition.state.duplicate(true)
 var sample_item:Dictionary={"kind":"buff","id":"medics","levels":1,"price":120,"quality":2,"sold":false,"locked":false}
 duplicate_shop.buffs={};duplicate_shop.shop=[sample_item.duplicate(true),sample_item.duplicate(true)]
 check(Expedition.purchase_problem(duplicate_shop,0).is_empty() and not Expedition.purchase_problem(duplicate_shop,1).is_empty(),"only first same-shop item can be purchased")
 duplicate_shop.buffs={};duplicate_shop.supplies=1000;duplicate_shop.shop=[sample_item.duplicate(true),sample_item.duplicate(true)]
 check(Expedition.commit(duplicate_shop) and Expedition.buy(0) and not Expedition.buy(1) and Expedition.state.buffs.medics==1,"second duplicate slot stays blocked after first copy is purchased")
 var unique_shop:=Market.shop(duplicate_shop,12)
 var unique_keys:={}
 var unique:=true
 for shop_item:Dictionary in unique_shop:
  if shop_item.kind=="supplies":continue
  var key:=Market.shop_key(shop_item)
  if unique_keys.has(key):unique=false
  unique_keys[key]=true
 check(unique,"generated shop contains no repeated purchasable item")
 var equipment_run:Dictionary=duplicate_shop.duplicate(true)
 equipment_run.buffs={};equipment_run.supplies=1000;equipment_run.shop=[sample_item.duplicate(true)]
 check(Expedition.commit(equipment_run) and Expedition.buy(0) and Expedition.state.buffs.medics==1,"equipment purchase grants level one")
 var equipment_next:Dictionary=Expedition.state.duplicate(true);equipment_next.shop=[sample_item.duplicate(true)];equipment_next.buffs.medics=2
 check(Expedition.commit(equipment_next) and Expedition.buy(0) and Expedition.state.buffs.medics==3,"equipment purchase upgrades to level three")
 equipment_next=Expedition.state.duplicate(true);equipment_next.shop=[sample_item.duplicate(true)]
 check(not Expedition.purchase_problem(equipment_next,0).is_empty() and not Expedition.buy(0) and Expedition.state.buffs.medics==3,"equipment at level three cannot be purchased again")
 var price_run:Dictionary=Expedition.state.duplicate(true)
 price_run.shop=[];price_run.buffs={};price_run.supplies=1000;price_run.stage=1
 var training_item:Dictionary={"kind":"training","id":"E1","price":Growth.PRICE,"sold":false,"locked":false}
 Market.roll_shop_prices([training_item],Market.rng(price_run,"price_test"))
 check(training_item.discounted and int(training_item.original_price)==25 and int(training_item.price) in [12,10,7],"growth offers charge one of three rounded sale prices")
 price_run.shop=[training_item.duplicate(true)]
 check(Expedition.commit(price_run) and Expedition.buy(0) and Expedition.state.supplies==1000-int(training_item.price),"discounted growth purchase charges displayed price")
 var manual_run:Dictionary=Expedition.state.duplicate(true);manual_run.relics[Growth.RELIC]=true;manual_run.free_upgrade_stage=0;manual_run.stage=1
 check(Expedition.commit(manual_run) and Growth.price(Expedition.state)==0,"field manual remains free independent of shop discount")
 check(Expedition.service("native","E1"),"fixed native unlock service")
 check(Army.native_rank(Expedition.state,"E1")==1 and MetaProgress.unit_talents.is_empty(),"all talents upgrade locally from default zero")
 check(Expedition.service("native","E1") and Army.native_rank(Expedition.state,"E1")==2,"all talents rank two")
 check(Expedition.service("native","E1") and Army.native_rank(Expedition.state,"E1")==3,"three upgrades reach all talent cap without chapter gate")
 var growth=preload("res://scripts/expedition/growth.gd")
 var before:int=growth.level(Expedition.state,"E1","atk")
 check(Expedition.service("training","E1") and growth.level(Expedition.state,"E1","atk")==before+1,"attack and defense upgrade")
 next=Expedition.state.duplicate(true);next.stage=6;next.unit_growth.E1={"atk":5,"def":5}
 check(not growth.can_upgrade(next,"E1"),"five-level cap independent of chapter")
 next.stage=16;check(growth.level(next,"E1","atk")==5,"late chapter keeps five-level cap")
 next.stage=2;Expedition.open_event(next);Expedition.commit(next)
 check(not Expedition.state.event.is_empty() and Expedition.resolve_event(0) and not Expedition.resolve_event(0),"one event choice persisted")
 var invalid:Dictionary=Expedition.state.duplicate(true);invalid.supplies=-1
 check(not Expedition.commit(invalid),"invalid state rejected")

func instantiate_battle() -> bool:
 screen=load("res://scenes/battle.tscn").instantiate();add_child(screen)
 screen.process_mode=Node.PROCESS_MODE_DISABLED;battle=screen.battle
 check(screen.expedition_runtime!=null and screen.expedition_runtime.error.is_empty() and screen.expedition_runtime.tasks!=null,"real battle deployment "+str(Expedition.state.stage),screen.expedition_runtime.error)
 return screen.expedition_runtime!=null and screen.expedition_runtime.error.is_empty() and screen.expedition_runtime.tasks!=null

func new_ready(country:String,stage:int=1,map_id:String="exp_plain") -> void:
 check(Expedition.start(country,"",800+stage),"new run "+country+str(stage))
 Expedition.choose(0)
 var next:Dictionary=Expedition.state.duplicate(true);next.stage=stage;next.supplies=10000;next.buffs={}
 Expedition.ready(next)
 next.routes[0].map=map_id;next.routes[0].title=Campaign.map_name(map_id)
 Expedition.commit(next)

func clear_enemies() -> void:
 for unit in battle.units.duplicate():
  if battle.actor_alive(unit) and unit.side=="enemy" and not unit.special.has("expedition_objective"):unit._die()

func satisfy_objective(tasks) -> void:
 var kind:String=tasks.state.kind
 if kind=="annihilate":
  var survivor=battle.spawn_unit("E1","enemy",battle.enemy_base_center)
  var targets=battle.buildings.filter(func(b):return battle.actor_alive(b) and BattleRequest.is_ai_house(b.side) and not BattleRequest.friendly("ally",b.side))
  var last=targets.pop_back()
  for b in targets:b._die()
  tasks.tick(0.1)
  check(not battle.ended and tasks.state.remaining==1,"last enemy structure blocks victory")
  last._die();tasks.tick(0.1)
  check(tasks.state.outcome==1 and battle.actor_alive(survivor),"no troops required after all enemy buildings fall")
  return
 clear_enemies()
 if kind in ["supply","radar","assault","boss"]:
  for key in ["supply0","supply1","radar","node0","node1"]:
   var target=tasks.actor(key)
   if target!=null:target._die()
  tasks.tick(1.0)
  if kind=="boss" and tasks.state.stage==30:
   var mission_marks:Array=screen.hud.minimap.objective_marks()
   check(mission_marks.size()==4 and mission_marks.filter(func(mark):return str(mark.key).begins_with("point")).size()==3,"final boss control phase adds three public minimap points")
   for point:Vector2 in tasks.state.points:
    var unit=battle.spawn_unit("E1","ally",point)
    unit.hold_position=true
   for n in 46:tasks.tick(1.0)
  var command=tasks.actor("command")
  if command!=null:
   check(not command.special.get("expedition_protected",false),"boss shield has counterplay "+str(tasks.state.stage))
   command._die()
  if not battle.ended:tasks.tick(1.0)
 elif kind=="escort":
  for n in 2:tasks.actor("convoy"+str(n)).position=tasks.state.points[2]
  tasks.tick(1.0)
 elif kind=="defend":
  for n in 360:
   if not battle.ended:tasks.tick(1.0)
 else:
  for point:Vector2 in tasks.state.points:
   var unit=battle.spawn_unit("E1","ally",point);unit.hold_position=true
  # Keep the assertion about the objective predicate separate from natural RTS timing.
  for n in 181:
   clear_enemies()
   if not battle.ended:tasks.tick(1.0)

func check_campaign() -> void:
 check(Expedition.start("美国","",772),"30 stage deterministic campaign")
 var frozen:Dictionary=Expedition.state.frozen.duplicate(true)
 for stage in range(1,31):
  for reward_round in (1 if stage==1 else 4 if stage>=26 else 3 if stage>=16 else 2):
   check(Expedition.state.phase=="reward","pending reward round "+str(stage)+":"+str(reward_round))
   var replacement:String="" if Expedition.state.buffs.is_empty() else str(Expedition.state.buffs.keys()[0])
   var reward_token:=Expedition.reward_token()
   check(Expedition.choose(0,replacement,reward_token),"claim stage reward "+str(stage)+":"+str(reward_round))
   check(not Expedition.choose(0,replacement,reward_token),"stale reward click rejected "+str(stage)+":"+str(reward_round))
  if stage>1:
   check(Expedition.state.phase=="event" and Expedition.state.event.completed_stage==stage-1,"every victory has a post-battle event "+str(stage-1))
   var pending:Dictionary=Expedition.state.duplicate(true)
   var event_token:=Expedition.event_token()
   check(not Expedition.launch(0) and not Expedition.buy(0) and not Expedition.service("kit"),"pending event blocks camp and battle actions "+str(stage))
   check(Expedition.load_run() and Expedition.state==pending,"pending event persisted without reroll "+str(stage))
   check(Expedition.resolve_event(0,event_token) and not Expedition.resolve_event(0,event_token),"post-battle event claimed exactly once "+str(stage))
   check(Expedition.state.event_history.size()==stage-1 and Expedition.state.event_history.back().stage==stage-1,"one event history entry per victory "+str(stage))
  check(Expedition.state.phase=="ready","rewards and event complete before launch "+str(stage))
  # Explicitly choose a legal carry roster, mirroring the camp's demobilize action.
  for id:String in Army.available(Expedition.state):
   var qty:=Army.quantity(Expedition.state,id)
   if qty>2:Expedition.dismiss(id,qty-2)
  if Army.available(Expedition.state).size()>5:
   for id:String in Army.available(Expedition.state).slice(5):Expedition.dismiss(id,Army.quantity(Expedition.state,id))
  if Expedition.state.active_roster.is_empty():Expedition.set_active(Army.available(Expedition.state)[0],true)
  var next:Dictionary=Expedition.state.duplicate(true)
  # All real objective families on controlled campaign arenas; native maps tested separately.
  next.routes[0].map="exp_fortress" if stage==30 else "exp_plain"
  next.routes[0].elite=stage%2==0
  Expedition.commit(next)
  check(Expedition.launch(0),"launch stage "+str(stage),Expedition.error)
  check(BattleRequest.house_difficulty("enemy")==1+(stage-1)/5 and bool(BattleRequest.combat_context.get("brutal_three",false))==(stage>=26),"actual enemy difficulty reaches brutal three only in final chapter "+str(stage))
  if not instantiate_battle():await finish();break
  for frame in 3:await get_tree().process_frame
  check(screen.hud.covers_world_pixel(screen.hud.expedition_panel.get_global_rect().get_center()),"objective toolbar owns pointer "+str(stage))
  check(BattleRequest.combat_context.bonuses==frozen.bonuses,"frozen profile stage "+str(stage))
  check(Expedition.state.has("checkpoint"),"opening checkpoint stage "+str(stage))
  check(not battle.power_low,"powered facilities stage "+str(stage))
  var locked:String=""
  for id:String in Expedition.state.catalog:
   if id not in Expedition.state.licenses:locked=id;break
  if not locked.is_empty():check(not Rules.block_reason(locked,"ally").is_empty(),"late game retains license boundary "+str(stage))
  if stage==1:
   check(not BattleSaves.save_slot(battle,"quick").ok,"ordinary saves cannot branch expedition")
   var funds:float=battle.funds
   check(Expedition.checkpoint(battle),"save real task checkpoint")
   await finish()
   check(Expedition.load_run() and Expedition.prepare_battle(),"resume existing task")
   if not instantiate_battle():await finish();break
   check(is_equal_approx(battle.funds,funds),"resume no duplicate funding")
  var tasks=screen.expedition_runtime.tasks
  preload("res://tests/expedition_minimap_cases.gd").inspect(self,tasks)
  check(tasks.z_index==DepthLayers.ORDER_PREVIEW,"public objective markers above fog "+str(stage))
  if stage==1:
   check(tasks.visible_points()==[1],"capture marks only its actual objective")
   tasks.focus_next()
   check((battle.camera.position+battle.camera_focus_offset()).distance_to(tasks.state.points[1])<1.0,"locate objective centers the playable camera area")
  var before_supplies:int=Expedition.state.supplies
  var before_currency:Dictionary=MetaProgress.currency.duplicate(true)
  var prior_sale:Dictionary=Expedition.state.get("last_auto_sale",{}).duplicate(true)
  var earned:int=[180,220,260,300,340,380][(stage-1)/5]+(200 if stage%5==0 else 100 if next.routes[0].elite else 0)
  earned+=30*int(Expedition.state.buffs.get("supplies",0))+mini(30,mini(5,int(battle.allied_state.get("expedition_losses",0)))*8*int(Expedition.state.buffs.get("salvage",0)))
  earned+=preload("res://scripts/expedition/relics.gd").victory_supplies(Expedition.state)
  satisfy_objective(tasks)
  var income:Dictionary={"credits":800+400*((stage-1)/5),"cores":20+10*((stage-1)/5)}
  var regular:Dictionary=GameData.meta_config.idle.settlement
  var regular_income:Dictionary={"credits":int(regular.win_credits)+int(regular.per_kill_credits)*battle.kills+int(regular.wave_credits)*battle.waves_cleared,"cores":int(regular.win_cores)+int(regular.wave_cores)*battle.waves_cleared}
  for currency:String in income:
   check(MetaProgress.balance(currency)==float(before_currency.get(currency,0))+income[currency]+regular_income[currency],"real victory pays extra chapter income and preserves ordinary rewards "+str(stage)+currency)
  check(Expedition.state.history.back().income==income,"history freezes awarded amounts "+str(stage))
  check(preload("res://tests/expedition_income_cases.gd").contains_text(screen.result_overlay,"远征额外 · 军需券 +%d · 战略核心 +%d（已到账）"%[income.credits,income.cores]),"victory overlay displays chapter award "+str(stage))
  preload("res://tests/expedition_minimap_cases.gd").completed(self,tasks)
  earned+=60 if battle.allied_state.get("expedition_optional",false) else 0
  var sale:Dictionary=Expedition.state.get("last_auto_sale",{})
  var sale_income:int=int(sale.get("supplies",0)) if sale!=prior_sale else 0
  check(Expedition.state.supplies==before_supplies+earned+sale_income and Expedition.state.history.back().supplies==earned,"actual settlement separates raised rewards and automatic sale "+str(stage),{"before":before_supplies,"earned":earned,"sale":sale_income,"after":Expedition.state.supplies})
  check(battle.ended and Expedition.state.phase in ["reward","complete"],"real task result stage "+str(stage),tasks.summary())
  var supplies:int=Expedition.state.supplies
  check(not Expedition.settle(battle,true) and supplies==Expedition.state.supplies,"no repeated settlement "+str(stage))
  var paid_currency:Dictionary=MetaProgress.currency.duplicate(true)
  check(Expedition.load_run(),"reload paid expedition "+str(stage))
  MetaProgress.load_save()
  check(MetaProgress.currency==paid_currency,"reload and repeat preserve wallet "+str(stage))
  await finish()
  if Expedition.state.phase not in ["reward","complete"]:break
 check(Expedition.state.phase=="complete" and Expedition.state.history.size()==30,"all 30 objectives completed")
 check(Expedition.state.event_history.size()==29 and Expedition.state.event.is_empty(),"final victory completes without an unusable next-stage event")
 check(Expedition.load_run() and Expedition.state.phase=="complete","completion survives disk reload")

func check_native_and_traits() -> void:
 new_ready("美国",16)
 var next:Dictionary=Expedition.state.duplicate(true);next.native_talents={"E1":3};next.unit_growth={"E1":{"atk":5,"def":5}}
 Expedition.grant(next,{"kind":"special_unit","id":"GGI","tier":3,"native_rank":2,"count":1})
 Expedition.commit(next);Expedition.launch(0)
 if not instantiate_battle():await finish();return
 var normal=battle.spawn_unit("GGI","ally",battle.player_start()+Vector2(400,0))
 var special=null
 for unit in battle.units:
  if unit.special.has("expedition_variant"):special=unit;break
 check(special!=null and is_equal_approx(Training.scale(normal),1.3) and is_equal_approx(Training.scale(special),1.3),"ordinary and special share default zero-rank native talent")
 check(special!=null and special.bonuses.attack_bonus>normal.bonuses.attack_bonus and special.bonuses.defense_bonus>normal.bonuses.defense_bonus,"individual five-level growth has real attack and defense consumers")
 var soldier=battle.spawn_unit("E1","ally",battle.player_start()+Vector2(420,50))
 check(is_equal_approx(Training.scale(soldier),2.2),"native rank 3 uses real mechanism scalar")
 var permanent:Dictionary=MetaProgress.unit_talents.duplicate(true)
 var foe=battle.spawn_unit("E1","enemy",battle.player_start()+Vector2(500,50))
 check(Training.scale(foe)==1.0,"enemy native unaffected")
 var traits:Dictionary=Rules.context().traits
 traits.fortify=3;traits.vehicle=3;traits.mobile=3;traits.energy=3;traits.artillery=3
 var tank=battle.spawn_unit("MTNK","ally",battle.player_start()+Vector2(500,100))
 tank.special.expedition_distance=180;tank.special.expedition_mobile_cd=0
 check(is_equal_approx(Rules.impact(foe,tank,100,"bullet"),125),"mobile legal first hit +25 percent")
 check(is_equal_approx(Rules.impact(foe,tank,100,"bullet"),100),"first hit cannot repeatedly trigger")
 tank.special.expedition_drive_until=100;tank.hp=tank.max_hp*0.2;Rules.context().buffs.last_stand=3
 check(Rules.defend(tank,100)>=65,"combined reduction capped")
 check(Rules.absorb(tank,100)<100,"first battle shield absorbs real incoming damage")
 check(Expedition.checkpoint(battle),"special squads and combat timers checkpoint")
 await finish();Expedition.prepare_battle()
 if instantiate_battle():
  var restored=false
  for unit in battle.units:
   if unit.special.has("expedition_variant"):restored=Training.scale(unit)>1 and unit.special.expedition_tier==3
  check(restored,"special native and tier survive real restore")
  check(MetaProgress.unit_talents==permanent,"run effects do not write permanent profile")
 await finish()

func check_potomac_mining() -> void:
 new_ready("苏俄",9,"yr_potomac")
 check(Expedition.launch(0),"launch Potomac stage 9")
 if instantiate_battle():
  var miners: Array = battle.units.filter(func(u):return u.side=="ally" and u.is_harvester)
  check(miners.size()==2,"both starting war miners spawn")
  for miner in miners:
   var refinery=miner.home_base
   check(is_instance_valid(refinery),"starting miner has a refinery")
   if not is_instance_valid(refinery):continue
   var ore=miner._native_ore_target(false)
   check(is_instance_valid(ore),"starting miner has reachable ore after all facilities deploy")
   var dock:Vector2=refinery.refinery_dock_point(miner.radius)
   var stage:Vector2=dock+refinery.refinery_dock_direction()*miner.DOCK_STAGE_BACK
   var queue:Vector2=stage+Building.RefineryTraffic.queue_offset(refinery.refinery_dock_direction(),miner.radius,1)
   check(battle.path_service.same_zone(miner.position,stage) and battle.path_service.same_zone(stage,queue),"return and waiting positions are on the mining route")
 await finish()

func check_soviet_and_maps() -> void:
 for id:String in Campaign.NEW_MAPS:
  new_ready("苏俄",1,id)
  check(Expedition.launch(0),"new map launch "+id)
  if instantiate_battle():
   check(battle.map_layout()==id,"native terrain selected "+id)
   for point:Vector2 in screen.expedition_runtime.tasks.state.points:
    check(point.is_finite() and battle.path_service.same_zone(screen.expedition_runtime.tasks.state.origin,point),"reachable objective "+id)
   check(Expedition.checkpoint(battle),"native map checkpoint "+id)
  await finish()

func check_failure_and_retreat() -> void:
 new_ready("美国")
 var income_before:Dictionary=MetaProgress.currency.duplicate(true)
 var supplies:int=Expedition.state.supplies
 Expedition.launch(0)
 if instantiate_battle():
  check(Expedition.retreat(battle),"ordinary stage retreat")
  check(Expedition.state.supplies==supplies-80 and Expedition.state.stage==2,"retreat costs 80 and skips rewards")
  check(not Expedition.retreat(battle),"retreat once")
  check(MetaProgress.currency==income_before,"retreat grants no permanent income")
 await finish()
 new_ready("美国",5);Expedition.launch(0)
 if instantiate_battle():check(not Expedition.retreat(battle),"boss cannot retreat")
 await finish()
 new_ready("美国");Expedition.launch(0)
 if instantiate_battle():
  for building in battle.buildings.duplicate():
   if battle.actor_alive(building) and building.side=="ally":building._die()
  for unit in battle.units.duplicate():
   if battle.actor_alive(unit) and unit.side=="ally":unit._die()
  battle._check_end()
  check(battle.ended and Expedition.state.phase=="failed","actual base defeat ends run")
  var regular:Dictionary=GameData.meta_config.idle.settlement
  check(MetaProgress.balance("credits")==float(income_before.credits)+int(regular.lose_credits)+int(regular.per_kill_credits)*battle.kills and MetaProgress.balance("cores")==float(income_before.cores)+int(regular.lose_cores),"defeat preserves earlier income and only grants original defeat reward")
  check(not Expedition.launch(0) and not Expedition.choose(0),"failed run cannot reuse reward")
 await finish()

func check_camp() -> void:
 new_ready("美国")
 var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);add_child(viewport)
 var camp=load("res://scenes/expedition.tscn").instantiate();viewport.add_child(camp)
 for tab in 4:
  camp.change_tab(tab)
  for frame in 3:await get_tree().process_frame
  check(camp.body.size.x<=1232,"camp tab fits 1280 width "+str(tab),camp.body.size)
 camp.new_run()
 for frame in 3:await get_tree().process_frame
 check(camp.budget!=null and not camp.opening.is_empty(),"custom opening controls exist")
 viewport.free();await get_tree().process_frame
