extends "res://tests/base_recovery_regression.gd"
const Tactics=preload("res://scripts/expedition/elite_tactics.gd")
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):get_tree().quit(2);return
	start(MatchRules.EXTENDED)
	BattleRequest.combat_context.expedition={"elite_tactic":"armor_column","buffs":{},"trait_buffs":{},"traits":{},"condition":"","relics":{}}
	var tank=battle.spawn_unit("HTNK","enemy",Vector2(1500,1500))
	var original_hp:float=tank.max_hp
	Tactics.apply(tank,"armor_column");tank.hp=tank.max_hp*0.6
	tank._grant_veteran(2,false)
	check(is_equal_approx(tank.max_hp,original_hp*1.15),"promotion preserves elite hp")
	check(is_equal_approx(tank.hp/tank.max_hp,0.6),"promotion preserves health fraction")
	AlliedAbilities.change_side(tank,"ally")
	check(is_equal_approx(tank.max_hp,original_hp) and not tank.special.has("expedition_elite_applied"),"capturing elite removes hp bonus")
	check(is_equal_approx(tank.hp/tank.max_hp,0.6),"capture preserves health fraction")
	AlliedAbilities.change_side(tank,"enemy")
	check(is_equal_approx(tank.max_hp,original_hp*1.15),"returning to enemy restores exactly one bonus")
	var infantry=battle.spawn_unit("E2","enemy",Vector2(1700,1500))
	var original_speed:float=infantry.move_speed
	Tactics.apply(infantry,"rapid_raiders")
	AlliedAbilities.change_side(infantry,"ally")
	check(is_equal_approx(infantry._base_speed,original_speed),"captured infantry loses elite speed")
	BattleRequest.combat_context.expedition.elite_tactic="rapid_raiders"
	AlliedAbilities.change_side(infantry,"enemy")
	check(is_equal_approx(infantry._base_speed,original_speed*1.12),"enemy infantry regains speed exactly once")
	var defense=battle._place_building("GAPILL","enemy",Vector2(2100,1600),true)
	var defense_hp:float=defense.max_hp
	Tactics.apply(defense,"entrenched")
	check(is_equal_approx(defense.max_hp,defense_hp*1.2),"defense elite hp")
	AlliedAbilities.change_side(defense,"ally")
	check(is_equal_approx(defense.max_hp,defense_hp),"captured defense loses elite hp")
	var codec:=BattleSaves.Snapshot.new()
	var saved:Dictionary=codec.capture(battle)
	check(codec.error.is_empty(),"capture full real battle snapshot")
	var file:=FileAccess.open(output_dir.path_join("elite_checkpoint.bin"),FileAccess.WRITE)
	file.store_var(saved);file.close()
	file=FileAccess.open(output_dir.path_join("elite_checkpoint.bin"),FileAccess.READ)
	var loaded:Dictionary=file.get_var(false);file.close()
	codec.restore(battle,loaded)
	check(codec.error.is_empty(),"restore disk checkpoint")
	var restored_tank=null;var restored_infantry=null
	for actor in battle.units:
		if actor.unit_id=="HTNK":restored_tank=actor
		if actor.unit_id=="E2":restored_infantry=actor
	check(restored_tank!=null and restored_infantry!=null,"restored actors exist")
	if restored_tank!=null:
		Tactics.apply(restored_tank,"armor_column");restored_tank._grant_veteran(1,false)
		check(is_equal_approx(restored_tank.max_hp,original_hp*1.15),"checkpoint and rank refresh never stack or reset hp")
	if restored_infantry!=null:
		Tactics.apply(restored_infantry,"rapid_raiders");restored_infantry._recompute_bonuses()
		check(is_equal_approx(restored_infantry.move_speed,original_speed*1.12),"checkpoint and recomputation preserve one speed bonus")
	# Actual HUD grouping and mouse callbacks keep heroes separate from their base unit.
	var soldier=battle.spawn_unit("E1","ally",Vector2(1300,1300))
	var hero=battle.spawn_unit("E1","ally",Vector2(1400,1300));hero.special.academy_hero="E1"
	battle.clear_selection();battle.select_unit(soldier,true);battle.select_unit(hero,true)
	battle.hud._rebuild_grouped_strip([soldier,hero])
	check(battle.hud._strip_icons.size()==2,"hero and ordinary infantry have separate HUD groups")
	var hero_entry:Dictionary={}
	for entry:Dictionary in battle.hud._strip_icons:
		if entry.key=="E1:E1":hero_entry=entry
	check(not hero_entry.is_empty(),"hero identity retained on tile")
	if not hero_entry.is_empty():
		var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
		hero_entry.icon.gui_input.emit(click)
		check(battle.selected_units.size()==1 and battle.selected_units[0]==hero,"left click selects hero group only")
	battle.clear_selection();battle.select_unit(soldier,true);battle.select_unit(hero,true)
	battle.hud._rebuild_grouped_strip([soldier,hero])
	for entry:Dictionary in battle.hud._strip_icons:
		if entry.key=="E1:E1":
			var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_RIGHT;click.pressed=true
			entry.icon.gui_input.emit(click);break
	check(battle.selected_units.size()==1 and battle.selected_units[0]==soldier,"right click removes hero and retains ordinary unit")
	var tasks:=preload("res://scripts/expedition/objectives.gd").new()
	battle.add_child(tasks);tasks.world=battle
	tasks.state={"waves":0,"stage":4,"points":[Vector2(1000,1000),Vector2(1600,1600)],"kind":"defend"}
	BattleRequest.combat_context.expedition.elite=true
	BattleRequest.combat_context.expedition.elite_tactic="armor_column"
	var before_wave:int=battle.units.size()
	tasks.wave()
	var new_wave:Array=battle.units.slice(before_wave)
	check(new_wave.size()==5,"armor tactic adds one unit to real elite task wave")
	check(new_wave.filter(func(actor):return actor.unit_id=="HTNK").size()==1,"armor wave contains one heavy tank")
	check(new_wave[-1].special.get("expedition_elite_tactic","")=="armor_column","wave unit receives public elite bonus")
	BattleRequest.combat_context.expedition.elite_tactic="rapid_raiders"
	before_wave=battle.units.size();tasks.wave();new_wave=battle.units.slice(before_wave)
	check(new_wave.size()==6,"rapid tactic adds two infantry to real elite task wave")
	check(new_wave.all(func(actor):return actor.unit_id=="E2" and actor.special.get("expedition_elite_tactic","")=="rapid_raiders"),"rapid wave has correct units and persistent speed")
	tasks.free()
	await finish()
	FileAccess.open(output_dir.path_join("elite-persistence.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("ELITE PERSISTENCE checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
