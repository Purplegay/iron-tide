extends "res://tests/progression_expansion_regression.gd"
const Cases=preload("res://tests/mirror_fork_cases.gd")
const Mirror=preload("res://scripts/units/mirror_fork.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for rank in 4:await display_case(rank)
	await Cases.run(self)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)

func display_case(rank:int) -> void:
	start(MatchRules.EXTENDED)
	var unit=Cases.owner(self,rank);var index:=UnitSkillLayout.find(unit,Mirror.ID)
	battle.select_unit(unit,false);battle._emit_selection()
	var hud=screen.hud
	hud._set_unit_menu_collapsed(false,false)
	check(not hud.sel_shield_label.visible,"no phantom shield before transfer")
	check(battle.request_ability(index)==1,"real first W creates mirrors for display")
	var mirrors:=Mirror.living(unit)
	mirrors[0].hp=mirrors[0].max_hp*.3;mirrors[1].hp=mirrors[1].max_hp*.8
	var shield:float=mirrors[1].hp
	check(battle.request_ability(index)==1,"real second W grants displayed shield")
	hud._refresh_selection_live(false)
	var expected:="护盾 %s / %s"%[HpBar.shield_number(shield),HpBar.shield_number(shield)]
	check(hud.sel_shield_label.visible and hud.sel_shield_label.text==expected,"HUD displays actual transferred shield without unrelated tank cap")
	check(is_equal_approx(unit.shield_readout_amount(),shield) and HpBar.readout("ally",unit.hp,unit.max_hp,unit.shield_readout_amount()).ends_with("盾 "+HpBar.shield_number(shield)),"world HP readout includes mirror shield")
	hud._toggle_unit_menu();hud._refresh_selection_live(false)
	check(hud.sel_shield_label.visible and hud._compact_vitals.is_ancestor_of(hud.sel_shield_label),"compact menu keeps shield number")
	unit.receive_hit(1,"bullet");hud._refresh_selection_live(false)
	var remaining:float=R.state(unit).mirror_shield.hp
	check(remaining<shield and is_equal_approx(unit.shield_readout_amount(),remaining) and hud.sel_shield_label.text=="护盾 %s / %s"%[HpBar.shield_number(remaining),HpBar.shield_number(shield)],"damage updates world and compact HUD from same remaining shield")
	var codec=BattleSaves.Snapshot.new();codec.restore(battle,codec.capture(battle))
	for candidate in battle.units:
		if candidate.special.get("mirror_test_owner",false):unit=candidate;break
	battle.select_unit(unit,false);battle._emit_selection();hud._refresh_selection_live(false)
	check(codec.error.is_empty() and is_equal_approx(unit.shield_readout_amount(),remaining) and hud.sel_shield_label.text=="护盾 %s / %s"%[HpBar.shield_number(remaining),HpBar.shield_number(shield)],"restored shield display retains damage and original cap")
	Mirror.absorb(unit,remaining+1);hud._refresh_selection_live(false)
	check(not hud.sel_shield_label.visible and unit.shield_readout_amount()==0,"broken shield disappears from both readouts")
	R.state(unit).mirror_shield={"hp":.1,"maximum":shield,"left":.1};hud._refresh_selection_live(false)
	check(hud.sel_shield_label.text.begins_with("护盾 1 /"),"positive fractional shield never displays zero")
	Mirror.tick(unit,.1);hud._refresh_selection_live(false)
	check(not hud.sel_shield_label.visible and unit.shield_readout_amount()==0,"expiry hides shield values")
	check(HpBar.readout("enemy",100,100,shield).is_empty(),"enemy shield numbers remain hidden")
	var tank=battle.spawn_unit("MTNK","ally",Vector2(1200,1200))
	tank.special.academy_hero="MTNK"
	tank.special.hero_stationary_shield={"hp":20.0,"left":8.0}
	battle.select_unit(tank,false);battle._emit_selection();hud._refresh_selection_live(false)
	check(hud.sel_shield_label.visible and hud.sel_shield_label.text=="护盾 20 / "+HpBar.shield_number(tank.max_hp*.5) and tank.shield_readout_amount()==20,"existing tank shield retains number and half-health cap")
	await finish()
