extends "res://tests/base_recovery_regression.gd"
const Growth=preload("res://scripts/units/radiation_growth.gd")
const Soviet=preload("res://scripts/units/soviet_specials.gd")

func spawn(rank:int,at:=Vector2(1200,1200)):
	BattleRequest.combat_context.unit_talents={"DESO":{Growth.ID:rank}}
	var unit=battle.spawn_unit("DESO","ally",at)
	unit.set_deployed(true,false)
	Soviet.drop_radiation(unit)
	return unit

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	var intervals:=[5.0,4.8,4.5,1.5]
	var totals:=[0.5,2.0,2.5,4.0]
	for rank in 4:
		battle.allied_state.erase("rad_sites")
		var unit=spawn(rank)
		var site:Dictionary=battle.allied_state.rad_sites[0]
		var base:float=unit.data.deployed_weapon.range
		var level:float=site.level
		var life:float=site.left
		var pulse:float=site.pulse
		Growth.tick(unit,intervals[rank]-0.01)
		check(is_equal_approx(site.radius,base),"rank %d no early growth"%rank)
		Growth.tick(unit,0.01)
		check(is_equal_approx(site.radius,base+totals[rank]*Ra2Damage.PX_PER_CELL/3),"rank %d first layer is one third"%rank)
		Growth.tick(unit,intervals[rank]*2)
		check(int(unit.special[Growth.STACKS])==3 and is_equal_approx(site.radius,base+totals[rank]*Ra2Damage.PX_PER_CELL),"rank %d three layers exact radius"%rank)
		Growth.tick(unit,100)
		check(int(unit.special[Growth.STACKS])==3,"rank %d stops at three layers"%rank)
		check(site.level==level and site.left==life and site.pulse==pulse,"growth does not amplify level or alter decay/pulse")
		Soviet.drop_radiation(unit)
		check(is_equal_approx(site.base_radius,base) and is_equal_approx(site.radius,base+totals[rank]*Ra2Damage.PX_PER_CELL),"refresh does not compound radius")
		var visual=battle.get_node("RadiationFields").get_child(0)
		check(is_equal_approx(visual.size.x,site.radius*2),"rendered field matches gameplay radius")
		unit.set_deployed(false,false)
		check(not unit.special.has(Growth.CLOCK) and not unit.special.has(Growth.STACKS) and is_equal_approx(site.radius,base),"undeploy clears stacks and extra area")
		unit.set_deployed(true,false)
		check(not unit.special.has(Growth.STACKS),"redeploy starts from zero")
		battle.units.erase(unit);unit.free()
	battle.allied_state.erase("rad_sites")
	var first=spawn(3)
	var second=spawn(3)
	var shared:Dictionary=battle.allied_state.rad_sites[0]
	var base:float=first.data.deployed_weapon.range
	Growth.tick(first,4.5);Growth.tick(second,1.5)
	first.set_deployed(false,false)
	check(is_equal_approx(shared.radius,base+4.0*Ra2Damage.PX_PER_CELL/3),"merged site keeps remaining emitter contribution only")
	second.hp=0
	Soviet.tick_world(battle,0)
	check(is_equal_approx(shared.radius,base),"emitter death removes extra radius")
	first.set_deployed(true,false)
	Soviet.drop_radiation(first)
	first._cd_timer=100
	first._physics_process(1.5)
	check(int(first.special.get(Growth.STACKS,0))==1,"real deployed physics drives growth")
	Growth.tick(first,0.25)
	var codec=BattleSaves.Snapshot.new()
	var snapshot:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"growth owner references can be captured")
	codec.restore(battle,snapshot)
	var restored=battle.units.filter(func(u):return u.unit_id=="DESO" and u.hp>0)[0]
	check(int(restored.special[Growth.STACKS])==1 and is_equal_approx(restored.special[Growth.CLOCK],1.75),"load preserves layers and partial timer")
	Growth.tick(restored,1.25)
	check(int(restored.special[Growth.STACKS])==2,"loaded partial timer reaches next layer without restarting")
	var restored_site:Dictionary=battle.allied_state.rad_sites[0]
	check(is_equal_approx(restored_site.radius,base+8.0*Ra2Damage.PX_PER_CELL/3),"restored site retains live source reference")
	BattleRequest.combat_context.unit_talents={}
	var plain=battle.spawn_unit("DESO","ally",Vector2(1500,1500))
	plain.set_deployed(true,false);Soviet.drop_radiation(plain);Growth.tick(plain,100)
	check(not plain.special.has(Growth.STACKS),"unallocated talent grants no growth")
	check(MetaProgress.available_talent_slots("DESO")==2 and MetaProgress.talent_options("DESO").has("native_radiation"),"growth and native radiation talents remain available")
	battle.allied_state.erase("rad_sites")
	var expanded=spawn(3)
	BattleRequest.combat_context.unit_talents.DESO["deso_sample"]=0
	Soviet.drop_radiation(expanded)
	Growth.tick(expanded,4.5)
	var area:Dictionary=battle.allied_state.rad_sites[0]
	check(not area.has("samplers"),"retired sampling cannot register from old battle loadout")
	var victim=battle.spawn_unit("MTNK","enemy",expanded.position+Vector2(base+Ra2Damage.PX_PER_CELL,0))
	var before:float=victim.hp
	battle.paused=false
	battle.ended=false
	get_tree().paused=false
	area.pulse=0.0
	Soviet.tick_world(battle,0)
	check(victim.hp<before,"expanded annulus deals actual radiation damage")
	expanded.set_deployed(false,false)
	before=victim.hp
	area.pulse=0.0
	Soviet.tick_world(battle,0)
	check(victim.hp==before,"withdrawn annulus stops damaging immediately")
	await finish()
	var ui=load("res://scenes/meta.tscn").instantiate()
	add_child(ui)
	ui._show_talent_demo("DESO",Growth.ID,3)
	var options:Array=ui.get_node("TalentDemo").find_children("*","OptionButton",true,false).filter(func(option):return option.item_count>0 and option.get_item_text(0)=="解锁 0 级")
	check(options.size()==1 and options[0].item_count==4 and options[0].selected==3,"demo exposes all four talent levels")
	ui.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
