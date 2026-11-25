extends "res://tests/progression_expansion_2_naval_regression.gd"
const Relay=preload("res://scripts/units/water_relay.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save()
	for level in 4:await relay_cycle(level)
	await overlap();await exclusions();await saved_pool();await loss_and_cap();await fractional_armor();await tuning_and_large_step()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)

func relay_cycle(level:int) -> void:
	setup(level)
	var ship:=make("DEST","ally",Vector2(1100,1200),Naval.WATER);ship.max_hp=1000;ship.hp=1000
	var close:=make("HYD","ally",Vector2(1140,1200));var next:=make("AEGIS","ally",Vector2(1180,1200))
	var enemy:=make("HTNK","enemy",Vector2(1300,1200))
	check(cast(ship),"real W starts shared relay "+str(level))
	var id:int=Naval.state(ship).water_guards[0].relay
	var row:=Relay.pool(ship,id)
	check(row.targets==[ship,close,next] and row.cap==[150.,200.,250.,300.][level],"cast snapshots fixed group and rank cap")
	var stored:=0.0
	for target in [ship,close,next]:
		var before:float=target.hp;target.receive_hit(100,"shell",{},enemy)
		stored+=100-(before-target.hp)
		check(is_equal_approx(row.stored,stored),"all three recipients contribute their actual damage reduction")
	Naval.defend(ship,100,"shell",{},enemy)
	check(is_equal_approx(row.stored,stored),"pure defense query cannot charge relay")
	ship.hp=700;close.max_hp=2000;close.hp=500;next.max_hp=400;next.hp=200
	close.position+=Vector2(1000,0)
	Relay.world_tick(battle,3.99);check(Relay.amount(close)==0,"no shield before water expires")
	Relay.world_tick(battle,.01)
	check(is_equal_approx(Relay.amount(close),stored) and Relay.amount(ship)==0 and Relay.amount(next)==0,"expiry chooses lowest HP ratio even after moving away")
	battle.select_unit(close,false);battle._emit_selection()
	check(is_instance_valid(battle.hud.sel_shield_label) and battle.hud.sel_shield_label.visible and battle.hud.sel_shield_label.text.contains(HpBar.shield_number(stored)),"selected-unit HUD displays relay shield amount")
	check(close.hp==500 and not battle.allied_state.has(Relay.POOLS) and Naval.guard(close)==0,"transfer grants shield without healing or leaving old water")
	Relay.world_tick(battle,0);check(is_equal_approx(Relay.amount(close),stored),"repeated world tick never settles a completed pool twice")
	var before:float=close.hp;close.receive_hit(10,"shell",{},enemy)
	check(close.hp==before and is_equal_approx(Relay.amount(close),stored-10),"relay shield absorbs actual incoming damage")
	Relay.world_tick(battle,5.99);check(Relay.amount(close)>0,"shield remains until final duration boundary")
	Relay.world_tick(battle,.01);check(Relay.amount(close)==0,"shield expires after configured six seconds")
	await finish()

func overlap() -> void:
	setup(0)
	var first:=make("DEST","ally",Vector2(1100,1200),Naval.WATER)
	var second:=make("DEST","ally",Vector2(1140,1200),Naval.WATER)
	var target:=make("HYD","ally",Vector2(1180,1200));var enemy:=make("HTNK","enemy",Vector2(1300,1200))
	cast(first);var one:int=Naval.state(first).water_guards[0].relay
	BattleRequest.combat_context.card_ranks[Naval.WATER]=3;cast(second)
	var two:int=Naval.state(second).water_guards[-1].relay
	target.receive_hit(100,"shell",{},enemy)
	check(Relay.pool(first,one).stored==0 and Relay.pool(first,two).stored==24,"overlapping weak water cannot duplicate strongest reduction")
	w(first).cd_left=0;cast(first);var three:int=Naval.state(first).water_guards[-1].relay
	target.receive_hit(100,"shell",{},enemy)
	check(Relay.pool(first,two).stored==48 and Relay.pool(first,three).stored==0,"equal strength awards only earlier cast")
	Relay.grant(target,80,5);Relay.grant(target,60,10)
	check(Relay.amount(target)==80 and Naval.state(target)[Relay.SHIELD].left==5,"weaker relay neither stacks nor extends stronger residual shield")
	Relay.grant(target,100,6);check(Relay.amount(target)==100,"stronger relay replaces rather than sums")
	var hp:float=target.hp
	Naval.state(target).erase("water_guards");target.receive_hit(150,"shell",{},enemy)
	check(Relay.amount(target)==0 and target.hp==hp-50,"shield breaking passes only excess damage to HP")
	await finish()

func exclusions() -> void:
	setup(3)
	var ship:=make("DEST","ally",Vector2(1100,1200),Naval.WATER)
	var enemy:=make("HTNK","enemy",Vector2(1300,1200));cast(ship)
	var row:=Relay.pool(ship,Naval.state(ship).water_guards[0].relay)
	ship.receive_hit(100,"shell",{"expansion_extra":true},enemy)
	ship.receive_hit(100,"shell",{"equipment_secondary":true},enemy)
	ship.receive_hit(100,"crush",{},enemy);ship.receive_hit(100,"shell",{},ship)
	ship.receive_hit(100,"shell",{},null);ship.receive_hit(-100,"shell",{},enemy)
	GM.god_mode=true;ship.receive_hit(100,"shell",{},enemy);GM.god_mode=false
	ship.special.iron_left=1;ship.receive_hit(100,"shell",{},enemy);ship.special.erase("iron_left")
	check(row.stored==0,"skills secondary melee friendly unknown healing and immune hits cannot charge")
	Relay.world_tick(battle,4);check(Relay.amount(ship)==0,"empty reserve cannot manufacture shield")
	await finish()

func saved_pool() -> void:
	setup(3)
	var ship:=make("DEST","ally",Vector2(1100,1200),Naval.WATER)
	var target:=make("HYD","ally",Vector2(1140,1200));var enemy:=make("HTNK","enemy",Vector2(1300,1200))
	cast(ship);ship.receive_hit(100,"shell",{},enemy);target.receive_hit(100,"shell",{},enemy)
	var id:int=Naval.state(ship).water_guards[0].relay
	Relay.world_tick(battle,1.25)
	var snapshot:Dictionary=BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	ship=battle.units.filter(func(unit):return unit.unit_id=="DEST")[0];target=battle.units.filter(func(unit):return unit.unit_id=="HYD")[0];enemy=battle.units.filter(func(unit):return unit.unit_id=="HTNK")[0]
	var row:=Relay.pool(ship,id)
	check(row.left==2.75 and row.stored==48 and row.targets==[ship,target],"snapshot restores one shared pool with remapped recipients")
	target.receive_hit(100,"shell",{},enemy);check(row.stored==72,"restored participant contributes to same shared pool")
	target.hp=1000;Relay.world_tick(battle,2.75)
	check(Relay.amount(target)==72,"restored pool settles once into living weakest recipient")
	Relay.tick(target,2)
	snapshot=BattleSaves.Snapshot.new().capture(battle);BattleSaves.Snapshot.new().restore(battle,snapshot)
	target=battle.units.filter(func(unit):return unit.unit_id=="HYD")[0]
	check(Relay.amount(target)==72 and Naval.state(target)[Relay.SHIELD].left==4,"shield HP and remaining duration survive save")
	Relay.world_tick(battle,10);check(Relay.amount(target)==0 and not battle.allied_state.has(Relay.CARRIERS),"restored shield expires and settled pool cannot grant again")
	await finish()

func loss_and_cap() -> void:
	setup(3)
	var ship:=make("DEST","ally",Vector2(1100,1200),Naval.WATER);ship.max_hp=1000;ship.hp=1000
	var target:=make("HYD","ally",Vector2(1140,1200));var captured:=make("AEGIS","ally",Vector2(1180,1200))
	var enemy:=make("HTNK","enemy",Vector2(1300,1200));cast(ship)
	var row:=Relay.pool(ship,Naval.state(ship).water_guards[0].relay)
	target.receive_hit(10000,"shell",{},enemy);check(row.stored==300,"all recipients share caster-snapshot cap")
	ship.hp=0;captured.side="enemy";captured.hp=1
	Relay.world_tick(battle,4)
	check(Relay.amount(target)==300 and Relay.amount(captured)==0,"caster death does not cancel transfer; captured lowest-HP ship is excluded")
	await finish()
	setup(3);ship=make("DEST","ally",Vector2(1100,1200),Naval.WATER);cast(ship)
	ship.hp=0;Relay.world_tick(battle,4);check(not battle.allied_state.has(Relay.POOLS),"no surviving recipients removes pool without reward")
	await finish()

func fractional_armor() -> void:
	setup(3)
	var ship:=make("DEST","ally",Vector2(1100,1200),Naval.WATER);ship.bonuses.defense_bonus=2
	var enemy:=make("HTNK","enemy",Vector2(1300,1200))
	var before:float=ship.hp;ship.receive_hit(101,"shell",{},enemy);var unguarded:float=before-ship.hp
	cast(ship);before=ship.hp;ship.receive_hit(101,"shell",{},enemy)
	var row:=Relay.pool(ship,Naval.state(ship).water_guards[0].relay)
	check(is_equal_approx(row.stored,unguarded-(before-ship.hp)),"reserve uses post-defense quantized actual reduction, not raw input")
	var stored:float=row.stored;ship.receive_hit(.1,"shell",{},enemy)
	check(row.stored==stored,"sub-integer zero-damage hits cannot farm fractional reserves")
	await finish()

func tuning_and_large_step() -> void:
	setup(3)
	var model=GameData.progression_tuning
	check(model.apply("skill/ap_escort_water",{"values/relay_cap/3":.5,"values/relay_duration/3":8}).is_empty(),"GM edits new relay cap and duration")
	var ship:=make("DEST","ally",Vector2(1100,1200),Naval.WATER);ship.max_hp=1000;ship.hp=1000
	var target:=make("HYD","ally",Vector2(1140,1200));var enemy:=make("HTNK","enemy",Vector2(1300,1200))
	cast(ship);var row:=Relay.pool(ship,Naval.state(ship).water_guards[0].relay)
	for i in 3:target.receive_hit(1000,"shell",{},enemy)
	check(row.stored==500 and row.cap==500 and row.shield_duration==8,"actual cast consumes configured cap and shield lifetime")
	model.apply("skill/ap_escort_water",{})
	ship.hp=100;Relay.world_tick(battle,5)
	check(Relay.amount(ship)==500 and Naval.state(ship)[Relay.SHIELD].left==7,"large world step settles at water expiry and deducts only elapsed shield time")
	X.tick(ship,5)
	check(Naval.state(ship)[Relay.SHIELD].left==7,"unit tick cannot double-age world-owned relay shield")
	Relay.world_tick(battle,7)
	check(Relay.amount(ship)==0 and not battle.allied_state.has(Relay.CARRIERS),"configured shield expires and cleans world carrier list")
	await finish()
