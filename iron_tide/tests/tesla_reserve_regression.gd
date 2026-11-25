extends "res://tests/ground_control_regression.gd"
const Reserve = preload("res://scripts/units/tesla_reserve.gd")
const Support = preload("res://scripts/units/tesla_support.gd")

func shoot(actor, target) -> bool:
	actor.order_target(target, false, false)
	actor.aim_dir = actor.position.direction_to(target.position)
	actor.hull_angle = actor.aim_dir.angle()
	actor.turret_angle = actor.hull_angle
	actor._cd_timer = 0
	return actor._try_fire_ready()

func exercise(mode: String) -> void:
	start(mode)
	battle.fog = null
	BattleRequest.combat_context.bonuses = MatchRules.neutral_bonuses()
	BattleRequest.combat_context.unit_bonus = {}
	var intervals := [10.0,8.0,5.0,3.0]
	var limits := [1,2,3,3]
	var per_layer := [0.05,0.10,0.30,0.50]
	for rank in 4:
		BattleRequest.combat_context.unit_talents = {"SHK":{Reserve.ID:rank}}
		var actor = battle.spawn_unit("SHK","ally",Vector2(1200,1200))
		var target = battle.spawn_unit("HTNK","enemy",Vector2(1270,1200))
		activate(actor);activate(target)
		target.max_hp = 100000
		target.hp = target.max_hp
		actor.bonuses = MatchRules.neutral_bonuses()
		var key := prefix + "rank %d " % rank
		actor._physics_process(intervals[rank]-0.01)
		check(int(actor.special.get(Reserve.STACKS,0)) == 0,key+"no early layer")
		actor._physics_process(0.01)
		var active := mode == MatchRules.EXTENDED
		check(int(actor.special.get(Reserve.STACKS,0)) == (1 if active else 0),key+"physics reaches first layer")
		var before_first:float=target.hp
		check(shoot(actor,target),key+"one-layer attack fires")
		check(is_equal_approx(before_first-target.hp,floorf(50.0*(1.0+per_layer[rank] if active else 1.0))),key+"single layer damage is additive")
		Reserve.tick(actor,1000)
		check(int(actor.special.get(Reserve.STACKS,0)) == (limits[rank] if active else 0),key+"stack cap")
		check(float(actor.special.get(Reserve.CLOCK,0)) == 0,key+"no banked time at cap")
		for elite in [false,true]:
			if elite: actor._grant_veteran(2,false)
			# Baseline and charged attacks use the same real firing / armor / veterancy path.
			actor.special.erase(Reserve.STACKS);actor.special.erase(Reserve.CLOCK)
			var before: float = target.hp
			check(shoot(actor,target),key+"baseline actually fires "+str(elite))
			var baseline: float = before-target.hp
			Reserve.tick(actor,1000)
			before=target.hp
			check(shoot(actor,target),key+"charged attack actually fires "+str(elite))
			var multiplier: float = 1.0+limits[rank]*per_layer[rank] if active else 1.0
			check(baseline>0 and is_equal_approx(before-target.hp,floorf(baseline*multiplier)),key+"real damage multiplier "+str(elite),[before-target.hp,floorf(baseline*multiplier)])
			check(not actor.special.has(Reserve.STACKS) and not actor.special.has(Reserve.CLOCK),key+"shot consumes layers and partial timer")
			before=target.hp
			check(shoot(actor,target) and is_equal_approx(before-target.hp,baseline),key+"next shot does not retain bonus")
		Reserve.tick(actor,intervals[rank]*0.75)
		shoot(actor,target)
		Reserve.tick(actor,intervals[rank]*0.25)
		check(int(actor.special.get(Reserve.STACKS,0))==0,key+"zero-layer shot resets partial progress")
		Reserve.tick(actor,1000)
		actor.attack_target = null
		check(not actor._try_fire_ready() and int(actor.special.get(Reserve.STACKS,0))==(limits[rank] if active else 0),key+"invalid order does not consume")
		var coil = battle._place_building("TESLA","ally",Vector2(1200,1260),true)
		coil._buildup_play=-1
		actor._cd_timer=0
		Support.tick(actor,coil,0)
		check(int(actor.special.get(Reserve.STACKS,0))==(limits[rank] if active else 0),key+"coil support does not discharge talent")
		check(coil.special.get("tesla_chargers",[]).has(actor),key+"coil support still registers")
		battle.buildings.erase(coil);coil.free()
		if active:
			actor.special.erase(Reserve.STACKS);actor.special.erase(Reserve.CLOCK)
			Reserve.tick(actor,intervals[rank]+0.25 if limits[rank]>1 else 0.25)
			var codec=BattleSaves.Snapshot.new()
			var snapshot: Dictionary=codec.capture(battle)
			check(codec.error.is_empty(),key+"snapshot captures talent")
			codec.restore(battle,snapshot)
			actor=battle.units.filter(func(u):return u.unit_id=="SHK")[0]
			target=battle.units.filter(func(u):return u.unit_id=="HTNK")[0]
			check(int(actor.special.get(Reserve.STACKS,0))==(1 if limits[rank]>1 else 0) and is_equal_approx(float(actor.special[Reserve.CLOCK]),0.25),key+"snapshot retains partial layer")
			Reserve.tick(actor,intervals[rank]-0.25)
			check(int(actor.special[Reserve.STACKS])==(2 if limits[rank]>1 else 1),key+"restored clock continues")
		battle.units.erase(actor);actor.free()
		battle.units.erase(target);target.free()
	BattleRequest.combat_context.unit_talents={}
	var plain=battle.spawn_unit("SHK","ally",Vector2(1200,1200))
	activate(plain)
	Reserve.tick(plain,1000)
	check(not plain.special.has(Reserve.STACKS),prefix+"unallocated grants nothing")
	BattleRequest.combat_context.unit_talents={"SHK":{Reserve.ID:3}}
	plain.side="enemy"
	Reserve.tick(plain,1000)
	check(not plain.special.has(Reserve.STACKS),prefix+"enemy does not inherit player talent")
	plain.side="ally"
	plain.hp=0
	Reserve.tick(plain,1000)
	check(not plain.special.has(Reserve.STACKS),prefix+"dead units cannot charge")
	if mode==MatchRules.EXTENDED:
		plain.hp=plain.max_hp
		var target=battle.spawn_unit("HTNK","enemy",Vector2(1270,1200))
		activate(target)
		target.max_hp=100000;target.hp=100000
		var missed:=false
		target.add_buff("dodge",100,1.0)
		for attempt in 12:
			Reserve.tick(plain,100)
			var before:float=target.hp
			check(shoot(plain,target),"dodge fixture fires")
			missed=missed or target.hp==before
			check(not plain.special.has(Reserve.STACKS),"dodged or successful shot always discharges")
		check(missed,"dodge fixture exercised actual miss")
		Reserve.tick(plain,100)
		var point:=ForceFirePoint.new()
		point.global_position=Vector2(1200,1150)
		plain._fire_shot(point)
		check(not plain.special.has(Reserve.STACKS) and not plain.special.has(Reserve.CLOCK),"empty-ground fire spends reserve")
		plain.order_move(Vector2(1400,1200))
		plain._physics_process(1.0)
		check(is_equal_approx(float(plain.special.get(Reserve.CLOCK,0)),1.0),"movement still charges in actual physics")
		var carrier=battle.spawn_unit("BFRT","ally",plain.position)
		activate(carrier)
		plain.set_stowed(carrier)
		carrier.logistics.passengers.append(plain)
		plain._physics_process(8.0)
		check(int(plain.special.get(Reserve.STACKS,0))==3,"passenger accumulates while not firing")
		carrier.set_fire_stance("guard")
		carrier.order_target(target,false,false)
		plain._cd_timer=0
		OpenTopped.tick(plain,0.01)
		check(not plain.special.has(Reserve.STACKS),"open-topped passenger shot consumes reserve")
		check_ui_and_purchase()
	await finish()

func text_of(node:Node) -> String:
	if node.is_queued_for_deletion():return ""
	var result:=str(node.text) if node is Label or node is Button else ""
	for child in node.get_children():result+="\n"+text_of(child)
	return result

func check_ui_and_purchase() -> void:
	MetaProgress.reset_save()
	MetaProgress.owned_talent_points=1
	MetaProgress.currency.cores=1000
	MetaProgress.currency.credits=100000
	check(MetaProgress.buy_talent_slot("SHK",1),"purchase first talent slot")
	check(MetaProgress.set_unit_talent("SHK",Reserve.ID),"allocate talent through real purchase entry")
	for rank in 3:check(MetaProgress.upgrade_talent("SHK",Reserve.ID,rank),"upgrade through real purchase entry "+str(rank))
	check(not MetaProgress.upgrade_talent("SHK",Reserve.ID,3),"talent caps at rank three")
	MetaProgress.unit_talents={}
	MetaProgress.load_save()
	check(MetaProgress.talent_rank("SHK",Reserve.ID,MetaProgress.unit_talents)==3,"purchased rank persists through disk reload")
	var ui=load("res://scenes/meta.tscn").instantiate()
	add_child(ui)
	ui._set_page("units")
	ui._unit_sel="SHK"
	ui._rebuild_unit_detail()
	var description:=text_of(ui.unit_detail)
	for expected in ["停火蓄电","每 10.0 秒叠层","每 8.0 秒叠层","每 5.0 秒叠层","每 3.0 秒叠层","最多 1 层","最多 2 层","最多 3 层","50.0%"]:
		check(description.contains(expected),"UI includes "+expected)
	ui._show_talent_demo("SHK",Reserve.ID,3)
	var choices:Array=ui.get_node("TalentDemo").find_children("*","OptionButton",true,false).filter(func(option):return option.item_count>0 and option.get_item_text(0)=="解锁 0 级")
	check(choices.size()==1 and choices[0].item_count==4 and choices[0].selected==3,"preview exposes all four ranks")
	check(preload("res://scripts/ui/progression_icon.gd").texture(Reserve.ID)!=null,"talent icon resolves")
	ui.free()
	BattleRequest.freeze_combat_context()
	check(BattleRequest.combat_context.unit_talents.get("SHK",{}).get(Reserve.ID,-1)==3,"new match freezes purchased talent rank")
	MetaProgress.unit_talents={}
	check(BattleRequest.has_unit_talent("SHK",Reserve.ID,"ally"),"lobby changes do not change active match talent")
	MetaProgress.load_save()
	check(MetaProgress.set_effect_enabled("talent",Reserve.ID,"SHK",false),"talent can be disabled without losing purchase")
	BattleRequest.freeze_combat_context()
	check(not BattleRequest.has_unit_talent("SHK",Reserve.ID,"ally"),"disabled talent is omitted from next match")
	check(MetaProgress.talent_rank("SHK",Reserve.ID,MetaProgress.unit_talents)==3,"disabled rank retained")
	BattleRequest.combat_context.erase("unit_talents")
	check(not BattleRequest.has_unit_talent("SHK",Reserve.ID,"ally"),"legacy battle without talent snapshot does not inherit lobby upgrades")
